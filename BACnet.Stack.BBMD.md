# `BACnet.Stack.BBMD`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/bbmd.ex#L1)

The BBMD module is responsible for acting as a BACnet/IPv4 Broadcast Management Device (BBMD).

It will subscribe for BACnet/IP Virtual Link Layer messages from the `BACnet.Stack.Client`
and act accordingly on BBMD-specific BVLC messages.
It will handle both Broadcast Distribution according to the Broadcast Distribution Table (BDT)
on local broadcast and Foreign Device Registration, including distributing broadcasts from those.

It allows to read the BDT and registered Foreign Devices through BVLC messages and
the module functions. New Foreign Device Registrations may be "paused" and "resumed" at any time.
Pausing Foreign Device Registrations will mean that new Register messages will be rejected.

BBMDs allow a Foreign Device (a device not residing on the same subnet) to send broadcasts
to the network the BBMD is connected to. More specifically, the Foreign Device will tell the BBMD
to distribute a specific APDU as broadcast and the BBMD will forward that APDU as broadcast
on the network. BACnet devices on that network will then respond with `I-Am` APDUs directly
to that device. As such, proper network routing is required for this to work.

For each network (client/transport) one BBMD process is required,
if Foreign Devices should be served (enables to discover local BACnet devices).
**Only one BBMD is allowed on a BACnet network.**

# `client`

```elixir
@type client() :: BACnet.Stack.Client.server()
```

Represents a `BACnet.Stack.Client` process. It will be used to retrieve the
transport module, transport and portal through the `BACnet.Stack.Client` API.

# `server`

```elixir
@type server() :: GenServer.server()
```

Represents a server process of the BBMD module.

# `start_option`

```elixir
@type start_option() ::
  {:bdt, [BACnet.Protocol.BroadcastDistributionTableEntry.t()]}
  | {:bdt_readonly, boolean()}
  | {:client, client()}
  | {:max_fd_registrations, pos_integer()}
  | {:override_port, 47808..65535}
  | {:paused, boolean()}
  | {:proxy_mode, boolean()}
  | GenServer.option()
```

Valid start options. For a description of each, see `start_link/1`.

# `start_options`

```elixir
@type start_options() :: [start_option()]
```

List of start options.

# `add_bdt_entry`

```elixir
@spec add_bdt_entry(server(), BACnet.Protocol.BroadcastDistributionTableEntry.t()) ::
  :ok | {:error, term()}
```

Add an entry to the Broadcast Distribution Table.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `get_broadcast_distribution_table`

```elixir
@spec get_broadcast_distribution_table(server()) :: [
  BACnet.Protocol.BroadcastDistributionTableEntry.t()
]
```

Get the Foreign Device Table.

# `get_foreign_device_table`

```elixir
@spec get_foreign_device_table(server()) :: [
  BACnet.Protocol.ForeignDeviceTableEntry.t()
]
```

Get the Foreign Device Table.

# `pause_fd_registration`

```elixir
@spec pause_fd_registration(server()) :: :ok
```

Pause Foreign Device Registration process.

All new Foreign Device Registration requests will be rejected.
Leading to "draining" of the BBMD through expiration of registrations,
as long as expiration time (TTL) are not exorbitantly large.

See also `resume_fd_registration/1` for resuming.

# `remove_bdt_entry`

```elixir
@spec remove_bdt_entry(server(), BACnet.Protocol.BroadcastDistributionTableEntry.t()) ::
  :ok | {:error, term()}
```

Removes an entry from the Broadcast Distribution Table.

# `remove_foreign_device`

```elixir
@spec remove_foreign_device(server(), BACnet.Protocol.ForeignDeviceTableEntry.t()) ::
  :ok | {:error, term()}
```

Removes a Foreign Device from the Foreign Device table.

This may be used to remove known dead devices with long expiration time
manually without having to wait for the entries to expire.

# `resume_fd_registration`

```elixir
@spec resume_fd_registration(server()) :: :ok
```

Resumes Foreign Device Registration process.

All new Foreign Device Registration requests will be processed as normal.
This function reverses `pause_fd_registration/1`.

# `start_link`

```elixir
@spec start_link(start_options()) :: GenServer.on_start()
```

Starts and links the BACnet Broadcast Management Device.

The following options are available, in addition to `t:GenServer.options/0`:
  - `bdt: [BroadcastDistributionTableEntry.t()]` - Optional. The Broadcast Distribution Table to distribute broadcasts to peers.
  - `bdt_readonly: boolean()` - Optional. Whether the Broadcast Distribution Table is readonly on the BACnet side.
    By default the BDT can be written to and changed. Setting this to `true` will only allow writes through the Elixir side.
  - `client: client()` - Required. The client & transport information.
  - `max_fd_registrations: pos_integer()` - Optional. The amount of Foreign Device registrations that can be accepted
    are limited by this option (defaults to `512`). That is by design to not allow an unlimited number of registrations to be
    accumulated with a long Time-To-Live. Only up to the given number will be accepted at most concurrently,
    any further registration will be rejected and must wait until one registration times out or
    gets deleted to allow a new registration to be accepted.
    The maximum Time-To-Live is `65_535` seconds (ca. 18h 12mins), as per ASHRAE 135 J.5.2.1.
  - `override_port: 47_808..65_535` - Optional. Overrides the used broadcast port (defaults to transport port number).
  - `paused: boolean()` - Optional. Start in paused state. See also `pause_fd_registration/1` and `resume_fd_registration/1`.
  - `proxy_mode: boolean()` - Optional. This is an alternate mode to the BBMD operation as described in ASHRAE 135 Annex J.4.5.
    Instead of broadcasting received BVLL `Distribute-Broadcast-To-Network` as `Forwarded-NPDU`, it will do a regular broadcast.
    Which means the devices will respond unicast to the BBMD.
    The BBMD will forward all received `IAm` and `IHave` NPDUs to all Foreign Devices, even if the Foreign Device has not
    sent a request for `WhoIs` or the request has been long ago executed. This mode is only for development and testing purposes.
    It should not be used in production for regular BBMD operation.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
