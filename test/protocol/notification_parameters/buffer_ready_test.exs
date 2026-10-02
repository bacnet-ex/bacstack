defmodule BACnet.Protocol.NotificationParameters.BufferReadyTest do
  alias BACnet.BeamTypes
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.NotificationParameters
  alias BACnet.Protocol.NotificationParameters.BufferReady
  alias BACnet.Protocol.ObjectIdentifier

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest BufferReady

  test "create struct by hand is valid according to typespec" do
    assert true ==
             BeamTypes.check_type({:struct, BufferReady}, %BufferReady{
               buffer_property: %DeviceObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{type: :analog_input, instance: 0},
                 property_identifier: :present_value,
                 property_array_index: nil,
                 device_identifier: nil
               },
               previous_notification: 0,
               current_notification: 100
             })
  end

  test "get tag number" do
    assert 10 = BufferReady.get_tag_number()
  end

  test "encode" do
    assert {:ok,
            {:constructed,
             {10,
              [
                constructed: {0, [tagged: {0, <<0, 0, 0, 0>>, 4}, tagged: {1, "U", 1}], 0},
                tagged: {1, <<0>>, 1},
                tagged: {2, <<100>>, 1}
              ], 0}}} =
             NotificationParameters.encode(%BufferReady{
               buffer_property: %DeviceObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{type: :analog_input, instance: 0},
                 property_identifier: :present_value,
                 property_array_index: nil,
                 device_identifier: nil
               },
               previous_notification: 0,
               current_notification: 100
             })
  end

  test "encode failure 1" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%BufferReady{
               buffer_property: 5.9,
               previous_notification: 0,
               current_notification: 100
             })
  end

  test "encode failure 2" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%BufferReady{
               buffer_property: %DeviceObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{type: :analog_input, instance: 0},
                 property_identifier: :present_value,
                 property_array_index: nil,
                 device_identifier: nil
               },
               previous_notification: 0.0,
               current_notification: 100
             })
  end

  test "encode failure 3" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%BufferReady{
               buffer_property: %DeviceObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{type: :analog_input, instance: 0},
                 property_identifier: :present_value,
                 property_array_index: nil,
                 device_identifier: nil
               },
               previous_notification: 1.2,
               current_notification: 100
             })
  end

  test "encode invalid data" do
    assert {:error, :invalid_value} =
             NotificationParameters.encode(%BufferReady{
               buffer_property: %DeviceObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{type: :analog_input, instance: false},
                 property_identifier: :present_value,
                 property_array_index: nil,
                 device_identifier: nil
               },
               previous_notification: 12,
               current_notification: 100
             })
  end

  test "decode" do
    assert {:ok,
            %BufferReady{
              buffer_property: %DeviceObjectPropertyRef{
                object_identifier: %ObjectIdentifier{type: :analog_input, instance: 0},
                property_identifier: :present_value,
                property_array_index: nil,
                device_identifier: nil
              },
              previous_notification: 0,
              current_notification: 100
            }} =
             NotificationParameters.parse(
               {:constructed,
                {10,
                 [
                   constructed: {0, [tagged: {0, <<0, 0, 0, 0>>, 4}, tagged: {1, "U", 1}], 0},
                   tagged: {1, <<0>>, 1},
                   tagged: {2, <<100>>, 1}
                 ], 0}}
             )
  end

  test "decode invalid" do
    assert {:error, :invalid_notification_values} =
             NotificationParameters.parse(
               {:constructed,
                {10,
                 [
                   constructed: {0, [tagged: {0, <<0, 0, 0, 0>>, 4}, tagged: {1, "U", 1}], 0},
                   tagged: {1, <<0>>, 1}
                 ], 0}}
             )
  end

  test "decode invalid data" do
    assert {:error, :unknown_tag_encoding} =
             NotificationParameters.parse(
               {:constructed,
                {10,
                 [
                   constructed: {0, [tagged: {0, <<>>, 0}, tagged: {1, "U", 1}], 0},
                   tagged: {1, <<0>>, 1},
                   tagged: {2, <<100>>, 1}
                 ], 0}}
             )
  end
end
