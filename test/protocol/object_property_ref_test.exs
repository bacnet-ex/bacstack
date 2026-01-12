defmodule BACnet.Protocol.ObjectPropertyRefTest do
  alias BACnet.Protocol.ObjectPropertyRef
  alias BACnet.Protocol.ObjectIdentifier

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest ObjectPropertyRef

  test "decode ref" do
    assert {:ok,
            {%ObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :acked_transitions,
               property_array_index: nil
             }, []}} =
             ObjectPropertyRef.parse(
               tagged: {0, <<0, 0, 0, 24>>, 4},
               tagged: {1, <<0>>, 1}
             )
  end

  test "decode ref with array index" do
    assert {:ok,
            {%ObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :acked_transitions,
               property_array_index: 250
             }, []}} =
             ObjectPropertyRef.parse(
               tagged: {0, <<0, 0, 0, 24>>, 4},
               tagged: {1, <<0>>, 1},
               tagged: {2, <<250>>, 1}
             )
  end

  test "decode ref unknown property" do
    assert {:ok,
            {%ObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: 520,
               property_array_index: nil
             }, []}} =
             ObjectPropertyRef.parse(
               tagged: {0, <<0, 0, 0, 24>>, 4},
               tagged: {1, <<520::size(16)>>, 2}
             )
  end

  test "decode invalid ref missing pattern" do
    assert {:error, :invalid_tags} = ObjectPropertyRef.parse(tagged: {0, <<0, 0, 0, 24>>, 4})
  end

  test "decode invalid ref invalid tag" do
    assert {:error, :invalid_data} = ObjectPropertyRef.parse(tagged: {0, <<>>, 1})
  end

  test "encode ref" do
    assert {:ok,
            [
              tagged: {0, <<0, 0, 0, 24>>, 4},
              tagged: {1, <<0>>, 1}
            ]} =
             ObjectPropertyRef.encode(%ObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :acked_transitions,
               property_array_index: nil
             })
  end

  test "encode ref with array index" do
    assert {:ok,
            [
              tagged: {0, <<0, 0, 0, 24>>, 4},
              tagged: {1, <<0>>, 1},
              tagged: {2, <<250>>, 1}
            ]} =
             ObjectPropertyRef.encode(%ObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :acked_transitions,
               property_array_index: 250
             })
  end

  test "encode ref unknown property" do
    assert {:ok,
            [
              tagged: {0, <<0, 0, 0, 24>>, 4},
              tagged: {1, <<520::size(16)>>, 2}
            ]} =
             ObjectPropertyRef.encode(%ObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: 520,
               property_array_index: nil
             })
  end

  test "encode invalid ref" do
    assert {:error, :invalid_value} =
             ObjectPropertyRef.encode(%ObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: 5.0,
               property_array_index: nil
             })
  end

  test "valid ref" do
    assert true ==
             ObjectPropertyRef.valid?(%ObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :acked_transitions,
               property_array_index: nil
             })

    assert true ==
             ObjectPropertyRef.valid?(%ObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :acked_transitions,
               property_array_index: 250
             })

    assert true ==
             ObjectPropertyRef.valid?(%ObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: 520,
               property_array_index: nil
             })
  end

  test "invalid ref" do
    assert false ==
             ObjectPropertyRef.valid?(%ObjectPropertyRef{
               object_identifier: :hello,
               property_identifier: :acked_transitions,
               property_array_index: nil
             })

    assert false ==
             ObjectPropertyRef.valid?(%ObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :hello, instance: 24},
               property_identifier: :acked_transitions,
               property_array_index: nil
             })

    assert false ==
             ObjectPropertyRef.valid?(%ObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: :hello,
               property_array_index: nil
             })

    assert false ==
             ObjectPropertyRef.valid?(%ObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               property_identifier: 520,
               property_array_index: :hello
             })
  end
end
