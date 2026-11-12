<!--t: Driving a Binary Input -->

# Driving a Binary Input

`BACnet.Protocol.ObjectTypes.BinaryInput` exposes a physical two-state sensor or contact.
The object applies polarity and maintains logical history and active seconds. The
[object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host) -
the integrating application or higher-level stack - needs to supply samples, clocks and
physical reliability, retain results, serialize operations and deliver requested wakeups.
This object performs no hardware or property I/O.

Run the example from the repository root.

```sh
mix run examples/objects_lifecycle/binary_input_lifecycle.exs
```

The source is `examples/objects_lifecycle/binary_input_lifecycle.exs`. It uses supplied
samples and clocks without processes, network operations or sleeping. A running host needs
the timer ownership and arming examples in `BACnet.Protocol.ObjectExecution.Lifecycle`.

## Initialize and select optional properties

```elixir
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.BinaryInput

{:ok, object} = BinaryInput.create(40, "Door contact", %{
  interface_value: :undefined,
  reliability: :no_fault_detected,
  change_of_state_count: 0,
  elapsed_active_time: 0
})
start = Context.new(:initialization,
  now: ~U[2026-11-08 10:00:00Z], monotonic_time: 0)
{:ok, stored} = Lifecycle.execute(object, start)
```

Selecting any transition-history member adds its two partners. Active time has a separate
reset-time partner. `interface_value: :undefined` explicitly selects an unknown Interface_Value -
leaving the property out or supplying nil does not select it. The raw sample is retained
separately in metadata and is initially unknown unless an initial Boolean is supplied
through the existing `physical_input` creation option.

Initialization establishes a baseline without inventing a historical transition. It retains
existing totals and reset timestamps. A known initial raw sample is mapped through current
polarity before that baseline is recorded. With no known sample, the supplied logical value
remains. Keep all fields of `BACnet.Protocol.ObjectExecution.Result`, not just the object.

## Supply a physical sample

```elixir
sample = Context.new({:application_write, :present_value, nil, nil},
  now: ~U[2026-11-08 10:00:00.100Z], monotonic_time: 100, state: stored.state)
{:ok, candidate} = BinaryInput.set_input(stored.object, true)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, sample)
{:ok, stored} = Lifecycle.execute(prepared, sample)
true = stored.object.present_value
true = stored.object.interface_value
1 = stored.object.change_of_state_count
```

`BACnet.Protocol.ObjectTypes.BinaryInput.set_input/2` builds a candidate, retains the raw
sample and applies polarity. Preparation performs no I/O or runtime-state changes. The
host needs to commit the prepared candidate and execute with the same clocks and previous
runtime state before another operation observes the input. Retain the complete returned
result. Deliver each accepted sample, including repeated identical samples - only actual
logical changes increment the count. Raw property operations do not run this lifecycle.

Physical reliability reports use a separate application write to `reliability`. The adapter
owns diagnosis and sample acquisition. The object does not poll the sensor or infer a
specific hardware fault from missing input data.

## Change polarity or mark a sample unknown

```elixir
polarity = Context.new({:property_write, :polarity, nil, nil},
  now: ~U[2026-11-08 10:00:00.200Z], monotonic_time: 200, state: stored.state)
{:ok, candidate} = BinaryInput.update_property(stored.object, :polarity, :reverse)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, polarity)
{:ok, stored} = Lifecycle.execute(prepared, polarity)
false = stored.object.present_value
false = stored.object.interface_value
2 = stored.object.change_of_state_count
```

An in-service polarity edit changes the logical value for a steady physical contact and
therefore counts as a transition. With no known raw sample, the implementation inverts the
previous logical value on a polarity change without claiming knowledge of the physical
input. Repeated execution does not apply that change twice.

A nil raw sample marks the input unknown while retaining its logical value:

```elixir
sample = Context.new({:application_write, :present_value, nil, nil},
  now: ~U[2026-11-08 10:00:00.250Z], monotonic_time: 250, state: stored.state)
{:ok, candidate} = BinaryInput.set_input(stored.object, nil)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, sample)
{:ok, stored} = Lifecycle.execute(prepared, sample)
:undefined = stored.object.interface_value
false = stored.object.present_value
```

Interface_Value is read-only to BACnet clients and is maintained only when selected. Its
Boolean states encode as enumerated 0/1 - `:undefined` encodes as NULL. The property
annotations handle both directions through `BACnet.Protocol.ObjectsUtility`:

