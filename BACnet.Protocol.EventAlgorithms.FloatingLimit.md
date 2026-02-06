# `BACnet.Protocol.EventAlgorithms.FloatingLimit`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_algorithms/floating_limit.ex#L1)

Implements the BACnet event algorithm `FloatingLimit`.

The FloatingLimit event algorithm detects whether the monitored value exceeds a range
defined by a setpoint, a high difference limit, a low difference limit and a deadband.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.5.

# `t`

```elixir
@opaque t()
```

Representative type for the event algorithm.

# `execute`

```elixir
@spec execute(t()) ::
  {:event, new_state :: t(),
   BACnet.Protocol.NotificationParameters.FloatingLimit.t()}
  | {:delayed_event | :no_event, new_state :: t()}
```

Calculates the new state for the current state and parameters.
Prior to this function invocation, the state should have been
updated with `update/2`, if any of the properties has changed.

Please note that the actual setpoint needs to be set through `update/2`,
as no lookup will occur (and can not), so the actual active setpoint as float,
needs to be set in the state.

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
> (a) If pCurrentState is NORMAL, and pMonitoredValue is greater than (pSetpoint + pHighDiffLimit)
> for pTimeDelay, then indicate a transition to the HIGH_LIMIT event state.
>
> (b) If pCurrentState is NORMAL, and pMonitoredValue is less than (pSetpoint - pLowDiffLimit)
> for pTimeDelay, then indicate a transition to the LOW_LIMIT event state.
>
> (c) Optional: If pCurrentState is HIGH_LIMIT, and pMonitoredValue is less than (pSetpoint - pLowDiffLimit)
> for pTimeDelay, then indicate a transition to the LOW_LIMIT event state.
>
> (d) If pCurrentState is HIGH_LIMIT, and pMonitoredValue is less than (pSetpoint + pHighDiffLimit - pDeadband)
> for pTimeDelayNormal, then indicate a transition to the NORMAL event state.
>
> (e) Optional: If pCurrentState is LOW_LIMIT, and pMonitoredValue is greater than (pSetpoint + pHighDiffLimit)
> for pTimeDelay, then indicate a transition to the HIGH_LIMIT event state.
>
> (f) If pCurrentState is LOW_LIMIT, and pMonitoredValue is greater than (pSetpoint - pLowDiffLimit + pDeadband)
> for pTimeDelayNormal, then indicate a transition to the NORMAL event state.

# `new`

```elixir
@spec new(float(), BACnet.Protocol.EventParameters.FloatingLimit.t()) :: t()
```

Creates a new algorithm state.

# `update`

```elixir
@spec update(t(), Keyword.t()) :: t()
```

Updates the state using the given parameters (`monitored_value`, `parameters`, `setpoint`, `status_flags`).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
