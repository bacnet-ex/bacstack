defmodule BACnet.Test.Protocol.ObjectTypes.MultistateInputTest do
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.ObjectTypes.MultistateInput

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_multi_state_input

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "verify create/4 enforces number_of_states for present_value" do
    assert {:ok, _obj} =
             MultistateInput.create(1, "TEST", %{number_of_states: 4, present_value: 1})

    assert {:ok, _obj} =
             MultistateInput.create(1, "TEST", %{number_of_states: 4, present_value: 2})

    assert {:ok, _obj} =
             MultistateInput.create(1, "TEST", %{number_of_states: 4, present_value: 3})

    assert {:ok, _obj} =
             MultistateInput.create(1, "TEST", %{number_of_states: 4, present_value: 4})

    assert {:error, {:value_failed_property_validation, :present_value}} =
             MultistateInput.create(1, "TEST", %{number_of_states: 4, present_value: 5})

    assert {:error, {:value_failed_property_validation, :present_value}} =
             MultistateInput.create(1, "TEST", %{number_of_states: 4, present_value: 32_767})
  end

  test "verify create/4 enforces number_of_states for state_text" do
    assert {:ok, _obj} =
             MultistateInput.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list(["1", "2", "3", "4"])
             })

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateInput.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list([])
             })

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateInput.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list(["1"])
             })

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateInput.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list(["1", "2", "3", "4", "5"])
             })
  end

  test "verify update_property/3 enforces number_of_states for present_value" do
    {:ok, obj} = MultistateInput.create(1, "TEST", %{number_of_states: 4})

    assert {:ok, %{present_value: 2}} = MultistateInput.update_property(obj, :present_value, 2)
    assert {:ok, %{present_value: 3}} = MultistateInput.update_property(obj, :present_value, 3)
    assert {:ok, %{present_value: 4}} = MultistateInput.update_property(obj, :present_value, 4)

    assert {:error, {:value_failed_property_validation, :present_value}} =
             MultistateInput.update_property(obj, :present_value, 5)

    assert {:error, {:value_failed_property_validation, :present_value}} =
             MultistateInput.update_property(obj, :present_value, 6)

    assert {:error, {:value_failed_property_validation, :present_value}} =
             MultistateInput.update_property(obj, :present_value, 32_767)
  end

  test "verify update_property/3 enforces number_of_states for state_text" do
    {:ok, obj} =
      MultistateInput.create(1, "TEST", %{
        number_of_states: 4,
        state_text: BACnetArray.from_list(["", "", "", ""])
      })

    arr = BACnetArray.from_list(["1", "2", "3", "4"])

    assert {:ok, %MultistateInput{state_text: ^arr}} =
             MultistateInput.update_property(obj, :state_text, arr)

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateInput.update_property(obj, :state_text, BACnetArray.from_list([]))

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateInput.update_property(obj, :state_text, BACnetArray.from_list(["1"]))

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateInput.update_property(
               obj,
               :state_text,
               BACnetArray.from_list(["1", "2", "3", "4", "5"])
             )
  end
end
