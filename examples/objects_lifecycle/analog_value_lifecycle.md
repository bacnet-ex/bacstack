<!--t: Driving an Analog Value -->

# Driving an Analog Value

`BACnet.Protocol.ObjectTypes.AnalogValue` represents an in-memory engineering value,
such as a setpoint, calculated result or tuning constant. The object module defines its
lifecycle behaviour. The integrating application - the
[object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host) -
needs to retain the object and runtime state, serialize operations and preserve write origin.
No host I/O callback or periodic calculation is required for this object.

Run the example from the repository root.

```sh
mix run examples/objects_lifecycle/analog_value_lifecycle.exs
```

The source is `examples/objects_lifecycle/analog_value_lifecycle.exs`. Its variables
represent retained host storage. It demonstrates ordinary application writes, adding
commandability, masked commands, relinquishment, out-of-service simulation and reliability
inhibition. It starts no processes or timers and performs no network operations.

## Initialize and retain the result

The following Elixir blocks can be run in order in the same IEx session:

```elixir
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.AnalogValue

{:ok, object} = AnalogValue.create(30, "Room setpoint", %{
  present_value: 21.0,
  units: :degrees_celsius,
  reliability: :process_error
})
start = Context.new(:initialization,
  now: ~U[2026-11-08 10:00:00Z], monotonic_time: 0)
{:ok, stored} = Lifecycle.execute(object, start)
21.0 = stored.object.present_value
nil = stored.next_execution
```

Retain all fields of `BACnet.Protocol.ObjectExecution.Result` and pass the returned
state back for the same instance. Initialization establishes a baseline from the supplied
properties. Other local operations require that state. With intrinsic reporting enabled,
a pending alarm or recovery can request a wakeup. Replace the previous request with
`next_execution` from the retained result.

## Prepare, commit and execute writes

For a non-commandable instance, use
`BACnet.Protocol.ObjectTypes.AnalogValue.update_property/3` to construct the candidate:

```elixir
write = Context.new({:application_write, :present_value, nil, nil},
  now: ~U[2026-11-08 10:00:01Z], monotonic_time: 1000, state: stored.state)
{:ok, candidate} = AnalogValue.update_property(stored.object, :present_value, 22.0)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, write)
stored = %{stored | object: prepared}
{:ok, stored} = Lifecycle.execute(stored.object, write)
22.0 = stored.object.present_value
```

The host needs to commit the prepared object while retaining the previous runtime state,
then execute with the same context before exposing the operation. These variable updates
perform that sequence synchronously. Deliver every accepted write, including same-value
writes. On preparation failure, retain the original object, state and wakeup. A raw setter
neither performs lifecycle origin checks nor runs execution.

The host also needs to enforce service permissions, read-only annotations, array indices
and BACnet priority rules. Application writes use `:application_write`. BACnet requests
use `:property_write`, including requests handled by a local callback.

## Select commandability and relinquish a command

The Priority_Array/Relinquish_Default pair selects optional commandability. Adding either
property supplies its partner and replaces the previous direct value with the effective
command value:

```elixir
write = Context.new({:application_write, :relinquish_default, nil, nil},
  now: ~U[2026-11-08 10:00:02Z], monotonic_time: 2000, state: stored.state)
{:ok, candidate} = AnalogValue.add_property(stored.object, :relinquish_default, 19.0)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, write)
stored = %{stored | object: prepared}
{:ok, stored} = Lifecycle.execute(stored.object, write)
19.0 = stored.object.present_value

write = Context.new({:property_write, :present_value, nil, 8},
  now: ~U[2026-11-08 10:00:03Z], monotonic_time: 3000, state: stored.state)
{:ok, candidate} = AnalogValue.set_priority(stored.object, 8, 23.0)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, write)
stored = %{stored | object: prepared}
{:ok, stored} = Lifecycle.execute(stored.object, write)
23.0 = stored.object.present_value

relinquish = %{write | state: stored.state}
{:ok, candidate} = AnalogValue.set_priority(stored.object, 8, nil)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, relinquish)
stored = %{stored | object: prepared}
{:ok, stored} = Lifecycle.execute(stored.object, relinquish)
19.0 = stored.object.present_value
```

For commandable instances, use `BACnet.Protocol.ObjectTypes.AnalogValue.set_priority/3`
for both BACnet and application Present_Value writes. A missing BACnet priority means 16 -
the host needs to supply that value to the setter. A nil value relinquishes only that slot.
Lower-priority commands remain stored while masked. The lowest numbered non-nil slot wins,
falling back to Relinquish_Default when all slots are nil. Priority 6 is reserved and denied.
No minimum on/off timers are implemented for Analog Value. For non-commandable properties,
a supplied command priority is ignored.

