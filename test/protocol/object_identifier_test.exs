defmodule BACnet.Protocol.ObjectIdentifierTest do
  alias BACnet.Protocol.ObjectIdentifier

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest ObjectIdentifier

  test "decode object identifier" do
    assert {:ok, {%ObjectIdentifier{type: :device, instance: 12}, []}} =
             ObjectIdentifier.parse(
               object_identifier: %ObjectIdentifier{type: :device, instance: 12}
             )
  end

  test "decode invalid object identifier" do
    assert {:error, :invalid_tags} = ObjectIdentifier.parse([])
  end

  test "encode object identifier" do
    assert {:ok, [object_identifier: %ObjectIdentifier{type: :device, instance: 12}]} =
             ObjectIdentifier.encode(%ObjectIdentifier{type: :device, instance: 12})
  end

  test "from number" do
    assert {:ok, %ObjectIdentifier{type: :analog_input, instance: 255}} =
             ObjectIdentifier.from_number(255)

    assert {:ok, %ObjectIdentifier{type: :device, instance: 1_201_610}} =
             ObjectIdentifier.from_number(34_756_042)
  end

  test "to number" do
    assert 255 = ObjectIdentifier.to_number(%ObjectIdentifier{type: :analog_input, instance: 255})

    assert 34_756_042 =
             ObjectIdentifier.to_number(%ObjectIdentifier{type: :device, instance: 1_201_610})
  end

  test "valid object identifier" do
    assert true == ObjectIdentifier.valid?(%ObjectIdentifier{type: :device, instance: 12})
    assert true == ObjectIdentifier.valid?(%ObjectIdentifier{type: :analog_value, instance: 0})
    assert true == ObjectIdentifier.valid?(%ObjectIdentifier{type: :file, instance: 0x3FFFFF})
  end

  test "invalid object identifier" do
    assert false == ObjectIdentifier.valid?(%ObjectIdentifier{type: :hello, instance: 0})
    assert false == ObjectIdentifier.valid?(%ObjectIdentifier{type: :file, instance: -1})
    assert false == ObjectIdentifier.valid?(%ObjectIdentifier{type: :device, instance: 0x400000})

    assert false ==
             ObjectIdentifier.valid?(%ObjectIdentifier{type: :analog_value, instance: :hello})
  end
end
