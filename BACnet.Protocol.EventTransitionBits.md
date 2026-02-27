# `BACnet.Protocol.EventTransitionBits`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_transition_bits.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.EventTransitionBits{
  to_fault: boolean(),
  to_normal: boolean(),
  to_offnormal: boolean()
}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet event transition bits into application tags encoding.

# `from_bitstring`

```elixir
@spec from_bitstring(tuple()) :: t()
```

Creates from an application tag bitstring an event transition bits.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet event transition bits from application tags encoding.

# `to_bitstring`

```elixir
@spec to_bitstring(t()) :: BACnet.Protocol.ApplicationTags.primitive_encoding()
```

Creates an application tag bitstring from an event transition bits.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given event transition bits is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
