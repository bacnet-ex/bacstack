# `BACnet.Protocol.EventAlgorithms.ChangeOfLifeSafety`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_algorithms/change_of_life_safety.ex#L1)

Implements the BACnet event algorithm `ChangeOfLifeSafety`.

The ChangeOfLifeSafety event algorithm detects whether the monitored value equals
a value that is listed as an alarm value or life safety alarm value.
Event state transitions are also indicated if the value of the mode algorithm changed
since the last transition indicated. In this case, any time delays are overridden
and the transition is indicated immediately.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.8.

# `t`

```elixir
@opaque t()
```

Representative type for the event algorithm.

# `execute`

```elixir
@spec execute(t()) ::
  {:event, new_state :: t(),
   BACnet.Protocol.NotificationParameters.ChangeOfLifeSafety.t()}
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
> (a) If pCurrentState is NORMAL, and pMonitoredValue is equal to any of the values
> contained in pAlarmValues, and remains within the set of values of pAlarmValues
> either for pTimeDelay or for pMode changes, then indicate a transition
> to the OFFNORMAL event state.
>
> (b) If pCurrentState is NORMAL, and pMonitoredValue is equal to any of the values
> contained in pLifeSafetyAlarmValues, and remains within the set of values of
> pLifeSafetyAlarmValues either for pTimeDelay or for pMode changes,
> then indicate a transition to the LIFE_SAFETY_ALARM event state.
>
> (c) If pCurrentState is NORMAL, and pMode changes, then indicate a transition
> to the NORMAL event state.
>
> (d) If pCurrentState is OFFNORMAL, and pMonitoredValue is not equal to any of the
> values contained in pAlarmValues and pLifeSafetyAlarmValues either for
> pTimeDelayNormal or for pMode changes, then indicate a transition
> to the NORMAL event state.
>
> (e) If pCurrentState is OFFNORMAL, and pMonitoredValue is equal to any of the values
> contained in pLifeSafetyAlarmValues, and remains within the set of values of
> pLifeSafetyAlarmValues either for pTimeDelay or for pMode changes,
> then indicate a transition to the LIFE_SAFETY_ALARM event state.
>
> (f) Optional: If pCurrentState is OFFNORMAL, and pMonitoredValue is equal to one of
> the values contained in pAlarmValues that is different from the value causing
> the last transition to OFFNORMAL, and remains equal to that value for pTimeDelay,
> then indicate a transition to the OFFNORMAL event state.
>
> (g) If pCurrentState is OFFNORMAL, and pMode changes, then indicate a transition
> to the OFFNORMAL event state.
>
> (h) If pCurrentState is LIFE_SAFETY_ALARM, and pMonitoredValue is not equal to any
> of the values contained in pAlarmValues and pLifeSafetyAlarmValues either for
> pTimeDelayNormal or for pMode changes, then indicate a transition
> to the NORMAL event state.
>
> (i) If pCurrentState is LIFE_SAFETY_ALARM, and pMonitoredValue is equal to any
> of the values contained in pAlarmValues, and remains within the set of values
> of pAlarmValues either for pTimeDelay or for pMode changes,
> then indicate a transition to the OFFNORMAL event state.
>
> (j) Optional: If pCurrentState is LIFE_SAFETY_ALARM, and pMonitoredValue is equal
> to one of the values contained in pLifeSafetyAlarmValues that is different
> from the value causing the last transition to LIFE_SAFETY_ALARM,
> and remains equal to that value for pTimeDelay,
> then indicate a transition to the LIFE_SAFETY_ALARM event state.
>
> (k) If pCurrentState is LIFE_SAFETY_ALARM, and pMode changes, then indicate
> a transition to the LIFE_SAFETY_ALARM event state.

# `new`

```elixir
@spec new(
  BACnet.Protocol.Constants.life_safety_state(),
  BACnet.Protocol.Constants.life_safety_mode(),
  BACnet.Protocol.Constants.life_safety_operation(),
  BACnet.Protocol.EventParameters.ChangeOfLifeSafety.t()
) :: t()
```

Creates a new algorithm state.

# `update`

```elixir
@spec update(t(), Keyword.t()) :: t()
```

Updates the state using the given parameters (`mode`, `monitored_value`,
`operation_expected`, `parameters`, `status_flags`).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
