defmodule BACnet.Protocol.ForeignDeviceTableEntryTest do
  alias BACnet.Protocol.ForeignDeviceTableEntry

  use ExUnit.Case, async: true

  @moduletag :bbmd
  @moduletag :bvlc
  @moduletag :protocol_data_structures

  doctest ForeignDeviceTableEntry

  test "decode entry" do
    assert {:ok,
            {%ForeignDeviceTableEntry{
               ip: {192, 168, 1, 100},
               port: 47808,
               time_to_live: 49320,
               remaining_time: 712
             }, <<0xBA, 0xC0, 0xFF, 0xFF, 0xFF, 0xFF>>}} =
             ForeignDeviceTableEntry.decode(
               <<0xC0, 0xA8, 0x01, 0x64, 0xBA, 0xC0, 0xC0, 0xA8, 0x02, 0xC8, 0xBA, 0xC0, 0xFF,
                 0xFF, 0xFF, 0xFF>>
             )
  end

  test "decode entry invalid data" do
    assert {:error, :invalid_data} =
             ForeignDeviceTableEntry.decode(
               <<0xC0, 0xA8, 0x01, 0x64, 0xBA, 0xC0, 0xFF, 0xFF, 0xFF>>
             )
  end

  test "encode entry" do
    assert {:ok, <<0xC0, 0xA8, 0x01, 0x64, 0xBA, 0xC0, 0xC0, 0xA8, 0x02, 0xC8>>} =
             ForeignDeviceTableEntry.encode(%ForeignDeviceTableEntry{
               ip: {192, 168, 1, 100},
               port: 47808,
               time_to_live: 49320,
               remaining_time: 712
             })
  end

  test "encode entry without ttl and remaining" do
    assert {:ok, <<0xC0, 0xA8, 0x01, 0x64, 0xBA, 0xC0>>} =
             ForeignDeviceTableEntry.encode(%ForeignDeviceTableEntry{
               ip: {192, 168, 1, 100},
               port: 47808,
               time_to_live: nil,
               remaining_time: nil
             })
  end

  test "encode entry invalid data" do
    assert {:error, :invalid_data} =
             ForeignDeviceTableEntry.encode(%ForeignDeviceTableEntry{
               ip: 1_244_222,
               port: 47808,
               time_to_live: nil,
               remaining_time: nil
             })
  end
end
