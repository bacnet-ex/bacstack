defmodule BACnet.Test.Protocol.ObjectTypes.MultistateValueTest do
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.ObjectTypes.MultistateValue
  alias BACnet.Protocol.PriorityArray

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_multi_state_value

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "verify create/4 enforces number_of_states for relinquish_default" do
    assert {:ok, %{present_value: 1} = _obj} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, relinquish_default: 1})

    assert {:ok, %{present_value: 2} = _obj} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, relinquish_default: 2})

    assert {:ok, %{present_value: 3} = _obj} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, relinquish_default: 3})

    assert {:ok, %{present_value: 4} = _obj} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, relinquish_default: 4})

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, relinquish_default: 5})

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, relinquish_default: 32_767})
  end

  test "verify create/4 enforces number_of_states for present_value" do
    assert {:ok, %{present_value: 1} = _obj} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, present_value: 1})

    assert {:ok, %{present_value: 2} = _obj} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, present_value: 2})

    assert {:ok, %{present_value: 3} = _obj} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, present_value: 3})

    assert {:ok, %{present_value: 4} = _obj} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, present_value: 4})

    assert {:error, {:value_failed_property_validation, :present_value}} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, present_value: 5})

    assert {:error, {:value_failed_property_validation, :present_value}} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, present_value: 32_767})
  end

  test "verify create/4 given present_value gets re-calculated for commandable objects" do
    assert {:ok, %{present_value: 1} = _obj} =
             MultistateValue.create(1, "TEST", %{
               number_of_states: 4,
               relinquish_default: 1,
               present_value: 1
             })

    assert {:ok, %{present_value: 1} = _obj} =
             MultistateValue.create(1, "TEST", %{
               number_of_states: 4,
               relinquish_default: 1,
               present_value: 2
             })

    assert {:ok, %{present_value: 1} = _obj} =
             MultistateValue.create(1, "TEST", %{
               number_of_states: 4,
               relinquish_default: 1,
               present_value: 3
             })

    assert {:ok, %{present_value: 1} = _obj} =
             MultistateValue.create(1, "TEST", %{
               number_of_states: 4,
               relinquish_default: 1,
               present_value: 4
             })

    assert {:ok, %{present_value: 1} = _obj} =
             MultistateValue.create(1, "TEST", %{
               number_of_states: 4,
               relinquish_default: 1,
               present_value: 5
             })

    assert {:ok, %{present_value: 1} = _obj} =
             MultistateValue.create(1, "TEST", %{
               number_of_states: 4,
               relinquish_default: 1,
               present_value: 32_767
             })
  end

  test "verify create/4 enforces number_of_states for state_text" do
    assert {:ok, _obj} =
             MultistateValue.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list(["1", "2", "3", "4"])
             })

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateValue.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list([])
             })

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateValue.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list(["1"])
             })

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateValue.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list(["1", "2", "3", "4", "5"])
             })
  end

  test "verify update_property/3 enforces number_of_states for present_value" do
    {:ok, obj} = MultistateValue.create(1, "TEST", %{number_of_states: 4})

    assert {:ok, %{present_value: 2}} = MultistateValue.update_property(obj, :present_value, 2)
    assert {:ok, %{present_value: 3}} = MultistateValue.update_property(obj, :present_value, 3)
    assert {:ok, %{present_value: 4}} = MultistateValue.update_property(obj, :present_value, 4)

    assert {:error, {:value_failed_property_validation, :present_value}} =
             MultistateValue.update_property(obj, :present_value, 5)

    assert {:error, {:value_failed_property_validation, :present_value}} =
             MultistateValue.update_property(obj, :present_value, 6)

    assert {:error, {:value_failed_property_validation, :present_value}} =
             MultistateValue.update_property(obj, :present_value, 32_767)
  end

  test "verify update_property/3 enforces number_of_states for state_text" do
    {:ok, obj} =
      MultistateValue.create(1, "TEST", %{
        number_of_states: 4,
        state_text: BACnetArray.from_list(["", "", "", ""])
      })

    arr = BACnetArray.from_list(["1", "2", "3", "4"])

    assert {:ok, %MultistateValue{state_text: ^arr}} =
             MultistateValue.update_property(obj, :state_text, arr)

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateValue.update_property(obj, :state_text, BACnetArray.from_list([]))

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateValue.update_property(obj, :state_text, BACnetArray.from_list(["1"]))

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateValue.update_property(
               obj,
               :state_text,
               BACnetArray.from_list(["1", "2", "3", "4", "5"])
             )
  end

  test "verify update_property/3 enforces number_of_states for relinquish_default" do
    {:ok, obj} = MultistateValue.create(1, "TEST", %{number_of_states: 4, relinquish_default: 1})

    assert {:ok, %{relinquish_default: 2}} =
             MultistateValue.update_property(obj, :relinquish_default, 2)

    assert {:ok, %{relinquish_default: 3}} =
             MultistateValue.update_property(obj, :relinquish_default, 3)

    assert {:ok, %{relinquish_default: 4}} =
             MultistateValue.update_property(obj, :relinquish_default, 4)

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             MultistateValue.update_property(obj, :relinquish_default, 5)

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             MultistateValue.update_property(obj, :relinquish_default, 6)

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             MultistateValue.update_property(obj, :relinquish_default, 32_767)
  end

  test "verify update_property/3 enforces number_of_states for priority_array" do
    {:ok, obj} = MultistateValue.create(1, "TEST", %{number_of_states: 4, relinquish_default: 1})

    assert {:ok, %{priority_array: %{priority_16: 2}}} =
             MultistateValue.update_property(obj, :priority_array, %PriorityArray{priority_16: 2})

    assert {:ok, _obj} =
             MultistateValue.update_property(obj, :priority_array, %PriorityArray{priority_16: 3})

    assert {:ok, _obj} =
             MultistateValue.update_property(obj, :priority_array, %PriorityArray{priority_16: 4})

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateValue.update_property(obj, :priority_array, %PriorityArray{priority_16: 5})

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateValue.update_property(obj, :priority_array, %PriorityArray{priority_16: 6})

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateValue.update_property(obj, :priority_array, %PriorityArray{
               priority_16: 32_767
             })
  end

  test "verify set_priority/3 enforces number_of_states" do
    {:ok, obj} = MultistateValue.create(1, "TEST", %{number_of_states: 4, relinquish_default: 1})

    assert {:ok, %{priority_array: %{priority_16: 2}}} = MultistateValue.set_priority(obj, 16, 2)
    assert {:ok, _obj} = MultistateValue.set_priority(obj, 16, 3)
    assert {:ok, _obj} = MultistateValue.set_priority(obj, 16, 4)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateValue.set_priority(obj, 16, 5)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateValue.set_priority(obj, 16, 6)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateValue.set_priority(obj, 16, 32_767)
  end
end
