# `BACnet.Protocol.EventParameters.ChangeOfValue`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_parameters.ex#L92)

Represents the BACnet event algorithm `ChangeOfValue` parameters.

The ChangeOfValue event algorithm, for monitored values of datatype REAL, detects whether the absolute value of
the monitored value changes by an amount equal to or greater than a positive REAL increment.

The ChangeOfValue event algorithm, for monitored values of datatype BIT STRING, detects whether the monitored
value changes in any of the bits specified by a bitmask.

For detection of change, the value of the monitored value when a transition to NORMAL is indicated shall be used in
evaluation of the conditions until the next transition to NORMAL is indicated. The initialization of the value used in
evaluation before the first transition to NORMAL is indicated is a local matter.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.3.

# `t`

```elixir
@type t() :: %BACnet.Protocol.EventParameters.ChangeOfValue{
  bitmask: tuple() | nil,
  increment: float() | nil,
  time_delay: non_neg_integer(),
  time_delay_normal: non_neg_integer() | nil
}
```

Representative type for the event parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
