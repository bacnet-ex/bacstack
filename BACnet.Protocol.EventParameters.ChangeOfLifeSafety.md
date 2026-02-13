# `BACnet.Protocol.EventParameters.ChangeOfLifeSafety`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_parameters.ex#L207)

Represents the BACnet event algorithm `ChangeOfLifeSafety` parameters.

The ChangeOfLifeSafety event algorithm detects whether the monitored value equals a value that is listed as an
alarm value or life safety alarm value. Event state transitions are also indicated if the value of the mode parameter changed
since the last transition indicated. In this case, any time delays are overridden and the transition is indicated immediately.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.8.

# `t`

```elixir
@type t() :: %BACnet.Protocol.EventParameters.ChangeOfLifeSafety{
  alarm_values: [BACnet.Protocol.Constants.life_safety_state()],
  life_safety_alarm_values: [BACnet.Protocol.Constants.life_safety_state()],
  mode: BACnet.Protocol.DeviceObjectPropertyRef.t(),
  time_delay: non_neg_integer(),
  time_delay_normal: non_neg_integer() | nil
}
```

Representative type for the event parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
