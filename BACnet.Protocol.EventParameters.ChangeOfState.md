# `BACnet.Protocol.EventParameters.ChangeOfState`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_parameters.ex#L67)

Represents the BACnet event algorithm `ChangeOfState` parameters.

The ChangeOfState event algorithm detects whether the monitored value equals a value that is listed as an alarm
value. The monitored value may be of any discrete or enumerated datatype, including Boolean.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.2.

# `t`

```elixir
@type t() :: %BACnet.Protocol.EventParameters.ChangeOfState{
  alarm_values: [BACnet.Protocol.PropertyState.t()],
  time_delay: non_neg_integer(),
  time_delay_normal: non_neg_integer() | nil
}
```

Representative type for the event parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
