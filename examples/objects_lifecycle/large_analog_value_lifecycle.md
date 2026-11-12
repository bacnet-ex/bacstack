<!--t: Driving a Large Analog Value -->

# Driving a Large Analog Value

`BACnet.Protocol.ObjectTypes.LargeAnalogValue` exposes double-precision application data.
The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
needs to serialize writes and retain their results per instance.

Run the walkthrough from the repository root with
`mix run examples/objects_lifecycle/large_analog_value_lifecycle.exs`. You can also paste the Elixir
blocks into IEx in order.

## Initialize and command a Double value

```elixir
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.LargeAnalogValue

{:ok, object} = LargeAnalogValue.create(10, "Precise value", %{
  min_present_value: :infn,
  max_present_value: 50.0,
  relinquish_default: 5.0,
  reliability: :no_fault_detected
})
{:ok, stored} = Lifecycle.execute(object, Context.new(:initialization))
5.0 = stored.object.present_value

write = fn stored, property, value, origin, priority ->
  context = Context.new({origin, property, nil, priority}, state: stored.state)

  candidate =
    if property == :present_value and LargeAnalogValue.has_priority_array?(stored.object),
      do: LargeAnalogValue.set_priority(stored.object, priority || 16, value),
      else: LargeAnalogValue.update_property(stored.object, property, value)

  with {:ok, candidate} <- candidate,
       {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, context) do
    Lifecycle.execute(prepared, context)
  end
end

{:ok, stored} = write.(stored, :present_value, 40.0, :application_write, nil)
{:ok, stored} = write.(stored, :present_value, 1.0000000000000002, :property_write, 8)
1.0000000000000002 = stored.object.present_value
40.0 = stored.object.priority_array.priority_16
```

Selecting Relinquish_Default also selects Priority_Array. The host needs to decode
BACnet Double values and route Present_Value commands through
`BACnet.Protocol.ObjectTypes.LargeAnalogValue.set_priority/3`. Use priority 16 for
a BACnet command with no priority. Pass `nil` to relinquish a priority in response
to a BACnet NULL command. Priority 6 is reserved. A plain instance accepts direct
writes through `BACnet.Protocol.ObjectTypes.LargeAnalogValue.update_property/3`.

Priority 8 takes precedence over priority 16. Present_Value becomes
`1.0000000000000002` at its original Double precision, and `40.0` remains stored
at priority 16.

Retain the complete successful `BACnet.Protocol.ObjectExecution.Result` before
exposing another operation. The host needs to deliver every accepted write and enforce
service permissions, read-only annotations and array indices. Rejected writes leave the
previous result in storage.

## Tighten the range after reconciling commands

When both limits are configured, the effective value, each stored command and
Relinquish_Default must fit within the range. This example uses `:infn` (negative
infinity) as its lower limit, so only the upper limit constrains finite values.

```elixir
{:error, {:property_out_of_range, :priority_array}} =
  write.(stored, :max_present_value, 20.0, :application_write, nil)
50.0 = stored.object.max_present_value

{:ok, stored} = write.(stored, :present_value, nil, :property_write, 16)
{:ok, stored} = write.(stored, :max_present_value, 20.0, :application_write, nil)
{:ok, stored} = write.(stored, :present_value, nil, :property_write, 8)
5.0 = stored.object.present_value
```

The first attempt to lower the maximum to `20.0` fails because the command at
priority 16 still stores `40.0`, even though priority 8 currently controls
Present_Value. Clearing priority 16 removes the out-of-range command, so the same
limit change succeeds. Clearing priority 8 then leaves the array empty, and
Present_Value falls back to the configured Relinquish_Default of `5.0`.

## Simulate while out of service

```elixir
{:ok, stored} = write.(stored, :out_of_service, true, :property_write, nil)
{:error, :out_of_service} =
  write.(stored, :present_value, 5.0, :application_write, nil)
{:ok, stored} = write.(stored, :present_value, 12.0, :property_write, 8)
12.0 = stored.object.present_value

{:ok, stored} =
  write.(stored, :reliability_evaluation_inhibit, true, :property_write, nil)
{:ok, stored} = write.(stored, :reliability, :process_error, :application_write, nil)
:process_error = stored.object.reliability
true = stored.object.status_flags.fault

{:ok, stored} = write.(stored, :out_of_service, false, :application_write, nil)
:no_fault_detected = stored.object.reliability
false = stored.object.status_flags.fault
12.0 = stored.object.present_value
```

Application Present_Value writes are rejected during isolation, including repeated
values and masked commands. BACnet commands continue to arbitrate. A local callback
handling a BACnet request needs to keep its BACnet origin. The Reliability write
above supplies an explicit simulated report. Both origins can supply that report.
Returning to service preserves the effective value and masks Reliability while
inhibition remains enabled. An instance with no Out_Of_Service property is treated
as in service.

## Read and restart

```elixir
read = Context.new({:property_read, :present_value, nil}, state: stored.state)
{:ok, stored} = Lifecycle.prepare_read(stored.object, read)
{:ok, 12.0} = LargeAnalogValue.get_property(stored.object, :present_value)
nil = stored.next_execution
```

Retain the result of `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` before
reading. An active reporting delay can request a monotonic wakeup. After restart,
initialize restored properties with fresh runtime state.
Refresh any suppressed Reliability report that was held only in the previous runtime state.

## Intrinsic reporting

Create the local object with `intrinsic_reporting: true` to enable reporting.
DOUBLE_OUT_OF_RANGE evaluates finite Present_Value, Low_Limit, High_Limit
and Deadband values. Limit_Enable selects the checks. These properties
govern event detection and recovery. Min_Pres_Value and Max_Pres_Value
govern the permitted command range.

Call `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after
committing each result. The
[intrinsic reporting example](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-intrinsic-transitions)
shows when to send a notification and how to handle acknowledgment.
