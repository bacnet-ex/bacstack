<!--t: Driving a DateTime Value -->

# Driving a DateTime Value

`BACnet.Protocol.ObjectTypes.DateTimeValue` exposes a date and time as a
BACnet DateTime. This example uses priorities to choose a service deadline in UTC.
Run `mix run examples/objects_lifecycle/date_time_value_lifecycle.exs` from the repository
root, or paste the Elixir blocks into IEx in order.

## Initialize and command the deadline

```elixir
alias BACnet.Protocol.BACnetDate
alias BACnet.Protocol.BACnetDateTime
alias BACnet.Protocol.BACnetTime
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.DateTimeValue

scheduled = BACnetDateTime.from_datetime(~U[2027-02-28 08:00:00Z])
fallback = BACnetDateTime.from_datetime(~U[2027-03-15 08:00:00Z])
test_datetime = BACnetDateTime.from_datetime(~U[2027-01-15 09:30:15.25Z])
unknown = %BACnetDateTime{
  date: %BACnetDate{
    year: :unspecified,
    month: :unspecified,
    day: :unspecified,
    weekday: :unspecified
  },
  time: %BACnetTime{
    hour: :unspecified,
    minute: :unspecified,
    second: :unspecified,
    hundredth: :unspecified
  }
}

{:ok, object} =
  DateTimeValue.create(40, "Service deadline", %{
    present_value: fallback,
    relinquish_default: fallback,
    is_utc: true,
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
  candidate = DateTimeValue.set_priority(stored.object, priority || 16, value)
  commit.(stored, candidate, {origin, :present_value, nil, priority})
end

write = fn stored, property, value, origin ->
  candidate = DateTimeValue.update_property(stored.object, property, value)
  commit.(stored, candidate, {origin, property, nil, nil})
end

{:ok, stored} = command.(stored, scheduled, :application_write, nil)
{:ok, stored} = command.(stored, unknown, :property_write, 8)
^unknown = stored.object.present_value
^scheduled = stored.object.priority_array.priority_16
```

Selecting Relinquish_Default also selects Priority_Array. Use
`BACnet.Protocol.ObjectTypes.DateTimeValue.set_priority/3` for commands.
Use priority 16 when a BACnet command omits its priority. Priority 6 is reserved.
A non-commandable instance accepts direct Present_Value writes through
`BACnet.Protocol.ObjectTypes.DateTimeValue.update_property/3`. Use
`BACnet.Protocol.BACnetDateTime.from_datetime/1` to build a fully specified value
from an Elixir DateTime. DateTime Value also accepts a value with all eight fields
unspecified. For partial wildcards or special codes such as `:last`, use
`BACnet.Protocol.ObjectTypes.DateTimePatternValue`.

This example supplies UTC values and sets Is_UTC to true. When Is_UTC is false
or absent, supply device-local values. Is_UTC declares how to interpret the stored
fields. The object preserves those fields when Is_UTC changes.

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

The fully unspecified date-time at priority 8 is an active command. The host passes
nil for a BACnet NULL command to clear a slot. Clearing priority 8 exposes the
scheduled deadline at priority 16. Clearing priority 16 leaves no active slots,
so Present_Value falls back to Relinquish_Default.

## Simulate while out of service

```elixir
{:ok, stored} = write.(stored, :out_of_service, true, :property_write)
{:error, :out_of_service} = command.(stored, scheduled, :application_write, nil)
{:ok, stored} = command.(stored, test_datetime, :property_write, 8)

{:ok, stored} = write.(stored, :reliability_evaluation_inhibit, true, :property_write)
{:ok, stored} = write.(stored, :reliability, :process_error, :application_write)
:process_error = stored.object.reliability
true = stored.object.status_flags.fault

{:ok, stored} = write.(stored, :out_of_service, false, :application_write)
:no_fault_detected = stored.object.reliability
false = stored.object.status_flags.fault

read = Context.new({:property_read, :present_value, nil}, state: stored.state)
{:ok, stored} = Lifecycle.prepare_read(stored.object, read)
{:ok, ^test_datetime} = DateTimeValue.get_property(stored.object, :present_value)
nil = stored.next_execution
```

Out of service, local application writes to Present_Value are blocked. BACnet
commands still arbitrate. Either write origin can supply a simulated Reliability
report. Returning to service keeps the current deadline and masks Reliability
while inhibition remains enabled.

Retain the result of `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2`
before reading. The object requests no wakeup.
An application that acts at the stored deadline needs its own timer.
After a restart, initialize from the saved properties with fresh runtime state.
If the last Reliability report was held only in runtime state, supply a fresh one.
