<!--t: Driving a Command -->

# Driving a Command

`BACnet.Protocol.ObjectTypes.Command` executes the Action list selected by each
accepted write to its `present_value`. This includes same-value writes. A zero
code or an empty list succeeds without target writes.

The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
is the integrating application or higher-level stack that retains objects and
runtime results, serializes operations and delivers requested execution steps.

Run the example from the repository root.

```sh
mix run examples/objects_lifecycle/command_lifecycle.exs
```

It demonstrates:

- Publishing busy state before target I/O and rejecting another write while busy.
- Applying a local BinaryOutput command using an encoded ENUMERATED value.
- Waiting two monotonic seconds after the first write without sleeping.
- Encoding a remote WriteProperty request through a simulated callback.
- Relinquishing a local priority with a NULL encoding.
- Repeating execution after a same-value write.
- Aborting on a simulated remote failure, leaving the earlier local write in place.

The example uses application-owned Agent storage and controlled UTC/monotonic
samples. It sends no network traffic. The local target adapter applies priority
writes through property and lifecycle operations. The remote adapter constructs
a request and simulates success or timeout - it does not contact a device.

## Accepting a command

Build a candidate with `BACnet.Protocol.ObjectTypes.Command.update_property/3`,
then call `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3` with the
original object, candidate and property-write context. On success, the host needs
to commit the accepted candidate while retaining the previous state and request,
then execute the same trigger through
`BACnet.Protocol.ObjectExecution.Lifecycle.execute/2`.

Command returns `{:error, :busy}` for a present-value write while `in_process` is
true. The host needs to return BACnet OBJECT/BUSY before committing that write.
Busy Action/Action_Text configuration writes are also rejected. The computed
`in_process` and `all_writes_successful` properties reject client write preparation.
Property updates alone do not start a sequence.

The first execution result sets `in_process` true and `all_writes_successful`
false, resets the selected list's write-success flags and requests `:immediate`.
The host needs to retain that result before delivering `:continuation`. Each
subsequent successful result also needs to be retained before another step.

## Writes and encoded values

A write callback receives the complete `BACnet.Protocol.DeviceObjectPropertyRef`,
the entry's encoded value or encoding list, and its optional priority. It needs
to resolve local or remote targets, enforce property permissions and apply the
conditional array-index and priority rules. An Action Command needs an array
index for an array target, a priority for a commandable target, and no priority
for a non-commandable target.

For local values, obtain the identifier from the target module's getter and use
`BACnet.Protocol.ObjectsUtility.cast_property_to_value/4`. Array elements use
`allow_partial: true`. NULL command relinquishment is handled before ordinary
casting by passing `nil` to the target's priority setter. Array length handling
and property-specific resizing belong to the write path.

For remote values, the adapter can pass the encoding or encoding list directly
to `BACnet.Stack.ClientHelper.write_property/6`, preserving the property, array
index and priority. The application needs to supply device-address resolution
and bounded client waits. The adapter factory in [Driving a Schedule](schedule_lifecycle.html)
illustrates this forwarding contract.

Command itself needs no object lookup callback. A recognized explicit self-device
reference is normalized to local. Other device-qualified references remain remote.
When the context's `device_identifier` is `nil`, all qualified references remain remote.

## Delays and completion

Post_Delay is measured in **seconds after the write**, including failed writes.
A positive delay also applies before final completion and after an aborting failure.
The delay is measured with monotonic milliseconds and is unaffected by wall-clock
changes.

After a write with a positive delay, Command returns another `:immediate` request.
The host needs to retain the write result and sample fresh clocks for that next
continuation. Command uses that monotonic sample to arm its post-delay request.
Reusing the pre-write sample would shorten a delay when the callback takes time.

| Phase | Returned request | Host action |
| --- | --- | --- |
| Busy state published | `:immediate` | Retain, then continue. |
| Write completed with positive Post_Delay | `:immediate` | Retain its flags, then continue with a fresh monotonic sample. |
| Post-delay armed | `BACnet.Protocol.ObjectExecution.Wakeup` with monotonic deadline | Retain, arm a timer and execute at/after the deadline. |
| Deadline delivered early | Same monotonic deadline | Retain and rearm for the remaining time. |
| More entries without delay | `:immediate` | Retain and continue. |
| Sequence complete | `nil` | Retain final flags and cancel the previous request. |

The example explicitly checks and delivers deadlines. A running host needs actual
timer arming, cancellation and stale-delivery handling - complete examples are in
`BACnet.Protocol.ObjectExecution.Lifecycle`.

## Failures, cycles and restart

An operational callback result `{:error, reason}` sets that entry's
`write_successful` false. With `quit_on_failure: false`, later writes are attempted.
With `quit_on_failure: true`, the remainder is skipped and its flags remain false.
Earlier successful writes remain in effect. At completion, `in_process` is false
and `all_writes_successful` is true only for a fully successful sequence.

Operational failures return `{:ok, result}` containing flags and retained failure
details. Command's core representation has no Reliability property. Host exceptions
and malformed callback results are programming errors and propagate. There is no
rollback and no automatic replay after completion or a VM restart.

For local self-targets or command cycles, the callback needs to check the published
busy object before calling a blocked owner. Return BUSY for a present-value write
to a running Command. This avoids re-entering its owner and implements the busy
interlock. Later commands after completion are new executions, so configuration
cycles with delays still need appropriate application configuration.

After a restart, run `:initialization` with fresh state. Command clears an
interrupted busy flag and marks the sequence unsuccessful while retaining its
recorded per-entry results. The effects of writes already performed can still
exist on their targets. Initialization does not replay the sequence.

Remote snapshots remain passive. Command does not define an intrinsic reporting
property group.
