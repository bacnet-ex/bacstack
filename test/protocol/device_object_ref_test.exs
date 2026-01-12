defmodule BACnet.Protocol.DeviceObjectRefTest do
  alias BACnet.Protocol.DeviceObjectRef
  alias BACnet.Protocol.ObjectIdentifier

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest DeviceObjectRef

  test "decode ref" do
    assert {:ok,
            {%DeviceObjectRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               device_identifier: nil
             }, []}} = DeviceObjectRef.parse(tagged: {1, <<0, 0, 0, 24>>, 4})
  end

  test "decode ref with device" do
    assert {:ok,
            {%DeviceObjectRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               device_identifier: %ObjectIdentifier{type: :device, instance: 21}
             }, []}} =
             DeviceObjectRef.parse(
               tagged: {0, <<8::size(10), 21::size(22)>>, 4},
               tagged: {1, <<0, 0, 0, 24>>, 4}
             )
  end

  test "decode invalid ref missing pattern" do
    assert {:error, :invalid_tags} = DeviceObjectRef.parse([])
  end

  test "decode invalid ref invalid tag" do
    assert {:error, :invalid_data} = DeviceObjectRef.parse(tagged: {1, <<>>, 1})
  end

  test "encode ref" do
    assert {:ok,
            [
              tagged: {1, <<0, 0, 0, 24>>, 4}
            ]} =
             DeviceObjectRef.encode(%DeviceObjectRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               device_identifier: nil
             })
  end

  test "encode ref with device" do
    assert {:ok,
            [
              tagged: {0, <<8::size(10), 21::size(22)>>, 4},
              tagged: {1, <<0, 0, 0, 24>>, 4}
            ]} =
             DeviceObjectRef.encode(%DeviceObjectRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               device_identifier: %ObjectIdentifier{type: :device, instance: 21}
             })
  end

  test "encode invalid ref" do
    assert {:error, :invalid_value} =
             DeviceObjectRef.encode(%DeviceObjectRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               device_identifier: 5.0
             })
  end

  test "valid ref" do
    assert true ==
             DeviceObjectRef.valid?(%DeviceObjectRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               device_identifier: nil
             })

    assert true ==
             DeviceObjectRef.valid?(%DeviceObjectRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               device_identifier: %ObjectIdentifier{type: :device, instance: 21}
             })
  end

  test "invalid ref" do
    assert false ==
             DeviceObjectRef.valid?(%DeviceObjectRef{
               object_identifier: :hello,
               device_identifier: nil
             })

    assert false ==
             DeviceObjectRef.valid?(%DeviceObjectRef{
               object_identifier: %ObjectIdentifier{type: :hello, instance: 24},
               device_identifier: nil
             })

    assert false ==
             DeviceObjectRef.valid?(%DeviceObjectRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               device_identifier: :hello
             })

    assert false ==
             DeviceObjectRef.valid?(%DeviceObjectRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               device_identifier: %ObjectIdentifier{type: :file, instance: 2}
             })

    assert false ==
             DeviceObjectRef.valid?(%DeviceObjectRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               device_identifier: %ObjectIdentifier{type: :hello, instance: 24}
             })
  end
end
