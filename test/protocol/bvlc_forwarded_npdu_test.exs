defmodule BACnet.Protocol.BvlcForwardedNpduTest do
  alias BACnet.Protocol.BvlcForwardedNPDU

  use ExUnit.Case, async: true

  @moduletag :protocol

  doctest BvlcForwardedNPDU

  test "decoding Forwarded NPDU" do
    assert {:ok,
            {%BvlcForwardedNPDU{
               originating_ip: {192, 168, 1, 1},
               originating_port: 47_808
             },
             <<1, 32, 255, 255, 0, 255, 32, 1, 12>>}} ==
             BvlcForwardedNPDU.decode(
               <<192, 168, 1, 1, 186, 192, 1, 32, 255, 255, 0, 255, 32, 1, 12>>
             )
  end

  test "decoding Forwarded NPDU failure" do
    assert {:error, :invalid_data} =
             BvlcForwardedNPDU.decode(<<192, 168, 1, 1, 255>>)
  end

  test "encoding Forwarded NPDU" do
    assert {:ok, <<192, 168, 1, 1, 186, 192>>} ==
             BvlcForwardedNPDU.encode(%BvlcForwardedNPDU{
               originating_ip: {192, 168, 1, 1},
               originating_port: 47_808
             })
  end

  test "encoding Forwarded NPDU failure invalid IP" do
    assert {:error, :invalid_ip} =
             BvlcForwardedNPDU.encode(%BvlcForwardedNPDU{
               originating_ip: nil,
               originating_port: 47_808
             })
  end

  test "encoding Forwarded NPDU failure invalid port" do
    assert {:error, :invalid_npdu} =
             BvlcForwardedNPDU.encode(%BvlcForwardedNPDU{
               originating_ip: {192, 168, 1, 256},
               originating_port: 0
             })
  end
end
