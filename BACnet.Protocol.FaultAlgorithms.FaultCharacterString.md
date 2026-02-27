# `BACnet.Protocol.FaultAlgorithms.FaultCharacterString`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/fault_algorithms/fault_character_string.ex#L1)

Represents the BACnet fault algorithm `FaultCharacterString`.

The FAULT_CHARACTERSTRING fault algorithm detects whether the monitored value matches a
character string that is listed as a fault value. Fault values are of type
BACnetOptionalCharacterString and may also be NULL or an empty character string.

For more specific information about the fault algorithm, consult ASHRAE 135 13.4.2.

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
> (a) If pCurrentReliability is NO_FAULT_DETECTED, and pMonitoredValue matches
> one of the values in pFaultValues, then indicate a transition
> to the MULTI_STATE_FAULT reliability.
>
> (b) If pCurrentReliability is MULTI_STATE_FAULT, and pMonitoredValue does not
> match any of the values contained in pFaultValues,
> then indicate a transition to the NO_FAULT_DETECTED reliability.
>
> (c) Optional: If pCurrentReliability is MULTI_STATE_FAULT, and pMonitoredValue
> matches one of the values contained in pFaultValues that is different
> from the value that caused the last transition to MULTI_STATE_FAULT,
> then indicate a transition to the MULTI_STATE_FAULT reliability.

# `new`

```elixir
@spec new(String.t(), BACnet.Protocol.FaultParameters.FaultCharacterString.t()) :: t()
```

Creates a new algorithm state.

# `update`

```elixir
@spec update(t(), Keyword.t()) :: t()
```

Updates the state using the given parameters (`monitored_value`, `parameters`).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
