# `BACnet.Stack.Transport.EthernetTransport`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/transport/ethernet_transport.ex#L1)

The BACnet transport for BACnet/Ethernet.

This module uses the `:socket` module and requires `NET_RAW`
capabilities to use raw ethernet sockets.

Windows does not support raw ethernet sockets as part of its API
and thus trying to start an Ethernet transport will fail at socket level.

The Linux kernel/driver will re-calculate the ethernet frame size
and not honor the ethernet frame size in the ethernet frame itself,
thus all padding zeros will be included in the frame and APDU.
This may lead to unexpected behaviour in some edge cases.
Use the IP transport or use BSD as an operating system instead,
if you're having issues due to padding zeros being in the payload.

# `mac_address`

```elixir
@type mac_address() :: binary()
```

The destination and source address is a binary representing the MAC address of the ethernet link.

# `open_option`

```elixir
@type open_option() ::
  {:eth_ifname, binary()}
  | {:supervisor, Supervisor.supervisor()}
  | GenServer.option()
```

Valid open options. For a description of each, see `open/2`.

# `open_options`

```elixir
@type open_options() :: [open_option()]
```

List of open options.

# `send_option`

```elixir
@type send_option() :: BACnet.Stack.TransportBehaviour.transport_send_option()
```

Valid send options. For a description of each, see `send/4`.

# `send_options`

```elixir
@type send_options() :: [send_option()]
```

List of send options.

# `bacnet_protocol`

```elixir
@spec bacnet_protocol() :: BACnet.Stack.TransportBehaviour.transport_protocol()
```

Get the BACnet transport protocol this transport implements.

# `child_spec`

```elixir
@spec child_spec(list()) :: Supervisor.child_spec()
```

Produces a supervisor child spec.
It will call `child_spec(callback, opts)` with the given 2-element list elements.

See also `Supervisor.child_spec/2` for the rest of the behaviour.

# `child_spec`

```elixir
@spec child_spec(BACnet.Stack.TransportBehaviour.transport_callback(), Keyword.t()) ::
  Supervisor.child_spec()
```

Produces a supervisor child spec based on the BACnet transport `open` callback, as such
it will take the `callback` and `opts` for `open/2`.

See also `Supervisor.child_spec/2` for the rest of the behaviour.

# `close`

```elixir
@spec close(GenServer.server()) :: :ok
```

Closes the Transport module.

# `get_broadcast_address`

```elixir
@spec get_broadcast_address(GenServer.server()) :: mac_address()
```

Get the broadcast address.

Since the broadcast address is static,
you can also use `nil` as `transport` argument.

# `get_local_address`

```elixir
@spec get_local_address(GenServer.server()) :: mac_address()
```

Get the local address.

# `get_portal`

```elixir
@spec get_portal(GenServer.server()) :: term()
```

Get the transport module portal for the given transport PID/port.
Transport modules may return the input as output, if the same
PID or port is used for sending.

This is used to get the portal before having received data from
the transport module, so data can be sent prior to reception.

# `is_destination_routed`

```elixir
@spec is_destination_routed(GenServer.server(), mac_address() | term()) :: boolean()
```

Checks whether the given destination is an address that needs to be routed.

Always returns `false` due to how Ethernet works (no routing).

# `is_valid_destination`

```elixir
@spec is_valid_destination(mac_address() | term()) :: boolean()
```

Verifies whether the given destination is valid for the transport module.

# `max_apdu_length`

```elixir
@spec max_apdu_length() :: pos_integer()
```

Get the maximum APDU length for this transport.

# `max_npdu_length`

```elixir
@spec max_npdu_length() :: pos_integer()
```

Get the maximum NPDU length for this transport.

The NPDU length contains the maximum transmittable size
of the NPDU, including the APDU, without violating
the maximum transmission unit of the underlying transport.

Any necessary transport header (i.e. BVLL, LLC) must have
been taken into account when calculating this number.

# `open`

```elixir
@spec open(
  callback :: BACnet.Stack.TransportBehaviour.transport_callback(),
  opts :: open_options()
) :: {:ok, pid()} | {:error, term()}
```

Opens/starts the Transport module. A process is started, that is linked to the caller process.

See the `BACnet.Stack.TransportBehaviour` documentation for more information.

In case of this BACnet/Ethernet transport, the transport is a PID,
due to the GenServer receiving and processing Ethernet frames.
The portal is a tuple of the underlying socket, the ethernet interface index and the MAC address of the interface,
so that there's no need to go through the GenServer. The BACnet/Ethernet transport module makes sure
the data is correctly wrapped for the BACnet/Ethernet protocol.
Source and destination address is a binary containing the MAC address.

This transport takes the following options, in addition to `t:GenServer.options/0`:
- `eth_ifname: binary()` - Optional. The ethernet interface to use. Defaults to the first one (normally loopback).
- `supervisor: Supervisor.supervisor()` - Optional. The task supervisor to use to spawn tasks under.
  Tasks are spawned to invoke the given callback. If no supervisor is given,
  the tasks will be spawned unsupervised.

# `send`

```elixir
@spec send(
  BACnet.Stack.TransportBehaviour.portal(),
  mac_address(),
  BACnet.Stack.EncoderProtocol.t() | iodata(),
  send_options()
) :: :ok | {:error, term()}
```

Sends data to the BACnet network.

See the `BACnet.Stack.TransportBehaviour` documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
