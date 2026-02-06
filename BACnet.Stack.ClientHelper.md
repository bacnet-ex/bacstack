# `BACnet.Stack.ClientHelper`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/client_helper.ex#L1)

BACnet stack client helper functions for executing commands/queries.

# `i_am`

```elixir
@spec i_am(
  GenServer.server(),
  term() | :broadcast,
  BACnet.Protocol.ObjectIdentifier.t(),
  non_neg_integer(),
  Keyword.t()
) :: :ok | {:error, term()}
```

Sends an I-Am service request to the destination, or optionally using
`:broadcast` (or the real broadcast address) as local broadcast.

See also `BACnet.Protocol.Services.IAm`.

The `Client.send/4` options are available.

# `read_object`

```elixir
@spec read_object(
  GenServer.server(),
  term(),
  BACnet.Protocol.ObjectIdentifier.t(),
  Keyword.t()
) ::
  {:ok, BACnet.Protocol.ObjectsUtility.bacnet_object()}
  | {:error, BACnet.Protocol.apdu()}
  | {:error, term()}
```

Read a BACnet object from a remote BACnet device and transform it into an object.

The required properties are always as a bare minimum read, only more properties can be read, never less.

The value is casted through the `BACnet.Protocol.ObjectsUtility` module based on the object modules.
As such object types or properties that are not supported, will fail.

If you want to read a device object and don't know the proper device instance number,
you can use `4_194_303` as instance number. By the BACnet specification that instance number will be
treated by the remote BACnet device as if the instance number was locally correctly matched.

The following options are available:
- All options from `BACnet.Stack.Client.send/4`.
- All options from `BACnet.Protocol.Services.ReadPropertyMultiple.to_apdu/2`.
- All options from `BACnet.Protocol.ObjectsUtility.cast_read_properties_ack/3`.
- All options from `BACnet.Protocol.ObjectsUtility.cast_properties_to_object/3`.
- `properties: [:all | :required | Constants.property_identifier()]` - Optional. Select the properties to read.
- `read_level: :all | :required` - Optional. Select how many properties should be read (defaults to `:all`).

`properties` and `read_level` are mutually excluse. If both are given, `properties` takes precedence.

# `read_property`

```elixir
@spec read_property(
  GenServer.server(),
  term(),
  BACnet.Protocol.ObjectIdentifier.t(),
  BACnet.Protocol.Constants.property_identifier() | non_neg_integer(),
  non_neg_integer() | nil,
  Keyword.t()
) ::
  {:ok, term()}
  | {:ok,
     BACnet.Protocol.ApplicationTags.Encoding.t()
     | [BACnet.Protocol.ApplicationTags.Encoding.t()]}
  | {:error, BACnet.Protocol.apdu()}
  | {:error, term()}
```

Read a single property from a remote BACnet object and transform the value.

The value is casted through the `BACnet.Protocol.ObjectsUtility` module based on the object modules.
As such object types or properties that are not supported, will fail, unless you specify
the `raw` options, which will give you the `Encoding` struct (or list of) to handle yourself.
Array indexes of 0 will return the array size as `{:ok, non_neg_integer()}`, if successfully read.

If you want to read a device object's property without needing to know before hand which instance number,
you can use `4_194_303` as instance number. By the BACnet specification that instance number will be
treated by the remote BACnet device as if the instance number was locally correctly matched.

The following options are available:
- All options from `BACnet.Stack.Client.send/4`.
- All options from `BACnet.Protocol.Services.ReadProperty.to_apdu/2`.
- `raw: boolean()` - Optional. Returns the `t:Encoding.t/0` (or list of) instead of trying to transform the value.

# `read_property_multiple`

```elixir
@spec read_property_multiple(
  GenServer.server(),
  term(),
  BACnet.Protocol.ObjectIdentifier.t(),
  [
    BACnet.Protocol.AccessSpecification.Property.t()
    | BACnet.Protocol.Constants.property_identifier()
    | :all
    | :required
    | :optional
  ],
  Keyword.t()
) ::
  {:ok, %{optional(BACnet.Protocol.Constants.property_identifier()) =&gt; term()}}
  | {:ok, [BACnet.Protocol.ReadAccessResult.t()]}
  | {:error, BACnet.Protocol.apdu()}
  | {:error, term()}
```

Read multiple properties from a remote BACnet object at once and transform each value.

The values are casted through the `BACnet.Protocol.ObjectsUtility` module based on the object modules.
As such object types or properties that are not supported, will fail, unless you specify
the `raw` options, which will give you a list of `ReadAccessResult`s to handle yourself.

The following options are available:
- All options from `BACnet.Stack.Client.send/4`.
- All options from `BACnet.Protocol.Services.ReadPropertyMultiple.to_apdu/2`.
- `raw: boolean()` - Optional. Returns the results instead of trying to transform each value.

