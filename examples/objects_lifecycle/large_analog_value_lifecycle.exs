alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.LargeAnalogValue

{:ok, object} =
  LargeAnalogValue.create(10, "Precise value", %{
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

{:error, {:property_out_of_range, :priority_array}} =
  write.(stored, :max_present_value, 20.0, :application_write, nil)

50.0 = stored.object.max_present_value

{:ok, stored} = write.(stored, :present_value, nil, :property_write, 16)
{:ok, stored} = write.(stored, :max_present_value, 20.0, :application_write, nil)
{:ok, stored} = write.(stored, :present_value, nil, :property_write, 8)
5.0 = stored.object.present_value

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

read = Context.new({:property_read, :present_value, nil}, state: stored.state)
{:ok, stored} = Lifecycle.prepare_read(stored.object, read)
{:ok, 12.0} = LargeAnalogValue.get_property(stored.object, :present_value)
nil = stored.next_execution
