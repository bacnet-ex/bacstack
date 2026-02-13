# `BACnet.Protocol.EventParameters.SignedOutOfRange`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_parameters.ex#L349)

Represents the BACnet event algorithm `SignedOutOfRange` parameters.

The SignedOutOfRange event algorithm detects whether the monitored value exceeds a range defined by a high
limit and a low limit. Each of these limits may be enabled or disabled. If disabled, the normal range has no lower limit or no
higher limit respectively. In order to reduce jitter of the resulting event state, a deadband is applied when the value is in the
process of returning to the normal range.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.14.

# `t`

```elixir
@type t() :: %BACnet.Protocol.EventParameters.SignedOutOfRange{
  deadband: integer(),
  high_limit: integer(),
  low_limit: integer(),
  time_delay: non_neg_integer(),
  time_delay_normal: non_neg_integer() | nil
}
```

Representative type for the event parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
