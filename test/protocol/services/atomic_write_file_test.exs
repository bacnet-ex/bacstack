defmodule BACnet.Test.Protocol.Services.AtomicWriteFile do
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.AtomicWriteFile
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest AtomicWriteFile

  test "get name" do
    assert :atomic_write_file == AtomicWriteFile.get_name()
  end

  test "is confirmed" do
    assert true == AtomicWriteFile.is_confirmed()
  end

  test "decoding AtomicWriteFile stream access" do
    assert {:ok,
            %AtomicWriteFile{
              object_identifier: %ObjectIdentifier{
                instance: 154,
                type: :file
              },
              stream_access: true,
              start_position: 440,
              data: "SCHEDULE 0,SCHEDULE 0,\r\n"
            }} =
             AtomicWriteFile.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :atomic_write_file,
               parameters: [
                 object_identifier: %ObjectIdentifier{
                   instance: 154,
                   type: :file
                 },
                 constructed:
                   {0,
                    [
                      signed_integer: 440,
                      octet_string: "SCHEDULE 0,SCHEDULE 0,\r\n"
                    ], 0}
               ]
             })
  end

  test "decoding AtomicWriteFile record access" do
    assert {:ok,
            %AtomicWriteFile{
              object_identifier: %ObjectIdentifier{
                instance: 154,
                type: :file
              },
              stream_access: false,
              start_position: 40,
              data: ["SCHEDULE 0,SCHEDULE 0,\r\n", "SCHEDULE 6,SCHEDULE 5,\r\n"]
            }} =
             AtomicWriteFile.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :atomic_write_file,
               parameters: [
                 object_identifier: %ObjectIdentifier{
                   instance: 154,
                   type: :file
                 },
                 constructed:
                   {1,
                    [
                      signed_integer: 40,
                      unsigned_integer: 2,
                      octet_string: "SCHEDULE 0,SCHEDULE 0,\r\n",
                      octet_string: "SCHEDULE 6,SCHEDULE 5,\r\n"
                    ], 0}
               ]
             })
  end

  test "decoding AtomicWriteFile invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             AtomicWriteFile.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :atomic_write_file,
               parameters: [
                 object_identifier: %ObjectIdentifier{
                   instance: 550,
                   type: :file
                 }
               ]
             })
  end

  test "decoding AtomicWriteFile invalid APDU" do
    assert {:error, :invalid_request} =
             AtomicWriteFile.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :atomic_read_file,
               parameters: []
             })
  end

  test "decoding AtomicWriteFile invalid object stream access" do
    assert {:error, :invalid_request_parameters} =
             AtomicWriteFile.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :atomic_write_file,
               parameters: [
                 object_identifier: %ObjectIdentifier{
                   instance: 550,
                   type: :device
                 },
                 constructed:
                   {0,
                    [
                      signed_integer: 440,
                      octet_string: "SCHEDULE 0,SCHEDULE 0,\r\n"
                    ], 0}
               ]
             })
  end

  test "decoding AtomicWriteFile invalid object record access" do
    assert {:error, :invalid_request_parameters} =
             AtomicWriteFile.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :atomic_write_file,
               parameters: [
                 object_identifier: %ObjectIdentifier{
                   instance: 550,
                   type: :device
                 },
                 constructed:
                   {1,
                    [
                      signed_integer: 40,
                      unsigned_integer: 2,
                      octet_string: "SCHEDULE 0,SCHEDULE 0,\r\n",
                      octet_string: "SCHEDULE 6,SCHEDULE 5,\r\n"
                    ], 0}
               ]
             })
  end

  test "decoding AtomicWriteFile invalid access" do
    assert {:error, :invalid_request_parameters} =
             AtomicWriteFile.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :atomic_write_file,
               parameters: [
                 object_identifier: %ObjectIdentifier{
                   instance: 550,
                   type: :file
                 },
                 constructed:
                   {2,
                    [
                      signed_integer: 440,
                      octet_string: "SCHEDULE 0,SCHEDULE 0,\r\n"
                    ], 0}
               ]
             })
  end

  test "encoding AtomicWriteFile stream access" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :atomic_write_file,
              parameters: [
                object_identifier: %ObjectIdentifier{
                  instance: 154,
                  type: :file
                },
                constructed:
                  {0,
                   [
                     signed_integer: 440,
                     octet_string: "SCHEDULE 0,SCHEDULE 0,\r\n"
                   ], 0}
              ]
            }} =
             AtomicWriteFile.to_apdu(
               %AtomicWriteFile{
                 object_identifier: %ObjectIdentifier{
                   instance: 154,
                   type: :file
                 },
                 stream_access: true,
                 start_position: 440,
                 data: "SCHEDULE 0,SCHEDULE 0,\r\n"
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding AtomicWriteFile record access" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :atomic_write_file,
              parameters: [
                object_identifier: %ObjectIdentifier{
                  instance: 154,
                  type: :file
                },
                constructed:
                  {1,
                   [
                     signed_integer: 40,
                     unsigned_integer: 2,
                     octet_string: "SCHEDULE 0,SCHEDULE 0,\r\n",
                     octet_string: "SCHEDULE 6,SCHEDULE 5,\r\n"
                   ], 0}
              ]
            }} =
             AtomicWriteFile.to_apdu(
               %AtomicWriteFile{
                 object_identifier: %ObjectIdentifier{
                   instance: 154,
                   type: :file
                 },
                 stream_access: false,
                 start_position: 40,
                 data: ["SCHEDULE 0,SCHEDULE 0,\r\n", "SCHEDULE 6,SCHEDULE 5,\r\n"]
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "protocol implementation get name" do
    assert :atomic_write_file ==
             ServicesProtocol.get_name(%AtomicWriteFile{
               object_identifier: %ObjectIdentifier{
                 instance: 154,
                 type: :file
               },
               stream_access: true,
               start_position: 440,
               data: "SCHEDULE 0,SCHEDULE 0,\r\n"
             })
  end

  test "protocol implementation is confirmed" do
    assert true ==
             ServicesProtocol.is_confirmed(%AtomicWriteFile{
               object_identifier: %ObjectIdentifier{
                 instance: 154,
                 type: :file
               },
               stream_access: true,
               start_position: 440,
               data: "SCHEDULE 0,SCHEDULE 0,\r\n"
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
              service: :atomic_write_file,
              parameters: [
                object_identifier: %ObjectIdentifier{
                  instance: 154,
                  type: :file
                },
                constructed:
                  {0,
                   [
                     signed_integer: 440,
                     octet_string: "SCHEDULE 0,SCHEDULE 0,\r\n"
                   ], 0}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %AtomicWriteFile{
                 object_identifier: %ObjectIdentifier{
                   instance: 154,
                   type: :file
                 },
                 stream_access: true,
                 start_position: 440,
                 data: "SCHEDULE 0,SCHEDULE 0,\r\n"
               },
               invoke_id: 1,
               max_segments: 4
             )
  end
end
