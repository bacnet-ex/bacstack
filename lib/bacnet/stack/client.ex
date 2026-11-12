defmodule BACnet.Stack.Client do
  @moduledoc """
  The BACnet client is responsible for connecting the application to the BACnet transport protocol
  and vice versa - it interfaces with the BACnet transport protocol, using the transport behaviour.
  The client will take requests and send them to the BACnet transport protocol and ultimately listen for
  frames from the BACnet transport protocol.

  The application will receive process messages on the specified `notification_receiver`. If there's no
  notification receiver and a confirmed service request is received, the client will automatically send
  a Reject APDU with reason `:other` to the remote BACnet device,
  the application won't be informed in any way.

  BACnet BVLL, BACnet NPDU and proprietary are directly forwarded to the application, without any processing.

  For  BACnet BVLL, the following message is sent:
  ```elixir
  {:bacnet_transport, protocol_id, source_address, {:bvlc, bvlc}, portal}
  ```
  This is the same as `t:BACnet.Stack.TransportBehaviour.transport_msg/0`.

  For BACnet NSPDU, the following message is sent:
  ```elixir
  {:bacnet_transport, protocol_id, source_address, {:network, bvlc, npci, nsdu}, portal}
  ```
  This is the same as `t:BACnet.Stack.TransportBehaviour.transport_msg/0`.

  For BACnet proprietary messages, the following message is sent:
  ```elixir
  {:bacnet_transport, protocol_id, source_address, {:proprietary, type, destination, data}, portal}
  ```
  This is the same as `t:BACnet.Stack.TransportBehaviour.transport_msg/0`.

  For BACnet APDU, the following message is sent:
  ```elixir
  {:bacnet_client, reference() | nil, apdu, {source_address, bvlc, npci}, pid()}
  ```
  The reference is only present on confirmed service requests and is used for `reply/4`.
  APDU is `t:BACnet.Protocol.apdu/0`. The PID is of the `Client` process.
  For the rest, see `t:BACnet.Stack.TransportBehaviour.transport_msg/0`.

  BACnet APDUs are decoded, checked against the internal cache and forwarded to the application.
  The client has an internal cache for requests for the application and replies from the application
  to the transport protocol in order to deduplicate request (i.e. when the application takes for the
  remote BACnet device far too long and re-sends the APDU).
  In case of duplicated request, the request will not be forwarded to the application,
  instead it will be silently dropped and the application will possibly reply in a timely fashion,
  or the APDU timeout will occur and the Client will reply instead - this situation may arise when
  the response does not arrive at the remote BACnet device within
  the remote BACnet device's configured APDU timeout window.
  Individual APDU timeouts on a per-source basis can be applied using `set_apdu_timeouts/2`.

  The client will also keep track of sent APDUs for confirmed service requests and re-send them
  automatically, if no response arrives in the APDU timeout timeframe. If the maximum APDU retries
  is reached, the request will be deleted and the application will get an APDU timeout response.

  Confirmed request invoke IDs are managed per destination and optional routed NPCI target.
  Responses preserve the peer's invoke ID independently of any local requester transaction.
  This mechanism can be disabled on startup and allows external management (or usage with care) if desired.

  If the application takes too long to respond to a remote BACnet request, the client will automatically
  send an Abort APDU and respond to a `reply` request from the application with an app timeout response.

  If the application replies to a routed request (Forwarded NPDU), the client will automatically
  set the correct destination address in `reply/4`.

  The BACnet client will not automatically respond to Who-Is, Who-Has, Time-Synchronization, etc. queries,
  as this is outside of the responsibility of this low level BACnet client implementation.

  By default, the client will validate outgoing service requests in development environments and
  reject invalid service requests. In prod environments this is disabled for performance reasons.
  The idea behind this is to prevent invalid/bad service request APDUs to be written to the network
  and catch early accidents. In production we assume we don't construct invalid APDUs and instead
  prefer the performance gain of skipping validation.
  Outgoing service request APDUs validation can be explicitely disabled by configuring
  application environment `:bacstack` key `:client_prod_compilation` to `true`.
  If this is a dependency of your project, don't forget to `mix deps.compile --force bacstack`.

  If this library is a dependency in a project, Mix always compiles dependencies in `:prod`.
  To override this behaviour, see `mix help deps`.
  """

  alias BACnet.Protocol
  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.BvlcForwardedNPDU
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.IncompleteAPDU
  alias BACnet.Protocol.NPCI
  alias BACnet.Protocol.NpciTarget
  alias BACnet.Stack.EncoderProtocol
  alias BACnet.Stack.SegmentationEndpoint
  alias BACnet.Stack.Segmentator
  alias BACnet.Stack.SegmentsStore
  alias BACnet.Stack.Telemetry
  alias BACnet.Stack.TransportBehaviour

  import BACnet.Internal, only: [is_server: 1, log_debug: 1]

  require Constants
  require Logger

  use GenServer

  @apdu_timer_offset 50
  @apdu_timeout_multiplicator 0.9

  @call_timeout Application.compile_env(:bacstack, :client_call_timeout, 60_000)
  @retry_send_after_time Application.compile_env(:bacstack, :client_retry_send_after_time, 1000)

  @default_apdu_retries 3
  @default_apdu_timeout 3000
  @default_window_size 16

  defguardp is_apdu(type)
            when type in [
                   APDU.Abort,
                   APDU.ComplexACK,
                   APDU.ConfirmedServiceRequest,
                   APDU.Error,
                   APDU.Reject,
                   APDU.SegmentACK,
                   APDU.SimpleACK,
                   APDU.UnconfirmedServiceRequest
                 ]

  defguardp is_apdu_resp(type)
            when type in [
                   APDU.Abort,
                   APDU.ComplexACK,
                   APDU.Error,
                   APDU.Reject,
                   APDU.SegmentACK,
                   APDU.SimpleACK
                 ]

  defmodule ApduTimer do
    @moduledoc """
    Internal module for `BACnet.Stack.Client`.

    It is used as APDU timer for outgoing APDUs.
    It holds together all the necessary information
    to track the APDU, time, retry count and contains
    information that is used to reply to the application.
    """

    @typedoc """
    Representative type for its purpose.
    """
    @type t :: %__MODULE__{
            portal: TransportBehaviour.portal(),
            destination: term(),
            npci_id: NpciTarget.t() | nil,
            apdu: Protocol.apdu(),
            send_opts: Keyword.t(),
            call_ref: term(),
            retry_count: non_neg_integer(),
            timer: reference(),
            monotonic_time: integer()
          }

    @fields [
      :portal,
      :destination,
      :npci_id,
      :apdu,
      :send_opts,
      :call_ref,
      :retry_count,
      :monotonic_time,
      :timer
    ]
    @enforce_keys @fields
    defstruct @fields
  end

  defmodule ReplyTimer do
    @moduledoc """
    Internal module for `BACnet.Stack.Client`.

    It is used as reply timer for incoming APDUs.
    It holds together all the necessary information
    to fire when the application does not respond
    fast enough and will reply negatively to the
    remote BACnet client.
    """

    @typedoc """
    Representative type for its purpose.
    """
    @type t :: %__MODULE__{
            bvlc: Protocol.bvlc(),
            npci: NPCI.t(),
            portal: TransportBehaviour.portal(),
            service_req: Protocol.apdu(),
            source_addr: term(),
            npci_id: NpciTarget.t() | nil,
            ref: reference(),
            monotonic_time: integer(),
            has_retried: boolean(),
            timer: reference() | nil
          }

    @fields [
      :bvlc,
      :npci,
      :portal,
      :service_req,
      :source_addr,
      :npci_id,
      :ref,
      :monotonic_time,
      :has_retried,
      :timer
    ]
    @enforce_keys @fields
    defstruct @fields
  end

  defmodule State do
    @moduledoc """
    Internal module for `BACnet.Stack.Client`.

    It is used as `GenServer` state.
    """

    @typedoc """
    Key for the application reply timer.
    """
    @type app_timer_key ::
            {address :: term(), npci_id :: NpciTarget.t() | nil, invoke_id :: byte()}

    @typedoc """
    Representative type for its purpose.
    """
    @type t :: %__MODULE__{
            apdu_timers: %{optional(app_timer_key()) => BACnet.Stack.Client.ApduTimer.t()},
            apdu_timeouts: BACnet.Stack.Client.apdu_timeouts(),
            app_reply_mapping: %{
              optional(reference()) => app_timer_key()
            },
            app_reply_timers: %{
              optional(app_timer_key()) => BACnet.Stack.Client.ReplyTimer.t()
            },
            free_invoke_ids: %{
              optional({term(), NpciTarget.t() | nil}) => :queue.queue(byte())
            },
            notification_receiver: [Process.dest()],
            notification_recv_monitors: %{optional(pid()) => reference()},
            segmentator: Segmentator.server(),
            segments_store: SegmentsStore.server(),
            transport_broadcast_addr: term(),
            transport_mod: module(),
            transport_pid: TransportBehaviour.transport(),
            transport_portal: TransportBehaviour.portal(),
            opts: %{
              apdu_retries: non_neg_integer(),
              apdu_timeout: pos_integer(),
              disable_app_timeout: boolean(),
              disable_invoke_id_management: boolean(),
              npci_source: NpciTarget.t() | nil,
              segmented_rcv_window_overwrite: boolean()
            }
          }

    @fields [
      :apdu_timers,
      :apdu_timeouts,
      :app_reply_mapping,
      :app_reply_timers,
      :free_invoke_ids,
      :notification_receiver,
      :notification_recv_monitors,
      :segmentator,
      :segments_store,
      :transport_broadcast_addr,
      :transport_mod,
      :transport_pid,
      :transport_portal,
      :opts
    ]
    @enforce_keys @fields
    defstruct @fields
  end

  # Validate outgoing APDUs, but only if not in prod env or prod compilation enabled
  if Application.compile_env(:bacstack, :client_prod_compilation, Mix.env() == :prod) do
    @compile {:inline, do_validate: 3}
    defp do_validate(server, msg, _body), do: GenServer.call(server, msg, @call_timeout)
  else
    defp do_validate(server, msg, %type{} = body) do
      if function_exported?(type, :to_service, 1) do
        type.to_service(body)
      else
        # Unable to validate APDU (currently we can only validate Service Requests)
        {:ok, nil}
      end
    rescue
      e -> {:error, {:invalid_apdu, {:rescue, e, __STACKTRACE__}, body}}
    catch
      type, error -> {:error, {:invalid_apdu, {:catch, type, error}, body}}
    else
      result ->
        case result do
          {:ok, _term} -> GenServer.call(server, msg, @call_timeout)
          {:error, err} -> {:error, {:invalid_apdu, {:validation, err}, body}}
        end
    end
  end

  @typedoc """
  Per-source APDU timeouts.

  The optional NPCI target is the complete source network/address pair, not a
  BACnet Device object instance. A nil target is the fallback for that transport source.
  """
  @type apdu_timeouts :: %{
          optional({source_address :: term(), npci_id :: NpciTarget.t() | nil}) =>
            apdu_timeout :: non_neg_integer()
        }

  @typedoc """
  Valid start options. For a description of each, see `start_link/1`.
  """
  @type start_option ::
          {:apdu_retries, pos_integer()}
          | {:apdu_timeout, pos_integer()}
          | {:disable_app_timeout, boolean()}
          | {:disable_invoke_id_management, boolean()}
          | {:notification_receiver, Process.dest() | [Process.dest()]}
          | {:npci_source, NpciTarget.t()}
          | {:segmentator, Segmentator.server()}
          | {:segments_store, SegmentsStore.server()}
          | {:segmented_rcv_window_overwrite, boolean()}
          | {:transport, module() | {module(), TransportBehaviour.transport()}}
          | GenServer.option()

  @typedoc """
  Represents a server process of the Client module.
  """
  @type server :: GenServer.server()

  @typedoc """
  List of start options.
  """
  @type start_options :: [start_option()]

  @doc """
  Starts and links the BACnet Client.

  The following options are available, in addition to `t:GenServer.options/0`:
    - `apdu_retries: pos_integer()` - Optional. The amount of APDU sending retries (defaults to 3).
      Only applied to confirmed service requests.
    - `apdu_timeout: pos_integer()` - Optional. The APDU timeout to be waiting for a response, in ms (defaults to 3000ms).
      Only applied to confirmed service requests.
    - `disable_app_timeout: boolean()` - Optional. Disables the application timeout mechanism.
    - `disable_invoke_id_management: boolean()` - Optional. Disables `invoke_id` management and override in request payloads.
    - `notification_receiver: Process.dest() | [Process.dest()]` - Optional. The destination to send messages to.
      Duplicate destinations are ignored. PID receivers are monitored and automatically removed on exit,
      just like receivers added through `subscribe/2`.
    - `npci_source: NpciTarget.t()` - Optional. The NPCI target to use as source for outgoing APDUs.
    - `segmentator: Segmentator.server()` - Required. The segmentator server to use.
    - `segments_store: SegmentsStore.server()` - Required. The segments store server to use.
    - `segmented_rcv_window_overwrite: boolean()` - Optional. Enable to overwrite the window size to 1 for incoming
      segmented APDUs when it is bound to be routed (i.e. subject to BACnet/IP UDP packet re-ordering).
      If you're having difficulty receiving segmented APDUs and the packets get routed on BACnet/IP,
      you should consider enabling this and see if it helps.
    - `transport: module() | {module(), TransportBehaviour.transport()}` - Required. The transport to use.
      `module` is equivalent to `{module, module}` (the module name is registered process name).
      The given transport must implement the `BACnet.Stack.TransportBehaviour` behaviour.
  """
  @spec start_link(start_options()) :: GenServer.on_start()
  def start_link(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError, "start_link/1 expected a keyword list, got: #{inspect(opts)}"
    end

    {opts2, genserver_opts} =
      Keyword.split(opts, [
        :apdu_retries,
        :apdu_timeout,
        :disable_app_timeout,
        :disable_invoke_id_management,
        :notification_receiver,
        :npci_source,
        :segmentator,
        :segments_store,
        :segmented_rcv_window_overwrite,
        :transport
      ])

    validate_start_link_opts(opts2, "start_link/1")

    GenServer.start_link(__MODULE__, Map.new(opts2), genserver_opts)
  end

  @doc """
  Configure the client.

  Only some of the available `t:start_options/0` can be configured,
  unsupported options can only be changed by re-starting the client completely.

  The following options are supported:
  - `apdu_retries`
  - `apdu_timeout`
  - `disable_app_timeout` (note that current active timers will NOT be cancelled)
  - `npci_source`
  - `segmented_rcv_window_overwrite`

  For a description of each option, see `start_link/1`.
  """
  @spec configure(server(), start_options()) :: :ok
  def configure(server, opts) when is_server(server) and is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "configure/2 expected opts to be a keyword list, " <>
              "got: #{inspect(opts)}"
    end

    validate_start_link_opts(opts, "configure/2", true)

    Enum.each(opts, fn
      # Supported options
      {key, _val}
      when key in [
             :apdu_retries,
             :apdu_timeout,
             :disable_app_timeout,
             :npci_source,
             :segmented_rcv_window_overwrite
           ] ->
        true

      {key, _val} ->
        raise ArgumentError,
              "configure/2 does not support option " <> inspect(key)
    end)

    GenServer.call(server, {:configure, Map.new(opts)})
  end

  @doc """
  Add a source to the per-source APDU timeouts map. This is only used for receiving.

  Each source is identified by its transport address and optional complete NPCI
  source target (`NpciTarget`, including network and address). A nil target is
  used as the fallback when no exact target entry exists.
  """
  @spec add_apdu_timeout(server(), term(), NpciTarget.t() | nil, pos_integer()) :: :ok
  def add_apdu_timeout(server, source_address, npci_id, timeout)
      when is_server(server) and
             (is_struct(npci_id, NpciTarget) or is_nil(npci_id)) and
             is_integer(timeout) and timeout > 0 do
    GenServer.call(server, {:add_apdu_timeout, source_address, npci_id, timeout})
  end

  @doc """
  Get the per-source APDU timeouts map. This is only used for receiving.

  Each source is identified by its transport address and optional complete NPCI
  source target (`NpciTarget`, including network and address). A nil target is
  used as the fallback when no exact target entry exists.
  """
  @spec get_apdu_timeouts(server()) :: {:ok, apdu_timeouts()}
  def get_apdu_timeouts(server) when is_server(server) do
    GenServer.call(server, :get_apdu_timeouts)
  end

  @doc """
  Get the transport used in the client.
  """
  @spec get_transport(server()) ::
          {module(), TransportBehaviour.transport(), TransportBehaviour.portal()}
  def get_transport(server) when is_server(server) do
    GenServer.call(server, :get_transport)
  end

  @doc """
  Replies to a confirmed service request from a remote BACnet device.
  The APDU frame may be segmentated by the client, depending on the
  APDU size and maximum transmittable APDU size.

  The reference identifies the request in the client. The request is hold
  in the client to be able to apply application timeout constraints and
  automatically respond on application timeout.
  The remote BACnet device may send the same request again within the
  configured APDU timeout and thus will be silently deduplicated (dropped).
  The reference is given as part of the BACnet client notification process message.

  If an automatic application timeout response has been sent (Abort APDU),
  `{:error, :app_timeout}` will be returned when trying to reply to the
  request.

  See `send/4` for more information about `opts`.
  The options `:max_apdu_length`, `:max_segments` and `:segmentation_supported` of `opts`
  are automatically derived from the confirmed service request, if not explicitely given.
  """
  @spec reply(server(), reference(), Protocol.apdu(), Keyword.t()) ::
          :ok
          | {:error, :app_timeout}
          | {:error, term()}
          | {:error, {Exception.t(), stacktrace :: Exception.stacktrace()}}
  def reply(server, ref, %type{} = reply, opts \\ [])
      when is_server(server) and is_reference(ref) and is_apdu_resp(type) and is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "reply/4 expected opts to be a keyword list, " <>
              "got: #{inspect(opts)}"
    end

    validate_send_opts(opts, "reply/4")

    # do_validate(server, {:reply, ref, reply, opts}, reply)
    GenServer.call(server, {:reply, ref, reply, opts}, @call_timeout)
  end

  @doc """
  Remove a source from the per-source APDU timeouts map. This is only used for receiving.

  Each source is identified by its transport address and optional complete NPCI
  source target (`NpciTarget`, including network and address).
  """
  @spec remove_apdu_timeout(server(), term(), NpciTarget.t() | nil) :: :ok
  def remove_apdu_timeout(server, source_address, npci_id)
      when is_server(server) and
             (is_struct(npci_id, NpciTarget) or is_nil(npci_id)) do
    GenServer.call(server, {:remove_apdu_timeout, source_address, npci_id})
  end

  @doc """
  Sends the given APDU frame to the specified destination (remote BACnet device).
  The APDU frame may be segmentated by the client.

  The client will keep track of sent confirmed service requests and automatically
  re-send the APDUs, if the APDU times out, without a response from the remote
  BACnet server. If the maximum APDU retry count gets reached,
  `{:error, :apdu_timeout}` will be returned.

  This function returns, for confirmed service requests, after receiving the
  response from the remote BACnet server, for everything else almost immediately.

  As such, this function will block for maximum 60s (default compiled value), before
  the backpressure mechanism will exit the caller.

  Destination depends on the transport module and is validated against the
  transport module.

  BACnet Abort/Error/Reject are also returned in `:ok` tuples, not only
  acknowledgements and requests.

  When sending and the APDU is too large and thus is needed to be segmented,
  the client will check accordinging to the given options,
  whether segmentation can occur and how many segments are supported.
  If the remote device does not support segmentation or a buffer overflow
  would occur due to too many segments, this client will send an Abort APDU
  to the remote device and return an error to the caller. The same will happen
  for too long APDUs that can not be segmented.

  See the `c:BACnet.Stack.TransportBehaviour.send/4` documentation for what `opts` can be.
  In addition the following are available:
    - `max_apdu_length: pos_integer()` - Optional. The maximum APDU length
      the remote BACnet device supports (defaults to the transport max APDU length).
      Limited by the transport max (extended) APDU length.
      If the transport supports an extended APDU length, you need to make sure
      the transport uses it, if it needs to be explicitely enabled.
      For calculation, always the NPDU length is used, as it expresses how many
      bytes for the APDU can actually be used without constraining the transport's
      actual maximum transmission unit.
    - `max_segments: pos_integer()` - Optional. Maximum amount of segments the
      remote BACnet device can accept (defaults to 2).
    - `npci_id: NpciTarget.t()` - Optional. The remote network/address pair
      used to scope invoke ID allocation together with the transport destination.
      Set it to the same complete target used in `:destination` or `:npci.destination`
      when allocating invoke IDs independently for devices behind a router.
      This option does not configure routing - omit it to share one invoke ID pool
      for the transport destination.
      Please note, if wrongfully used, this may lead to collisions and invalid data -
      including  replies sent to requests that were never meant for that request.
    - `segmentation_supported: Constants.segmentation()` - Optional. Which kind
      of segmentation the remote BACnet device supports (defaults to none).

  This function may be subject to outgoing APDU validation.
  """
  @spec send(server(), term(), Protocol.apdu(), Keyword.t()) ::
          :ok
          | {:ok, Protocol.apdu()}
          | {:error, :apdu_timeout}
          | {:error, :apdu_too_long}
          | {:error, :segmentation_not_supported}
          | {:error, term()}
          | {:error, {Exception.t(), stacktrace :: Exception.stacktrace()}}
          | {:error, {term(), stacktrace :: Exception.stacktrace()}}
  def send(server, destination, %type{} = data, opts \\ [])
      when is_server(server) and is_apdu(type) and is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "send/4 expected opts to be a keyword list, " <>
              "got: #{inspect(opts)}"
    end

    validate_send_opts(opts, "send/4")

    do_validate(server, {:send, destination, data, opts}, data)
  end

  @doc """
  Set the per-source APDU timeouts map. This is only used for receiving.

  Each source is identified by its transport address and optional complete NPCI
  source target (`NpciTarget`, including network and address). A nil target is
  used as the fallback when no exact target entry exists.
  """
  @spec set_apdu_timeouts(server(), apdu_timeouts()) :: :ok
  def set_apdu_timeouts(server, %{} = timeouts) when is_server(server) do
    GenServer.call(server, {:set_apdu_timeouts, timeouts})
  end

  @doc """
  Puts the subscriber in the `notification_receiver` list.
  The list contains only unique elements, so this function call is idempotent.

  After this function returns, the subscriber will start to receive
  process messages as lined out by the module documentation.

  If `subscriber` is a PID, it will be monitored and automatically removed.
  This means for short lived processes, using the PID is recommended
  as the PID is automatically removed when the process dies.
  """
  @spec subscribe(server(), pid() | Process.dest() | GenServer.server()) :: :ok
  def subscribe(server, subscriber) when is_server(server) and is_server(subscriber) do
    GenServer.call(server, {:subscribe, subscriber})
  end

  @doc """
  Removes the subscriber from the `notification_receiver` list.

  After this function returns, the subscriber will stop receiving
  process messages as lined out by the module documentation.
  Its PID monitor, if present, is removed and
  queued `:DOWN` messages for that monitor are flushed.
  """
  @spec unsubscribe(server(), pid() | Process.dest() | GenServer.server()) :: :ok
  def unsubscribe(server, subscriber) when is_server(server) and is_server(subscriber) do
    GenServer.call(server, {:unsubscribe, subscriber})
  end

  @doc false
  def init(opts) do
    # Transform transport option into transport module and pid/name
    {transport_mod, transport_pid} =
      case opts.transport do
        {mod, pid} -> {mod, pid}
        mod -> {mod, mod}
      end

    state_opts =
      opts
      |> Map.drop([
        :notification_receiver,
        :segmentator,
        :segments_store,
        :transport
      ])
      |> Map.put_new(:apdu_retries, @default_apdu_retries)
      |> Map.put_new(:apdu_timeout, @default_apdu_timeout)
      |> Map.put_new(:disable_app_timeout, false)
      |> Map.put_new(:disable_invoke_id_management, false)
      |> Map.put_new(:npci_source, nil)
      |> Map.put_new(:segmented_rcv_window_overwrite, false)

    receivers =
      opts
      |> Map.get(:notification_receiver, [])
      |> List.wrap()
      |> Enum.uniq()

    receiver_monitors =
      Map.new(for pid <- receivers, is_pid(pid), do: {pid, Process.monitor(pid)})

    state = %State{
      apdu_timers: %{},
      apdu_timeouts: %{},
      app_reply_mapping: %{},
      app_reply_timers: %{},
      free_invoke_ids: %{},
      notification_receiver: receivers,
      notification_recv_monitors: receiver_monitors,
      segmentator: opts.segmentator,
      segments_store: opts.segments_store,
      transport_broadcast_addr: transport_mod.get_broadcast_address(transport_pid),
      transport_mod: transport_mod,
      transport_pid: transport_pid,
      transport_portal: transport_mod.get_portal(transport_pid),
      opts: state_opts
    }

    log_debug(fn -> "Client: Started on #{inspect(self())}" end)

    {:ok, state}
  end

  @doc false
  def handle_call({:configure, %{} = opts}, _from, %State{} = state) do
    new_state = %{state | opts: Map.merge(state.opts, opts)}
    {:reply, :ok, new_state}
  end

  def handle_call(
        {:add_apdu_timeout, source_address, npci_id, timeout},
        _from,
        %State{apdu_timeouts: apdu_timeouts} = state
      ) do
    log_debug(fn -> "Client: Received add_apdu_timeout request" end)

    new_state = %{
      state
      | apdu_timeouts: Map.put(apdu_timeouts, {source_address, npci_id}, timeout)
    }

    {:reply, :ok, new_state}
  end

  def handle_call(:get_apdu_timeouts, _from, %State{} = state) do
    log_debug(fn -> "Client: Received get_apdu_timeouts request" end)
    {:reply, {:ok, state.apdu_timeouts}, state}
  end

  def handle_call(
        {:remove_apdu_timeout, source_address, npci_id},
        _from,
        %State{apdu_timeouts: apdu_timeouts} = state
      ) do
    log_debug(fn -> "Client: Received remove_apdu_timeout request" end)

    new_state = %{state | apdu_timeouts: Map.delete(apdu_timeouts, {source_address, npci_id})}
    {:reply, :ok, new_state}
  end

  def handle_call({:set_apdu_timeouts, %{} = new_value}, _from, %State{} = state) do
    log_debug(fn -> "Client: Received set_apdu_timeouts request" end)

    new_state = %{state | apdu_timeouts: new_value}
    {:reply, :ok, new_state}
  end

  def handle_call(:get_transport, _from, %State{} = state) do
    log_debug(fn -> "Client: Received get_transport request" end)
    {:reply, {state.transport_mod, state.transport_pid, state.transport_portal}, state}
  end

  def handle_call(
        {:transport_call, function, args},
        _from,
        %State{transport_mod: trans_mod} = state
      )
      when is_atom(function) and is_list(args) do
    log_debug(fn -> "Client: Received transport_call request" end)

    result =
      try do
        case apply(trans_mod, function, args) do
          {:ok, _term} = term -> term
          {:error, _err} = term -> term
          term -> {:ok, term}
        end
      catch
        _kind, e -> {:error, {e, __STACKTRACE__}}
      end

    {:reply, result, state}
  end

  def handle_call(:get_broadcast_address, _from, %State{transport_mod: trans_mod} = state) do
    log_debug(fn -> "Client: Received get_broadcast_address request" end)

    result =
      try do
        brd = trans_mod.get_broadcast_address(state.transport_pid)
        {:ok, brd}
      catch
        _kind, e -> {:error, {e, __STACKTRACE__}}
      end

    {:reply, result, state}
  end

  def handle_call({:subscribe, pid}, _from, %State{} = state) do
    log_debug(fn -> "Client: Received subscribe request" end)

    new_state =
      state
      |> Map.update!(:notification_receiver, fn list ->
        if Enum.member?(list, pid) do
          list
        else
          [pid | list]
        end
      end)
      |> Map.update!(:notification_recv_monitors, fn monitors ->
        if is_pid(pid) and not Map.has_key?(monitors, pid) do
          # Monitor PIDs, because they should be removed
          # once the subscribing process dies
          Map.put(monitors, pid, Process.monitor(pid))
        else
          monitors
        end
      end)

    {:reply, :ok, new_state}
  end

  def handle_call({:unsubscribe, pid}, _from, %State{} = state) do
    log_debug(fn -> "Client: Received unsubscribe request" end)

    new_state =
      state
      |> Map.update!(:notification_receiver, fn list ->
        List.delete(list, pid)
      end)
      |> Map.update!(:notification_recv_monitors, fn monitors ->
        # Demonitor the PID
        case Map.pop(monitors, pid) do
          {nil, mon} ->
            mon

          {ref, mon} ->
            Process.demonitor(ref, [:flush])
            mon
        end
      end)

    {:reply, :ok, new_state}
  end

  def handle_call(
        {:send, destination, %{} = data, opts},
        from,
        %State{transport_mod: trans_mod} = state
      ) do
    log_debug(fn -> "Client: Received send request" end)

    try do
      trans_mod.valid_destination?(destination)
    catch
      _kind, e -> {:reply, {:error, {e, __STACKTRACE__}}, state}
    else
      is_valid_dest ->
        if is_valid_dest do
          # Match the effective routing target: an explicit NPCI overrides :destination
          routed_target =
            case Keyword.get(opts, :npci) do
              %NPCI{destination: target} -> target
              nil -> opts[:destination]
              _other -> nil
            end

          apdu_timer_id =
            case routed_target do
              %NpciTarget{address: addr} = target when not is_nil(addr) -> target
              _other -> nil
            end

          if state.opts.disable_invoke_id_management and
               is_struct(data, ConfirmedServiceRequest) and
               Map.has_key?(
                 state.apdu_timers,
                 {destination, apdu_timer_id, Map.get(data, :invoke_id)}
               ) do
            {:reply, {:error, :duplicate_invoke_id}, state}
          else
            needs_tracking = is_struct(data, ConfirmedServiceRequest)

            case send_data(
                   data,
                   opts,
                   destination,
                   state.transport_portal,
                   opts[:npci_id],
                   apdu_timer_id,
                   needs_tracking,
                   from,
                   state,
                   false
                 ) do
              {:ok, new_state} ->
                if needs_tracking, do: {:noreply, new_state}, else: {:reply, :ok, new_state}

              {:retry, new_state} ->
                # We don't have a free invoke_id, so retry later
                Process.send_after(
                  self(),
                  {:"$gen_call", from, {:send, destination, data, opts}},
                  @retry_send_after_time
                )

                {:noreply, new_state}

              term ->
                {:reply, term, state}
            end
          end
        else
          {:reply, {:error, :invalid_destination}, state}
        end
    end
  end

  def handle_call({:reply, ref, %{} = data, opts}, _from, %State{} = state) do
    log_debug(fn -> "Client: Received reply request" end)

    reply_key = Map.get(state.app_reply_mapping, ref, ref)

    {reply, new_state} =
      case Map.fetch(state.app_reply_timers, reply_key) do
        {:ok, reply} ->
          destination =
            case reply.bvlc do
              %BvlcForwardedNPDU{} = forwarded ->
                {forwarded.originating_ip, forwarded.originating_port}

              _else ->
                reply.source_addr
            end

          new_opts =
            opts
            |> kw_put_new(:destination, get_reply_opts_destination(reply.npci))
            |> Keyword.put_new(:max_apdu_length, reply.service_req.max_apdu)
            |> Keyword.put_new_lazy(:max_segments, fn ->
              case reply.service_req.max_segments do
                # BTL-2017: Unspecified might be as low as 2 and is kept for backwards compatibility
                :unspecified -> 2
                val -> val
              end
            end)
            |> Keyword.put_new_lazy(:segmentation_supported, fn ->
              if reply.service_req.segmented_response_accepted do
                Constants.macro_assert_name(:segmentation, :segmented_receive)
              end
            end)

          Telemetry.execute_client_inc_apdu_reply(self(), data, new_opts, reply, state)

          case send_data(
                 data,
                 new_opts,
                 destination,
                 reply.portal,
                 reply.npci_id,
                 reply.npci_id,
                 false,
                 nil,
                 state,
                 true
               ) do
            {:ok, new_state} ->
              if reply.timer, do: Process.cancel_timer(reply.timer)

              new_state2 =
                new_state
                |> Map.update!(:app_reply_mapping, fn mapping ->
                  Map.delete(mapping, ref)
                end)
                |> Map.update!(:app_reply_timers, fn timers ->
                  Map.delete(timers, reply_key)
                end)

              {:ok, new_state2}

            {:error, _err} = err ->
              {err, state}
          end

        :error ->
          {{:error, :app_timeout}, state}
      end

    {:reply, reply, new_state}
  end

  def handle_call(_msg, _from, state) do
    {:noreply, state}
  end

  @doc false
  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  @doc false
  def handle_info(
        {:bacnet_transport, _proto, source_address, {:bvlc, _bvlc}, _portal} = data,
        %State{notification_receiver: dest} = state
      ) do
    log_debug(fn ->
      "Client: Got BACnet stack BVLC data from #{inspect(source_address)}, data: #{inspect(data)}"
    end)

    Telemetry.execute_client_transport_message(self(), data, state)

    send_process_dest(dest, data)
    {:noreply, state}
  end

  def handle_info(
        {:bacnet_transport, _proto, source_address, {:network, _bvlc, _npci, _nsdu}, _portal} =
          data,
        %State{notification_receiver: dest} = state
      ) do
    log_debug(fn ->
      "Client: Got BACnet stack NSDU data from #{inspect(source_address)}, data: #{inspect(data)}"
    end)

    Telemetry.execute_client_transport_message(self(), data, state)

    send_process_dest(dest, data)
    {:noreply, state}
  end

  def handle_info(
        {:bacnet_transport, _proto, source_address, {:proprietary, _type, _destination, _payload},
         _portal} =
          data,
        %State{notification_receiver: dest} = state
      ) do
    log_debug(fn ->
      "Client: Got BACnet stack proprietary data from #{inspect(source_address)}, data: #{inspect(data)}"
    end)

    Telemetry.execute_client_transport_message(self(), data, state)

    send_process_dest(dest, data)
    {:noreply, state}
  end

  def handle_info(
        {:bacnet_transport, _proto, source_address, {:apdu, bvlc, npci, raw_apdu} = cb_data,
         portal} = data,
        %State{} = state
      ) do
    log_debug(fn ->
      "Client: Got BACnet stack APDU data from #{inspect(source_address)}, data: #{inspect(cb_data)}"
    end)

    Telemetry.execute_client_transport_message(self(), data, state)

    new_state = handle_raw_apdu(source_address, bvlc, npci, raw_apdu, portal, state)

    {:noreply, new_state}
  end

  def handle_info(
        {seg_state, {:apdu_timer_setup, %SegmentationEndpoint{} = endpoint, :requester, key}},
        %State{} = state
      ) do
    case Map.fetch(state.apdu_timers, key) do
      {:ok, timer} ->
        if SegmentationEndpoint.new(
             state.transport_mod,
             timer.portal,
             timer.destination,
             timer.send_opts
           ) == endpoint do
          handle_segmented_apdu_result(seg_state, key, state)
        else
          {:noreply, state}
        end

      :error ->
        {:noreply, state}
    end
  end

  def handle_info({:apdu_timer, key}, %State{opts: %{apdu_retries: max_retry}} = state) do
    # If remote server takes too long to reply, send APDU again
    # for n times and if still no reply, abort and reply to call
    log_debug(fn -> "Client: Received APDU timer message for #{inspect(key)}" end)

    new_state =
      case Map.fetch(state.apdu_timers, key) do
        {:ok, %ApduTimer{retry_count: retry} = timer} when retry >= max_retry ->
          log_debug(fn ->
            "Client: APDU timer #{inspect(key)} has reached max retry count, removing"
          end)

          Telemetry.execute_client_request_apdu_timer(self(), timer, state)

          GenServer.reply(timer.call_ref, {:error, :apdu_timeout})

          # Update state
          new_state = %{state | apdu_timers: Map.delete(state.apdu_timers, key)}

          # Return invoke ID to map
          case key do
            {_dest, _dev, invoke_id} when not is_nil(invoke_id) ->
              update_free_invoke_ids(timer.destination, timer.npci_id, invoke_id, new_state)

            _other ->
              new_state
          end

        {:ok, %ApduTimer{} = timer} ->
          case send_data(
                 timer.apdu,
                 timer.send_opts,
                 timer.destination,
                 timer.portal,
                 timer.npci_id,
                 nil,
                 # No tracking because we update the timer "inline"
                 false,
                 nil,
                 state,
                 # Skip check because we "lock" the invoke ID using the APDU timer
                 true
               ) do
            {:ok, new_state} ->
              %{
                new_state
                | apdu_timers:
                    Map.update!(state.apdu_timers, key, fn timer ->
                      %{
                        timer
                        | retry_count: timer.retry_count + 1,
                          timer:
                            Process.send_after(
                              self(),
                              {:apdu_timer, key},
                              state.opts.apdu_timeout + @apdu_timer_offset
                            )
                      }
                    end)
              }

            {:error, err} ->
              log_debug(fn ->
                "Client: Error on trying to re-send APDU on APDU timeout, error: #{inspect(err)}"
              end)

              # Try again a tiny bit later, store timer reference in state
              %{
                state
                | apdu_timers:
                    Map.update!(state.apdu_timers, key, fn timer ->
                      %{
                        timer
                        | timer:
                            Process.send_after(self(), {:apdu_timer, key}, @apdu_timer_offset)
                      }
                    end)
              }

              state
          end

        :error ->
          state
      end

    {:noreply, new_state}
  end

  def handle_info({:reply_timer, reply_key}, %State{} = state) do
    # If app takes too long to reply to request, send abort APDU to remote device
    log_debug(fn -> "Client: Received reply timer message for #{inspect(reply_key)}" end)

    new_state =
      case Map.fetch(state.app_reply_timers, reply_key) do
        {:ok, %ReplyTimer{} = reply} ->
          apdu = %APDU.Abort{
            sent_by_server: true,
            invoke_id: reply.service_req.invoke_id,
            reason: Constants.macro_assert_name(:abort_reason, :application_exceeded_reply_time)
          }

          Telemetry.execute_client_inc_apdu_timeout(self(), reply, state)

          case send_data(
                 apdu,
                 get_reply_opts_for_npci(apdu, :original_unicast, reply.npci, state),
                 reply.source_addr,
                 reply.portal,
                 reply.npci_id,
                 reply.npci_id,
                 false,
                 nil,
                 state,
                 true
               ) do
            {:ok, new_state} ->
              %{
                new_state
                | app_reply_mapping: Map.delete(state.app_reply_mapping, reply.ref),
                  app_reply_timers: Map.delete(state.app_reply_timers, reply_key)
              }

            {:error, err} ->
              log_debug(fn ->
                "Client: Encountered error during app reply timeout when sending APDU abort reply, error: #{inspect(err)}"
              end)

              if reply.has_retried do
                # We have already retried sending the Abort APDU, we do not do it again,
                # clean up regardless
                %{
                  state
                  | app_reply_mapping: Map.delete(state.app_reply_mapping, reply.ref),
                    app_reply_timers: Map.delete(state.app_reply_timers, reply_key)
                }
              else
                # Retry in 10ms again once
                timers =
                  Map.put(state.app_reply_timers, reply_key, %{
                    reply
                    | timer: Process.send_after(self(), {:reply_timer, reply_key}, 10),
                      has_retried: true
                  })

                %{state | app_reply_timers: timers}
              end
          end

        :error ->
          state
      end

    {:noreply, new_state}
  end

  def handle_info({:DOWN, ref, :process, pid, _reason}, %State{} = state) do
    # Only remove the subscription that owns this monitor
    # A stale DOWN from a previous subscription must not
    # remove a newer subscription for the same PID
    new_state =
      case Map.fetch(state.notification_recv_monitors, pid) do
        {:ok, ^ref} ->
          %{
            state
            | notification_receiver: List.delete(state.notification_receiver, pid),
              notification_recv_monitors: Map.delete(state.notification_recv_monitors, pid)
          }

        _other ->
          state
      end

    {:noreply, new_state}
  end

  # def handle_info({:DOWN, _ref, _type, _object, _reason}, %State{} = state)
  #     when object == state.transport_pid do
  #   # When transport goes down, go down too - we need to get initialized from start
  #   {:stop, :transport_down, state}
  # end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @spec handle_segmented_apdu_result(
          :done | :timeout | :cancelled,
          State.app_timer_key(),
          State.t()
        ) :: {:noreply, State.t()}
  defp handle_segmented_apdu_result(seg_state, key, %State{} = state) do
    # Segmentator module reports back for the segmented APDU
    # seg_state will be :done|:timeout|:cancelled
    # (:cancelled shouldn't scratch us, as this should already be locally handled)
    log_debug(fn ->
      "Client: Received APDU timer setup message for #{inspect(key)} with state #{seg_state}"
    end)

    new_state =
      case Map.fetch(state.apdu_timers, key) do
        {:ok, %ApduTimer{} = timer} ->
          case seg_state do
            :done ->
              %{
                state
                | apdu_timers:
                    Map.update!(state.apdu_timers, key, fn timer ->
                      %{
                        timer
                        | retry_count: timer.retry_count + 1,
                          timer:
                            Process.send_after(
                              self(),
                              {:apdu_timer, key},
                              state.opts.apdu_timeout + @apdu_timer_offset
                            )
                      }
                    end)
              }

            :timeout ->
              log_debug(fn ->
                "Client: APDU timer #{inspect(key)} has reached max retry count (via Segmentator), removing"
              end)

              Telemetry.execute_client_request_apdu_timer(self(), timer, state)

              GenServer.reply(timer.call_ref, {:error, :apdu_timeout})
              %{state | apdu_timers: Map.delete(state.apdu_timers, key)}

            _other ->
              %{state | apdu_timers: Map.delete(state.apdu_timers, key)}
          end

        :error ->
          state
      end

    {:noreply, new_state}
  end

  # Segmentation control must reach shared components even without application subscribers
  # or an outgoing request timer (for example, while sending a segmented response)
  @spec handle_segmentation_control(
          term(),
          Protocol.bvlc(),
          NPCI.t(),
          Protocol.apdu(),
          TransportBehaviour.portal(),
          State.t()
        ) :: State.t()
  defp handle_segmentation_control(source_address, bvlc, npci, %type{} = apdu, portal, state)
       when type in [APDU.SegmentACK, APDU.Abort, APDU.Error, APDU.Reject, APDU.SimpleACK] do
    endpoint =
      SegmentationEndpoint.new(
        state.transport_mod,
        portal,
        segmentation_peer(source_address, bvlc),
        destination: npci.source
      )

    if type in [APDU.SegmentACK, APDU.Abort, APDU.Error, APDU.Reject] do
      case Segmentator.handle_apdu(state.segmentator, endpoint, apdu) do
        :ok ->
          :ok

        {:error, err} ->
          log_debug(fn ->
            "Client: Error while handling APDU by Segmentator, error: #{inspect(err)}"
          end)

          Telemetry.execute_client_exception(
            self(),
            :error,
            err,
            [Telemetry.make_stacktrace_from_env(__ENV__)],
            %{},
            state
          )
      end
    end

    if type != APDU.SegmentACK do
      SegmentsStore.cancel(state.segments_store, endpoint, apdu)
    end

    case apdu do
      %APDU.Abort{sent_by_server: false} ->
        cancel_responder_reply(source_address, npci.source, apdu.invoke_id, portal, state)

      _other ->
        state
    end
  end

  defp handle_segmentation_control(_source_address, _bvlc, _npci, _apdu, _portal, state),
    do: state

  @spec cancel_responder_reply(
          term(),
          NpciTarget.t() | nil,
          byte(),
          TransportBehaviour.portal(),
          State.t()
        ) :: State.t()
  defp cancel_responder_reply(source_address, npci_id, invoke_id, portal, state) do
    reply_key = {source_address, npci_id, invoke_id}

    case Map.fetch(state.app_reply_timers, reply_key) do
      {:ok, %ReplyTimer{portal: ^portal} = reply} ->
        if reply.timer, do: Process.cancel_timer(reply.timer)

        %{
          state
          | app_reply_timers: Map.delete(state.app_reply_timers, reply_key),
            app_reply_mapping: Map.delete(state.app_reply_mapping, reply.ref)
        }

      _other ->
        state
    end
  end

  @spec segmentation_peer(term(), Protocol.bvlc()) :: term()
  defp segmentation_peer(_source_address, %BvlcForwardedNPDU{} = forwarded),
    do: {forwarded.originating_ip, forwarded.originating_port}

  defp segmentation_peer(source_address, _bvlc), do: source_address

  @spec handle_raw_apdu(
          term(),
          Protocol.bvlc(),
          NPCI.t(),
          binary(),
          TransportBehaviour.portal(),
          State.t()
        ) :: State.t()
  defp handle_raw_apdu(
         source_address,
         bvlc,
         %NPCI{} = npci,
         raw_apdu,
         portal,
         %State{transport_mod: trans_mod} = state
       ) do
    case APDU.decode(raw_apdu) do
      {:ok, apdu} ->
        Telemetry.execute_client_inc_apdu(self(), source_address, bvlc, npci, apdu, state)
        state = handle_segmentation_control(source_address, bvlc, npci, apdu, portal, state)
        handle_apdu(source_address, bvlc, npci, apdu, portal, state)

      {:incomplete, %IncompleteAPDU{} = incomplete} ->
        log_debug(fn ->
          "Client: Received fragmented APDU from #{inspect(source_address)}, " <>
            "invoke_id: #{incomplete.invoke_id}, seq_number: #{incomplete.sequence_number}, " <>
            "more_follows: #{inspect(incomplete.more_follows)}"
        end)

        # Derive NPCI ID from NPCI source
        npci_id = npci.source

        reply_key = {source_address, npci_id, incomplete.invoke_id}

        # When we receive a segmented response, we need to reset the APDU timer,
        # because with many segments, the single timeout (default 3s) is too short
        # The SegmentsStore module handles individual segment timeouts
        state =
          case Map.fetch(state.apdu_timers, reply_key) do
            {:ok, %ApduTimer{timer: ptimer} = timer}
            when not incomplete.server and not is_nil(ptimer) ->
              Process.cancel_timer(ptimer)

              %{
                state
                | apdu_timers:
                    Map.put(state.apdu_timers, reply_key, %{
                      timer
                      | timer:
                          Process.send_after(
                            self(),
                            {:apdu_timer, reply_key},
                            trunc(state.opts.apdu_timeout + @apdu_timer_offset)
                          )
                    })
              }

            _else ->
              state
          end

        incomplete_apdu =
          if state.opts.segmented_rcv_window_overwrite and
               trans_mod.destination_routed?(state.transport_pid, source_address) do
            IncompleteAPDU.set_window_size(incomplete, 1)
          else
            incomplete
          end

        case SegmentsStore.segment(
               state.segments_store,
               incomplete_apdu,
               trans_mod,
               portal,
               segmentation_peer(source_address, bvlc),
               destination: npci.source
             ) do
          {:ok, complete_data} ->
            log_debug(fn ->
              "Client: Completed fragmented APDU from #{inspect(source_address)}, invoke_id: #{incomplete.invoke_id}"
            end)

            Telemetry.execute_client_inc_apdu_segmentation_completed(
              self(),
              source_address,
              bvlc,
              npci,
              raw_apdu,
              complete_data,
              incomplete_apdu,
              state
            )

            handle_raw_apdu(source_address, bvlc, npci, complete_data, portal, state)

          :incomplete ->
            Telemetry.execute_client_inc_apdu_segmentation_incomplete(
              self(),
              source_address,
              bvlc,
              npci,
              raw_apdu,
              incomplete_apdu,
              state
            )

            state

          {:error, err, cancelled} ->
            log_debug(fn ->
              "Client: Got error from segments store for #{inspect(source_address)}, invoke_id: #{incomplete.invoke_id}, " <>
                "cancelled: #{inspect(cancelled)}, error: #{inspect(err)}"
            end)

            Telemetry.execute_client_inc_apdu_segmentation_error(
              self(),
              source_address,
              bvlc,
              npci,
              raw_apdu,
              incomplete_apdu,
              err,
              cancelled,
              state
            )

            state
        end

      {:error, err} ->
        Telemetry.execute_client_inc_apdu_decode_error(
          self(),
          source_address,
          bvlc,
          npci,
          raw_apdu,
          err,
          state
        )

        if is_tuple(err) and is_atom(elem(err, 0)) and
             String.starts_with?("#{elem(err, 0)}", "unknown_") do
          log_debug(fn ->
            "Client: Encountered unknown enumeration (constant) while decoding APDU, " <>
              if(npci.expects_reply, do: "sending Reject APDU to source, ", else: "") <>
              "error: #{inspect(err)}"
          end)

          if npci.expects_reply do
            send_reply_for_unknown_enumeration(
              source_address,
              bvlc,
              npci,
              raw_apdu,
              portal,
              state
            )
          else
            state
          end
        else
          log_debug(fn -> "Client: Got invalid APDU data, error: #{inspect(err)}" end)
          state
        end
    end

    # rescue
    #   e ->
    #     log_debug(fn ->
    #       "Client: Encountered exception while decoding APDU, " <>
    #         "exception: #{inspect(Exception.message(e))}"
    #     end)

    #     state
  end

  @spec handle_apdu(
          term(),
          Protocol.bvlc(),
          NPCI.t(),
          Protocol.apdu(),
          TransportBehaviour.portal(),
          State.t()
        ) :: State.t()
  defp handle_apdu(source_address, bvlc, npci, apdu, portal, state)

  # Do not handle APDU and send Reject APDU if no listener configured and reply expected
  # Unless this is a reply to one of the requests sent
  defp handle_apdu(
         source_address,
         bvlc,
         %NPCI{expects_reply: true} = npci,
         %apdu_type{invoke_id: invoke_id} = apdu,
         portal,
         %State{apdu_timers: apdu_timers, notification_receiver: []} = state
       )
       when not is_apdu_resp(apdu_type) or map_size(apdu_timers) == 0 do
    log_debug(fn ->
      "Client: Received APDU with reply expected and no listener, " <>
        "sending Reject APDU to source"
    end)

    # Derive NPCI ID from NPCI source
    npci_id = npci.source

    reject = %APDU.Reject{
      invoke_id: invoke_id,
      reason: Constants.macro_assert_name(:reject_reason, :other)
    }

    Telemetry.execute_client_inc_apdu_rejected(
      self(),
      source_address,
      bvlc,
      npci,
      reject,
      apdu,
      state
    )

    case send_data(
           reject,
           get_reply_opts_for_npci(reject, bvlc, npci, state),
           source_address,
           portal,
           npci_id,
           npci_id,
           false,
           nil,
           state,
           true
         ) do
      {:ok, new_state} ->
        new_state

      {:error, err} ->
        log_debug(fn ->
          "Client: Encountered error on sending Reject reply due to no listener, error: #{inspect(err)}"
        end)

        state
    end
  end

  # Do not handle APDU if there's no listener configured
  # Usually no reply is expected from us, but might be "expected" due to response
  # Unless this is a reply to one of the requests sent
  defp handle_apdu(
         _source_address,
         _bvlc,
         %NPCI{} = _npci,
         %apdu_type{} = _apdu,
         _portal,
         %State{apdu_timers: apdu_timers, notification_receiver: []} = state
       )
       when not is_apdu_resp(apdu_type) or map_size(apdu_timers) == 0 do
    state
  end

  # Handle APDU since we have a listener
  defp handle_apdu(source_address, bvlc, %NPCI{} = npci, apdu, portal, %State{} = state) do
    # Derive NPCI ID from NPCI source
    npci_id = npci.source

    # Get the invoke_id from the APDU (only relevant for confirmed requests)
    invoke_id = Map.get(apdu, :invoke_id)
    reply_key = {source_address, npci_id, invoke_id}

    # If confirmed service request, look up and see if it already exists, if it does, ignore it
    # If it does not exist yet, create an app reply timer to send Abort APDU to client on timeout
    {handle, ref, new_state} =
      check_for_duplicated_requests(
        npci_id,
        source_address,
        bvlc,
        npci,
        apdu,
        reply_key,
        portal,
        state
      )

    # case state.notification_receiver do
    #   [] -> :ok
    #   dest -> send_process_dest(dest, {:bacnet_client_info, self(), :apdu, bvlc, npci, {apdu, portal, ref}})
    # end

    log_debug(fn ->
      npci_info = if npci_id, do: ":NPCI-#{format_npci_target(npci_id)}"
      keyword = if handle, do: "handled", else: "ignored"

      "Client: Received APDU #{inspect(apdu.__struct__)} from #{inspect(source_address)}#{npci_info} to be #{keyword}"
    end)

    if handle do
      Telemetry.execute_client_inc_apdu_handled(self(), source_address, bvlc, npci, apdu, state)

      do_handle_apdu(ref, source_address, bvlc, npci, apdu, portal, npci_id, new_state)
    else
      Telemetry.execute_client_inc_apdu_duplicated(
        self(),
        source_address,
        bvlc,
        npci,
        apdu,
        state
      )

      new_state
    end
  end

  # If confirmed service request, look up and see if it already exists, if it does, ignore it
  # If it does not exist yet, create an app reply timer to send abort APDU to client on timeout
  @spec check_for_duplicated_requests(
          NpciTarget.t() | nil,
          term(),
          Protocol.bvlc(),
          NPCI.t(),
          Protocol.apdu(),
          term(),
          term(),
          State.t()
        ) :: {should_handle :: boolean(), reply_id :: reference() | nil, new_state :: State.t()}
  defp check_for_duplicated_requests(
         npci_id,
         source_address,
         bvlc,
         npci,
         apdu,
         reply_key,
         portal,
         state
       )

  defp check_for_duplicated_requests(
         npci_id,
         source_address,
         bvlc,
         %NPCI{} = npci,
         %ConfirmedServiceRequest{} = apdu,
         reply_key,
         portal,
         %State{} = state
       ) do
    case Map.fetch(state.app_reply_timers, reply_key) do
      # Duplicated request (same request by source_address, npci_id, invoke_id)
      {:ok, _reply} ->
        log_debug(fn ->
          npci_info = if npci_id, do: ":NPCI-#{format_npci_target(npci_id)}"

          "Client: Received duplicated request from " <>
            inspect(source_address) <> "#{npci_info} with invoke ID #{apdu.invoke_id}"
        end)

        {false, nil, state}

      :error ->
        # Get timeout or use default APDU timeout, and multiply with factor - the rest is our reserve to reply
        timeout =
          trunc(
            Map.get(
              state.apdu_timeouts,
              {source_address, npci_id},
              Map.get(state.apdu_timeouts, {source_address, nil}, state.opts.apdu_timeout)
            ) * @apdu_timeout_multiplicator
          )

        put_app_reply_timer(
          reply_key,
          %ReplyTimer{
            bvlc: bvlc,
            npci: npci,
            portal: portal,
            service_req: apdu,
            source_addr: source_address,
            npci_id: npci_id,
            ref: make_ref(),
            has_retried: false,
            monotonic_time: System.monotonic_time(),
            timer:
              unless(state.opts.disable_app_timeout,
                do: Process.send_after(self(), {:reply_timer, reply_key}, timeout)
              )
          },
          state
        )
    end
  end

  defp check_for_duplicated_requests(
         _npci_id,
         _source_address,
         _bvlc,
         _npci,
         _apdu,
         _reply_key,
         _portal,
         %State{} = state
       ),
       do: {true, nil, state}

  @spec put_app_reply_timer(
          term(),
          ReplyTimer.t(),
          State.t()
        ) :: {boolean(), reference(), State.t()}
  defp put_app_reply_timer(reply_key, reply_timer, %State{} = state) do
    {true, reply_timer.ref,
     %{
       state
       | app_reply_mapping: Map.put(state.app_reply_mapping, reply_timer.ref, reply_key),
         app_reply_timers: Map.put(state.app_reply_timers, reply_key, reply_timer)
     }}
  end

  @spec do_handle_apdu(
          reference() | nil,
          term(),
          Protocol.bvlc(),
          NPCI.t(),
          Protocol.apdu(),
          TransportBehaviour.portal(),
          NpciTarget.t() | nil,
          State.t()
        ) :: State.t()
  defp do_handle_apdu(ref, source_address, bvlc, npci, apdu, portal, npci_id, state)

  defp do_handle_apdu(
         ref,
         source_address,
         bvlc,
         %NPCI{} = npci,
         %APDU.Abort{sent_by_server: false} = apdu,
         portal,
         npci_id,
         %State{} = state
       ) do
    # A client Abort cancels our responder transaction, never our outgoing request
    send_notification_apdu(
      ref,
      source_address,
      bvlc,
      npci,
      apdu,
      portal,
      npci_id,
      state
    )
  end

  defp do_handle_apdu(
         ref,
         source_address,
         bvlc,
         %NPCI{} = npci,
         %ConfirmedServiceRequest{} = apdu,
         portal,
         npci_id,
         %State{} = state
       ) do
    send_notification_apdu(
      ref,
      source_address,
      bvlc,
      npci,
      apdu,
      portal,
      npci_id,
      state
    )
  end

  defp do_handle_apdu(
         ref,
         source_address,
         bvlc,
         %NPCI{} = npci,
         %APDU.UnconfirmedServiceRequest{} = apdu,
         portal,
         npci_id,
         %State{} = state
       ) do
    send_notification_apdu(
      ref,
      source_address,
      bvlc,
      npci,
      apdu,
      portal,
      npci_id,
      state
    )
  end

  defp do_handle_apdu(
         ref,
         source_address,
         bvlc,
         %NPCI{} = npci,
         %type{} = apdu,
         portal,
         npci_id,
         %State{} = state
       )
       when type in [APDU.ComplexACK, APDU.SimpleACK] do
    case remove_apdu_timer_for_response(source_address, apdu, npci_id, state) do
      {nil, new_state} ->
        send_notification_apdu(
          ref,
          source_address,
          bvlc,
          npci,
          apdu,
          portal,
          npci_id,
          new_state
        )

      {%ApduTimer{} = timer, new_state} ->
        Telemetry.execute_client_request_stop(
          self(),
          source_address,
          bvlc,
          npci,
          apdu,
          timer,
          state
        )

        GenServer.reply(timer.call_ref, {:ok, apdu})
        new_state
    end
  end

  defp do_handle_apdu(
         _ref,
         _source_address,
         _bvlc,
         %NPCI{} = _npci,
         %APDU.SegmentACK{},
         _portal,
         _npci_id,
         %State{} = state
       ) do
    state
  end

  defp do_handle_apdu(
         ref,
         source_address,
         bvlc,
         %NPCI{} = npci,
         %type{} = apdu,
         portal,
         npci_id,
         %State{} = state
       )
       when type in [APDU.Abort, APDU.Error, APDU.Reject] do
    case remove_apdu_timer_for_response(source_address, apdu, npci_id, state) do
      {nil, new_state} ->
        send_notification_apdu(
          ref,
          source_address,
          bvlc,
          npci,
          apdu,
          portal,
          npci_id,
          new_state
        )

      {%ApduTimer{} = timer, new_state} ->
        Telemetry.execute_client_request_stop(
          self(),
          source_address,
          bvlc,
          npci,
          apdu,
          timer,
          state
        )

        GenServer.reply(timer.call_ref, {:ok, apdu})
        new_state
    end
  end

  @spec update_free_invoke_ids(term(), NpciTarget.t() | nil, byte(), State.t()) :: State.t()
  defp update_free_invoke_ids(destination, npci_id, invoke_id, state) do
    key = {destination, npci_id}

    case Map.fetch(state.free_invoke_ids, key) do
      {:ok, queue} ->
        new = :queue.in(invoke_id, queue)

        new_ids =
          if :queue.len(new) == 256 do
            Map.delete(state.free_invoke_ids, key)
          else
            Map.put(state.free_invoke_ids, key, new)
          end

        %{state | free_invoke_ids: new_ids}

      :error ->
        state
    end
  end

  @spec remove_apdu_timer_for_response(
          term(),
          Protocol.apdu(),
          NpciTarget.t() | nil,
          State.t()
        ) ::
          {ApduTimer.t() | nil, State.t()}
  defp remove_apdu_timer_for_response(
         source_address,
         %{invoke_id: invoke_id} = _apdu,
         npci_id,
         state
       ) do
    reply_key = {source_address, npci_id, invoke_id}

    case Map.fetch(state.apdu_timers, reply_key) do
      {:ok, %ApduTimer{} = timer} ->
        if timer.timer, do: Process.cancel_timer(timer.timer)

        new_state = update_free_invoke_ids(timer.destination, timer.npci_id, invoke_id, state)
        {timer, %{new_state | apdu_timers: Map.delete(state.apdu_timers, reply_key)}}

      _else ->
        # If npci_id is not nil and we didn't find a APDU timer,
        # try to find a generic one (with explicit nil)
        if npci_id do
          reply_key2 = {source_address, nil, invoke_id}

          case Map.fetch(state.apdu_timers, reply_key2) do
            {:ok, %ApduTimer{} = timer} ->
              if timer.timer, do: Process.cancel_timer(timer.timer)

              new_state =
                update_free_invoke_ids(timer.destination, nil, invoke_id, state)

              {timer, %{new_state | apdu_timers: Map.delete(state.apdu_timers, reply_key2)}}

            _else ->
              {nil, state}
          end
        else
          {nil, state}
        end
    end
  end

  @spec send_notification_apdu(
          reference() | nil,
          term(),
          Protocol.bvlc(),
          NPCI.t(),
          Protocol.apdu(),
          TransportBehaviour.portal(),
          NpciTarget.t() | nil,
          State.t()
        ) :: State.t()
  defp send_notification_apdu(
         ref,
         source_address,
         bvlc,
         %NPCI{} = npci,
         apdu,
         _portal,
         _npci_id,
         %State{notification_receiver: dest} = state
       ) do
    send_process_dest(dest, {:bacnet_client, ref, apdu, {source_address, bvlc, npci}, self()})
    state
  end

  @spec send_process_dest(Process.dest() | [Process.dest()], term()) :: :ok
  defp send_process_dest(dest, msg) when is_list(dest) do
    Enum.each(dest, fn prc ->
      try do
        Kernel.send(prc, msg)
      catch
        # Ignore any exception coming from send/2 (an "invalid" destination raises!
        # [i.e. an atom but it's not registered])
        _type, _err -> :ok
      end
    end)
  end

  defp new_invoke_id_queue(), do: :queue.from_list(Enum.to_list(0..255//1))

  @spec find_free_invoke_id(term(), NpciTarget.t() | nil, State.t()) ::
          {:ok, byte(), State.t()} | :error
  defp find_free_invoke_id(destination, npci_id, %State{free_invoke_ids: free} = state) do
    key = {destination, npci_id}

    case Map.fetch(free, key) do
      {:ok, queue} ->
        case :queue.out(queue) do
          {{:value, id}, new} ->
            {:ok, id, %{state | free_invoke_ids: Map.put(free, key, new)}}

          {:empty, _queue} ->
            :error
        end

      :error ->
        # First request (or previously fully freed) for this destination
        {{:value, id}, new} = :queue.out(new_invoke_id_queue())
        {:ok, id, %{state | free_invoke_ids: Map.put(free, key, new)}}
    end
  end

  @spec send_data(
          Protocol.apdu(),
          Keyword.t(),
          term(),
          TransportBehaviour.portal(),
          NpciTarget.t() | nil,
          NpciTarget.t() | nil,
          boolean(),
          term() | nil,
          State.t(),
          boolean()
        ) :: {:ok, new_state :: State.t()} | {:error, term()} | {:retry, new_state :: State.t()}
  defp send_data(
         apdu,
         opts,
         destination,
         portal,
         npci_id,
         apdu_timer_npci_key,
         needs_tracking,
         call_ref,
         state,
         skip_invoke_id_check
       )

  defp send_data(
         %ConfirmedServiceRequest{} = apdu,
         opts,
         destination,
         portal,
         npci_id,
         apdu_timer_npci_key,
         needs_tracking,
         call_ref,
         %State{opts: %{disable_invoke_id_management: false}} = state,
         false
       )
       when (is_struct(npci_id, NpciTarget) or is_nil(npci_id)) and
              (is_struct(apdu_timer_npci_key, NpciTarget) or is_nil(apdu_timer_npci_key)) do
    case find_free_invoke_id(destination, npci_id, state) do
      {:ok, new_invoke_id, new_state} ->
        send_data(
          %{apdu | invoke_id: new_invoke_id},
          opts,
          destination,
          portal,
          npci_id,
          apdu_timer_npci_key,
          needs_tracking,
          call_ref,
          new_state,
          true
        )

      :error ->
        {:retry, state}
    end
  end

  defp send_data(
         apdu,
         opts,
         destination,
         portal,
         npci_id,
         apdu_timer_npci_key,
         needs_tracking,
         call_ref,
         %State{transport_mod: trans_mod} = state,
         _skip_invoke_id_check
       )
       when (is_struct(npci_id, NpciTarget) or is_nil(npci_id)) and
              (is_struct(apdu_timer_npci_key, NpciTarget) or is_nil(apdu_timer_npci_key)) do
    sys_mono_time = System.monotonic_time()
    key = {destination, apdu_timer_npci_key, Map.get(apdu, :invoke_id)}

    try do
      # Catch any errors when trying to encode the APDU
      bin = EncoderProtocol.encode(apdu)

      max_npdu_len =
        if function_exported?(trans_mod, :max_ext_npdu_length, 0) do
          trans_mod.max_ext_npdu_length()
        else
          trans_mod.max_npdu_length()
        end

      {bin, max_npdu_len}
    catch
      kind, e ->
        Telemetry.execute_client_exception(
          self(),
          kind,
          e,
          __STACKTRACE__,
          %{apdu: apdu, destination: destination},
          state
        )

        {:error, {e, __STACKTRACE__}}
    else
      {apdu_data, max_npdu_len} ->
        send_opts =
          opts
          |> kw_put_new(:source, state.opts.npci_source)
          |> Keyword.put_new(:is_broadcast, state.transport_broadcast_addr == destination)

        {result, apdu_too_long} =
          do_send_data(
            apdu,
            send_opts,
            destination,
            portal,
            npci_id,
            apdu_timer_npci_key,
            state,
            {apdu_data, max_npdu_len}
          )

        if needs_tracking do
          case result do
            :ok ->
              timer = %ApduTimer{
                portal: portal,
                destination: destination,
                npci_id: npci_id,
                apdu: apdu,
                send_opts: opts,
                call_ref: call_ref,
                # If we're sending segmented, the Segmentator handles re-sending,
                # so we only need to wait for it to timeout (or possibly get a reply)
                retry_count: if(apdu_too_long, do: state.opts.apdu_retries, else: 0),
                monotonic_time: sys_mono_time,
                # If we're sending segmented,
                # the timer will be setup when the Segmentator reports back
                timer:
                  if(apdu_too_long,
                    do: nil,
                    else:
                      Process.send_after(
                        self(),
                        {:apdu_timer, key},
                        trunc(state.opts.apdu_timeout + @apdu_timer_offset)
                      )
                  )
              }

              Telemetry.execute_client_request_start(
                self(),
                destination,
                apdu,
                send_opts,
                timer,
                state
              )

              new_state = %{state | apdu_timers: Map.put(state.apdu_timers, key, timer)}
              {:ok, new_state}

            {:error, _err} = err ->
              err
          end
        else
          case result do
            :ok -> {:ok, state}
            term -> term
          end
        end
    end
  end

  @spec do_send_data(
          Protocol.apdu(),
          Keyword.t(),
          term(),
          TransportBehaviour.portal(),
          NpciTarget.t() | nil,
          NpciTarget.t() | nil,
          State.t(),
          {iodata(), non_neg_integer()}
        ) :: {result :: :ok | {:error, term()}, apdu_too_long :: boolean()}
  defp do_send_data(
         apdu,
         send_opts,
         destination,
         portal,
         npci_id,
         apdu_timer_npci_key,
         %State{transport_mod: trans_mod} = state,
         {apdu_data, max_npdu_len}
       )
       when (is_struct(npci_id, NpciTarget) or is_nil(npci_id)) and
              (is_struct(apdu_timer_npci_key, NpciTarget) or is_nil(apdu_timer_npci_key)) do
    key = {destination, apdu_timer_npci_key, Map.get(apdu, :invoke_id)}

    # Reserve NPCI space in the transport's NPDU budget before applying the
    # peer's complete APDU limit. The encoder reserves each segment's APCI
    transport_apdu_len =
      max_npdu_len - 2 - if(send_opts[:source], do: 9, else: 0) -
        if(send_opts[:destination], do: 10, else: 0)

    max_apdu_len =
      min(
        max(Keyword.get(send_opts, :max_apdu_length, transport_apdu_len), 50),
        transport_apdu_len
      )

    apdu_length = IO.iodata_length(apdu_data)
    max_segments = send_opts[:max_segments] || 2

    apdu_too_long = apdu_length > max_apdu_len
    apdu_supports_seg = EncoderProtocol.supports_segmentation(apdu)
    supports_segments = supports_segmentation(send_opts[:segmentation_supported])

    result =
      cond do
        apdu_too_long and not apdu_supports_seg ->
          # If segmentation is not supported by the APDU type,
          # send an abort and indiciate Abort APDU_TOO_LONG,
          # but only if this is not a request to a remote device
          resp =
            if EncoderProtocol.response?(apdu) do
              abort = %APDU.Abort{
                sent_by_server: true,
                invoke_id: apdu.invoke_id,
                reason: Constants.macro_assert_name(:abort_reason, :apdu_too_long)
              }

              Telemetry.execute_client_send_error(
                self(),
                destination,
                apdu,
                send_opts,
                abort,
                :apdu_too_long,
                state
              )

              trans_mod.send(portal, destination, abort, transport_send_opts(send_opts))
            else
              :ok
            end

          # Return the send error if present, or our error (no error swallowing)
          with :ok <- resp do
            {:error, :apdu_too_long}
          end

        apdu_too_long and not supports_segments ->
          # Segmentation not supported by the remote device,
          # indicate Abort SEGMENTATION_NOT_SUPPORTED,
          # but only if this is a response,
          # if this is a request, we do not need to send anything
          resp =
            if EncoderProtocol.response?(apdu) do
              abort = %APDU.Abort{
                sent_by_server: true,
                invoke_id: apdu.invoke_id,
                reason: Constants.macro_assert_name(:abort_reason, :segmentation_not_supported)
              }

              Telemetry.execute_client_send_error(
                self(),
                destination,
                apdu,
                send_opts,
                abort,
                :apdu_segmentation_unsupported,
                state
              )

              trans_mod.send(portal, destination, abort, transport_send_opts(send_opts))
            else
              :ok
            end

          # Return the send error if present, or our error (no error swallowing)
          with :ok <- resp do
            {:error, :segmentation_not_supported}
          end

        apdu_too_long ->
          Telemetry.execute_client_send(
            self(),
            destination,
            apdu,
            send_opts,
            true,
            state
          )

          seg_opts =
            send_opts
            |> transport_send_opts()
            |> Keyword.put(:callback_to, self())
            |> Keyword.put(
              :callback_msg,
              {:apdu_timer_setup,
               SegmentationEndpoint.new(trans_mod, portal, destination, send_opts),
               if(is_struct(apdu, ConfirmedServiceRequest), do: :requester, else: :responder),
               key}
            )

          Segmentator.create_sequence(
            state.segmentator,
            {trans_mod, state.transport_pid, portal},
            destination,
            {%{
               apdu
               | proposed_window_size:
                   Map.get(apdu, :proposed_window_size) || @default_window_size
             }, apdu_data},
            max_apdu_len,
            max_segments,
            seg_opts
          )

        true ->
          Telemetry.execute_client_send(
            self(),
            destination,
            apdu,
            send_opts,
            false,
            state
          )

          trans_mod.send(portal, destination, apdu_data, transport_send_opts(send_opts))
      end

    {result, apdu_too_long}
  end

  @spec send_reply_for_unknown_enumeration(
          term(),
          Protocol.bvlc(),
          NPCI.t(),
          binary(),
          TransportBehaviour.portal(),
          State.t()
        ) :: State.t()
  defp send_reply_for_unknown_enumeration(
         source_address,
         bvlc,
         %NPCI{} = npci,
         raw_apdu,
         portal,
         %State{} = state
       ) do
    case APDU.get_invoke_id_from_raw_apdu(raw_apdu) do
      {:ok, invoke_id} ->
        npci_id = npci.source

        reject = %APDU.Reject{
          invoke_id: invoke_id,
          reason: Constants.macro_assert_name(:reject_reason, :undefined_enumeration)
        }

        case send_data(
               reject,
               get_reply_opts_for_npci(reject, bvlc, npci, state),
               source_address,
               portal,
               npci_id,
               npci_id,
               false,
               nil,
               state,
               true
             ) do
          {:ok, new_state} ->
            new_state

          {:error, err} ->
            log_debug(fn ->
              "Client: Encountered error on sending Reject reply due to unknown enumeration, error: #{inspect(err)}"
            end)

            state
        end

      _else ->
        log_debug(fn ->
          "Client: Unable to extract invoke ID from invalid APDU (caused by unknown enumeration)"
        end)

        state
    end
  end

  @spec supports_segmentation(Constants.segmentation() | term()) :: boolean()
  defp supports_segmentation(Constants.macro_assert_name(:segmentation, :segmented_both)),
    do: true

  defp supports_segmentation(Constants.macro_assert_name(:segmentation, :segmented_receive)),
    do: true

  defp supports_segmentation(_term), do: false

  @spec get_reply_opts_for_npci(Protocol.apdu(), Protocol.bvlc(), NPCI.t(), State.t()) ::
          Keyword.t()
  defp get_reply_opts_for_npci(_apdu, _bvlc, %NPCI{} = npci, %State{} = _state) do
    # Source gets always set in send_data/8
    kw_put_lazy([], :destination, get_reply_opts_destination(npci))
  end

  defp get_reply_opts_destination(%NPCI{source: %NpciTarget{} = src} = _npci) do
    src
  end

  defp get_reply_opts_destination(%NPCI{} = _npci) do
    nil
  end

  # These options drive segmentation inside the client
  # The transport send does not understand them
  @spec transport_send_opts(Keyword.t()) :: Keyword.t()
  defp transport_send_opts(opts) do
    Keyword.drop(opts, [:max_apdu_length, :max_segments, :segmentation_supported])
  end

  @spec kw_put_lazy(Keyword.t(), atom(), term()) :: Keyword.t()
  defp kw_put_lazy(kw, _key, nil), do: kw
  defp kw_put_lazy(kw, key, val), do: Keyword.put(kw, key, val)

  @spec kw_put_new(Keyword.t(), atom(), term() | nil) :: Keyword.t()
  defp kw_put_new(kw, _key, nil), do: kw
  defp kw_put_new(kw, key, val), do: Keyword.put_new(kw, key, val)

  # credo:disable-for-lines:50 Credo.Check.Refactor.CyclomaticComplexity
  defp validate_start_link_opts(opts, mfa, skip_check \\ false)
       when is_binary(mfa) and is_boolean(skip_check) do
    case opts[:apdu_retries] do
      nil ->
        :ok

      term when is_integer(term) and term >= 0 ->
        :ok

      term ->
        raise ArgumentError,
              mfa <>
                " expected apdu_retries to be a non negative integer, " <>
                "got: #{inspect(term)}"
    end

    case opts[:apdu_timeout] do
      nil ->
        :ok

      term when is_integer(term) and term > 0 ->
        :ok

      term ->
        raise ArgumentError,
              mfa <>
                " expected apdu_timeout to be a positive integer, " <>
                "got: #{inspect(term)}"
    end

    case opts[:disable_app_timeout] do
      nil ->
        :ok

      term when is_boolean(term) ->
        :ok

      term ->
        raise ArgumentError,
              mfa <>
                " expected disable_app_timeout to be a boolean, " <>
                "got: #{inspect(term)}"
    end

    case opts[:disable_invoke_id_management] do
      nil ->
        :ok

      term when is_boolean(term) ->
        :ok

      term ->
        raise ArgumentError,
              mfa <>
                " expected disable_invoke_id_management to be a boolean, " <>
                "got: #{inspect(term)}"
    end

    case opts[:notification_receiver] do
      nil ->
        :ok

      term when is_atom(term) ->
        :ok

      term when is_pid(term) ->
        :ok

      term when is_port(term) ->
        :ok

      term when is_tuple(term) and tuple_size(term) == 2 ->
        :ok

      term when is_list(term) ->
        unless Enum.all?(
                 term,
                 &(is_atom(&1) or is_pid(&1) or is_port(&1) or
                     (is_tuple(&1) and tuple_size(&1) == 2))
               ) do
          raise ArgumentError,
                mfa <>
                  " expected notification_receiver to be a Process destination or " <>
                  "list of Process destinations, got: #{inspect(term)}"
        end

      term ->
        raise ArgumentError,
              mfa <>
                " expected notification_receiver to be a Process destination or " <>
                "list of Process destinations, got: #{inspect(term)}"
    end

    case opts[:npci_source] do
      nil ->
        :ok

      %NpciTarget{} ->
        :ok

      term ->
        raise ArgumentError,
              mfa <>
                " expected npci_source to be a NpciTarget, " <>
                "got: #{inspect(term)}"
    end

    case opts[:segmentator] do
      term when is_atom(term) ->
        :ok

      term when is_pid(term) ->
        :ok

      term when is_tuple(term) and tuple_size(term) == 2 ->
        :ok

      term when is_tuple(term) and tuple_size(term) == 3 ->
        :ok

      term ->
        raise ArgumentError,
              mfa <>
                " expected segmentator to be a GenServer name, " <>
                "got: #{inspect(term)}"
    end

    case opts[:segments_store] do
      term when is_atom(term) ->
        :ok

      term when is_pid(term) ->
        :ok

      term when is_tuple(term) and tuple_size(term) == 2 ->
        :ok

      term when is_tuple(term) and tuple_size(term) == 3 ->
        :ok

      term ->
        raise ArgumentError,
              mfa <>
                " expected segments_store to be a GenServer name, " <>
                "got: #{inspect(term)}"
    end

    case opts[:segmented_rcv_window_overwrite] do
      nil ->
        :ok

      term when is_boolean(term) ->
        :ok

      term ->
        raise ArgumentError,
              mfa <>
                " expected segmented_rcv_window_overwrite to be a boolean, " <>
                "got: #{inspect(term)}"
    end

    transport = opts[:transport]

    case transport do
      mod when is_atom(mod) ->
        :ok

      {mod, term} when is_atom(mod) and is_atom(term) ->
        :ok

      {mod, term} when is_atom(mod) and is_pid(term) ->
        :ok

      {mod, term} when is_atom(mod) and is_port(term) ->
        :ok

      {mod, term} when is_atom(mod) and is_tuple(term) and tuple_size(term) == 2 ->
        :ok

      {mod, term} when is_atom(mod) and is_tuple(term) and tuple_size(term) == 3 ->
        :ok

      term ->
        raise ArgumentError,
              mfa <>
                " expected transport to be a tuple of module name " <>
                "and TransportBehaviour.transport(), got: #{inspect(term)}"
    end

    if not skip_check do
      # Unwrap the transport module name
      {transport_mod, _pid} =
        case transport do
          {mod, pid} -> {mod, pid}
          mod -> {mod, nil}
        end

      unless Code.ensure_loaded?(transport_mod) do
        raise ArgumentError, "Given transport module #{inspect(transport_mod)} is not loaded"
      end

      unless Enum.any?(transport_mod.__info__(:attributes), fn
               {:behaviour, TransportBehaviour} -> true
               {:behaviour, [TransportBehaviour]} -> true
               _else -> false
             end) do
        raise ArgumentError,
              "Given transport module #{inspect(transport_mod)} does not " <>
                "implement the BACnet transport behaviour"
      end
    end
  end

  defp validate_send_opts(opts, function) when is_list(opts) and is_binary(function) do
    # Validate send options
    Enum.each(opts, fn
      {:npci_id, npci_id} ->
        unless is_struct(npci_id, NpciTarget) or is_nil(npci_id) do
          raise ArgumentError,
            message:
              "#{function} expected npci_id in opts to be nil " <>
                " or a NpciTarget struct, got: " <> inspect(npci_id)
        end

      {:max_apdu_length, max_apdu_length} ->
        unless is_integer(max_apdu_length) and max_apdu_length > 0 do
          raise ArgumentError,
            message:
              "#{function} expected max_apdu_length in opts to be " <>
                "a positive integer, got: " <> inspect(max_apdu_length)
        end

      {:max_segments, max_segments} ->
        unless is_integer(max_segments) and max_segments > 0 do
          raise ArgumentError,
            message:
              "#{function} expected max_segments in opts to be " <>
                "a positive integer, got: " <> inspect(max_segments)
        end

      {:segmentation_supported, segmentation_supported} ->
        unless Constants.has_by_name(:segmentation, segmentation_supported) do
          raise ArgumentError,
            message:
              "#{function} expected segmentation_supported in opts to be " <>
                "a valid atom, got: " <> inspect(segmentation_supported)
        end

      # Unknown option - ignore
      _else ->
        nil
    end)
  end

  defp format_npci_target(%NpciTarget{} = target) do
    "#{target.net}.#{target.address}"
  end
end
