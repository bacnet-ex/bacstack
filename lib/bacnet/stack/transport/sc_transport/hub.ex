if BACstack.MixProject.sc_enabled?() do
  defmodule BACnet.Stack.Transport.ScTransport.Hub do
    @moduledoc """
    The BACnet/SC (Secure Connect) Hub.
    It accepts BACnet/SC hub connections and forwards BVLC traffic.

    This hub implementation should be considered experimental.

    The hub is a listener. A device that sends and receives BACnet application
    traffic starts a `BACnet.Stack.Transport.ScTransport.Node` as its transport.
    That node can use a local `:primary_hub_uri` such as `wss://localhost:4443/`.
    Connect-Accept advertises the listener's `:vmac` and `:device_uuid`. Use
    the same device identity for the listener and its local node.

    This implementation can serve as the primary or failover endpoint. Each
    node assigns those roles through its own hub URIs. The node's
    [implementation scope](`m:BACnet.Stack.Transport.ScTransport.Node#module-implementation-scope`)
    describes the shared security model and current protocol limits.

    To use this hub, you need to run on OTP 27+ and add the [optional dependecies](bacnet_sc.html#dependencies).
    See also the [BACnet/SC page](bacnet_sc.html) for more information.

    ## Listener and admission

    Start the hub under a supervisor with `start_link/1`. Configure the TCP
    `:port`, hub `:vmac`, `:device_uuid`, and operational `:credentials`.
    The bind `:ip` defaults to `{0, 0, 0, 0}`. Supply an IPv6 tuple to bind
    IPv6. The WebSocket `:path` defaults to `"/"`. Set `:port` to `0` to let
    the operating system assign a port and use `port/1` to retrieve it. The hub
    accepts HTTP/1.1 WebSocket upgrades for `hub.bsc.bacnet.org` over mutual
    TLS 1.3. The peer's operational certificate must be valid and directly
    signed by one of the configured site issuers. Set `:crl_check` to enable
    revocation checks.

    For a local test, start the listener on loopback. This example reads the
    hub's enrolled PEM credentials and its saved UUID and VMAC from `sc-site`.
    The [certificate enrollment example](bacnet_sc.html#certificate-enrollment-example)
    shows how to prepare credentials and device identities.

    ```elixir
    alias BACnet.Stack.Transport.ScTransport.Credentials
    alias BACnet.Stack.Transport.ScTransport.Hub

    {:ok, credentials} =
      Credentials.from_pem(
        File.read!("sc-site/hub.pem"),
        File.read!("sc-site/hub-key.pem"),
        [File.read!("sc-site/ca.pem")]
      )

    {:ok, hub} =
      Hub.start_link(
        ip: {127, 0, 0, 1},
        port: 0xBAC0,
        device_uuid: File.read!("sc-site/hub-uuid"),
        vmac: File.read!("sc-site/hub-vmac"),
        credentials: credentials,
        name: Hub
      )
    ```

    An upgraded WebSocket has a connection process that handles BVLC messages,
    heartbeat checks, and disconnect timers. It must complete the Connect
    exchange before it can forward traffic. The hub registers the VMAC and
    Device UUID from Connect-Request. It replaces the older connection when
    the same device registers again. A request for an occupied VMAC from a
    different UUID receives `NODE_DUPLICATE_VMAC` and leaves the current owner
    in place. The hub reserves its own VMAC for its Device UUID before its
    local node connects.

    ## Forwarding and operations

    The hub takes the source VMAC from the sender's registration. It removes
    the destination field for a forwarded unicast and retains it for a
    broadcast. A unicast to an unknown VMAC is dropped. Broadcast forwarding
    includes all other registered nodes. The ingress connection receives no
    reflected copy. Message IDs and options travel with the forwarded frame,
    subject to the receiving peer's advertised limits. The hub drops a frame
    for any recipient whose limits it exceeds. An ingress frame that already
    contains an originating VMAC or lacks a destination on a non-link message
    is dropped. Where a Result is permitted, the hub sends a
    `PARAMETER_OUT_OF_RANGE` NAK to the sender.

    `status/1` reports established peers and up to 32 recent BVLC admission
    failures, newest first. A later failure from the same remote IP replaces
    its earlier entry. A Connect wait timeout is recorded as `TIMEOUT` (30).
    Each peer can have 64 frames awaiting its WebSocket. Further frames for
    that peer are dropped and counted in `status/1` as `egress_drops`.
    `reconfigure/2` updates the listener and retires sessions if the
    operational certificate or CRL policy changes, or a site issuer is
    removed. Issuer additions can keep established sessions in service.
    `restart_connections/1` requests that the peers disconnect while leaving
    the listener available. `close/1` suspends acceptance, waits for sessions
    to disconnect or reach the shutdown deadline, and releases the listener.

    ## Traffic audit

    Pass `:audit` in the hub options to enable the audit stream.
    See `BACnet.Stack.Transport.ScTransport.Audit` for details.
    """

    alias BACnet.Protocol.SecureConnect.BVLC
    alias BACnet.Stack.Transport.ScTransport.Audit
    alias BACnet.Stack.Transport.ScTransport.Config
    alias BACnet.Stack.Transport.ScTransport.Connection
    alias BACnet.Stack.Transport.ScTransport.Credentials

    import BACnet.Internal, only: [log_debug: 1]

    require Logger
    use GenServer

    @audit_counters %{queue_drops: 0, sink_failures: 0, correlation_losses: 0}
    @egress_limit 64

    defmodule Session do
      @moduledoc """
      Tracks a WebSocket and its remote address from the time the hub accepts
      it. After a successful BVLC handshake the hub records the registered
      identity and uses it to route traffic. The monitor removes the entry
      when its connection process exits.
      """

      @typedoc """
      Remote endpoint, connection monitor, and identity learned at registration.
      """
      @type t :: %__MODULE__{
              peer: BVLC.peer() | nil,
              remote: {:inet.ip_address(), :inet.port_number()},
              monitor: reference(),
              connected_at: DateTime.t() | nil,
              certificate_sha256: <<_::256>> | nil
            }

      @fields [:peer, :remote, :monitor, :connected_at, :certificate_sha256]
      @enforce_keys @fields
      defstruct @fields
    end

    defmodule Failure do
      @moduledoc """
      Records an inbound BACnet/SC connection request that the hub could not admit.

      The remote endpoint and BACnet error code are available even when the hub
      cannot determine the peer's identity. In that case the `:peer` field is
      `nil`. The hub retains recent failures by remote IP address.
      """

      @typedoc """
      The remote endpoint, optional peer identity, error code, and timestamp.
      """
      @type t :: %__MODULE__{
              remote: {:inet.ip_address(), :inet.port_number()},
              peer: BVLC.peer() | nil,
              code: non_neg_integer(),
              timestamp: DateTime.t()
            }

      @fields [:remote, :peer, :code, :timestamp]
      @enforce_keys @fields
      defstruct @fields
    end

    defmodule Status do
      @moduledoc """
      Reports the hub's registered peer sessions and recent admission failures.

      Connections are the sessions that completed registration, with the peer
      identity and time of connection. Failures are listed newest first.
      `egress_drops` counts recipient frames dropped since startup when that
      peer already had 64 frames awaiting processing by its WebSocket.
      """

      @typedoc """
      Registered sessions and recent failed inbound connection requests.
      """
      @type t :: %__MODULE__{
              connections: [Session.t()],
              failed: [Failure.t()],
              egress_drops: non_neg_integer()
            }

      @fields [:connections, :failed, :egress_drops]
      @enforce_keys @fields
      defstruct @fields
    end

    defmodule State do
      @moduledoc """
      Owns the hub's listener reference and session registry. All registry
      updates and forwarding decisions run in the hub process. The hub also
      keeps a bounded list of admission failures for BACnet diagnostics.

      During a graceful shutdown, drain waiters share the same disconnect
      deadline. They are released when the last session exits or that
      deadline expires.
      """

      @derive {Inspect, except: [:config]}

      @typedoc """
      Queue bookkeeping for an enabled audit worker.
      """
      @type audit_state :: %{
              worker: pid(),
              epoch: <<_::128>>,
              sequence: non_neg_integer(),
              queued: non_neg_integer(),
              gap?: boolean(),
              tick?: boolean()
            }

      @typedoc """
      Listener configuration, accepted sessions, failure history, and shutdown waiters.
      """
      @type t :: %__MODULE__{
              config: Config.hub_config(),
              listener: reference(),
              listener_monitor: reference(),
              sessions: %{pid() => Session.t()},
              by_vmac: %{BVLC.vmac() => pid()},
              by_uuid: %{<<_::128>> => pid()},
              egress: %{pid() => MapSet.t(reference())},
              egress_drops: non_neg_integer(),
              failed: [Failure.t()],
              drain: [GenServer.from()] | nil,
              admissions_held: boolean(),
              audit: audit_state() | nil,
              audit_counters: %{
                queue_drops: non_neg_integer(),
                sink_failures: non_neg_integer(),
                correlation_losses: non_neg_integer()
              }
            }

      @fields [
        :config,
        :listener,
        :listener_monitor,
        :sessions,
        :by_vmac,
        :by_uuid,
        :egress,
        :egress_drops,
        :failed,
        :drain,
        :admissions_held,
        :audit,
        :audit_counters
      ]
      @enforce_keys @fields
      defstruct @fields
    end

    @doc """
    Starts the hub and binds the TLS listener. Supply `:port`, `:vmac`,
    `:device_uuid`, and `:credentials`. Optional settings include `:ip`,
    `:path`, `:name`, and the connection timers. An IPv6 address tuple in
    `:ip` selects an IPv6 listener. The default address binds IPv4.

    See [Traffic audit](#module-traffic-audit) for the `:audit` option.
    """
    @spec start_link(Config.options()) :: GenServer.on_start()
    def start_link(opts) do
      with :ok <- Config.runtime([:ssl, :cowboy]),
           {:ok, config} <- Config.hub(opts) do
        GenServer.start_link(__MODULE__, config, Keyword.take(opts, [:name]))
      end
    end

    @doc """
    Returns the TCP port bound by the listener. Use this to resolve the
    assigned port when starting the hub with port zero.
    """
    @spec port(GenServer.server()) :: :inet.port_number()
    def port(hub), do: GenServer.call(hub, :port)

    @doc """
    Returns a `BACnet.Stack.Transport.ScTransport.Hub.Status` with the
    registered peer sessions and recent failed connection attempts.
    """
    @spec status(GenServer.server()) :: Status.t()
    def status(hub), do: GenServer.call(hub, :status)

    @doc """
    Returns the status with the audit mode, queued captures,
    and cumulative loss counters.

    Queue drops count captures lost before processing. Sink failures count
    failed publications. Correlation losses account for interrupted or
    ambiguous write tracking and audit worker resets.
    """
    @spec audit_status(GenServer.server()) :: Audit.Status.t()
    def audit_status(hub), do: GenServer.call(hub, :audit_status)

    @doc """
    Checks whether a local node's active hub identity and VMAC match an
    established session on this listener.
    """
    @spec local_connection?(GenServer.server(), BVLC.vmac(), binary(), BVLC.vmac()) :: boolean()
    def local_connection?(hub, local_vmac, hub_uuid, hub_vmac),
      do: GenServer.call(hub, {:local_connection, local_vmac, hub_uuid, hub_vmac})

    @doc """
    Suspends acceptance of new connections, requests disconnection of each
    open session, and waits for the sessions or the disconnect deadline.
    """
    @spec close(GenServer.server()) :: :ok
    def close(hub), do: GenServer.call(hub, :drain, :infinity)

    @doc """
    Updates the TLS listener and WebSocket path for new connections. Sessions
    normally retire when the operational certificate, issuer trust, or CRL
    policy requires a new handshake. Pass `false` to retain existing sessions
    and hold new BACnet/SC admissions until `finish_reconfigure/2` releases them.
    """
    @spec reconfigure(GenServer.server(), Config.options(), boolean()) :: :ok | {:error, term()}
    def reconfigure(hub, opts, retire_sessions? \\ true) do
      with {:ok, config} <- Config.hub(opts),
           do: GenServer.call(hub, {:reconfigure, config, retire_sessions?})
    end

    @doc """
    Releases admissions held during activation and optionally retires the
    existing sessions so they can reconnect with the active settings.
    """
    @spec finish_reconfigure(GenServer.server(), boolean()) :: :ok
    def finish_reconfigure(hub, retire_sessions?),
      do: GenServer.call(hub, {:finish_reconfigure, retire_sessions?})

    @doc """
    Requests graceful disconnection of every session while keeping the
    listener available for incoming connections.
    """
    @spec restart_connections(GenServer.server()) :: :ok
    def restart_connections(hub), do: GenServer.call(hub, :restart_connections)

    @doc false
    def init(config) do
      Process.flag(:trap_exit, true)
      listener = make_ref()
      {hold?, config} = Map.pop(config, :hold_connections, false)

      case start_listener(listener, config) do
        {:ok, pid} ->
          monitor_listener(self(), listener)

          log_debug(fn ->
            "BacScHub: Listening for SC connections on TCP port #{:ranch.get_port(listener)}"
          end)

          {:ok,
           %State{
             config: config,
             listener: listener,
             listener_monitor: Process.monitor(pid),
             sessions: %{},
             by_vmac: %{},
             by_uuid: %{},
             egress: %{},
             egress_drops: 0,
             failed: [],
             drain: nil,
             admissions_held: hold?,
             audit: start_audit(config.audit),
             audit_counters: @audit_counters
           }}

        {:error, reason} ->
          log_debug(fn -> "BacScHub: Could not start the listener on TCP port #{config.port}" end)
          {:stop, reason}
      end
    end

    @doc false
    def handle_call(:port, _from, state) do
      log_debug("BacScHub: Received listener port request")
      {:reply, :ranch.get_port(state.listener), state}
    end

    def handle_call({:local_connection, local_vmac, hub_uuid, hub_vmac}, _from, state) do
      log_debug("BacScHub: Received local connection lookup")

      local? =
        state.config.device_uuid == hub_uuid and state.config.vmac == hub_vmac and
          match?(%{peer: %{uuid: ^hub_uuid}}, state.sessions[state.by_vmac[local_vmac]])

      {:reply, local?, state}
    end

    def handle_call(:drain, from, %State{drain: waiters} = state) when is_list(waiters) do
      log_debug("BacScHub: Received another drain request while closing")
      {:noreply, %{state | drain: [from | waiters]}}
    end

    def handle_call(:drain, from, state) do
      log_debug("BacScHub: Draining the listener and its connections")
      :ok = :ranch.suspend_listener(state.listener)

      if map_size(state.sessions) == 0 do
        {:stop, :normal, :ok, state}
      else
        Enum.each(state.sessions, fn {pid, _session} -> Connection.disconnect(pid) end)

        Process.send_after(
          self(),
          :drain_timeout,
          :timer.seconds(state.config.disconnect_wait_timeout + 1)
        )

        {:noreply, %{state | drain: [from]}}
      end
    end

    def handle_call(:restart_connections, _from, state) do
      log_debug("BacScHub: Received session restart request")
      Enum.each(state.sessions, fn {pid, _session} -> Connection.disconnect(pid) end)
      {:reply, :ok, state}
    end

    def handle_call(:status, _from, state) do
      log_debug("BacScHub: Received status request")

      peers =
        for {_pid, %Session{peer: peer} = session} <- state.sessions, peer, do: session

      {:reply,
       %Status{connections: peers, failed: state.failed, egress_drops: state.egress_drops}, state}
    end

    def handle_call(:audit_status, _from, state) do
      counters = state.audit_counters

      status = %Audit.Status{
        mode: if(state.config.audit, do: state.config.audit.mode, else: :disabled),
        queued: if(state.audit, do: state.audit.queued, else: 0),
        queue_drops: counters.queue_drops,
        sink_failures: counters.sink_failures,
        correlation_losses: counters.correlation_losses
      }

      {:reply, status, state}
    end

    def handle_call(
          {:attach, _socket, _remote, _fingerprint},
          _from,
          %State{drain: drain} = state
        )
        when is_list(drain) do
      log_debug("BacScHub: Refused a WebSocket while closing")
      {:reply, {:error, :hub_closing}, state}
    end

    def handle_call(
          {:attach, _socket, _remote, _fingerprint},
          _from,
          %State{admissions_held: true} = state
        ) do
      log_debug("BacScHub: Refused a WebSocket during reconfiguration")
      {:reply, {:error, :hub_reconfiguring}, state}
    end

    def handle_call({:attach, socket, remote, fingerprint}, _from, state) do
      case Connection.start(self(), {:server, socket}, Map.delete(state.config, :audit)) do
        {:ok, pid} ->
          log_debug(fn -> "BacScHub: Accepted a WebSocket from #{inspect(remote)}" end)

          session = %Session{
            peer: nil,
            remote: remote,
            monitor: Process.monitor(pid),
            connected_at: nil,
            certificate_sha256: fingerprint
          }

          {:reply, {:ok, pid}, put_in(state.sessions[pid], session)}

        {:error, reason} ->
          log_debug("BacScHub: Could not start a session for the accepted WebSocket")
          {:reply, {:error, reason}, state}
      end
    end

    def handle_call({:register, pid, peer}, _from, %State{admissions_held: true} = state) do
      log_debug("BacScHub: Refused registration during reconfiguration")
      code = BVLC.error_code(:operational_problem)
      {:reply, {:error, code}, record_failure(state, state.sessions[pid], peer, code)}
    end

    def handle_call({:register, pid, peer}, _from, state) do
      occupant = state.sessions[state.by_vmac[peer.vmac]]
      occupied? = occupant != nil and occupant.peer.uuid != peer.uuid
      reserved? = peer.vmac == state.config.vmac and peer.uuid != state.config.device_uuid

      if reserved? or occupied? do
        code = BVLC.error_code(:node_duplicate_vmac)
        {:reply, {:error, code}, record_failure(state, state.sessions[pid], peer, code)}
      else
        state = retire_replaced_session(state, state.by_uuid[peer.uuid])
        session = %{state.sessions[pid] | peer: peer, connected_at: DateTime.utc_now()}

        log_debug(fn ->
          "BacScHub: Registered #{describe_peer(session.remote, peer)}"
        end)

        {:reply, :ok,
         %{
           state
           | sessions: Map.put(state.sessions, pid, session),
             by_vmac: Map.put(state.by_vmac, peer.vmac, pid),
             by_uuid: Map.put(state.by_uuid, peer.uuid, pid)
         }}
      end
    end

    def handle_call({:set_vmac, vmac}, _from, state) do
      log_debug(fn -> "BacScHub: Setting the listener VMAC to #{Base.encode16(vmac)}" end)
      {:reply, :ok, put_in(state.config.vmac, vmac)}
    end

    def handle_call({:reconfigure, config, retire_sessions?}, _from, state) do
      log_debug("BacScHub: Received listener reconfigure request")

      case reconfigure_listener(state.listener, state.config, config) do
        :ok ->
          if retire_sessions? and
               (state.config.crl_check != config.crl_check or
                  reconnect_required?(state.config.credentials, config.credentials)) do
            log_debug(
              "BacScHub: Retiring sessions after a change to the TLS credentials or policy"
            )

            Enum.each(state.sessions, fn {pid, _session} -> Connection.disconnect(pid) end)
          end

          state =
            if config.audit == state.config.audit do
              state
            else
              reset_audit(state, config.audit)
            end

          {:reply, :ok, %{state | config: config, admissions_held: not retire_sessions?}}

        error ->
          {:reply, error, state}
      end
    end

    def handle_call({:finish_reconfigure, retire_sessions?}, _from, state) do
      log_debug("BacScHub: Finishing listener reconfiguration")

      if retire_sessions? do
        Enum.each(state.sessions, fn {pid, _session} -> Connection.disconnect(pid) end)
      end

      {:reply, :ok, %{state | admissions_held: false}}
    end

    def handle_call({:route, ingress, frame}, _from, state) do
      case Map.get(state.sessions, ingress) do
        %Session{peer: %{vmac: _vmac}} = session ->
          {state, decision, destination} = route(state, ingress, session, frame)
          {:reply, :ok, observe_route(state, session, destination, frame, decision)}

        _stale ->
          log_debug("BacScHub: Ignored a route request from an unregistered session")
          {:reply, :ok, state}
      end
    end

    @doc false
    def handle_info({:sc_egress_done, pid, credit}, state) do
      case Map.fetch(state.egress, pid) do
        {:ok, credits} ->
          remaining = MapSet.delete(credits, credit)

          egress =
            if MapSet.size(remaining) == 0,
              do: Map.delete(state.egress, pid),
              else: Map.put(state.egress, pid, remaining)

          {:noreply, %{state | egress: egress}}

        :error ->
          {:noreply, state}
      end
    end

    def handle_info(
          {:sc_audit_complete, worker, kind, failures, losses},
          %{audit: %{worker: worker}} = state
        ) do
      audit =
        case kind do
          :capture -> Map.update!(state.audit, :queued, &(&1 - 1))
          :tick -> %{state.audit | tick?: false}
          :gap -> state.audit
        end

      counters = state.audit_counters

      counters = %{
        counters
        | sink_failures: counters.sink_failures + failures,
          correlation_losses: counters.correlation_losses + losses
      }

      {:noreply, %{state | audit: audit, audit_counters: counters}}
    end

    def handle_info({:sc_audit_tick, worker}, %{audit: %{worker: worker}} = state) do
      schedule_audit_tick(worker)

      if state.audit.queued == 0 and not state.audit.tick? do
        GenServer.cast(worker, {:tick, System.monotonic_time(:millisecond)})
        {:noreply, put_in(state.audit.tick?, true)}
      else
        {:noreply, state}
      end
    end

    def handle_info({:EXIT, worker, _reason}, %{audit: %{worker: worker}} = state) do
      Logger.warning("BacScHub: Audit worker exited; restarting capture")
      {:noreply, reset_audit(state, state.config.audit)}
    end

    @doc false
    def handle_info({:sc_connection, pid, {:connect_failed, code}}, state) do
      log_debug(fn -> "BacScHub: Received a Connect failure from session #{inspect(pid)}" end)
      {:noreply, record_connect_failure(state, pid, code)}
    end

    def handle_info({:sc_connection, pid, {:closed, :connect_timeout}}, state) do
      log_debug(fn -> "BacScHub: Received a connect timeout from session #{inspect(pid)}" end)
      {:noreply, record_connect_failure(state, pid, BVLC.error_code(:timeout))}
    end

    def handle_info(
          {:DOWN, monitor, :process, _pid, reason},
          %{listener_monitor: monitor} = state
        ) do
      log_debug("BacScHub: The listener stopped")
      {:stop, {:hub_listener_closed, reason}, state}
    end

    def handle_info({:DOWN, monitor, :process, pid, _reason}, state) do
      case state.sessions do
        %{^pid => %{monitor: ^monitor} = session} ->
          log_debug(fn ->
            "BacScHub: Disconnected #{describe_peer(session.remote, session.peer)}"
          end)

          state = forget_peer(state, session.peer)

          state = %{
            state
            | sessions: Map.delete(state.sessions, pid),
              egress: Map.delete(state.egress, pid)
          }

          if map_size(state.sessions) == 0, do: finish_drain(state), else: {:noreply, state}

        _other ->
          log_debug("BacScHub: Ignored a stale session monitor event")
          {:noreply, state}
      end
    end

    def handle_info(:drain_timeout, state) do
      log_debug("BacScHub: Listener drain timed out")
      finish_drain(state)
    end

    def handle_info(_message, state) do
      log_debug("BacScHub: Ignored an unrecognized or stale message")
      {:noreply, state}
    end

    @spec record_connect_failure(State.t(), pid(), non_neg_integer()) :: State.t()
    defp record_connect_failure(state, pid, code) do
      case Map.get(state.sessions, pid) do
        %{peer: nil} = session ->
          record_failure(state, session, nil, code)

        _other ->
          log_debug("BacScHub: Ignored a failure from a session that is no longer waiting")
          state
      end
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
      if state.audit, do: Process.exit(state.audit.worker, :kill)
      log_debug("BacScHub: Closing the TLS listener")
      :cowboy.stop_listener(state.listener)
    end

    @spec finish_drain(State.t()) :: {:noreply, State.t()} | {:stop, :normal, State.t()}
    defp finish_drain(%State{drain: waiters} = state) when is_list(waiters) do
      Enum.each(waiters, &GenServer.reply(&1, :ok))
      {:stop, :normal, state}
    end

    defp finish_drain(state), do: {:noreply, state}

    @spec start_listener(reference(), Config.hub_config()) :: {:ok, pid()} | {:error, term()}
    defp start_listener(listener, config) do
      with {:ok, dispatch} <- compile_dispatch(config.path) do
        :cowboy.start_tls(listener, transport_options(config), %{
          protocols: [:http],
          env: %{dispatch: dispatch}
        })
      end
    end

    @spec compile_dispatch(String.t()) :: {:ok, term()} | {:error, :invalid_hub_path}
    defp compile_dispatch(path) do
      {:ok, :cowboy_router.compile([{:_, [{path, __MODULE__.WebSocket, self()}]}])}
    rescue
      _error -> {:error, :invalid_hub_path}
    end

    @spec reconfigure_listener(reference(), Config.hub_config(), Config.hub_config()) ::
            :ok | {:error, term()}
    defp reconfigure_listener(listener, %{path: path} = old, %{path: path} = new),
      do: replace_tls(listener, old, new)

    defp reconfigure_listener(listener, old, new) do
      with {:ok, dispatch} <- compile_dispatch(new.path),
           :ok <- replace_tls(listener, old, new) do
        :cowboy.set_env(listener, :dispatch, dispatch)
      end
    end

    @spec transport_options(Config.hub_config()) :: %{
            socket_opts: Keyword.t(),
            handshake_timeout: pos_integer()
          }
    defp transport_options(config) do
      ip = Map.get(config, :ip, {0, 0, 0, 0})
      family = if tuple_size(ip) == 8, do: :inet6, else: :inet
      socket_opts = [family, port: config.port, ip: ip]

      %{
        socket_opts: socket_opts ++ Credentials.tls(config, :server),
        handshake_timeout: :timer.seconds(config.connect_wait_timeout)
      }
    end

    @spec replace_tls(reference(), Config.hub_config(), Config.hub_config()) ::
            :ok | {:error, term()}
    defp replace_tls(
           _listener,
           %{credentials: credentials} = old,
           %{credentials: credentials} = new
         )
         when old.port == new.port and old.connect_wait_timeout == new.connect_wait_timeout and
                :erlang.map_get(:ip, old) == :erlang.map_get(:ip, new) and
                old.crl_check == new.crl_check,
         do: :ok

    defp replace_tls(listener, old, config) do
      port = :ranch.get_port(listener)
      old = if old.port == 0, do: %{old | port: port}, else: old
      config = if config.port == 0, do: %{config | port: port}, else: config

      original = :ranch.get_transport_options(listener)

      original =
        Map.update!(original, :socket_opts, fn options ->
          {families, keywords} = Enum.split_with(options, &(&1 in [:inet, :inet6]))
          families ++ Keyword.put(keywords, :port, old.port)
        end)

      next =
        config
        |> transport_options()
        |> update_in([:socket_opts], fn [family | options] ->
          existing = Enum.reject(original.socket_opts, &(&1 in [:inet, :inet6]))
          [family | Keyword.merge(existing, options)]
        end)
        |> then(&Map.merge(original, &1))

      with :ok <- :ranch.suspend_listener(listener),
           :ok <- :ranch.set_transport_options(listener, next),
           :ok <- :ranch.resume_listener(listener) do
        :ok
      else
        {:error, _reason} = error ->
          with :ok <- :ranch.set_transport_options(listener, original),
               :ok <- :ranch.resume_listener(listener) do
            error
          else
            _failed -> exit(:sc_listener_rollback_failed)
          end
      end
    end

    @doc """
    Checks whether existing sessions must renegotiate after a credential change.
    """
    @spec reconnect_required?(Credentials.t(), Credentials.t()) :: boolean()
    def reconnect_required?(old, new) do
      old.cert != new.cert or Enum.any?(old.issuers, &(&1 not in new.issuers))
    end

    @spec monitor_listener(pid(), reference()) :: pid()
    defp monitor_listener(hub, listener) do
      spawn(fn ->
        monitor = Process.monitor(hub)

        receive do
          {:DOWN, ^monitor, :process, ^hub, _reason} -> :cowboy.stop_listener(listener)
        end
      end)
    end

    @spec retire_replaced_session(State.t(), pid() | nil) :: State.t()
    defp retire_replaced_session(state, nil), do: state

    defp retire_replaced_session(state, pid) do
      session = state.sessions[pid]

      log_debug(fn ->
        "BacScHub: Replacing the session from #{describe_peer(session.remote, session.peer)}"
      end)

      Connection.disconnect(pid)
      state = forget_peer(state, session.peer)
      put_in(state.sessions[pid].peer, nil)
    end

    @spec forget_peer(State.t(), BVLC.peer() | nil) :: State.t()
    defp forget_peer(state, nil), do: state

    defp forget_peer(state, peer) do
      %{
        state
        | by_vmac: Map.delete(state.by_vmac, peer.vmac),
          by_uuid: Map.delete(state.by_uuid, peer.uuid)
      }
    end

    @spec route(State.t(), pid(), Session.t(), BVLC.t()) ::
            {State.t(), Audit.Event.routing(), Session.t() | nil}
    defp route(state, ingress, session, %BVLC{source: address} = frame)
         when not is_nil(address) do
      log_debug(fn ->
        "BacScHub: Dropped #{frame.function} message #{frame.id} from " <>
          "#{describe_peer(session.remote, session.peer)} containing a source VMAC"
      end)

      response = BVLC.nak(%{frame | source: nil}, BVLC.error_code(:parameter_out_of_range))
      {state, _queued} = queue_frame(state, ingress, response)

      {state, :invalid_source, nil}
    end

    defp route(state, ingress, session, %BVLC{destination: nil} = frame) do
      log_debug(fn ->
        "BacScHub: Dropped #{frame.function} message #{frame.id} from " <>
          "#{describe_peer(session.remote, session.peer)} with no destination VMAC"
      end)

      response = BVLC.nak(frame, BVLC.error_code(:parameter_out_of_range))
      {state, _queued} = queue_frame(state, ingress, response)

      {state, :missing_destination, nil}
    end

    defp route(state, ingress, session, %BVLC{destination: destination} = frame) do
      broadcast? = destination == BVLC.broadcast()
      unicast = state.by_vmac[destination]
      recipients = if broadcast?, do: Map.values(state.by_vmac), else: List.wrap(unicast)

      forwarded = %{
        frame
        | source: session.peer.vmac,
          destination: if(broadcast?, do: destination)
      }

      {updated, queued} =
        Enum.reduce(recipients, {state, 0}, fn
          ^ingress, result ->
            result

          pid, {state, count} ->
            {state, added} = queue_frame(state, pid, forwarded)
            {state, count + added}
        end)

      dropped = updated.egress_drops - state.egress_drops
      target = if queued == 1 and unicast, do: state.sessions[unicast]

      log_debug(fn ->
        "BacScHub: Routed #{frame.function} message #{frame.id} from " <>
          "#{describe_peer(session.remote, session.peer)} to VMAC #{Base.encode16(destination)} " <>
          "(queued #{queued}, queue drops #{dropped})"
      end)

      decision =
        case {queued, dropped} do
          {0, 0} -> :no_recipient
          {0, _dropped} -> :egress_queue_full
          {queued, 0} -> {:queued, queued}
          {queued, dropped} -> {:partially_queued, queued, dropped}
        end

      {updated, decision, target}
    end

    @spec queue_frame(State.t(), pid(), BVLC.t() | nil) :: {State.t(), 0 | 1}
    defp queue_frame(state, _pid, nil), do: {state, 0}

    defp queue_frame(state, pid, frame) do
      credits = Map.get_lazy(state.egress, pid, &MapSet.new/0)

      if MapSet.size(credits) < @egress_limit do
        credit = make_ref()
        Connection.forward(pid, frame, credit)
        {put_in(state.egress[pid], MapSet.put(credits, credit)), 1}
      else
        {%{state | egress_drops: state.egress_drops + 1}, 0}
      end
    end

    @spec start_audit(Audit.config() | nil, boolean()) :: State.audit_state() | nil
    defp start_audit(config, paused? \\ false)
    defp start_audit(nil, _paused?), do: nil

    defp start_audit(config, paused?) do
      {:ok, worker} = Audit.start_link({self(), config, paused?})
      schedule_audit_tick(worker)

      %{
        worker: worker,
        epoch: :crypto.strong_rand_bytes(16),
        sequence: 0,
        queued: 0,
        gap?: false,
        tick?: false
      }
    end

    defp schedule_audit_tick(worker),
      do: Process.send_after(self(), {:sc_audit_tick, worker}, 1000)

    defp reset_audit(%{audit: nil} = state, config),
      do: %{state | audit: start_audit(config)}

    defp reset_audit(state, config) do
      Process.exit(state.audit.worker, :kill)
      counters = state.audit_counters

      counters = %{
        counters
        | queue_drops: counters.queue_drops + state.audit.queued,
          correlation_losses: counters.correlation_losses + 1
      }

      %{state | audit: start_audit(config, true), audit_counters: counters}
    end

    defp observe_route(%{audit: nil} = state, _source, _target, _frame, _decision), do: state

    defp observe_route(
           %{config: %{audit: %{mode: :writes}}} = state,
           _source,
           _target,
           %BVLC{function: function},
           _decision
         )
         when function != :npdu, do: state

    defp observe_route(%{audit: audit} = state, source, target, frame, decision) do
      sequence = audit.sequence + 1

      if audit.queued < state.config.audit.queue_limit do
        observation = %{
          capture_id: {audit.epoch, sequence},
          timestamp: DateTime.utc_now(),
          monotonic_time: System.monotonic_time(:millisecond),
          hub: %{uuid: state.config.device_uuid, vmac: state.config.vmac},
          ingress: audit_peer(source),
          ingress_session: source.monitor,
          egress: audit_peer(target),
          egress_session: if(target, do: target.monitor),
          destination_vmac: frame.destination,
          routing: decision,
          frame: frame
        }

        GenServer.cast(audit.worker, {:capture, observation})
        %{state | audit: %{audit | queued: audit.queued + 1, gap?: false, sequence: sequence}}
      else
        if not audit.gap?, do: GenServer.cast(audit.worker, :gap)
        state = update_in(state.audit_counters.queue_drops, &(&1 + 1))
        %{state | audit: %{audit | gap?: true, sequence: sequence}}
      end
    end

    defp audit_peer(nil), do: nil

    defp audit_peer(session) do
      %{
        uuid: session.peer.uuid,
        vmac: session.peer.vmac,
        remote: session.remote,
        certificate_sha256: session.certificate_sha256
      }
    end

    @spec describe_peer({:inet.ip_address(), :inet.port_number()}, BVLC.peer() | nil) ::
            String.t()
    defp describe_peer(remote, nil), do: inspect(remote)

    defp describe_peer(remote, peer) do
      "VMAC #{Base.encode16(peer.vmac)} (Device UUID #{Base.encode16(peer.uuid)}) at #{inspect(remote)}"
    end

    @spec record_failure(State.t(), Session.t(), BVLC.peer() | nil, non_neg_integer()) ::
            State.t()
    defp record_failure(state, session, peer, code) do
      log_debug(fn ->
        "BacScHub: Connection from #{describe_peer(session.remote, peer)} failed with BACnet error code #{code}"
      end)

      failure = %Failure{
        remote: session.remote,
        peer: peer,
        code: code,
        timestamp: DateTime.utc_now()
      }

      {ip, _port} = session.remote

      earlier =
        Enum.reject(state.failed, fn %{remote: {peer_ip, _peer_port}} -> peer_ip == ip end)

      %{state | failed: Enum.take([failure | earlier], 32)}
    end

    defmodule WebSocket do
      @moduledoc """
      Adapts Cowboy WebSocket callbacks to an inbound BACnet/SC connection.

      The handler negotiates the hub subprotocol and forwards WebSocket events
      to the associated session process. The session handles the BACnet/SC
      handshake, message validation, and timeouts. The handler owns the socket
      and closes it when the session exits.
      """

      import BACnet.Internal, only: [log_debug: 1]

      @doc false
      @spec init(map(), pid()) ::
              {:cowboy_websocket, map(),
               {pid(), {:inet.ip_address(), :inet.port_number()}, binary() | nil}, map()}
              | {:ok, map(), pid()}
      def init(req, hub) do
        protocol = Connection.subprotocol()
        offered = :cowboy_req.parse_header("sec-websocket-protocol", req, [])

        log_debug(fn ->
          "BacScHubWS: Incoming request from " <>
            inspect(:cowboy_req.peer(req)) <>
            " with protocols " <>
            inspect(offered) <>
            " (expected: " <> protocol <> ")"
        end)

        if protocol in offered do
          req = :cowboy_req.set_resp_header("sec-websocket-protocol", protocol, req)

          options = %{
            compress: false,
            idle_timeout: :infinity,
            max_frame_size: Connection.websocket_limit()
          }

          fingerprint =
            case :cowboy_req.cert(req) do
              cert when is_binary(cert) -> :crypto.hash(:sha256, cert)
              :undefined -> nil
            end

          {:cowboy_websocket, req, {hub, :cowboy_req.peer(req), fingerprint}, options}
        else
          {:ok, :cowboy_req.reply(400, req), hub}
        end
      end

      @doc false
      @spec websocket_init(
              {pid(), {:inet.ip_address(), :inet.port_number()}}
              | {pid(), {:inet.ip_address(), :inet.port_number()}, binary() | nil}
            ) ::
              {:ok, {pid(), reference()}} | {:stop, nil}
      def websocket_init({hub, remote}), do: websocket_init({hub, remote, nil})

      def websocket_init({hub, remote, fingerprint}) do
        log_debug(fn -> "BacScHubWS: Initializing websocket for " <> inspect(remote) end)

        case GenServer.call(hub, {:attach, self(), remote, fingerprint}) do
          {:ok, session} -> {:ok, {session, Process.monitor(session)}}
          {:error, _reason} -> {:stop, nil}
        end
      end

      @doc false
      @spec websocket_handle(term(), term()) :: term()
      def websocket_handle(frame, {session, _monitor} = state) do
        send(session, {:sc_websocket, self(), frame})
        {:ok, state}
      end

      @doc false
      @spec websocket_info(term(), term()) :: term()
      def websocket_info({:sc_send, frame}, state), do: {[frame], state}

      def websocket_info({:sc_forward, session, frame, hub, credit}, {session, _monitor} = state) do
        # Cowboy processes the returned send command before the next WebSocket callback.
        send(self(), {:sc_forwarded, hub, credit})
        {[frame], state}
      end

      def websocket_info({:sc_forwarded, hub, credit}, {session, _monitor} = state) do
        send(hub, {:sc_egress_done, session, credit})
        {:ok, state}
      end

      def websocket_info({:DOWN, monitor, :process, pid, _reason}, {pid, monitor} = state),
        do: {:stop, state}

      def websocket_info(_message, state), do: {:ok, state}
    end
  end
end
