defmodule BACnet.Test.Protocol.ObjectTypes.NetworkPortTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectTypes.NetworkPort

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_network_port

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "network configuration updates mark changes pending while descriptive updates do not" do
    {:ok, object} =
      NetworkPort.create(1, "port", %{
        network_type: :ptp,
        protocol_level: :physical,
        description: "old",
        network_number: 1
      })

    refute object.changes_pending

    assert {:ok, %NetworkPort{description: "new", changes_pending: false}} =
             NetworkPort.update_property(object, :description, "new")

    assert {:ok, %NetworkPort{network_number: 2, changes_pending: true}} =
             NetworkPort.update_property(object, :network_number, 2)

    assert {:error, {:invalid_property_type, :network_number}} =
             NetworkPort.update_property(object, :network_number, -1)
  end

  test "automatic address configuration controls IPv4 and IPv6 writability" do
    {:ok, object} =
      NetworkPort.create(1, "port", %{
        network_type: :ptp,
        protocol_level: :physical,
        ip_dhcp_enable: false,
        ipv6_auto_addressing_enable: false,
        description: "port"
      })

    for property <- [
          :ip_address,
          :ip_subnet_mask,
          :ip_default_gateway,
          :ip_dns_server,
          :ipv6_address,
          :ipv6_prefix_length,
          :ipv6_default_gateway,
          :ipv6_dns_server
        ] do
      assert NetworkPort.property_writable?(object, property)
    end

    {:ok, automatic} = NetworkPort.update_property(object, :ip_dhcp_enable, true)
    {:ok, automatic} = NetworkPort.update_property(automatic, :ipv6_auto_addressing_enable, true)

    for property <- [
          :ip_address,
          :ip_subnet_mask,
          :ip_default_gateway,
          :ip_dns_server,
          :ipv6_address,
          :ipv6_prefix_length,
          :ipv6_default_gateway,
          :ipv6_dns_server
        ] do
      refute NetworkPort.property_writable?(automatic, property)
    end

    assert NetworkPort.property_writable?(object, :mac_address)
    refute NetworkPort.property_writable?(%{object | network_type: :ipv4}, :mac_address)
    refute NetworkPort.property_writable?(%{object | network_type: :ipv6}, :mac_address)
    assert NetworkPort.property_writable?(object, :description)
    refute NetworkPort.property_writable?(object, :network_type)
    refute NetworkPort.property_writable?(object, :unknown_property)
  end

  test "IP decoding handles unused addresses and rejects malformed lengths" do
    object_id = %ObjectIdentifier{type: :network_port, instance: 1}

    for {property, empty} <- [
          {:ip_address, {0, 0, 0, 0}},
          {:bacnet_ipv6_multicast_address, {{0, 0, 0, 0, 0, 0, 0, 0}, 0}}
        ] do
      assert {:ok, ^empty} =
               ObjectsUtility.cast_property_to_value(
                 object_id,
                 property,
                 Encoding.create!({:octet_string, <<>>})
               )

      assert {:error, {:invalid_tags, {^property, %Encoding{}}}} =
               ObjectsUtility.cast_property_to_value(
                 object_id,
                 property,
                 Encoding.create!({:octet_string, <<1, 2, 3>>})
               )
    end

    assert {:error, {:invalid_property_value, {:ipv6_address, :invalid}}} =
             ObjectsUtility.cast_value_to_property(object_id, :ipv6_address, :invalid)

    assert {:error, {:invalid_property_value, {:ip_address, :invalid}}} =
             ObjectsUtility.cast_value_to_property(object_id, :ip_address, :invalid)
  end

  test "IPv4 encoder supports port suffixes at both port boundaries" do
    for port <- [0, 65_535] do
      expected = <<192, 0, 2, 1, port::16>>

      assert {:ok, %Encoding{type: :octet_string, value: ^expected}} =
               ObjectsUtility.cast_value_to_property(
                 %ObjectIdentifier{type: :network_port, instance: 1},
                 :ip_address,
                 {{192, 0, 2, 1}, port}
               )
    end
  end

  test "IPv6 multicast addresses validate address words and port ranges" do
    {:ok, object} =
      NetworkPort.create(1, "port", %{network_type: :ptp, protocol_level: :physical})

    for value <- [{{65_535, 0, 0, 0, 0, 0, 0, 1}, 0}, {{0, 0, 0, 0, 0, 0, 0, 0}, 65_535}] do
      assert {:ok, %NetworkPort{bacnet_ipv6_multicast_address: ^value}} =
               NetworkPort.add_property(object, :bacnet_ipv6_multicast_address, value)
    end

    for value <- [
          {{65_536, 0, 0, 0, 0, 0, 0, 1}, 47_808},
          {{0, 0, 0, 0, 0, 0, 0, 1}, -1},
          {{0, 0, 0, 0, 0, 0, 0, 1}, 65_536},
          {:invalid, 47_808}
        ] do
      assert {:error, {:value_failed_property_validation, :bacnet_ipv6_multicast_address}} =
               NetworkPort.add_property(object, :bacnet_ipv6_multicast_address, value)
    end

    assert {:ok, %NetworkPort{ip_dns_server: %BACnetArray{}}} =
             NetworkPort.add_property(object, :ip_dns_server, BACnetArray.new())
  end

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
