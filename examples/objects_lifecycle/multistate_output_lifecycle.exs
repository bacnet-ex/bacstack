# Run from the repository root: mix run examples/objects_lifecycle/multistate_output_lifecycle.exs
alias BACnet.Protocol.BACnetArray
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.MultistateOutput

{:ok, object} =
  MultistateOutput.create(10, "Fan speed", %{
    number_of_states: 3,
    state_text: BACnetArray.from_list(["Off", "Low", "High"]),
    relinquish_default: 1,
    feedback_value: 1,
    interface_value: :undefined,
    reliability: :no_fault_detected
  })

start = Context.new(:initialization)
{:ok, stored} = Lifecycle.execute(object, start)
1 = stored.object.present_value
nil = stored.next_execution

write = fn stored, property, value, source, priority ->
  context = Context.new({source, property, nil, priority}, state: stored.state)

  candidate =
    if property == :present_value,
      do: MultistateOutput.set_priority(stored.object, priority || 16, value),
      else: MultistateOutput.update_property(stored.object, property, value)

  with {:ok, candidate} <- candidate,
       {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, context) do
    stored = %{stored | object: prepared}
    Lifecycle.execute(stored.object, context)
  end
end

{:ok, stored} = write.(stored, :present_value, 2, :application_write, nil)
2 = MultistateOutput.get_output(stored.object)
1 = stored.object.feedback_value
:undefined = stored.object.interface_value

{:ok, stored} = write.(stored, :out_of_service, true, :property_write, nil)
{:ok, stored} = write.(stored, :present_value, 3, :property_write, 8)
3 = stored.object.present_value
1 = MultistateOutput.get_output(stored.object, 1)

{:error, :out_of_service} =
  write.(stored, :feedback_value, 2, :application_write, nil)

{:ok, stored} = write.(stored, :interface_value, 2, :application_write, nil)
2 = stored.object.interface_value
1 = stored.object.feedback_value

{:ok, stored} = write.(stored, :reliability_evaluation_inhibit, true, :property_write, nil)
{:ok, stored} = write.(stored, :reliability, :process_error, :application_write, nil)
:process_error = stored.object.reliability
true = stored.object.status_flags.fault
{:ok, stored} = write.(stored, :out_of_service, false, :property_write, nil)
:no_fault_detected = stored.object.reliability
false = stored.object.status_flags.fault
3 = MultistateOutput.get_output(stored.object)

{:error, {:invalid_configuration, :present_value}} =
  write.(stored, :number_of_states, 2, :application_write, nil)

{:ok, stored} = write.(stored, :present_value, nil, :property_write, 8)
2 = stored.object.present_value
{:ok, stored} = write.(stored, :number_of_states, 2, :application_write, nil)
["Off", "Low"] = BACnetArray.to_list(stored.object.state_text)

{:error, {:value_failed_property_validation, :state_text}} =
  write.(stored, :state_text, BACnetArray.from_list(["Off"]), :property_write, nil)

read = Context.new({:property_read, :present_value, nil}, state: stored.state)
{:ok, stored} = Lifecycle.prepare_read(stored.object, read)
{:ok, 2} = MultistateOutput.get_property(stored.object, :present_value)
nil = stored.next_execution

IO.puts("Multistate Output lifecycle walkthrough passed")
