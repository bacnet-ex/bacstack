defmodule BACnet.Test.Protocol.Services.DeleteObjectTest do
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.DeleteObject
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest DeleteObject

  test "get name" do
    assert :delete_object == DeleteObject.get_name()
  end

  test "is confirmed" do
    assert true == DeleteObject.is_confirmed()
  end

  test "decoding DeleteObject" do
    assert {:ok,
            %DeleteObject{
              object_specifier: %ObjectIdentifier{type: :analog_input, instance: 15}
            }} =
             DeleteObject.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :delete_object,
               parameters: [
                 object_identifier: %ObjectIdentifier{type: :analog_input, instance: 15}
               ]
             })
  end

  test "decoding DeleteObject invalid missing pattern" do
    assert {:error, :invalid_request_parameters} ==
             DeleteObject.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :delete_object,
               parameters: []
             })
  end

  test "decoding DeleteObject invalid APDU" do
    assert {:error, :invalid_request} ==
             DeleteObject.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :create_object,
               parameters: []
             })
  end

  test "encoding DeleteObject" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :delete_object,
              parameters: [
                object_identifier: %ObjectIdentifier{type: :analog_input, instance: 15}
              ]
            }} =
             DeleteObject.to_apdu(
               %DeleteObject{
                 object_specifier: %ObjectIdentifier{type: :analog_input, instance: 15}
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "protocol implementation get name" do
    assert :delete_object ==
             ServicesProtocol.get_name(%DeleteObject{
               object_specifier: %ObjectIdentifier{type: :analog_input, instance: 15}
             })
  end

  test "protocol implementation is confirmed" do
    assert true ==
             ServicesProtocol.is_confirmed(%DeleteObject{
               object_specifier: %ObjectIdentifier{type: :analog_input, instance: 15}
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
              service: :delete_object,
              parameters: [
                object_identifier: %ObjectIdentifier{type: :analog_input, instance: 15}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %DeleteObject{
                 object_specifier: %ObjectIdentifier{type: :analog_input, instance: 15}
               },
               invoke_id: 1,
               max_segments: 4
             )
  end
end
