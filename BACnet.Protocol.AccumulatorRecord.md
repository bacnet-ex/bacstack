# `BACnet.Protocol.AccumulatorRecord`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/accumulator_record.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.AccumulatorRecord{
  accumulated_value: non_neg_integer(),
  present_value: non_neg_integer(),
  status: BACnet.Protocol.Constants.accumulator_status(),
  timestamp: BACnet.Protocol.BACnetDateTime.t()
}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes an accumulator record struct into application tags encoding.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet accumulator record into a struct.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given accumulator record is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
