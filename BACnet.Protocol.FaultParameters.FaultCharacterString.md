# `BACnet.Protocol.FaultParameters.FaultCharacterString`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/fault_parameters.ex#L49)

Represents the BACnet fault algorithm `FaultCharacterString` parameters.

The FAULT_CHRACTERSTRING fault algorithm detects whether the monitored value matches a
character string that is listed as a fault value. Fault values are of type
BACnetOptionalCharacterString and may also be NULL or an empty character string.

For more specific information about the fault algorithm, consult ASHRAE 135 13.4.2.

# `t`

```elixir
@type t() :: %BACnet.Protocol.FaultParameters.FaultCharacterString{
  fault_values: [String.t()]
}
```

Representative type for the fault parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