## Out-of-service simulation

Out of service prevents normal local application writes to Present_Value. It includes
same-value and masked commands, plus indirect local changes to the effective value.
BACnet writes remain available and commandable instances continue to arbitrate:

```elixir
write = Context.new({:property_write, :out_of_service, nil, nil},
  now: ~U[2026-11-08 10:00:04Z], monotonic_time: 4000, state: stored.state)
{:ok, candidate} = AnalogValue.update_property(stored.object, :out_of_service, true)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, write)
stored = %{stored | object: prepared}
{:ok, stored} = Lifecycle.execute(stored.object, write)

local = %{write | trigger: {:application_write, :present_value, nil, 8}, state: stored.state}
{:ok, candidate} = AnalogValue.set_priority(stored.object, 8, 25.0)
{:error, :out_of_service} = Lifecycle.prepare_write(stored.object, candidate, local)
19.0 = stored.object.present_value

network = %{local | trigger: {:property_write, :present_value, nil, 8}}
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, network)
stored = %{stored | object: prepared}
{:ok, stored} = Lifecycle.execute(stored.object, network)
25.0 = stored.object.present_value
```

A rejected candidate is not committed. Returning to service permits local value production
again. Out of service does not define hardware isolation for this software value or prevent
Reliability reports from being supplied.

## Reliability inhibition and explicit simulation

The application supplies Reliability from its source health. Lifecycle execution does not
infer a fault from a failed write or calculate one from alarm limits. The existing property
mechanics maintain the corresponding FAULT status flag.

When Reliability_Evaluation_Inhibit is true, the lifecycle presents NO_FAULT_DETECTED.
It retains the latest supplied report for restoration when inhibition ends. An alternate
Reliability explicitly supplied or written while out of service remains visible even while
inhibited. Entering out of service alone does not expose an earlier suppressed report.

Continuing the out-of-service example, select inhibition and write a simulation value:

```elixir
write = Context.new({:property_write, :reliability_evaluation_inhibit, nil, nil},
  now: ~U[2026-11-08 10:00:05Z], monotonic_time: 5000, state: stored.state)
{:ok, candidate} = AnalogValue.update_property(stored.object, :reliability_evaluation_inhibit, true)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, write)
stored = %{stored | object: prepared}
{:ok, stored} = Lifecycle.execute(stored.object, write)
:no_fault_detected = stored.object.reliability

write = %{write | trigger: {:property_write, :reliability, nil, nil}, state: stored.state}
{:ok, candidate} = AnalogValue.update_property(stored.object, :reliability, :no_sensor)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, write)
stored = %{stored | object: prepared}
{:ok, stored} = Lifecycle.execute(stored.object, write)
:no_sensor = stored.object.reliability
true = stored.object.status_flags.fault
```

Returning to service while inhibited masks that simulation again. Disabling inhibition
restores the latest supplied report. Initialization with an out-of-service object treats
its supplied Reliability as the initial simulation value.

## Reads, restart and boundaries

A read can use `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` before the getter:

```elixir
read = Context.new({:property_read, :present_value, nil},
  now: ~U[2026-11-08 10:00:06Z], monotonic_time: 6000, state: stored.state)
{:ok, stored} = Lifecycle.prepare_read(stored.object, read)
{:ok, 25.0} = AnalogValue.get_property(stored.object, :present_value)
nil = stored.next_execution
```

Wall-clock changes and monotonic time do not drive arithmetic for this core implementation.
After a restart, initialize from restored object properties with fresh context and runtime
state. A suppressed report that existed only in old runtime state is not reconstructible
from a property exposing NO_FAULT_DETECTED - supply a fresh report when needed.

Missing, malformed or other-instance state returns `{:error, :invalid_execution_state}`.
A stored non-nil priority-6 command returns `{:error, {:invalid_configuration, :priority_6}}`.
Neither error supplies a replacement result. Remote snapshots remain passive and reject
local write preparation.

## Intrinsic reporting

Create the local object with `intrinsic_reporting: true` to enable reporting.
OUT_OF_RANGE monitors Present_Value, including the effective command when a
priority array is selected. Set Low_Limit and High_Limit and enable the checks
through Limit_Enable. These limits and Deadband govern event detection and
recovery. Min_Pres_Value and Max_Pres_Value govern the permitted command range.

Call `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after
committing each result. The
[intrinsic reporting example](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-intrinsic-transitions)
shows when to send a notification and how to handle acknowledgment.
