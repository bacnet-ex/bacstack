# `BACnet.Protocol.PropertyRef`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/property_ref.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.PropertyRef{
  property_array_index: non_neg_integer() | nil,
  property_identifier:
    BACnet.Protocol.Constants.property_identifier() | non_neg_integer()
}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet property reference into application tags encoding.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet property reference into a struct.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given property reference is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
