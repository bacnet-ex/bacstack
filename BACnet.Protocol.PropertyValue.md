# `BACnet.Protocol.PropertyValue`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/property_value.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.PropertyValue{
  priority: 1..16 | nil,
  property_array_index: non_neg_integer() | nil,
  property_identifier:
    BACnet.Protocol.Constants.property_identifier() | non_neg_integer(),
  property_value: BACnet.Protocol.ApplicationTags.Encoding.t()
}
```

# `encode`

Encodes a BACnet property value into application tags encoding.

# `encode_all`

```elixir
@spec encode_all([t()], Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encode a list of property values into application tag-encoded property values.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parse application tag-encoded property value into a struct.

# `parse_all`

```elixir
@spec parse_all(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, [t()]} | {:error, term()}
```

Parse application tag-encoded property values into a list of structs.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given property value is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
