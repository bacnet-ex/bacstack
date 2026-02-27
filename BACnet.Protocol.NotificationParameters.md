# `BACnet.Protocol.NotificationParameters`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/notification_parameters.ex#L1)

BACnet has various different types of notification parameters.
Each of them is represented by a different module.

The event algorithm `AccessEvent` is not supported.

Consult the module `BACnet.Protocol.EventAlgorithms` for
details about each event's algorithms.
Consult the module `BACnet.Protocol.EventParameters` for
details about each event's parameters.

# `notification_parameter`

```elixir
@type notification_parameter() ::
  BACnet.Protocol.NotificationParameters.ChangeOfBitstring.t()
  | BACnet.Protocol.NotificationParameters.ChangeOfState.t()
  | BACnet.Protocol.NotificationParameters.ChangeOfValue.t()
  | BACnet.Protocol.NotificationParameters.CommandFailure.t()
  | BACnet.Protocol.NotificationParameters.FloatingLimit.t()
  | BACnet.Protocol.NotificationParameters.OutOfRange.t()
  | BACnet.Protocol.NotificationParameters.ComplexEventType.t()
  | BACnet.Protocol.NotificationParameters.ChangeOfLifeSafety.t()
  | BACnet.Protocol.NotificationParameters.Extended.t()
  | BACnet.Protocol.NotificationParameters.BufferReady.t()
  | BACnet.Protocol.NotificationParameters.UnsignedRange.t()
  | BACnet.Protocol.NotificationParameters.DoubleOutOfRange.t()
  | BACnet.Protocol.NotificationParameters.SignedOutOfRange.t()
  | BACnet.Protocol.NotificationParameters.UnsignedOutOfRange.t()
  | BACnet.Protocol.NotificationParameters.ChangeOfCharacterString.t()
  | BACnet.Protocol.NotificationParameters.ChangeOfStatusFlags.t()
  | BACnet.Protocol.NotificationParameters.ChangeOfReliability.t()
```

Possible BACnet notification parameters.

# `encode`

```elixir
@spec encode(notification_parameter(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding()} | {:error, term()}
```

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding()) ::
  {:ok, notification_parameter()} | {:error, term()}
```

# `valid?`

```elixir
@spec valid?(notification_parameter()) :: boolean()
```

Validates whether the given notification parameter is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
