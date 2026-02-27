# `BACnet.Protocol.EventTimestamps`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_timestamps.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.EventTimestamps{
  to_fault: BACnet.Protocol.BACnetTimestamp.t(),
  to_normal: BACnet.Protocol.BACnetTimestamp.t(),
  to_offnormal: BACnet.Protocol.BACnetTimestamp.t()
}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet event timestamps into BACnet application tags encoding.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet event timestamps from BACnet application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given event timestamps is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
