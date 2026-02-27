# `BACnet.Protocol.NotificationParameters.BufferReady`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/notification_parameters.ex#L285)

Represents the BACnet event algorithm `BufferReady` notification parameters.

The BufferReady event algorithm detects whether a defined number of records have been added to a log buffer since
start of operation or the previous notification, whichever is most recent.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.7.

# `t`

```elixir
@type t() :: %BACnet.Protocol.NotificationParameters.BufferReady{
  buffer_property: BACnet.Protocol.DeviceObjectPropertyRef.t(),
  current_notification: BACnet.Protocol.ApplicationTags.unsigned32(),
  previous_notification: BACnet.Protocol.ApplicationTags.unsigned32()
}
```

Representative type for the notification parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
