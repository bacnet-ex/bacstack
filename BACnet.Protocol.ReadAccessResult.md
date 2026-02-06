# `BACnet.Protocol.ReadAccessResult`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/read_access_result.ex#L1)

Represents BACnet Read Access Result, used in BACnet `Read-Property-Multiple`.

# `t`

```elixir
@type t() :: %BACnet.Protocol.ReadAccessResult{
  object_identifier: BACnet.Protocol.ObjectIdentifier.t(),
  results: [BACnet.Protocol.ReadAccessResult.ReadResult.t()]
}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet Read Access Result into BACnet application tags encoding.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet Read Access Result from BACnet application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given read access result is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
