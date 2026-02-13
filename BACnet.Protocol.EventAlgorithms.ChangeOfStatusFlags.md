# `BACnet.Protocol.EventAlgorithms.ChangeOfStatusFlags`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_algorithms/change_of_status_flags.ex#L1)

Implements the BACnet event algorithm `ChangeOfStatusFlags`.

The ChangeOfStatusFlags event algorithm detects whether a significant flag of the
monitored value of type BACnetStatusFlags has the value TRUE.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.11.

# `t`

```elixir
@opaque t()
```

Representative type for the event algorithm.

# `execute`

```elixir
@spec execute(t()) ::
  {:event, new_state :: t(),
   BACnet.Protocol.NotificationParameters.ChangeOfStatusFlags.t()}
  | {:delayed_event | :no_event, new_state :: t()}
```

Calculates the new state for the current state and parameters.
Prior to this function invocation, the state should have been
updated with `update/2`, if any of the properties has changed.

`:delayed_event` helps identifying whether the algorithm needs
to be called periodically in order to overcome the `time_delay`
and trigger a state change. As soon as `:event` or `:no_event`
is given as flag, it means the caller can go back to event
orientated calling.

The `status_flags` field of the notifications parameters is
updated from the state with the correct `in_alarm` state,
however to ensure the Status Flags have an overall correct status,
the user has to make sure all bits are correctly.

ASHRAE 135:
> The conditions evaluated by this event algorithm are:
>
> (a) If pCurrentState is NORMAL, and pMonitoredValue has a value of TRUE
> in any of its flags that also has a value of TRUE in the corresponding
> flag in pSelectedFlags for pTimeDelay, then indicate a transition to the
> OFFNORMAL event state.
>
> (b) If pCurrentState is OFFNORMAL, and pMonitoredValue has none of its
> flags set to TRUE that also has a value of TRUE in the corresponding flag
> in the pSelectedFlags event parameter for pTimeDelayNormal, then indicate
> a transition to the NORMAL event state.
>
> (c) If pCurrentState is OFFNORMAL, and the set of selected flags of
> pMonitoredValue that have a value of TRUE changes, then indicate a transition
> to the OFFNORMAL event state.

# `new`

```elixir
@spec new(
  BACnet.Protocol.StatusFlags.t(),
  BACnet.Protocol.ApplicationTags.Encoding.t() | nil,
  BACnet.Protocol.EventParameters.ChangeOfStatusFlags.t()
) :: t()
```

Creates a new algorithm state.

# `update`

```elixir
@spec update(t(), Keyword.t()) :: t()
```

Updates the state using the given parameters (`monitored_value`, `parameters`, `present_value`).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
