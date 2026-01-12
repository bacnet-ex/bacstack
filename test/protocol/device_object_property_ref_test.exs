defmodule BACnet.Protocol.DeviceObjectPropertyRefTest do
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ObjectIdentifier

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest DeviceObjectPropertyRef

  test "decode ref" do
    assert {:ok,
            {%DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :acked_transitions,
               property_array_index: nil,
               device_identifier: nil
             }, []}} =
             DeviceObjectPropertyRef.parse(
               tagged: {0, <<0, 0, 0, 24>>, 4},
               tagged: {1, <<0>>, 1}
             )
  end

  test "decode ref with array index" do
    assert {:ok,
            {%DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :acked_transitions,
               property_array_index: 250,
               device_identifier: nil
             }, []}} =
             DeviceObjectPropertyRef.parse(
               tagged: {0, <<0, 0, 0, 24>>, 4},
               tagged: {1, <<0>>, 1},
               tagged: {2, <<250>>, 1}
             )
  end

  test "decode ref with device" do
    assert {:ok,
            {%DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :acked_transitions,
               property_array_index: nil,
               device_identifier: %ObjectIdentifier{type: :device, instance: 21}
             }, []}} =
             DeviceObjectPropertyRef.parse(
               tagged: {0, <<0, 0, 0, 24>>, 4},
               tagged: {1, <<0>>, 1},
               tagged: {3, <<8::size(10), 21::size(22)>>, 4}
             )
  end

  test "decode ref unknown property" do
    assert {:ok,
            {%DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: 520,
               property_array_index: nil,
               device_identifier: nil
             }, []}} =
             DeviceObjectPropertyRef.parse(
               tagged: {0, <<0, 0, 0, 24>>, 4},
               tagged: {1, <<520::size(16)>>, 2}
             )
  end

  test "decode invalid ref missing pattern" do
    assert {:error, :invalid_tags} =
             DeviceObjectPropertyRef.parse(tagged: {0, <<0, 0, 0, 24>>, 4})
  end

  test "decode invalid ref invalid tag" do
    assert {:error, :invalid_data} = DeviceObjectPropertyRef.parse(tagged: {0, <<>>, 1})
  end

  test "encode ref" do
    assert {:ok,
            [
              tagged: {0, <<0, 0, 0, 24>>, 4},
              tagged: {1, <<0>>, 1}
            ]} =
             DeviceObjectPropertyRef.encode(%DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :acked_transitions,
               property_array_index: nil,
               device_identifier: nil
             })
  end

  test "encode ref with array index" do
    assert {:ok,
            [
              tagged: {0, <<0, 0, 0, 24>>, 4},
              tagged: {1, <<0>>, 1},
              tagged: {2, <<250>>, 1}
            ]} =
             DeviceObjectPropertyRef.encode(%DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :acked_transitions,
               property_array_index: 250,
               device_identifier: nil
             })
  end

  test "encode ref with device" do
    assert {:ok,
            [
              tagged: {0, <<0, 0, 0, 24>>, 4},
              tagged: {1, <<0>>, 1},
              tagged: {3, <<8::size(10), 21::size(22)>>, 4}
            ]} =
             DeviceObjectPropertyRef.encode(%DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :acked_transitions,
               property_array_index: nil,
               device_identifier: %ObjectIdentifier{type: :device, instance: 21}
             })
  end

  test "encode ref unknown property" do
    assert {:ok,
            [
              tagged: {0, <<0, 0, 0, 24>>, 4},
              tagged: {1, <<520::size(16)>>, 2}
            ]} =
             DeviceObjectPropertyRef.encode(%DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: 520,
               property_array_index: nil,
               device_identifier: nil
             })
  end

  test "encode invalid ref" do
    assert {:error, :invalid_value} =
             DeviceObjectPropertyRef.encode(%DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: 5.0,
               property_array_index: nil,
               device_identifier: nil
             })
  end

  test "valid ref" do
    assert true ==
             DeviceObjectPropertyRef.valid?(%DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :acked_transitions,
               property_array_index: nil,
               device_identifier: nil
             })

    assert true ==
             DeviceObjectPropertyRef.valid?(%DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :acked_transitions,
               property_array_index: 250,
               device_identifier: nil
             })

    assert true ==
             DeviceObjectPropertyRef.valid?(%DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :acked_transitions,
               property_array_index: nil,
               device_identifier: %ObjectIdentifier{type: :device, instance: 21}
             })

    assert true ==
             DeviceObjectPropertyRef.valid?(%DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: 520,
               property_array_index: nil,
               device_identifier: nil
             })
  end

  test "invalid ref" do
    assert false ==
             DeviceObjectPropertyRef.valid?(%DeviceObjectPropertyRef{
               object_identifier: :hello,
               property_identifier: :acked_transitions,
               property_array_index: nil,
               device_identifier: nil
             })

    assert false ==
             DeviceObjectPropertyRef.valid?(%DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :hello, instance: 24},
               property_identifier: :acked_transitions,
               property_array_index: nil,
               device_identifier: nil
             })

    assert false ==
             DeviceObjectPropertyRef.valid?(%DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :hello,
               property_array_index: nil,
               device_identifier: nil
             })

    assert false ==
             DeviceObjectPropertyRef.valid?(%DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: 520,
               property_array_index: :hello,
               device_identifier: nil
             })

    assert false ==
             DeviceObjectPropertyRef.valid?(%DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: 520,
               property_array_index: nil,
               device_identifier: :hello
             })

    assert false ==
             DeviceObjectPropertyRef.valid?(%DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: 520,
               property_array_index: nil,
               device_identifier: %ObjectIdentifier{type: :file, instance: 2}
             })

    assert false ==
             DeviceObjectPropertyRef.valid?(%DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: 520,
               property_array_index: nil,
               device_identifier: %ObjectIdentifier{type: :hello, instance: 24}
             })
  end
end
