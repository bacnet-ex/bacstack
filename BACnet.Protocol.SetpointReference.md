# `BACnet.Protocol.SetpointReference`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/setpoint_reference.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.SetpointReference{
  ref: BACnet.Protocol.ObjectPropertyRef.t() | nil
}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet setpoint reference into application tags encoding.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet setpoint reference from application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given setpoint reference is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
