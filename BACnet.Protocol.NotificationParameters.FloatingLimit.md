# `BACnet.Protocol.NotificationParameters.FloatingLimit`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/notification_parameters.ex#L152)

Represents the BACnet event algorithm `FloatingLimit` notification parameters.

The FloatingLimit event algorithm detects whether the monitored value exceeds a range defined by a setpoint, a high
difference limit, a low difference limit and a deadband.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.5.

# `t`

```elixir
@type t() :: %BACnet.Protocol.NotificationParameters.FloatingLimit{
  error_limit: float(),
  reference_value: float(),
  setpoint_value: float(),
  status_flags: BACnet.Protocol.StatusFlags.t()
}
```

Representative type for the notification parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
