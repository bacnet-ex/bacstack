defmodule BACnet.Protocol.HostNPortTest do
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.HostNPort

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest HostNPort

  test "parse none host" do
    assert {:ok, {%HostNPort{host: :none, port: 0}, []}} =
             HostNPort.parse([
               {:constructed, {0, {:tagged, {0, <<>>, 0}}, 0}},
               {:tagged, {1, <<0, 0>>, 2}}
             ])
  end

  test "parse IPv4 host" do
    assert {:ok,
            {%HostNPort{
               host: {:ip_address, <<192, 168, 1, 105>>},
               port: 47808
             },
             []}} =
             HostNPort.parse([
               {:constructed, {0, {:tagged, {1, <<192, 168, 1, 105>>, 4}}, 0}},
               {:tagged, {1, <<186, 192>>, 2}}
             ])
  end

  test "parse name host" do
    dns = "router.local"

    assert {:ok,
            {%HostNPort{
               host: {:name, ^dns},
               port: 0xBAC0
             },
             []}} =
             HostNPort.parse([
               {:constructed, {0, {:tagged, {2, <<0, dns::binary>>, byte_size(dns) + 1}}, 0}},
               {:tagged, {1, <<186, 192>>, 2}}
             ])
  end

  test "parse leaves remaining tags" do
    extra = {:unsigned_integer, 99}

    assert {:ok, {%HostNPort{host: :none, port: 1}, [^extra]}} =
             HostNPort.parse([
               {:constructed, {0, {:tagged, {0, <<>>, 0}}, 0}},
               {:tagged, {1, <<0, 1>>, 2}},
               extra
             ])
  end

  test "parse rejects incomplete tags" do
    assert {:error, :invalid_tags} = HostNPort.parse([])
    assert {:error, :invalid_tags} = HostNPort.parse([{:constructed, {0, [], 0}}])
  end

  test "parse rejects non-constructed host tag" do
    # Classic mistake: primitive tag 0 instead of constructed
    assert {:error, :invalid_tags} =
             HostNPort.parse([
               {:tagged, {0, <<>>, 0}},
               {:tagged, {1, <<0>>, 1}}
             ])
  end

  test "parse rejects invalid port" do
    # 65536 as unsigned
    large_port_bin = <<0x01, 0x00, 0x00>>

    assert {:error, :invalid_port} =
             HostNPort.parse([
               {:constructed, {0, {:tagged, {1, <<192, 168, 1, 105>>, 4}}, 0}},
               {:tagged, {1, large_port_bin, 3}}
             ])
  end

  test "parse rejects unknown host choice tag" do
    # constructed host containing an unknown alternative tag 5
    assert {:error, :invalid_host} =
             HostNPort.parse([
               {:constructed, {0, [{:tagged, {5, <<0>>, 1}}], 0}},
               {:tagged, {1, <<186, 192>>, 2}}
             ])
  end

  test "encode none host (constructed outer tag 0)" do
    assert {:ok, tags} = HostNPort.encode(%HostNPort{host: :none, port: 0})

    assert [
             {:constructed, {0, inner, 0}},
             {:tagged, {1, _, _}}
           ] = tags

    # inner must be the NULL choice alternative [0]
    assert {:tagged, {0, _, _}} = inner
  end

  test "encode IPv4 host (constructed outer tag 0)" do
    hnp = %HostNPort{
      host: {:ip_address, <<192, 168, 1, 100>>},
      port: 0xBAC0
    }

    assert {:ok, tags} = HostNPort.encode(hnp)

    assert [
             {:constructed, {0, inner, 0}},
             {:tagged, {1, port_bin, _}}
           ] = tags

    # inner = CHOICE alternative [1] OCTET STRING
    assert {:tagged, {1, <<192, 168, 1, 100>>, 4}} = inner

    assert {:ok, {:unsigned_integer, 0xBAC0}} =
             ApplicationTags.unfold_to_type(:unsigned_integer, port_bin)
  end

  test "encode name host (constructed outer tag 0)" do
    hnp = %HostNPort{
      host: {:name, "bbmd.example.com"},
      port: 47808
    }

    assert {:ok, tags} = HostNPort.encode(hnp)

    assert [
             {:constructed, {0, inner, 0}},
             {:tagged, {1, port_bin, _}}
           ] = tags

    # inner = CHOICE alternative [2] CharacterString
    assert {:tagged, {2, name_bin, _}} = inner

    assert {:ok, {:character_string, "bbmd.example.com"}} =
             ApplicationTags.unfold_to_type(:character_string, name_bin)

    assert {:ok, {:unsigned_integer, 47808}} =
             ApplicationTags.unfold_to_type(:unsigned_integer, port_bin)
  end

  test "encode rejects invalid host" do
    assert {:error, :invalid_host} =
             HostNPort.encode(%HostNPort{host: :invalid, port: 0})

    assert {:error, :invalid_host} =
             HostNPort.encode(%HostNPort{host: {:ip_address, 123}, port: 0})
  end

  test "valid? with none host" do
    assert HostNPort.valid?(%HostNPort{host: :none, port: 0})
    assert HostNPort.valid?(%HostNPort{host: :none, port: 47808})
    assert HostNPort.valid?(%HostNPort{host: :none, port: 65_535})
  end

  test "valid? with IPv4 address" do
    assert HostNPort.valid?(%HostNPort{
             host: {:ip_address, <<192, 168, 1, 10>>},
             port: 0xBAC0
           })
  end

  test "valid? with IPv6 address" do
    ipv6 = <<0x20, 0x01, 0x0D, 0xB8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>

    assert HostNPort.valid?(%HostNPort{
             host: {:ip_address, ipv6},
             port: 47808
           })
  end

  test "valid? with host name" do
    assert HostNPort.valid?(%HostNPort{
             host: {:name, "bbmd.example.com"},
             port: 47808
           })

    assert HostNPort.valid?(%HostNPort{
             host: {:name, "192.168.1.1"},
             port: 47808
           })
  end

  test "valid? rejects invalid values" do
    # bad port
    refute HostNPort.valid?(%HostNPort{host: :none, port: -1})
    refute HostNPort.valid?(%HostNPort{host: :none, port: 65_536})
    refute HostNPort.valid?(%HostNPort{host: :none, port: 1.5})

    # bad IP length
    refute HostNPort.valid?(%HostNPort{
             host: {:ip_address, <<1, 2, 3>>},
             port: 47808
           })

    refute HostNPort.valid?(%HostNPort{
             host: {:ip_address, <<>>},
             port: 47808
           })

    # empty name
    refute HostNPort.valid?(%HostNPort{host: {:name, ""}, port: 47808})

    # wrong host shape
    refute HostNPort.valid?(%HostNPort{host: :ip_address, port: 47808})
    refute HostNPort.valid?(%HostNPort{host: {:ip_address}, port: 47808})
    refute HostNPort.valid?(%HostNPort{host: "hello", port: 47808})
  end

  test "round-trip none" do
    original = %HostNPort{host: :none, port: 0}
    assert {:ok, tags} = HostNPort.encode(original)
    assert {:ok, {decoded, []}} = HostNPort.parse(tags)
    assert decoded == original
  end

  test "round-trip IPv4" do
    original = %HostNPort{
      host: {:ip_address, <<192, 168, 0, 50>>},
      port: 47808
    }

    assert {:ok, tags} = HostNPort.encode(original)
    assert {:ok, {decoded, []}} = HostNPort.parse(tags)
    assert decoded == original
  end

  test "round-trip name" do
    original = %HostNPort{
      host: {:name, "bbmd.ashrae.org"},
      port: 0xBAC0
    }

    assert {:ok, tags} = HostNPort.encode(original)
    assert {:ok, {decoded, []}} = HostNPort.parse(tags)
    assert decoded == original
  end

  test "round-trip IPv6" do
    ipv6 = <<0x20, 0x01, 0x0D, 0xB8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1>>

    original = %HostNPort{
      host: {:ip_address, ipv6},
      port: 47808
    }

    assert {:ok, tags} = HostNPort.encode(original)
    assert {:ok, {decoded, []}} = HostNPort.parse(tags)
    assert decoded == original
  end
end
