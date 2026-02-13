# `BACnet.Protocol.BACnetError`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/bacnet_error.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.BACnetError{
  class: BACnet.Protocol.Constants.error_class() | non_neg_integer(),
  code: BACnet.Protocol.Constants.error_code() | non_neg_integer()
}
```

Represents a casual BACnet Error.

To allow forward compatibility, each field can be an integer.

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet error into BACnet application tags encoding.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet error from BACnet application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given status flags is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