# `reinitialize_device`

```elixir
@spec reinitialize_device(
  GenServer.server(),
  term(),
  BACnet.Protocol.Constants.reinitialized_state(),
  String.t() | nil,
  Keyword.t()
) :: :ok | {:error, BACnet.Protocol.apdu()} | {:error, term()}
```

Send a Reinitialize-Device service request to a remote BACnet device.

Password must be an ASCII string between 1 to 20 characters, inclusive, or nil.

The following options are available:
- All options from `BACnet.Stack.Client.send/4`.
- All options from `BACnet.Protocol.Services.ReinitializeDevice.to_apdu/2`.

# `scan_device`

```elixir
@spec scan_device(
  GenServer.server(),
  term(),
  BACnet.Protocol.ObjectIdentifier.t(),
  Keyword.t()
) ::
  {:ok,
   %{
     optional(BACnet.Protocol.Constants.object_type()) =&gt; %{
       optional(non_neg_integer()) =&gt;
         BACnet.Protocol.ObjectsUtility.bacnet_object()
     }
   }}
  | {:error, {term(), BACnet.Protocol.ObjectIdentifier.t()}}
  | {:error, term()}
```

Scan the given device for available objects and read all objects. A map of objects will be returned on success.

If you don't know the device object identifier of the BACnet device in question, but you know the
BACnet network address (i.e. the IP address and port for BACnet/IP), you can use the Who-Is service
with the destination address being the device's network address, to discover the object identifier.
You can also use `read_property/6` to read the `:object_identifier` property.

The scan process is parallelized through `Task.async_stream/3` and thus the `invoke_id` is
automatically being set. Since this implementation simply uses `invoke_id` in the range of `0..max_concurrency-1`,
it would be safest when the `BACnet.Stack.Client` implementation manages and overrides the `invoke_id`,
so that an user does not have to care about possible collisions.
The current "default" implementation of `BACnet.Stack.Client` does manage `invoke_id`s,
but it can be deactivated, so care must be exercised if it done.
You need to be aware to not invoke/have parallel other requests to the same destination,
as the `invoke_id` could be duplicated.

The values are casted through the `BACnet.Protocol.ObjectsUtility` module based on the object modules.
As such object types or properties that are not supported, will fail the operation.

The following options are available:
- All options from `read_object/4`.
- All options from `BACnet.Stack.Client.send/4`.
- All options from `BACnet.Protocol.Services.ReadPropertyMultiple.to_apdu/2`, except `invoke_id`.
- All options from `BACnet.Protocol.ObjectsUtility.cast_read_properties_ack/3`.
- All options from `BACnet.Protocol.ObjectsUtility.cast_properties_to_object/3`.
- `exit_on_error: boolean()` - Optional. Whether to exit the process on first error.
- `ignore_errors: boolean()` - Optional. Whether to ignore errors and continue with the rest.
- `ignore_unsupported_object_types: boolean()` - Optional. Whether to ignore unknown/unsupported object types.
- `task_max_concurrency: pos_integer()` - Optional. The maximum task concurrency to use (limited to 255).
- `task_supervisor: Supervisor.supervisor()` - Optional. The task supervisor to use for spawning tasks.
- `task_timeout: timeout()` - Optional. The timeout to use for the task async stream (defaults to `30_000`).

`exit_on_error` and `ignore_errors` are mutually excluse. `ignore_errors` takes precedence, if set to `true`.

# `send_time_synchronization`

```elixir
@spec send_time_synchronization(
  GenServer.server(),
  term(),
  Keyword.t()
) :: :ok | {:error, term()}
```

Send a (UTC) Time Synchronization service APDU to the destination.

`:broadcast` will be resolved to the local broadcast address.

The following options are available:
- All options from `BACnet.Stack.Client.send/4`.
- All options from `BACnet.Protocol.Services.TimeSynchronziation.to_apdu/2` respectively
  `BACnet.Protocol.Services.UtcTimeSynchronziation.to_apdu/2`.
- `datetime: DateTime.t()` - Optional. The timestamp to use for synchronization.
  It will be automatically shifted to UTC, if necessary.
  If omitted, `DateTime.now!/1` will be used with Time Synchronization -
  if the default timezone is "Etc/UTC", then UTC Time Synchronization will be used.
  The `utc` option overrides the behaviour of the default timezone -
  you may use a non-UTC timezone and still be able to use UTC.
- `utc: boolean()` - Optional. Whether to use UTC Time Synchronization.

# `subscribe_cov_property`

```elixir
@spec subscribe_cov_property(
  GenServer.server(),
  term(),
  BACnet.Protocol.ObjectIdentifier.t(),
  BACnet.Protocol.Constants.property_identifier(),
  Keyword.t()
) :: :ok | {:error, BACnet.Protocol.apdu()} | {:error, term()}
```

