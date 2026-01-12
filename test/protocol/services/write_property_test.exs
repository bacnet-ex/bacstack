defmodule BACnet.Test.Protocol.Services.WritePropertyTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol
  alias BACnet.Protocol.Services.WriteProperty

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest WriteProperty

  test "get name" do
    assert :write_property == WriteProperty.get_name()
  end

  test "is confirmed" do
    assert true == WriteProperty.is_confirmed()
  end

  test "decoding WriteProperty" do
    assert {:ok,
            %WriteProperty{
              object_identifier: %ObjectIdentifier{
                type: :analog_value,
                instance: 1
              },
              property_identifier: :present_value,
              property_array_index: nil,
              property_value: Encoding.create!({:real, 180.0}),
              priority: nil
            }} ==
             WriteProperty.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: [
                 tagged: {0, <<0, 128, 0, 1>>, 4},
                 tagged: {1, "U", 1},
                 constructed: {3, {:real, 180.0}, 0}
               ]
             })
  end

  test "decoding WriteProperty list" do
    assert {:ok,
            %WriteProperty{
              object_identifier: %ObjectIdentifier{
                type: :analog_value,
                instance: 1
              },
              property_identifier: :present_value,
              property_array_index: nil,
              property_value: [
                Encoding.create!({:real, 180.0}),
                Encoding.create!({:enumerated, 1})
              ],
              priority: nil
            }} ==
             WriteProperty.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: [
                 tagged: {0, <<0, 128, 0, 1>>, 4},
                 tagged: {1, "U", 1},
                 constructed: {3, [{:real, 180.0}, {:enumerated, 1}], 0}
               ]
             })
  end

  test "decoding WriteProperty with priority" do
    assert {:ok,
            %WriteProperty{
              object_identifier: %ObjectIdentifier{
                type: :analog_value,
                instance: 1
              },
              property_identifier: :present_value,
              property_array_index: nil,
              property_value: Encoding.create!({:real, 180.0}),
              priority: 10
            }} ==
             WriteProperty.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: [
                 tagged: {0, <<0, 128, 0, 1>>, 4},
                 tagged: {1, "U", 1},
                 constructed: {3, {:real, 180.0}, 0},
                 tagged: {4, "\n", 1}
               ]
             })
  end

  test "decoding WriteProperty with priority array index" do
    assert {:ok,
            %WriteProperty{
              object_identifier: %ObjectIdentifier{
                type: :analog_value,
                instance: 1
              },
              property_identifier: :present_value,
              property_array_index: 250,
              property_value: Encoding.create!({:real, 180.0}),
              priority: nil
            }} ==
             WriteProperty.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: [
                 tagged: {0, <<0, 128, 0, 1>>, 4},
                 tagged: {1, "U", 1},
                 tagged: {2, <<250>>, 1},
                 constructed: {3, {:real, 180.0}, 0}
               ]
             })
  end

  test "decoding WriteProperty invalid encoding" do
    assert {:error, :unknown_tag_encoding} =
             WriteProperty.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: [
                 tagged: {0, <<>>, 0},
                 tagged: {1, "U", 1}
               ]
             })
  end

  test "decoding WriteProperty invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             WriteProperty.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: [
                 tagged: {0, <<0, 128, 0, 1>>, 4},
                 tagged: {1, "U", 1}
               ]
             })
  end

  test "decoding WriteProperty invalid APDU" do
    assert {:error, :invalid_request} =
             WriteProperty.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :i_am,
               parameters: [
                 tagged: {0, <<0, 128, 0, 1>>, 4},
                 tagged: {1, "U", 1}
               ]
             })
  end

  test "encoding WriteProperty" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :write_property,
              parameters: [
                tagged: {0, <<0, 128, 0, 1>>, 4},
                tagged: {1, "U", 1},
                constructed: {3, {:real, 180.0}, 0}
              ]
            }} =
             WriteProperty.to_apdu(
               %WriteProperty{
                 object_identifier: %ObjectIdentifier{
                   type: :analog_value,
                   instance: 1
                 },
                 property_identifier: :present_value,
                 property_array_index: nil,
                 property_value: Encoding.create!({:real, 180.0}),
                 priority: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding WriteProperty list" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :write_property,
              parameters: [
                tagged: {0, <<0, 128, 0, 1>>, 4},
                tagged: {1, "U", 1},
                constructed: {3, [{:real, 180.0}, {:enumerated, 1}], 0}
              ]
            }} =
             WriteProperty.to_apdu(
               %WriteProperty{
                 object_identifier: %ObjectIdentifier{
                   type: :analog_value,
                   instance: 1
                 },
                 property_identifier: :present_value,
                 property_array_index: nil,
                 property_value: [
                   Encoding.create!({:real, 180.0}),
                   Encoding.create!({:enumerated, 1})
                 ],
                 priority: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding WriteProperty with priority" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :write_property,
              parameters: [
                tagged: {0, <<0, 128, 0, 1>>, 4},
                tagged: {1, "U", 1},
                constructed: {3, {:real, 180.0}, 0},
                tagged: {4, "\n", 1}
              ]
            }} =
             WriteProperty.to_apdu(
               %WriteProperty{
                 object_identifier: %ObjectIdentifier{
                   type: :analog_value,
                   instance: 1
                 },
                 property_identifier: :present_value,
                 property_array_index: nil,
                 property_value: Encoding.create!({:real, 180.0}),
                 priority: 10
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding WriteProperty with property array index" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :write_property,
              parameters: [
                tagged: {0, <<0, 128, 0, 1>>, 4},
                tagged: {1, "U", 1},
                tagged: {2, <<250>>, 1},
                constructed: {3, {:real, 180.0}, 0}
              ]
            }} =
             WriteProperty.to_apdu(
               %WriteProperty{
                 object_identifier: %ObjectIdentifier{
                   type: :analog_value,
                   instance: 1
                 },
                 property_identifier: :present_value,
                 property_array_index: 250,
                 property_value: Encoding.create!({:real, 180.0}),
                 priority: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding WriteProperty invalid encoding" do
    assert {:error, :invalid_value} =
             WriteProperty.to_apdu(
               %WriteProperty{
                 object_identifier: %ObjectIdentifier{
                   type: :analog_value,
                   instance: 1
                 },
                 property_identifier: :present_value,
                 property_array_index: nil,
                 property_value: [%{Encoding.create!({:real, 180.0}) | encoding: nil}],
                 priority: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "protocol implementation get name" do
    assert :write_property ==
             ServicesProtocol.get_name(%WriteProperty{
               object_identifier: %ObjectIdentifier{
                 type: :analog_value,
                 instance: 1
               },
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: [%{Encoding.create!({:real, 180.0}) | encoding: nil}],
               priority: nil
             })
  end

  test "protocol implementation is confirmed" do
    assert true ==
             ServicesProtocol.is_confirmed(%WriteProperty{
               object_identifier: %ObjectIdentifier{
                 type: :analog_value,
                 instance: 1
               },
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: [%{Encoding.create!({:real, 180.0}) | encoding: nil}],
               priority: nil
             })
  end

  test "protocol implementation to APDU" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :write_property,
              parameters: [
                tagged: {0, <<0, 128, 0, 1>>, 4},
                tagged: {1, "U", 1},
                constructed: {3, {:real, 180.0}, 0}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %WriteProperty{
                 object_identifier: %ObjectIdentifier{
                   type: :analog_value,
                   instance: 1
                 },
                 property_identifier: :present_value,
                 property_array_index: nil,
                 property_value: Encoding.create!({:real, 180.0}),
                 priority: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end
end
