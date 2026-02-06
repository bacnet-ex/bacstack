# `BACnet.Protocol.EventAlgorithms.UnsignedOutOfRange`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_algorithms/unsigned_out_of_range.ex#L1)

Implements the BACnet event algorithm `UnsignedOutOfRange`.

The UnsignedOutOfRange event algorithm detects whether the monitored value exceeds a
range defined by a high limit and a low limit. Each of these limits may be enabled
or disabled. If disabled, the normal range has no lower limit or no higher limit
respectively. In order to reduce jitter of the resulting event state, a deadband
is applied when the value is in the process of returning to the normal range.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.15.

# `t`

```elixir
@opaque t()
```

Representative type for the event algorithm.

# `execute`

```elixir
@spec execute(t()) ::
  {:event, new_state :: t(),
   BACnet.Protocol.NotificationParameters.UnsignedOutOfRange.t()}
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
> (a) If pCurrentState is NORMAL, and the HighLimitEnable flag of pLimitEnable is TRUE,
> and pMonitoredValue is greater than pHighLimit for pTimeDelay, then indicate a transition
> to the HIGH_LIMIT event state.
>
> (b) If pCurrentState is NORMAL, and the LowLimitEnable flag of pLimitEnable is TRUE,
> and pMonitoredValue is less than pLowLimit for pTimeDelay, then indicate a transition
> to the LOW_LIMIT event state.
>
> (c) If pCurrentState is HIGH_LIMIT, and the HighLimitEnable flag of pLimitEnable is FALSE,
> then indicate a transition to the NORMAL event state.
>
> (d) Optional: If pCurrentState is HIGH_LIMIT, and the LowLimitEnable flag of pLimitEnable is TRUE,
> and pMonitoredValue is less than pLowLimit for pTimeDelay, then indicate a transition
> to the LOW_LIMIT event state.
>
> (e) If pCurrentState is HIGH_LIMIT, and pMonitoredValue is less than (pHighLimit - pDeadband)
> for pTimeDelayNormal, then indicate a transition to the NORMAL event state.
>
> (f) If pCurrentState is LOW_LIMIT, and the LowLimitEnable flag of pLimitEnable is FALSE,
> then indicate a transition to the NORMAL event state.
>
> (g) Optional: If pCurrentState is LOW_LIMIT, and the HighLimitEnable flag of pLimitEnable is TRUE,
> and pMonitoredValue is greater than pHighLimit for pTimeDelay, then indicate a transition
> to the HIGH_LIMIT event state.
>
> (h) If pCurrentState is LOW_LIMIT, and pMonitoredValue is greater than (pLowLimit + pDeadband)
> for pTimeDelayNormal, then indicate a transition to the NORMAL event state.

# `new`

```elixir
@spec new(
  non_neg_integer(),
  BACnet.Protocol.LimitEnable.t(),
  BACnet.Protocol.EventParameters.UnsignedOutOfRange.t()
) :: t()
```

Creates a new algorithm state.

# `update`

```elixir
@spec update(t(), Keyword.t()) :: t()
```

Updates the state using the given parameters (`limit_enable`, `monitored_value`,
`parameters`, `status_flags`).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
