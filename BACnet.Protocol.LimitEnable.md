# `BACnet.Protocol.LimitEnable`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/limit_enable.ex#L1)

BACnet Limit Enable conveys several flags that describe the enabled limit detection algorithms.

* The LOW_LIMIT_ENABLE flag indicates whether the low limit detection algorithm is enabled.
* The HIGH_LIMIT_ENABLE flag indicates whether the high limit detection algorithm is enabled.

# `t`

```elixir
@type t() :: %BACnet.Protocol.LimitEnable{
  high_limit_enable: boolean(),
  low_limit_enable: boolean()
}
```

Represents BACnet limit enable flags.

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet limit enable into application tags encoding.

# `from_bitstring`

```elixir
@spec from_bitstring(tuple()) :: t()
```

Creates from an application tag bitstring a limit enable.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet limit enable from application tags encoding.

# `to_bitstring`

```elixir
@spec to_bitstring(t()) :: BACnet.Protocol.ApplicationTags.primitive_encoding()
```

Creates an application tag bitstring from a limit enable.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given limit enable is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
