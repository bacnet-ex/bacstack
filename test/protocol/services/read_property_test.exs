defmodule BACnet.Test.Protocol.Services.ReadPropertyTest do
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol
  alias BACnet.Protocol.Services.ReadProperty

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest ReadProperty

  test "get name" do
    assert :read_property == ReadProperty.get_name()
  end

  test "is confirmed" do
    assert true == ReadProperty.is_confirmed()
  end

  test "decoding ReadProperty" do
    assert {:ok,
            %ReadProperty{
              object_identifier: %ObjectIdentifier{
                type: :analog_output,
                instance: 101
              },
              property_identifier: :present_value,
              property_array_index: nil
            }} =
             ReadProperty.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_property,
               parameters: [
                 tagged: {0, <<0, 64, 0, 101>>, 4},
                 tagged: {1, "U", 1}
               ]
             })
  end

  test "decoding ReadProperty invalid unknown tag encoding" do
    assert {:error, :unknown_tag_encoding} =
             ReadProperty.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_property,
               parameters: [
                 tagged: {0, <<>>, 0}
               ]
             })
  end

  test "decoding ReadProperty invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             ReadProperty.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_property,
               parameters: [
                 tagged: {0, <<0, 64, 0, 101>>, 4}
               ]
             })
  end

  test "decoding ReadProperty invalid APDU" do
    assert {:error, :invalid_request} =
             ReadProperty.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property,
               parameters: []
             })
  end

  test "encoding ReadProperty" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :read_property,
              parameters: [
                tagged: {0, <<0, 64, 0, 101>>, 4},
                tagged: {1, "U", 1}
              ]
            }} =
             ReadProperty.to_apdu(
               %ReadProperty{
                 object_identifier: %ObjectIdentifier{
                   type: :analog_output,
                   instance: 101
                 },
                 property_identifier: :present_value,
                 property_array_index: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding ReadProperty with property array index" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :read_property,
              parameters: [
                tagged: {0, <<0, 64, 0, 101>>, 4},
                tagged: {1, "U", 1},
                tagged: {2, <<15>>, 1}
              ]
            }} =
             ReadProperty.to_apdu(
               %ReadProperty{
                 object_identifier: %ObjectIdentifier{
                   type: :analog_output,
                   instance: 101
                 },
                 property_identifier: :present_value,
                 property_array_index: 15
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "protocol implementation get name" do
    assert :read_property ==
             ServicesProtocol.get_name(%ReadProperty{
               object_identifier: %ObjectIdentifier{
                 type: :analog_output,
                 instance: 101
               },
               property_identifier: :present_value,
               property_array_index: 15
             })
  end

  test "protocol implementation is confirmed" do
    assert true ==
             ServicesProtocol.is_confirmed(%ReadProperty{
               object_identifier: %ObjectIdentifier{
                 type: :analog_output,
                 instance: 101
               },
               property_identifier: :present_value,
               property_array_index: 15
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
              service: :read_property,
              parameters: [
                tagged: {0, <<0, 64, 0, 101>>, 4},
                tagged: {1, "U", 1},
                tagged: {2, <<15>>, 1}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %ReadProperty{
                 object_identifier: %ObjectIdentifier{
                   type: :analog_output,
                   instance: 101
                 },
                 property_identifier: :present_value,
                 property_array_index: 15
               },
               invoke_id: 1,
               max_segments: 4
             )
  end
end
