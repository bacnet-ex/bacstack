# `BACnet.Protocol.EventAlgorithms.ChangeOfCharacterString`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_algorithms/change_of_character_string.ex#L1)

Implements the BACnet event algorithm `ChangeOfCharacterString`.

The ChangeOfCharacterString event algorithm detects whether the monitored value
matches a character string that is listed as an alarm value.
Alarm values are of type BACnetOptionalCharacterString, and may also be NULL or
an empty character string.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.16.

# `t`

```elixir
@opaque t()
```

Representative type for the event algorithm.

# `execute`

```elixir
@spec execute(t()) ::
  {:event, new_state :: t(),
   BACnet.Protocol.NotificationParameters.ChangeOfCharacterString.t()}
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
> (a) If pCurrentState is NORMAL, and pMonitoredValue matches any of
> the values contained in pAlarmValues for pTimeDelay, then indicate
> a transition to the OFFNORMAL event state.
>
> (b) If pCurrentState is OFFNORMAL, and pMonitoredValue does not match any
> of the values contained in pAlarmValues for pTimeDelayNormal, then indicate
> a transition to the NORMAL event state.
>
> (c) If pCurrentState is OFFNORMAL, and pMonitoredValue matches one of the
> values contained in pAlarmValues that is different from the value that caused
> the last transition to OFFNORMAL, and remains equal to that value for pTimeDelay,
> then indicate a transition to the OFFNORMAL event state.

# `new`

```elixir
@spec new(String.t(), BACnet.Protocol.EventParameters.ChangeOfCharacterString.t()) ::
  t()
```

Creates a new algorithm state.

# `update`

```elixir
@spec update(t(), Keyword.t()) :: t()
```

Updates the state using the given parameters (`monitored_value`, `parameters`, `status_flags`).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
