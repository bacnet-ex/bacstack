defmodule BACnet.Test.Protocol.Services.GetEventInformationTest do
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.GetEventInformation
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest GetEventInformation

  test "get name" do
    assert :get_event_information == GetEventInformation.get_name()
  end

  test "is confirmed" do
    assert true == GetEventInformation.is_confirmed()
  end

  test "decoding GetEventInformation" do
    assert {:ok,
            %GetEventInformation{
              last_received_object_identifier: %ObjectIdentifier{
                type: :binary_output,
                instance: 65_551
              }
            }} =
             GetEventInformation.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_event_information,
               parameters: [
                 tagged: {0, <<1, 1, 0, 15>>, 4}
               ]
             })
  end

  test "decoding GetEventInformation optional" do
    assert {:ok,
            %GetEventInformation{
              last_received_object_identifier: nil
            }} =
             GetEventInformation.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_event_information,
               parameters: []
             })
  end

  test "decoding GetEventInformation invalid unknown tag encoding" do
    assert {:error, :unknown_tag_encoding} =
             GetEventInformation.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_event_information,
               parameters: [
                 tagged: {0, <<>>, 0}
               ]
             })
  end

  test "decoding GetEventInformation invalid APDU" do
    assert {:error, :invalid_request} =
             GetEventInformation.from_apdu(%ConfirmedServiceRequest{
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

  test "encoding GetEventInformation" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :get_event_information,
              parameters: [tagged: {0, <<0, 0, 0, 15>>, 4}]
            }} =
             GetEventInformation.to_apdu(
               %GetEventInformation{
                 last_received_object_identifier: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 15
                 }
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding GetEventInformation optional" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :get_event_information,
              parameters: []
            }} =
             GetEventInformation.to_apdu(
               %GetEventInformation{
                 last_received_object_identifier: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "protocol implementation get name" do
    assert :get_event_information ==
             ServicesProtocol.get_name(%GetEventInformation{
               last_received_object_identifier: nil
             })
  end

  test "protocol implementation is confirmed" do
    assert true ==
             ServicesProtocol.is_confirmed(%GetEventInformation{
               last_received_object_identifier: nil
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
              service: :get_event_information,
              parameters: []
            }} =
             ServicesProtocol.to_apdu(
               %GetEventInformation{
                 last_received_object_identifier: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end
end
