# `BACnet.Protocol.DaysOfWeek`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/days_of_week.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.DaysOfWeek{
  friday: boolean(),
  monday: boolean(),
  saturday: boolean(),
  sunday: boolean(),
  thursday: boolean(),
  tuesday: boolean(),
  wednesday: boolean()
}
```

Represents a BACnet days of week.

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet days of week into application tags encoding.

# `from_bitstring`

```elixir
@spec from_bitstring(tuple()) :: t()
```

Creates from an application tag bitstring a days of week.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet days of week from application tags encoding.

# `to_bitstring`

```elixir
@spec to_bitstring(t()) :: BACnet.Protocol.ApplicationTags.primitive_encoding()
```

Creates an application tag bitstring from a days of week.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given days of week is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
