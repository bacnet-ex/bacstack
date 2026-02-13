# `BACnet.Protocol.EventParameters.None`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_parameters.ex#L458)

Represents the BACnet event algorithm `None` parameters.

This event algorithm has no parameters, no conditions, and does not indicate
any transitions of event state. The NONE algorithm is used when only fault detection
is in use by an object.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.17.

# `t`

```elixir
@type t() :: %BACnet.Protocol.EventParameters.None{}
```

Representative type for the event parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
