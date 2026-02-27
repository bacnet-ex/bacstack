# `BACnet.Protocol.NotificationParameters.CommandFailure`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/notification_parameters.ex#L127)

Represents the BACnet event algorithm `CommandFailure` notification parameters.

The CommandFailure event algorithm detects whether the monitored value and the feedback value disagree for a time
period. It may be used, for example, to verify that a process change has occurred after writing a property.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.4.

# `t`

```elixir
@type t() :: %BACnet.Protocol.NotificationParameters.CommandFailure{
  command_value: BACnet.Protocol.ApplicationTags.Encoding.t(),
  feedback_value: BACnet.Protocol.ApplicationTags.Encoding.t(),
  status_flags: BACnet.Protocol.StatusFlags.t()
}
```

Representative type for the notification parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
