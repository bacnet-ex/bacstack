# `BACnet.Protocol.AlarmSummary`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/alarm_summary.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.AlarmSummary{
  acknowledged_transitions: BACnet.Protocol.EventTransitionBits.t(),
  alarm_state: BACnet.Protocol.Constants.event_state(),
  object_identifier: BACnet.Protocol.ObjectIdentifier.t()
}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet alarm summary into BACnet application tags encoding.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet alarm summary from BACnet application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given alarm summary is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
