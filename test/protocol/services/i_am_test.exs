defmodule BACnet.Test.Protocol.Services.IAmTest do
  alias BACnet.Protocol.APDU.UnconfirmedServiceRequest
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.IAm
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol

  require Constants
  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest IAm

  test "get name" do
    assert :i_am == IAm.get_name()
  end

  test "is confirmed" do
    assert false == IAm.is_confirmed()
  end

  test "decoding IAm" do
    assert {:ok,
            %IAm{
              device: %ObjectIdentifier{
                instance: 111,
                type: :device
              },
              max_apdu: 50,
              segmentation_supported:
                Constants.macro_assert_name(:segmentation, :no_segmentation),
              vendor_id: 42
            }} =
             IAm.from_apdu(%UnconfirmedServiceRequest{
               service: :i_am,
               parameters: [
                 object_identifier: %ObjectIdentifier{
                   instance: 111,
                   type: :device
                 },
                 unsigned_integer: 50,
                 enumerated: 3,
                 unsigned_integer: 42
               ]
             })
  end

  test "decoding IAm invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             IAm.from_apdu(%UnconfirmedServiceRequest{
               service: :i_am,
               parameters: [
                 object_identifier: %ObjectIdentifier{
                   instance: 111,
                   type: :device
                 }
               ]
             })
  end

  test "decoding IAm invalid vendor id" do
    assert {:error, :invalid_vendor_id_value} =
             IAm.from_apdu(%UnconfirmedServiceRequest{
               service: :i_am,
               parameters: [
                 object_identifier: %ObjectIdentifier{
                   instance: 111,
                   type: :device
                 },
                 unsigned_integer: 50,
                 enumerated: 3,
                 unsigned_integer: 425_345
               ]
             })
  end

  test "decoding IAm invalid APDU" do
    assert {:error, :invalid_request} =
             IAm.from_apdu(%UnconfirmedServiceRequest{
               service: :i_have,
               parameters: []
             })
  end

  test "decoding IAm unknown segmentation" do
    assert {:error, {:unknown_segmentation, 255}} =
             IAm.from_apdu(%UnconfirmedServiceRequest{
               service: :i_am,
               parameters: [
                 object_identifier: %ObjectIdentifier{
                   instance: 111,
                   type: :device
                 },
                 unsigned_integer: 50,
                 enumerated: 255,
                 unsigned_integer: 42
               ]
             })
  end

  test "encoding IAm" do
    assert {:ok,
            %UnconfirmedServiceRequest{
              service: :i_am,
              parameters: [
                object_identifier: %ObjectIdentifier{
                  instance: 111,
                  type: :device
                },
                unsigned_integer: 1476,
                enumerated: 0,
                unsigned_integer: 255
              ]
            }} =
             IAm.to_apdu(
               %IAm{
                 device: %ObjectIdentifier{
                   instance: 111,
                   type: :device
                 },
                 max_apdu: 1476,
                 segmentation_supported:
                   Constants.macro_assert_name(:segmentation, :segmented_both),
                 vendor_id: 255
               },
               []
             )
  end

  test "encoding IAm unknown segmentation" do
    assert {:error, {:unknown_segmentation, :hello_there}} =
             IAm.to_apdu(
               %IAm{
                 device: %ObjectIdentifier{
                   instance: 111,
                   type: :device
                 },
                 max_apdu: 1476,
                 segmentation_supported: :hello_there,
                 vendor_id: 255
               },
               []
             )
  end

  test "protocol implementation get name" do
    assert :i_am ==
             ServicesProtocol.get_name(%IAm{
               device: %ObjectIdentifier{
                 instance: 111,
                 type: :device
               },
               max_apdu: 1476,
               segmentation_supported:
                 Constants.macro_assert_name(:segmentation, :segmented_both),
               vendor_id: 255
             })
  end

  test "encoding IAm invalid vendor id" do
    assert {:error, :invalid_vendor_id_value} =
             IAm.to_apdu(
               %IAm{
                 device: %ObjectIdentifier{
                   instance: 111,
                   type: :device
                 },
                 max_apdu: 1476,
                 segmentation_supported:
                   Constants.macro_assert_name(:segmentation, :segmented_both),
                 vendor_id: 345_534
               },
               []
             )
  end

  test "protocol implementation is confirmed" do
    assert false ==
             ServicesProtocol.is_confirmed(%IAm{
               device: %ObjectIdentifier{
                 instance: 111,
                 type: :device
               },
               max_apdu: 1476,
               segmentation_supported:
                 Constants.macro_assert_name(:segmentation, :segmented_both),
               vendor_id: 255
             })
  end

  test "protocol implementation to APDU" do
    assert {:ok,
            %UnconfirmedServiceRequest{
              service: :i_am,
              parameters: [
                object_identifier: %ObjectIdentifier{
                  instance: 111,
                  type: :device
                },
                unsigned_integer: 1476,
                enumerated: 0,
                unsigned_integer: 255
              ]
            }} =
             ServicesProtocol.to_apdu(
               %IAm{
                 device: %ObjectIdentifier{
                   instance: 111,
                   type: :device
                 },
                 max_apdu: 1476,
                 segmentation_supported:
                   Constants.macro_assert_name(:segmentation, :segmented_both),
                 vendor_id: 255
               },
               []
             )
  end
end
