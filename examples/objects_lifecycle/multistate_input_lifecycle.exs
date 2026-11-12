# Run from the repository root: mix run examples/objects_lifecycle/multistate_input_lifecycle.exs
alias BACnet.Protocol.BACnetArray
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.MultistateInput

{:ok, object} =
  MultistateInput.create(10, "Valve position", %{
    number_of_states: 3,
    state_text: BACnetArray.from_list(["Closed", "Partly open", "Open"]),
    present_value: 1,
    interface_value: :undefined,
    reliability: :no_fault_detected
  })

{:ok, stored} = Lifecycle.execute(object, Context.new(:initialization))

commit = fn stored, candidate, trigger ->
  context = Context.new(trigger, state: stored.state)

  with {:ok, candidate} <- candidate,
       {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, context) do
    stored = %{stored | object: prepared}
    Lifecycle.execute(stored.object, context)
  end
end

sample = fn stored, value ->
  commit.(
    stored,
    MultistateInput.set_input(stored.object, value),
    {:application_write, :present_value, nil, nil}
  )
end

write = fn stored, property, value, origin ->
  commit.(
    stored,
    MultistateInput.update_property(stored.object, property, value),
    {origin, property, nil, nil}
  )
end

{:ok, stored} = sample.(stored, 2)
2 = stored.object.present_value
2 = stored.object.interface_value

{:error, :write_access_denied} = write.(stored, :present_value, 2, :property_write)
{:ok, stored} = write.(stored, :out_of_service, true, :property_write)
{:ok, stored} = write.(stored, :present_value, 3, :property_write)
{:ok, stored} = sample.(stored, 1)
3 = stored.object.present_value
1 = stored.object.interface_value

{:ok, stored} = sample.(stored, :undefined)
3 = stored.object.present_value
:undefined = stored.object.interface_value
:no_fault_detected = stored.object.reliability

{:ok, stored} = write.(stored, :reliability_evaluation_inhibit, true, :property_write)
{:ok, stored} = write.(stored, :reliability, :process_error, :application_write)
:process_error = stored.object.reliability
true = stored.object.status_flags.fault

{:ok, stored} = write.(stored, :out_of_service, false, :property_write)
3 = stored.object.present_value
:no_fault_detected = stored.object.reliability
false = stored.object.status_flags.fault
{:ok, stored} = sample.(stored, 2)
2 = stored.object.present_value
2 = stored.object.interface_value

{:error, {:invalid_configuration, :interface_value}} =
  write.(stored, :number_of_states, 1, :application_write)

{:ok, stored} = write.(stored, :number_of_states, 2, :application_write)
["Closed", "Partly open"] = BACnetArray.to_list(stored.object.state_text)

{:error, {:value_failed_property_validation, :state_text}} =
  write.(stored, :state_text, BACnetArray.from_list(["Closed"]), :property_write)

read = Context.new({:property_read, :present_value, nil}, state: stored.state)
{:ok, stored} = Lifecycle.prepare_read(stored.object, read)
{:ok, 2} = MultistateInput.get_property(stored.object, :present_value)
nil = stored.next_execution

IO.puts("Multistate Input lifecycle walkthrough passed")
