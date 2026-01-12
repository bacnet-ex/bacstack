defmodule BACnet.Test.Protocol.Services.WhoIsTest do
  alias BACnet.Protocol.APDU.UnconfirmedServiceRequest
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol
  alias BACnet.Protocol.Services.WhoIs

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest WhoIs

  test "get name" do
    assert :who_is == WhoIs.get_name()
  end

  test "is confirmed" do
    assert false == WhoIs.is_confirmed()
  end

  test "decoding WhoIs" do
    assert {:ok,
            %WhoIs{
              device_id_low_limit: nil,
              device_id_high_limit: nil
            }} =
             WhoIs.from_apdu(%UnconfirmedServiceRequest{
               service: :who_is,
               parameters: []
             })
  end

  test "decoding WhoIs with optionals" do
    assert {:ok,
            %WhoIs{
              device_id_low_limit: 50,
              device_id_high_limit: 255
            }} =
             WhoIs.from_apdu(%UnconfirmedServiceRequest{
               service: :who_is,
               parameters: [
                 tagged: {0, <<50>>, 1},
                 tagged: {1, <<255>>, 1}
               ]
             })
  end

  test "decoding WhoIs invalid APDU" do
    assert {:error, :invalid_request} =
             WhoIs.from_apdu(%UnconfirmedServiceRequest{
               service: :i_am,
               parameters: []
             })
  end

  test "encoding WhoIs" do
    assert {:ok,
            %UnconfirmedServiceRequest{
              service: :who_is,
              parameters: []
            }} =
             WhoIs.to_apdu(
               %WhoIs{
                 device_id_low_limit: nil,
                 device_id_high_limit: nil
               },
               []
             )
  end

  test "encoding WhoIs with optionals" do
    assert {:ok,
            %UnconfirmedServiceRequest{
              service: :who_is,
              parameters: [
                tagged: {0, <<50>>, 1},
                tagged: {1, <<255>>, 1}
              ]
            }} =
             WhoIs.to_apdu(
               %WhoIs{
                 device_id_low_limit: 50,
                 device_id_high_limit: 255
               },
               []
             )
  end

  test "encoding WhoIs requires both" do
    assert_raise ArgumentError, fn ->
      WhoIs.to_apdu(
        %WhoIs{
          device_id_low_limit: 53_532,
          device_id_high_limit: nil
        },
        []
      )
    end
  end

  test "encoding WhoIs requires both 2" do
    assert_raise ArgumentError, fn ->
      WhoIs.to_apdu(
        %WhoIs{
          device_id_low_limit: nil,
          device_id_high_limit: 532_523
        },
        []
      )
    end
  end

  test "encoding WhoIs low_limit must be smaller or equal than high_limit" do
    assert_raise ArgumentError, fn ->
      WhoIs.to_apdu(
        %WhoIs{
          device_id_low_limit: 523,
          device_id_high_limit: 500
        },
        []
      )
    end
  end

  test "encoding WhoIs low_limit too large" do
    assert_raise ArgumentError, fn ->
      WhoIs.to_apdu(
        %WhoIs{
          device_id_low_limit: 4_194_304,
          device_id_high_limit: 500_000_000
        },
        []
      )
    end
  end

  test "encoding WhoIs high_limit too large" do
    assert_raise ArgumentError, fn ->
      WhoIs.to_apdu(
        %WhoIs{
          device_id_low_limit: 523,
          device_id_high_limit: 4_194_304
        },
        []
      )
    end
  end

  test "protocol implementation get name" do
    assert :who_is ==
             ServicesProtocol.get_name(%WhoIs{
               device_id_low_limit: 50,
               device_id_high_limit: 255
             })
  end

  test "protocol implementation is confirmed" do
    assert false ==
             ServicesProtocol.is_confirmed(%WhoIs{
               device_id_low_limit: 50,
               device_id_high_limit: 255
             })
  end

  test "protocol implementation to APDU" do
    assert {:ok,
            %UnconfirmedServiceRequest{
              service: :who_is,
              parameters: [
                tagged: {0, <<50>>, 1},
                tagged: {1, <<255>>, 1}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %WhoIs{
                 device_id_low_limit: 50,
                 device_id_high_limit: 255
               },
               []
             )
  end
end
