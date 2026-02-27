# `BACnet.Protocol.EventParameters.UnsignedRange`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_parameters.ex#L292)

Represents the BACnet event algorithm `UnsignedRange` parameters.

The UnsignedRange event algorithm detects whether the monitored value exceeds a range defined by a high limit and
a low limit.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.9.

# `t`

```elixir
@type t() :: %BACnet.Protocol.EventParameters.UnsignedRange{
  high_limit: non_neg_integer(),
  low_limit: non_neg_integer(),
  time_delay: non_neg_integer(),
  time_delay_normal: non_neg_integer() | nil
}
```

Representative type for the event parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
