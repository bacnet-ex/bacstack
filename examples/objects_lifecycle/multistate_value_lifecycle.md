<!--t: Driving a Multistate Value -->

# Driving a Multistate Value

`BACnet.Protocol.ObjectTypes.MultistateValue` holds an application mode in 1..Number_Of_States.
The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
needs to serialize operations, retain complete results and supply the context of each
write. The object module performs no application calculation or hardware I/O.

Run the example from the repository root.

```sh
mix run examples/objects_lifecycle/multistate_value_lifecycle.exs
```

The source is `examples/objects_lifecycle/multistate_value_lifecycle.exs`. Its variables
represent host storage. It starts no process, timer or network operation. The Elixir
blocks below can also be run sequentially in the same IEx session.

## Initialize and retain the result

```elixir
alias BACnet.Protocol.BACnetArray
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.MultistateValue

{:ok, object} = MultistateValue.create(5, "Operating mode", %{
  number_of_states: 3,
  state_text: BACnetArray.from_list(["Off", "Low", "High"]),
  relinquish_default: 1,
  reliability: :no_fault_detected
})
start = Context.new(:initialization,
  now: ~U[2026-11-08 10:00:00Z], monotonic_time: 0)
{:ok, stored} = Lifecycle.execute(object, start)
1 = stored.object.present_value
nil = stored.next_execution
```

Selecting Relinquish_Default adds Priority_Array through their implicit relationship.
The effective command or default replaces any supplied direct value. Without either
property, the object remains non-commandable and accepts direct property updates.
State labels are optional descriptions - they do not define application behaviour.

Retain every field of `BACnet.Protocol.ObjectExecution.Result` and pass this instance's
state back on subsequent calls. Local operations require initialization. Missing,
malformed or other-instance state returns `{:error, :invalid_execution_state}`.

## Prepare, commit and execute writes

This helper constructs either a command or a direct property update, prepares it before
commit, then executes using the previous runtime state:

```elixir
write = fn stored, property, value, source, priority ->
  context = Context.new({source, property, nil, priority},
    now: start.now, monotonic_time: 0, state: stored.state)
  candidate =
    if property == :present_value and MultistateValue.has_priority_array?(stored.object),
      do: MultistateValue.set_priority(stored.object, priority || 16, value),
      else: MultistateValue.update_property(stored.object, property, value)
  with {:ok, candidate} <- candidate,
       {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, context) do
    stored = %{stored | object: prepared}
    Lifecycle.execute(stored.object, context)
  end
end

{:ok, stored} = write.(stored, :present_value, 2, :application_write, nil)
{:ok, stored} = write.(stored, :present_value, 3, :property_write, 8)
3 = stored.object.present_value
2 = stored.object.priority_array.priority_16
```

The lowest numbered non-nil priority wins. The host needs to use priority 16 when a
BACnet command omits it. Lower-priority commands remain stored while masked. Retain the
complete successful result before the next operation. On rejection, keep the original
object, runtime state and wakeup. Preparation is pure and returns no partial object.
Every accepted write needs its own lifecycle operation, including same-value or masked
commands. Raw property functions do not execute the lifecycle themselves.

`BACnet.Protocol.ObjectTypes.MultistateValue.set_priority/3` accepts nil for slot
relinquishment. Priority 6 is reserved and unavailable for commands or relinquishment:

```elixir
{:error, :write_access_denied} =
  write.(stored, :present_value, 2, :property_write, 6)
{:ok, stored} = write.(stored, :present_value, nil, :property_write, 8)
2 = stored.object.present_value
{:ok, stored} = write.(stored, :present_value, nil, :property_write, nil)
1 = stored.object.present_value
```

All commands and the relinquish default need to remain in 1..Number_Of_States, including
masked values. Commandable Present_Value cannot be updated directly. The host still
needs to enforce service permissions, read-only annotations, indices and priority rules.

## Separate local production from BACnet simulation

Use application origin for normal local value production and BACnet origin for requests
from the network. A local callback that handles a BACnet request needs to preserve its
BACnet origin. Out_Of_Service prevents local software from changing Present_Value while
BACnet writes remain available for simulation:

```elixir
{:ok, stored} = write.(stored, :out_of_service, true, :property_write, nil)
{:error, :out_of_service} =
  write.(stored, :present_value, 2, :application_write, nil)
{:ok, stored} = write.(stored, :present_value, 3, :property_write, 8)
3 = stored.object.present_value
{:ok, stored} = write.(stored, :out_of_service, false, :property_write, nil)
{:ok, stored} = write.(stored, :present_value, nil, :property_write, 8)
{:ok, stored} = write.(stored, :present_value, 2, :application_write, nil)
2 = stored.object.present_value
```

Isolation also rejects local same-value and masked Present_Value commands, and indirect
local changes to the effective value. A configuration edit that leaves the effective
value unchanged is allowed. Preparation checks the original and final Out_Of_Service
states - returning to service and supplying the next local value are separate operations.
Command arbitration continues during simulation. The lifecycle does not restore an older
application mode on return to service.

## Resize the state set deliberately

