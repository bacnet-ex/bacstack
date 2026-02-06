# `BACnet.Protocol.StatusFlags`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/status_flags.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.StatusFlags{
  fault: boolean(),
  in_alarm: boolean(),
  out_of_service: boolean(),
  overridden: boolean()
}
```

Represents the BACnet Status Flags.

The `IN_ALARM` flag is set, if the Event State is not normal.

The `FAULT` flag is set, if the reliability has detected a fault.

The `OVERRIDDEN` flag is set, if the output has been overridden by some sort
of BACnet device local mechanism.

The `OUT_OF_SERVICE` flag is set, if the Out Of Service property is set.

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet status flags into application tags encoding.

# `from_bitstring`

```elixir
@spec from_bitstring(tuple()) :: t()
```

Creates from an application tag bitstring a status flag.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet status flags from application tags encoding.

# `to_bitstring`

```elixir
@spec to_bitstring(t()) :: BACnet.Protocol.ApplicationTags.primitive_encoding()
```

Creates an application tag bitstring from a status flag.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given status flags is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
