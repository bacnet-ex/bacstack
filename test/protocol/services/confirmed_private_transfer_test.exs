defmodule BACnet.Test.Protocol.Services.ConfirmedPrivateTransferTest do
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.Services.ConfirmedPrivateTransfer
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest ConfirmedPrivateTransfer

  test "get name" do
    assert :confirmed_private_transfer == ConfirmedPrivateTransfer.get_name()
  end

  test "is confirmed" do
    assert true == ConfirmedPrivateTransfer.is_confirmed()
  end

  test "decoding ConfirmedPrivateTransfer" do
    assert {:ok,
            %ConfirmedPrivateTransfer{
              vendor_id: 25,
              service_number: 8,
              parameters: [
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :real,
                  value: 72.4
                },
                %BACnet.Protocol.ApplicationTags.Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :octet_string,
                  value: <<22, 73>>
                }
              ]
            }} =
             ConfirmedPrivateTransfer.from_apdu(%ConfirmedServiceRequest{
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

  test "decoding ConfirmedPrivateTransfer empty params" do
    assert {:ok,
            %ConfirmedPrivateTransfer{
              vendor_id: 25,
              service_number: 8,
              parameters: nil
            }} =
             ConfirmedPrivateTransfer.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_private_transfer,
               parameters: [
                 tagged: {0, <<25>>, 1},
                 tagged: {1, "\b", 1}
               ]
             })
  end

  test "decoding ConfirmedPrivateTransfer invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             ConfirmedPrivateTransfer.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_private_transfer,
               parameters: [
                 tagged: {0, <<25>>, 1}
               ]
             })
  end

  test "decoding ConfirmedPrivateTransfer invalid vendor id" do
    assert {:error, :invalid_vendor_id_value} =
             ConfirmedPrivateTransfer.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_private_transfer,
               parameters: [
                 tagged: {0, <<255, 255, 255, 255>>, 4},
                 tagged: {1, "\b", 1},
                 constructed: {2, [real: 72.4, octet_string: <<22, 73>>], 0}
               ]
             })
  end

  test "decoding ConfirmedPrivateTransfer invalid APDU" do
    assert {:error, :invalid_request} =
             ConfirmedPrivateTransfer.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_event_notification,
               parameters: []
             })
  end

  test "encoding ConfirmedPrivateTransfer" do
    assert {:ok,
            %ConfirmedServiceRequest{
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
            }} =
             ConfirmedPrivateTransfer.to_apdu(
               %ConfirmedPrivateTransfer{
                 vendor_id: 25,
                 service_number: 8,
                 parameters: [
                   %BACnet.Protocol.ApplicationTags.Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :real,
                     value: 72.4
                   },
                   %BACnet.Protocol.ApplicationTags.Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :octet_string,
                     value: <<22, 73>>
                   }
                 ]
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding ConfirmedPrivateTransfer invalid vendor id" do
    assert {:error, :invalid_vendor_id_value} =
             ConfirmedPrivateTransfer.to_apdu(
               %ConfirmedPrivateTransfer{
                 vendor_id: 25_532_245,
                 service_number: 8,
                 parameters: [
                   %BACnet.Protocol.ApplicationTags.Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :real,
                     value: 72.4
                   },
                   %BACnet.Protocol.ApplicationTags.Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :octet_string,
                     value: <<22, 73>>
                   }
                 ]
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "protocol implementation get name" do
    assert :confirmed_private_transfer ==
             ServicesProtocol.get_name(%ConfirmedPrivateTransfer{
               vendor_id: 25,
               service_number: 8,
               parameters: [
                 %BACnet.Protocol.ApplicationTags.Encoding{
                   encoding: :primitive,
                   extras: [],
                   type: :real,
                   value: 72.4
                 },
                 %BACnet.Protocol.ApplicationTags.Encoding{
                   encoding: :primitive,
                   extras: [],
                   type: :octet_string,
                   value: <<22, 73>>
                 }
               ]
             })
  end

  test "protocol implementation is confirmed" do
    assert true ==
             ServicesProtocol.is_confirmed(%ConfirmedPrivateTransfer{
               vendor_id: 25,
               service_number: 8,
               parameters: [
                 %BACnet.Protocol.ApplicationTags.Encoding{
                   encoding: :primitive,
                   extras: [],
                   type: :real,
                   value: 72.4
                 },
                 %BACnet.Protocol.ApplicationTags.Encoding{
                   encoding: :primitive,
                   extras: [],
                   type: :octet_string,
                   value: <<22, 73>>
                 }
               ]
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
              service: :confirmed_private_transfer,
              parameters: [
                tagged: {0, <<25>>, 1},
                tagged: {1, "\b", 1},
                constructed: {2, [real: 72.4, octet_string: <<22, 73>>], 0}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %ConfirmedPrivateTransfer{
                 vendor_id: 25,
                 service_number: 8,
                 parameters: [
                   %BACnet.Protocol.ApplicationTags.Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :real,
                     value: 72.4
                   },
                   %BACnet.Protocol.ApplicationTags.Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :octet_string,
                     value: <<22, 73>>
                   }
                 ]
               },
               invoke_id: 1,
               max_segments: 4
             )
  end
end