```elixir
{:ok, null} = BACnet.Protocol.ObjectsUtility.cast_value_to_property(
  BinaryInput.get_object_identifier(stored.object), :interface_value, :undefined)
:null = null.type
{:ok, :undefined} = BACnet.Protocol.ObjectsUtility.cast_property_to_value(
  BinaryInput.get_object_identifier(stored.object), :interface_value, null)
```

## Out-of-service simulation

BACnet Present_Value writes use `:property_write` and require out of service, even for
same-value writes. Local physical samples use `:application_write`. This is a
non-commandable object, so write priority has no arbitration effect.

```elixir
isolate = Context.new({:property_write, :out_of_service, nil, nil},
  now: ~U[2026-11-08 10:00:00.300Z], monotonic_time: 300, state: stored.state)
{:ok, candidate} = BinaryInput.update_property(stored.object, :out_of_service, true)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, isolate)
{:ok, stored} = Lifecycle.execute(prepared, isolate)

simulate = Context.new({:property_write, :present_value, nil, nil},
  now: ~U[2026-11-08 10:00:00.400Z], monotonic_time: 400, state: stored.state)
{:ok, candidate} = BinaryInput.update_property(stored.object, :present_value, true)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, simulate)
{:ok, stored} = Lifecycle.execute(prepared, simulate)

sample = Context.new({:application_write, :present_value, nil, nil},
  now: ~U[2026-11-08 10:00:00.500Z], monotonic_time: 500, state: stored.state)
{:ok, candidate} = BinaryInput.set_input(stored.object, true)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, sample)
{:ok, stored} = Lifecycle.execute(prepared, sample)
true = stored.object.present_value
false = stored.object.interface_value
```

The physical observation is retained while the simulated value remains independent.
Polarity edits while out of service affect Interface_Value but leave simulated Present_Value
alone. A local application candidate that changes the simulated value is rejected.
Explicit Reliability simulation is accepted from either write origin, including same-value
writes. The host needs to stop forwarding automatic hardware Reliability updates while
decoupled - application origin alone does not identify the intent of a report.
History and active-time accounting continue to follow the simulated logical value.

For an explicit local Reliability simulation, use the same preparation and execution
sequence with application origin:

```elixir
simulation = Context.new({:application_write, :reliability, nil, nil},
  now: ~U[2026-11-08 10:00:00.600Z], monotonic_time: 600, state: stored.state)
{:ok, candidate} = BinaryInput.update_property(stored.object, :reliability, :process_error)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, simulation)
{:ok, stored} = Lifecycle.execute(prepared, simulation)
:process_error = stored.object.reliability
true = stored.object.status_flags.fault
```

## Deliver wakeups, refresh reads and reset totals

While the logical value is ACTIVE and active-time accounting is selected, execution requests
the next accumulated whole second using monotonic time:

```elixir
timer = Context.new(:timer,
  now: ~U[2026-11-08 10:00:01.400Z], monotonic_time: 1400, state: stored.state)
true = BACnet.Protocol.ObjectExecution.Wakeup.due?(stored.next_execution, timer)
{:ok, stored} = Lifecycle.execute(stored.object, timer)

read = Context.new({:property_read, :elapsed_active_time, nil},
  now: ~U[2026-11-08 10:00:01.450Z], monotonic_time: 1450, state: stored.state)
{:ok, stored} = Lifecycle.prepare_read(stored.object, read)
{:ok, 1} = BinaryInput.get_property(stored.object, :elapsed_active_time)
```

Retain every replacement wakeup. The object never arms timers itself. Fractions survive
inactive intervals, late execution accrues all elapsed whole ACTIVE seconds, and wall-clock
corrections do not alter durations. The host needs prompt sample delivery - elapsed time
cannot reveal sensor transitions that were never supplied.

Zero writes to totals stamp their reset times, even when already zero. This example retains
each result before preparing the next write:

```elixir
stored = Enum.reduce([:change_of_state_count, :elapsed_active_time], stored, fn property, current ->
  reset = Context.new({:property_write, property, nil, nil},
    now: ~U[2026-11-08 10:00:01.500Z], monotonic_time: 1500, state: current.state)
  {:ok, candidate} = BinaryInput.update_property(current.object, property, 0)
  {:ok, prepared} = Lifecycle.prepare_write(current.object, candidate, reset)
  {:ok, updated} = Lifecycle.execute(prepared, reset)
  updated
end)
```

Nonzero total writes leave reset times unchanged. Reset timestamps are writable and do
not clear totals. An active-time total replacement clears the fractional remainder.
State-change counts retain their unrestricted non-negative integer range. Elapsed seconds
wrap modulo 2^32 without treating wraparound as an explicit reset.

## Return to service and supply physical reliability

