# `BACnet.Protocol.FaultParameters.FaultStatusFlags`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/fault_parameters.ex#L160)

Represents the BACnet fault algorithm `FaultStatusFlags` parameters.

The FAULT_STATUS_FLAGS fault algorithm detects whether the monitored
status flags are indicating a fault condition.

For more specific information about the fault algorithm, consult ASHRAE 135 13.4.6.

# `t`

```elixir
@type t() :: %BACnet.Protocol.FaultParameters.FaultStatusFlags{
  status_flags: BACnet.Protocol.DeviceObjectPropertyRef.t()
}
```

Representative type for the fault parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
