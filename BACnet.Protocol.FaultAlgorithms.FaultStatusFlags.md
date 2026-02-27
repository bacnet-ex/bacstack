# `BACnet.Protocol.FaultAlgorithms.FaultStatusFlags`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/fault_algorithms/fault_status_flags.ex#L1)

Represents the BACnet fault algorithm `FaultStatusFlags`.

The FAULT_STATUS_FLAGS fault algorithm detects whether the monitored
status flags are indicating a fault condition.

For more specific information about the fault algorithm, consult ASHRAE 135 13.4.6.

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
> (a) If pCurrentReliability is NO_FAULT_DETECTED,
> and the FAULT bit in pMonitoredValue is TRUE, then
> indicate a transition to the MEMBER_FAULT reliability.
>
> (b) If pCurrentReliability is MEMBER_FAULT,
> and the FAULT bit in pMonitoredValue is FALSE,
> then indicate a transition to the NO_FAULT_DETECTED reliability.

# `new`

```elixir
@spec new(
  BACnet.Protocol.StatusFlags.t(),
  BACnet.Protocol.FaultParameters.FaultStatusFlags.t()
) :: t()
```

Creates a new algorithm state.

# `update`

```elixir
@spec update(t(), Keyword.t()) :: t()
```

Updates the state using the given parameters (`monitored_value`, `parameters`).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
