alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.OctetStringValue

{:ok, object} =
  OctetStringValue.create(40, "Device payload", %{
    present_value: <<1, 0>>,
    relinquish_default: <<1, 0>>,
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
  candidate = OctetStringValue.set_priority(stored.object, priority || 16, value)
  commit.(stored, candidate, {origin, :present_value, nil, priority})
end

write = fn stored, property, value, origin ->
  candidate = OctetStringValue.update_property(stored.object, property, value)
  commit.(stored, candidate, {origin, property, nil, nil})
end

{:ok, stored} = command.(stored, <<0, 255, 128>>, :application_write, nil)
{:ok, stored} = command.(stored, <<>>, :property_write, 8)
<<>> = stored.object.present_value
<<0, 255, 128>> = stored.object.priority_array.priority_16

{:ok, stored} = command.(stored, nil, :property_write, 8)
<<0, 255, 128>> = stored.object.present_value
{:ok, stored} = command.(stored, nil, :property_write, 16)
<<1, 0>> = stored.object.present_value

{:ok, stored} = write.(stored, :out_of_service, true, :property_write)
{:error, :out_of_service} = command.(stored, <<2, 0>>, :application_write, nil)
{:ok, stored} = command.(stored, <<0, 128, 255>>, :property_write, 8)

{:ok, stored} = write.(stored, :reliability_evaluation_inhibit, true, :property_write)
{:ok, stored} = write.(stored, :reliability, :process_error, :application_write)
:process_error = stored.object.reliability
true = stored.object.status_flags.fault

{:ok, stored} = write.(stored, :out_of_service, false, :application_write)
:no_fault_detected = stored.object.reliability
false = stored.object.status_flags.fault

read = Context.new({:property_read, :present_value, nil}, state: stored.state)
{:ok, stored} = Lifecycle.prepare_read(stored.object, read)
{:ok, <<0, 128, 255>>} = OctetStringValue.get_property(stored.object, :present_value)
nil = stored.next_execution
