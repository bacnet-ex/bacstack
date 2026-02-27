# `BACnet.Protocol.TimeValue`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/time_value.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.TimeValue{
  time: BACnet.Protocol.BACnetTime.t(),
  value: BACnet.Protocol.ApplicationTags.Encoding.t()
}
```

Represents a BACnet Time Value (used in Daily Schedule and Special Event).

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet time value into BACnet application tags encoding.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet time value from BACnet application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given time value is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
