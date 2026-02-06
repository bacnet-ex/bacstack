defmodule BACnet.Test.Protocol.Services.ConfirmedTextMessageTest do
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.Services.ConfirmedTextMessage
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest ConfirmedTextMessage

  test "get name" do
    assert :confirmed_text_message == ConfirmedTextMessage.get_name()
  end

  test "is confirmed" do
    assert true == ConfirmedTextMessage.is_confirmed()
  end

  test "decoding ConfirmedTextMessage" do
    assert {:ok,
            %ConfirmedTextMessage{
              source_device: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 5},
              class: nil,
              priority: :normal,
              message: "PM required for PUMP347"
            }} =
             ConfirmedTextMessage.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_text_message,
               parameters: [
                 tagged: {0, <<2, 0, 0, 5>>, 4},
                 tagged: {2, <<0>>, 1},
                 tagged:
                   {3,
                    <<0, 80, 77, 32, 114, 101, 113, 117, 105, 114, 101, 100, 32, 102, 111, 114,
                      32, 80, 85, 77, 80, 51, 52, 55>>, 24}
               ]
             })
  end

  test "decoding ConfirmedTextMessage with numeric class" do
    assert {:ok,
            %ConfirmedTextMessage{
              source_device: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 5},
              class: 1,
              priority: :normal,
              message: "PM required for PUMP347"
            }} =
             ConfirmedTextMessage.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_text_message,
               parameters: [
                 tagged: {0, <<2, 0, 0, 5>>, 4},
                 constructed: {1, {:tagged, {0, <<1>>, 1}}, 0},
                 tagged: {2, <<0>>, 1},
                 tagged:
                   {3,
                    <<0, 80, 77, 32, 114, 101, 113, 117, 105, 114, 101, 100, 32, 102, 111, 114,
                      32, 80, 85, 77, 80, 51, 52, 55>>, 24}
               ]
             })
  end

  test "decoding ConfirmedTextMessage with string class" do
    assert {:ok,
            %ConfirmedTextMessage{
              source_device: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 5},
              class: "Hello World",
              priority: :urgent,
              message: "PM required for PUMP347"
            }} =
             ConfirmedTextMessage.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_text_message,
               parameters: [
                 tagged: {0, <<2, 0, 0, 5>>, 4},
                 constructed:
                   {1,
                    {:tagged, {1, <<0, 72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100>>, 1}},
                    0},
                 tagged: {2, <<1>>, 1},
                 tagged:
                   {3,
                    <<0, 80, 77, 32, 114, 101, 113, 117, 105, 114, 101, 100, 32, 102, 111, 114,
                      32, 80, 85, 77, 80, 51, 52, 55>>, 24}
               ]
             })
  end

  test "decoding ConfirmedTextMessage invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             ConfirmedTextMessage.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_text_message,
               parameters: [
                 tagged: {0, <<2, 0, 0, 5>>, 4},
                 tagged: {2, <<0>>, 1}
               ]
             })
  end

  test "decoding ConfirmedTextMessage invalid APDU" do
    assert {:error, :invalid_request} =
             ConfirmedTextMessage.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_event_message,
               parameters: []
             })
  end

  test "decoding ConfirmedTextMessage with invalid class" do
    assert {:error, :invalid_request_parameters} =
             ConfirmedTextMessage.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_text_message,
               parameters: [
                 tagged: {0, <<2, 0, 0, 5>>, 4},
                 constructed: {1, nil, 0},
                 tagged: {2, <<0>>, 1},
                 tagged:
                   {3,
                    <<0, 80, 77, 32, 114, 101, 113, 117, 105, 114, 101, 100, 32, 102, 111, 114,
                      32, 80, 85, 77, 80, 51, 52, 55>>, 24}
               ]
             })
  end

  test "encoding ConfirmedTextMessage" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :confirmed_text_message,
              parameters: [
                tagged: {0, <<2, 0, 0, 5>>, 4},
                tagged: {2, <<0>>, 1},
                tagged:
                  {3,
                   <<0, 80, 77, 32, 114, 101, 113, 117, 105, 114, 101, 100, 32, 102, 111, 114, 32,
                     80, 85, 77, 80, 51, 52, 55>>, 24}
              ]
            }} =
             ConfirmedTextMessage.to_apdu(
               %ConfirmedTextMessage{
                 source_device: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 5},
                 class: nil,
                 priority: :normal,
                 message: "PM required for PUMP347"
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding ConfirmedTextMessage with numeric class" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :confirmed_text_message,
              parameters: [
                tagged: {0, <<2, 0, 0, 5>>, 4},
                constructed: {1, {:tagged, {0, <<55>>, 1}}, 0},
                tagged: {2, <<0>>, 1},
                tagged:
                  {3,
                   <<0, 80, 77, 32, 114, 101, 113, 117, 105, 114, 101, 100, 32, 102, 111, 114, 32,
                     80, 85, 77, 80, 51, 52, 55>>, 24}
              ]
            }} =
             ConfirmedTextMessage.to_apdu(
               %ConfirmedTextMessage{
                 source_device: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 5},
                 class: 55,
                 priority: :normal,
                 message: "PM required for PUMP347"
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding ConfirmedTextMessage with string class" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :confirmed_text_message,
              parameters: [
                tagged: {0, <<2, 0, 0, 5>>, 4},
                constructed: {1, {:tagged, {1, <<0, 110, 117, 108, 108>>, 5}}, 0},
                tagged: {2, <<1>>, 1},
                tagged:
                  {3,
                   <<0, 80, 77, 32, 114, 101, 113, 117, 105, 114, 101, 100, 32, 102, 111, 114, 32,
                     80, 85, 77, 80, 51, 52, 55>>, 24}
              ]
            }} =
             ConfirmedTextMessage.to_apdu(
               %ConfirmedTextMessage{
                 source_device: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 5},
                 class: "null",
                 priority: :urgent,
                 message: "PM required for PUMP347"
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "protocol implementation get name" do
    assert :confirmed_text_message ==
             ServicesProtocol.get_name(%ConfirmedTextMessage{
               source_device: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 5},
               class: "null",
               priority: :urgent,
               message: "PM required for PUMP347"
             })
  end

  test "protocol implementation is confirmed" do
    assert true ==
             ServicesProtocol.is_confirmed(%ConfirmedTextMessage{
               source_device: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 5},
               class: "null",
               priority: :urgent,
               message: "PM required for PUMP347"
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
              service: :confirmed_text_message,
              parameters: [
                tagged: {0, <<2, 0, 0, 5>>, 4},
                constructed: {1, {:tagged, {1, <<0, 110, 117, 108, 108>>, 5}}, 0},
                tagged: {2, <<1>>, 1},
                tagged:
                  {3,
                   <<0, 80, 77, 32, 114, 101, 113, 117, 105, 114, 101, 100, 32, 102, 111, 114, 32,
                     80, 85, 77, 80, 51, 52, 55>>, 24}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %ConfirmedTextMessage{
                 source_device: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 5},
                 class: "null",
                 priority: :urgent,
                 message: "PM required for PUMP347"
               },
               invoke_id: 1,
               max_segments: 4
             )
  end
end
