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

{:ok, stored} = command.(stored, nil, :property_write, 8)
^scheduled = stored.object.present_value
{:ok, stored} = command.(stored, nil, :property_write, 16)
^fallback = stored.object.present_value

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
