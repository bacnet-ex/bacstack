defmodule BACnet.Test.Protocol.APDU.ConfirmedServiceRequestTest do
  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.IncompleteAPDU
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.PropertyRef
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
             EncoderProtocol.request?(%ConfirmedServiceRequest{
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
             EncoderProtocol.response?(%ConfirmedServiceRequest{
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
  test "APDU to service SubscribeCov" do
    assert {:ok,
            %Services.SubscribeCov{
              process_identifier: 18,
              monitored_object: %ObjectIdentifier{type: :analog_input, instance: 10},
              issue_confirmed_notifications: true,
              lifetime: 0
            }} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :subscribe_cov,
               parameters: [
                 tagged: {0, <<18>>, 1},
                 tagged: {1, <<0, 0, 0, 10>>, 4},
                 tagged: {2, <<1>>, 1},
                 tagged: {3, <<0>>, 1}
               ]
             })
  end

  @tag :service
  test "APDU to service SubscribeCovProperty" do
    assert {:ok,
            %Services.SubscribeCovProperty{
              process_identifier: 18,
              monitored_object: %ObjectIdentifier{type: :analog_input, instance: 10},
              issue_confirmed_notifications: true,
              lifetime: 60,
              monitored_property: %PropertyRef{
                property_identifier: :present_value,
                property_array_index: nil
              },
              cov_increment: 1.0
            }} =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :subscribe_cov_property,
               parameters: [
                 tagged: {0, <<18>>, 1},
                 tagged: {1, <<0, 0, 0, 10>>, 4},
                 tagged: {2, <<1>>, 1},
                 tagged: {3, "<", 1},
                 constructed: {4, {:tagged, {0, "U", 1}}, 0},
                 tagged: {5, <<63, 128, 0, 0>>, 4}
               ]
             })
  end

  @tag :service
  test "APDU to service is not supported for an unknown service" do
    assert :not_supported =
             ConfirmedServiceRequest.to_service(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 480,
               max_segments: :unspecified,
               invoke_id: 35,
               sequence_number: nil,
               proposed_window_size: nil,
               service: 250,
               parameters: []
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

  test "EncoderProtocol supports segmentation" do
    assert true ==
             EncoderProtocol.supports_segmentation(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :acknowledge_alarm,
               parameters: []
             })
  end

  test "encode returns the encoded request or the encoder error" do
    request = %ConfirmedServiceRequest{
      segmented_response_accepted: true,
      max_apdu: 480,
      max_segments: :unspecified,
      invoke_id: 35,
      sequence_number: nil,
      proposed_window_size: nil,
      service: :read_property,
      parameters: []
    }

    assert {:ok, iodata} = ConfirmedServiceRequest.encode(request)
    assert is_binary(IO.iodata_to_binary(iodata))

    assert {:error, %ArgumentError{message: message}} =
             ConfirmedServiceRequest.encode(%{request | invoke_id: -1})

    assert message =~ "Invoke ID"
  end

  test "EncoderProtocol encodes limits" do
    request = %ConfirmedServiceRequest{
      segmented_response_accepted: true,
      max_apdu: 1476,
      max_segments: :unspecified,
      invoke_id: 35,
      sequence_number: nil,
      proposed_window_size: nil,
      service: :read_property,
      parameters: [tagged: {0, <<0, 0, 0, 1>>, 4}, tagged: {1, "P", 1}]
    }

    assert raw(request) == <<2, 5, 35, 12, 12, 0, 0, 0, 1, 25, 80>>

    assert {:ok, decoded} = APDU.decode(raw(request))
    assert decoded.invoke_id == 35
    assert decoded.service == :read_property
    assert decoded.max_apdu == 1476
    assert decoded.max_segments == :unspecified
    assert decoded.segmented_response_accepted == true
    assert decoded.sequence_number == nil
    assert decoded.proposed_window_size == nil

    plain = %ConfirmedServiceRequest{
      segmented_response_accepted: true,
      max_apdu: 480,
      max_segments: :unspecified,
      invoke_id: 35,
      sequence_number: nil,
      proposed_window_size: nil,
      service: :read_property,
      parameters: []
    }

    refused = %{plain | segmented_response_accepted: false, max_apdu: 50, max_segments: 2}
    assert {:ok, decoded} = APDU.decode(raw(refused))
    assert decoded.segmented_response_accepted == false
    assert decoded.max_apdu == 50
    assert decoded.max_segments == 2

    for max_segments <- [2, 4, 8, 16, 32, 64, :more_than_64, :unspecified] do
      apdu = %{plain | max_segments: max_segments}
      assert {:ok, decoded} = APDU.decode(raw(apdu))
      assert decoded.max_segments == max_segments
    end

    for max_apdu <- [50, 128, 206, 480, 1024, 1476] do
      apdu = %{plain | max_apdu: max_apdu}
      assert {:ok, decoded} = APDU.decode(raw(apdu))
      assert decoded.max_apdu == max_apdu
    end

    service = Constants.by_name!(:confirmed_service_choice, :read_property)
    assert raw(%{plain | service: service}) == raw(plain)

    numbered = %{plain | invoke_id: 255, service: 250}
    assert {:ok, decoded} = APDU.decode(raw(numbered))
    assert decoded.invoke_id == 255
    assert decoded.service == 250
    assert decoded.parameters == []

    assert raw(plain) ==
             raw(%{plain | sequence_number: 0, proposed_window_size: 127})

    assert_raise RuntimeError, ~r/Unable to encode parameters in confirmed/, fn ->
      EncoderProtocol.encode(%{plain | parameters: [{:constructed, :bad}]})
    end
  end

  test "EncoderProtocol rejects inconsistent segmentation fields" do
    request = %ConfirmedServiceRequest{
      segmented_response_accepted: true,
      max_apdu: 480,
      max_segments: :unspecified,
      invoke_id: 35,
      sequence_number: nil,
      proposed_window_size: nil,
      service: :read_property,
      parameters: []
    }

    assert_raise ArgumentError, ~r/Invoke ID/, fn ->
      EncoderProtocol.encode(%{request | invoke_id: -1})
    end

    assert_raise ArgumentError, ~r/Sequence number must be nil/, fn ->
      EncoderProtocol.encode(%{request | sequence_number: -1, proposed_window_size: 1})
    end

    assert_raise ArgumentError, ~r/Sequence number must be nil/, fn ->
      EncoderProtocol.encode(%{request | sequence_number: 256, proposed_window_size: 1})
    end

    assert_raise ArgumentError, ~r/Proposed window size/, fn ->
      EncoderProtocol.encode(%{request | sequence_number: 0, proposed_window_size: 0})
    end

    assert_raise ArgumentError, ~r/Proposed window size/, fn ->
      EncoderProtocol.encode(%{request | sequence_number: 0, proposed_window_size: 128})
    end

    assert_raise ArgumentError, ~r/both be nil or an integer/, fn ->
      EncoderProtocol.encode(%{request | sequence_number: nil, proposed_window_size: 1})
    end

    assert_raise ArgumentError, ~r/both be nil or an integer/, fn ->
      EncoderProtocol.encode(%{request | sequence_number: 0, proposed_window_size: nil})
    end
  end

  test "EncoderProtocol segments a payload and rejects a short maximum" do
    empty = %ConfirmedServiceRequest{
      segmented_response_accepted: true,
      max_apdu: 480,
      max_segments: :unspecified,
      invoke_id: 35,
      sequence_number: 0,
      proposed_window_size: 1,
      service: :read_property,
      parameters: []
    }

    assert [segment] = EncoderProtocol.encode_segmented(empty, 50)
    assert {:ok, decoded} = APDU.decode(IO.iodata_to_binary(segment))
    assert decoded.invoke_id == empty.invoke_id
    assert decoded.service == :read_property
    assert decoded.parameters == []
    assert decoded.sequence_number == nil
    assert decoded.proposed_window_size == nil
    assert EncoderProtocol.encode_to_segmented(empty, segment, 50) == []

    request = %ConfirmedServiceRequest{
      segmented_response_accepted: false,
      max_apdu: 480,
      max_segments: :unspecified,
      invoke_id: 35,
      sequence_number: 9,
      proposed_window_size: 4,
      service: :read_property,
      parameters: [unsigned_integer: 1, unsigned_integer: 2]
    }

    segments = assert_split(request, 4, 7)
    assert [0, 1 | _rest] = Enum.map(segments, &sequence_number/1)

    assert_raise ArgumentError, ~r/segmented header size of 6/, fn ->
      EncoderProtocol.encode_segmented(request, 6)
    end
  end

  defp assert_split(apdu, header_size, apdu_size) do
    full = raw(apdu)
    payload = binary_part(full, header_size, byte_size(full) - header_size)
    assert byte_size(payload) > 1

    segments = EncoderProtocol.encode_segmented(apdu, apdu_size)
    header = binary_part(full, 0, header_size)

    assert segments ==
             EncoderProtocol.encode_to_segmented(apdu, [header, payload], apdu_size)

    payload_limit = apdu_size - header_size - 2

    assert length(segments) ==
             div(byte_size(payload) + payload_limit - 1, payload_limit)

    joined =
      segments
      |> Enum.with_index()
      |> Enum.map(fn {segment, index} ->
        assert {:incomplete, %IncompleteAPDU{} = incomplete} =
                 APDU.decode(IO.iodata_to_binary(segment))

        assert incomplete.sequence_number == index
        assert incomplete.window_size == apdu.proposed_window_size
        assert incomplete.invoke_id == apdu.invoke_id
        assert incomplete.more_follows == index < length(segments) - 1
        assert :binary.last(incomplete.header) == service_byte(apdu.service)
        incomplete.data
      end)
      |> IO.iodata_to_binary()

    assert joined == payload
    segments
  end

  defp sequence_number(segment) do
    assert {:incomplete, %IncompleteAPDU{sequence_number: sequence_number}} =
             APDU.decode(IO.iodata_to_binary(segment))

    sequence_number
  end

  defp service_byte(service) when is_atom(service) do
    Constants.by_name!(:confirmed_service_choice, service)
  end

  defp service_byte(service) when is_integer(service), do: service

  defp raw(apdu), do: IO.iodata_to_binary(EncoderProtocol.encode(apdu))
end
