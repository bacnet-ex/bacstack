# `BACnet.Protocol.NotificationParameters.ChangeOfLifeSafety`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/notification_parameters.ex#L227)

Represents the BACnet event algorithm `ChangeOfLifeSafety` notification parameters.

The ChangeOfLifeSafety event algorithm detects whether the monitored value equals a value that is listed as an
alarm value or life safety alarm value. Event state transitions are also indicated if the value of the mode parameter changed
since the last transition indicated. In this case, any time delays are overridden and the transition is indicated immediately.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.8.

# `t`

```elixir
@type t() :: %BACnet.Protocol.NotificationParameters.ChangeOfLifeSafety{
  new_mode: BACnet.Protocol.Constants.life_safety_mode(),
  new_state: BACnet.Protocol.Constants.life_safety_state(),
  operation_expected: BACnet.Protocol.Constants.life_safety_operation(),
  status_flags: BACnet.Protocol.StatusFlags.t()
}
```

Representative type for the notification parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
