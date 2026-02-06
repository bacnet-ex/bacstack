defmodule BACnet.Test.Protocol.Services.UnconfirmedPrivateTransferTest do
  alias BACnet.Protocol.APDU.UnconfirmedServiceRequest
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol
  alias BACnet.Protocol.Services.UnconfirmedPrivateTransfer

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest UnconfirmedPrivateTransfer

  test "get name" do
    assert :unconfirmed_private_transfer == UnconfirmedPrivateTransfer.get_name()
  end

  test "is confirmed" do
    assert false == UnconfirmedPrivateTransfer.is_confirmed()
  end

  test "decoding UnconfirmedPrivateTransfer" do
    assert {:ok,
            %UnconfirmedPrivateTransfer{
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
             UnconfirmedPrivateTransfer.from_apdu(%UnconfirmedServiceRequest{
               service: :unconfirmed_private_transfer,
               parameters: [
                 tagged: {0, <<25>>, 1},
                 tagged: {1, "\b", 1},
                 constructed: {2, [real: 72.4, octet_string: <<22, 73>>], 0}
               ]
             })
  end

  test "decoding UnconfirmedPrivateTransfer empty params" do
    assert {:ok,
            %UnconfirmedPrivateTransfer{
              vendor_id: 25,
              service_number: 8,
              parameters: nil
            }} =
             UnconfirmedPrivateTransfer.from_apdu(%UnconfirmedServiceRequest{
               service: :unconfirmed_private_transfer,
               parameters: [
                 tagged: {0, <<25>>, 1},
                 tagged: {1, "\b", 1}
               ]
             })
  end

  test "decoding UnconfirmedPrivateTransfer invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             UnconfirmedPrivateTransfer.from_apdu(%UnconfirmedServiceRequest{
               service: :unconfirmed_private_transfer,
               parameters: [
                 tagged: {0, <<25>>, 1}
               ]
             })
  end

  test "decoding UnconfirmedPrivateTransfer invalid vendor id" do
    assert {:error, :invalid_vendor_id_value} =
             UnconfirmedPrivateTransfer.from_apdu(%UnconfirmedServiceRequest{
               service: :unconfirmed_private_transfer,
               parameters: [
                 tagged: {0, <<255, 255, 255, 255>>, 4},
                 tagged: {1, "\b", 1},
                 constructed: {2, [real: 72.4, octet_string: <<22, 73>>], 0}
               ]
             })
  end

  test "decoding UnconfirmedPrivateTransfer invalid APDU" do
    assert {:error, :invalid_request} =
             UnconfirmedPrivateTransfer.from_apdu(%UnconfirmedServiceRequest{
               service: :who_is,
               parameters: []
             })
  end

  test "encoding UnconfirmedPrivateTransfer" do
    assert {:ok,
            %UnconfirmedServiceRequest{
              service: :unconfirmed_private_transfer,
              parameters: [
                tagged: {0, <<25>>, 1},
                tagged: {1, "\b", 1},
                constructed: {2, [real: 72.4, octet_string: <<22, 73>>], 0}
              ]
            }} =
             UnconfirmedPrivateTransfer.to_apdu(
               %UnconfirmedPrivateTransfer{
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
               []
             )
  end

  test "encoding UnconfirmedPrivateTransfer invalid vendor id" do
    assert {:error, :invalid_vendor_id_value} =
             UnconfirmedPrivateTransfer.to_apdu(
               %UnconfirmedPrivateTransfer{
                 vendor_id: 25_534_512,
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
               []
             )
  end

  test "protocol implementation get name" do
    assert :unconfirmed_private_transfer ==
             ServicesProtocol.get_name(%UnconfirmedPrivateTransfer{
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
    assert false ==
             ServicesProtocol.is_confirmed(%UnconfirmedPrivateTransfer{
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
            %UnconfirmedServiceRequest{
              service: :unconfirmed_private_transfer,
              parameters: [
                tagged: {0, <<25>>, 1},
                tagged: {1, "\b", 1},
                constructed: {2, [real: 72.4, octet_string: <<22, 73>>], 0}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %UnconfirmedPrivateTransfer{
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
               []
             )
  end
end
