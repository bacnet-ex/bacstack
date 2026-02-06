defmodule BACnet.Test.Protocol.APDU.ConfirmedServiceRequestTest do
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services
  alias BACnet.Stack.EncoderProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu

  doctest ConfirmedServiceRequest

  test "EncoderProtocol expects reply" do
    assert true ==
             EncoderProtocol.expects_reply(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :acknowledge_alarm,
               parameters: [
                 {:tagged, {0, <<0, 0, 53, 12>>, 4}},
                 {:tagged, {1, <<2, 0, 53, 12>>, 4}},
                 {:tagged, {2, <<0>>, 1}},
                 {:constructed, {3, {:tagged, {0, <<2, 12, 49, 0>>, 4}}, 0}},
                 {:tagged, {4, "\0Hello World", 12}},
                 {:constructed, {5, {:tagged, {0, <<5, 19, 11, 15>>, 4}}, 0}}
               ]
             })
  end

  test "EncoderProtocol is request" do
    assert true ==
             EncoderProtocol.is_request(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :acknowledge_alarm,
               parameters: [
                 {:tagged, {0, <<0, 0, 53, 12>>, 4}},
                 {:tagged, {1, <<2, 0, 53, 12>>, 4}},
                 {:tagged, {2, <<0>>, 1}},
                 {:constructed, {3, {:tagged, {0, <<2, 12, 49, 0>>, 4}}, 0}},
                 {:tagged, {4, "\0Hello World", 12}},
                 {:constructed, {5, {:tagged, {0, <<5, 19, 11, 15>>, 4}}, 0}}
               ]
             })
  end

  test "EncoderProtocol is response" do
    assert false ==
             EncoderProtocol.is_response(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :acknowledge_alarm,
               parameters: [
                 {:tagged, {0, <<0, 0, 53, 12>>, 4}},
                 {:tagged, {1, <<2, 0, 53, 12>>, 4}},
                 {:tagged, {2, <<0>>, 1}},
                 {:constructed, {3, {:tagged, {0, <<2, 12, 49, 0>>, 4}}, 0}},
                 {:tagged, {4, "\0Hello World", 12}},
                 {:constructed, {5, {:tagged, {0, <<5, 19, 11, 15>>, 4}}, 0}}
               ]
             })
  end

  @tag :service
  test "APDU to service AcknowledgeAlarm" do
    assert {:ok, %Services.AcknowledgeAlarm{}} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :acknowledge_alarm,
               parameters: [
                 {:tagged, {0, <<0, 0, 53, 12>>, 4}},
                 {:tagged, {1, <<2, 0, 53, 12>>, 4}},
                 {:tagged, {2, <<0>>, 1}},
                 {:constructed, {3, {:tagged, {0, <<2, 12, 49, 0>>, 4}}, 0}},
                 {:tagged, {4, "\0Hello World", 12}},
                 {:constructed, {5, {:tagged, {0, <<5, 19, 11, 15>>, 4}}, 0}}
               ]
             })
  end

  @tag :service
  test "APDU to service AddListElement" do
    assert {:ok, %Services.AddListElement{}} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :add_list_element,
               parameters: [
                 tagged: {0, <<2, 192, 0, 3>>, 4},
                 tagged: {1, "5", 1},
                 constructed:
                   {3,
                    [
                      tagged: {0, <<0, 0, 0, 15>>, 4},
                      constructed: {1, [tagged: {0, "U", 1}, tagged: {0, "g", 1}], 0}
                    ], 0}
               ]
             })
  end

  @tag :service
  test "APDU to service AtomicReadFile" do
    assert {:ok, %Services.AtomicReadFile{}} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :atomic_read_file,
               parameters: [
                 object_identifier: %ObjectIdentifier{
                   instance: 550,
                   type: :file
                 },
                 constructed: {0, [signed_integer: 0, unsigned_integer: 440], 0}
               ]
             })
  end

  @tag :service
  test "APDU to service AtomicWriteFile" do
    assert {:ok, %Services.AtomicWriteFile{}} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :atomic_write_file,
               parameters: [
                 object_identifier: %ObjectIdentifier{
                   instance: 0,
                   type: :file
                 },
                 constructed:
                   {0,
                    [
                      signed_integer: 0,
                      octet_string: "hello world"
                    ], 0}
               ]
             })
  end

  @tag :service
  test "APDU to service ConfirmedCovNotification" do
    assert {:ok, %Services.ConfirmedCovNotification{}} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_cov_notification,
               parameters: [
                 tagged: {0, "c", 1},
                 tagged: {1, <<2, 1, 79, 241>>, 4},
                 tagged: {2, <<0, 192, 0, 102>>, 4},
                 tagged: {3, <<30>>, 1},
                 constructed:
                   {4,
                    [
                      tagged: {0, "U", 1},
                      constructed: {2, {:enumerated, 0}, 0},
                      tagged: {0, "o", 1},
                      constructed: {2, {:bitstring, {4, {false, false, false, false}}}, 0}
                    ], 0}
               ]
             })
  end

  @tag :service
  test "APDU to service ConfirmedEventNotification" do
    assert {:ok, %Services.ConfirmedEventNotification{}} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_event_notification,
               parameters: [
                 tagged: {0, "{", 1},
                 tagged: {1, <<2, 15, 226, 104>>, 4},
                 tagged: {2, <<0, 45, 198, 208>>, 4},
                 constructed: {3, {:tagged, {0, <<2, 12, 49, 0>>, 4}}, 0},
                 tagged: {4, <<1>>, 1},
                 tagged: {5, <<200>>, 1},
                 tagged: {6, <<6>>, 1},
                 tagged: {8, <<0>>, 1},
                 tagged: {9, <<1>>, 1},
                 tagged: {10, <<3>>, 1},
                 tagged: {11, <<0>>, 1},
                 constructed:
                   {12,
                    {:constructed,
                     {6,
                      [
                        tagged: {0, "U", 1},
                        constructed: {2, {:real, 1.0}, 0},
                        tagged: {3, "\a", 1}
                      ], 0}}, 0}
               ]
             })
  end

  @tag :service
  test "APDU to service ConfirmedPrivateTransfer" do
    assert {:ok, %Services.ConfirmedPrivateTransfer{}} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_private_transfer,
               parameters: [
                 tagged: {0, <<25>>, 1},
                 tagged: {1, "\b", 1},
                 constructed: {2, [real: 72.4, octet_string: <<22, 73>>], 0}
               ]
             })
  end

  @tag :service
  test "APDU to service ConfirmedTextMessage" do
    assert {:ok, %Services.ConfirmedTextMessage{}} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
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

  @tag :service
  test "APDU to service CreateObject" do
    assert {:ok, %Services.CreateObject{}} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :create_object,
               parameters: [
                 constructed: {0, {:tagged, {0, "\n", 1}}, 0},
                 constructed:
                   {1,
                    [
                      tagged: {0, "M", 1},
                      constructed: {2, {:character_string, "Trend 1"}, 0},
                      tagged: {0, ")", 1},
                      constructed: {2, {:enumerated, 0}, 0}
                    ], 0}
               ]
             })
  end

  @tag :service
  test "APDU to service DeleteObject" do
    assert {:ok, %Services.DeleteObject{}} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :delete_object,
               parameters: [
                 object_identifier: %ObjectIdentifier{type: :binary_input, instance: 153_545}
               ]
             })
  end

  @tag :service
  test "APDU to service DeviceCommunicationControl" do
    assert {:ok, %Services.DeviceCommunicationControl{}} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :device_communication_control,
               parameters: [
                 tagged: {1, <<1>>, 1}
               ]
             })
  end

  @tag :service
  test "APDU to service GetAlarmSummary" do
    assert {:ok, %Services.GetAlarmSummary{}} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_alarm_summary,
               parameters: []
             })
  end

  @tag :service
  test "APDU to service GetEnrollmentSummary" do
    assert {:ok, %Services.GetEnrollmentSummary{}} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_enrollment_summary,
               parameters: [tagged: {0, <<2>>, 1}]
             })
  end

  @tag :service
  test "APDU to service GetEventInformation" do
    assert {:ok, %Services.GetEventInformation{}} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_event_information,
               parameters: [tagged: {0, <<1, 1, 0, 15>>, 4}]
             })
  end

  @tag :service
  test "APDU to service LifeSafetyOperation" do
    assert {:ok, %Services.LifeSafetyOperation{}} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :life_safety_operation,
               parameters: [
                 tagged: {0, <<18>>, 1},
                 tagged: {1, <<0, 77, 68, 76>>, 4},
                 tagged: {2, <<4>>, 1},
                 tagged: {3, <<5, 64, 0, 1>>, 4}
               ]
             })
  end

  @tag :service
  test "APDU to service ReadPropertyMultiple" do
    assert {:ok, %Services.ReadPropertyMultiple{}} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_property_multiple,
               parameters: [
                 tagged: {0, <<0, 0, 0, 16>>, 4},
                 constructed: {1, [tagged: {0, "U", 1}, tagged: {0, "g", 1}], 0}
               ]
             })
  end

  @tag :service
  test "APDU to service ReadProperty" do
    assert {:ok, %Services.ReadProperty{}} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
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

  @tag :service
  test "APDU to service ReadRange" do
    assert {:ok, %Services.ReadRange{}} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               parameters: [
                 tagged: {0, <<5, 0, 0, 1>>, 4},
                 tagged: {1, <<131>>, 1}
               ]
             })
  end

  @tag :service
  test "APDU to service ReinitializeDevice" do
    assert {:ok, %Services.ReinitializeDevice{}} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :reinitialize_device,
               parameters: [
                 tagged: {0, <<0>>, 1}
               ]
             })
  end

  @tag :service
  test "APDU to service RemoveListElement" do
    assert {:ok, %Services.RemoveListElement{}} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :remove_list_element,
               parameters: [
                 tagged: {0, <<2, 192, 0, 3>>, 4},
                 tagged: {1, "5", 1},
                 constructed:
                   {3,
                    [
                      tagged: {0, <<0, 0, 0, 12>>, 4},
                      constructed:
                        {1,
                         [
                           tagged: {0, "U", 1},
                           tagged: {0, "g", 1},
                           tagged: {0, <<28>>, 1}
                         ], 0},
                      tagged: {0, <<0, 0, 0, 13>>, 4},
                      constructed:
                        {1,
                         [
                           tagged: {0, "U", 1},
                           tagged: {0, "g", 1},
                           tagged: {0, <<28>>, 1}
                         ], 0}
                    ], 0}
               ]
             })
  end

  @tag :service
  test "APDU to service WriteProperty" do
    assert {:ok, %Services.WriteProperty{}} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
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

  @tag :service
  test "APDU to service WritePropertyMultiple" do
    assert {:ok, %Services.WritePropertyMultiple{}} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property_multiple,
               parameters: [
                 tagged: {0, <<0, 128, 0, 5>>, 4},
                 constructed: {1, [tagged: {0, "U", 1}, constructed: {2, {:real, 67.0}, 0}], 0},
                 tagged: {0, <<0, 128, 0, 6>>, 4},
                 constructed: {1, [tagged: {0, "U", 1}, constructed: {2, {:real, 67.0}, 0}], 0},
                 tagged: {0, <<0, 128, 0, 7>>, 4},
                 constructed: {1, [tagged: {0, "U", 1}, constructed: {2, {:real, 72.0}, 0}], 0}
               ]
             })
  end
end
