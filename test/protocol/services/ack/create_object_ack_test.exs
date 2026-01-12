defmodule BACnet.Test.Protocol.Services.CreateObjectAckTest do
  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.APDU.SimpleACK
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.Ack.CreateObjectAck

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service
  @moduletag :service_ack

  doctest CreateObjectAck

  test "decoding CreateObjectAck" do
    assert {:ok,
            %CreateObjectAck{
              object_identifier: %ObjectIdentifier{
                type: :file,
                instance: 13
              }
            }} ==
             CreateObjectAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :create_object,
               payload: [
                 object_identifier: %ObjectIdentifier{
                   type: :file,
                   instance: 13
                 }
               ]
             })
  end

  test "decoding CreateObjectAck invalid missing pattern" do
    assert {:error, :invalid_service_ack} =
             CreateObjectAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :create_object,
               payload: []
             })
  end

  test "decoding CreateObjectAck invalid wrong ACK" do
    assert {:error, :invalid_service_ack} =
             CreateObjectAck.from_apdu(%SimpleACK{
               invoke_id: 0,
               service: :unconfirmed_service_request
             })
  end

  test "encoding CreateObjectAck" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 55,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :create_object,
              payload: [
                object_identifier: %ObjectIdentifier{
                  type: :file,
                  instance: 13
                }
              ]
            }} ==
             CreateObjectAck.to_apdu(
               %CreateObjectAck{
                 object_identifier: %ObjectIdentifier{
                   type: :file,
                   instance: 13
                 }
               },
               55
             )
  end

  test "encoding CreateObjectAck with optional invoke_id" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 0,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :create_object,
              payload: [
                object_identifier: %ObjectIdentifier{
                  type: :file,
                  instance: 13
                }
              ]
            }} ==
             CreateObjectAck.to_apdu(%CreateObjectAck{
               object_identifier: %ObjectIdentifier{
                 type: :file,
                 instance: 13
               }
             })
  end

  test "encoding CreateObjectAck invalid invoke_id" do
    assert {:error, :invalid_parameter} ==
             CreateObjectAck.to_apdu(
               %CreateObjectAck{
                 object_identifier: %ObjectIdentifier{
                   type: :file,
                   instance: 13
                 }
               },
               256
             )
  end
end
