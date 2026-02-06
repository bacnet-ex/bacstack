# `BACnet.Protocol.EventParameters.CommandFailure`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_parameters.ex#L125)

Represents the BACnet event algorithm `CommandFailure` parameters.

The CommandFailure event algorithm detects whether the monitored value and the feedback value disagree for a time
period. It may be used, for example, to verify that a process change has occurred after writing a property.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.4.

# `t`

```elixir
@type t() :: %BACnet.Protocol.EventParameters.CommandFailure{
  feedback_value: BACnet.Protocol.ApplicationTags.Encoding.t(),
  time_delay: non_neg_integer(),
  time_delay_normal: non_neg_integer() | nil
}
```

Representative type for the event parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