For local objects, changing Number_Of_States synchronizes a selected State_Text array.
Growth preserves old labels and appends empty strings. Shrinking truncates labels only
when the value, every priority command and the default remain valid:

```elixir
{:ok, stored} = write.(stored, :number_of_states, 4, :application_write, nil)
["Off", "Low", "High", ""] = BACnetArray.to_list(stored.object.state_text)
{:ok, stored} = write.(stored, :present_value, 4, :application_write, nil)
{:error, {:invalid_configuration, :present_value}} =
  write.(stored, :number_of_states, 2, :application_write, nil)
4 = stored.object.number_of_states
{:ok, stored} = write.(stored, :present_value, 2, :application_write, nil)
{:ok, stored} = write.(stored, :number_of_states, 2, :application_write, nil)
{:ok, stored} = write.(stored, :state_text,
  BACnetArray.from_list(["Off", "Running"]), :property_write, nil)
2 = stored.object.number_of_states
```

State_Text replacements must match the existing Number_Of_States and never change it.
A mismatched length is rejected with `{:value_failed_property_validation, :state_text}`
inside the error result. Lifecycle preflight also rejects sparse labels. Reductions do not
clamp values or clear commands - reconcile those values first. A rejected edit leaves the original count and labels intact.
The array retains its fixed/variable representation. Changing the count does not select
State_Text when absent. Adding that optional property requires matching labels.

Number_Of_States remains read-only to BACnet clients. The host needs to enforce that
service restriction even though the application can reconfigure it locally. For indexed
State_Text edits, first construct a complete candidate array, then use the same write
lifecycle. `BACnet.Protocol.BACnetArray.set_item/3` can replace one label:

```elixir
{:ok, labels} = BACnetArray.set_item(stored.object.state_text, 2, "On")
{:ok, stored} = write.(stored, :state_text, labels, :property_write, nil)
["Off", "On"] = BACnetArray.to_list(stored.object.state_text)
```

## Supply Reliability and simulate it explicitly

The application supplies Reliability from its source-health diagnosis. Rejected values
or configuration changes do not diagnose a fault. Inhibition masks a supplied report
with NO_FAULT_DETECTED and retains the latest report for restoration:

```elixir
{:ok, stored} = write.(stored, :reliability, :process_error, :application_write, nil)
{:ok, stored} = write.(stored, :reliability_evaluation_inhibit, true, :property_write, nil)
:no_fault_detected = stored.object.reliability
{:ok, stored} = write.(stored, :reliability, :communication_failure, :application_write, nil)
:no_fault_detected = stored.object.reliability
{:ok, stored} = write.(stored, :reliability_evaluation_inhibit, false, :property_write, nil)
:communication_failure = stored.object.reliability
```

Explicit out-of-service Reliability simulation is available from either origin, including
while inhibited. Entering out of service alone does not expose an earlier suppressed
report. The host needs to suppress automatic source reports during simulation - origin
alone does not distinguish automatic reporting from explicit simulation:

```elixir
{:ok, stored} = write.(stored, :reliability_evaluation_inhibit, true, :property_write, nil)
{:ok, stored} = write.(stored, :out_of_service, true, :property_write, nil)
:no_fault_detected = stored.object.reliability
{:ok, stored} = write.(stored, :reliability, :process_error, :application_write, nil)
:process_error = stored.object.reliability
true = stored.object.status_flags.fault
```

Returning to service while inhibited masks simulation again. Property propagation
maintains FAULT, IN_ALARM and OUT_OF_SERVICE from the supplied properties. The host supplies
OVERRIDDEN when applicable. Removing optional Reliability clears FAULT during execution.

## Read, restart and retain boundaries

```elixir
read = Context.new({:property_read, :present_value, nil},
  now: start.now, monotonic_time: 0, state: stored.state)
{:ok, stored} = Lifecycle.prepare_read(stored.object, read)
{:ok, 2} = MultistateValue.get_property(stored.object, :present_value)
nil = stored.next_execution
{:ok, restarted} = Lifecycle.execute(stored.object,
  Context.new(:initialization, now: start.now, monotonic_time: 0))
2 = restarted.object.present_value
:process_error = restarted.object.reliability
```

A pending reporting delay can request a monotonic wakeup. Replace the previous
request with `next_execution` from the retained result.
After restart, initialize restored properties with fresh context and runtime state.
Runtime-only suppressed reports cannot be recovered from NO_FAULT_DETECTED - supply a
fresh source report when necessary. Remote snapshots remain passive and reject local
write preparation.

## Intrinsic reporting

Create the local object with `intrinsic_reporting: true` to enable reporting.
CHANGE_OF_STATE compares the effective Present_Value with Alarm_Values,
including after a priority is relinquished. FAULT_STATE uses Fault_Values
while reliability evaluation is enabled. A state in both lists produces a
reliability fault first. After the fault clears, a remaining alarm condition
is evaluated in an immediate continuation.

With Fault_Values configured, the fault algorithm supplies Reliability while
evaluation is enabled. Set Reliability_Evaluation_Inhibit to true before an
out-of-service simulation write to retain the written Reliability.

Call `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after
committing each result. The
[intrinsic reporting example](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-intrinsic-transitions)
shows when to send a notification and how to handle acknowledgment.
