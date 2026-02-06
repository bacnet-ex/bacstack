defmodule BACnet.Test.Protocol.Services.AtomicReadFile do
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.AtomicReadFile
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest AtomicReadFile

  test "get name" do
    assert :atomic_read_file == AtomicReadFile.get_name()
  end

  test "is confirmed" do
    assert true == AtomicReadFile.is_confirmed()
  end

  test "decoding AtomicReadFile stream access" do
    assert {:ok,
            %AtomicReadFile{
              object_identifier: %ObjectIdentifier{
                instance: 550,
                type: :file
              },
              stream_access: true,
              start_position: 0,
              requested_count: 440
            }} =
             AtomicReadFile.from_apdu(%ConfirmedServiceRequest{
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

  test "decoding AtomicReadFile record access" do
    assert {:ok,
            %AtomicReadFile{
              object_identifier: %ObjectIdentifier{
                instance: 550,
                type: :file
              },
              stream_access: false,
              start_position: 50,
              requested_count: 4
            }} =
             AtomicReadFile.from_apdu(%ConfirmedServiceRequest{
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
                 constructed: {1, [signed_integer: 50, unsigned_integer: 4], 0}
               ]
             })
  end

  test "decoding AtomicReadFile invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             AtomicReadFile.from_apdu(%ConfirmedServiceRequest{
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
                 }
               ]
             })
  end

  test "decoding AtomicReadFile invalid APDU" do
    assert {:error, :invalid_request} =
             AtomicReadFile.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :atomic_write_file,
               parameters: []
             })
  end

  test "decoding AtomicReadFile invalid object" do
    assert {:error, :invalid_request_parameters} =
             AtomicReadFile.from_apdu(%ConfirmedServiceRequest{
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
                   type: :device
                 },
                 constructed: {0, [signed_integer: 0, unsigned_integer: 440], 0}
               ]
             })
  end

  test "decoding AtomicReadFile invalid access" do
    assert {:error, :invalid_request_parameters} =
             AtomicReadFile.from_apdu(%ConfirmedServiceRequest{
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
                 constructed: {2, [signed_integer: 0, unsigned_integer: 440], 0}
               ]
             })
  end

  test "encoding AtomicReadFile stream access" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :atomic_read_file,
              parameters: [
                {:object_identifier, %ObjectIdentifier{type: :file, instance: 1}},
                {:constructed, {0, [signed_integer: 44, unsigned_integer: 59], 0}}
              ]
            }} =
             AtomicReadFile.to_apdu(
               %AtomicReadFile{
                 object_identifier: %ObjectIdentifier{type: :file, instance: 1},
                 stream_access: true,
                 start_position: 44,
                 requested_count: 59
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding AtomicReadFile record access" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :atomic_read_file,
              parameters: [
                {:object_identifier, %ObjectIdentifier{type: :file, instance: 15}},
                {:constructed, {1, [signed_integer: 0, unsigned_integer: 1], 0}}
              ]
            }} =
             AtomicReadFile.to_apdu(
               %AtomicReadFile{
                 object_identifier: %ObjectIdentifier{type: :file, instance: 15},
                 stream_access: false,
                 start_position: 0,
                 requested_count: 1
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "protocol implementation get name" do
    assert :atomic_read_file ==
             ServicesProtocol.get_name(%AtomicReadFile{
               object_identifier: %ObjectIdentifier{type: :file, instance: 15},
               stream_access: true,
               start_position: 0,
               requested_count: 1
             })
  end

  test "protocol implementation is confirmed" do
    assert true ==
             ServicesProtocol.is_confirmed(%AtomicReadFile{
               object_identifier: %ObjectIdentifier{type: :file, instance: 15},
               stream_access: true,
               start_position: 0,
               requested_count: 1
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
              service: :atomic_read_file,
              parameters: [
                {:object_identifier, %ObjectIdentifier{type: :file, instance: 15}},
                {:constructed, {0, [signed_integer: 0, unsigned_integer: 1], 0}}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %AtomicReadFile{
                 object_identifier: %ObjectIdentifier{type: :file, instance: 15},
                 stream_access: true,
                 start_position: 0,
                 requested_count: 1
               },
               invoke_id: 1,
               max_segments: 4
             )
  end
end
