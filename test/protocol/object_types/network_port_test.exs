defmodule BACnet.Test.Protocol.ObjectTypes.NetworkPortTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsUtility
  # alias BACnet.Protocol.ObjectTypes.NetworkPort

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_network_port

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  for property <- [
        :ip_address,
        :ip_subnet_mask,
        :ip_default_gateway,
        :bacnet_ip_multicast_address,
        :ip_dns_server,
        :ip_dhcp_server
      ] do
    ip =
      nil
      |> List.duplicate(4)
      |> Enum.map(fn _el -> Enum.random(1..254//1) end)

    ip_tup = Macro.escape(List.to_tuple(ip))
    ip_bin = :binary.list_to_bin(ip)

    test "verify network port #{property} decoding" do
      assert {:ok, unquote(ip_tup)} =
               ObjectsUtility.cast_property_to_value(
                 %ObjectIdentifier{type: :network_port, instance: 0},
                 unquote(property),
                 %Encoding{
                   encoding: :primitive,
                   extras: [],
                   type: :octet_string,
                   value: unquote(ip_bin)
                 },
                 allow_partial: true
               )
    end

    test "verify network port #{property} encoding" do
      assert {:ok,
              %Encoding{
                encoding: :primitive,
                extras: [],
                type: :octet_string,
                value: unquote(ip_bin)
              }} =
               ObjectsUtility.cast_value_to_property(
                 %ObjectIdentifier{type: :network_port, instance: 0},
                 unquote(property),
                 unquote(ip_tup),
                 allow_partial: true
               )
    end
  end

  for property <- [:ipv6_address, :ipv6_default_gateway, :ipv6_dns_server, :ipv6_dhcp_server] do
    ip =
      nil
      |> List.duplicate(8)
      |> Enum.map(fn _el -> Enum.random(1..65_534//1) end)

    ip_tup = Macro.escape(List.to_tuple(ip))
    ip_bin = Enum.reduce(ip, <<>>, &<<&2::binary, &1::size(16)>>)

    test "verify network port #{property} decoding" do
      assert {:ok, unquote(ip_tup)} =
               ObjectsUtility.cast_property_to_value(
                 %ObjectIdentifier{type: :network_port, instance: 0},
                 unquote(property),
                 %Encoding{
                   encoding: :primitive,
                   extras: [],
                   type: :octet_string,
                   value: unquote(ip_bin)
                 },
                 allow_partial: true
               )
    end

    test "verify network port #{property} encoding" do
      assert {:ok,
              %Encoding{
                encoding: :primitive,
                extras: [],
                type: :octet_string,
                value: unquote(ip_bin)
              }} =
               ObjectsUtility.cast_value_to_property(
                 %ObjectIdentifier{type: :network_port, instance: 0},
                 unquote(property),
                 unquote(ip_tup),
                 allow_partial: true
               )
    end
  end

  test "verify network port bacnet_ipv6_multicast_address decoding" do
    ip =
      nil
      |> List.duplicate(8)
      |> Enum.map(fn _el -> Enum.random(1..65_534//1) end)

    ip_tup = List.to_tuple(ip)
    ip_bin = Enum.reduce(ip, <<>>, &<<&2::binary, &1::size(16)>>)
    port = Enum.random(1..65_535//1)
    final = {ip_tup, port}

    assert {:ok, ^final} =
             ObjectsUtility.cast_property_to_value(
               %ObjectIdentifier{type: :network_port, instance: 0},
               :bacnet_ipv6_multicast_address,
               %Encoding{
                 encoding: :primitive,
                 extras: [],
                 type: :octet_string,
                 value: <<ip_bin::binary, port::size(16)>>
               },
               allow_partial: true
             )
  end

  test "verify network port bacnet_ipv6_multicast_address encoding" do
    ip =
      nil
      |> List.duplicate(8)
      |> Enum.map(fn _el -> Enum.random(1..65_534//1) end)

    ip_tup = List.to_tuple(ip)
    ip_bin = Enum.reduce(ip, <<>>, &<<&2::binary, &1::size(16)>>)
    port = Enum.random(1..65_535//1)
    bin = <<ip_bin::binary, port::size(16)>>

    assert {:ok,
            %Encoding{
              encoding: :primitive,
              extras: [],
              type: :octet_string,
              value: ^bin
            }} =
             ObjectsUtility.cast_value_to_property(
               %ObjectIdentifier{type: :network_port, instance: 0},
               :bacnet_ipv6_multicast_address,
               {ip_tup, port},
               allow_partial: true
             )
  end
end
