# `BACnet.Stack.ForeignDevice`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/foreign_device.ex#L1)

The Foreign Device module is a server process that takes care of registering the application
(client/transport) as a Foreign Device in a BACnet/IPv4 Broadcast Management Device (BBMD).

It will automatically renew the registration in the BBMD, as long as this
Foreign Device process is alive. The default Time-To-Live (TTL) is a
development value and should always be overwritten in a production environment
to lessen network traffic caused by Foreign Device registration.

It also allows to read the BBMD's Broadcast Distribution Table,
Foreign Device Table and distribute Unconfirmed Service Request APDUs
through it.

If registration in the BBMD fails, it will automatically retry to
register in the BBMD at a later point in time (10 seconds).
Currently this value can not be changed and is hardcoded.

For each BBMD (client/transport) one Foreign Device process is required.
This allows to register in many BBMDs as Foreign Device.

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

Represents a server process of the Foreign Device module.

# `start_option`

```elixir
@type start_option() ::
  {:bbmd, {:inet.ip4_address(), port :: 1..65535}}
  | {:client, client()}
  | {:reply_rfd, boolean()}
  | {:ttl, pos_integer()}
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

# `distribute_broadcast`

```elixir
@spec distribute_broadcast(
  server(),
  BACnet.Protocol.APDU.UnconfirmedServiceRequest.t(),
  Keyword.t()
) ::
  :ok | {:error, BACnet.Protocol.BvlcResult.t()} | {:error, term()}
```

Distributes the given APDU as broadcast through the BBMD.
Only unconfirmed service requests can be sent as broadcast.

It will spawn a new `Task` to temporarily subscribe for
`BACnet.Stack.Client` notifications to receive BVLL/BVLC messages.

It uses `BACnet.Stack.Client` to send the APDU,
all `opts` will be given to `BACnet.Stack.Client.send/4`,
in addition, the following are available for this function only:
- `receive_timeout: non_neg_integer()` - Optional. The timeout to use to await
  BVLL/BVLC NAK response from the BBMD. Defaults to `1_000`.

# `get_status`

```elixir
@spec get_status(server()) :: :registered | :waiting_for_ack | :uninitialized
```

Get the status of Foreign Device registration.

# `read_broadcast_distribution_table`

```elixir
@spec read_broadcast_distribution_table(server(), Keyword.t()) ::
  {:ok, [BACnet.Protocol.BroadcastDistributionTableEntry.t()]}
  | {:error, BACnet.Protocol.BvlcResult.t()}
  | {:error, term()}
```

Reads the Broadcast Distribution Table of the BBMD.

This function will only read the BBMD address from the Foreign Device server,
all communication to the BBMD is done in the caller process using a `Task`.
The new `Task` will temporarily subscribe for `BACnet.Stack.Client` notifications
to be able to process BVLL/BVLC messages.

The following options are available:
- `timeout: non_neg_integer() | :infinity` - Optional.
  The timeout to use for waiting for the BBMD reply.

# `read_foreign_device_table`

```elixir
@spec read_foreign_device_table(server(), Keyword.t()) ::
  {:ok, [BACnet.Protocol.ForeignDeviceTableEntry.t()]}
  | {:error, BACnet.Protocol.BvlcResult.t()}
  | {:error, term()}
```

Reads the Foreign Device Table of the BBMD.

This function will only read the BBMD address from the Foreign Device server,
all communication to the BBMD is done in the caller process using a `Task`.
The new `Task` will temporarily subscribe for `BACnet.Stack.Client` notifications
to be able to process BVLL/BVLC messages.

The following options are available:
- `timeout: non_neg_integer() | :infinity` - Optional.
  The timeout to use for waiting for the BBMD reply.

# `renew`

```elixir
@spec renew(server()) :: :ok
```

Explicitely renews the Foreign Device Registration in the BBMD.

This function returns `:ok` almost immediately,
without waiting for a response from the BBMD.

# `send_whois`

```elixir
@spec send_whois(server(), non_neg_integer(), Keyword.t()) ::
  {:ok, [BACnet.Protocol.Services.IAm.t()]} | {:error, term()}
```

Sends a Who-Is APDU to the BBMD for local broadcast.

It uses `distribute_broadcast/3` to do the broadcast
and then collects the incoming `BACnet.Protocol.Services.IAm` messages.
This function will always spawn a new `Task`
to send and collect messages.

It accepts the same options as `BACnet.Stack.ClientHelper.who_is/3`,
except `apdu_destination` and `no_subscribe`.

# `start_link`

```elixir
@spec start_link(start_options()) :: GenServer.on_start()
```

Starts and links the BACnet Foreign Device.

The following options are available,
in addition to `t:GenServer.options/0`:
  - `bbmd: {:inet.ip4_address(), 1..65_535}` - Required. The BBMD address to register itself as Foreign Device with.
  - `client: client()` - Required. The client & transport information.
  - `reply_rfd: boolean()` - Optional. Enables replying to `Register-Foreign-Device` packets from other BACnet clients.
    Defaults to `true`. If multiple `ForeignDevice` processes are running on the same client/transport,
    all except for one MUST have this option disabled.
  - `ttl: pos_integer()` - Optional. The time in seconds until the Foreign Device Registration expires. Defaults to `60`.

# `stop`

```elixir
@spec stop(server()) :: :ok
```

Stops and shuts down the Foreign Device.

If a registration is active, it will try to delete it in the BBMD.

# `write_broadcast_distribution_table`

```elixir
@spec write_broadcast_distribution_table(
  server(),
  [BACnet.Protocol.BroadcastDistributionTableEntry.t()],
  Keyword.t()
) :: :ok | {:error, BACnet.Protocol.BvlcResult.t()} | {:error, term()}
```

Writes the Broadcast Distribution Table of the BBMD.

This function will only read the BBMD address from the Foreign Device server,
all communication to the BBMD is done in the caller process using a `Task`.
The new `Task` will temporarily subscribe for `BACnet.Stack.Client` notifications
to be able to process BVLL/BVLC messages.

Since the response from the BBMD is a generic success message, without any
other information, you MUST make sure that this is the ONLY BVLL command that
gets executed concurrently. Otherwise this or any other concurrent BVLL command
MAY receive a false positive response instead of a negative response that would
be the actual response to the BVLL command.

The following options are available:
- `timeout: non_neg_integer() | :infinity` - Optional.
  The timeout to use for waiting for the BBMD reply.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
