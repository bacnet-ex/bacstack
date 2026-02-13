# `BACnet.Stack.SegmentsStore`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/segments_store.ex#L1)

The Segments Store module handles incoming segments of a segmented request or response.
Outgoing segments need to be handled manually or through the `BACnet.Stack.Segmentator` module.

New segment sequences are automatically created when receiving a segmented request or response,
through the `segment/6` function. Responses to the source of a segmented request or response are
automatically sent.

Users of this module need to route incoming `Abort`, `Error`, `Reject` and segmented APDUs
(identified by the `:incomplete` tuple of `BACnet.APDU.decode/1`) to this module,
so the Segments Store can function properly. See the `cancel/3` and `segment/6` documentation.

The Segments Store module is transport layer agnostic due to the nature of using
the `BACnet.Stack.TransportBehaviour`.

This module is written to not require one instance per destination or transport layer protocol,
as such when handling a segment, the transport module, portal, and source address need to be given.

Please note that in some circumstances, such as BACnet/IP and IP routing, the packets are under subject
to packet re-ordering. To address this, you may overwrite the window size field for packets outside
of the local network using `BACnet.IncompleteAPDU.set_window_size/2` before calling `segment/6`.
The value should be set to `1`, so for each segment an acknowledge needs to be sent (thus preventing
packet re-ordering and packets arriving out of order).

# `server`

```elixir
@type server() :: GenServer.server()
```

Represents a server process of the Segments Store module.

# `start_option`

```elixir
@type start_option() ::
  {:apdu_retries, pos_integer()}
  | {:apdu_timeout, pos_integer()}
  | {:max_segments, BACnet.Protocol.Constants.max_segments()}
  | GenServer.option()
```

Valid start options. For a description of each, see `start_link/1`.

# `start_options`

```elixir
@type start_options() :: [start_option()]
```

List of start options.

# `cancel`

```elixir
@spec cancel(
  server(),
  term(),
  BACnet.Protocol.APDU.Abort.t()
  | BACnet.Protocol.APDU.Error.t()
  | BACnet.Protocol.APDU.Reject.t()
  | BACnet.Protocol.APDU.SimpleACK.t()
  | (invoke_id :: 0..255)
) :: :ok
```

Cancels a segment sequence in the Store.

This function must be called by the user when one of the following conditions is met:
  - Abort PDU received with the same invoke ID
  - Error PDU received with the same invoke ID
  - Reject PDU received with the same invoke ID
  - SimpleACK PDU received with the same invoke ID

This function does nothing if no sequence exists in the Store, thus it is safe to call it,
even if no segmentation is in progress. Although if there is a lot of traffic, the user
should consider filtering and only call this function with interesting
APDUs (APDUs for segmented requests/responses).

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `segment`

```elixir
@spec segment(
  server(),
  BACnet.Protocol.IncompleteAPDU.t(),
  module(),
  BACnet.Stack.TransportBehaviour.portal(),
  term(),
  Keyword.t()
) ::
  {:ok, complete_data :: binary()}
  | :incomplete
  | {:error, term(), cancel :: boolean()}
```

Sends a segment to the Store to be handled. `cancel` specifies whether segmentation is aborted/cancelled.

If no segment sequence for the source address and invoke ID exist yet, one will be created automatically. Sequences
aborted by the Store are automatically removed from it and the remote BACnet device is notified.

Once all segments have been received, an ok-tuple is returned with the complete APDU binary data,
which then can be decoded using the `BACnet.Protocol` module.

This module sends answers directly to the remote BACnet device, as such the transport module and portal needs to be specified.

The `opts` argument will be passed on to the transport module's send function without modification.

# `start_link`

```elixir
@spec start_link(start_options()) :: GenServer.on_start()
```

Starts and links the Segments Store.

The following options are available, in addition to `t:GenServer.options/0`:
  - `apdu_retries: pos_integer()` - Optional. The amount of APDU sending retries (defaults to 3).
  - `apdu_timeout: pos_integer()` - Optional. The APDU timeout to be waiting for a response, in ms (defaults to 3000ms).
  - `max_segments: Constants.max_segments()` - Optional. The maximum amount of segments to allow (defaults to `:more_than_64`).
    While `:unspecified` is allowed here, it shouldn't be used anywhere, because it makes it for the server unable to determine
    if the response is transmittable. Since this setting here does not go to the server, `:unspecified` is allowed here.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
