defmodule BACnet.Protocol.RouterEntryTest do
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.RouterEntry

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest RouterEntry

  test "parse without performance index" do
    assert {:ok, net_tag} =
             ApplicationTags.create_tag_encoding(0, :unsigned_integer, 100)

    assert {:ok, mac_tag} =
             ApplicationTags.create_tag_encoding(1, :octet_string, <<0xAA, 0xBB>>)

    assert {:ok, status_tag} =
             ApplicationTags.create_tag_encoding(2, :enumerated, 0)

    assert {:ok,
            {%RouterEntry{
               network_number: 100,
               mac_address: <<0xAA, 0xBB>>,
               status: :available,
               performance_index: nil
             }, []}} = RouterEntry.parse([net_tag, mac_tag, status_tag])
  end

  test "parse with performance index" do
    assert {:ok, net_tag} =
             ApplicationTags.create_tag_encoding(0, :unsigned_integer, 2001)

    assert {:ok, mac_tag} =
             ApplicationTags.create_tag_encoding(1, :octet_string, <<0x01>>)

    assert {:ok, status_tag} =
             ApplicationTags.create_tag_encoding(2, :enumerated, 2)

    assert {:ok, perf_tag} =
             ApplicationTags.create_tag_encoding(3, :unsigned_integer, 99)

    assert {:ok,
            {%RouterEntry{
               network_number: 2001,
               mac_address: <<0x01>>,
               status: :disconnected,
               performance_index: 99
             }, []}} = RouterEntry.parse([net_tag, mac_tag, status_tag, perf_tag])
  end

  test "parse leaves remaining tags" do
    assert {:ok, net_tag} =
             ApplicationTags.create_tag_encoding(0, :unsigned_integer, 5)

    assert {:ok, mac_tag} =
             ApplicationTags.create_tag_encoding(1, :octet_string, <<0xFF>>)

    assert {:ok, status_tag} =
             ApplicationTags.create_tag_encoding(2, :enumerated, 1)

    extra = {:null, nil}

    assert {:ok, {%RouterEntry{status: :busy}, [^extra]}} =
             RouterEntry.parse([net_tag, mac_tag, status_tag, extra])
  end

  test "parse rejects incomplete tags" do
    assert {:error, :invalid_tags} = RouterEntry.parse([])
    assert {:error, :invalid_tags} = RouterEntry.parse([{:tagged, {0, <<1>>, 1}}])
  end

  test "parse rejects invalid status value" do
    assert {:ok, net_tag} =
             ApplicationTags.create_tag_encoding(0, :unsigned_integer, 1)

    assert {:ok, mac_tag} =
             ApplicationTags.create_tag_encoding(1, :octet_string, <<0x00>>)

    # enumerated value 99 is not a valid status
    assert {:ok, status_tag} =
             ApplicationTags.create_tag_encoding(2, :enumerated, 99)

    assert {:error, :invalid_status} =
             RouterEntry.parse([net_tag, mac_tag, status_tag])
  end

  test "parse rejects out-of-range network number" do
    # Craft a tagged whose binary decodes to 65536
    large_bin = <<0x01, 0x00, 0x00>>

    assert {:error, :invalid_network_number} =
             RouterEntry.parse([
               {:tagged, {0, large_bin, 3}},
               {:tagged, {1, <<0x00>>, 1}},
               {:tagged, {2, <<0>>, 1}}
             ])
  end

  test "encode without performance index" do
    entry = %RouterEntry{
      network_number: 42,
      mac_address: <<0xC0, 0xA8, 0x01, 0x01, 0xBA, 0xC0>>,
      status: :available,
      performance_index: nil
    }

    assert {:ok, tags} = RouterEntry.encode(entry)

    assert [
             {:tagged, {0, net_bin, _}},
             {:tagged, {1, <<0xC0, 0xA8, 0x01, 0x01, 0xBA, 0xC0>>, 6}},
             {:tagged, {2, status_bin, _}}
           ] = tags

    assert {:ok, {:unsigned_integer, 42}} =
             ApplicationTags.unfold_to_type(:unsigned_integer, net_bin)

    assert {:ok, {:enumerated, 0}} =
             ApplicationTags.unfold_to_type(:enumerated, status_bin)
  end

  test "encode with performance index" do
    entry = %RouterEntry{
      network_number: 1001,
      mac_address: <<0x01, 0x02>>,
      status: :busy,
      performance_index: 17
    }

    assert {:ok, tags} = RouterEntry.encode(entry)

    assert [
             {:tagged, {0, _, _}},
             {:tagged, {1, <<0x01, 0x02>>, 2}},
             {:tagged, {2, status_bin, _}},
             {:tagged, {3, perf_bin, _}}
           ] = tags

    assert {:ok, {:enumerated, 1}} =
             ApplicationTags.unfold_to_type(:enumerated, status_bin)

    assert {:ok, {:unsigned_integer, 17}} =
             ApplicationTags.unfold_to_type(:unsigned_integer, perf_bin)
  end

  test "encode all status values" do
    for {status, expected_int} <- [available: 0, busy: 1, disconnected: 2] do
      entry = %RouterEntry{
        network_number: 1,
        mac_address: <<0x00>>,
        status: status,
        performance_index: nil
      }

      assert {:ok, tags} = RouterEntry.encode(entry)
      assert {:tagged, {2, status_bin, _}} = Enum.at(tags, 2)

      assert {:ok, {:enumerated, ^expected_int}} =
               ApplicationTags.unfold_to_type(:enumerated, status_bin)
    end
  end

  test "encode rejects invalid status" do
    assert {:error, :invalid_status} =
             RouterEntry.encode(%RouterEntry{
               network_number: 1,
               mac_address: <<1>>,
               status: :invalid,
               performance_index: nil
             })
  end

  test "encode rejects invalid performance index" do
    assert {:error, :invalid_performance_index} =
             RouterEntry.encode(%RouterEntry{
               network_number: 1,
               mac_address: <<1>>,
               status: :available,
               performance_index: 300
             })
  end

  test "encode rejects invalid network number" do
    assert {:error, :invalid_data} =
             RouterEntry.encode(%RouterEntry{
               network_number: 70_000,
               mac_address: <<1>>,
               status: :available,
               performance_index: nil
             })
  end

  test "valid? accepts complete entries" do
    assert RouterEntry.valid?(%RouterEntry{
             network_number: 1001,
             mac_address: <<192, 168, 1, 1, 0xBA, 0xC0>>,
             status: :available,
             performance_index: 50
           })

    assert RouterEntry.valid?(%RouterEntry{
             network_number: 0,
             mac_address: <<0x01>>,
             status: :busy,
             performance_index: nil
           })

    assert RouterEntry.valid?(%RouterEntry{
             network_number: 65_535,
             mac_address: <<0xFF, 0xFF>>,
             status: :disconnected,
             performance_index: 255
           })
  end

  test "valid? rejects invalid values" do
    # bad network number
    refute RouterEntry.valid?(%RouterEntry{
             network_number: -1,
             mac_address: <<1>>,
             status: :available,
             performance_index: nil
           })

    refute RouterEntry.valid?(%RouterEntry{
             network_number: 65_536,
             mac_address: <<1>>,
             status: :available,
             performance_index: nil
           })

    # non-binary MAC
    refute RouterEntry.valid?(%RouterEntry{
             network_number: 1,
             mac_address: :none,
             status: :available,
             performance_index: nil
           })

    # invalid status atom
    refute RouterEntry.valid?(%RouterEntry{
             network_number: 1,
             mac_address: <<1>>,
             status: :unknown,
             performance_index: nil
           })

    # bad performance index
    refute RouterEntry.valid?(%RouterEntry{
             network_number: 1,
             mac_address: <<1>>,
             status: :available,
             performance_index: -1
           })

    refute RouterEntry.valid?(%RouterEntry{
             network_number: 1,
             mac_address: <<1>>,
             status: :available,
             performance_index: 256
           })
  end

  test "round-trip without performance index" do
    original = %RouterEntry{
      network_number: 300,
      mac_address: <<0xDE, 0xAD, 0xBE, 0xEF>>,
      status: :available,
      performance_index: nil
    }

    assert {:ok, tags} = RouterEntry.encode(original)
    assert {:ok, {decoded, []}} = RouterEntry.parse(tags)
    assert decoded == original
  end

  test "round-trip with performance index" do
    original = %RouterEntry{
      network_number: 4001,
      mac_address: <<0x11, 0x22, 0x33, 0x44, 0x55, 0x66>>,
      status: :busy,
      performance_index: 128
    }

    assert {:ok, tags} = RouterEntry.encode(original)
    assert {:ok, {decoded, []}} = RouterEntry.parse(tags)
    assert decoded == original
  end

  test "round-trip all statuses" do
    for status <- [:available, :busy, :disconnected] do
      original = %RouterEntry{
        network_number: 7,
        mac_address: <<0x01>>,
        status: status,
        performance_index: 0
      }

      assert {:ok, tags} = RouterEntry.encode(original)
      assert {:ok, {decoded, []}} = RouterEntry.parse(tags)
      assert decoded == original
    end
  end
end
