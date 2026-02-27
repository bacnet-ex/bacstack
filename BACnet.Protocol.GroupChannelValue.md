# `BACnet.Protocol.GroupChannelValue`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/group_channel_value.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.GroupChannelValue{
  channel: BACnet.Protocol.ApplicationTags.unsigned16(),
  overriding_priority: 1..16 | nil,
  value:
    BACnet.Protocol.ApplicationTags.Encoding.t()
    | (lightning_command :: [BACnet.Protocol.ApplicationTags.Encoding.t()])
}
```

Represents a BACnet Group Channel Value.

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a group channel value struct into application tags encoding.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet group channel value into a struct.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given BACnet group channel value is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
