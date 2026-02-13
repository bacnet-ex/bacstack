# `BACnet.Protocol.SpecialEvent`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/special_event.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.SpecialEvent{
  list: [BACnet.Protocol.TimeValue.t()],
  period:
    BACnet.Protocol.CalendarEntry.t() | BACnet.Protocol.ObjectIdentifier.t(),
  priority: 1..16
}
```

Represents a BACnet Special Event.

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encode a BACnet special event into application tag-encoded.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parse a BACnet special event from application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given special event is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
