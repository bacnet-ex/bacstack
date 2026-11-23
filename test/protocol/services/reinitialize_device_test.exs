defmodule BACnet.Test.Protocol.Services.ReinitializeDeviceTest do
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol
  alias BACnet.Protocol.Services.ReinitializeDevice

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest ReinitializeDevice

  test "get name" do
    assert :reinitialize_device == ReinitializeDevice.get_name()
  end

  test "is confirmed" do
    assert true == ReinitializeDevice.confirmed?()
  end

  test "decoding ReinitializeDevice" do
    assert {:ok,
            %ReinitializeDevice{
              reinitialized_state: :warmstart,
              password: "AbCdEfGh"
            }} =
             ReinitializeDevice.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :reinitialize_device,
               parameters: [
                 tagged: {0, <<1>>, 1},
                 tagged: {1, <<0, 65, 98, 67, 100, 69, 102, 71, 104>>, 9}
               ]
             })
  end

  test "decoding ReinitializeDevice without password" do
    assert {:ok,
            %ReinitializeDevice{
              reinitialized_state: :coldstart,
              password: nil
            }} =
             ReinitializeDevice.from_apdu(%ConfirmedServiceRequest{
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

  test "decoding ReinitializeDevice rejects an empty password" do
    assert {:error, :invalid_empty_password} =
             ReinitializeDevice.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :reinitialize_device,
               parameters: [
                 tagged: {0, <<1>>, 1},
                 tagged: {1, <<0>>, 1}
               ]
             })
  end

  test "decoding ReinitializeDevice rejects a password with 21 characters" do
    assert {:error, :password_too_long} =
             ReinitializeDevice.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :reinitialize_device,
               parameters: [
                 tagged: {0, <<1>>, 1},
                 tagged: {1, <<0, "abcdefghijklmnopqrstu">>, 22}
               ]
             })
  end

  test "decoding ReinitializeDevice rejects invalid UTF-8 in the password" do
    assert {:error, :invalid_password} =
             ReinitializeDevice.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :reinitialize_device,
               parameters: [
                 tagged: {0, <<1>>, 1},
                 tagged: {1, <<0, 255>>, 2}
               ]
             })
  end

  test "decoding ReinitializeDevice invalid unknown tag encoding" do
    assert {:error, :unknown_tag_encoding} =
             ReinitializeDevice.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :reinitialize_device,
               parameters: [
                 tagged: {0, <<>>, 0}
               ]
             })
  end

  test "decoding ReinitializeDevice invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             ReinitializeDevice.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :reinitialize_device,
               parameters: []
             })
  end

  test "decoding ReinitializeDevice invalid APDU" do
    assert {:error, :invalid_request} =
             ReinitializeDevice.from_apdu(%ConfirmedServiceRequest{
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

  test "decoding ReinitializeDevice unknown state" do
    assert {:error, {:unknown_reinitialized_state, 255}} =
             ReinitializeDevice.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :reinitialize_device,
               parameters: [
                 tagged: {0, <<255>>, 1},
                 tagged: {1, <<0, 65, 98, 67, 100, 69, 102, 71, 104>>, 9}
               ]
             })
  end

  test "encoding ReinitializeDevice" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :reinitialize_device,
              parameters: [
                tagged: {0, <<1>>, 1},
                tagged: {1, <<0, 65, 98, 67, 100, 69, 102, 71, 104>>, 9}
              ]
            }} =
             ReinitializeDevice.to_apdu(
               %ReinitializeDevice{
                 reinitialized_state: :warmstart,
                 password: "AbCdEfGh"
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding ReinitializeDevice without password" do
    assert {:ok,
            %ConfirmedServiceRequest{
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
            }} =
             ReinitializeDevice.to_apdu(
               %ReinitializeDevice{
                 reinitialized_state: :coldstart,
                 password: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding ReinitializeDevice accepts a password with 20 multibyte characters" do
    password = String.duplicate("ä", 20)
    encoded_password = <<0, password::binary>>

    assert {:ok,
            %ConfirmedServiceRequest{
              parameters: [tagged: {0, <<1>>, 1}, tagged: {1, ^encoded_password, 41}]
            }} =
             ReinitializeDevice.to_apdu(
               %ReinitializeDevice{reinitialized_state: :warmstart, password: password},
               []
             )
  end

  test "encoding ReinitializeDevice rejects an empty password" do
    assert {:error, :invalid_empty_password} =
             ReinitializeDevice.to_apdu(
               %ReinitializeDevice{reinitialized_state: :warmstart, password: ""},
               []
             )
  end

  test "encoding ReinitializeDevice rejects invalid UTF-8 in the password" do
    assert {:error, :invalid_password} =
             ReinitializeDevice.to_apdu(
               %ReinitializeDevice{reinitialized_state: :warmstart, password: <<255>>},
               []
             )
  end

  test "encoding ReinitializeDevice rejects an invalid password type" do
    assert_raise ArgumentError, fn ->
      ReinitializeDevice.to_apdu(
        %ReinitializeDevice{reinitialized_state: :warmstart, password: :hello},
        []
      )
    end
  end

  test "encoding ReinitializeDevice unknown state" do
    assert {:error, {:unknown_reinitialized_state, :hello_there}}

    ReinitializeDevice.to_apdu(
      %ReinitializeDevice{
        reinitialized_state: :hello_there,
        password: "AbCdEfGh"
      },
      invoke_id: 1,
      max_segments: 4
    )
  end

  test "encoding ReinitializeDevice preserves segmented_response_accepted=false" do
    service = %ReinitializeDevice{
      reinitialized_state: :warmstart,
      password: nil
    }

    assert {:ok, %ConfirmedServiceRequest{segmented_response_accepted: false} = apdu} =
             ReinitializeDevice.to_apdu(service, segmented_response_accepted: false)

    assert {:ok, ^apdu} =
             ServicesProtocol.to_apdu(service, segmented_response_accepted: false)
  end

  test "protocol implementation get name" do
    assert :reinitialize_device ==
             ServicesProtocol.get_name(%ReinitializeDevice{
               reinitialized_state: :coldstart,
               password: nil
             })
  end

  test "protocol implementation is confirmed" do
    assert true ==
             ServicesProtocol.confirmed?(%ReinitializeDevice{
               reinitialized_state: :coldstart,
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
              service: :reinitialize_device,
              parameters: [
                tagged: {0, <<0>>, 1}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %ReinitializeDevice{
                 reinitialized_state: :coldstart,
                 password: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end
end
