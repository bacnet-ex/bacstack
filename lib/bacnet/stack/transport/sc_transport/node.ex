if BACstack.MixProject.sc_enabled?() do
  defmodule BACnet.Stack.Transport.ScTransport.Node do
    @moduledoc """
    The BACnet/SC (Secure Connect) transport for a node
    that exchanges BACnet traffic through a hub.

    This transport should be considered experimental.

    To use this transport, you need to run on OTP 27+ and add the [optional dependecies](bacnet_sc.html#dependencies).
    See also the [BACnet/SC page](bacnet_sc.html) for more information.

    ## Implementation scope

    This experimental transport uses the `hub.bsc.bacnet.org` WebSocket
    subprotocol over HTTP/1.1 with mutual TLS 1.3. Direct node-to-node
    connections (`dc.bsc.bacnet.org`) are outside its scope. An Address-Resolution
    request receives a BVLC NAK with `OPTIONAL_FUNCTIONALITY_NOT_SUPPORTED`
    when the request permits a NAK. Peer certificates authenticate membership in
    the configured site trust. The VMAC and Device UUID come from the peer's
    BACnet/SC Connect message and are independent of the certificate identity.

    ## Starting a node

    Open a node with `open/2` or add it to a supervisor using `child_spec/2`.
    Supply a 16-octet `:device_uuid`, a six-octet unicast `:vmac`, and
    `:credentials` prepared by `BACnet.Stack.Transport.ScTransport.Credentials`.
    The UUID identifies the device across sessions and should be saved by the
    application. A collision with another device causes the node to select a
    Random-48 VMAC and try again. Applications can query the live VMAC using
    `get_local_address/1`. Set `:status_receiver` to a PID to receive
    `{:sc_vmac, node_pid, new_vmac}` after a `NODE_DUPLICATE_VMAC` result.
    Persist the new VMAC if it should survive a restart.
    A `BACnet.Stack.Transport.ScTransport.ManagedPort` persists it for its node.

    This example connects to the loopback listener shown in
    `BACnet.Stack.Transport.ScTransport.Hub`. Use the node's own enrolled
    credentials and saved UUID and VMAC. The current process receives the
    transport messages because `self()` is passed as the callback.

    ```elixir
    alias BACnet.Stack.Transport.ScTransport.Credentials
    alias BACnet.Stack.Transport.ScTransport.Node, as: ScNode

    {:ok, credentials} =
      Credentials.from_pem(
        File.read!("sc-site/node.pem"),
        File.read!("sc-site/node-key.pem"),
        [File.read!("sc-site/ca.pem")]
      )

    {:ok, node} =
      ScNode.open(self(),
        primary_hub_uri: "wss://127.0.0.1:47808/",
        device_uuid: File.read!("sc-site/node-uuid"),
        vmac: File.read!("sc-site/node-vmac"),
        credentials: credentials
        name: ScNode
      )
    ```

    `open/2` starts the connection in the background. Use `status/1` to check
    whether the primary hub is active before sending traffic.

    You could add this to your supervisor tree to wait for the connection to become active:
    ```elixir
    %{
      id: :ScNodeWaitConnection,
      restart: :temporary,
      start:
        {Kernel, :apply,
          [
            fn ->
              connected? =
                Enum.any?(1..200, fn _attempt ->
                  case ScNode.status(ScNode).active do
                    :primary ->
                      true

                    nil ->
                      Process.sleep(50)
                      false
                  end
                end)

              if connected? do
                :ignore
              else
                {:error, :hub_handshake_not_completed}
              end
            end,
            []
          ]}
    }
    ```

    ## Hub connection and failover

    Configure the primary WebSocket URI through `:primary_hub_uri` and a
    second endpoint through `:failover_hub_uri`. Configured endpoints must
    use `wss`. An omitted or empty URI leaves that slot unconfigured. A node
    with only a failover URI dials that endpoint directly.

    When both are configured, the connector dials primary first. After losing
    an active primary connection, it tries primary again before dialing failover.
    The retry can start immediately once the minimum interval since the last
    dial has elapsed. Failed attempts use capped exponential backoff.
    While failover carries traffic, the connector continues to probe the
    primary using capped exponential backoff. A valid BACnet/SC Connect-Accept
    from primary switches application traffic over and starts graceful
    disconnection from failover. `status/1` reports the active slot, observed
    peer identity, and the last connection and disconnection of each slot.

    Sessions use binary WebSocket messages. The `:verify_hostname` and
    `:crl_check` options are passed to
    `BACnet.Stack.Transport.ScTransport.Credentials.tls/2` and default to
    disabled. The [timer table](`m:BACnet.Stack.Transport.ScTransport.Config#module-timers`)
    lists defaults and ranges. Heartbeats probe idle sessions, and
    graceful disconnection waits for the matching acknowledgment.

    IPv6 literals use bracketed URI syntax, such as `wss://[::1]:4443/`.
    For hub hostnames, use `ip_family: :inet6` to select IPv6 DNS resolution.
    Hostnames use IPv4 by default.

    ## Sending and receiving BACnet traffic

    A BACnet client uses the node process as a stable portal. Reconnecting or
    switching hubs leaves that portal usable. A send while disconnected
    returns `{:error, :not_connected}`. Callers decide when to retry. A
    destination is a six-octet VMAC or the local all-ones broadcast VMAC.
    The transport supports NPDUs up to 1,497 octets and APDUs up to 1,476
    octets. Each send also respects the active hub's advertised receive limits.

    SC data options can accompany an NPDU through `:data_options`. On receive,
    the usual BACstack callback carries the decoded NPDU or APDU, with a
    `BACnet.Protocol.SecureConnect.BVLC` struct as its datalink metadata. The node
    responds to advertisement solicitations and caches advertisements for up to
    1,024 VMACs on the active connection. A hub switch
    clears the cache. The node ignores application frames from inactive hub
    sessions, including while both WebSockets are up during handover.

    See `BACnet.Stack.Transport.ScTransport.ManagedPort` to expose and manage a node
    over BACnet, and `BACnet.Stack.Transport.ScTransport.Hub` to run a hub listener.
    """

    alias BACnet.Protocol
    alias BACnet.Protocol.SecureConnect.BVLC
    alias BACnet.Stack.Transport.ScTransport.Config
    alias BACnet.Stack.Transport.ScTransport.Connection
    alias BACnet.Stack.Transport.ScTransport.Node.Advertisement
    alias BACnet.Stack.Transport.ScTransport.Node.ConnectionStatus
    alias BACnet.Stack.Transport.ScTransport.Node.Status
    alias BACnet.Stack.TransportBehaviour

    import BACnet.Internal, only: [log_debug: 1]

    require Logger
    use GenServer

    @behaviour TransportBehaviour

    @duplicate_vmac BVLC.error_code(:node_duplicate_vmac)
    @roles [:primary, :failover]
    @protocol {:bacnet_sc, __MODULE__}

    @typedoc """
    Options accepted by the node when sending a frame. Data options are carried
    alongside the NPDU in the BVLC message.
    """
    @type send_option ::
            TransportBehaviour.transport_send_option() | {:data_options, [BVLC.option()]}

    @typedoc """
    The configured slot used to dial a hub.
    """
    @type role :: :primary | :failover

    @typep send_request ::
             {:send_frame, BVLC.t()} | {:send_npdu, BVLC.vmac(), binary(), [BVLC.option()]}

    defmodule Advertisement do
      @moduledoc """
      Records the capabilities announced by an SC peer in a BVLC Advertisement.

      The hub indicator describes the sender's hub connection. The direct
      connection flag and receive limits describe the sender's BVLC endpoint.
      The node caches these observations by the originating peer's VMAC.
      """

      @typedoc """
      The peer's hub indicator, direct-connection capability, and receive limits.
      """
      @type t :: %__MODULE__{
              hub: 0..2,
              accepts_direct_connections: boolean(),
              max_bvlc: non_neg_integer(),
              max_npdu: non_neg_integer()
            }

      @fields [:hub, :accepts_direct_connections, :max_bvlc, :max_npdu]
      @enforce_keys @fields
      defstruct @fields
    end

    defmodule ConnectionStatus do
      @moduledoc """
      Records the latest observation for a primary or failover hub slot.

      The peer and connection timestamp describe the last successful handshake.
      Disconnection and failed-dial timestamps distinguish the end of an
      established session from an unsuccessful attempt to open one. Fields that
      have no observation yet contain `nil`.
      """

      @typedoc """
      The peer, session timestamps, failed-dial timestamp, and latest error.
      """
      @type t :: %__MODULE__{
              peer: BVLC.peer() | nil,
              connected_at: DateTime.t() | nil,
              disconnected_at: DateTime.t() | nil,
              failed_at: DateTime.t() | nil,
              error: term()
            }

      @fields [:peer, :connected_at, :disconnected_at, :failed_at, :error]
      @enforce_keys @fields
      defstruct @fields
    end

    defmodule Status do
      @moduledoc """
      A snapshot of the node's hub connector and advertisement cache.

      The active role identifies the hub currently carrying application traffic.
      Each hub slot contains its latest connection observation or `nil` if it
      has none. Advertisement entries are indexed by the announcing peer's VMAC.
      """

      @typedoc """
      The active hub role, local VMAC, both hub slots, and peer advertisements.
      """
      @type t :: %__MODULE__{
              active: BACnet.Stack.Transport.ScTransport.Node.role() | nil,
              vmac: BVLC.vmac(),
              primary: ConnectionStatus.t() | nil,
              failover: ConnectionStatus.t() | nil,
              advertisements: %{optional(BVLC.vmac()) => Advertisement.t()}
            }

      @fields [:active, :vmac, :primary, :failover, :advertisements]
      @enforce_keys @fields
      defstruct @fields
    end

    defmodule State do
      @moduledoc """
      Holds the node connector state across hub session restarts. The transport
      process owns this state and keeps the same callback and portal while it
      selects an active hub and schedules connection attempts for each slot.

      Timer tokens distinguish current attempts from previously cancelled ones.
      Connection observations are retained for management reads, and the
      advertisement cache belongs to the current active session.
      """

      alias BACnet.Stack.Transport.ScTransport.Node

      @derive {Inspect, except: [:config]}

      @typedoc """
      Connector configuration, active role, pending work, and peer observations.
      """
      @type t :: %__MODULE__{
              callback: TransportBehaviour.transport_callback(),
              config: Config.node_config(),
              active: Node.role() | nil,
              attempts: %{optional(Node.role()) => %{pid: pid(), monitor: reference()}},
              retiring: %{optional(pid()) => {Node.role(), DateTime.t(), reference()}},
              timers: %{optional(Node.role()) => {reference(), reference()}},
              last_start: %{optional(Node.role()) => integer()},
              delays: %{optional(Node.role()) => pos_integer()},
              statuses: %{optional(Node.role()) => ConnectionStatus.t()},
              advertisements: %{optional(BVLC.vmac()) => Advertisement.t()}
            }

      @fields [
        :callback,
        :config,
        :active,
        :attempts,
        :retiring,
        :timers,
        :last_start,
        :delays,
        :statuses,
        :advertisements
      ]
      @enforce_keys @fields
      defstruct @fields
    end

    @doc """
    Starts a supervised-compatible node linked to the caller. The hub connection is
    established asynchronously. The callback receives application and network frames
    using the standard BACstack transport callback format.
    """
    @spec open(TransportBehaviour.transport_callback(), Config.options()) :: GenServer.on_start()
    def open(callback, opts) do
      with :ok <- Config.runtime([:ssl, :gun]),
           {:ok, config} <- Config.node(opts) do
        GenServer.start_link(__MODULE__, {callback, config}, Keyword.take(opts, [:name]))
      end
    end

    @doc """
    Builds the child specification for `{Node, [callback, opts]}`. A
    `{callback, opts}` tuple is also accepted. An empty argument list supplies
    the base specification used by `BACnet.Stack.TransportBehaviour.child_spec/4`.
    """
    @spec child_spec(
            []
            | [TransportBehaviour.transport_callback() | Config.options()]
            | {TransportBehaviour.transport_callback(), Config.options()}
          ) :: Supervisor.child_spec()
    def child_spec(arg)

    def child_spec([]), do: child_spec({nil, []})
    def child_spec([callback, opts]), do: child_spec({callback, opts})

    def child_spec({callback, opts}) do
      %{id: Keyword.get(opts, :name, __MODULE__), start: {__MODULE__, :open, [callback, opts]}}
    end

    @doc """
    Builds a child specification from the callback and node options passed to `open/2`.
    """
    @spec child_spec(TransportBehaviour.transport_callback(), Config.options()) ::
            Supervisor.child_spec()
    def child_spec(callback, opts), do: child_spec({callback, opts})

    @doc """
    Stops the node and starts disconnection of any open hub sessions.
    """
    @spec close(GenServer.server()) :: :ok
    def close(transport), do: GenServer.stop(transport)

    @doc """
    Returns the transport identifier used by BACstack for BACnet Secure Connect.
    """
    @spec bacnet_protocol() :: TransportBehaviour.transport_protocol()
    def bacnet_protocol(), do: :bacnet_sc

    @doc """
    Returns the maximum APDU size in octets that this transport advertises.
    """
    @spec max_apdu_length() :: 1476
    def max_apdu_length(), do: 1476

    @doc """
    Returns the maximum NPDU size in octets, including the network header.
    """
    @spec max_npdu_length() :: 1497
    def max_npdu_length(), do: BVLC.max_npdu()

    @doc """
    Returns the six-octet local broadcast VMAC.
    """
    @spec get_broadcast_address(GenServer.server()) :: BVLC.vmac()
    def get_broadcast_address(_transport), do: BVLC.broadcast()

    @doc """
    Returns the node’s current VMAC, including any change made after a collision.
    """
    @spec get_local_address(GenServer.server()) :: BVLC.vmac()
    def get_local_address(transport), do: GenServer.call(transport, :local_address)

    @doc """
    Returns the node PID used for sending and receiving frames. Named nodes resolve
    to the same PID carried by receive callbacks.
    """
    @spec get_portal(GenServer.server()) :: pid()
    def get_portal(transport) when is_pid(transport), do: transport
    def get_portal(transport), do: GenServer.call(transport, :portal)

    @doc """
    Returns `false` because BACnet/SC destinations are VMACs on the local datalink.
    The caller may still provide network routing fields in the NPCI.
    """
    @spec destination_routed?(GenServer.server(), term()) :: false
    def destination_routed?(_transport, _address), do: false

    @doc """
    Checks whether a value is a usable unicast VMAC or the local broadcast VMAC.
    """
    @spec valid_destination?(term()) :: boolean()
    def valid_destination?(address), do: address == BVLC.broadcast() or BVLC.valid_vmac?(address)

    @doc """
    Returns the node's `BACnet.Stack.Transport.ScTransport.Node.Status`.
    The active role is `nil` while disconnected. The `:primary` and `:failover`
    fields hold the latest observations for those slots.
    """
    @spec status(GenServer.server()) :: Status.t()
    def status(transport), do: GenServer.call(transport, :status)

    @doc """
    Uses a correlated heartbeat to confirm that the current hub has received the
    frames already sent on this session. The probe has a two-second operation
    deadline independent of the periodic heartbeat timer.
    """
    @spec flush(GenServer.server()) :: :ok | {:error, :not_connected | :heartbeat_timeout}
    def flush(transport), do: GenServer.call(transport, :flush)

    @doc """
    Applies new node options while preserving the portal. Adding trusted issuers
    can retain the current connection. Pass `true` as the third argument to
    restart sessions even when the configuration is identical.
    """
    @spec reconfigure(GenServer.server(), Config.options(), boolean()) :: :ok | {:error, term()}
    def reconfigure(transport, opts, restart? \\ false) do
      with {:ok, config} <- Config.node(opts) do
        GenServer.call(transport, {:reconfigure, config, restart?})
      end
    end

    @doc """
    Reconfigures the node and waits for its retired active session to close.
    Use after queuing a reply through a local hub that will also retire its
    sessions. The disconnect follows the reply on the same WebSocket.
    """
    @spec reconfigure_for_hub_cutover(GenServer.server(), Config.options()) ::
            :ok | {:error, term()}
    def reconfigure_for_hub_cutover(transport, opts) do
      with {:ok, config} <- Config.node(opts) do
        case GenServer.call(transport, {:reconfigure_for_hub_cutover, config}) do
          {nil, _timeout} -> :ok
          {pid, timeout} -> await_session(pid, timeout)
        end
      end
    end

    @spec await_session(pid(), non_neg_integer()) :: :ok
    defp await_session(pid, timeout) do
      monitor = Process.monitor(pid)

      receive do
        {:DOWN, ^monitor, :process, ^pid, _reason} -> :ok
      after
        timeout ->
          Process.demonitor(monitor, [:flush])
          :ok
      end
    end

    @doc """
    Sends an APDU or network message to a VMAC through the active hub. Pass
    `:data_options` to include Annex AB data options. With `:skip_headers`, supply
    an encoded SC NPDU frame addressed to the same VMAC. The function returns
    `{:error, :not_connected}` while no hub session is available.
    """
    @spec send(GenServer.server(), BVLC.vmac(), BACnet.Stack.EncoderProtocol.t() | iodata(), [
            send_option()
          ]) :: :ok | {:error, term()}
    def send(portal, destination, data, opts \\ []) do
      if valid_destination?(destination) do
        with {:ok, request} <- packet(destination, data, opts) do
          GenServer.call(portal, request)
        end
      else
        {:error, :invalid_destination}
      end
    end

    @spec packet(BVLC.vmac(), BACnet.Stack.EncoderProtocol.t() | iodata(), [send_option()]) ::
            {:ok, send_request()} | {:error, term()}
    defp packet(destination, data, opts) do
      if opts[:skip_headers] == true and not is_struct(data) do
        raw_packet(destination, IO.iodata_to_binary(data))
      else
        npdu_packet(destination, data, opts)
      end
    end

    @spec raw_packet(BVLC.vmac(), binary()) :: {:ok, {:send_frame, BVLC.t()}} | {:error, atom()}
    defp raw_packet(destination, payload) do
      case BVLC.decode(payload) do
        {:ok, %BVLC{source: nil, destination: ^destination, function: :npdu} = frame} ->
          if byte_size(frame.payload) <= max_npdu_length(),
            do: {:ok, {:send_frame, frame}},
            else: {:error, :npdu_too_long}

        _other ->
          {:error, :invalid_bvlc}
      end
    end

    @spec npdu_packet(BVLC.vmac(), BACnet.Stack.EncoderProtocol.t() | iodata(), [send_option()]) ::
            {:ok, {:send_npdu, BVLC.vmac(), binary(), [BVLC.option()]}} | {:error, term()}
    defp npdu_packet(destination, data, opts) do
      broadcast? = destination == BVLC.broadcast()

      with {:ok, {npci, apdu}} <- TransportBehaviour.build_bacnet_packet(data, broadcast?, opts) do
        payload = IO.iodata_to_binary([npci, apdu])
        options = Keyword.get(opts, :data_options, [])

        cond do
          IO.iodata_length(apdu) == 0 -> {:error, :data_empty}
          IO.iodata_length(apdu) > max_apdu_length() -> {:error, :apdu_too_long}
          byte_size(payload) > max_npdu_length() -> {:error, :npdu_too_long}
          npci in [[], ""] -> {:error, :missing_npci}
          not valid_options?(options) -> {:error, :invalid_data_options}
          true -> {:ok, {:send_npdu, destination, payload, options}}
        end
      end
    end

    @spec valid_options?(term()) :: boolean()
    defp valid_options?(options) when is_list(options) do
      Enum.all?(options, fn
        {1, true, nil} ->
          true

        {type, must, data} when type in 2..31 and is_boolean(must) ->
          is_nil(data) or (is_binary(data) and byte_size(data) <= 65_535)

        _other ->
          false
      end)
    end

    defp valid_options?(_options), do: false

    @doc false
    def init({callback, config}) do
      state = %State{
        callback: callback,
        config: config,
        active: nil,
        attempts: %{},
        retiring: %{},
        timers: %{},
        last_start: %{},
        delays: %{},
        statuses: %{},
        advertisements: %{}
      }

      log_debug("BacScNode: Starting the hub connector")
      {:ok, start_connector(state)}
    end

    @doc false
    def handle_call(:local_address, _from, state) do
      log_debug("BacScNode: Received local address request")
      {:reply, state.config.vmac, state}
    end

    def handle_call(:portal, _from, state) do
      log_debug("BacScNode: Received portal request")
      {:reply, self(), state}
    end

    def handle_call(:status, _from, state) do
      log_debug("BacScNode: Received status request")

      status = %Status{
        active: state.active,
        vmac: state.config.vmac,
        primary: state.statuses[:primary],
        failover: state.statuses[:failover],
        advertisements: state.advertisements
      }

      {:reply, status, state}
    end

    def handle_call({:reconfigure, config, restart?}, _from, state) do
      log_debug("BacScNode: Received reconfigure request")

      if not restart? and can_retain_session?(state.config, config) do
        {:reply, :ok, %{state | config: config}}
      else
        log_debug("BacScNode: Restarting hub connections for a configuration update")
        state = reset(state)
        {:reply, :ok, start_connector(%{state | config: config, last_start: %{}, delays: %{}})}
      end
    end

    def handle_call({:reconfigure_for_hub_cutover, config}, from, state) do
      log_debug("BacScNode: Received reconfigure request for local hub cutover")
      active = state.attempts[state.active]
      timeout = :timer.seconds(state.config.disconnect_wait_timeout + 2)
      {:reply, :ok, updated} = handle_call({:reconfigure, config, true}, from, state)
      {:reply, {active && active.pid, timeout}, updated}
    end

    def handle_call(request, _from, %{active: role} = state)
        when request == :flush or elem(request, 0) in [:send_npdu, :send_frame] do
      log_debug(fn ->
        operation = if request == :flush, do: :flush, else: elem(request, 0)
        "BacScNode: Received #{operation} request with active hub #{inspect(role)}"
      end)

      case state.attempts[role] do
        %{pid: pid} ->
          result =
            try do
              GenServer.call(pid, request)
            catch
              :exit, _reason -> {:error, :not_connected}
            end

          {:reply, result, state}

        nil ->
          {:reply, {:error, :not_connected}, state}
      end
    end

    @doc false
    def handle_info({:sc_dial, role, token}, state) do
      log_debug(fn -> "BacScNode: Received dial timer for the #{role} hub" end)

      case state.timers[role] do
        {_timer, ^token} ->
          {:noreply, start_attempt(%{state | timers: Map.delete(state.timers, role)}, role)}

        _stale ->
          {:noreply, state}
      end
    end

    def handle_info({:sc_connection, pid, {:ready, peer}}, state) do
      log_debug(fn -> "BacScNode: Received a ready event from session #{inspect(pid)}" end)

      case role_for(state, pid) do
        nil -> {:noreply, state}
        role -> {:noreply, activate(state, role, peer)}
      end
    end

    def handle_info({:sc_connection, pid, {:closed, reason}}, state) do
      log_debug(fn -> "BacScNode: Received a close event from session #{inspect(pid)}" end)
      {:noreply, connection_closed(state, pid, reason)}
    end

    def handle_info({:sc_connection, pid, {:frame, frame}}, state) do
      if state.active && state.attempts[state.active].pid == pid do
        {:noreply, receive_frame(state, pid, frame)}
      else
        log_debug(fn -> "BacScNode: Ignored a frame from inactive session #{inspect(pid)}" end)
        {:noreply, state}
      end
    end

    def handle_info({:DOWN, _monitor, :process, pid, reason}, state) do
      log_debug(fn -> "BacScNode: Received a process-down event for #{inspect(pid)}" end)
      {:noreply, connection_closed(state, pid, reason)}
    end

    def handle_info(_message, state) do
      log_debug("BacScNode: Ignored an unrecognized message")
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
    def terminate(_reason, state) do
      log_debug("BacScNode: Closing the node")
      reset(state)
    end

    @spec role_for(State.t(), pid()) :: role() | nil
    defp role_for(state, pid) do
      Enum.find(@roles, fn role -> match?(%{pid: ^pid}, state.attempts[role]) end)
    end

    @spec start_connector(State.t()) :: State.t()
    defp start_connector(state) do
      role = if state.config.primary, do: :primary, else: :failover
      schedule(state, role)
    end

    @spec can_retain_session?(Config.node_config(), Config.node_config()) :: boolean()
    defp can_retain_session?(old, new) do
      old_issuers = old.credentials.issuers
      new_issuers = new.credentials.issuers
      updated = put_in(old.credentials.issuers, new_issuers)
      updated == new and Enum.all?(old_issuers, &(&1 in new_issuers))
    end

    @spec schedule(State.t(), role()) :: State.t()
    defp schedule(state, role) do
      if state.config[role] && !state.attempts[role] && !state.timers[role] do
        minimum = min(state.config.min_reconnect_time, state.config.max_reconnect_time)
        delay = Map.get(state.delays, role, minimum)
        now = System.monotonic_time(:millisecond)

        wait =
          if last = state.last_start[role],
            do: max(0, last + :timer.seconds(delay) - now),
            else: 0

        token = make_ref()
        timer = Process.send_after(self(), {:sc_dial, role, token}, wait)
        log_debug(fn -> "BacScNode: Scheduled the #{role} hub in #{wait} ms" end)
        put_in(state.timers[role], {timer, token})
      else
        state
      end
    end

    @spec start_attempt(State.t(), role()) :: State.t()
    defp start_attempt(state, role) do
      state = put_in(state.last_start[role], System.monotonic_time(:millisecond))
      uri = state.config[role]

      log_debug(fn ->
        "BacScNode: VMAC #{Base.encode16(state.config.vmac)} connecting to the #{role} hub " <>
          "at #{inspect({uri.host, uri.port})}"
      end)

      case Connection.start(self(), {:client, role, uri}, state.config) do
        {:ok, pid} ->
          attempt = %{pid: pid, monitor: Process.monitor(pid)}
          put_in(state.attempts[role], attempt)

        {:error, reason} ->
          disconnected(state, role, reason)
      end
    end

    @spec activate(State.t(), role(), BVLC.peer()) :: State.t()
    defp activate(state, role, peer) do
      status = %ConnectionStatus{
        peer: peer,
        connected_at: DateTime.utc_now(),
        disconnected_at: nil,
        failed_at: nil,
        error: nil
      }

      log_debug(fn ->
        event =
          if state.active == :failover and role == :primary,
            do: "Returned to the primary hub",
            else: "Connected to the #{role} hub"

        "BacScNode: #{event} at #{inspect({state.config[role].host, state.config[role].port})} " <>
          "with VMAC #{Base.encode16(peer.vmac)} and Device UUID #{Base.encode16(peer.uuid)} " <>
          "as local VMAC #{Base.encode16(state.config.vmac)}"
      end)

      state =
        %{
          state
          | statuses: Map.put(state.statuses, role, status),
            delays: Map.delete(state.delays, role)
        }

      if role == :primary do
        %{retire(state, :failover) | active: :primary, advertisements: %{}}
      else
        %{state | active: :failover, advertisements: %{}}
      end
    end

    @spec disconnected(State.t(), role() | nil, term()) :: State.t()
    defp disconnected(state, nil, _reason), do: state

    defp disconnected(state, role, reason) do
      was_active = state.active == role
      state = retire(state, role, reason)

      log_disconnect(state.config[role], role, was_active, reason)

      state =
        if was_active do
          state
        else
          failed_at = DateTime.utc_now()

          status =
            case state.statuses[role] do
              nil ->
                %ConnectionStatus{
                  peer: nil,
                  connected_at: nil,
                  disconnected_at: nil,
                  failed_at: failed_at,
                  error: reason
                }

              previous ->
                %{previous | failed_at: failed_at, error: reason}
            end

          put_in(state.statuses[role], status)
        end

      case reason do
        {:connect_rejected, @duplicate_vmac} ->
          vmac = BVLC.random_vmac()

          log_debug(fn ->
            "BacScNode: The #{role} hub rejected VMAC #{Base.encode16(state.config.vmac)}. " <>
              "Retrying with VMAC #{Base.encode16(vmac)}"
          end)

          receiver = state.config[:status_receiver]
          if is_pid(receiver), do: Kernel.send(receiver, {:sc_vmac, self(), vmac})
          state = reset(state)
          start_connector(put_in(state.config.vmac, vmac))

        _other ->
          state = if was_active, do: state, else: increase_delay(state, role)
          state = schedule(state, role)
          if role == :primary and !was_active, do: schedule(state, :failover), else: state
      end
    end

    @spec log_disconnect(URI.t(), role(), boolean(), term()) :: :ok
    defp log_disconnect(uri, role, was_active, reason) do
      str_role = String.capitalize(Atom.to_string(role))

      if reason in [:closed, :owner_closed, {:connect_rejected, @duplicate_vmac}] do
        log_debug(fn ->
          "BacScNode: #{str_role} hub session " <>
            "at #{inspect({uri.host, uri.port})} ended " <>
            "with #{inspect(reason)}"
        end)
      else
        Logger.warning(fn ->
          event =
            if was_active,
              do: "Lost active #{role} hub connection",
              else: "#{str_role} hub connection attempt failed"

          "BacScNode: #{event} at #{inspect({uri.host, uri.port})} " <>
            "with #{inspect(reason, limit: 8, printable_limit: 100)}. " <>
            "Retrying with configured backoff."
        end)
      end
    end

    @spec connection_closed(State.t(), pid(), term()) :: State.t()
    defp connection_closed(state, pid, reason) do
      case Map.pop(state.retiring, pid) do
        {nil, _retiring} ->
          disconnected(state, role_for(state, pid), reason)

        {{role, connected_at, monitor}, retiring} ->
          Process.demonitor(monitor, [:flush])
          state = %{state | retiring: retiring}

          case state.statuses[role] do
            %{connected_at: ^connected_at} ->
              put_in(state.statuses[role].disconnected_at, DateTime.utc_now())

            _newer_session ->
              state
          end
      end
    end

    @spec increase_delay(State.t(), role()) :: State.t()
    defp increase_delay(state, role) do
      delay =
        case state.delays[role] do
          nil -> state.config.min_reconnect_time
          previous -> previous * 2
        end

      put_in(state.delays[role], min(delay, state.config.max_reconnect_time))
    end

    @spec retire(State.t(), role(), term()) :: State.t()
    defp retire(state, role, reason \\ :planned) do
      case state.timers[role] do
        {timer, _token} -> Process.cancel_timer(timer)
        nil -> :ok
      end

      state = retire_attempt(state, role, state.attempts[role], reason)

      %{
        state
        | active: if(state.active == role, do: nil, else: state.active),
          attempts: Map.delete(state.attempts, role),
          timers: Map.delete(state.timers, role)
      }
    end

    @spec retire_attempt(State.t(), role(), %{pid: pid(), monitor: reference()} | nil, term()) ::
            State.t()
    defp retire_attempt(%{active: role} = state, role, %{pid: pid, monitor: monitor}, :planned) do
      connected_at = state.statuses[role].connected_at
      Connection.disconnect(pid)
      put_in(state.retiring[pid], {role, connected_at, monitor})
    end

    defp retire_attempt(state, role, attempt, reason) do
      if attempt do
        Process.demonitor(attempt.monitor, [:flush])
        Connection.disconnect(attempt.pid)
      end

      if state.active == role and reason != :planned do
        status = %{state.statuses[role] | disconnected_at: DateTime.utc_now(), error: reason}
        put_in(state.statuses[role], status)
      else
        state
      end
    end

    @spec reset(State.t()) :: State.t()
    defp reset(state), do: Enum.reduce(@roles, state, &retire(&2, &1))

    @spec receive_frame(State.t(), pid(), BVLC.t()) :: State.t()
    defp receive_frame(state, pid, frame) do
      marker = BVLC.unsupported_option(frame)

      log_debug(fn ->
        hub = state.statuses[state.active].peer.vmac
        source = if frame.source, do: Base.encode16(frame.source), else: Base.encode16(hub)
        destination = frame.destination || state.config.vmac

        "BacScNode: Received #{frame.function} message #{frame.id} from VMAC #{source} " <>
          "to VMAC #{Base.encode16(destination)} through the #{state.active} hub #{Base.encode16(hub)}"
      end)

      cond do
        frame.destination not in [nil, BVLC.broadcast()] ->
          state

        marker ->
          if response = BVLC.nak(frame, BVLC.error_code(:header_not_understood), marker),
            do: Connection.transmit(pid, response)

          state

        true ->
          process_frame(state, pid, frame)
      end
    end

    @spec process_frame(State.t(), pid(), BVLC.t()) :: State.t()
    defp process_frame(state, _pid, %BVLC{function: :npdu, source: source, payload: npdu} = frame)
         when not is_nil(source) and byte_size(npdu) <= 1497 do
      with {:ok, {npci, payload}} <- Protocol.decode_npci(npdu),
           true <- is_nil(npci.hopcount) or npci.hopcount > 0,
           {:ok, {type, data}} <- Protocol.decode_npdu(npci, payload) do
        deliver(state.callback, source, {type, %{frame | payload: <<>>}, npci, data})
      end

      state
    end

    defp process_frame(state, pid, %BVLC{function: :address_resolution} = frame) do
      if response = BVLC.nak(frame, BVLC.error_code(:optional_functionality_not_supported)),
        do: Connection.transmit(pid, response)

      state
    end

    defp process_frame(state, pid, %BVLC{function: :advertisement_solicitation} = frame) do
      status = if state.active == :primary, do: 1, else: 2
      payload = <<status, 0, BVLC.max_bvlc()::size(16), BVLC.max_npdu()::size(16)>>
      GenServer.cast(pid, {:advertise, frame.source, payload})
      state
    end

    defp process_frame(state, _pid, %BVLC{function: :advertisement, source: source} = frame)
         when not is_nil(source) do
      <<hub, direct, max_bvlc::size(16), max_npdu::size(16)>> = frame.payload

      advertisement = %Advertisement{
        hub: hub,
        accepts_direct_connections: direct == 1,
        max_bvlc: max_bvlc,
        max_npdu: max_npdu
      }

      deliver(state.callback, source, {:bvlc, frame})

      if map_size(state.advertisements) < 1024 or Map.has_key?(state.advertisements, source) do
        put_in(state.advertisements[source], advertisement)
      else
        state
      end
    end

    defp process_frame(state, _pid, %BVLC{function: function} = frame)
         when function in [:result, :proprietary, :address_resolution_ack] do
      source = frame.source || state.statuses[state.active].peer.vmac
      deliver(state.callback, source, {:bvlc, frame})
      state
    end

    defp process_frame(state, _pid, _frame), do: state

    @spec deliver(
            TransportBehaviour.transport_callback(),
            BVLC.vmac(),
            TransportBehaviour.transport_cb_frame()
          ) :: term()
    defp deliver(callback, source, frame) do
      portal = self()

      case callback do
        fun when is_function(fun, 3) ->
          Task.start(fn -> fun.(source, frame, portal) end)

        {module, function, 3} when is_atom(module) and is_atom(function) ->
          Task.start(fn -> apply(module, function, [source, frame, portal]) end)

        receiver ->
          try do
            Kernel.send(receiver, {:bacnet_transport, @protocol, source, frame, portal})
          catch
            :error, :badarg -> :ok
          end
      end
    end
  end
end
