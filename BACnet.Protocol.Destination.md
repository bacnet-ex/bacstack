# `BACnet.Protocol.Destination`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/destination.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.Destination{
  from_time: BACnet.Protocol.BACnetTime.t(),
  issue_confirmed_notifications: boolean(),
  process_identifier: BACnet.Protocol.ApplicationTags.unsigned32(),
  recipient: BACnet.Protocol.Recipient.t(),
  to_time: BACnet.Protocol.BACnetTime.t(),
  transitions: BACnet.Protocol.EventTransitionBits.t(),
  valid_days: BACnet.Protocol.DaysOfWeek.t()
}
```

Represents a BACnet destination.

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet destination into BACnet application tags encoding.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet destination from BACnet application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given BACnet destination is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
