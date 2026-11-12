<!--t: Driving a Date Value -->

# Driving a Date Value

`BACnet.Protocol.ObjectTypes.DateValue` exposes a calendar date as a BACnet DATE.
This example uses priorities to choose the service date.
Run `mix run examples/objects_lifecycle/date_value_lifecycle.exs` from the repository
root, or paste the Elixir blocks into IEx in order.

## Initialize and command the date

```elixir
alias BACnet.Protocol.BACnetDate
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.DateValue

scheduled = BACnetDate.from_date(~D[2027-02-28])
fallback = BACnetDate.from_date(~D[2027-03-15])
test_date = BACnetDate.from_date(~D[2027-01-15])
unknown = %BACnetDate{
  year: :unspecified,
  month: :unspecified,
  day: :unspecified,
  weekday: :unspecified
}

{:ok, object} =
  DateValue.create(40, "Service date", %{
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
  candidate = DateValue.set_priority(stored.object, priority || 16, value)
  commit.(stored, candidate, {origin, :present_value, nil, priority})
end

write = fn stored, property, value, origin ->
  candidate = DateValue.update_property(stored.object, property, value)
  commit.(stored, candidate, {origin, property, nil, nil})
end

{:ok, stored} = command.(stored, scheduled, :application_write, nil)
{:ok, stored} = command.(stored, unknown, :property_write, 8)
^unknown = stored.object.present_value
^scheduled = stored.object.priority_array.priority_16
```

Selecting Relinquish_Default also selects Priority_Array. Use
`BACnet.Protocol.ObjectTypes.DateValue.set_priority/3` for commands.
Use priority 16 when a BACnet command omits its priority. Priority 6 is reserved.
A non-commandable instance accepts direct Present_Value writes through
`BACnet.Protocol.ObjectTypes.DateValue.update_property/3`. Use
`BACnet.Protocol.BACnetDate.from_date/1` to build a fully specified date from an Elixir
date. Date Value accepts a fully unspecified date as well. For dates with a mix
of specified and unspecified fields or special codes such as `:last`, use
`BACnet.Protocol.ObjectTypes.DatePatternValue`.

The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
needs to serialize operations, enforce write permissions and retain the complete
`BACnet.Protocol.ObjectExecution.Result` after each successful operation.
A failed operation leaves the prior result in storage.

## Relinquish a command

```elixir
{:ok, stored} = command.(stored, nil, :property_write, 8)
^scheduled = stored.object.present_value
{:ok, stored} = command.(stored, nil, :property_write, 16)
^fallback = stored.object.present_value
```

The fully unspecified date at priority 8 is an active command. The host passes
nil for a BACnet NULL command to clear a slot. Clearing priority 8 exposes the
scheduled date at priority 16. Clearing priority 16 leaves no active slots,
so Present_Value falls back to Relinquish_Default.

## Simulate while out of service

```elixir
{:ok, stored} = write.(stored, :out_of_service, true, :property_write)
{:error, :out_of_service} = command.(stored, scheduled, :application_write, nil)
{:ok, stored} = command.(stored, test_date, :property_write, 8)

{:ok, stored} = write.(stored, :reliability_evaluation_inhibit, true, :property_write)
{:ok, stored} = write.(stored, :reliability, :process_error, :application_write)
:process_error = stored.object.reliability
true = stored.object.status_flags.fault

{:ok, stored} = write.(stored, :out_of_service, false, :application_write)
:no_fault_detected = stored.object.reliability
false = stored.object.status_flags.fault

read = Context.new({:property_read, :present_value, nil}, state: stored.state)
{:ok, stored} = Lifecycle.prepare_read(stored.object, read)
{:ok, ^test_date} = DateValue.get_property(stored.object, :present_value)
nil = stored.next_execution
```

Out of service, local application writes to Present_Value are blocked. BACnet
commands still arbitrate. Either write origin can supply a simulated Reliability
report. Returning to service keeps the current date and masks Reliability
while inhibition remains enabled.

Retain the result of `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2`
before reading. The object requests no wakeup.
An application that acts on the service date needs its own trigger.
After a restart, initialize from the saved properties with fresh runtime state.
If the last Reliability report was held only in runtime state, supply a fresh one.
