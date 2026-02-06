defmodule BACnet.Test.Protocol.ObjectTypes.MultistateOutputTest do
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.ObjectTypes.MultistateOutput
  alias BACnet.Protocol.PriorityArray

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_multi_state_output

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "verify create/4 enforces number_of_states for relinquish_default" do
    assert {:ok, %{present_value: 1} = _obj} =
             MultistateOutput.create(1, "TEST", %{number_of_states: 4, relinquish_default: 1})

    assert {:ok, %{present_value: 2} = _obj} =
             MultistateOutput.create(1, "TEST", %{number_of_states: 4, relinquish_default: 2})

    assert {:ok, %{present_value: 3} = _obj} =
             MultistateOutput.create(1, "TEST", %{number_of_states: 4, relinquish_default: 3})

    assert {:ok, %{present_value: 4} = _obj} =
             MultistateOutput.create(1, "TEST", %{number_of_states: 4, relinquish_default: 4})

    assert {:error, {:value_failed_property_validation, _key}} =
             MultistateOutput.create(1, "TEST", %{number_of_states: 4, relinquish_default: 5})

    assert {:error, {:value_failed_property_validation, _key}} =
             MultistateOutput.create(1, "TEST", %{number_of_states: 4, relinquish_default: 32_767})
  end

  test "verify create/4 given present_value gets re-calculated" do
    assert {:ok, %{present_value: 1} = _obj} =
             MultistateOutput.create(1, "TEST", %{number_of_states: 4, present_value: 1})

    assert {:ok, %{present_value: 1} = _obj} =
             MultistateOutput.create(1, "TEST", %{number_of_states: 4, present_value: 2})

    assert {:ok, %{present_value: 1} = _obj} =
             MultistateOutput.create(1, "TEST", %{number_of_states: 4, present_value: 3})

    assert {:ok, %{present_value: 1} = _obj} =
             MultistateOutput.create(1, "TEST", %{number_of_states: 4, present_value: 4})
  end

  test "verify create/4 enforces number_of_states for state_text" do
    assert {:ok, _obj} =
             MultistateOutput.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list(["1", "2", "3", "4"])
             })

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateOutput.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list([])
             })

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateOutput.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list(["1"])
             })

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateOutput.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list(["1", "2", "3", "4", "5"])
             })
  end

  test "verify update_property/3 enforces number_of_states for state_text" do
    {:ok, obj} =
      MultistateOutput.create(1, "TEST", %{
        number_of_states: 4,
        state_text: BACnetArray.from_list(["", "", "", ""])
      })

    arr = BACnetArray.from_list(["1", "2", "3", "4"])

    assert {:ok, %MultistateOutput{state_text: ^arr}} =
             MultistateOutput.update_property(obj, :state_text, arr)

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateOutput.update_property(obj, :state_text, BACnetArray.from_list([]))

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateOutput.update_property(obj, :state_text, BACnetArray.from_list(["1"]))

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateOutput.update_property(
               obj,
               :state_text,
               BACnetArray.from_list(["1", "2", "3", "4", "5"])
             )
  end

  test "verify update_property/3 enforces number_of_states for relinquish_default" do
    {:ok, obj} = MultistateOutput.create(1, "TEST", %{number_of_states: 4, relinquish_default: 1})

    assert {:ok, %{relinquish_default: 2}} =
             MultistateOutput.update_property(obj, :relinquish_default, 2)

    assert {:ok, %{relinquish_default: 3}} =
             MultistateOutput.update_property(obj, :relinquish_default, 3)

    assert {:ok, %{relinquish_default: 4}} =
             MultistateOutput.update_property(obj, :relinquish_default, 4)

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             MultistateOutput.update_property(obj, :relinquish_default, 5)

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             MultistateOutput.update_property(obj, :relinquish_default, 6)

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             MultistateOutput.update_property(obj, :relinquish_default, 32_767)
  end

  test "verify update_property/3 enforces number_of_states for priority_array" do
    {:ok, obj} = MultistateOutput.create(1, "TEST", %{number_of_states: 4, relinquish_default: 1})

    assert {:ok, %{priority_array: %{priority_16: 2}}} =
             MultistateOutput.update_property(obj, :priority_array, %PriorityArray{priority_16: 2})

    assert {:ok, _obj} =
             MultistateOutput.update_property(obj, :priority_array, %PriorityArray{priority_16: 3})

    assert {:ok, _obj} =
             MultistateOutput.update_property(obj, :priority_array, %PriorityArray{priority_16: 4})

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateOutput.update_property(obj, :priority_array, %PriorityArray{priority_16: 5})

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateOutput.update_property(obj, :priority_array, %PriorityArray{priority_16: 6})

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateOutput.update_property(obj, :priority_array, %PriorityArray{
               priority_16: 32_767
             })
  end

  test "verify set_priority/3 enforces number_of_states" do
    {:ok, obj} = MultistateOutput.create(1, "TEST", %{number_of_states: 4, relinquish_default: 1})

    assert {:ok, %{priority_array: %{priority_16: 2}}} = MultistateOutput.set_priority(obj, 16, 2)
    assert {:ok, _obj} = MultistateOutput.set_priority(obj, 16, 3)
    assert {:ok, _obj} = MultistateOutput.set_priority(obj, 16, 4)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateOutput.set_priority(obj, 16, 5)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateOutput.set_priority(obj, 16, 6)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateOutput.set_priority(obj, 16, 32_767)
  end
end
