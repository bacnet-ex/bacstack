defmodule BACnet.Test.Protocol.Services.ConfirmedPrivateTransferAckTest do
  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.APDU.SimpleACK
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.Services.Ack.ConfirmedPrivateTransferAck

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service
  @moduletag :service_ack

  doctest ConfirmedPrivateTransferAck

  test "decoding ConfirmedPrivateTransferAck" do
    assert {:ok,
            %ConfirmedPrivateTransferAck{
              vendor_id: 25,
              service_number: 8,
              result: [
                %Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :real,
                  value: 1.0
                }
              ]
            }} ==
             ConfirmedPrivateTransferAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_private_transfer,
               payload: [
                 tagged: {0, <<25>>, 1},
                 tagged: {1, "\b", 1},
                 constructed: {2, {:real, 1.0}, 0}
               ]
             })
  end

  test "decoding ConfirmedPrivateTransferAck without results" do
    assert {:ok,
            %ConfirmedPrivateTransferAck{
              vendor_id: 25,
              service_number: 8,
              result: []
            }} ==
             ConfirmedPrivateTransferAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_private_transfer,
               payload: [
                 tagged: {0, <<25>>, 1},
                 tagged: {1, "\b", 1}
               ]
             })
  end

  test "decoding ConfirmedPrivateTransferAck invalid missing pattern" do
    assert {:error, :invalid_service_ack} =
             ConfirmedPrivateTransferAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_private_transfer,
               payload: [tagged: {0, <<25>>, 1}]
             })
  end

  test "decoding ConfirmedPrivateTransferAck invalid data" do
    assert {:error, :invalid_data} ==
             ConfirmedPrivateTransferAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_private_transfer,
               payload: [
                 tagged: {0, <<>>, 1},
                 tagged: {1, "\b", 1}
               ]
             })
  end

  test "decoding ConfirmedPrivateTransferAck invalid wrong ACK" do
    assert {:error, :invalid_service_ack} =
             ConfirmedPrivateTransferAck.from_apdu(%SimpleACK{
               invoke_id: 0,
               service: :unconfirmed_service_request
             })
  end

  test "decoding ConfirmedPrivateTransferAck invalid vendor id" do
    assert {:error, :invalid_vendor_id_value} ==
             ConfirmedPrivateTransferAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_private_transfer,
               payload: [
                 tagged: {0, <<255, 255, 255, 255>>, 4},
                 tagged: {1, "\b", 1}
               ]
             })
  end

  test "encoding ConfirmedPrivateTransferAck" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 0,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :confirmed_private_transfer,
              payload: [
                tagged: {0, <<25>>, 1},
                tagged: {1, "\b", 1},
                constructed: {2, [{:real, 1.0}], 0}
              ]
            }} ==
             ConfirmedPrivateTransferAck.to_apdu(%ConfirmedPrivateTransferAck{
               vendor_id: 25,
               service_number: 8,
               result: [
                 %Encoding{
                   encoding: :primitive,
                   extras: [],
                   type: :real,
                   value: 1.0
                 }
               ]
             })
  end

  test "encoding ConfirmedPrivateTransferAck without results" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 55,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :confirmed_private_transfer,
              payload: [
                tagged: {0, <<25>>, 1},
                tagged: {1, "\b", 1}
              ]
            }} ==
             ConfirmedPrivateTransferAck.to_apdu(
               %ConfirmedPrivateTransferAck{
                 vendor_id: 25,
                 service_number: 8,
                 result: []
               },
               55
             )
  end

  test "encoding ConfirmedPrivateTransferAck invalid invoke_id" do
    assert {:error, :invalid_parameter} ==
             ConfirmedPrivateTransferAck.to_apdu(
               %ConfirmedPrivateTransferAck{
                 vendor_id: 25,
                 service_number: 8,
                 result: []
               },
               256
             )
  end

  test "encoding ConfirmedPrivateTransferAck invalid vendor id" do
    assert {:error, :invalid_vendor_id_value} ==
             ConfirmedPrivateTransferAck.to_apdu(
               %ConfirmedPrivateTransferAck{
                 vendor_id: 25_524_139,
                 service_number: 8,
                 result: []
               },
               55
             )
  end
end
