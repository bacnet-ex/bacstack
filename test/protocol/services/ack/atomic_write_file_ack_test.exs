defmodule BACnet.Test.Protocol.Services.AtomicWriteFileAckTest do
  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.APDU.SimpleACK
  alias BACnet.Protocol.Services.Ack.AtomicWriteFileAck

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service
  @moduletag :service_ack

  doctest AtomicWriteFileAck

  test "decoding AtomicWriteFileAck with stream access" do
    assert {:ok,
            %AtomicWriteFileAck{
              stream_access: true,
              start_position: 15
            }} ==
             AtomicWriteFileAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :atomic_write_file,
               payload: [
                 tagged: {0, <<15>>, 1}
               ]
             })
  end

  test "decoding AtomicWriteFileAck with record access" do
    assert {:ok,
            %AtomicWriteFileAck{
              stream_access: false,
              start_position: 14
            }} ==
             AtomicWriteFileAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :atomic_write_file,
               payload: [
                 tagged: {1, <<14>>, 1}
               ]
             })
  end

  test "decoding AtomicWriteFileAck invalid missing pattern" do
    assert {:error, :invalid_service_ack} =
             AtomicWriteFileAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :atomic_write_file,
               payload: [boolean: false]
             })
  end

  test "decoding AtomicWriteFileAck invalid wrong ACK" do
    assert {:error, :invalid_service_ack} =
             AtomicWriteFileAck.from_apdu(%SimpleACK{
               invoke_id: 0,
               service: :unconfirmed_service_request
             })
  end

  test "encoding AtomicWriteFileAck with stream access" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 0,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :atomic_write_file,
              payload: [
                tagged: {0, <<2>>, 1}
              ]
            }} ==
             AtomicWriteFileAck.to_apdu(%AtomicWriteFileAck{
               stream_access: true,
               start_position: 2
             })
  end

  test "encoding AtomicWriteFileAck with record access" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 22,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :atomic_write_file,
              payload: [
                tagged: {1, <<14>>, 1}
              ]
            }} ==
             AtomicWriteFileAck.to_apdu(
               %AtomicWriteFileAck{
                 stream_access: false,
                 start_position: 14
               },
               22
             )
  end

  test "encoding AtomicWriteFileAck invalid invoke_id" do
    assert {:error, :invalid_parameter} ==
             AtomicWriteFileAck.to_apdu(
               %AtomicWriteFileAck{
                 stream_access: false,
                 start_position: 14
               },
               256
             )
  end
end
