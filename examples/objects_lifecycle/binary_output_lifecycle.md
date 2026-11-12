<!--t: Driving a Binary Output -->

# Driving a Binary Output

`BACnet.Protocol.ObjectTypes.BinaryOutput` represents a commandable two-state output.
Its lifecycle maintains logical transition history, elapsed active seconds and minimum
on/off protection. The integrating application - the
[object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host) -
needs to retain results, serialize operations, deliver wakeups and connect the object to
its physical adapter. The object implementation performs no hardware I/O.

Run the example from the repository root.

```sh
mix run examples/objects_lifecycle/binary_output_lifecycle.exs
```

The source is `examples/objects_lifecycle/binary_output_lifecycle.exs`. It supplies clocks,
retains each result and records a simulated physical signal. Its chosen adapter policy
holds that signal unchanged while out of service. It starts no timers or processes and
performs no network operations. A running host needs the timer integration examples in
`BACnet.Protocol.ObjectExecution.Lifecycle`.

## Initialize and command

```elixir
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.BinaryOutput

{:ok, object} = BinaryOutput.create(30, "Pump enable", %{
  polarity: :reverse,
  min_on_time: 3,
  min_off_time: 2,
  feedback_value: false,
  reliability: :no_fault_detected,
  change_of_state_count: 0,
  elapsed_active_time: 0
})
start = Context.new(:initialization,
  now: ~U[2026-11-08 10:00:00Z], monotonic_time: 0)
{:ok, stored} = Lifecycle.execute(object, start)

command = Context.new({:property_write, :present_value, nil, 8},
  now: ~U[2026-11-08 10:00:00.100Z], monotonic_time: 100, state: stored.state)
{:ok, candidate} = BinaryOutput.set_priority(stored.object, 8, true)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, command)
{:ok, stored} = Lifecycle.execute(prepared, command)
```

Retain all fields of `BACnet.Protocol.ObjectExecution.Result` for this instance. Build
candidates through the property API, prepare them without I/O, commit the returned
candidate and execute with the same clocks and previous runtime state. Complete that
sequence before exposing another operation or applying its command to hardware. Deliver
same-value writes too. Rejected preparation leaves the original object, state and wakeup
unchanged. The raw property API does not run this lifecycle itself.

The priority array and relinquish default are always present on Binary Output. An omitted
command priority means 16. NULL (`nil`) relinquishes its slot. Priority 6 belongs to the
minimum-time mechanism and external commands using it are rejected even without timing
properties. The host needs to enforce BACnet access rules for the read-only priority array.

## Apply the physical command

```elixir
if stored.object.out_of_service do
  :adapter_isolated
else
  physical_signal = BinaryOutput.get_output(stored.object)
  {:apply_to_adapter, physical_signal}
end
```

This code computes an adapter action. Apply it through the application's driver. With
normal polarity the signal equals the logical command. Reverse polarity inverts it.
A polarity change updates the requested physical signal and preserves the logical
transition count, active seconds and start time of a minimum-time hold.

`BACnet.Protocol.ObjectTypes.BinaryOutput.get_output/2` accepts a fallback while out of
service. For example, `BACnet.Protocol.ObjectTypes.BinaryOutput.get_output/2` with a true
second argument returns true while decoupled, regardless of polarity:

```elixir
{:ok, candidate} = BinaryOutput.update_property(stored.object, :out_of_service, true)
isolate = Context.new({:property_write, :out_of_service, nil, nil},
  now: ~U[2026-11-08 10:00:00.200Z], monotonic_time: 200, state: stored.state)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, isolate)
{:ok, stored} = Lifecycle.execute(prepared, isolate)
true = BinaryOutput.get_output(stored.object, true)
```

The fallback does not mandate a hardware policy or prove what the actuator is doing.
The default false fallback is a convenience value. The host needs to isolate its physical
adapter while out of service and reapply the current command and polarity when returning
to service. The walkthrough demonstrates a policy that retains the last physical signal.

## Minimum times and wakeups

An effective ACTIVE transition puts ACTIVE into priority 6 for `min_on_time` seconds.
INACTIVE uses `min_off_time`. Lower-priority commands remain stored while masked. Expiry
clears the hold and reevaluates the array. A resulting logical transition starts its new
applicable hold. Priorities 1 through 5 can override a hold and start timing for their
new state. Same-value and masked writes do not restart it. Duration edits reevaluate the
current hold from its original logical transition time.

Use each result's replacement `BACnet.Protocol.ObjectExecution.Wakeup`. It may request an
earlier second boundary for active-time accounting rather than the hold's final expiry.
For a supplied context with a fresh time, check
`BACnet.Protocol.ObjectExecution.Wakeup.due?/2`, execute with `:timer`, retain the result
and replace the previous timer:

```elixir
timer = Context.new(:timer,
  now: ~U[2026-11-08 10:00:01.100Z], monotonic_time: 1100, state: stored.state)
true = BACnet.Protocol.ObjectExecution.Wakeup.due?(stored.next_execution, timer)
{:ok, stored} = Lifecycle.execute(stored.object, timer)
```

The object never arms a timer itself. The host needs timely wakeup delivery to observe
transitions in order. Late calls accrue all elapsed whole ACTIVE seconds; they cannot
recover hardware events or transitions that the host never delivered.

## Logical history, totals and resets

Any transition of effective Present_Value increments the optional state-change count and
stamps `change_of_state_time`. Polarity changes, physical feedback changes and commands
masked by higher priorities are not logical transitions. The count retains its existing
non-negative integer range without a fixed wrap limit.

