# `BACnet.Protocol.EventParameters.ChangeOfBitstring`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_parameters.ex#L41)

Represents the BACnet event algorithm `ChangeOfBitstring` parameters.

The ChangeOfBitstring event algorithm detects whether the monitored value of type BIT STRING equals a value
that is listed as an alarm value, after applying a bitmask.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.1.

# `t`

```elixir
@type t() :: %BACnet.Protocol.EventParameters.ChangeOfBitstring{
  alarm_values: [tuple()],
  bitmask: tuple(),
  time_delay: non_neg_integer(),
  time_delay_normal: non_neg_integer() | nil
}
```

Representative type for the event parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
