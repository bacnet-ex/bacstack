# `BACnet.Protocol.EventParameters.ChangeOfStatusFlags`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_parameters.ex#L433)

Represents the BACnet event algorithm `ChangeOfStatusFlags` parameters.

The ChangeOfStatusFlags event algorithm detects whether a significant flag of the monitored value of type
BACnetStatusFlags has the value TRUE.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.11.

# `t`

```elixir
@type t() :: %BACnet.Protocol.EventParameters.ChangeOfStatusFlags{
  selected_flags: BACnet.Protocol.StatusFlags.t(),
  time_delay: non_neg_integer(),
  time_delay_normal: non_neg_integer() | nil
}
```

Representative type for the event parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