```elixir
resume = Context.new({:property_write, :out_of_service, nil, nil},
  now: ~U[2026-11-08 10:00:01.600Z], monotonic_time: 1600, state: stored.state)
{:ok, candidate} = BinaryInput.update_property(stored.object, :out_of_service, false)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, resume)
{:ok, stored} = Lifecycle.execute(prepared, resume)
false = stored.object.present_value

report = Context.new({:application_write, :reliability, nil, nil},
  now: ~U[2026-11-08 10:00:01.700Z], monotonic_time: 1700, state: stored.state)
{:ok, candidate} = BinaryInput.update_property(stored.object, :reliability, :process_error)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, report)
{:ok, stored} = Lifecycle.execute(prepared, report)
true = stored.object.status_flags.fault
```

Returning to service reconciles the latest known raw sample with current polarity. When
physical reliability is retained, it replaces simulated reliability. With no retained
physical status, the current supplied value remains until a fresh report. The host needs
to refresh sample/status when its retained observations are insufficient.

Reliability inhibition masks automatic status without discarding reports:

```elixir
inhibit = Context.new({:property_write, :reliability_evaluation_inhibit, nil, nil},
  now: ~U[2026-11-08 10:00:01.800Z], monotonic_time: 1800, state: stored.state)
{:ok, candidate} = BinaryInput.update_property(stored.object, :reliability_evaluation_inhibit, true)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, inhibit)
{:ok, stored} = Lifecycle.execute(prepared, inhibit)
:no_fault_detected = stored.object.reliability
```

A report received while inhibited is retained for resumption:

```elixir
report = Context.new({:application_write, :reliability, nil, nil},
  now: ~U[2026-11-08 10:00:01.900Z], monotonic_time: 1900, state: stored.state)
{:ok, candidate} = BinaryInput.update_property(stored.object, :reliability, :communication_failure)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, report)
{:ok, stored} = Lifecycle.execute(prepared, report)
:no_fault_detected = stored.object.reliability

resume = Context.new({:property_write, :reliability_evaluation_inhibit, nil, nil},
  now: ~U[2026-11-08 10:00:02Z], monotonic_time: 2000, state: stored.state)
{:ok, candidate} = BinaryInput.update_property(stored.object, :reliability_evaluation_inhibit, false)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, resume)
{:ok, stored} = Lifecycle.execute(prepared, resume)
:communication_failure = stored.object.reliability
```

Out-of-service simulation can explicitly preserve a different reliability while inhibited:

```elixir
stored = Enum.reduce([{:out_of_service, true}, {:reliability_evaluation_inhibit, true},
                     {:reliability, :process_error}], stored, fn {property, value}, current ->
  simulate = Context.new({:property_write, property, nil, nil},
    now: ~U[2026-11-08 10:00:02.100Z], monotonic_time: 2100, state: current.state)
  {:ok, candidate} = BinaryInput.update_property(current.object, property, value)
  {:ok, prepared} = Lifecycle.prepare_write(current.object, candidate, simulate)
  {:ok, updated} = Lifecycle.execute(prepared, simulate)
  updated
end)
:process_error = stored.object.reliability

local_simulation = Context.new({:application_write, :reliability, nil, nil},
  now: ~U[2026-11-08 10:00:02.200Z], monotonic_time: 2200, state: stored.state)
{:ok, candidate} = BinaryInput.update_property(stored.object, :reliability, :no_fault_detected)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, local_simulation)
{:ok, stored} = Lifecycle.execute(prepared, local_simulation)
:no_fault_detected = stored.object.reliability
false = stored.object.status_flags.fault
```

Initialization treats a supplied out-of-service reliability as initial simulation. Rejected
writes and invalid execution state do not themselves diagnose a hardware fault.

## Recovery and reporting boundaries

After a VM restart, initialize from the saved object properties, including totals and reset
times. Start with fresh runtime state and clocks. Newly selected history groups start
accounting when they are added. State from another instance, invalid state or a monotonic
sample earlier than the last one returns `{:error, :invalid_execution_state}`.

## Intrinsic reporting

Create the local object with `intrinsic_reporting: true` to enable reporting.
CHANGE_OF_STATE compares the logical Present_Value with Alarm_Value.
Polarity is applied before the comparison, and the simulated Present_Value
is evaluated while out of service. Time_Delay applies to the alarm and
Time_Delay_Normal applies to recovery. The next wakeup uses the earlier of any
reporting and active-time history deadlines. Reliability faults take precedence.

Remote snapshots remain passive.

Call `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after
committing each result. The
[intrinsic reporting example](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-intrinsic-transitions)
shows when to send a notification and how to handle acknowledgment.
