# `BACnet.Protocol.EventAlgorithms.ChangeOfValue`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_algorithms/change_of_value.ex#L1)

Implements the BACnet event algorithm `ChangeOfValue`.

The ChangeOfValue event algorithm, for monitored values of datatype REAL, detects
whether the absolute value of the monitored value changes by an amount equal to
or greater than a positive REAL increment.

The ChangeOfValue event algorithm, for monitored values of datatype BIT STRING,
detects whether the monitored value changes in any of the bits specified by a bitmask.

For detection of change, the value of the monitored value when a transition to NORMAL
is indicated shall be used in evaluation of the conditions until the next transition
to NORMAL is indicated. The initialization of the value used in evaluation before
the first transition to NORMAL is indicated is a local matter.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.3.

# `t`

```elixir
@opaque t()
```

Representative type for the event algorithm.

# `execute`

```elixir
@spec execute(t()) ::
  {:event, new_state :: t(),
   BACnet.Protocol.NotificationParameters.ChangeOfValue.t()}
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
updated from the state with the correct `in_alarm` state (`false`),
however to ensure the Status Flags have an overall correct status,
the user has to make sure all bits are correctly.

ASHRAE 135:
> The conditions evaluated by this event algorithm, for a monitored value of type REAL, are:
>
> (a) If pCurrentState is NORMAL, and the absolute value of pMonitoredValue changes by an amount
> equal to or greater than pIncrement for pTimeDelayNormal, then indicate a transition
> to the NORMAL event state.
>
> The conditions evaluated by this event algorithm, for a monitored value of type BIT STRING, are:
>
> (a) If pCurrentState is NORMAL, and any of the significant bits of pMonitoredValue change state
> and remain changed for pTimeDelayNormal, then indicate a transition to the NORMAL event state.

# `new`

```elixir
@spec new(float() | tuple(), BACnet.Protocol.EventParameters.ChangeOfValue.t()) :: t()
```

Creates a new algorithm state.

# `update`

```elixir
@spec update(t(), Keyword.t()) :: t()
```

Updates the state using the given parameters (`monitored_value`, `parameters`, `status_flags`).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
