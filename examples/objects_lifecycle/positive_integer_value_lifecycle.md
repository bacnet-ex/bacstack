<!--t: Driving a Positive Integer Value -->

# Driving a Positive Integer Value

`BACnet.Protocol.ObjectTypes.PositiveIntegerValue` exposes unsigned application data.
The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
needs to serialize writes and retain their results per instance.

Run the walkthrough from the repository root with
`mix run examples/objects_lifecycle/positive_integer_value_lifecycle.exs`. You can also paste the Elixir
blocks into IEx in order.

## Initialize and command an unsigned value

```elixir
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.PositiveIntegerValue

{:ok, object} = PositiveIntegerValue.create(10, "Count", %{
  min_present_value: 0,
  max_present_value: 50,
  relinquish_default: 5,
  reliability: :no_fault_detected
})
{:ok, stored} = Lifecycle.execute(object, Context.new(:initialization))
5 = stored.object.present_value

write = fn stored, property, value, origin, priority ->
  context = Context.new({origin, property, nil, priority}, state: stored.state)

  candidate =
    if property == :present_value and PositiveIntegerValue.has_priority_array?(stored.object),
      do: PositiveIntegerValue.set_priority(stored.object, priority || 16, value),
      else: PositiveIntegerValue.update_property(stored.object, property, value)

  with {:ok, candidate} <- candidate,
       {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, context) do
    stored = %{stored | object: prepared}
    Lifecycle.execute(stored.object, context)
  end
end

{:ok, stored} = write.(stored, :present_value, 40, :application_write, nil)
{:ok, stored} = write.(stored, :present_value, 0, :property_write, 8)
0 = stored.object.present_value
40 = stored.object.priority_array.priority_16
```

Selecting Relinquish_Default also selects Priority_Array. The host needs to route
Present_Value commands through `BACnet.Protocol.ObjectTypes.PositiveIntegerValue.set_priority/3`
and pass priority 16 for a BACnet command with no priority. A plain instance accepts
direct writes through `BACnet.Protocol.ObjectTypes.PositiveIntegerValue.update_property/3`.

Retain the complete successful `BACnet.Protocol.ObjectExecution.Result` before
exposing another operation. The host needs to deliver every accepted write and enforce
service permissions, read-only annotations and array indices. Rejected writes leave the
previous result in storage.

## Tighten the range after reconciling commands

```elixir
{:error, {:value_failed_property_validation, :priority_array}} =
  write.(stored, :max_present_value, 20, :application_write, nil)
50 = stored.object.max_present_value

{:ok, stored} = write.(stored, :present_value, nil, :property_write, 16)
{:ok, stored} = write.(stored, :max_present_value, 20, :application_write, nil)
{:ok, stored} = write.(stored, :present_value, nil, :property_write, 8)
5 = stored.object.present_value
```

When both limits are present, every stored priority, the effective value and the
relinquish default need to fit. The masked command at priority 16 prevents the first
limit change. The zero at priority 8 is an active command. Relinquishing slot 16
allows the range to narrow. A nil command at priority 8 then reveals the default
because all slots are empty. Priority 6 is reserved.

## Simulate while out of service

```elixir
{:ok, stored} = write.(stored, :out_of_service, true, :property_write, nil)
{:error, :out_of_service} =
  write.(stored, :present_value, 5, :application_write, nil)
{:ok, stored} = write.(stored, :present_value, 12, :property_write, 8)
12 = stored.object.present_value

{:ok, stored} =
  write.(stored, :reliability_evaluation_inhibit, true, :property_write, nil)
{:ok, stored} = write.(stored, :reliability, :process_error, :application_write, nil)
:process_error = stored.object.reliability
true = stored.object.status_flags.fault

{:ok, stored} = write.(stored, :out_of_service, false, :application_write, nil)
:no_fault_detected = stored.object.reliability
false = stored.object.status_flags.fault
12 = stored.object.present_value
```

Application Present_Value writes are rejected during isolation, including repeated
values and masked commands. BACnet commands continue to arbitrate. A local callback
handling a BACnet request needs to keep its BACnet origin. The Reliability write
above supplies an explicit simulated report. Both origins can supply that report.
Returning to service preserves the effective value and masks Reliability while
inhibition remains enabled.

## Read and restart

```elixir
read = Context.new({:property_read, :present_value, nil}, state: stored.state)
{:ok, stored} = Lifecycle.prepare_read(stored.object, read)
{:ok, 12} = PositiveIntegerValue.get_property(stored.object, :present_value)
nil = stored.next_execution
```

Retain the result of `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` before
reading. An active reporting delay can request a monotonic wakeup. After restart,
initialize restored properties with fresh runtime state.
Refresh any suppressed Reliability report that was held only in the previous runtime state.

## Intrinsic reporting

Create the local object with `intrinsic_reporting: true` to enable reporting.
UNSIGNED_OUT_OF_RANGE evaluates the unsigned Present_Value against the
checks selected by Limit_Enable. Low_Limit and High_Limit configure event
thresholds and Deadband governs recovery. A command or relinquishment can
change the effective value being monitored.

Call `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after
committing each result. The
[intrinsic reporting example](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-intrinsic-transitions)
shows when to send a notification and how to handle acknowledgment.
