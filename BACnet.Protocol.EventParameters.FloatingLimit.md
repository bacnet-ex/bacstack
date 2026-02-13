# `BACnet.Protocol.EventParameters.FloatingLimit`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_parameters.ex#L150)

Represents the BACnet event algorithm `FloatingLimit` parameters.

The FloatingLimit event algorithm detects whether the monitored value exceeds a range defined by a setpoint, a high
difference limit, a low difference limit and a deadband.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.5.

# `t`

```elixir
@type t() :: %BACnet.Protocol.EventParameters.FloatingLimit{
  deadband: float(),
  high_diff_limit: float(),
  low_diff_limit: float(),
  setpoint: BACnet.Protocol.DeviceObjectPropertyRef.t(),
  time_delay: non_neg_integer(),
  time_delay_normal: non_neg_integer() | nil
}
```

Representative type for the event parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
