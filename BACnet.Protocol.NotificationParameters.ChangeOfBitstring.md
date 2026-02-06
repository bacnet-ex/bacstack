# `BACnet.Protocol.NotificationParameters.ChangeOfBitstring`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/notification_parameters.ex#L48)

Represents the BACnet event algorithm `ChangeOfBitstring` notification parameters.

The ChangeOfBitstring event algorithm detects whether the monitored value of type BIT STRING equals a value
that is listed as an alarm value, after applying a bitmask.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.1.

# `t`

```elixir
@type t() :: %BACnet.Protocol.NotificationParameters.ChangeOfBitstring{
  referenced_bitstring: tuple(),
  status_flags: BACnet.Protocol.StatusFlags.t()
}
```

Representative type for the notification parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
