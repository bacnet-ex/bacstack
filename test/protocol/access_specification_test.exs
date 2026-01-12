defmodule BACnet.Protocol.AccessSpecificationTest do
  alias BACnet.Protocol.AccessSpecification
  alias BACnet.Protocol.ObjectIdentifier

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest AccessSpecification

  test "decode access specification" do
    assert {:ok,
            {%AccessSpecification{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               properties: [
                 %AccessSpecification.Property{
                   property_identifier: :ack_required,
                   property_array_index: nil,
                   property_value: nil
                 },
                 %AccessSpecification.Property{
                   property_identifier: :deadband,
                   property_array_index: nil,
                   property_value: nil
                 }
               ]
             }, []}} =
             AccessSpecification.parse(
               tagged: {0, <<0, 0, 0, 24>>, 4},
               constructed: {1, [tagged: {0, <<1>>, 1}, tagged: {0, <<25>>, 1}], 0}
             )
  end

  test "decode access specification with property tag error" do
    assert {:error, :invalid_tags} =
             AccessSpecification.parse(
               tagged: {0, <<0, 0, 0, 24>>, 4},
               constructed: {1, [], 0}
             )
  end

  test "decode access specification with property tag error nested" do
    assert {:error, :invalid_tags} =
             AccessSpecification.parse(
               tagged: {0, <<0, 0, 0, 24>>, 4},
               constructed: {1, [tagged: {0, <<1>>, 1}, tagged: {10, <<25>>, 1}], 0}
             )
  end

  test "decode invalid access specification missing tags" do
    assert {:error, :invalid_tags} = AccessSpecification.parse([])
  end

  test "decode invalid access specification invalid tags" do
    assert {:error, :unknown_tag_encoding} = AccessSpecification.parse(tagged: {0, <<>>, 0})
  end

  test "encode access specification" do
    assert {:ok,
            [
              tagged: {0, <<0, 0, 0, 24>>, 4},
              constructed: {1, [tagged: {0, <<1>>, 1}, tagged: {0, <<25>>, 1}], 0}
            ]} =
             AccessSpecification.encode(%AccessSpecification{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               properties: [
                 %AccessSpecification.Property{
                   property_identifier: :ack_required,
                   property_array_index: nil,
                   property_value: nil
                 },
                 %AccessSpecification.Property{
                   property_identifier: :deadband,
                   property_array_index: nil,
                   property_value: nil
                 }
               ]
             })
  end

  test "encode invalid access specification" do
    assert {:error, :invalid_value} =
             AccessSpecification.encode(%AccessSpecification{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               properties: [
                 %AccessSpecification.Property{
                   property_identifier: 4.2,
                   property_array_index: nil,
                   property_value: nil
                 }
               ]
             })
  end

  test "valid access specification" do
    assert true ==
             AccessSpecification.valid?(%AccessSpecification{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               properties: [
                 %AccessSpecification.Property{
                   property_identifier: :ack_required,
                   property_array_index: nil,
                   property_value: nil
                 },
                 %AccessSpecification.Property{
                   property_identifier: :deadband,
                   property_array_index: nil,
                   property_value: nil
                 }
               ]
             })

    assert true ==
             AccessSpecification.valid?(%AccessSpecification{
               object_identifier: %ObjectIdentifier{type: :device, instance: 24},
               properties: [
                 %AccessSpecification.Property{
                   property_identifier: :ack_required,
                   property_array_index: nil,
                   property_value: nil
                 },
                 :all,
                 :required,
                 :optional
               ]
             })
  end

  test "invalid access specification" do
    assert false ==
             AccessSpecification.valid?(%AccessSpecification{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               properties: []
             })

    assert false ==
             AccessSpecification.valid?(%AccessSpecification{
               object_identifier: %ObjectIdentifier{type: 512, instance: 24},
               properties: [
                 %AccessSpecification.Property{
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: nil
                 }
               ]
             })

    assert false ==
             AccessSpecification.valid?(%AccessSpecification{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 24},
               properties: [
                 %AccessSpecification.Property{
                   property_identifier: :hello_there,
                   property_array_index: nil,
                   property_value: nil
                 }
               ]
             })

    assert false ==
             AccessSpecification.valid?(%AccessSpecification{
               object_identifier: :hello,
               properties: [
                 %AccessSpecification.Property{
                   property_identifier: :there,
                   property_array_index: nil,
                   property_value: nil
                 }
               ]
             })

    assert false ==
             AccessSpecification.valid?(%AccessSpecification{
               object_identifier: %ObjectIdentifier{type: :hello, instance: 24},
               properties: [
                 %AccessSpecification.Property{
                   property_identifier: :there,
                   property_array_index: nil,
                   property_value: nil
                 }
               ]
             })

    assert false ==
             AccessSpecification.valid?(%AccessSpecification{
               object_identifier: %ObjectIdentifier{type: :device, instance: 24},
               properties: [
                 :hello_there
               ]
             })
  end
end
