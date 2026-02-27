# `BACnet.Protocol.ReadAccessResult.ReadResult`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/read_access_result/read_result.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.ReadAccessResult.ReadResult{
  error: BACnet.Protocol.BACnetError.t() | nil,
  property_array_index: non_neg_integer() | nil,
  property_identifier:
    BACnet.Protocol.Constants.property_identifier() | non_neg_integer(),
  property_value:
    BACnet.Protocol.ApplicationTags.Encoding.t()
    | [BACnet.Protocol.ApplicationTags.Encoding.t()]
    | nil
}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet Read Access Result Read Result into BACnet application tags encoding.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet Read Access Result Read Result from BACnet application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given read access read result is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
