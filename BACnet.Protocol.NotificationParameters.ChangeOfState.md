# `BACnet.Protocol.NotificationParameters.ChangeOfState`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/notification_parameters.ex#L72)

Represents the BACnet event algorithm `ChangeOfState` notification parameters.

The ChangeOfState event algorithm detects whether the monitored value equals a value that is listed as an alarm
value. The monitored value may be of any discrete or enumerated datatype, including Boolean.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.2.

# `t`

```elixir
@type t() :: %BACnet.Protocol.NotificationParameters.ChangeOfState{
  new_state: BACnet.Protocol.PropertyState.t(),
  status_flags: BACnet.Protocol.StatusFlags.t()
}
```

Representative type for the notification parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
