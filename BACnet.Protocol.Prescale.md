# `BACnet.Protocol.Prescale`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/prescale.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.Prescale{
  modulo_divide: non_neg_integer(),
  multiplier: non_neg_integer()
}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet prescale into application tags encoding.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet prescale from application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given prescale is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
