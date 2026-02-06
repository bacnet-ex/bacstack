# `BACnet.Protocol.NotificationParameters.UnsignedRange`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/notification_parameters.ex#L310)

Represents the BACnet event algorithm `UnsignedRange` notification parameters.

The UnsignedRange event algorithm detects whether the monitored value exceeds a range defined by a high limit and
a low limit.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.9.

# `t`

```elixir
@type t() :: %BACnet.Protocol.NotificationParameters.UnsignedRange{
  exceeded_limit: non_neg_integer(),
  exceeding_value: non_neg_integer(),
  status_flags: BACnet.Protocol.StatusFlags.t()
}
```

Representative type for the notification parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
