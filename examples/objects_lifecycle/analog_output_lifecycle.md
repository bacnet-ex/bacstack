<!--t: Driving an Analog Output -->

# Driving an Analog Output

`BACnet.Protocol.ObjectTypes.AnalogOutput` represents a prioritized engineering command
for an output channel or actuator. The object module maintains its command and reliability
behaviour. The integrating application - the
[object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host) -
needs to retain results, serialize operations, apply in-service commands through its driver
and supply hardware reliability reports. Lifecycle execution performs no hardware I/O.

Run the example from the repository root.

```sh
mix run examples/objects_lifecycle/analog_output_lifecycle.exs
```

The source is `examples/objects_lifecycle/analog_output_lifecycle.exs`. Its variables
represent host storage. Its adapter records requested values and holds its last request
while out of service. This is an example physical policy - a real adapter needs its own
implementation. A recorded command does not prove that an actuator reached that value.
The example starts no processes or timers and performs no network operations.

## Initialize and retain

The following Elixir blocks can be run in order in the same IEx session:

```elixir
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.AnalogOutput

{:ok, object} = AnalogOutput.create(40, "Valve command", %{
  units: :percent, relinquish_default: 20.0, reliability: :no_output
})
start = Context.new(:initialization,
  now: ~U[2026-11-08 10:00:00Z], monotonic_time: 0)
{:ok, stored} = Lifecycle.execute(object, start)
20.0 = stored.object.present_value
nil = stored.next_execution
```

Priority_Array and Relinquish_Default are required. Initialization establishes the
command/reliability baseline from supplied properties and performs no adapter operation.
Retain every field of `BACnet.Protocol.ObjectExecution.Result` and pass that instance's
state back on subsequent calls. The host needs to keep state separately for each object.

## Prepare, commit and execute commands

This helper represents one serialized host write. The caller retains its returned result.
It preserves the actual origin, applies the default BACnet priority of 16 and completes
execution before returning the operation:

```elixir
write = fn stored, property, value, source, priority ->
  context = Context.new({source, property, nil, priority},
    now: start.now, monotonic_time: 0, state: stored.state)
  candidate =
    if property == :present_value,
      do: AnalogOutput.set_priority(stored.object, priority || 16, value),
      else: AnalogOutput.update_property(stored.object, property, value)

  with {:ok, candidate} <- candidate,
       {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, context) do
    stored = %{stored | object: prepared}
    Lifecycle.execute(stored.object, context)
  end
end

{:ok, stored} = write.(stored, :present_value, 40.0, :property_write, 8)
{:ok, stored} = write.(stored, :present_value, 75.0, :application_write, nil)
40.0 = stored.object.present_value
75.0 = stored.object.priority_array.priority_16
```

`BACnet.Protocol.ObjectTypes.AnalogOutput.set_priority/3` constructs the command candidate.
`BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3` checks it before commit.
On preparation failure, retain the original object, state and wakeup. On success, the
host needs to commit the prepared object while retaining the previous state, execute
with the same context and retain the complete result before exposing another operation.
Deliver every accepted write, including same-value writes. Raw setters do not perform
lifecycle origin checks or execution.

BACnet requests use `:property_write`, even when a local callback handles the request.
Local logical commands and adapter reliability reports use `:application_write`. The host
also needs to enforce service permissions, read-only annotations, array indices and
BACnet priority rules. The array itself is read-only to BACnet clients.

A nil command relinquishes only its slot. The lowest numbered non-nil slot wins - if
all slots are nil, Relinquish_Default becomes effective. Masked commands remain stored.
Priority 6 is reserved and rejected, even though Analog Output has no minimum on/off timer:

```elixir
{:error, :write_access_denied} = AnalogOutput.set_priority(stored.object, 6, 50.0)
```

## Physical requests and out-of-service simulation

This example adapter records requests in a list. Its chosen policy holds the last request
while out of service. A real driver needs to implement the physical isolation and report
actual channel health independently:

```elixir
apply_command = fn stored, requests ->
  if stored.object.out_of_service,
    do: requests,
    else: [AnalogOutput.get_output(stored.object) | requests]
end
requests = apply_command.(stored, [])
[40.0] = requests

{:ok, stored} = write.(stored, :out_of_service, true, :property_write, nil)
{:ok, stored} = write.(stored, :present_value, 90.0, :application_write, 2)
90.0 = stored.object.present_value
requests = apply_command.(stored, requests)
[40.0] = requests
+0.0 = AnalogOutput.get_output(stored.object)
40.0 = AnalogOutput.get_output(stored.object, hd(requests))
```