The elapsed-time indicator is **Present_Value**, a permitted local choice for Binary
Output. The algorithm does not derive active seconds from feedback or the physical signal.
Monotonic milliseconds accumulate into whole seconds, preserving the fractional remainder
across inactive intervals. The seconds total wraps modulo 2^32 without stamping a reset.
Wall-clock adjustments affect timestamps rather than these durations.

Zero total writes stamp their corresponding reset times, including repeated zero writes:

```elixir
reset = Context.new({:property_write, :elapsed_active_time, nil, nil},
  now: ~U[2026-11-08 10:00:01.200Z], monotonic_time: 1200, state: stored.state)
{:ok, candidate} = BinaryOutput.update_property(stored.object, :elapsed_active_time, 0)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, reset)
{:ok, stored} = Lifecycle.execute(prepared, reset)
```

Nonzero total writes leave reset timestamps unchanged. Reset timestamps are writable and
do not themselves clear totals. An active-time total write also discards its fractional
remainder. Any selected transition-history member brings its other two partners; elapsed
active time has its own reset-time partner.

Before a computed read, refresh with fresh clocks, retain the result, then use the getter:

```elixir
read = Context.new({:property_read, :elapsed_active_time, nil},
  now: ~U[2026-11-08 10:00:01.700Z], monotonic_time: 1700, state: stored.state)
{:ok, stored} = Lifecycle.prepare_read(stored.object, read)
{:ok, seconds} = BinaryOutput.get_property(stored.object, :elapsed_active_time)
0 = seconds
```

## Independent feedback and physical reliability

Feedback can be selected without intrinsic reporting. It represents the actual entity
controlled by the logical command. The host supplies its logical value after any adapter
mapping. It may differ from both Present_Value and the physical electrical signal.

Physical feedback and reliability updates use `:application_write` triggers:

```elixir
feedback = Context.new({:application_write, :feedback_value, nil, nil},
  now: ~U[2026-11-08 10:00:01.800Z], monotonic_time: 1800, state: stored.state)
{:ok, candidate} = BinaryOutput.update_property(stored.object, :feedback_value, true)
{:error, :out_of_service} = Lifecycle.prepare_write(stored.object, candidate, feedback)
```

This example remains out of service from the isolation step above. Once back in service,
the same sequence can succeed - execute the prepared write and retain its result. Physical
reliability reports can use `:reliability` with application origin while in service.
While out of service, explicit Reliability simulation is accepted from either origin,
including same-value writes. The host needs to stop forwarding automatic hardware
Reliability reports while decoupled - application origin alone does not identify intent.
The object updates the corresponding fault flag through its existing property mechanics.
It does not infer a physical fault from a command or a rejected write.

For example, explicitly simulate Reliability locally while the output remains isolated:

```elixir
simulation = Context.new({:application_write, :reliability, nil, nil},
  now: ~U[2026-11-08 10:00:01.850Z], monotonic_time: 1850, state: stored.state)
{:ok, candidate} = BinaryOutput.update_property(stored.object, :reliability, :process_error)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, simulation)
{:ok, stored} = Lifecycle.execute(prepared, simulation)
:process_error = stored.object.reliability
true = stored.object.status_flags.fault
```

While out of service, BACnet writes can also simulate feedback. Logical commands
from either origin, priority arbitration, minimum times and history accounting continue.
This differs from Binary Value, where out of service prevents local software value writes.
The host needs to preserve origin rather than classifying every local callback as an
application write - a local adapter processing a BACnet request retains its BACnet origin.

## Modeled command-following feedback

For outputs whose feedback is intentionally modeled as following the command, select the
existing creation option:

```elixir
{:ok, modeled} = BinaryOutput.create(31, "Modeled output", %{}, auto_write_feedback: true)
start = Context.new(:initialization,
  now: ~U[2026-11-08 10:00:00Z], monotonic_time: 0)
{:ok, modeled_result} = Lifecycle.execute(modeled, start)
command = Context.new({:property_write, :present_value, nil, 8},
  now: ~U[2026-11-08 10:00:00.100Z], monotonic_time: 100, state: modeled_result.state)
{:ok, candidate} = BinaryOutput.set_priority(modeled_result.object, 8, true)
{:ok, prepared} = Lifecycle.prepare_write(modeled_result.object, candidate, command)
{:ok, modeled_result} = Lifecycle.execute(prepared, command)
true = modeled_result.object.feedback_value
```

The property mechanics copy logical Present_Value into feedback, including out-of-service
simulation. This does not measure the physical device or prove successful actuation. The
option selects the feedback property automatically. Explicit feedback writes are rejected
by lifecycle preparation with `{:error, :feedback_managed_automatically}` in this mode.
Choose independent feedback when an adapter reports actual state. The runnable walkthrough
includes both modes.

## Restart and capability boundaries

Initialization establishes the history baseline and retains totals and reset timestamps. A stored hold restarts for its full applicable duration at the
new monotonic origin. Obsolete holds are reconciled, counting actual logical changes.
After a VM restart, supply fresh clocks and runtime state rather than reusing old monotonic
timestamps. Newly selected history groups start accounting at that operation.

Invalid/cross-instance state or backwards monotonic time returns
`{:error, :invalid_execution_state}` without a replacement result. Remote snapshots remain passive.

## Intrinsic reporting

Create the local object with `intrinsic_reporting: true` to enable reporting.
COMMAND_FAILURE compares the effective Present_Value with Feedback_Value.
Use independent feedback to detect a mismatch between the command and
the adapter's reported state. With modeled feedback enabled, Feedback_Value
follows the command. A mismatch needs to persist for Time_Delay. Once the
values match, Time_Delay_Normal governs recovery.

Call `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after
committing each result. The
[intrinsic reporting example](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-intrinsic-transitions)
shows when to send a notification and how to handle acknowledgment.
