# `BACnet.Protocol.FaultParameters.None`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/fault_parameters.ex#L28)

Represents the BACnet fault algorithm `None` parameters.

The NONE fault algorithm is a placeholder for the case where no fault algorithm is applied by the object.
This fault algorithm has no parameters, no conditions, and does not indicate any transitions of reliability.

For more specific information about the fault algorithm, consult ASHRAE 135 13.4.1.

# `t`

```elixir
@type t() :: %BACnet.Protocol.FaultParameters.None{}
```

Representative type for the fault parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
