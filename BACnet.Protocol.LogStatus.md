# `BACnet.Protocol.LogStatus`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/log_status.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.LogStatus{
  buffer_purged: boolean(),
  log_disabled: boolean(),
  log_interrupted: boolean()
}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet log status into application tags encoding.

# `from_bitstring`

```elixir
@spec from_bitstring({boolean(), boolean()} | {boolean(), boolean(), boolean()}) ::
  t()
```

Creates from an application tag bitstring a log status.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet log status from application tags encoding.

# `to_bitstring`

```elixir
@spec to_bitstring(t()) :: BACnet.Protocol.ApplicationTags.primitive_encoding()
```

Creates an application tag bitstring from a log status.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given log status is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
