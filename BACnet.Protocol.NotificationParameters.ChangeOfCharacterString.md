# `BACnet.Protocol.NotificationParameters.ChangeOfCharacterString`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/notification_parameters.ex#L421)

Represents the BACnet event algorithm `ChangeOfCharacterString` notification parameters.

The ChangeOfCharacterString event algorithm detects whether the monitored value matches a character string
that is listed as an alarm value. Alarm values are of type BACnetOptionalCharacterString, and may also be NULL or an
empty character string.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.16.

# `t`

```elixir
@type t() :: %BACnet.Protocol.NotificationParameters.ChangeOfCharacterString{
  alarm_value: String.t(),
  changed_value: String.t(),
  status_flags: BACnet.Protocol.StatusFlags.t()
}
```

Representative type for the notification parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
