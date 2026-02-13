# `BACnet.Protocol.EventAlgorithms`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_algorithms.ex#L1)

BACnet has various different types of event algorithms.
Each of them is implemented by a different module.

The event algorithm `AccessEvent` is not supported.

ASHRAE 135:
> Event algorithms monitor a value and evaluate whether the condition for
> a transition of event state exists. The result of the evaluation,
> indicated to the Event-State-Detection process, may be a transition to
> a new event state, a transition to the same event state, or no transition.
> The final determination of the Event_State property value is the responsibility
> of the Event-State- Detection process and is subject to additional conditions. See Clause 13.2.
>
> Each of the event algorithms defines its input parameters, the allowable normal and
> offnormal states, the conditions for transitions between those states,
> and the notification parameters conveyed in event notifications for the algorithm.
> When executing an event algorithm, all conditions defined for the algorithm shall be
> evaluated in the order as presented for the algorithm. Some algorithms specify
> optional conditions, marked as "Optional:" Whether or not an implementation uses
> these conditions is a local matter. If no condition evaluates to true, then no
> transition shall be indicated to the Event-State-Detection process.

# `event_algorithm`

```elixir
@type event_algorithm() ::
  BACnet.Protocol.EventAlgorithms.ChangeOfBitstring.t()
  | BACnet.Protocol.EventAlgorithms.ChangeOfState.t()
  | BACnet.Protocol.EventAlgorithms.ChangeOfValue.t()
  | BACnet.Protocol.EventAlgorithms.CommandFailure.t()
  | BACnet.Protocol.EventAlgorithms.FloatingLimit.t()
  | BACnet.Protocol.EventAlgorithms.OutOfRange.t()
  | BACnet.Protocol.EventAlgorithms.ChangeOfLifeSafety.t()
  | BACnet.Protocol.EventAlgorithms.BufferReady.t()
  | BACnet.Protocol.EventAlgorithms.UnsignedRange.t()
  | BACnet.Protocol.EventAlgorithms.DoubleOutOfRange.t()
  | BACnet.Protocol.EventAlgorithms.SignedOutOfRange.t()
  | BACnet.Protocol.EventAlgorithms.UnsignedOutOfRange.t()
  | BACnet.Protocol.EventAlgorithms.ChangeOfCharacterString.t()
  | BACnet.Protocol.EventAlgorithms.ChangeOfStatusFlags.t()
```

Possible BACnet event algorithms.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
