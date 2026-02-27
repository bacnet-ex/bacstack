# `BACnet.Protocol.NotificationParameters.UnsignedOutOfRange`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/notification_parameters.ex#L393)

Represents the BACnet event algorithm `UnsignedOutOfRange` notification parameters.

The UnsignedOutOfRange event algorithm detects whether the monitored value exceeds a range defined by a high
limit and a low limit. Each of these limits may be enabled or disabled. If disabled, the normal range has no lower limit or no
higher limit respectively. In order to reduce jitter of the resulting notification state, a deadband is applied when the value is in the
process of returning to the normal range.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.15.

# `t`

```elixir
@type t() :: %BACnet.Protocol.NotificationParameters.UnsignedOutOfRange{
  deadband: non_neg_integer(),
  exceeded_limit: non_neg_integer(),
  exceeding_value: non_neg_integer(),
  status_flags: BACnet.Protocol.StatusFlags.t()
}
```

Representative type for the notification parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
