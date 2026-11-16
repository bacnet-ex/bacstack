if BACstack.MixProject.sc_enabled?() do
  defmodule BACnet.Stack.Transport.ScTransport.Connection do
    @moduledoc """
    Runs one internal BACnet/SC session owned by
    `BACnet.Stack.Transport.ScTransport.Node` or
    `BACnet.Stack.Transport.ScTransport.Hub`.

    Outbound sessions use Gun for the TLS connection and WebSocket upgrade.
    Inbound sessions receive WebSocket events from the Cowboy handler. Once
    the WebSocket is available, both use Annex AB BVLC messages to establish
    the session, detect loss of the peer, and disconnect.

    Both roles send a Heartbeat-Request after `:heartbeat_timeout` without
    inbound BVLC traffic and answer received Heartbeat-Requests. The
    initiating peer's probe is the one required by Addendum bj, YY.6.3.
    Each session correlates heartbeat and disconnect acknowledgments by
    message ID.
    The owner selects the active connector or registers the inbound peer for
    forwarding. Monitoring the owner and socket ensures the session is released
    when either side of that relationship ends.
    """

    alias BACnet.Protocol.SecureConnect.BVLC
    alias BACnet.Stack.Transport.ScTransport.Config
    alias BACnet.Stack.Transport.ScTransport.Credentials
    alias BACnet.Stack.Transport.ScTransport.Diagnostics.GunEvents

    import BACnet.Internal, only: [log_debug: 1]

    require Logger
    use GenServer

    @subprotocol "hub.bsc.bacnet.org"
    @websocket_limit 131_072

    @typedoc """
    Session role and endpoint. A client identifies the hub slot it is dialing.
    A server holds the Cowboy process for the accepted WebSocket.
    """
    @type role :: {:client, :primary | :failover, URI.t()} | {:server, pid()}

    @typedoc """
    The current stage of the session handshake, activity check, or shutdown.
    """
    @type phase ::
            :opening
            | :await_request
            | :await_accept
            | :connected
            | :probing
            | :disconnecting
            | :closing

    defmodule State do
      @moduledoc """
      Tracks one outbound or inbound BACnet/SC session. The session monitors
      both its owner and its WebSocket. A client uses the stream reference to
      associate incoming Gun messages with its WebSocket upgrade.

      The phase timer advances the handshake, heartbeat, and disconnect
      exchanges. The waiting message ID correlates a response to the current
      control request. A separate flush entry lets management confirm that a
      reply has crossed the connection before reconfiguring the port.
      """

      alias BACnet.Stack.Transport.ScTransport.Connection

      @derive {Inspect, except: [:config]}

      @typedoc """
      Session ownership, negotiated peer limits, and outstanding exchanges.
      """
      @type t :: %__MODULE__{
              owner: pid(),
              monitor: reference(),
              role: Connection.role(),
              config: Config.node_config() | Config.hub_config(),
              phase: Connection.phase(),
              timer: {reference(), reference()} | nil,
              next_id: 0..65_535,
              waiting_id: 0..65_535 | nil,
              flush: {0..65_535, GenServer.from(), reference()} | nil,
              socket: pid() | nil,
              stream: reference() | nil,
              socket_monitor: reference() | nil,
              peer: BVLC.peer() | nil,
              close_reason: term(),
              dial_failure: {:dial_error, :dns | :tcp | :tls, term()} | nil,
              request_error: non_neg_integer() | nil
            }

      @fields [
        :owner,
        :monitor,
        :role,
        :config,
        :phase,
        :timer,
        :next_id,
        :waiting_id,
        :flush,
        :socket,
        :stream,
        :socket_monitor,
        :peer,
        :close_reason,
        :dial_failure,
        :request_error
      ]
      @enforce_keys @fields
      defstruct @fields
    end

    @typep transition :: {:noreply, State.t()} | {:stop, :normal, State.t()}

    @doc """
    Returns the WebSocket subprotocol identifier for BACnet/SC hub connections.
    """
    @spec subprotocol() :: String.t()
    def subprotocol(), do: @subprotocol

    @doc """
    Returns the maximum payload size accepted by the WebSocket adapters.
    The BVLC codec applies its own message size limit after reception.
    """
    @spec websocket_limit() :: pos_integer()
    def websocket_limit(), do: @websocket_limit

    @doc """
    Starts a session that monitors its owner. Client sessions dial the
    configured hub. Server sessions attach to an upgraded WebSocket.
    """
    @spec start(pid(), role(), Config.node_config() | Config.hub_config()) :: GenServer.on_start()
    def start(owner, role, config), do: GenServer.start(__MODULE__, {owner, role, config})

    @doc """
    Queues a BVLC frame for transmission on an established session. The
    frame must fit within the peer’s advertised receive limits.
    """
    @spec transmit(pid(), BVLC.t()) :: :ok
    def transmit(pid, frame), do: GenServer.cast(pid, {:transmit, frame})

    @doc """
    Requests graceful disconnection. The session waits for a correlated
    acknowledgment or a timeout before closing its WebSocket.
    """
    @spec disconnect(pid()) :: :ok
    def disconnect(pid), do: GenServer.cast(pid, :disconnect)

    @doc false
    def init({owner, role, config}) do
      monitor = Process.monitor(owner)

      state = %State{
        owner: owner,
        monitor: monitor,
        role: role,
        config: config,
        phase: :opening,
        timer: nil,
        next_id: 0,
        waiting_id: nil,
        flush: nil,
        socket: nil,
        stream: nil,
        socket_monitor: nil,
        peer: nil,
        close_reason: :closed,
        dial_failure: nil,
        request_error: nil
      }

      case role do
        {:client, _kind, _uri} ->
          {:ok, state, {:continue, :dial}}

        {:server, socket} ->
          state = %{state | socket: socket, socket_monitor: Process.monitor(socket)}
          {:ok, arm(state, :await_request, config.connect_wait_timeout)}
      end
    end

    @doc false
    def handle_continue(:dial, %{role: {:client, _kind, uri}, config: config} = state) do
      log_debug(fn -> "BacScConnection: Dialing #{describe_role(state.role)} over TLS" end)
      tls = Credentials.tls(config, :client)

      host = String.to_charlist(uri.host)

      family =
        case :inet.parse_address(host) do
          {:ok, ip} when tuple_size(ip) == 8 -> :inet6
          {:ok, _ipv4} -> :inet
          {:error, _reason} -> Map.get(config, :ip_family, :inet)
        end

      options = %{
        transport: :tls,
        tcp_opts: [family, nodelay: true],
        tls_opts: tls,
        protocols: [:http],
        event_handler: {GunEvents, self()},
        retry: 0,
        connect_timeout: :timer.seconds(config.connect_wait_timeout),
        tls_handshake_timeout: :timer.seconds(config.connect_wait_timeout)
      }

      case :gun.open(host, uri.port, options) do
        {:ok, socket} ->
          state = %{state | socket: socket, socket_monitor: Process.monitor(socket)}
          {:noreply, arm(state, :opening, config.connect_wait_timeout)}

        {:error, reason} ->
          stop(state, {:gun_open, reason})
      end
    end

    @doc false
    def handle_call(:flush, from, %{phase: phase, flush: nil} = state)
        when phase in [:connected, :probing] do
      {request, state} = allocate(state, :heartbeat_request, <<>>)

      log_debug(fn ->
        "BacScConnection: Flushing traffic from VMAC #{Base.encode16(state.config.vmac)} " <>
          "through peer VMAC #{Base.encode16(state.peer.vmac)} with heartbeat message #{request.id}"
      end)

      emit_frame(state, request)
      timer = Process.send_after(self(), {:flush_timeout, request.id}, 2_000)
      {:noreply, %{state | flush: {request.id, from, timer}}}
    end

    def handle_call(:flush, _from, state) do
      log_event(state, "Cannot start another flush")
      {:reply, {:error, :not_connected}, state}
    end

    def handle_call({:send_frame, frame}, _from, %{phase: phase} = state)
        when phase in [:connected, :probing] do
      case encoded_for_peer(state, frame) do
        {:ok, binary} ->
          log_outbound(state, frame)
          emit(state, {:binary, binary})
          {:reply, :ok, state}

        {:error, reason} ->
          log_event(state, fn -> "Rejected BVLC send due to #{reason}" end)
          {:reply, {:error, reason}, state}
      end
    end

    def handle_call({:send_frame, _frame}, _from, state) do
      log_event(state, "Rejected BVLC send before connection was ready")
      {:reply, {:error, :not_connected}, state}
    end

    def handle_call({:send_npdu, destination, npdu, options}, _from, %{phase: phase} = state) do
      if phase in [:connected, :probing] do
        {frame, state} = allocate(state, :npdu, npdu)
        frame = %{frame | destination: destination, data_options: options}

        case encoded_for_peer(state, frame) do
          {:ok, binary} ->
            log_outbound(state, frame)
            emit(state, {:binary, binary})
            {:reply, :ok, state}

          {:error, reason} ->
            log_event(state, fn -> "Rejected NPDU send due to #{reason}" end)
            {:reply, {:error, reason}, state}
        end
      else
        log_event(state, "Rejected NPDU send before connection was ready")
        {:reply, {:error, :not_connected}, state}
      end
    end

    @doc false
    def handle_cast({:transmit, frame}, %{phase: phase} = state)
        when phase in [:connected, :probing] do
      log_event(state, fn -> "Received #{frame.function} message #{frame.id} for forwarding" end)

      case encoded_for_peer(state, frame) do
        {:ok, binary} ->
          emit(state, {:binary, binary})

        {:error, reason} ->
          log_debug(fn ->
            "BacScConnection: Skipped #{frame.function} message #{frame.id} for peer VMAC " <>
              "#{Base.encode16(state.peer.vmac)} due to #{reason}"
          end)
      end

      {:noreply, state}
    end

    def handle_cast({:advertise, destination, payload}, %{phase: phase} = state)
        when phase in [:connected, :probing] do
      log_event(state, "Received advertisement request")
      {frame, state} = allocate(state, :advertisement, payload)
      emit_frame(state, %{frame | destination: destination})
      {:noreply, state}
    end

    def handle_cast(:disconnect, state) do
      log_event(state, "Received local disconnect request")
      initiate_disconnect(state, :closed)
    end

    def handle_cast(_message, state) do
      log_event(state, "Ignored a cast")
      {:noreply, state}
    end

    @doc false
    def handle_info(
          {:gun_up, socket, :http},
          %{socket: socket, role: {:client, _slot, uri}} = state
        ) do
      log_event(state, "Gun established TLS. Requesting the WebSocket upgrade")

      opts = %{
        protocols: [{@subprotocol, :gun_ws_h}],
        compress: false,
        invalid_request_headers: :raise,
        max_frame_size: @websocket_limit
      }

      # Gun brackets IPv6 tuples in its Host header, but here the host stays a
      # string so TLS can apply its hostname checks when enabled.
      headers =
        if String.contains?(uri.host, ":"),
          do: [{"host", "[#{uri.host}]:#{uri.port}"}],
          else: []

      stream = :gun.ws_upgrade(socket, Config.target(uri), headers, opts)
      {:noreply, %{state | stream: stream}}
    end

    def handle_info(
          {:gun_upgrade, socket, stream, _protocols, headers},
          %{
            phase: :opening,
            socket: socket,
            stream: stream
          } = state
        ) do
      log_event(state, "Received Gun WebSocket upgrade response")

      if :proplists.get_all_values("sec-websocket-protocol", headers) == [@subprotocol] do
        {request, state} = allocate(state, :connect_request, identity(state))
        emit_frame(state, request)

        {:noreply,
         arm(%{state | waiting_id: request.id}, :await_accept, state.config.connect_wait_timeout)}
      else
        close(state, 1002, :invalid_subprotocol)
      end
    end

    def handle_info(
          {:gun_response, socket, stream, _fin, status, _headers},
          %{
            socket: socket,
            stream: stream
          } = state
        ) do
      log_event(state, fn -> "WebSocket upgrade rejected with HTTP #{status}" end)
      stop(state, {:http_status, status})
    end

    def handle_info({:gun_down, socket, _protocol, reason, _streams}, %{socket: socket} = state) do
      log_event(state, "Received Gun down event")
      socket_closed(state, {:gun_down, reason})
    end

    def handle_info({:gun_error, socket, _stream, reason}, %{socket: socket} = state) do
      log_event(state, "Received Gun stream error")
      cause = if state.phase == :opening, do: {:http_upgrade, reason}, else: {:gun_error, reason}
      socket_closed(state, cause)
    end

    def handle_info({:gun_error, socket, reason}, %{socket: socket} = state) do
      log_event(state, "Received Gun connection error")
      socket_closed(state, {:gun_error, reason})
    end

    def handle_info(
          {:sc_dial_error, socket, stage, reason},
          %{socket: socket, phase: :opening} = state
        ) do
      log_event(state, fn -> "Gun reported a failure during #{stage}" end)
      {:noreply, %{state | dial_failure: {:dial_error, stage, reason}}}
    end

    def handle_info({:gun_ws, socket, stream, frame}, %{socket: socket, stream: stream} = state),
      do: incoming_websocket(state, frame)

    def handle_info(
          {:sc_websocket, socket, frame},
          %{socket: socket, role: {:server, socket}} = state
        ),
        do: incoming_websocket(state, frame)

    def handle_info({:DOWN, monitor, :process, _pid, reason}, %{socket_monitor: monitor} = state) do
      log_event(state, "WebSocket process went down")
      reason = if elem(state.role, 0) == :client, do: {:gun_process_down, reason}, else: reason
      socket_closed(state, reason)
    end

    def handle_info({:DOWN, monitor, :process, _pid, _reason}, %{monitor: monitor} = state) do
      log_event(state, "Session owner went down")
      initiate_disconnect(state, :owner_closed)
    end

    def handle_info({:flush_timeout, id}, %{flush: {id, from, _timer}} = state) do
      log_event(state, fn -> "Flush heartbeat #{id} timed out" end)
      GenServer.reply(from, {:error, :heartbeat_timeout})
      {:noreply, %{state | flush: nil}}
    end

    def handle_info({:sc_timeout, token}, %{timer: {_timer, token}, phase: phase} = state) do
      log_event(state, "Session timer elapsed")

      case phase do
        :connected ->
          {request, state} = allocate(state, :heartbeat_request, <<>>)
          emit_frame(state, request)

          {:noreply,
           arm(%{state | waiting_id: request.id}, :probing, state.config.heartbeat_timeout)}

        :probing ->
          initiate_disconnect(state, :heartbeat_timeout)

        :disconnecting ->
          close(state, 1000, state.close_reason)

        :closing ->
          stop(state, state.close_reason)

        _phase ->
          close(state, 1000, handshake_timeout(state))
      end
    end

    def handle_info(_message, state) do
      log_event(state, "Ignored an unrecognized or stale message")
      {:noreply, state}
    end

    @doc false
    def format_status(status) do
      status
      |> Map.replace(:state, :redacted)
      |> Map.replace(:message, :redacted)
      |> Map.replace(:log, [])
    end

    @doc false
    def terminate(_reason, %{role: {:client, _slot, _uri}, socket: socket}) when is_pid(socket) do
      :gun.close(socket)
    end

    def terminate(_reason, _state), do: :ok

    @spec incoming_websocket(State.t(), term()) :: transition()
    defp incoming_websocket(state, frame) do
      log_event(state, "Received a WebSocket frame")
      websocket(frame, state)
    end

    @spec websocket(term(), State.t()) :: transition()
    defp websocket({:binary, binary}, state) when byte_size(binary) <= 65_535 do
      case BVLC.decode(binary) do
        {:ok, frame} ->
          receive_frame(state, frame)

        {:error, error, frame} ->
          if frame, do: send_nak(state, frame, error)

          state =
            if match?(<<6, _rest::binary>>, binary),
              do: report_connect_error(state, error),
              else: state

          {:noreply, state}
      end
    end

    defp websocket({:binary, _oversize}, state), do: {:noreply, state}
    defp websocket({:text, _text}, state), do: close(state, 1003, :unsupported_data)
    defp websocket(:close, state), do: socket_closed(state, :websocket_closed)

    defp websocket({:close, code, _reason}, state),
      do: socket_closed(state, {:websocket_closed, code})

    defp websocket(_frame, state), do: {:noreply, state}

    @spec receive_frame(State.t(), BVLC.t()) :: transition()
    defp receive_frame(state, frame) do
      log_event(state, fn -> "Received #{frame.function} message #{frame.id}" end)
      marker = BVLC.unsupported_option(frame)

      if is_nil(frame.destination) and not is_nil(marker) do
        error = BVLC.error_code(:header_not_understood)
        send_nak(state, frame, error, marker)

        state =
          if frame.function == :connect_request,
            do: report_connect_error(state, error),
            else: state

        {:noreply, state}
      else
        receive_phase(state, frame)
      end
    end

    @spec report_connect_error(State.t(), non_neg_integer()) :: State.t()
    defp report_connect_error(%{phase: :await_request} = state, code) do
      notify(state, {:connect_failed, code})
      %{state | request_error: code}
    end

    defp report_connect_error(state, _code), do: state

    @spec handshake_timeout(State.t()) :: term()
    defp handshake_timeout(%{phase: :opening, stream: stream}) when not is_nil(stream),
      do: :http_upgrade_timeout

    defp handshake_timeout(%{phase: :await_request, request_error: code}) when not is_nil(code),
      do: {:connect_rejected, code}

    defp handshake_timeout(_state), do: :connect_timeout

    @spec receive_phase(State.t(), BVLC.t()) :: transition()
    defp receive_phase(
           %{phase: :await_request} = state,
           %BVLC{function: :connect_request} = request
         ) do
      peer = BVLC.peer(request.payload)

      case GenServer.call(state.owner, {:register, self(), peer}) do
        :ok ->
          emit_frame(state, BVLC.response(request, :connect_accept, identity(state)))
          {:noreply, connected(%{state | peer: peer})}

        {:error, code} ->
          send_nak(state, request, code)
          close(state, 1000, {:connect_rejected, code})
      end
    end

    defp receive_phase(
           %{phase: :await_accept, waiting_id: id} = state,
           %BVLC{
             function: :connect_accept,
             id: id
           } = accept
         ) do
      peer = BVLC.peer(accept.payload)
      notify(state, {:ready, peer})
      {:noreply, connected(%{state | peer: peer})}
    end

    defp receive_phase(%{phase: :await_accept, waiting_id: id} = state, %BVLC{
           function: :result,
           source: nil,
           destination: nil,
           id: id,
           payload: <<6, 1, _marker, _class::size(16), code::size(16), _details::binary>>
         }),
         do: close(state, 1000, {:connect_rejected, code})

    defp receive_phase(%{phase: :disconnecting, waiting_id: id} = state, %BVLC{
           function: :disconnect_ack,
           id: id
         }),
         do: close(state, 1000, state.close_reason)

    defp receive_phase(%{phase: :disconnecting, waiting_id: id} = state, %BVLC{
           function: :result,
           source: nil,
           destination: nil,
           id: id,
           payload: <<8, 1, _result::binary>>
         }),
         do: close(state, 1000, state.close_reason)

    defp receive_phase(%{phase: phase} = state, %BVLC{function: :disconnect_request} = frame)
         when phase in [:connected, :probing, :disconnecting] do
      emit_frame(state, BVLC.response(frame, :disconnect_ack))
      close(state, 1000, :closed)
    end

    defp receive_phase(%{phase: phase} = state, %BVLC{function: :heartbeat_request} = frame)
         when phase in [:connected, :probing] do
      emit_frame(state, BVLC.response(frame, :heartbeat_ack))
      {:noreply, if(phase == :connected, do: connected(state), else: state)}
    end

    defp receive_phase(%{flush: {id, from, timer}} = state, %BVLC{
           function: :heartbeat_ack,
           id: id
         }) do
      Process.cancel_timer(timer)
      GenServer.reply(from, :ok)
      {:noreply, %{state | flush: nil}}
    end

    defp receive_phase(%{phase: :probing, waiting_id: id} = state, %BVLC{
           function: :heartbeat_ack,
           id: id
         }),
         do: {:noreply, connected(state)}

    defp receive_phase(%{phase: phase} = state, frame) when phase in [:connected, :probing] do
      if not BVLC.link_function?(frame.function), do: dispatch_frame(state, frame)
      {:noreply, if(phase == :connected, do: connected(state), else: state)}
    end

    defp receive_phase(state, _frame), do: {:noreply, state}

    @spec initiate_disconnect(State.t(), term()) :: transition()
    defp initiate_disconnect(%{phase: phase} = state, reason)
         when phase in [:connected, :probing] do
      {request, state} = allocate(state, :disconnect_request, <<>>)
      emit_frame(state, request)
      state = %{state | waiting_id: request.id, close_reason: reason}
      {:noreply, arm(state, :disconnecting, state.config.disconnect_wait_timeout)}
    end

    defp initiate_disconnect(%{phase: phase} = state, _reason)
         when phase in [:disconnecting, :closing],
         do: {:noreply, state}

    defp initiate_disconnect(state, reason), do: close(state, 1000, reason)

    @spec connected(State.t()) :: State.t()
    defp connected(state),
      do: arm(%{state | waiting_id: nil}, :connected, state.config.heartbeat_timeout)

    @spec arm(State.t(), phase(), pos_integer()) :: State.t()
    defp arm(state, phase, seconds) do
      if state.phase != phase do
        log_event(state, fn -> "Entering #{phase} with a #{seconds}s timer" end)
      end

      if state.timer, do: Process.cancel_timer(elem(state.timer, 0))
      token = make_ref()
      timer = Process.send_after(self(), {:sc_timeout, token}, :timer.seconds(seconds))
      %{state | timer: {timer, token}, phase: phase}
    end

    @spec identity(State.t()) :: binary()
    defp identity(state), do: BVLC.identity(state.config.vmac, state.config.device_uuid)

    @spec allocate(State.t(), BVLC.function_name(), binary()) :: {BVLC.t(), State.t()}
    defp allocate(state, function, payload) do
      frame = %BVLC{
        function: function,
        id: state.next_id,
        source: nil,
        destination: nil,
        destination_options: [],
        data_options: [],
        payload: payload
      }

      {frame, %{state | next_id: rem(state.next_id + 1, 65_536)}}
    end

    @spec log_outbound(State.t(), BVLC.t()) :: :ok
    defp log_outbound(state, frame) do
      log_debug(fn ->
        "BacScConnection: Sending #{frame.function} message #{frame.id} from VMAC " <>
          "#{Base.encode16(state.config.vmac)} to VMAC #{Base.encode16(frame.destination || state.peer.vmac)} " <>
          "through peer VMAC #{Base.encode16(state.peer.vmac)}"
      end)
    end

    @spec encoded_for_peer(State.t(), BVLC.t()) ::
            {:ok, binary()} | {:error, :peer_npdu_too_long | :peer_bvlc_too_long}
    defp encoded_for_peer(state, frame) do
      binary = BVLC.encode(frame)

      cond do
        frame.function == :npdu and byte_size(frame.payload) > state.peer.max_npdu ->
          {:error, :peer_npdu_too_long}

        byte_size(binary) > min(state.peer.max_bvlc, BVLC.max_bvlc()) ->
          {:error, :peer_bvlc_too_long}

        true ->
          {:ok, binary}
      end
    end

    @spec send_nak(State.t(), BVLC.t(), 0..65_535, byte()) :: term()
    defp send_nak(state, frame, error, marker \\ 0) do
      if response = BVLC.nak(frame, error, marker), do: emit_frame(state, response)
    end

    @spec emit_frame(State.t(), BVLC.t()) :: term()
    defp emit_frame(state, frame), do: emit(state, {:binary, BVLC.encode(frame)})

    @spec emit(State.t(), tuple()) :: :ok | tuple()
    defp emit(%{role: {:server, socket}}, frame), do: send(socket, {:sc_send, frame})

    defp emit(%{role: {:client, _slot, _uri}, socket: socket, stream: stream}, frame)
         when is_pid(socket) and not is_nil(stream),
         do: :gun.ws_send(socket, stream, frame)

    defp emit(_state, _frame), do: :ok

    @spec close(State.t(), non_neg_integer(), term()) :: {:noreply, State.t()}
    defp close(state, code, reason) do
      emit(state, {:close, code, ""})
      {:noreply, arm(%{state | close_reason: reason}, :closing, 1)}
    end

    @spec stop(State.t(), term()) :: {:stop, :normal, State.t()}
    defp stop(state, reason) do
      reason = redact_options(reason)

      log_event(state, fn ->
        "Ended session with #{inspect(reason, limit: 8, printable_limit: 100)}"
      end)

      notify(state, {:closed, reason})
      {:stop, :normal, state}
    end

    @spec redact_options(term()) :: term()
    defp redact_options({:options, _options}), do: :invalid_options

    defp redact_options({:dial_error, stage, reason}),
      do: {:dial_error, stage, redact_options(reason)}

    defp redact_options({source, reason})
         when source in [:gun_open, :gun_error, :gun_down, :gun_process_down, :shutdown, :error],
         do: {source, redact_options(reason)}

    defp redact_options(reason), do: reason

    @spec socket_closed(State.t(), term()) :: {:stop, :normal, State.t()}
    defp socket_closed(%{phase: phase} = state, _reason) when phase in [:disconnecting, :closing],
      do: stop(state, state.close_reason)

    defp socket_closed(
           %{phase: :opening, dial_failure: {:dial_error, _stage, _cause} = failure} = state,
           _reason
         ),
         do: stop(state, failure)

    defp socket_closed(state, reason), do: stop(state, reason)

    @spec log_event(State.t(), String.t() | (-> String.t())) :: :ok
    defp log_event(state, message) do
      log_debug(fn ->
        message = if is_function(message, 0), do: message.(), else: message
        "BacScConnection: #{describe_role(state.role)} in #{state.phase} - #{message}"
      end)
    end

    @spec describe_role(role()) :: String.t()
    defp describe_role({:client, slot, uri}),
      do: "#{String.capitalize(Atom.to_string(slot))} hub at #{inspect({uri.host, uri.port})}"

    defp describe_role({:server, socket}), do: "accepted WebSocket #{inspect(socket)}"

    @spec dispatch_frame(State.t(), BVLC.t()) :: :ok | {:sc_connection, pid(), {:frame, BVLC.t()}}
    defp dispatch_frame(%{role: {:server, _socket}} = state, frame) do
      # A subsequent heartbeat ACK confirms that all earlier frames reached the hub.
      GenServer.call(state.owner, {:route, self(), frame})
    end

    defp dispatch_frame(state, frame), do: notify(state, {:frame, frame})

    @spec notify(State.t(), tuple()) :: {:sc_connection, pid(), tuple()}
    defp notify(state, event), do: send(state.owner, {:sc_connection, self(), event})
  end
end
