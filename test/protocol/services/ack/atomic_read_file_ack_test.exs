defmodule BACnet.Test.Protocol.Services.AtomicReadFileAckTest do
  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.APDU.SimpleACK
  alias BACnet.Protocol.Services.Ack.AtomicReadFileAck

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service
  @moduletag :service_ack

  doctest AtomicReadFileAck

  test "decoding AtomicReadFileAck with stream access" do
    assert {:ok,
            %AtomicReadFileAck{
              stream_access: true,
              start_position: 0,
              record_count: nil,
              data: "Chiller01 On-Time=4.3 Hours",
              eof: false
            }} ==
             AtomicReadFileAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :atomic_read_file,
               payload: [
                 boolean: false,
                 constructed:
                   {0, [signed_integer: 0, octet_string: "Chiller01 On-Time=4.3 Hours"], 0}
               ]
             })
  end

  test "decoding AtomicReadFileAck with record access" do
    assert {:ok,
            %AtomicReadFileAck{
              stream_access: false,
              start_position: 14,
              record_count: 2,
              data: ["12:00,45.6", "12:15,44.8"],
              eof: true
            }} ==
             AtomicReadFileAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :atomic_read_file,
               payload: [
                 boolean: true,
                 constructed:
                   {1,
                    [
                      signed_integer: 14,
                      unsigned_integer: 2,
                      octet_string: "12:00,45.6",
                      octet_string: "12:15,44.8"
                    ], 0}
               ]
             })
  end

  test "decoding AtomicReadFileAck invalid missing pattern" do
    assert {:error, :invalid_service_ack} =
             AtomicReadFileAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :atomic_read_file,
               payload: [boolean: false]
             })
  end

  test "decoding AtomicReadFileAck invalid data chunk" do
    assert {:error, :invalid_data} ==
             AtomicReadFileAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :atomic_read_file,
               payload: [
                 boolean: true,
                 constructed:
                   {1,
                    [
                      signed_integer: 14,
                      unsigned_integer: 2,
                      octet_string: "12:00,45.6",
                      signed_integer: 5
                    ], 0}
               ]
             })
  end

  test "decoding AtomicReadFileAck invalid wrong ACK" do
    assert {:error, :invalid_service_ack} =
             AtomicReadFileAck.from_apdu(%SimpleACK{
               invoke_id: 0,
               service: :unconfirmed_service_request
             })
  end

  test "encoding AtomicReadFileAck with stream access" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 55,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :atomic_read_file,
              payload: [
                boolean: false,
                constructed:
                  {0, [signed_integer: 0, octet_string: "Chiller01 On-Time=4.3 Hours"], 0}
              ]
            }} ==
             AtomicReadFileAck.to_apdu(
               %AtomicReadFileAck{
                 stream_access: true,
                 start_position: 0,
                 record_count: nil,
                 data: "Chiller01 On-Time=4.3 Hours",
                 eof: false
               },
               55
             )
  end

  test "encoding AtomicReadFileAck with record access" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 0,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :atomic_read_file,
              payload: [
                boolean: true,
                constructed:
                  {1,
                   [
                     signed_integer: 14,
                     unsigned_integer: 2,
                     octet_string: "12:00,45.6",
                     octet_string: "12:15,44.8"
                   ], 0}
              ]
            }} ==
             AtomicReadFileAck.to_apdu(%AtomicReadFileAck{
               stream_access: false,
               start_position: 14,
               record_count: 2,
               data: ["12:00,45.6", "12:15,44.8"],
               eof: true
             })
  end

  test "encoding AtomicReadFileAck invalid invoke_id" do
    assert {:error, :invalid_parameter} ==
             AtomicReadFileAck.to_apdu(
               %AtomicReadFileAck{
                 stream_access: false,
                 start_position: 14,
                 record_count: 2,
                 data: ["12:00,45.6", "12:15,44.8"],
                 eof: true
               },
               256
             )
  end
end
