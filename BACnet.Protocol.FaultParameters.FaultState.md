# `BACnet.Protocol.FaultParameters.FaultState`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/fault_parameters.ex#L134)

Represents the BACnet fault algorithm `FaultState` parameters.

The FAULT_STATE fault algorithm detects whether the monitored value
equals a value that is listed as a fault value. The monitored value
may be of any discrete or enumerated datatype, including Boolean.
If internal operational reliability is unreliable, then the
internal reliability takes precedence over evaluation of the monitored value.

For more specific information about the fault algorithm, consult ASHRAE 135 13.4.5.

# `t`

```elixir
@type t() :: %BACnet.Protocol.FaultParameters.FaultState{
  fault_values: [BACnet.Protocol.PropertyState.t()]
}
```

Representative type for the fault parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
