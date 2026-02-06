# `BACnet.Protocol.EventInformation`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_information.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.EventInformation{
  acknowledged_transitions: BACnet.Protocol.EventTransitionBits.t(),
  event_enable: BACnet.Protocol.EventTransitionBits.t(),
  event_priorities:
    {to_offnormal :: byte(), to_fault :: byte(), to_normal :: byte()},
  event_state: BACnet.Protocol.Constants.event_state(),
  event_timestamps: BACnet.Protocol.EventTimestamps.t(),
  notify_type: BACnet.Protocol.Constants.notify_type(),
  object_identifier: BACnet.Protocol.ObjectIdentifier.t()
}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet event information into BACnet application tags encoding.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet event information from BACnet application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given event information is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
