<!--t: Driving an Analog Input -->

# Driving an Analog Input

`BACnet.Protocol.ObjectTypes.AnalogInput` exposes a sensor reading in engineering units.
The object module handles lifecycle write access and Reliability inhibition. The
[object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
needs to acquire and convert sensor observations, retain object/runtime results and
serialize operations. Lifecycle execution performs no hardware acquisition.

Run the example from the repository root.

```sh
mix run examples/objects_lifecycle/analog_input_lifecycle.exs
```

The source is `examples/objects_lifecycle/analog_input_lifecycle.exs`. It supplies readings
and status, keeps physical Interface_Value observations separate from out-of-service
simulation, permits explicit simulation from either origin and supplies current readings
on resumption. Its variables represent host storage. It starts no sensor, process, timer or network operation.

## Initialize and retain

The following Elixir blocks can be run in order in the same IEx session:

```elixir
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.AnalogInput

{:ok, object} = AnalogInput.create(50, "Room temperature", %{
  present_value: 21.5, interface_value: :undefined,
  units: :degrees_celsius, update_interval: 100,
  reliability: :no_fault_detected
})
start = Context.new(:initialization,
  now: ~U[2026-11-08 10:00:00Z], monotonic_time: 0)
{:ok, stored} = Lifecycle.execute(object, start)
21.5 = stored.object.present_value
:undefined = stored.object.interface_value
nil = stored.next_execution
```

Initialize local instances before other operations. Retain every field of
`BACnet.Protocol.ObjectExecution.Result` and pass that instance's state back on subsequent
calls. Initialization preserves Present_Value and seeds Reliability state from the supplied
properties. It preserves a supplied Interface_Value without deriving it from Present_Value
and does not acquire a new reading. `interface_value: :undefined` explicitly selects the
optional unknown physical value - nil at creation omits it. The property is read-only to
BACnet clients and carries revision-16 property metadata from Addendum 135-2012at.

## Supply engineering readings through the write lifecycle

This helper performs one serialized host write and returns the result to retain:

```elixir
write = fn stored, property, value, source ->
  context = Context.new({source, property, nil, nil},
    now: start.now, monotonic_time: 0, state: stored.state)
  with {:ok, candidate} <- AnalogInput.update_property(stored.object, property, value),
       {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, context) do
    stored = %{stored | object: prepared}
    Lifecycle.execute(stored.object, context)
  end
end

sample = fn stored, value ->
  context = Context.new({:application_write, :present_value, nil, nil},
    now: start.now, monotonic_time: 0, state: stored.state)
  with {:ok, candidate} <- AnalogInput.set_input(stored.object, value),
       {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, context) do
    stored = %{stored | object: prepared}
    Lifecycle.execute(stored.object, context)
  end
end

{:ok, stored} = sample.(stored, 22.0)
22.0 = stored.object.present_value
22.0 = stored.object.interface_value
{:error, :write_access_denied} = write.(stored, :present_value, 30.0, :property_write)
22.0 = stored.object.present_value
```

`BACnet.Protocol.ObjectTypes.AnalogInput.set_input/2` builds a physical-observation
candidate, updating Present_Value in service and a selected Interface_Value in either
service state. It never selects the optional property implicitly. Existing Present_Value
range validation still applies in service, and an error returns no partial object.
Use `BACnet.Protocol.ObjectTypes.AnalogInput.update_property/3` for explicit simulation -
ordinary Present_Value writes do not update Interface_Value.
`BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3` checks the proposed operation
before commit. On rejection, retain the original object, runtime state and wakeup. On
success, the host needs to commit the candidate while retaining the previous state,
execute with the same context and retain the complete result before exposing another
operation. Deliver every accepted write, including same-value writes. Raw property
setters do not perform lifecycle checks or execution.

In-service readings use application origin. BACnet Present_Value writes require out of
service, including same-value writes. A local callback handling a BACnet request needs to
preserve its BACnet origin. `BACnet.Protocol.ObjectTypes.AnalogInput.property_writable?/2`
reflects that service-access rule. The host still needs to enforce service permissions,
other read-only annotations and array indices. Analog Input is not commandable - it has
no priority array and supplied write priorities are ignored.

## Separate automatic acquisition from explicit simulation

The host needs to keep automatic hardware changes decoupled from simulated Present_Value
and Reliability. Physical samples can still update a selected Interface_Value through
`BACnet.Protocol.ObjectTypes.AnalogInput.set_input/2` while out of service. Automatic
hardware Reliability reports still need to be suppressed. This example adapter uses the
physical-sample helper above for observations and keeps Reliability reports isolated:

```elixir
automatic_report = fn stored, property, value ->
  case property do
    :present_value ->
      sample.(stored, value)
    :reliability ->
      if stored.object.out_of_service,
        do: {:ok, stored},
        else: write.(stored, property, value, :application_write)
  end
end

{:ok, stored} = write.(stored, :out_of_service, true, :property_write)
{:ok, stored} = write.(stored, :present_value, 30.0, :application_write)
{:ok, stored} = write.(stored, :reliability, :process_error, :application_write)
true = stored.object.status_flags.fault
22.0 = stored.object.interface_value

latest = %{present_value: 23.0, reliability: :no_fault_detected}
{:ok, stored} = automatic_report.(stored, :present_value, latest.present_value)
30.0 = stored.object.present_value
23.0 = stored.object.interface_value
{:ok, unchanged} = automatic_report.(stored, :reliability, latest.reliability)
^stored = unchanged
```

The physical-sample helper updates Interface_Value without changing the simulated
Present_Value. Automatic Reliability reports are suppressed. Deliberate simulation calls
use the ordinary write helper with the same application origin - origin alone does not
identify intent. Explicit simulation from BACnet is also accepted:

```elixir
{:ok, stored} = write.(stored, :present_value, 31.0, :property_write)
31.0 = stored.object.present_value
23.0 = stored.object.interface_value
```

## Unknown physical values and wire conversion

`:undefined` means the physical value cannot be determined. It preserves Present_Value
and does not infer a Reliability fault. A selected Interface_Value encodes that unknown
value as BACnet NULL through its property annotations:

```elixir
{:ok, stored} = sample.(stored, :undefined)
:undefined = stored.object.interface_value
31.0 = stored.object.present_value
identifier = AnalogInput.get_object_identifier(stored.object)
{:ok, null} = BACnet.Protocol.ObjectsUtility.cast_value_to_property(
  identifier, :interface_value, stored.object.interface_value)
:null = null.type
{:ok, :undefined} = BACnet.Protocol.ObjectsUtility.cast_property_to_value(
  identifier, :interface_value, null)
{:ok, stored} = sample.(stored, latest.present_value)
23.0 = stored.object.interface_value
```

Known physical values encode as REAL. BACnet writes to Interface_Value are rejected in
both service states. Local adapters may also report Interface_Value alone through an
application-write context for that property when they need an independent observation.

In a real driver, calibration, scaling and filtering need to produce values in the declared
Units before reporting them. This module does not convert a raw sensor signal, poll hardware,
round readings or diagnose a particular fault from a rejected value.

## Return to service with current observations

The host can retain sensor observations separately during simulation. Returning to service
does not restore an older sample or acquire a fresh reading. Supply the current driver
value/status before exposing it as live data:

```elixir
{:ok, stored} = write.(stored, :out_of_service, false, :property_write)
31.0 = stored.object.present_value
{:ok, stored} = automatic_report.(stored, :present_value, latest.present_value)
{:ok, stored} = automatic_report.(stored, :reliability, latest.reliability)
23.0 = stored.object.present_value
false = stored.object.status_flags.fault
```

A known in-service Reliability report is retained separately from simulation and restored
on return to service. If initialization begins out of service with no known physical
status, the supplied Reliability remains until a fresh report, subject to inhibition.
The host needs to refresh status when retained observations are insufficient.

## Reliability inhibition and simulation

Reliability_Evaluation_Inhibit masks physical reports with NO_FAULT_DETECTED while retaining
the latest report for restoration when inhibition ends:

```elixir
{:ok, stored} = automatic_report.(stored, :reliability, :no_sensor)
{:ok, stored} = write.(stored, :reliability_evaluation_inhibit, true, :property_write)
:no_fault_detected = stored.object.reliability
{:ok, stored} = automatic_report.(stored, :reliability, :communication_failure)
:no_fault_detected = stored.object.reliability
{:ok, stored} = write.(stored, :reliability_evaluation_inhibit, false, :property_write)
:communication_failure = stored.object.reliability
```

An explicitly supplied or written out-of-service Reliability can simulate an alternate
condition even while inhibited. Both write origins are accepted. Entering out of service
alone does not expose an earlier suppressed hardware report:

```elixir
{:ok, stored} = write.(stored, :reliability_evaluation_inhibit, true, :property_write)
{:ok, stored} = write.(stored, :out_of_service, true, :property_write)
:no_fault_detected = stored.object.reliability
{:ok, stored} = write.(stored, :reliability, :process_error, :application_write)
:process_error = stored.object.reliability
true = stored.object.status_flags.fault
```

Returning to service while still inhibited masks simulation again. Removing Reliability
clears FAULT during lifecycle execution. Other status flags follow Event_State and
Out_Of_Service. Supply OVERRIDDEN when applicable. This example uses the default
creation options. For algorithm evaluation, see [intrinsic reporting](#intrinsic-reporting)
below.

## Update_Interval, reads and clocks

Update_Interval describes the maximum period between value updates in hundredths of a
second while in service and not overridden. Convert the property to milliseconds when
configuring a driver's acquisition interval.

```elixir
1000 = stored.object.update_interval * 10
```

Here 100 means a maximum interval of 1000 milliseconds. The driver needs to meet the
advertised interval through polling or pushed observations. Acquisition timers, stale
sensor diagnostics, rounding and filtering belong to the driver. Resolution describes
the smallest change the sensor can recognize.

Before a read, refresh lifecycle status and then obtain the supplied value:

```elixir
read = Context.new({:property_read, :present_value, nil},
  now: start.now, monotonic_time: 0, state: stored.state)
{:ok, stored} = Lifecycle.prepare_read(stored.object, read)
{:ok, 23.0} = AnalogInput.get_property(stored.object, :present_value)
nil = stored.next_execution
```

The read uses the last supplied measurement. A pending reporting delay can request
a monotonic wakeup. Replace the previous request with `next_execution` from the
retained result.

## Restart and boundaries

After a restart, initialize from restored properties with fresh clocks and runtime state.
Initialization retains Present_Value and Interface_Value. It uses the supplied Reliability
as the physical report when in service and as the simulated report when out of service.
Supply a fresh driver report if the previous physical report existed only in runtime state.

Missing, malformed or other-instance state returns `{:error, :invalid_execution_state}`
without a replacement result. Remote snapshots remain passive and reject local preparation.

## Intrinsic reporting

Create the local object with `intrinsic_reporting: true` to enable reporting.
OUT_OF_RANGE monitors the engineering value in Present_Value, including
a simulated value supplied while out of service. Select the low or high check
with Limit_Enable. Deadband affects recovery from a limit. A reliability
fault such as `:no_sensor` takes precedence over a limit alarm.

Call `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after
committing each result. The
[intrinsic reporting example](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-intrinsic-transitions)
shows when to send a notification and how to handle acknowledgment.
