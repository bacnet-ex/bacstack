# `BACnet.Protocol.EventAlgorithms.UnsignedRange`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_algorithms/unsigned_range.ex#L1)

Implements the BACnet event algorithm `UnsignedRange`.

The UnsignedRange event algorithm detects whether the monitored value exceeds a range
defined by a high limit and a low limit.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.9.

# `t`

```elixir
@opaque t()
```

Representative type for the event algorithm.

# `execute`

```elixir
@spec execute(t()) ::
  {:event, new_state :: t(),
   BACnet.Protocol.NotificationParameters.UnsignedRange.t()}
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
> (a) If pCurrentState is NORMAL, and pMonitoredValue is greater than
> pHighLimit for pTimeDelay, then indicate a transition to the
> HIGH_LIMIT event state.

> (b) If pCurrentState is NORMAL, and pMonitoredValue is less than pLowLimit
> for pTimeDelay, then indicate a transition to the LOW_LIMIT event state.
>
> (c) Optional: If pCurrentState is HIGH_LIMIT, and pMonitoredValue is less
> than pLowLimit for pTimeDelay, then indicate a transition to the
> LOW_LIMIT event state.
>
> (d) If pCurrentState is HIGH_LIMIT, and pMonitoredValue is equal to or less
> than pHighLimit for pTimeDelayNormal, then indicate a transition to the
> NORMAL event state.
> (e) Optional: If pCurrentState is LOW_LIMIT, and pMonitoredValue is greater
> than pHighLimit for pTimeDelay, then indicate a transition to the
> HIGH_LIMIT event state.
>
> (f) If pCurrentState is LOW_LIMIT, and pMonitoredValue is equal to or greater
> than pLowLimit, for pTimeDelayNormal, then indicate a transition to the
> NORMAL event state.

# `new`

```elixir
@spec new(non_neg_integer(), BACnet.Protocol.EventParameters.UnsignedRange.t()) :: t()
```

Creates a new algorithm state.

# `update`

```elixir
@spec update(t(), Keyword.t()) :: t()
```

Updates the state using the given parameters (`monitored_value`,
`parameters`, `status_flags`).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
