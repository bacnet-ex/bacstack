# `BACnet.Protocol.EventParameters`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_parameters.ex#L1)

BACnet has various different types of event parameters.
Each of them is represented by a different module.

The event algorithm `AccessEvent` is not supported.

Consult the module `BACnet.Protocol.EventAlgorithms` for
details about each event's algorithm.

# `event_parameter`

```elixir
@type event_parameter() ::
  BACnet.Protocol.EventParameters.ChangeOfBitstring.t()
  | BACnet.Protocol.EventParameters.ChangeOfState.t()
  | BACnet.Protocol.EventParameters.ChangeOfValue.t()
  | BACnet.Protocol.EventParameters.CommandFailure.t()
  | BACnet.Protocol.EventParameters.FloatingLimit.t()
  | BACnet.Protocol.EventParameters.OutOfRange.t()
  | BACnet.Protocol.EventParameters.ChangeOfLifeSafety.t()
  | BACnet.Protocol.EventParameters.Extended.t()
  | BACnet.Protocol.EventParameters.BufferReady.t()
  | BACnet.Protocol.EventParameters.UnsignedRange.t()
  | BACnet.Protocol.EventParameters.DoubleOutOfRange.t()
  | BACnet.Protocol.EventParameters.SignedOutOfRange.t()
  | BACnet.Protocol.EventParameters.UnsignedOutOfRange.t()
  | BACnet.Protocol.EventParameters.ChangeOfCharacterString.t()
  | BACnet.Protocol.EventParameters.ChangeOfStatusFlags.t()
  | BACnet.Protocol.EventParameters.None.t()
```

Possible BACnet event parameters.

# `encode`

```elixir
@spec encode(event_parameter(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding()} | {:error, term()}
```

# `parse`

```elixir
@spec parse(binary()) :: {:ok, event_parameter()} | {:error, term()}
```

# `valid?`

```elixir
@spec valid?(event_parameter()) :: boolean()
```

Validates whether the given event parameter is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