Subscribes for COV notification for a remote BACnet object property.

When using confirmed COV notifications, the remote BACnet device requires
you to send confirmations of the reception (`BACnet.Protocol.Services.SimpleACK`) -
this is not done automatically.

The following options are available:
- All options from `BACnet.Stack.Client.send/4`.
- All options from `BACnet.Protocol.Services.SubscribeCovProperty.to_apdu/2`.
- `confirmed: boolean()` - Optional. Request confirmed COV notifications.
  By default, COV notifications are requested to be unconfirmed.
- `cov_increment: float()` - Optional. The COV increment to use for float properties.
- `lifetime: non_neg_integer() | nil` - Optional. The COV subscription lifetime to use
  in seconds (defaults to 3600). To unsubscribe, use `nil`.
- `pid: non_neg_integer()` - Optional. The process identifier to use. By default,
  this will be calculated from the caller PID (`node bits 0-3 << 28 + pid_number << 13 + pid_serial`).

# `who_is`

```elixir
@spec who_is(GenServer.server(), pos_integer(), Keyword.t()) ::
  {:ok, [{source_address :: term(), BACnet.Protocol.Services.IAm.t()}]}
  | {:error, term()}
```

Sends a Who-Is service request to the network (local broadcast).
The I-Am responses will be collected and returned.

See also `BACnet.Protocol.Services.WhoIs`.

By default, it will collect all responses received until `timeout`.
By using `max` opts, one can tell the function how many to receive
and then stop prematurely. Either `max` or `timeout` will stop
the collecting. Timeout must be minimum `10`ms.

This function will by default spawn a new task and subscribe for
BACnet notification messages and afterwards unsubscribe.
This behaviour can be disabled through `no_subscribe` opts.

The following options are available, in addition the `Client.send/4` options:
- `apdu_destination: term()` - Optional. Overrides the APDU destination address.
- `high_limit: pos_integer()` - Optional. The maximum BACnet device ID for the Who-Is query.
- `low_limit: pos_integer()` - Optional. The minimum BACnet device ID for the Who-Is query.
- `max: pos_integer()` - Optional. The maximum amount of IAm responses to collect.
- `no_subscribe: boolean()` - Optional. Whether to spawn a new task.

# `write_property`

```elixir
@spec write_property(
  GenServer.server(),
  term(),
  BACnet.Protocol.ObjectIdentifier.t(),
  BACnet.Protocol.Constants.property_identifier() | non_neg_integer(),
  term()
  | BACnet.Protocol.ApplicationTags.Encoding.t()
  | [BACnet.Protocol.ApplicationTags.Encoding.t()],
  Keyword.t()
) :: :ok | {:error, BACnet.Protocol.apdu()} | {:error, term()}
```

Write to a single property of a remote BACnet object.

Either the actual value of the property can be given and then the value will
be automatically encoded through `BACnet.Protocol.ObjectsUtility`.
Or an `Encoding` struct (or list of) can be given, which will be used
directly without validation.

The following options are available:
- All options from `BACnet.Stack.Client.send/4`.
- All options from `BACnet.Protocol.Services.WriteProperty.to_apdu/2`.
- `array_index: non_neg_integer() | nil` - Optional. The property array index to write to.
- `priority: 1..16 | nil` - Optional. The BACnet priority to write to.

# `write_property_multiple`

```elixir
@spec write_property_multiple(
  GenServer.server(),
  term(),
  BACnet.Protocol.ObjectIdentifier.t(),
  %{
    optional(property_identifier) =&gt;
      value | {array_index :: non_neg_integer(), value}
  }
  | [
      {property_identifier, value | {array_index :: non_neg_integer(), value}}
      | {property_identifier, array_index :: non_neg_integer(), value}
      | BACnet.Protocol.AccessSpecification.Property.t()
    ],
  Keyword.t()
) ::
  :ok
  | {:error, BACnet.Protocol.Services.Error.WritePropertyMultipleError.t()}
  | {:error, BACnet.Protocol.apdu()}
  | {:error, term()}
when property_identifier:
       BACnet.Protocol.Constants.property_identifier() | non_neg_integer(),
     value:
       term()
       | BACnet.Protocol.ApplicationTags.Encoding.t()
       | [term() | BACnet.Protocol.ApplicationTags.Encoding.t()]
```

Write to multiple properties of a remote BACnet object.

Either the actual value of the property can be given and then the value will
be automatically encoded through `BACnet.Protocol.ObjectsUtility`.
Or an `Encoding` struct (or list of) can be given, which will be used
directly without validation.

Prioritized property access is not possible with this function.
Use `write_property/6` instead if you need to write to a specific priority.
You can however write to specific array indexes.

The following options are available:
- All options from `BACnet.Stack.Client.send/4`.
- All options from `BACnet.Protocol.Services.WritePropertyMultiple.to_apdu/2`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
