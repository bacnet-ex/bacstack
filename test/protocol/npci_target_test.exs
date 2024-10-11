defmodule BACnet.Protocol.NpciTargetTest do
  alias BACnet.Protocol.NpciTarget

  require NpciTarget
  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest NpciTarget

  test "is global broadcast" do
    assert true == NpciTarget.is_global_broadcast(%NpciTarget{net: 65_535, address: 1})
    assert true == NpciTarget.is_global_broadcast(%NpciTarget{net: 65_535, address: nil})
    assert false == NpciTarget.is_global_broadcast(%NpciTarget{net: 1, address: 1})
    assert false == NpciTarget.is_global_broadcast(%NpciTarget{net: 1, address: nil})
  end

  test "is remote broadcast" do
    assert true == NpciTarget.is_remote_broadcast(%NpciTarget{net: 65_535, address: nil})
    assert true == NpciTarget.is_remote_broadcast(%NpciTarget{net: 1, address: nil})
    assert false == NpciTarget.is_remote_broadcast(%NpciTarget{net: 65_535, address: 1})
    assert false == NpciTarget.is_remote_broadcast(%NpciTarget{net: 1, address: 1})
  end

  test "is remote station" do
    assert true == NpciTarget.is_remote_station(%NpciTarget{net: 65_534, address: 1})
    assert true == NpciTarget.is_remote_station(%NpciTarget{net: 1, address: 1})
    assert false == NpciTarget.is_remote_station(%NpciTarget{net: 65_535, address: 1})
    assert false == NpciTarget.is_remote_station(%NpciTarget{net: 1, address: nil})
  end
end
