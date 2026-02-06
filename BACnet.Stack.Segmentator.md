# `BACnet.Stack.Segmentator`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/segmentator.ex#L1)

The Segmentator module is responsible for sending segmented requests or responses.
Incoming segments need to be handled manually or through the `BACnet.Stack.SegmentsStore` module.

The Segmentator segments the given APDU (`ComplexACK` or `ConfirmedServiceRequest`) into segments
of maximum APDU size and checks if the remote device supports the amount of segments.
Both parameters need to be discovered by the user and given to this module, when creating a segmented sequence.

The Segmentator will automatically send segments in the window size given by the remote device and
wait for their acknowledgement. Timeouts and retransmissions are handled automatically.
Responses and retransmissions to the destination of a segmented request or response are automatically sent.

When the remote device is outside of the local network (packets are routed through a router),
this module will automatically overwrite the "Proposed Window Size" with 1, to ensure segments ordering.
Due to the nature of the UDP protocol (which BACnet/IP is based on), UDP re-ordering can occur and thus
segments may arrive out-of-order.
Re-ordering through the network may not occurr on other transport mediums. Whether a destination is outside
of the local network is determined through the `BACnet.Stack.TransportBehaviour` module.

The Segmentator module is transport layer agnostic due to the nature of using the `TransportBehaviour`.

Users of this module need to route incoming `Abort`, `Error`, `Reject` and `SegmentACK` APDUs to this module,
so the Segmentator can function properly. See the `handle_apdu/3` documentation.

This module is written to not require one instance per destination or transport layer protocol, as such when creating
a new sequence, the transport module, transport, portal, and destination parameters need to be given.

When wanting to send a new segmented request or response, first a new sequence must be created. As soon as the sequence
is created, transmitting the segments, retransmissions and timeouts are handled automatically.

# `server`

```elixir
@type server() :: GenServer.server()
```

Represents a server process of the Segmentator module.

# `start_option`

```elixir
@type start_option() ::
  {:apdu_retries, pos_integer()}
  | {:apdu_timeout, pos_integer()}
  | GenServer.option()
```

Valid start options. For a description of each, see `start_link/1`.

# `start_options`

```elixir
@type start_options() :: [start_option()]
```

List of start options.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `create_sequence`

```elixir
@spec create_sequence(
  server(),
  {transport_module :: module(),
   transport :: BACnet.Stack.TransportBehaviour.transport(),
   portal :: BACnet.Stack.TransportBehaviour.portal()},
  term(),
  BACnet.Protocol.APDU.ConfirmedServiceRequest.t()
  | BACnet.Protocol.APDU.ComplexACK.t(),
  non_neg_integer(),
  non_neg_integer(),
  Keyword.t()
) :: :ok | {:error, term()}
```

Creates a new Sequence for an APDU.

This module will automatically send the segments or abort APDUs.
Received `Abort` and `SegmentACK` APDUs need to be piped into this module through `handle_apdu/3`.

The `opts` argument will be passed on to the transport module's send function without modification.

# `handle_apdu`

```elixir
@spec handle_apdu(
  server(),
  term(),
  BACnet.Protocol.APDU.Abort.t()
  | BACnet.Protocol.APDU.Error.t()
  | BACnet.Protocol.APDU.Reject.t()
  | BACnet.Protocol.APDU.SegmentACK.t()
) :: :ok | {:error, term()}
```

Handles incoming `Abort`, `Error`, `Reject` and `SegmentACK` APDUs.

Received `Abort`, `Error`, `Reject` and `SegmentACK` APDUs need to be piped into this module using this function.
Only then this module can automatically function correctly and transmit or retransmit the segments.

Unknown destination-invoke ID mappings are silently ignored. As such the user can simply call this function
with all matching APDUs. Although if there is a lot of traffic, the user should consider filtering and only
call this function with interesting APDUs (APDUs for segmented requests/responses).

# `start_link`

```elixir
@spec start_link(start_options()) :: GenServer.on_start()
```

Starts and links the Segmentator.

The following options need to be given, in addition to `t:GenServer.options/0`:
  - `apdu_retries: pos_integer()` - Optional. The amount of APDU sending retries (defaults to 3).
  - `apdu_timeout: pos_integer()` - Optional. The APDU timeout to be waiting for a response, in ms (defaults to 3000ms).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
