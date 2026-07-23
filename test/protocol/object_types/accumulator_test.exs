defmodule BACnet.Test.Protocol.ObjectTypes.AccumulatorTest do
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsUtility
  # alias BACnet.Protocol.ObjectTypes.Accumulator

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_accumulator

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "verify accumulator scale real decoding" do
    assert {:ok, 10.0} =
             ObjectsUtility.cast_property_to_value(
               %ObjectIdentifier{type: :accumulator, instance: 0},
               :scale,
               %BACnet.Protocol.ApplicationTags.Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 0],
                 type: nil,
                 value: <<65, 32, 0, 0>>
               }
             )
  end

  test "verify accumulator scale int decoding" do
    assert {:ok, 10} =
             ObjectsUtility.cast_property_to_value(
               %ObjectIdentifier{type: :accumulator, instance: 0},
               :scale,
               %BACnet.Protocol.ApplicationTags.Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 1],
                 type: nil,
                 value: "\n"
               }
             )
  end

  test "verify accumulator scale real encoding" do
    assert {:ok,
            %BACnet.Protocol.ApplicationTags.Encoding{
              encoding: :tagged,
              extras: [tag_number: 0],
              type: nil,
              value: <<65, 32, 0, 0>>
            }} =
             ObjectsUtility.cast_value_to_property(
               %ObjectIdentifier{type: :accumulator, instance: 0},
               :scale,
               10.0
             )
  end

  test "verify accumulator scale int encoding" do
    assert {:ok,
            %BACnet.Protocol.ApplicationTags.Encoding{
              encoding: :tagged,
              extras: [tag_number: 1],
              type: nil,
              value: "\n"
            }} =
             ObjectsUtility.cast_value_to_property(
               %ObjectIdentifier{type: :accumulator, instance: 0},
               :scale,
               10
             )
  end
end
