# `BACnet.Protocol.FaultParameters.FaultLifeSafety`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/fault_parameters.ex#L103)

Represents the BACnet fault algorithm `FaultLifeSafety` parameters.

The FAULT_LIFE_SAFETY fault algorithm detects whether the monitored value equals
a value that is listed as a fault value.
The monitored value is of type BACnetLifeSafetyState. If internal operational
reliability is unreliable, then the internal reliability takes precedence over
evaluation of the monitored value.

In addition, this algorithm monitors a life safety mode value. If reliability is
MULTI_STATE_FAULT, then new transitions to MULTI_STATE_FAULT are indicated upon
change of the mode value.

For more specific information about the fault algorithm, consult ASHRAE 135 13.4.4.

# `t`

```elixir
@type t() :: %BACnet.Protocol.FaultParameters.FaultLifeSafety{
  fault_values: [BACnet.Protocol.Constants.life_safety_state()],
  mode: BACnet.Protocol.DeviceObjectPropertyRef.t()
}
```

Representative type for the fault parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
