defmodule BACnet.Test.Protocol.Services.DeviceCommunicationControlTest do
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.Services.DeviceCommunicationControl
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest DeviceCommunicationControl

  test "get name" do
    assert :device_communication_control == DeviceCommunicationControl.get_name()
  end

  test "is confirmed" do
    assert true == DeviceCommunicationControl.is_confirmed()
  end

  test "decoding DeviceCommunicationControl" do
    assert {:ok,
            %DeviceCommunicationControl{
              state: :disable,
              time_duration: 5,
              password: "#egbdf!"
            }} =
             DeviceCommunicationControl.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :device_communication_control,
               parameters: [
                 tagged: {0, <<5>>, 1},
                 tagged: {1, <<1>>, 1},
                 tagged: {2, <<0, 35, 101, 103, 98, 100, 102, 33>>, 8}
               ]
             })
  end

  test "decoding DeviceCommunicationControl without optionals" do
    assert {:ok,
            %DeviceCommunicationControl{
              state: :disable,
              time_duration: nil,
              password: nil
            }} =
             DeviceCommunicationControl.from_apdu(%ConfirmedServiceRequest{
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

  test "decoding DeviceCommunicationControl without password" do
    assert {:ok,
            %DeviceCommunicationControl{
              state: :disable_initiation,
              time_duration: 5,
              password: nil
            }} =
             DeviceCommunicationControl.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :device_communication_control,
               parameters: [
                 tagged: {0, <<5>>, 1},
                 tagged: {1, <<2>>, 1}
               ]
             })
  end

  test "decoding DeviceCommunicationControl without time duration" do
    assert {:ok,
            %DeviceCommunicationControl{
              state: :enable,
              time_duration: nil,
              password: "#egbdf!"
            }} =
             DeviceCommunicationControl.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :device_communication_control,
               parameters: [
                 tagged: {1, <<0>>, 1},
                 tagged: {2, <<0, 35, 101, 103, 98, 100, 102, 33>>, 8}
               ]
             })
  end

  test "decoding DeviceCommunicationControl invalid data" do
    assert {:error, :unknown_character_string_encoding} =
             DeviceCommunicationControl.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :device_communication_control,
               parameters: [
                 tagged: {0, <<5>>, 1},
                 tagged: {1, <<1>>, 1},
                 tagged: {2, <<255>>, 1}
               ]
             })
  end

  test "decoding DeviceCommunicationControl invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             DeviceCommunicationControl.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :device_communication_control,
               parameters: [
                 tagged: {0, <<5>>, 1},
                 tagged: {2, <<0, 35, 101, 103, 98, 100, 102, 33>>, 8}
               ]
             })
  end

  test "decoding DeviceCommunicationControl invalid time duration" do
    assert {:error, :invalid_time_duration_value} =
             DeviceCommunicationControl.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :device_communication_control,
               parameters: [
                 tagged: {0, <<255, 255, 255>>, 3},
                 tagged: {1, <<2>>, 1}
               ]
             })
  end

  test "decoding DeviceCommunicationControl invalid APDU" do
    assert {:error, :invalid_request} =
             DeviceCommunicationControl.from_apdu(%ConfirmedServiceRequest{
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

  test "decoding DeviceCommunicationControl unknown state" do
    assert {:error, {:unknown_state, 255}} =
             DeviceCommunicationControl.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :device_communication_control,
               parameters: [
                 tagged: {1, <<255>>, 1}
               ]
             })
  end

  test "encoding DeviceCommunicationControl" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :device_communication_control,
              parameters: [
                tagged: {0, <<5>>, 1},
                tagged: {1, <<1>>, 1},
                tagged: {2, <<0, 35, 101, 103, 98, 100, 102, 33>>, 8}
              ]
            }} =
             DeviceCommunicationControl.to_apdu(
               %DeviceCommunicationControl{
                 state: :disable,
                 time_duration: 5,
                 password: "#egbdf!"
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding DeviceCommunicationControl without optionals" do
    assert {:ok,
            %ConfirmedServiceRequest{
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
            }} =
             DeviceCommunicationControl.to_apdu(
               %DeviceCommunicationControl{
                 state: :disable,
                 time_duration: nil,
                 password: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding DeviceCommunicationControl without time duration" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :device_communication_control,
              parameters: [
                tagged: {1, <<1>>, 1},
                tagged: {2, <<0, 35, 101, 103, 98, 100, 102, 33>>, 8}
              ]
            }} =
             DeviceCommunicationControl.to_apdu(
               %DeviceCommunicationControl{
                 state: :disable,
                 time_duration: nil,
                 password: "#egbdf!"
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding DeviceCommunicationControl without password" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :device_communication_control,
              parameters: [
                tagged: {0, <<5>>, 1},
                tagged: {1, <<1>>, 1}
              ]
            }} =
             DeviceCommunicationControl.to_apdu(
               %DeviceCommunicationControl{
                 state: :disable,
                 time_duration: 5,
                 password: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding DeviceCommunicationControl invalid password length" do
    assert {:error, :password_too_long} =
             DeviceCommunicationControl.to_apdu(
               %DeviceCommunicationControl{
                 state: :disable,
                 time_duration: nil,
                 password: "abcdefghijklmnopqrstuvwxyz"
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding DeviceCommunicationControl invalid password UTF-8 string" do
    assert {:error, :invalid_password} =
             DeviceCommunicationControl.to_apdu(
               %DeviceCommunicationControl{
                 state: :disable,
                 time_duration: nil,
                 password: <<255>>
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding DeviceCommunicationControl invalid password type" do
    assert {:error, :invalid_password} =
             DeviceCommunicationControl.to_apdu(
               %DeviceCommunicationControl{
                 state: :disable,
                 time_duration: nil,
                 password: :hello
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding DeviceCommunicationControl unknown state" do
    assert {:error, {:unknown_state, :hello_there}} =
             DeviceCommunicationControl.to_apdu(
               %DeviceCommunicationControl{
                 state: :hello_there,
                 time_duration: nil,
                 password: nil
               },
               invoke_id: 1,
               max_segments: 4
             )

    assert {:error, {:unknown_state, 255}} =
             DeviceCommunicationControl.to_apdu(
               %DeviceCommunicationControl{
                 state: 255,
                 time_duration: nil,
                 password: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding DeviceCommunicationControl invalid time duration" do
    assert {:error, :invalid_time_duration_value} =
             DeviceCommunicationControl.to_apdu(
               %DeviceCommunicationControl{
                 state: :disable,
                 time_duration: 53_534_423,
                 password: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "protocol implementation get name" do
    assert :device_communication_control =
             ServicesProtocol.get_name(%DeviceCommunicationControl{
               state: :disable,
               time_duration: nil,
               password: nil
             })
  end

  test "protocol implementation is confirmed" do
    assert true ==
             ServicesProtocol.is_confirmed(%DeviceCommunicationControl{
               state: :disable,
               time_duration: nil,
               password: nil
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
              service: :device_communication_control,
              parameters: [
                tagged: {1, <<1>>, 1}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %DeviceCommunicationControl{
                 state: :disable,
                 time_duration: nil,
                 password: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end
end
