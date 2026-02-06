# `BACnet.Stack.TransportBehaviour`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/transport_behaviour.ex#L1)

Defines the BACnet transport protocol behaviour.

It ensures all implemented transport layer can be easily integrated
into the Elixir BACnet client, indepedently of the underlying
physical transport layer (IP, MS/TP, etc.).

# `portal`

```elixir
@type portal() :: pid() | port() | :socket.socket() | term()
```

Represents a transport module portal.

# `transport`

```elixir
@type transport() :: pid() | port() | GenServer.server() | :socket.socket() | term()
```

Represents a transport module reference.

# `transport_callback`

```elixir
@type transport_callback() ::
  mfa()
  | Process.dest()
  | (source_address :: term(),
     frame :: transport_cb_frame(),
     portal :: portal() -&gt;
       any())
```

Transport callback.

Callback may be a Module-Function-Arity tuple, a PID (where the data is sent to as a message)
or an anonymous function.
The MFA has the same arguments as the anonymous function. As such, the arity needs to be 3.
The return value is ignored.

# `transport_cb_frame`

```elixir
@type transport_cb_frame() ::
  {:bvlc, bvlc :: BACnet.Protocol.bvlc()}
  | {:network, bvlc :: BACnet.Protocol.bvlc(),
     npci :: BACnet.Protocol.NPCI.t() | nil,
     nsdu :: BACnet.Protocol.NetworkLayerProtocolMessage.t()}
  | {:apdu, bvlc :: BACnet.Protocol.bvlc(),
     npci :: BACnet.Protocol.NPCI.t() | nil, apdu :: binary()}
```

Transport Callback Frames. The callback may ignore any non-APDU frames, if they do not
wish to handle them.

The APDU is uninterpreted binary data and needs to be decoded first, through the `BACnet.Protocol` module.

# `transport_id`

```elixir
@type transport_id() :: {transport_protocol(), module()}
```

BACnet transport identifier, represented by the protocol and the implementing transport module.

# `transport_msg`

```elixir
@type transport_msg() ::
  {:bacnet_transport, transport_id(), source_address :: term(),
   data :: transport_cb_frame(), portal :: portal()}
```

Transport message structure.

# `transport_protocol`

```elixir
@type transport_protocol() ::
  :bacnet_arcnet
  | :bacnet_ethernet
  | :bacnet_ipv4
  | :bacnet_ipv6
  | :bacnet_lontalk
  | :bacnet_mstp
  | :bacnet_ptp
  | :bacnet_sc
```

BACnet transport protocols.

# `transport_send_option`

```elixir
@type transport_send_option() ::
  {:destination, BACnet.Protocol.NpciTarget.t()}
  | {:npci, BACnet.Protocol.NPCI.t() | false}
  | {:skip_headers, boolean()}
  | {:source, BACnet.Protocol.NpciTarget.t()}
```

Valid transport send options. For a description of each, see `c:send/4`.

# `bacnet_protocol`

```elixir
@callback bacnet_protocol() :: transport_protocol()
```

Get the BACnet transport protocol this transport implements.

# `close`

```elixir
@callback close(transport :: transport()) :: :ok
```

Closes the Transport module.

# `get_broadcast_address`

```elixir
@callback get_broadcast_address(transport :: transport()) :: term()
```

Get the broadcast address.

# `get_local_address`

```elixir
@callback get_local_address(transport :: transport()) :: term()
```

Get the local address.

# `get_portal`

```elixir
@callback get_portal(transport :: transport()) :: portal()
```

Get the transport module portal for the given transport PID/port.
Transport modules may return the input as output, if the same
PID or port is used for sending.

This is used to get the portal before having received data from
the transport module, so data can be sent prior to reception.

# `is_destination_routed`

```elixir
@callback is_destination_routed(transport :: transport(), address :: term()) :: boolean()
```

Checks whether the given destination is an address that needs to be routed.

# `is_valid_destination`

```elixir
@callback is_valid_destination(destination :: term()) :: boolean()
```

Verifies whether the given destination is valid for the transport module.

# `max_apdu_length`

```elixir
@callback max_apdu_length() :: pos_integer()
```

Get the maximum APDU length for this transport.

