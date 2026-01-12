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
    assert true == ReinitializeDevice.is_confirmed()
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

  test "protocol implementation get name" do
    assert :reinitialize_device ==
             ServicesProtocol.get_name(%ReinitializeDevice{
               reinitialized_state: :coldstart,
               password: nil
             })
  end

  test "protocol implementation is confirmed" do
    assert true ==
             ServicesProtocol.is_confirmed(%ReinitializeDevice{
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
