<!--t: Driving a Time Pattern Value -->

# Driving a Time Pattern Value

`BACnet.Protocol.ObjectTypes.TimePatternValue` exposes a time of day or
time pattern as a BACnet TIME. This example uses priorities to choose a recurring pattern.
Run `mix run examples/objects_lifecycle/time_pattern_value_lifecycle.exs` from the repository
root, or paste the Elixir blocks into IEx in order.

## Initialize and command the pattern

```elixir
alias BACnet.Protocol.BACnetTime
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.TimePatternValue

half_hour = %BACnetTime{hour: :unspecified, minute: 30, second: 0, hundredth: 0}
fallback = BACnetTime.from_time(~T[06:00:00])
unknown = %BACnetTime{
  hour: :unspecified,
  minute: :unspecified,
  second: :unspecified,
  hundredth: :unspecified
}
test_pattern = %{half_hour | minute: 15}

{:ok, object} =
  TimePatternValue.create(40, "Recurring time", %{
    present_value: fallback,
    relinquish_default: fallback,
    reliability: :no_fault_detected
  })

{:ok, stored} = Lifecycle.execute(object, Context.new(:initialization))

commit = fn stored, candidate, trigger ->
  context = Context.new(trigger, state: stored.state)

  with {:ok, candidate} <- candidate,
       {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, context) do
    Lifecycle.execute(prepared, context)
  end
end

command = fn stored, value, origin, priority ->
  candidate = TimePatternValue.set_priority(stored.object, priority || 16, value)
  commit.(stored, candidate, {origin, :present_value, nil, priority})
end

write = fn stored, property, value, origin ->
  candidate = TimePatternValue.update_property(stored.object, property, value)
  commit.(stored, candidate, {origin, property, nil, nil})
end

{:ok, stored} = command.(stored, half_hour, :application_write, nil)
{:ok, stored} = command.(stored, unknown, :property_write, 8)
^unknown = stored.object.present_value
^half_hour = stored.object.priority_array.priority_16
```

Selecting Relinquish_Default also selects Priority_Array. Use
`BACnet.Protocol.ObjectTypes.TimePatternValue.set_priority/3` for commands.
Use priority 16 when a BACnet command omits its priority. Priority 6 is reserved.
A non-commandable instance accepts direct Present_Value writes through
`BACnet.Protocol.ObjectTypes.TimePatternValue.update_property/3`. Supply a
`BACnet.Protocol.BACnetTime` with the desired fields. The command at priority 16
represents the half-hour mark of every hour. The fallback represents 06:00.

The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
needs to serialize operations, enforce write permissions and retain the complete
`BACnet.Protocol.ObjectExecution.Result` after each successful operation.
A failed operation leaves the prior result in storage.

## Relinquish a command

```elixir
{:ok, stored} = command.(stored, nil, :property_write, 8)
^half_hour = stored.object.present_value
{:ok, stored} = command.(stored, nil, :property_write, 16)
^fallback = stored.object.present_value
```

The fully unspecified time at priority 8 is an active command. The host passes
nil for a BACnet NULL command to clear a slot. Clearing priority 8 exposes the
pattern at priority 16. Clearing priority 16 leaves no active slots,
so Present_Value falls back to Relinquish_Default.

## Simulate while out of service

```elixir
{:ok, stored} = write.(stored, :out_of_service, true, :property_write)
{:error, :out_of_service} = command.(stored, half_hour, :application_write, nil)
{:ok, stored} = command.(stored, test_pattern, :property_write, 8)

{:ok, stored} = write.(stored, :reliability_evaluation_inhibit, true, :property_write)
{:ok, stored} = write.(stored, :reliability, :process_error, :application_write)
:process_error = stored.object.reliability
true = stored.object.status_flags.fault

{:ok, stored} = write.(stored, :out_of_service, false, :application_write)
:no_fault_detected = stored.object.reliability
false = stored.object.status_flags.fault

read = Context.new({:property_read, :present_value, nil}, state: stored.state)
{:ok, stored} = Lifecycle.prepare_read(stored.object, read)
{:ok, ^test_pattern} = TimePatternValue.get_property(stored.object, :present_value)
nil = stored.next_execution
```

Out of service, local application writes to Present_Value are blocked. BACnet
commands still arbitrate. Either write origin can supply a simulated Reliability
report. Returning to service keeps the current pattern and masks Reliability
while inhibition remains enabled.

Retain the result of `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2`
before reading. The object requests no wakeup.
The application can match the stored pattern against a time and decide how to act.
After a restart, initialize from the saved properties with fresh runtime state.
If the last Reliability report was held only in runtime state, supply a fresh one.
