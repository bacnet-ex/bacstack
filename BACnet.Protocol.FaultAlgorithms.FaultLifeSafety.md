# `BACnet.Protocol.FaultAlgorithms.FaultLifeSafety`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/fault_algorithms/fault_life_safety.ex#L1)

Represents the BACnet fault algorithm `FaultLifeSafety`.

The FAULT_LIFE_SAFETY fault algorithm detects whether the monitored value equals
a value that is listed as a fault value.
The monitored value is of type BACnetLifeSafetyState. If internal operational
reliability is unreliable, then the internal reliability takes precedence over
evaluation of the monitored value.

In addition, this algorithm monitors a life safety mode value. If reliability is
MULTI_STATE_FAULT, then new transitions to MULTI_STATE_FAULT are indicated upon
change of the mode value.

For more specific information about the fault algorithm, consult ASHRAE 135 13.4.4.

# `t`

```elixir
@opaque t()
```

Representative type for the event algorithm.

# `execute`

```elixir
@spec execute(t()) ::
  {:event, new_state :: t(),
   new_reliability :: BACnet.Protocol.Constants.reliability()}
  | {:no_event, new_state :: t()}
```

Calculates the new state for the current state and parameters.
Prior to this function invocation, the state should have been
updated with `update/2`, if any of the properties has changed.

ASHRAE 135:
> The conditions evaluated by this fault algorithm are:
>
> (a) If pCurrentReliability is NO_FAULT_DETECTED, and pMonitoredValue
> is equal to any of the values in pFaultValues, then indicate
> a transition to the MULTI_STATE_FAULT reliability.
>
> (b) If pCurrentReliability is MULTI_STATE_FAULT, and pMonitoredValue
> is not equal to any of the values contained in pFaultValues,
> then indicate a transition to the NO_FAULT_DETECTED reliability
>
> (c) If pCurrentReliability is MULTI_STATE_FAULT, and pMonitoredValue
> is equal to any of the values contained in pFaultValues,
> and pMode has changed since the last transition to MULTI_STATE_FAULT,
> then indicate a transition to the MULTI_STATE_FAULT reliability.
>
> (d) Optional: If pCurrentReliability is MULTI_STATE_FAULT,
> and pMonitoredValue is equal to one of the values contained
> in pFaultValues that is different from the value causing the last transition
> to MULTI_STATE_FAULT, then indicate a transition to the
> MULTI_STATE_FAULT reliability.

# `new`

```elixir
@spec new(
  BACnet.Protocol.Constants.life_safety_state(),
  BACnet.Protocol.Constants.life_safety_mode(),
  BACnet.Protocol.FaultParameters.FaultLifeSafety.t()
) :: t()
```

Creates a new algorithm state.

# `update`

```elixir
@spec update(t(), Keyword.t()) :: t()
```

Updates the state using the given parameters (`mode`, `monitored_value`, `parameters`).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
