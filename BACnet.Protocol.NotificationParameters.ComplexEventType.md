# `BACnet.Protocol.NotificationParameters.ComplexEventType`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/notification_parameters.ex#L206)

Represents the BACnet event algorithm `ComplexEventType` notification parameters.

The `ComplexEventType` algorithm is introduced to allow the addition of proprietary event algorithms
whose notification parameters are not necessarily network-visible.

# `t`

```elixir
@type t() :: %BACnet.Protocol.NotificationParameters.ComplexEventType{
  property_values: [BACnet.Protocol.PropertyValue.t()]
}
```

Representative type for the notification parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
