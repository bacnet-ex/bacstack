defmodule BACnet.Protocol.BroadcastDistributionTableEntryTest do
  alias BACnet.Protocol.BroadcastDistributionTableEntry

  use ExUnit.Case, async: true

  @moduletag :bbmd
  @moduletag :bvlc
  @moduletag :protocol_data_structures

  doctest BroadcastDistributionTableEntry

  test "decode entry" do
    assert {:ok,
            {%BroadcastDistributionTableEntry{
               ip: {192, 168, 1, 100},
               port: 47808,
               mask: {255, 255, 255, 255}
             }, <<0xC0, 0xA8, 0x02, 0xC8, 0xBA, 0xC0, 0xFF, 0xFF, 0xFF, 0xFF>>}} =
             BroadcastDistributionTableEntry.decode(
               <<0xC0, 0xA8, 0x01, 0x64, 0xBA, 0xC0, 0xFF, 0xFF, 0xFF, 0xFF, 0xC0, 0xA8, 0x02,
                 0xC8, 0xBA, 0xC0, 0xFF, 0xFF, 0xFF, 0xFF>>
             )
  end

  test "decode entry invalid data" do
    assert {:error, :invalid_data} =
             BroadcastDistributionTableEntry.decode(
               <<0xC0, 0xA8, 0x01, 0x64, 0xBA, 0xC0, 0xFF, 0xFF, 0xFF>>
             )
  end

  test "encode entry" do
    assert {:ok, <<0xC0, 0xA8, 0x01, 0x64, 0xBA, 0xC0, 0xFF, 0xFF, 0xFF, 0xFF>>} =
             BroadcastDistributionTableEntry.encode(%BroadcastDistributionTableEntry{
               ip: {192, 168, 1, 100},
               port: 47808,
               mask: {255, 255, 255, 255}
             })
  end

  test "encode entry invalid data" do
    assert {:error, :invalid_data} =
             BroadcastDistributionTableEntry.encode(%BroadcastDistributionTableEntry{
               ip: 1_244_222,
               port: 47808,
               mask: 1_242_412_312
             })
  end
end
