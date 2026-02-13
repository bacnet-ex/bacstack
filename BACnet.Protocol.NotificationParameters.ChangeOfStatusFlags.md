# `BACnet.Protocol.NotificationParameters.ChangeOfStatusFlags`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/notification_parameters.ex#L447)

Represents the BACnet event algorithm `ChangeOfStatusFlags` notification parameters.

The ChangeOfStatusFlags event algorithm detects whether a significant flag of the monitored value of type
BACnetStatusFlags has the value TRUE.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.11.

# `t`

```elixir
@type t() :: %BACnet.Protocol.NotificationParameters.ChangeOfStatusFlags{
  present_value: BACnet.Protocol.ApplicationTags.Encoding.t() | nil,
  referenced_flags: BACnet.Protocol.StatusFlags.t()
}
```

Representative type for the notification parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
