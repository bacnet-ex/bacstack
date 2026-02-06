defmodule BACnet.Test.Protocol.Services.UnconfirmedTextMessageTest do
  alias BACnet.Protocol.APDU.UnconfirmedServiceRequest
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol
  alias BACnet.Protocol.Services.UnconfirmedTextMessage

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest UnconfirmedTextMessage

  test "get name" do
    assert :unconfirmed_text_message == UnconfirmedTextMessage.get_name()
  end

  test "is confirmed" do
    assert false == UnconfirmedTextMessage.is_confirmed()
  end

  test "decoding UnconfirmedTextMessage" do
    assert {:ok,
            %UnconfirmedTextMessage{
              source_device: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 5},
              class: nil,
              priority: :normal,
              message: "PM required for PUMP347"
            }} =
             UnconfirmedTextMessage.from_apdu(%UnconfirmedServiceRequest{
               service: :unconfirmed_text_message,
               parameters: [
                 tagged: {0, <<2, 0, 0, 5>>, 4},
                 tagged: {2, <<0>>, 1},
                 tagged:
                   {3,
                    <<0, 80, 77, 32, 114, 101, 113, 117, 105, 114, 101, 100, 32, 102, 111, 114,
                      32, 80, 85, 77, 80, 51, 52, 55>>, 24}
               ]
             })
  end

  test "decoding UnconfirmedTextMessage with numeric class" do
    assert {:ok,
            %UnconfirmedTextMessage{
              source_device: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 5},
              class: 1,
              priority: :normal,
              message: "PM required for PUMP347"
            }} =
             UnconfirmedTextMessage.from_apdu(%UnconfirmedServiceRequest{
               service: :unconfirmed_text_message,
               parameters: [
                 tagged: {0, <<2, 0, 0, 5>>, 4},
                 constructed: {1, {:tagged, {0, <<1>>, 1}}, 0},
                 tagged: {2, <<0>>, 1},
                 tagged:
                   {3,
                    <<0, 80, 77, 32, 114, 101, 113, 117, 105, 114, 101, 100, 32, 102, 111, 114,
                      32, 80, 85, 77, 80, 51, 52, 55>>, 24}
               ]
             })
  end

  test "decoding UnconfirmedTextMessage with string class" do
    assert {:ok,
            %UnconfirmedTextMessage{
              source_device: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 5},
              class: "Hello World",
              priority: :urgent,
              message: "PM required for PUMP347"
            }} =
             UnconfirmedTextMessage.from_apdu(%UnconfirmedServiceRequest{
               service: :unconfirmed_text_message,
               parameters: [
                 tagged: {0, <<2, 0, 0, 5>>, 4},
                 constructed:
                   {1,
                    {:tagged, {1, <<0, 72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100>>, 1}},
                    0},
                 tagged: {2, <<1>>, 1},
                 tagged:
                   {3,
                    <<0, 80, 77, 32, 114, 101, 113, 117, 105, 114, 101, 100, 32, 102, 111, 114,
                      32, 80, 85, 77, 80, 51, 52, 55>>, 24}
               ]
             })
  end

  test "decoding UnconfirmedTextMessage invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             UnconfirmedTextMessage.from_apdu(%UnconfirmedServiceRequest{
               service: :unconfirmed_text_message,
               parameters: [
                 tagged: {0, <<2, 0, 0, 5>>, 4},
                 tagged: {2, <<0>>, 1}
               ]
             })
  end

  test "decoding UnconfirmedTextMessage with invalid class" do
    assert {:error, :invalid_request_parameters} =
             UnconfirmedTextMessage.from_apdu(%UnconfirmedServiceRequest{
               service: :unconfirmed_text_message,
               parameters: [
                 tagged: {0, <<2, 0, 0, 5>>, 4},
                 constructed: {1, nil, 0},
                 tagged: {2, <<0>>, 1},
                 tagged:
                   {3,
                    <<0, 80, 77, 32, 114, 101, 113, 117, 105, 114, 101, 100, 32, 102, 111, 114,
                      32, 80, 85, 77, 80, 51, 52, 55>>, 24}
               ]
             })
  end

  test "decoding UnconfirmedTextMessage invalid APDU" do
    assert {:error, :invalid_request} =
             UnconfirmedTextMessage.from_apdu(%UnconfirmedServiceRequest{
               service: :i_am,
               parameters: []
             })
  end

  test "encoding UnconfirmedTextMessage" do
    assert {:ok,
            %UnconfirmedServiceRequest{
              service: :unconfirmed_text_message,
              parameters: [
                tagged: {0, <<2, 0, 0, 5>>, 4},
                tagged: {2, <<0>>, 1},
                tagged:
                  {3,
                   <<0, 80, 77, 32, 114, 101, 113, 117, 105, 114, 101, 100, 32, 102, 111, 114, 32,
                     80, 85, 77, 80, 51, 52, 55>>, 24}
              ]
            }} =
             UnconfirmedTextMessage.to_apdu(
               %UnconfirmedTextMessage{
                 source_device: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 5},
                 class: nil,
                 priority: :normal,
                 message: "PM required for PUMP347"
               },
               []
             )
  end

  test "encoding UnconfirmedTextMessage with numeric class" do
    assert {:ok,
            %UnconfirmedServiceRequest{
              service: :unconfirmed_text_message,
              parameters: [
                tagged: {0, <<2, 0, 0, 5>>, 4},
                constructed: {1, {:tagged, {0, <<55>>, 1}}, 0},
                tagged: {2, <<0>>, 1},
                tagged:
                  {3,
                   <<0, 80, 77, 32, 114, 101, 113, 117, 105, 114, 101, 100, 32, 102, 111, 114, 32,
                     80, 85, 77, 80, 51, 52, 55>>, 24}
              ]
            }} =
             UnconfirmedTextMessage.to_apdu(
               %UnconfirmedTextMessage{
                 source_device: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 5},
                 class: 55,
                 priority: :normal,
                 message: "PM required for PUMP347"
               },
               []
             )
  end

  test "encoding UnconfirmedTextMessage with string class" do
    assert {:ok,
            %UnconfirmedServiceRequest{
              service: :unconfirmed_text_message,
              parameters: [
                tagged: {0, <<2, 0, 0, 5>>, 4},
                constructed: {1, {:tagged, {1, <<0, 110, 117, 108, 108>>, 5}}, 0},
                tagged: {2, <<1>>, 1},
                tagged:
                  {3,
                   <<0, 80, 77, 32, 114, 101, 113, 117, 105, 114, 101, 100, 32, 102, 111, 114, 32,
                     80, 85, 77, 80, 51, 52, 55>>, 24}
              ]
            }} =
             UnconfirmedTextMessage.to_apdu(
               %UnconfirmedTextMessage{
                 source_device: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 5},
                 class: "null",
                 priority: :urgent,
                 message: "PM required for PUMP347"
               },
               []
             )
  end

  test "protocol implementation get name" do
    assert :unconfirmed_text_message ==
             ServicesProtocol.get_name(%UnconfirmedTextMessage{
               source_device: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 5},
               class: "null",
               priority: :urgent,
               message: "PM required for PUMP347"
             })
  end

  test "protocol implementation is confirmed" do
    assert false ==
             ServicesProtocol.is_confirmed(%UnconfirmedTextMessage{
               source_device: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 5},
               class: "null",
               priority: :urgent,
               message: "PM required for PUMP347"
             })
  end

  test "protocol implementation to APDU" do
    assert {:ok,
            %UnconfirmedServiceRequest{
              service: :unconfirmed_text_message,
              parameters: [
                tagged: {0, <<2, 0, 0, 5>>, 4},
                constructed: {1, {:tagged, {1, <<0, 110, 117, 108, 108>>, 5}}, 0},
                tagged: {2, <<1>>, 1},
                tagged:
                  {3,
                   <<0, 80, 77, 32, 114, 101, 113, 117, 105, 114, 101, 100, 32, 102, 111, 114, 32,
                     80, 85, 77, 80, 51, 52, 55>>, 24}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %UnconfirmedTextMessage{
                 source_device: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 5},
                 class: "null",
                 priority: :urgent,
                 message: "PM required for PUMP347"
               },
               []
             )
  end
end
