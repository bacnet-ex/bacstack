alias BACnet.Protocol.BACnetArray
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.BitstringValue

{:ok, object} =
  BitstringValue.create(60, "Flags", %{
    present_value: {false, false},
    relinquish_default: {false, false},
    bit_text: BACnetArray.from_list(["Occupied", "Ventilating"]),
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
  candidate = BitstringValue.set_priority(stored.object, priority || 16, value)
  commit.(stored, candidate, {origin, :present_value, nil, priority})
end

write = fn stored, property, value, origin ->
  candidate = BitstringValue.update_property(stored.object, property, value)
  commit.(stored, candidate, {origin, property, nil, nil})
end

{:ok, stored} = command.(stored, {true, false}, :application_write, nil)
{:ok, stored} = command.(stored, {false, true}, :property_write, 8)
{false, true} = stored.object.present_value
{true, false} = stored.object.priority_array.priority_16
{:ok, "Occupied"} = BACnetArray.get_item(stored.object.bit_text, 1)

{:error, {:invalid_configuration, :bit_text}} =
  command.(stored, {true}, :property_write, 16)

{:error, {:invalid_configuration, :bit_text}} =
  write.(stored, :bit_text, BACnetArray.from_list(["Occupied"]), :application_write)

{:ok, stored} = command.(stored, nil, :property_write, 8)
{true, false} = stored.object.present_value
{:ok, stored} = command.(stored, nil, :property_write, 16)
{false, false} = stored.object.present_value

{:ok, stored} = write.(stored, :out_of_service, true, :property_write)
{:error, :out_of_service} = command.(stored, {true, true}, :application_write, nil)
{:ok, stored} = command.(stored, {true, true}, :property_write, 8)

{:ok, stored} = write.(stored, :reliability_evaluation_inhibit, true, :property_write)
{:ok, stored} = write.(stored, :reliability, :process_error, :application_write)
:process_error = stored.object.reliability
true = stored.object.status_flags.fault

{:ok, stored} = write.(stored, :out_of_service, false, :application_write)
:no_fault_detected = stored.object.reliability
false = stored.object.status_flags.fault

read = Context.new({:property_read, :present_value, nil}, state: stored.state)
{:ok, stored} = Lifecycle.prepare_read(stored.object, read)
{:ok, {true, true}} = BitstringValue.get_property(stored.object, :present_value)
nil = stored.next_execution
