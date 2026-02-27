# `BACnet.Protocol.NotificationParameters.ChangeOfReliability`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/notification_parameters.ex#L471)

Represents the BACnet event algorithm `ChangeOfReliability` notification parameters.

For all transitions to, or from, the FAULT state, the corresponding notification notification shall use the Event Type
ChangeOfReliability.

For more specific information about the fault notification event algorithm, consult ASHRAE 135 13.2.5.3.

# `t`

```elixir
@type t() :: %BACnet.Protocol.NotificationParameters.ChangeOfReliability{
  property_values: [BACnet.Protocol.PropertyValue.t()],
  reliability: BACnet.Protocol.Constants.reliability(),
  status_flags: BACnet.Protocol.StatusFlags.t()
}
```

Representative type for the notification parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
