# `BACnet.Stack.Client`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/client.ex#L1)

The BACnet client is responsible for connecting the application to the BACnet transport protocol
and vice versa - it interfaces with the BACnet transport protocol, using the transport behaviour.
The client will take requests and send them to the BACnet transport protocol and ultimately listen for
frames from the BACnet transport protocol.

The application will receive process messages on the specified `notification_receiver`. If there's no
notification receiver and a confirmed service request is received, the client will automatically send
a Reject APDU with reason `:other` to the remote BACnet device,
the application won't be informed in any way.

BACnet BVLL and BACnet NPDU are directly forwarded to the application, without any processing.

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

Invoke IDs are automatically managed on a per destination (with device ID, if given) basis to avoid
duplicated invoke IDs being sent to the same destination.
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

# `apdu_timeouts`

```elixir
@type apdu_timeouts() :: %{
  optional({source_address :: term(), device_id :: non_neg_integer() | nil}) =&gt;
    apdu_timeout :: non_neg_integer()
}
```

Per-source APDU timeouts.

Device ID is only known, if the source transmits it with the APDU,
as such, most of the time it can be nil.

# `server`

```elixir
@type server() :: GenServer.server()
```

Represents a server process of the Client module.

# `start_option`

```elixir
@type start_option() ::
  {:apdu_retries, pos_integer()}
  | {:apdu_timeout, pos_integer()}
  | {:disable_app_timeout, boolean()}
  | {:disable_invoke_id_management, boolean()}
  | {:notification_receiver, Process.dest() | [Process.dest()]}
  | {:npci_source, BACnet.Protocol.NpciTarget.t()}
  | {:segmentator, BACnet.Stack.Segmentator.server()}
  | {:segments_store, BACnet.Stack.SegmentsStore.server()}
  | {:segmented_rcv_window_overwrite, boolean()}
  | {:transport,
     module() | {module(), BACnet.Stack.TransportBehaviour.transport()}}
  | GenServer.option()
```

Valid start options. For a description of each, see `start_link/1`.

# `start_options`

```elixir
@type start_options() :: [start_option()]
```

List of start options.

# `add_apdu_timeout`

```elixir
@spec add_apdu_timeout(server(), term(), non_neg_integer() | nil, non_neg_integer()) ::
  :ok
```

Add a source to the per-source APDU timeouts map. This is only used for receiving.

Each source is identified by source address and device ID (device ID
is only known if the source transmit it in the BACnet NPCI).

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `get_apdu_timeouts`

```elixir
@spec get_apdu_timeouts(server()) :: {:ok, apdu_timeouts()}
```

Get the per-source APDU timeouts map. This is only used for receiving.

Each source is identified by source address and device ID (device ID
is only known if the source transmit it in the BACnet NPCI).

# `get_transport`

```elixir
@spec get_transport(server()) ::
  {module(), BACnet.Stack.TransportBehaviour.transport(),
   BACnet.Stack.TransportBehaviour.portal()}
```

Get the transport used in the client.

# `remove_apdu_timeout`

```elixir
@spec remove_apdu_timeout(server(), term(), non_neg_integer() | nil) :: :ok
```

Remove a source from the per-source APDU timeouts map. This is only used for receiving.

Each source is identified by source address and device ID (device ID
is only known if the source transmit it in the BACnet NPCI).

# `reply`

```elixir
@spec reply(server(), reference(), BACnet.Protocol.apdu(), Keyword.t()) ::
  :ok
  | {:error, :app_timeout}
  | {:error, term()}
  | {:error, {Exception.t(), stacktrace :: Exception.stacktrace()}}
```

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

# `send`

```elixir
@spec send(server(), term(), BACnet.Protocol.apdu(), Keyword.t()) ::
  :ok
  | {:ok, BACnet.Protocol.apdu()}
  | {:error, :apdu_timeout}
  | {:error, :apdu_too_long}
  | {:error, :segmentation_not_supported}
  | {:error, term()}
  | {:error, {Exception.t(), stacktrace :: Exception.stacktrace()}}
  | {:error, {term(), stacktrace :: Exception.stacktrace()}}
```

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
  - `device_id: pos_integer()` - Optional. The remote BACnet device ID.
    Only used for invoke ID management together with the destination address.
    Specifying it allows invoke IDs to be used on a per device ID basis,
    if multiple devices run on the same destination address (i.e. MS/TP to IP gateway).
    Please note, if wrongfully used, this may lead to collisions and invalid data -
    including  replies sent to requests that were never meant for that request.
  - `max_apdu_length: pos_integer()` - Optional. The maximum APDU length
    the remote BACnet device supports (defaults to the transport max APDU length).
  - `max_segments: pos_integer()` - Optional. Maximum amount of segments the
    remote BACnet device can accept (defaults to 2).
  - `segmentation_supported: Constants.segmentation()` - Optional. Which kind
    of segmentation the remote BACnet device supports (defaults to none).

This function may be subject to outgoing APDU validation.

# `set_apdu_timeouts`

```elixir
@spec set_apdu_timeouts(server(), apdu_timeouts()) :: :ok
```

Set the per-source APDU timeouts map. This is only used for receiving.

Each source is identified by source address and device ID (device ID
is only known if the source transmit it in the BACnet NPCI).

# `start_link`

```elixir
@spec start_link(start_options()) :: GenServer.on_start()
```

Starts and links the BACnet Client.

The following options are available, in addition to `t:GenServer.options/0`:
  - `apdu_retries: pos_integer()` - Optional. The amount of APDU sending retries (defaults to 3).
    Only applied to confirmed service requests.
  - `apdu_timeout: pos_integer()` - Optional. The APDU timeout to be waiting for a response, in ms (defaults to 3000ms).
    Only applied to confirmed service requests.
  - `disable_app_timeout: boolean()` - Optional. Disables the application timeout mechanism.
  - `disable_invoke_id_management: boolean()` - Optional. Disables `invoke_id` management and override in request payloads.
  - `notification_receiver: Process.dest() | [Process.dest()]` - Optional. The destination to send messages to.
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

# `subscribe`

```elixir
@spec subscribe(server(), pid() | Process.dest() | GenServer.server()) :: :ok
```

Puts the subscriber in the `notification_receiver` list.
The list contains only unique elements, so this function call is idempotent.

After this function returns, the subscriber will start to receive
process messages as lined out by the module documentation.

If `subscriber` is a PID, it will be monitored and automatically removed.
This means for short lived processes, using the PID is recommended
as the PID is automatically removed when the process dies.

# `unsubscribe`

```elixir
@spec unsubscribe(server(), pid() | Process.dest() | GenServer.server()) :: :ok
```

Removes the subscriber from the `notification_receiver` list.

After this function returns, the subscriber will stop receiving
process messages as lined out by the module documentation.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
