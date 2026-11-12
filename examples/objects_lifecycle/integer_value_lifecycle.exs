# Run from the repository root: mix run examples/objects_lifecycle/integer_value_lifecycle.exs
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.IntegerValue

{:ok, object} =
  IntegerValue.create(10, "Offset", %{
    min_present_value: -50,
    max_present_value: 50,
    relinquish_default: -5,
    reliability: :no_fault_detected
  })

{:ok, stored} = Lifecycle.execute(object, Context.new(:initialization))
-5 = stored.object.present_value

write = fn stored, property, value, origin, priority ->
  context = Context.new({origin, property, nil, priority}, state: stored.state)

  candidate =
    if property == :present_value and IntegerValue.has_priority_array?(stored.object),
      do: IntegerValue.set_priority(stored.object, priority || 16, value),
      else: IntegerValue.update_property(stored.object, property, value)

  with {:ok, candidate} <- candidate,
       {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, context) do
    stored = %{stored | object: prepared}
    Lifecycle.execute(stored.object, context)
  end
end

{:ok, stored} = write.(stored, :present_value, -40, :application_write, nil)
{:ok, stored} = write.(stored, :present_value, -10, :property_write, 8)
-10 = stored.object.present_value
-40 = stored.object.priority_array.priority_16

{:error, {:property_out_of_range, :priority_array}} =
  write.(stored, :min_present_value, -30, :application_write, nil)

-50 = stored.object.min_present_value

{:ok, stored} = write.(stored, :present_value, nil, :property_write, 16)
{:ok, stored} = write.(stored, :min_present_value, -30, :application_write, nil)
{:ok, stored} = write.(stored, :present_value, nil, :property_write, 8)
-5 = stored.object.present_value

{:ok, stored} = write.(stored, :out_of_service, true, :property_write, nil)

{:error, :out_of_service} =
  write.(stored, :present_value, -5, :application_write, nil)

{:ok, stored} = write.(stored, :present_value, -20, :property_write, 8)
-20 = stored.object.present_value

{:ok, stored} =
  write.(stored, :reliability_evaluation_inhibit, true, :property_write, nil)

{:ok, stored} = write.(stored, :reliability, :process_error, :application_write, nil)
:process_error = stored.object.reliability
true = stored.object.status_flags.fault

{:ok, stored} = write.(stored, :out_of_service, false, :application_write, nil)
:no_fault_detected = stored.object.reliability
false = stored.object.status_flags.fault
-20 = stored.object.present_value

read = Context.new({:property_read, :present_value, nil}, state: stored.state)
{:ok, stored} = Lifecycle.prepare_read(stored.object, read)
{:ok, -20} = IntegerValue.get_property(stored.object, :present_value)
nil = stored.next_execution

IO.puts("Integer Value lifecycle walkthrough passed")
