if BACstack.MixProject.sc_enabled?() do
  defmodule BACnet.Stack.Transport.ScTransport.ManagedPort do
    @moduledoc """
    A Managed Port is a process that owns a BACnet Secure Connect node,
    its management client, and an optional hub.

    Add the port to a supervisor with `start_link/1`. It owns the transport,
    the BACnet client, and the processes used to send and receive segmented
    messages. Use `endpoints/1` to obtain the active client,
    node, and optional hub for local integration. If hub capability is
    configured, the device still participates in the network through its
    node session, which can connect to its own hub listener. The node's
    [implementation scope](`m:BACnet.Stack.Transport.ScTransport.Node#module-implementation-scope`)
    describes the shared security model and current protocol limits.

    To use this managed port, you need to run on OTP 27+ and add the [optional dependecies](bacnet_sc.html#dependencies).
    See also the [BACnet/SC page](bacnet_sc.html) for more information.

    ## Startup options

    - `:mode` defaults to `:standalone`. Standalone mode creates a Device,
      an SC Network Port, and four File objects. Supply `:device_instance`,
      `:port_instance`, `:vendor_id`, and `:file_instances` with distinct
      instances for `:operational`, `:issuer_1`, `:issuer_2`, and `:csr`.
      Hosted mode takes `:host` and `:objects` and derives those values
      from the supplied objects.
    - `:storage_dir` is required in both modes. The port uses a private
      directory whose parent must already exist.
    - `:certificate_pem`, `:private_key_pem`, and `:issuer_pems` supply locally
      enrolled credentials on first boot. Later starts load the snapshot.
    - `:transport` supplies node options. In standalone mode it can set the
      initial hub URIs, timers, VMAC, and Device UUID. In hosted mode the host
      objects supply those values. Either mode can set TLS options and
      `:ip_family` here.
    - `:hub` supplies the local listener binding when the port is hub-capable.
      Omit it for a node-only port. In standalone mode the listener starts
      enabled unless `enabled: false` is supplied. In hosted mode the Network
      Port determines whether the listener starts enabled. Set `:audit` here
      to enable auditing for the local hub.
      See `BACnet.Stack.Transport.ScTransport.Audit` for details.
    - `:authorize` is an optional two-argument function. It receives the
      decoded service and `%{vmac: vmac, source: source}`. See the access
      rules below.

    ## Persistent settings

    The versioned snapshot saves the UUID, the current configuration, staged
    settings and uploads, and private key material. The service writes it
    using atomic replacement and owner-only permissions before acknowledging
    changes. On restart the snapshot supplies the active settings and
    restores pending changes. Keep the directory in durable, access-controlled
    storage to preserve the device's identity and enrollment.

    ## Integration with an object execution host

    Set `mode: :hosted` when the application already owns the BACnet
    Device, Network Port, and File objects. Supply the host's process or
    registered name as `:host` and the current objects as `:objects`.
    The Device must have a valid Device UUID. The local Network Port
    must use SC at the BACnet application protocol level, support Command
    execution, and reference the four stream-access Files. Supply the
    private storage and bootstrap credentials as in standalone mode. The
    host's objects provide the initial SC settings, VMAC, and File instance
    numbers. For a hub-capable port, pass the local listener binding as
    `:hub`. The Network Port provides the hub enable setting and accept URIs.

    The port's client delivers its BACnet notifications to the host.
    The host answers discovery and dispatches services for the whole device.
    Call `handle_request/3` to delegate a confirmed request on this SC
    client. Call `refresh_objects/2` after startup or to include live SC
    values in the host's own reads, including a ReadPropertyMultiple
    request that mixes SC objects with other objects.

    Call these functions from the configured host process. Pass the current
    objects and retain the returned objects before processing the next
    operation. If delegation returns `:unhandled`, the host handles the
    request and sends the reply. This includes ReadPropertyMultiple requests
    that target a mix of managed and other objects.

    Refreshing projects the persisted SC settings and File metadata onto the
    host objects. The snapshot takes precedence for managed properties and
    their staged values. Stage SC changes through the managed port so the host
    and snapshot agree. Delegated mutations with stale settings return
    `{:error, :refresh_required}`. Refresh and retain the returned objects
    before retrying the mutation.

    ## BACnet services and access

    - In standalone mode, the port answers Who-Is with I-Am when its instance
      is in range. In hosted mode the host answers discovery.
    - ReadProperty and ReadPropertyMultiple expose the managed objects. These
      services are allowed without consulting `:authorize`.
    - WriteProperty stages supported settings and runs supported Network Port
      commands. AtomicReadFile and AtomicWriteFile provide stream access to the
      certificate Files. ReinitializeDevice supports activation and warm restart.

    All other supported confirmed services require `:authorize` to return
    exactly `true`. A missing callback, any other return, or an exception,
    exit, or throw from the callback denies access. The node authenticates the hub during
    TLS. The address map contains the originating VMAC supplied by that hub
    and the routed NPCI source when present.

    The Protocol Revision 24 SC Network Port reports the live VMAC, hub URIs,
    timers, connector status, and certificate references. A hub-capable port
    also reports listener and peer diagnostics. `:sc_hub_function_binding`
    is a read-only decimal TCP port string. It reports the bound port while
    the listener is running. `:sc_hub_function_accept_uris` is stored and
    exposed through BACnet. Configure the TCP listener with `:hub`.

    ## Certificate rotation and activation

    Generate a CSR on the device and retrieve it from the read-only CSR File
    for signing. Upload the signed operational certificate and any issuer
    changes to the writable File objects. A staged upload takes effect after
    activation validates its format, validity interval, issuer signature,
    and key match where applicable. Two issuer slots allow the existing and
    replacement issuers to overlap while devices are being enrolled. After
    every peer trusts the replacement issuer and has a suitable certificate,
    activate a change that removes the old issuer.

    Activation validates the proposed settings, prepares the listener, and
    saves the new snapshot before queuing the SimpleACK over the current
    connection. Preparation or persistence errors leave changes pending. If
    queuing the reply fails, the port restores the previous snapshot and
    listener configuration and retains the pending changes. Once the reply
    is queued, the port applies the new runtime and retires affected sessions.
    Removing an issuer forces affected peers through a new TLS handshake.

    For offline maintenance use `activate/1` in standalone mode or `activate/2`
    in hosted mode. These local calls return the activation result directly.
    """

    alias BACnet.Protocol.APDU
    alias BACnet.Protocol.BACnetArray
    alias BACnet.Protocol.Device.ObjectTypesSupported
    alias BACnet.Protocol.Device.ServicesSupported
    alias BACnet.Protocol.ObjectExecution.Context
    alias BACnet.Protocol.ObjectExecution.Lifecycle
    alias BACnet.Protocol.ObjectIdentifier
    alias BACnet.Protocol.ObjectsUtility
    alias BACnet.Protocol.ObjectTypes.Device
    alias BACnet.Protocol.ObjectTypes.File
    alias BACnet.Protocol.ObjectTypes.NetworkPort
    alias BACnet.Protocol.SecureConnect.BVLC
    alias BACnet.Protocol.Services.IAm
    alias BACnet.Protocol.Services.WhoIs
    alias BACnet.Stack.Client
    alias BACnet.Stack.Segmentator
    alias BACnet.Stack.SegmentsStore
    alias BACnet.Stack.Transport.ScTransport.Activation
    alias BACnet.Stack.Transport.ScTransport.Audit
    alias BACnet.Stack.Transport.ScTransport.Config
    alias BACnet.Stack.Transport.ScTransport.Hosted
    alias BACnet.Stack.Transport.ScTransport.Hub
    alias BACnet.Stack.Transport.ScTransport.Management
    alias BACnet.Stack.Transport.ScTransport.Node
    alias BACnet.Stack.Transport.ScTransport.Objects
    alias BACnet.Stack.Transport.ScTransport.Store

    use GenServer

    @files [:operational, :issuer_1, :issuer_2, :csr]

    @typedoc """
    A BACnet File object slot used by the managed port. The operational and
    issuer slots hold certificates. The CSR slot exposes the generated request.
    """
    @type file_role :: :operational | :issuer_1 | :issuer_2 | :csr

    @typedoc """
    Standalone mode owns the managed objects. Hosted mode uses the objects
    supplied by the application that handles BACnet requests.
    """
    @type mode :: :standalone | :hosted

    @typedoc """
    The host's Device, SC Network Port, and referenced certificate Files.
    File roles identify which object carries each certificate or CSR.
    """
    @type host_objects :: %{
            device: Device.t(),
            port: NetworkPort.t(),
            files: %{
              operational: File.t(),
              issuer_1: File.t(),
              issuer_2: File.t(),
              csr: File.t()
            }
          }

    @typedoc """
    A confirmed BACnet request notification from the managed port's client.
    The reference identifies the reply route within that client.
    """
    @type request_notification ::
            {:bacnet_client, reference(), APDU.ConfirmedServiceRequest.t(),
             {BVLC.vmac(), BACnet.Protocol.bvlc(), BACnet.Protocol.NPCI.t()}, pid()}

    @typedoc """
    The persisted settings, staged writes, credential files, and Device UUID
    of the managed port. This internal value contains private key material.
    """
    @type snapshot :: %{
            transport: Keyword.t(),
            hub: Keyword.t() | nil,
            files: %{file_role() => non_neg_integer()},
            active: map(),
            pending: map(),
            certificates: %{operational: binary(), issuer_1: binary(), issuer_2: binary()},
            uploads: %{file_role() => binary()},
            file_dates: %{file_role() => BACnet.Protocol.BACnetDateTime.t()},
            upload_dates: %{file_role() => BACnet.Protocol.BACnetDateTime.t()},
            active_key: binary(),
            csr: binary(),
            csr_key: binary() | nil,
            activation: :in_progress | nil
          }

    @typedoc """
    Validated node and optional hub options derived from a snapshot, together
    with the private key that corresponds to the operational certificate.
    """
    @type runtime_config :: %{node: Keyword.t(), hub: Keyword.t() | nil, key: binary()}

    defmodule State do
      @moduledoc """
      Holds the durable snapshot and the processes that handle traffic for
      the managed port. In standalone mode it retains the Device and Network
      Port. In hosted mode the object fields are populated only while a
      request uses the objects supplied by the host.

      The node, client, and segmentation workers run for the lifetime of the
      port. The hub reference follows the active hub configuration. The
      authorization function evaluates requests against the site's policy.
      """

      alias BACnet.Stack.Transport.ScTransport.ManagedPort

      @derive {Inspect, except: [:snapshot, :runtime, :authorize, :hub_audit]}

      @typedoc """
      Managed objects, persisted configuration, owned endpoints, and authorization policy.
      """
      @type t :: %__MODULE__{
              path: Path.t(),
              snapshot: ManagedPort.snapshot(),
              runtime: ManagedPort.runtime_config(),
              device: Device.t() | nil,
              port: NetworkPort.t() | nil,
              files: %{ManagedPort.file_role() => File.t()} | nil,
              hosted: Hosted.t() | nil,
              hub: pid() | nil,
              node: pid(),
              client: pid(),
              store: pid(),
              segmentator: pid(),
              authorize: (struct(), map() -> term()) | nil,
              hub_audit: Keyword.t() | nil
            }

      @fields [
        :path,
        :snapshot,
        :runtime,
        :device,
        :port,
        :files,
        :hosted,
        :hub,
        :node,
        :client,
        :store,
        :segmentator,
        :authorize,
        :hub_audit
      ]
      @enforce_keys @fields
      defstruct @fields
    end

    @typedoc """
    Internal state passed between the managed port and its BACnet request handler.
    """
    @type state :: State.t()

    @doc """
    Starts a managed port linked to the caller. On the first start it validates
    and persists the bootstrap settings. On later starts it loads the snapshot
    before opening the node and optional hub.

    Set `:recover_expired_certificate` to `true` for a local startup recovery
    when the active certificate has expired and a replacement is already
    staged. The port validates the staged credentials with the active settings
    and persists them before opening any connections. Pending property writes
    still require activation.
    """
    @spec start_link(Keyword.t()) :: GenServer.on_start()
    def start_link(opts) do
      with :ok <- Config.runtime([:ssl, :gun, :cowboy, :x509]) do
        GenServer.start_link(__MODULE__, opts, Keyword.take(opts, [:name]))
      end
    end

    @doc """
    Returns the client, node transport, and optional hub processes owned by
    the managed port. The hub entry is `nil` when no listener is running.
    """
    @spec endpoints(GenServer.server()) :: %{client: pid(), transport: pid(), hub: pid() | nil}
    def endpoints(server), do: GenServer.call(server, :endpoints)

    @doc """
    Refreshes the host's Network Port and File objects from the current
    runtime and private snapshot. The host retains the returned objects.
    Invoke this from the configured host process in hosted mode.
    """
    @spec refresh_objects(GenServer.server(), host_objects()) ::
            {:ok, host_objects()} | {:error, term()}
    def refresh_objects(server, objects), do: GenServer.call(server, {:refresh_objects, objects})

    @doc """
    Delegates a confirmed request from the port's BACnet client. The managed
    port sends the reply for a handled request and returns the objects that
    the host should retain. `:unhandled` leaves the reply to the host.

    Pass the original client notification and the current host objects.
    Invoke this from the configured host process. The call waits through
    any local activation so the returned objects describe the outcome.
    An error validating the host or objects leaves the reply to the host.
    """
    @spec handle_request(GenServer.server(), request_notification(), host_objects()) ::
            {:ok, host_objects()} | :unhandled | {:error, term()}
    def handle_request(server, notification, objects),
      do: GenServer.call(server, {:host_request, notification, objects}, :infinity)

    @doc """
    Activates pending settings and credentials locally, including while the node
    is disconnected. Hosted callers supply their current objects and retain
    the objects returned by a successful activation.
    """
    @spec activate(GenServer.server(), host_objects() | nil) ::
            :ok | {:ok, host_objects()} | {:error, term()}
    def activate(server, objects \\ nil),
      do: GenServer.call(server, {:activate, objects}, :infinity)

    @doc false
    def init(opts) do
      Process.flag(:trap_exit, true)

      with {:ok, opts, hosted} <- configure_mode(opts),
           :ok <- validate_options(opts),
           hub_audit <- opts[:hub][:audit],
           {:ok, _audit} <- Audit.configure(hub_audit),
           {:ok, receiver} <- client_receiver(hosted),
           {:ok, path} <- Store.open(opts[:storage_dir]),
           {:ok, snapshot, new?} <- Store.load(path, opts),
           :ok <- Hosted.check_snapshot(hosted, snapshot),
           {:ok, snapshot, runtime, persist?} <-
             startup_runtime(snapshot, hub_audit, new?, opts[:recover_expired_certificate]),
           {:ok, device, port} <- initialize_objects(opts, snapshot, hosted),
           :ok <- Store.initialize(path, snapshot, persist?),
           {:ok, hub} <- start_hub(runtime.hub),
           {:ok, node} <- Node.open(self(), runtime.node),
           {:ok, store} <- SegmentsStore.start_link([]),
           {:ok, segmentator} <- Segmentator.start_link([]),
           {:ok, client} <- start_client(node, store, segmentator, receiver) do
        {:ok,
         %State{
           path: path,
           snapshot: snapshot,
           runtime: runtime,
           device: device,
           port: port,
           files: nil,
           hosted: hosted,
           hub: hub,
           node: node,
           client: client,
           store: store,
           segmentator: segmentator,
           authorize: opts[:authorize],
           hub_audit: hub_audit
         }}
      else
        {:error, reason} -> {:stop, reason}
      end
    end

    @spec startup_runtime(snapshot(), Keyword.t() | nil, boolean(), term()) ::
            {:ok, snapshot(), runtime_config(), boolean()} | {:error, term()}
    defp startup_runtime(snapshot, hub_audit, new?, recover?) do
      case runtime_config(snapshot, :active, hub_audit) do
        {:ok, runtime} ->
          {:ok, snapshot, runtime, new?}

        {:error, {:operational_certificate_file, :security, :certificate_expired}}
        when recover? == true and not new? and is_map_key(snapshot.uploads, :operational) ->
          with {:ok, runtime} <- runtime_config(%{snapshot | pending: %{}}, :proposed, hub_audit) do
            {:ok, Store.promote_credentials(snapshot, runtime.key), runtime, true}
          end

        error ->
          error
      end
    end

    @doc false
    def handle_call(:endpoints, _from, state) do
      {:reply, %{client: state.client, transport: state.node, hub: state.hub}, state}
    end

    def handle_call({:refresh_objects, objects}, {caller, _tag}, state) do
      result =
        with {:ok, view} <- with_host_objects(state, caller, objects),
             {:ok, port} <- Hosted.restore_port(view.port, view.snapshot) do
          Objects.host_objects(%{view | port: port})
        end

      {:reply, result, state}
    end

    def handle_call({:host_request, notification, objects}, {caller, _tag}, state) do
      with {:ok, view} <- with_host_objects(state, caller, objects),
           {:ok, updated} <- dispatch_host_request(view, notification) do
        {:reply, {:ok, supplied_objects(updated)}, clear_objects(updated)}
      else
        other -> {:reply, other, state}
      end
    end

    def handle_call({:activate, nil}, _from, %{hosted: nil} = state) do
      case Activation.run(state, :activate_changes, fn -> :ok end) do
        {:ok, updated} -> {:reply, :ok, updated}
        {:error, reason, restored} -> {:reply, {:error, reason}, restored}
      end
    end

    def handle_call({:activate, objects}, {caller, _tag}, state) do
      with {:ok, view} <- with_host_objects(state, caller, objects),
           :ok <- Hosted.check_configuration(view.port, view.snapshot) do
        case Activation.run(view, :activate_changes, fn -> :ok end) do
          {:ok, updated} -> {:reply, {:ok, supplied_objects(updated)}, clear_objects(updated)}
          {:error, reason, restored} -> {:reply, {:error, reason}, clear_objects(restored)}
        end
      else
        error -> {:reply, error, state}
      end
    end

    @spec with_host_objects(state(), pid(), host_objects()) ::
            {:ok, state()} | {:error, term()}
    defp with_host_objects(%State{hosted: %Hosted{} = hosted} = state, caller, objects) do
      if GenServer.whereis(hosted.host) == caller do
        with :ok <- Hosted.check(hosted, objects) do
          {:ok, %{state | device: objects.device, port: objects.port, files: objects.files}}
        end
      else
        {:error, :not_object_host}
      end
    end

    defp with_host_objects(_state, _caller, _objects), do: {:error, :standalone_mode}

    @spec supplied_objects(state()) :: host_objects()
    defp supplied_objects(state),
      do: %{device: state.device, port: state.port, files: state.files}

    @spec clear_objects(state()) :: state()
    defp clear_objects(state), do: %{state | device: nil, port: nil, files: nil}

    @spec dispatch_host_request(state(), request_notification()) ::
            {:ok, state()}
            | :unhandled
            | {:error, :invalid_client_notification | :refresh_required}
    defp dispatch_host_request(
           %State{client: client} = state,
           {:bacnet_client, ref, %APDU.ConfirmedServiceRequest{} = apdu,
            {<<vmac::binary-6>>, _bvlc, %BACnet.Protocol.NPCI{source: source}}, client}
         )
         when is_reference(ref) do
      Management.hosted_request(state, ref, apdu, %{vmac: vmac, source: source})
    end

    defp dispatch_host_request(_state, _notification), do: {:error, :invalid_client_notification}

    @doc false
    def handle_info(
          {:bacnet_transport, {:bacnet_sc, Node}, _source, frame, node} = event,
          %{node: node} = state
        ) do
      if state.hosted || match?({:apdu, _bvlc, _npci, _data}, frame),
        do: send(state.client, event)

      {:noreply, state}
    end

    def handle_info(
          {:bacnet_client, nil, %APDU.UnconfirmedServiceRequest{service: :who_is} = apdu,
           {source, _bvlc, npci}, client},
          %State{client: client, hosted: nil} = state
        ) do
      with {:ok, request} <- WhoIs.from_apdu(apdu),
           true <- matches?(state.device.object_instance, request),
           {:ok, response} <-
             IAm.to_apdu(
               %IAm{
                 device: ObjectsUtility.get_object_identifier(state.device),
                 max_apdu: Node.max_apdu_length(),
                 segmentation_supported: state.device.segmentation_supported,
                 vendor_id: state.device.vendor_identifier
               },
               []
             ) do
        # A routed discovery request needs the originator's network address.
        Client.send(client, source, response, destination: npci.source)
      end

      {:noreply, state}
    end

    def handle_info(
          {:bacnet_client, ref, %APDU.ConfirmedServiceRequest{} = apdu, {vmac, _bvlc, npci},
           client},
          %State{client: client, hosted: nil} = state
        ) do
      {:noreply, Management.request(state, ref, apdu, %{vmac: vmac, source: npci.source})}
    end

    def handle_info({:sc_vmac, node, vmac}, %{node: node} = state) do
      snapshot = put_in(state.snapshot, [:transport, :vmac], vmac)

      case Store.write(state.path, snapshot) do
        :ok ->
          if state.hub, do: GenServer.call(state.hub, {:set_vmac, vmac})

          runtime = %{
            state.runtime
            | node: Keyword.put(state.runtime.node, :vmac, vmac),
              hub: state.runtime.hub && Keyword.put(state.runtime.hub, :vmac, vmac)
          }

          {:noreply, %{state | snapshot: snapshot, runtime: runtime}}

        {:error, _reason} ->
          {:stop, :vmac_persistence_failed, state}
      end
    end

    def handle_info({:EXIT, pid, reason}, state) do
      if pid in [state.hub, state.node, state.client, state.store, state.segmentator] do
        {:stop, {:sc_child_exited, reason}, state}
      else
        {:noreply, state}
      end
    end

    def handle_info(_message, state), do: {:noreply, state}

    @doc false
    def terminate(_reason, state) do
      for pid <- [state.client, state.node, state.hub, state.segmentator, state.store],
          is_pid(pid) and Process.alive?(pid) do
        GenServer.stop(pid)
      end

      :ok
    end

    @doc false
    def format_status(status) do
      status
      |> Map.replace(:state, :redacted)
      |> Map.replace(:message, :redacted)
      |> Map.replace(:log, [])
    end

    @doc """
    Returns the BACnet File object identifier assigned to a credential or CSR slot.
    """
    @spec file_id(snapshot(), file_role()) :: ObjectIdentifier.t()
    def file_id(snapshot, role),
      do: %ObjectIdentifier{type: :file, instance: snapshot.files[role]}

    @doc """
    Validates a snapshot and returns the runtime settings for the requested mode.
    """
    @spec runtime_config(snapshot(), :active | :proposed, Keyword.t() | nil) ::
            {:ok, runtime_config()} | {:error, {atom(), atom(), atom()}}
    defdelegate runtime_config(snapshot, mode, hub_audit \\ nil), to: Store

    @spec start_hub(Keyword.t() | nil) :: {:ok, pid() | nil} | {:error, term()}
    defp start_hub(nil), do: {:ok, nil}
    defp start_hub(opts), do: Hub.start_link(opts)

    @spec start_client(pid(), pid(), pid(), pid() | atom()) :: GenServer.on_start()
    defp start_client(node, store, segmentator, receiver) do
      Client.start_link(
        transport: {Node, node},
        notification_receiver: receiver,
        segments_store: store,
        segmentator: segmentator
      )
    end

    @spec client_receiver(Hosted.t() | nil) ::
            {:ok, pid() | atom()} | {:error, :object_host_unavailable}
    defp client_receiver(nil), do: {:ok, self()}

    defp client_receiver(%Hosted{host: host}) when is_pid(host) or is_atom(host), do: {:ok, host}

    defp client_receiver(%Hosted{host: host}) do
      case GenServer.whereis(host) do
        pid when is_pid(pid) -> {:ok, pid}
        _other -> {:error, :object_host_unavailable}
      end
    end

    @spec configure_mode(Keyword.t()) :: {:ok, Keyword.t(), Hosted.t() | nil} | {:error, term()}
    defp configure_mode(opts) do
      case Keyword.get(opts, :mode, :standalone) do
        :standalone -> {:ok, opts, nil}
        :hosted -> configure_hosted(opts)
        _invalid -> {:error, :invalid_managed_port_options}
      end
    end

    @spec configure_hosted(Keyword.t()) :: {:ok, Keyword.t(), Hosted.t()} | {:error, term()}
    defp configure_hosted(opts) do
      objects = opts[:objects]

      with {:ok, binding} <- Hosted.bind(opts[:host], objects),
           {:ok, settings} <- Hosted.active_configuration(objects.port),
           {:ok, hub} <- configure_host_hub(opts[:hub], settings) do
        transport =
          Store.put_transport_settings(opts[:transport] || [], settings)

        transport =
          Keyword.merge(transport, device_uuid: binding.uuid, vmac: settings.mac_address)

        opts =
          Keyword.merge(opts,
            device_instance: binding.device.instance,
            port_instance: binding.port.instance,
            vendor_id: objects.device.vendor_identifier,
            file_instances: binding.files,
            network_number: settings.network_number,
            transport: transport,
            hub: hub
          )

        {:ok, opts, binding}
      end
    end

    @spec configure_host_hub(Keyword.t() | nil, map()) ::
            {:ok, Keyword.t() | nil} | {:error, :invalid_host_hub_binding}
    defp configure_host_hub(hub, settings) do
      case {hub, Map.fetch(settings, :sc_hub_function_enable)} do
        {nil, :error} ->
          {:ok, nil}

        {options, {:ok, enabled}} when is_list(options) ->
          if Keyword.keyword?(options) and options[:port] in 0..65_535 do
            accept_uris = BACnetArray.to_list(settings.sc_hub_function_accept_uris)
            {:ok, Keyword.merge(options, enabled: enabled, accept_uris: accept_uris)}
          else
            {:error, :invalid_host_hub_binding}
          end

        _invalid ->
          {:error, :invalid_host_hub_binding}
      end
    end

    @spec initialize_objects(Keyword.t(), snapshot(), Hosted.t() | nil) ::
            {:ok, Device.t() | nil, NetworkPort.t() | nil} | {:error, term()}
    defp initialize_objects(opts, snapshot, nil) do
      with {:ok, device} <- build_device(opts, snapshot),
           {:ok, port} <- build_port(opts, snapshot) do
        {:ok, device, port}
      end
    end

    defp initialize_objects(opts, snapshot, %Hosted{}) do
      with {:ok, _port} <- Hosted.restore_port(opts[:objects].port, snapshot), do: {:ok, nil, nil}
    end

    @spec build_device(Keyword.t(), snapshot()) :: {:ok, Device.t()} | {:error, term()}
    defp build_device(opts, snapshot) do
      device_id = %ObjectIdentifier{type: :device, instance: opts[:device_instance]}
      port_id = %ObjectIdentifier{type: :network_port, instance: opts[:port_instance]}
      objects = [device_id, port_id | Enum.map(@files, &file_id(snapshot, &1))]

      services = %ServicesSupported{
        who_is: true,
        i_am: true,
        read_property: true,
        read_property_multiple: true,
        write_property: true,
        atomic_read_file: true,
        atomic_write_file: true,
        reinitialize_device: true
      }

      Device.create(
        opts[:device_instance],
        opts[:device_name] || "BACstack SC",
        %{
          vendor_identifier: opts[:vendor_id],
          protocol_revision: 24,
          protocol_services_supported: services,
          protocol_object_types_supported: %ObjectTypesSupported{
            device: true,
            network_port: true,
            file: true
          },
          device_uuid: snapshot.transport[:device_uuid],
          segmentation_supported: :segmented_both,
          max_segments_accepted: 64,
          apdu_segment_timeout: 3000,
          object_list: BACnetArray.from_list(objects)
        },
        revision: 24,
        supports_secure_connect: true
      )
    end

    @spec build_port(Keyword.t(), snapshot()) :: {:ok, NetworkPort.t()} | {:error, term()}
    defp build_port(opts, snapshot) do
      properties =
        Map.merge(snapshot.active, %{
          network_type: :sc,
          protocol_level: :bacnet_application,
          mac_address: snapshot.transport[:vmac],
          max_bvlc_length_accepted: BVLC.max_bvlc(),
          max_npdu_length_accepted: BVLC.max_npdu(),
          operational_certificate_file: file_id(snapshot, :operational),
          issuer_certificate_files:
            BACnetArray.from_list(
              [file_id(snapshot, :issuer_1), file_id(snapshot, :issuer_2)],
              true
            ),
          certificate_signing_request_file: file_id(snapshot, :csr),
          command_validation_result: Objects.health(),
          sc_primary_hub_connection_status: Objects.connector(nil, nil),
          sc_failover_hub_connection_status: Objects.connector(nil, nil)
        })

      properties =
        if snapshot.hub do
          Map.put(properties, :sc_hub_function_binding, Integer.to_string(snapshot.hub[:port]))
        else
          properties
        end

      with {:ok, object} <-
             NetworkPort.create(opts[:port_instance], "BACnet/SC Port", properties,
               revision: 24,
               supports_sc_hub: not is_nil(snapshot.hub),
               supports_command_execution: true
             ) do
        Hosted.restore_changes(object, snapshot)
      end
    end

    @doc """
    Records a successful activation in the Network Port object and clears
    its pending property changes.
    """
    @spec commit_port(NetworkPort.t(), :activate_changes | :warmstart) ::
            {:ok, NetworkPort.t()} | {:error, term()}
    def commit_port(port, reason) do
      with {:ok, result} <-
             Lifecycle.execute(
               port,
               Context.new(:periodic,
                 options: [network_port_event: {:configuration_activated, reason}]
               )
             ) do
        {:ok, result.object}
      end
    end

    @spec validate_options(Keyword.t()) :: :ok | {:error, :invalid_managed_port_options}
    defp validate_options(opts) do
      files = opts[:file_instances]
      ids = if is_map(files), do: Enum.map(@files, &Map.get(files, &1)), else: []
      authorize = opts[:authorize]

      if is_binary(opts[:storage_dir]) and opts[:device_instance] in 0..4_194_302 and
           opts[:port_instance] in 0..255 and opts[:vendor_id] in 0..65_535 and
           length(Enum.uniq(ids)) == 4 and Enum.all?(ids, &(&1 in 0..4_194_302)) and
           (is_nil(authorize) or is_function(authorize, 2)) do
        :ok
      else
        {:error, :invalid_managed_port_options}
      end
    end

    @spec matches?(non_neg_integer(), WhoIs.t()) :: boolean()
    defp matches?(instance, request) do
      instance >= (request.device_id_low_limit || 0) and
        instance <= (request.device_id_high_limit || 4_194_302)
    end
  end
end
