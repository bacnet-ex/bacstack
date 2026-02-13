# `BACnet.Protocol.EventParameters.ChangeOfCharacterString`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_parameters.ex#L407)

Represents the BACnet event algorithm `ChangeOfCharacterString` parameters.

The ChangeOfCharacterString event algorithm detects whether the monitored value matches a character string
that is listed as an alarm value. Alarm values are of type BACnetOptionalCharacterString, and may also be NULL or an
empty character string.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.16.

# `t`

```elixir
@type t() :: %BACnet.Protocol.EventParameters.ChangeOfCharacterString{
  alarm_values: [String.t() | nil],
  time_delay: non_neg_integer(),
  time_delay_normal: non_neg_integer() | nil
}
```

Representative type for the event parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
