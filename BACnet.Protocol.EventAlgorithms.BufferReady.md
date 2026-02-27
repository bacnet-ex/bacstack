# `BACnet.Protocol.EventAlgorithms.BufferReady`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_algorithms/buffer_ready.ex#L1)

Implements the BACnet event algorithm `BufferReady`.

The BufferReady event algorithm detects whether a defined number of records
have been added to a log buffer since start of operation or the previous event,
whichever is most recent.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.7.

# `t`

```elixir
@opaque t()
```

Representative type for the event algorithm.

# `execute`

```elixir
@spec execute(t()) ::
  {:event, new_state :: t(),
   BACnet.Protocol.NotificationParameters.BufferReady.t()}
  | {:no_event, state :: t()}
```

Calculates the new state for the current state and parameters.
Prior to this function invocation, the state should have been
updated with `update/2`, if any of the properties has changed.

`previous_count` of `EventParameters.BufferReady` gets
automatically updated in the state on event.

ASHRAE 135:
> The conditions evaluated by this event algorithm are:
>
> (a) If pCurrentState is NORMAL, and pMonitoredValue is greater than
> or equal to pPreviousCount, and (pMonitoredValue - pPreviousCount)
> is greater than or equal to pThreshold and pThreshold is greater than 0,
> then indicate a transition to the NORMAL event state.
>
> (b) If pCurrentState is NORMAL, and pMonitoredValue is less than
> pPreviousCount, and (pMonitoredValue - pPreviousCount + 2^32 - 1)
> is greater than or equal to pThreshold and pThreshold is greater than 0,
> then indicate a transition to the NORMAL event state.

# `new`

```elixir
@spec new(
  non_neg_integer(),
  BACnet.Protocol.DeviceObjectPropertyRef.t(),
  BACnet.Protocol.EventParameters.BufferReady.t()
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
