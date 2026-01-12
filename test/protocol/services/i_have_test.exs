defmodule BACnet.Test.Protocol.Services.IHaveTest do
  alias BACnet.Protocol.APDU.UnconfirmedServiceRequest
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.IHave
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest IHave

  test "get name" do
    assert :i_have == IHave.get_name()
  end

  test "is confirmed" do
    assert false == IHave.is_confirmed()
  end

  test "decoding IHave" do
    assert {:ok,
            %IHave{
              device: %ObjectIdentifier{
                type: :device,
                instance: 8
              },
              object: %ObjectIdentifier{
                type: :analog_input,
                instance: 3
              },
              object_name: "OATemp"
            }} =
             IHave.from_apdu(%UnconfirmedServiceRequest{
               service: :i_have,
               parameters: [
                 object_identifier: %ObjectIdentifier{
                   type: :device,
                   instance: 8
                 },
                 object_identifier: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 3
                 },
                 character_string: "OATemp"
               ]
             })
  end

  test "decoding IHave invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             IHave.from_apdu(%UnconfirmedServiceRequest{
               service: :i_have,
               parameters: [
                 object_identifier: %ObjectIdentifier{
                   instance: 111,
                   type: :device
                 },
                 object_identifier: %ObjectIdentifier{
                   instance: 1,
                   type: :analog_input
                 }
               ]
             })
  end

  test "decoding IHave invalid APDU" do
    assert {:error, :invalid_request} =
             IHave.from_apdu(%UnconfirmedServiceRequest{
               service: :who_is,
               parameters: []
             })
  end

  test "encoding IHave" do
    assert {:ok,
            %UnconfirmedServiceRequest{
              service: :i_have,
              parameters: [
                object_identifier: %ObjectIdentifier{
                  type: :device,
                  instance: 8
                },
                object_identifier: %ObjectIdentifier{
                  type: :analog_input,
                  instance: 3
                },
                character_string: "OATemp"
              ]
            }} =
             IHave.to_apdu(
               %IHave{
                 device: %ObjectIdentifier{
                   type: :device,
                   instance: 8
                 },
                 object: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 3
                 },
                 object_name: "OATemp"
               },
               []
             )
  end

  test "encoding IHave invalid object name" do
    assert_raise ArgumentError, fn ->
      IHave.to_apdu(
        %IHave{
          device: %ObjectIdentifier{
            type: :device,
            instance: 8
          },
          object: %ObjectIdentifier{
            type: :analog_input,
            instance: 3
          },
          object_name: <<0xC3, 0x28>>
        },
        []
      )
    end

    assert_raise ArgumentError, fn ->
      IHave.to_apdu(
        %IHave{
          device: %ObjectIdentifier{
            type: :device,
            instance: 8
          },
          object: %ObjectIdentifier{
            type: :analog_input,
            instance: 3
          },
          object_name: <<0, 40>>
        },
        []
      )
    end
  end

  test "protocol implementation get name" do
    assert :i_have ==
             ServicesProtocol.get_name(%IHave{
               device: %ObjectIdentifier{
                 type: :device,
                 instance: 8
               },
               object: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 3
               },
               object_name: "OATemp"
             })
  end

  test "protocol implementation is confirmed" do
    assert false ==
             ServicesProtocol.is_confirmed(%IHave{
               device: %ObjectIdentifier{
                 type: :device,
                 instance: 8
               },
               object: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 3
               },
               object_name: "OATemp"
             })
  end

  test "protocol implementation to APDU" do
    assert {:ok,
            %UnconfirmedServiceRequest{
              service: :i_have,
              parameters: [
                object_identifier: %ObjectIdentifier{
                  type: :device,
                  instance: 8
                },
                object_identifier: %ObjectIdentifier{
                  type: :analog_input,
                  instance: 3
                },
                character_string: "OATemp"
              ]
            }} =
             ServicesProtocol.to_apdu(
               %IHave{
                 device: %ObjectIdentifier{
                   type: :device,
                   instance: 8
                 },
                 object: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 3
                 },
                 object_name: "OATemp"
               },
               []
             )
  end
end