# `max_npdu_length`

```elixir
@callback max_npdu_length() :: pos_integer()
```

Get the maximum NPDU length for this transport.

The NPDU length contains the maximum transmittable size
of the NPDU, including the APDU, without violating
the maximum transmission unit of the underlying transport.

Any necessary transport header (i.e. BVLL, LLC) must have
been taken into account when calculating this number.

# `open`

```elixir
@callback open(
  callback :: transport_callback(),
  opts :: Keyword.t()
) :: {:ok, transport :: transport()} | {:error, term()}
```

Opens/starts the Transport module. If a process is started, it is linked to the caller process.

The callback argument can be one of PID (resp. `t:Process.dest/0`), MFA tuple or a three arity function.
In case of a PID, the `t:transport_msg/0` structure is sent as message. Otherwise the function or MFA tuple
gets invoked with the arguments: `source_address :: term(), frame :: transport_cb_frame(), portal :: portal()`.
The function or MFA tuple may be run under a standalone task or a supervisored task.

The source address is any term and depends on the transport protocol. The portal is a term, where
the BACnet data is received from and sent to. The portal may be the same as the transport, but must
not be assumed it is. Sending data must always be directed to the portal and not to the transport.
Some transports may use "grouping data structures" to avoid going through processes and build
bottlenecks on busy networks.

# `send`

```elixir
@callback send(
  portal :: portal(),
  destination :: term(),
  data :: BACnet.Stack.EncoderProtocol.t() | iodata(),
  opts :: Keyword.t()
) :: :ok | {:error, term()}
```

Sends data to the BACnet network.

Segmentation and respect to APDU length needs to be handled by the caller. The transport module will raise,
if the maximum APDU/NPDU length is exceeded.

The data is a struct implementing the Encoder Protocol, or must be already encoded (iodata).

By default, the BACnet Virtual Link Layer, or similar, and Network Protocol Data Unit are added,
if either of those are required by the transport.

The following options are available (unless specified otherwise by the transport):
- `destination: NpciTarget.t()` - Optional. Sets the `destination` (DNET, DADDR, DLEN) in the
  NPCI header accordingly (defaults to absent). A value of `nil` should be treated as option absent.
- `npci: NPCI.t() | false` - Optional. The NPCI to use. If omitted, the NPCI will be calculated.
  If the `npci` option is present, options `destination` and `source` will be ignored.
  `false` can be used to omit the NPCI completely from the BACnet packet (i.e. for pure BVLL packets).
- `skip_headers: boolean()` - Optional. Skips adding all headers for the transport protocol (i.e. BVLL, NPCI).
- `source: NpciTarget.t()` - Optional. Sets the `source` (SNET, SADDR, SLEN) in the
  NPCI header accordingly (defaults to absent). A value of `nil` should be treated as option absent.

# `build_bacnet_packet`

```elixir
@spec build_bacnet_packet(iodata() | struct(), boolean(), Keyword.t()) ::
  {:ok, {npci :: iodata(), apdu :: iodata()}} | {:error, term()}
```

Builds the BACnet packet common parts. It is used in transports for common tasks.

It encodes the given APDU (if struct), encodes the NPDU (if not skipping headers)
and validates common grounds between all transports.

When the NPCI is not present in `opts`, it will be calculated from the payload.
`NPCI.new/1` is used to create the NPCI with `destination`, `expects_reply`
and `source` set.

The following gets validated:
- `expects_reply` in NPCI is not set if broadcast
- Valid `destination` option (is a `NpciTarget` struct - `address` is not validated)
- Valid `source` option (is a `NpciTarget` struct - `address` is not validated)

The following options of `c:send/4` are used:
- `destination: NpciTarget.t()`
- `npci: NPCI.t()`
- `skip_headers: boolean()`
- `source: NpciTarget.t()`

# `child_spec`

```elixir
@spec child_spec(module(), transport_callback(), Keyword.t(), Keyword.t()) ::
  Supervisor.child_spec()
```

Produces a supervisor child spec based on the BACnet transport `open` callback, as such
it will take the `callback` and `opts` for `c:open/2`.

See also `Supervisor.child_spec/2` for the rest of the behaviour.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
