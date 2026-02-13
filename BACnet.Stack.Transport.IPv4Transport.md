# `BACnet.Stack.Transport.IPv4Transport`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/transport/ipv4_transport.ex#L1)

The BACnet transport for BACnet/IP on IPv4.

BACnet/IPv4 uses UDP/IPv4 for communication. It uses both unicast and broadcast.
Broadcast is used for unconfirmed services, such as discovery.

The BACnet specification allows for using multicast, however multicast is not implemented,
as the majority of the commercial devices solely use unicast and broadcast.

For retrieving the broadcast address to send BACnet data the GenServer will be called.
When sending BACnet data in large quantities (high performance scenario),
this is however unwanted because it can slow down the process and bottleneck the whole
traffic, if the transport has huge traffic to handle.
For those rare cases, retrieving the broadcast address for sending can be optimized
by storing the broadcast address in `:persistent_term`.
This can be enabled in the application environment `:bacstack`
under `:client_broadcast_addr_in_persistent_term` with the value `true`.
Alternatively you can provide the option `:is_broadcast` for `send/4`.
When using `BACnet.Stack.Client`, it will provide `:is_broadcast` pre-calculated.

# `iplink_address`

```elixir
@type iplink_address() :: {:inet.ip4_address(), :inet.port_number()}
```

The destination and source address is a tuple of IPv4 address and UDP port.

# `open_option`

```elixir
@type open_option() ::
  {:bacnet_port, 47808..65535}
  | {:inet_backend, :inet | :socket}
  | {:local_ip, :inet.ip4_address() | binary() | :none}
  | {:reuseaddr, boolean()}
  | {:reuseport, boolean()}
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
@type send_option() ::
  {:bvlc, binary()}
  | {:is_broadcast, boolean()}
  | BACnet.Stack.TransportBehaviour.transport_send_option()
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

# `get_address_for_ifname`

```elixir
@spec get_address_for_ifname(binary()) ::
  {:ok, :inet.ip4_address()} | {:error, :inet.posix() | :not_found}
```

Get the IPv4 address for the given ethernet interface name.
Only interfaces with broadcast capabilities are considered.

Even if multiple IP addresses are bound to the interface,
only the first one is returned.
Which one is the first is undefined and may be platform-specific.
Do not rely on consistent results for interfaces with multiple IPv4 addresses,
unless you've tested it in full.

This is a helper function to get the address (which may be from DHCP) by
the ethernet interface name, which is useful for `open/2`/`child_spec/1`
when you don't directly know the IPv4 address of the interface you want to use.

# `get_broadcast_address`

```elixir
@spec get_broadcast_address(GenServer.server()) :: iplink_address()
```

Get the broadcast address.

# `get_local_address`

```elixir
@spec get_local_address(GenServer.server()) :: iplink_address()
```

Get the local address.

# `get_portal`

```elixir
@spec get_portal(GenServer.server()) :: port()
```

Get the transport module portal for the given transport PID/port.
Transport modules may return the input as output, if the same
PID or port is used for sending.

This is used to get the portal before having received data from
the transport module, so data can be sent prior to reception.

# `is_destination_routed`

```elixir
@spec is_destination_routed(GenServer.server(), iplink_address() | term()) ::
  boolean()
```

Checks whether the given destination is an address that needs to be routed.

# `is_valid_destination`

```elixir
@spec is_valid_destination(iplink_address() | term()) :: boolean()
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

In the case of this BACnet/IPv4 transport, the transport PID/port is a `GenServer` receiving the UDP unicast
and broadcast packets.
However the portal is the UDP port where the data is sent to directly,
without going through the `GenServer` for sending the data.
The BACnet/IPv4 transport module makes sure the data is correctly wrapped for the BACnet/IPv4 protocol.
Source and destination address is a tuple of IP address and port.

Two UDP sockets will be opened, unless we do not bind to a specific interface. The second socket is only
used for receiving broadcasts, since as soon as we bind to a specific interface, the kernel will not
send us broadcast packets anymore. On Windows, broadcasts are also received when binding.
We internally filter broadcast packets on the non-broadcast socket in such cases, where two sockets will be opened.

This transport takes the following options, in addition to `t:GenServer.options/0`:
- `bacnet_port: 47808..65535` - Optional. The port number to use for BACnet. Defaults to `0xBAC0` (47808).
- `inet_backend: :inet | :socket` - Optional. Allows to switch the inet (gen_udp) backend.
- `local_ip: :inet.ip4_address() | binary() | :none` - Optional. The local IP address to bind to. If not specified,
  the first private IP address will be discovered. As private IP addresses count the IANA private IP range -
  `10.0.0.0/8`, `172.16.0.0/12` and `192.168.0.0/16`.
  It may also be an ethernet interface name as a binary - in that case,
  the ethernet  interface adapters will be enumerated and
  the IP address of the given interface will be used to bind to.
  Use `:none` to not bind explicitely to a specific ethernet interface adapter, which in turn will automatically
  bind to all ethernet interfaces and all destinations will be marked as "routed" (`is_destination_routed/2`).
  As a consequence, broadcast traffic may not be sent to the network you may want to and some devices will not reply
  to such broadcasts (`255.255.255.255`),
  unless you explicitely specify the correct broadcast address as destination when sending BACnet frames.
  Some functionality, such as BBMD and Foreign Device, will not work, because we are unable to determine
  our IP address (we do not know the default routing interface). We will try to automatically update the information,
  however that requires receiving a broadcast from ourself (some OS don't give us our broadcast back, i.e. BSD),
  which will however in normal circumstances be too late, since the relevant processes have already been started in the supervision tree.
  The `:none` value is thus not recommended and should not be used in a production environment.
  The default way of discovering the network interface should work in non-complex environments (only one network interface),
  for complex environments you should specify the network interface explicitely.
- `reuseaddr: boolean()` - Optional. Allows to set `SO_REUSEADDR` on the UDP socket.
- `reuseport: boolean()` - Optional. Allows to set `SO_REUSEPORT` on the UDP socket - only with socket backend.
- `supervisor: Supervisor.supervisor()` - Optional. The task supervisor to use to spawn tasks under.
  Tasks are spawned to invoke the given callback. If no supervisor is given,
  the tasks will be spawned unsupervised.

# `send`

```elixir
@spec send(
  port(),
  iplink_address(),
  BACnet.Stack.EncoderProtocol.t() | iodata(),
  send_options()
) :: :ok | {:error, term()}
```

Sends data to the BACnet network.

See the `BACnet.Stack.TransportBehaviour` documentation for more information.

In addition, the following options are available:
- `bvlc: binary()` - Optional. The BACnet/IP Virtual Link Control to use.
  This needs to be the binary representation of any BVLC (i.e. of `BACnet.Protocol.BvlcForwardedNPDU`),
  including the BVLC function. The BVLC function gets automatically extracted and placed at the correct position.
- `is_broadcast: boolean()` - Optional. Whether the destination is a broadcast address or not.
  If omitted it will be automatically determined by calling the GenServer
  to get the broadcast address (or using `:persistent_term`, if enabled).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
