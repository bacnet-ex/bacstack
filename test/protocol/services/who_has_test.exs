defmodule BACnet.Test.Protocol.Services.WhoHasTest do
  alias BACnet.Protocol.APDU.UnconfirmedServiceRequest
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol
  alias BACnet.Protocol.Services.WhoHas

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest WhoHas

  test "get name" do
    assert :who_has == WhoHas.get_name()
  end

  test "is confirmed" do
    assert false == WhoHas.is_confirmed()
  end

  test "decoding WhoHas by name" do
    assert {:ok,
            %WhoHas{
              device_id_low_limit: nil,
              device_id_high_limit: nil,
              object: "OATemp"
            }} =
             WhoHas.from_apdu(%UnconfirmedServiceRequest{
               service: :who_has,
               parameters: [
                 tagged: {3, <<0, 79, 65, 84, 101, 109, 112>>, 7}
               ]
             })
  end

  test "decoding WhoHas by identifier" do
    assert {:ok,
            %WhoHas{
              device_id_low_limit: nil,
              device_id_high_limit: nil,
              object: %ObjectIdentifier{
                type: :analog_input,
                instance: 3
              }
            }} =
             WhoHas.from_apdu(%UnconfirmedServiceRequest{
               service: :who_has,
               parameters: [
                 tagged: {2, <<0, 0, 0, 3>>, 4}
               ]
             })
  end

  test "decoding WhoHas with optionals" do
    assert {:ok,
            %WhoHas{
              device_id_low_limit: 134_224_227,
              device_id_high_limit: 167_778_659,
              object: %ObjectIdentifier{
                type: :analog_input,
                instance: 3
              }
            }} =
             WhoHas.from_apdu(%UnconfirmedServiceRequest{
               service: :who_has,
               parameters: [
                 tagged: {0, <<8, 0, 25, 99>>, 4},
                 tagged: {1, <<10, 0, 25, 99>>, 4},
                 tagged: {2, <<0, 0, 0, 3>>, 4}
               ]
             })
  end

  test "decoding WhoHas invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             WhoHas.from_apdu(%UnconfirmedServiceRequest{
               service: :who_has,
               parameters: []
             })
  end

  test "decoding WhoHas invalid APDU" do
    assert {:error, :invalid_request} =
             WhoHas.from_apdu(%UnconfirmedServiceRequest{
               service: :who_is,
               parameters: []
             })
  end

  test "encoding WhoHas by name" do
    assert {:ok,
            %UnconfirmedServiceRequest{
              service: :who_has,
              parameters: [
                tagged: {3, <<0, 79, 65, 84, 101, 109, 112>>, 7}
              ]
            }} =
             WhoHas.to_apdu(
               %WhoHas{
                 device_id_low_limit: nil,
                 device_id_high_limit: nil,
                 object: "OATemp"
               },
               []
             )
  end

  test "encoding WhoHas by identifier" do
    assert {:ok,
            %UnconfirmedServiceRequest{
              service: :who_has,
              parameters: [
                tagged: {2, <<0, 0, 0, 3>>, 4}
              ]
            }} =
             WhoHas.to_apdu(
               %WhoHas{
                 device_id_low_limit: nil,
                 device_id_high_limit: nil,
                 object: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 3
                 }
               },
               []
             )
  end

  test "encoding WhoHas with optionals" do
    assert {:ok,
            %UnconfirmedServiceRequest{
              service: :who_has,
              parameters: [
                tagged: {0, <<3, 107, 227>>, 3},
                tagged: {1, <<11, 225, 163>>, 3},
                tagged: {2, <<0, 0, 0, 3>>, 4}
              ]
            }} =
             WhoHas.to_apdu(
               %WhoHas{
                 device_id_low_limit: 224_227,
                 device_id_high_limit: 778_659,
                 object: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 3
                 }
               },
               []
             )
  end

  test "encoding WhoHas requires both 1" do
    assert_raise ArgumentError, fn ->
      WhoHas.to_apdu(
        %WhoHas{
          device_id_low_limit: 224_227,
          device_id_high_limit: nil,
          object: nil
        },
        []
      )
    end
  end

  test "encoding WhoHas requires both 2" do
    assert_raise ArgumentError, fn ->
      WhoHas.to_apdu(
        %WhoHas{
          device_id_low_limit: nil,
          device_id_high_limit: 224_227,
          object: nil
        },
        []
      )
    end
  end

  test "encoding WhoHas low_limit must be smaller or equal to high_limit" do
    assert_raise ArgumentError, fn ->
      WhoHas.to_apdu(
        %WhoHas{
          device_id_low_limit: 224_230,
          device_id_high_limit: 224_227,
          object: nil
        },
        []
      )
    end
  end

  test "encoding WhoHas low_limit too large" do
    assert_raise ArgumentError, fn ->
      WhoHas.to_apdu(
        %WhoHas{
          device_id_low_limit: 4_194_304,
          device_id_high_limit: 134_224_227,
          object: "nil"
        },
        []
      )
    end
  end

  test "encoding WhoHas high_limit too large" do
    assert_raise ArgumentError, fn ->
      WhoHas.to_apdu(
        %WhoHas{
          device_id_low_limit: 1,
          device_id_high_limit: 4_194_304,
          object: "nil"
        },
        []
      )
    end
  end

  test "encoding WhoHas obect name must be valid UTF-8" do
    assert_raise ArgumentError, fn ->
      WhoHas.to_apdu(
        %WhoHas{
          device_id_low_limit: nil,
          device_id_high_limit: nil,
          object: <<0xC3, 0x28>>
        },
        []
      )
    end
  end

  test "encoding WhoHas obect name must be string or object identifier" do
    assert_raise ArgumentError, fn ->
      WhoHas.to_apdu(
        %WhoHas{
          device_id_low_limit: nil,
          device_id_high_limit: nil,
          object: 512
        },
        []
      )
    end
  end

  test "protocol implementation get name" do
    assert :who_has ==
             ServicesProtocol.get_name(%WhoHas{
               device_id_low_limit: 134_224_227,
               device_id_high_limit: 167_778_659,
               object: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 3
               }
             })
  end

  test "protocol implementation is confirmed" do
    assert false ==
             ServicesProtocol.is_confirmed(%WhoHas{
               device_id_low_limit: 134_224_227,
               device_id_high_limit: 167_778_659,
               object: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 3
               }
             })
  end

  test "protocol implementation to APDU" do
    assert {:ok,
            %UnconfirmedServiceRequest{
              service: :who_has,
              parameters: [
                tagged: {0, <<3, 107, 227>>, 3},
                tagged: {1, <<11, 225, 163>>, 3},
                tagged: {2, <<0, 0, 0, 3>>, 4}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %WhoHas{
                 device_id_low_limit: 224_227,
                 device_id_high_limit: 778_659,
                 object: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 3
                 }
               },
               []
             )
  end
end