`BACnet.Protocol.ObjectTypes.AnalogOutput.get_output/2` selects the in-service command or
its caller-supplied decoupled fallback. The default fallback is `0.0` - it is neither a
measurement nor a prescribed physical policy. Both BACnet and local logical commands
continue to arbitrate during simulation. Direct Present_Value updates must not bypass
the priority mechanism.

Relinquish the simulation and prior priority-8 command, then resume the current command:

```elixir
{:ok, stored} = write.(stored, :present_value, nil, :application_write, 2)
{:ok, stored} = write.(stored, :present_value, nil, :property_write, 8)
75.0 = stored.object.present_value
{:ok, stored} = write.(stored, :out_of_service, false, :property_write, nil)
requests = apply_command.(stored, requests)
[75.0, 40.0] = requests
```

The host needs to apply the current retained command when returning to service, including
commands accepted during simulation. Requesting an output does not establish its physical
value. This module does not manufacture feedback from its command.

## Reliability isolation and inhibition

Supply hardware diagnosis through application Reliability writes while in service.
While out of service, explicit writes from either origin can simulate Reliability,
including same-value writes. The host needs to stop forwarding automatic hardware reports
while decoupled - origin alone does not identify the intent of a write. A previously known
physical report is restored on return to service:

```elixir
{:ok, stored} = write.(stored, :out_of_service, true, :property_write, nil)
{:ok, stored} = write.(stored, :reliability, :no_fault_detected, :application_write, nil)
:no_fault_detected = stored.object.reliability
{:ok, stored} = write.(stored, :reliability, :process_error, :property_write, nil)
:process_error = stored.object.reliability
{:ok, stored} = write.(stored, :out_of_service, false, :property_write, nil)
:no_output = stored.object.reliability
```

Reliability_Evaluation_Inhibit masks physical reports with NO_FAULT_DETECTED, retaining
the latest report for restoration when inhibition ends:

```elixir
{:ok, stored} = write.(stored, :reliability_evaluation_inhibit, true, :property_write, nil)
{:ok, stored} = write.(stored, :reliability, :communication_failure, :application_write, nil)
:no_fault_detected = stored.object.reliability
false = stored.object.status_flags.fault
{:ok, stored} = write.(stored, :reliability_evaluation_inhibit, false, :property_write, nil)
:communication_failure = stored.object.reliability
true = stored.object.status_flags.fault
```

Explicit out-of-service Reliability simulation remains visible while inhibited. Entering
out of service alone does not expose an earlier suppressed report. Returning to service
while inhibited masks simulation again:

```elixir
{:ok, stored} = write.(stored, :reliability_evaluation_inhibit, true, :property_write, nil)
{:ok, stored} = write.(stored, :out_of_service, true, :property_write, nil)
:no_fault_detected = stored.object.reliability
{:ok, stored} = write.(stored, :reliability, :process_error, :property_write, nil)
:process_error = stored.object.reliability
{:ok, stored} = write.(stored, :out_of_service, false, :property_write, nil)
:no_fault_detected = stored.object.reliability
```

The host needs to supply a fresh physical report when retained observations are insufficient.
If initialization begins out of service, the supplied Reliability represents simulation.
Without a known physical report, that property remains on return to service until a fresh
report arrives, subject to inhibition. The lifecycle infers no hardware fault from a rejected
write, a range error or invalid runtime state.

## Reads, restart and remaining boundaries

A read can refresh the lifecycle before obtaining the property:

```elixir
read = Context.new({:property_read, :present_value, nil},
  now: start.now, monotonic_time: 0, state: stored.state)
{:ok, stored} = Lifecycle.prepare_read(stored.object, read)
{:ok, 75.0} = AnalogOutput.get_property(stored.object, :present_value)
nil = stored.next_execution
```

An active reporting delay can request a monotonic wakeup. Replace the previous request
with `next_execution` from the retained result. After a restart, initialize from restored
object properties with fresh context and state. A suppressed physical report stored only in old runtime state cannot
be reconstructed from a Reliability property exposing NO_FAULT_DETECTED.

Local instances require initialization. Missing, malformed or other-instance state returns
`{:error, :invalid_execution_state}`. A stored non-nil priority-6 command returns
`{:error, {:invalid_configuration, :priority_6}}`. Neither error supplies a replacement
result. Remote snapshots remain passive and reject local write preparation.

## Intrinsic reporting

Create the local object with `intrinsic_reporting: true` to enable reporting.
OUT_OF_RANGE monitors the effective Present_Value after priority
resolution. A write to a masked slot can change the Priority_Array while
leaving the monitored value unchanged. Select the limits with Limit_Enable
and use Deadband to control recovery. A reported output fault takes precedence
over a limit alarm.

Call `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after
committing each result. The
[intrinsic reporting example](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-intrinsic-transitions)
shows when to send a notification and how to handle acknowledgment.
