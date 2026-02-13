# `BACnet.Protocol.EventAlgorithms.ChangeOfState`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_algorithms/change_of_state.ex#L1)

Implements the BACnet event algorithm `ChangeOfState`.

The ChangeOfState event algorithm detects whether the monitored value equals a value
that is listed as an alarm value. The monitored value may be of any discrete or
enumerated datatype, including Boolean.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.2.

# `t`

```elixir
@opaque t()
```

Representative type for the event algorithm.

# `execute`

```elixir
@spec execute(t()) ::
  {:event, new_state :: t(),
   BACnet.Protocol.NotificationParameters.ChangeOfState.t()}
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
> (a) If pCurrentState is NORMAL, and pMonitoredValue is equal to any
> of the values contained in pAlarmValues for pTimeDelay,
> then indicate a transition to the OFFNORMAL event state.
>
> (b) If pCurrentState is OFFNORMAL, and pMonitoredValue is not equal
> to any of the values contained in pAlarmValues for pTimeDelayNormal,
> then indicate a transition to the NORMAL event state.
>
> (c) Optional: If pCurrentState is OFFNORMAL, and pMonitoredValue is
> equal to one of the values contained in pAlarmValues that is different
> from the value that caused the last transition to OFFNORMAL, and remains
> equal to that value for pTimeDelay,
> then indicate a transition to the OFFNORMAL event state.

# `new`

```elixir
@spec new(
  BACnet.Protocol.PropertyState.t(),
  BACnet.Protocol.EventParameters.ChangeOfState.t()
) :: t()
```

Creates a new algorithm state.

# `update`

```elixir
@spec update(t(), Keyword.t()) :: t()
```

Updates the state using the given parameters (`monitored_value`, `parameters`, `status_flags`).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
