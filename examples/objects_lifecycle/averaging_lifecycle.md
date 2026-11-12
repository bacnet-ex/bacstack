<!--t: Driving an Averaging object -->

# Driving an Averaging object

`BACnet.Protocol.ObjectTypes.Averaging` periodically reads one property and computes
statistics over its latest sample attempts. Use it for load profiles, temperature extrema
and short-term averages without a full historian.

The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
is the integrating application that retains results, supplies callbacks and clocks, and
delivers lifecycle operations. The Averaging module owns the sampling and window algorithm.
The host needs to keep each instance's object, opaque runtime state and replacement
execution request together.

Run the example from the repository root.

```sh
mix run examples/objects_lifecycle/averaging_lifecycle.exs
```

The walkthrough uses an Agent for storage, supplied clocks and an in-memory Analog Value
as its local source. Its remote read adapter constructs a
`BACnet.Protocol.Services.ReadProperty` request and returns a simulated response.
To drive sampling with process timers, see the
[wakeup examples](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-wakeups-continuations-and-restarts).

## Configure and initialize

The walkthrough configures a three-second window with three sample slots. Each period is
therefore one second. `window_samples` defaults to 15 if omitted. Positive window settings
and a period of at least one millisecond are required by this implementation.

The initialization context has fresh state, an initialization trigger and a bounded read
callback. `BACnet.Protocol.ObjectExecution.Lifecycle.execute/2` clears old statistics without
reading the source and requests the first sample one period later. The host needs to retain
that result before using the instance. It must not restore old VM-monotonic state after restart.

The module documentation includes a complete initialization and one-sample code example.
The walkthrough extends it through rolling statistics, errors and configuration changes.

## Drive sampling and retain results

For every due timer, the example obtains the retained result and creates a fresh
`BACnet.Protocol.ObjectExecution.Context`, preserving its state. It checks
`BACnet.Protocol.ObjectExecution.Wakeup.due?/2`, executes with a timer trigger and retains the
returned result. The explicit clock values make the example deterministic and require no sleeps.

A running host needs to replace its previous timer after every successful result and ignore
stale timer messages. Each wakeup here contains a monotonic deadline and no wall-time deadline.
Sample the clock again after the read and result commit when calculating the remaining
delay. That includes the time spent in the callback.

Early or repeated calls do not acquire the same slot twice. A computed read through
`BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` acquires a sample if due, otherwise
preserving the window and deadline. Retain the refreshed result before calling
`BACnet.Protocol.ObjectTypes.Averaging.get_property/2`.

The walkthrough produces these observations:

| Delivered time | Acquisition | Retained attempts | Valid samples | Mean |
| --- | --- | --- | --- | --- |
| Initialization | None | 0 | 0 | NaN |
| 1 second | 10 | 1 | 1 | 10 |
| 2 seconds | Read error | 2 | 1 | 10 |
| 3 seconds | 20 | 3 | 2 | 15 |
| 4 seconds | 30 | 3 | 2 | 25 |
| 5 seconds | 40 | 3 | 3 | 30 |

The failed attempt occupies a slot and ages out like any other attempt. Only successful
samples contribute to the mean. When all attempts
are missed, extrema use positive/negative infinity, mean and optional variance use NaN,
and optional extrema timestamps are unspecified.

## Prepare a reset write before committing

A write to `attempted_samples`, `object_property_reference`, `window_interval` or
`window_samples` clears the window even when its value is unchanged. Only zero may be written
to `attempted_samples` by a BACnet client. Calculated properties are read-only to clients.

The walkthrough writes the existing value 3 to `window_samples` at five seconds. Its write
helper performs all phases:

1. Build the candidate with `BACnet.Protocol.ObjectTypes.Averaging.update_property/3`.
2. Call `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3` with the original,
   candidate and matching property-write context. A successful reset candidate already has
   empty statistics. On rejection, preserve the original result and request.
3. Commit that candidate while retaining the previous runtime state and request.
4. Execute the same write trigger and retain the returned object, new state and new wakeup.

The example ends that write with zero counts and a first new deadline at six seconds.
Low-level property updates alone do not clear runtime samples or reschedule execution.

## Handle late delivery

After that reset, the walkthrough delivers a timer at 8.5 seconds. The six- and seven-second
slots are marked missed, and one current value is acquired for the eight-second slot. The
counts are three attempts and one valid sample. Its acquisition timestamp is 8.5 seconds,
and the next deadline remains nine seconds.

This is an instantaneous sampling policy. Repeated current reads could not recover the past
values. Late handling retains at most the configured number of slots, including after long
pauses. Rational periods round each absolute deadline up to the next millisecond instead of
accumulating rounded period lengths. Wall-clock corrections affect sample timestamps without
shifting the monotonic cadence.

## Supply local and remote read adapters

The local example adapter checks the source identity and property access, then reads
the stored Present_Value with `BACnet.Protocol.ObjectTypes.AnalogValue.get_property/2`.
An adapter that also serves computed properties needs to run the target's read lifecycle
before returning those values. Preserve array indices, reject cyclic reads and avoid
synchronously calling an owner that is already blocked on the read.

Averaging accepts native booleans, integers and REAL values, primitive numeric
`BACnet.Protocol.ApplicationTags.Encoding` values and singleton encoding lists. For application
representations such as enumeration atoms, a local adapter can obtain the numeric BACnet
encoding through `BACnet.Protocol.ObjectsUtility.cast_value_to_property/4`, using the source
module's object identifier. Array element reads also need the applicable partial-value conversion.

The final write changes `object_property_reference` to device 42 and resets the window.
The next read receives the full remote reference. Its adapter creates a ReadProperty APDU
and returns a simulated REAL encoding containing 21.5. A production adapter needs to resolve
the destination and bound network waits. It can use `BACnet.Stack.ClientHelper.read_property/6`
with `raw: true` to preserve numeric type information instead of obtaining enumeration atoms.
An explicit reference to the context's local device identifier normalizes to a local reference.
Other qualified references remain remote, including when no local identifier is supplied.

Operational read failures or unsupported values return a successful lifecycle result containing
a missed attempt and the latest acquisition error in opaque state. The host needs to retain
it and continue servicing wakeups. Averaging has no Reliability property. Exceptions and
malformed callback results are programming errors. Optional variance, special REAL values,
reset details and restart expectations are documented in `BACnet.Protocol.ObjectTypes.Averaging`.
