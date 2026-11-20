defmodule BACnet.ProtocolTest do
  alias BACnet.Protocol
  alias BACnet.Protocol.BvlcForwardedNPDU
  alias BACnet.Protocol.BvlcFunction
  alias BACnet.Protocol.BvlcResult
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.NetworkLayerProtocolMessage
  alias BACnet.Protocol.NPCI
  alias BACnet.Protocol.NpciTarget

  require Constants
  use ExUnit.Case, async: true

  @moduletag :protocol

  doctest Protocol

  test "decoding BACnet Virtual Link Layer IPv4 original unicast" do
    assert {:ok, {0, :original_unicast, <<1, 32, 255, 255, 0, 255, 32, 1, 12>>}} ==
             Protocol.decode_bvll(
               Constants.macro_by_name(:bvll, :type_bacnet_ipv4),
               10,
               <<1, 32, 255, 255, 0, 255, 32, 1, 12>>
             )
  end

  test "decoding BACnet Virtual Link Layer IPv4 original broadcast" do
    assert {:ok, {0, :original_broadcast, <<1, 32, 255, 255, 0, 255, 32, 1, 12>>}} ==
             Protocol.decode_bvll(
               Constants.macro_by_name(:bvll, :type_bacnet_ipv4),
               11,
               <<1, 32, 255, 255, 0, 255, 32, 1, 12>>
             )
  end

  test "decoding BACnet Virtual Link Layer IPv4 BVLC Result (successful completion)" do
    assert {
             :ok,
             {2, %BvlcResult{result_code: :successful_completion}, <<1, 32>>}
           } ==
             Protocol.decode_bvll(
               Constants.macro_by_name(:bvll, :type_bacnet_ipv4),
               0,
               <<0, 0, 1, 32>>
             )
  end

  test "decoding BACnet Virtual Link Layer IPv4 unknown result code" do
    assert {:error, {:unknown_result_code, 65_535}} =
             Protocol.decode_bvll(
               Constants.macro_by_name(:bvll, :type_bacnet_ipv4),
               0,
               <<255, 255>>
             )
  end

  test "decoding BACnet Virtual Link Layer IPv4 BVLC Result failure" do
    assert {:error, :insufficient_bvlc_data} =
             Protocol.decode_bvll(Constants.macro_by_name(:bvll, :type_bacnet_ipv4), 0, <<>>)
  end

  test "decoding BACnet Virtual Link Layer IPv4 Forwarded NPDU" do
    assert {:ok,
            {6,
             %BvlcForwardedNPDU{
               originating_ip: {192, 168, 1, 1},
               originating_port: 47_808
             }, <<1, 32, 255, 255, 0, 255, 32, 1, 12>>}} ==
             Protocol.decode_bvll(
               Constants.macro_by_name(:bvll, :type_bacnet_ipv4),
               4,
               <<192, 168, 1, 1, 186, 192, 1, 32, 255, 255, 0, 255, 32, 1, 12>>
             )
  end

  test "decoding BACnet Virtual Link Layer IPv4 Forwarded NPDU failure" do
    assert {:error, :invalid_data} =
             Protocol.decode_bvll(
               Constants.macro_by_name(:bvll, :type_bacnet_ipv4),
               4,
               <<192, 168, 1, 1, 255>>
             )
  end

  test "decoding BACnet Virtual Link Layer IPv4 distribute original broadcast" do
    assert {:ok, {0, :distribute_broadcast_to_network, <<1, 32, 255, 255, 0, 255, 32, 1, 12>>}} ==
             Protocol.decode_bvll(
               Constants.macro_by_name(:bvll, :type_bacnet_ipv4),
               9,
               <<1, 32, 255, 255, 0, 255, 32, 1, 12>>
             )
  end

  test "decoding BACnet Virtual Link Layer IPv4 BVLC Function" do
    assert {:ok, {2, %BvlcFunction{}, <<>>}} =
             Protocol.decode_bvll(
               Constants.macro_by_name(:bvll, :type_bacnet_ipv4),
               5,
               <<234, 96>>
             )
  end

  test "decoding BACnet Virtual Link Layer IPv4 unsupported BVLC" do
    assert {:error, :unsupported_bvlc_function} =
             Protocol.decode_bvll(
               Constants.macro_by_name(:bvll, :type_bacnet_ipv4),
               12,
               <<1, 32>>
             )
  end

  test "NPCI decoding preserves both addresses, their lengths, hop count and payload" do
    for length <- 1..7,
        address <- [:binary.copy(<<0>>, length), <<0, :binary.copy(<<255>>, length - 1)::binary>>] do
      wire =
        <<1, 40, 0, 1, length, address::binary, 255, 254, length, address::binary, 17, 0x10, 8>>

      assert {:ok, {npci, <<0x10, 8>>}} = Protocol.decode_npci(wire)
      assert npci.destination == %NpciTarget{net: 1, address: address}
      assert npci.source == %NpciTarget{net: 65_534, address: address}
      assert npci.hopcount == 17
      assert IO.iodata_to_binary([NPCI.encode(npci), <<0x10, 8>>]) == wire
    end
  end

  test "NPCI decoding accepts the network-number boundaries" do
    for dnet <- [1, 65_535], snet <- [1, 65_534] do
      assert {:ok, {%NPCI{destination: destination, source: source}, <<>>}} =
               Protocol.decode_npci(<<1, 40, dnet::16, 0, snet::16, 1, 0, 255>>)

      assert destination == %NpciTarget{net: dnet, address: nil}
      assert source == %NpciTarget{net: snet, address: <<0>>}
    end
  end

  test "NPCI decoding rejects reserved network numbers and empty source addresses" do
    assert {:error, :invalid_destination} = Protocol.decode_npci(<<1, 32, 0, 0, 0, 255>>)

    for snet <- [0, 65_535] do
      assert {:error, :invalid_source} = Protocol.decode_npci(<<1, 8, snet::16, 1, 42>>)
    end

    assert {:error, :invalid_source} = Protocol.decode_npci(<<1, 8, 0, 1, 0, 0x10, 8>>)
  end

  test "NPCI decoding rejects oversized and truncated target addresses" do
    for {control, reason} <- [{32, :invalid_destination}, {8, :invalid_source}] do
      assert {:error, ^reason} = Protocol.decode_npci(<<1, control, 0, 1, 8, 0::64, 255>>)
      assert {:error, ^reason} = Protocol.decode_npci(<<1, control, 0, 1, 255, 0::2040, 255>>)

      for length <- 1..7 do
        truncated = :binary.copy(<<0>>, length - 1)

        assert {:error, ^reason} =
                 Protocol.decode_npci(<<1, control, 0, 1, length, truncated::binary>>)
      end
    end
  end

  test "decoding BACnet NPCI invalid gracefully" do
    assert {:error, :invalid_npci} = Protocol.decode_npci(<<10, 08>>)
  end

  test "decoding BACnet NPCI without reply" do
    assert {:ok,
            {%NPCI{
               priority: :normal,
               expects_reply: false,
               destination: nil,
               source: nil,
               hopcount: nil,
               is_network_message: false
             }, <<48, 1, 12, 12>>}} = Protocol.decode_npci(<<1, 0, 48, 1, 12, 12>>)
  end

  test "decoding BACnet NPCI with reply" do
    assert {:ok,
            {%NPCI{
               priority: :normal,
               expects_reply: true,
               destination: nil,
               source: nil,
               hopcount: nil,
               is_network_message: false
             }, <<0, 0, 0, 16, 12>>}} = Protocol.decode_npci(<<1, 4, 0, 0, 0, 16, 12>>)
  end

  test "decoding BACnet NPCI with source" do
    assert {:ok,
            {%NPCI{
               priority: :normal,
               expects_reply: false,
               destination: nil,
               source: %NpciTarget{net: 3, address: <<108>>},
               hopcount: nil,
               is_network_message: false
             }, <<48, 16, 6>>}} = Protocol.decode_npci(<<1, 8, 0, 3, 1, 108, 48, 16, 6>>)
  end

  test "decoding BACnet NPCI with invalid source" do
    assert {:error, :invalid_source} = Protocol.decode_npci(<<1, 8, 0, 3, 1>>)
  end

  test "decoding BACnet NPCI with destination" do
    assert {:ok,
            {%NPCI{
               priority: :normal,
               expects_reply: true,
               destination: %NpciTarget{net: 2, address: <<85>>},
               source: nil,
               hopcount: 255,
               is_network_message: false
             }, <<80, 2>>}} = Protocol.decode_npci(<<1, 36, 0, 2, 1, 85, 255, 80, 2>>)
  end

  test "decoding BACnet NPCI with destination address nil" do
    assert {:ok,
            {%NPCI{
               priority: :normal,
               expects_reply: false,
               destination: %NpciTarget{net: 65_535, address: nil},
               source: nil,
               hopcount: 255,
               is_network_message: false
             }, <<32, 1, 12>>}} = Protocol.decode_npci(<<1, 32, 255, 255, 0, 255, 32, 1, 12>>)
  end

  test "decoding BACnet NPCI with invalid destination" do
    assert {:error, :invalid_destination} = Protocol.decode_npci(<<1, 36, 0, 2, 1>>)
  end

  test "decoding BACnet NPCI with hopcount" do
    assert {:ok,
            {%NPCI{
               priority: :normal,
               expects_reply: false,
               destination: %NpciTarget{net: 65_535, address: nil},
               source: nil,
               hopcount: 14,
               is_network_message: false
             }, <<>>}} = Protocol.decode_npci(<<1, 32, 255, 255, 0, 14>>)
  end

  test "decoding BACnet NPCI with invalid hopcount" do
    assert {:error, :invalid_hopcount} = Protocol.decode_npci(<<1, 32, 255, 255, 0>>)
  end

  test "decoding BACnet NPCI with priority normal" do
    assert {:ok,
            {%NPCI{
               priority: :normal,
               expects_reply: false,
               destination: nil,
               source: nil,
               hopcount: nil,
               is_network_message: false
             }, <<>>}} = Protocol.decode_npci(<<1, 0>>)
  end

  test "decoding BACnet NPCI with priority urgent" do
    assert {:ok,
            {%NPCI{
               priority: :urgent,
               expects_reply: false,
               destination: nil,
               source: nil,
               hopcount: nil,
               is_network_message: false
             }, <<>>}} = Protocol.decode_npci(<<1, 1>>)
  end

  test "decoding BACnet NPCI with priority critical equipment" do
    assert {:ok,
            {%NPCI{
               priority: :critical_equipment_message,
               expects_reply: false,
               destination: nil,
               source: nil,
               hopcount: nil,
               is_network_message: false
             }, <<>>}} = Protocol.decode_npci(<<1, 2>>)
  end

  test "decoding BACnet NPCI with priority life safety" do
    assert {:ok,
            {%NPCI{
               priority: :life_safety_message,
               expects_reply: false,
               destination: nil,
               source: nil,
               hopcount: nil,
               is_network_message: false
             }, <<>>}} = Protocol.decode_npci(<<1, 3>>)
  end

  test "decoding BACnet NPCI I-Am-Router-To-Network" do
    assert {:ok,
            {%NPCI{
               priority: :normal,
               expects_reply: false,
               destination: nil,
               source: nil,
               hopcount: nil,
               is_network_message: true
             }, <<1, 0, 44, 0, 85, 0, 99, 48, 57, 255, 254>>}} =
             Protocol.decode_npci(<<1, 128, 1, 0, 44, 0, 85, 0, 99, 48, 57, 255, 254>>)
  end

  test "decoding BACnet NSDU Who-Is-Router-To-Network" do
    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :who_is_router_to_network,
              msg_type: nil,
              data: nil
            }} =
             Protocol.decode_nsdu(<<0>>)
  end

  test "decoding BACnet NSDU Who-Is-Router-To-Network with DNET" do
    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :who_is_router_to_network,
              msg_type: nil,
              data: 44
            }} =
             Protocol.decode_nsdu(<<0, 0, 44>>)
  end

  test "decoding BACnet NSDU I-Am-Router-To-Network" do
    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :i_am_router_to_network,
              msg_type: nil,
              data: [44, 85, 99, 12_345, 65_534]
            }} =
             Protocol.decode_nsdu(<<1, 0, 44, 0, 85, 0, 99, 48, 57, 255, 254>>)
  end

  test "decoding BACnet NSDU I-Am-Router-To-Network empty list" do
    assert {:error, :invalid_data} = Protocol.decode_nsdu(<<1>>)
  end

  test "decoding BACnet NSDU DNET lists rejects incomplete network numbers" do
    for code <- [1, 4, 5], payload <- [<<0>>, <<0, 44, 0>>, <<0, 44, 0, 85, 255>>] do
      assert {:error, :invalid_data} = Protocol.decode_nsdu(<<code, payload::binary>>)
    end
  end

  test "decoding BACnet NSDU DNET lists with a single network" do
    for {type, code} <- [
          {:i_am_router_to_network, 1},
          {:router_busy_to_network, 4},
          {:router_available_to_network, 5}
        ] do
      assert {:ok,
              %NetworkLayerProtocolMessage{
                network_message_type: ^type,
                msg_type: nil,
                data: [44]
              }} = Protocol.decode_nsdu(<<code, 0, 44>>)
    end
  end

  test "decoding BACnet NSDU busy and available messages without DNETs" do
    for {type, code} <- [{:router_busy_to_network, 4}, {:router_available_to_network, 5}] do
      assert {:ok,
              %NetworkLayerProtocolMessage{
                network_message_type: ^type,
                msg_type: nil,
                data: []
              }} = Protocol.decode_nsdu(<<code>>)
    end
  end

  test "decoding BACnet NSDU I-Could-Be-Router-To-Network" do
    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :i_could_be_router_to_network,
              msg_type: nil,
              data: {44, 6}
            }} =
             Protocol.decode_nsdu(<<2, 0, 44, 6>>)
  end

  test "decoding BACnet NSDU Reject-Message-To-Network" do
    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :reject_message_to_network,
              msg_type: nil,
              data: {44, 0, "Other reason"}
            }} =
             Protocol.decode_nsdu(<<3, 0, 0, 44>>)

    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :reject_message_to_network,
              msg_type: nil,
              data: {44, 1, "The router is not directly connected to DNET" <> _rest}
            }} =
             Protocol.decode_nsdu(<<3, 1, 0, 44>>)

    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :reject_message_to_network,
              msg_type: nil,
              data: {44, 2, "The router is busy and unable" <> _rest}
            }} =
             Protocol.decode_nsdu(<<3, 2, 0, 44>>)

    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :reject_message_to_network,
              msg_type: nil,
              data: {44, 3, "It is an unknown network layer message type" <> _rest}
            }} =
             Protocol.decode_nsdu(<<3, 3, 0, 44>>)

    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :reject_message_to_network,
              msg_type: nil,
              data: {44, 4, "The message is too long" <> _rest}
            }} =
             Protocol.decode_nsdu(<<3, 4, 0, 44>>)

    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :reject_message_to_network,
              msg_type: nil,
              data:
                {44, 5, "The source message was rejected due to a BACnet security error" <> _rest}
            }} =
             Protocol.decode_nsdu(<<3, 5, 0, 44>>)

    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :reject_message_to_network,
              msg_type: nil,
              data:
                {44, 6,
                 "The source message was rejected due to errors in the addressing" <> _rest}
            }} =
             Protocol.decode_nsdu(<<3, 6, 0, 44>>)

    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :reject_message_to_network,
              msg_type: nil,
              data: {44, 7, :undefined}
            }} =
             Protocol.decode_nsdu(<<3, 7, 0, 44>>)
  end

  test "decoding BACnet NSDU Router-Busy-To-Network" do
    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :router_busy_to_network,
              msg_type: nil,
              data: [44, 85, 99, 12_345, 65_534]
            }} =
             Protocol.decode_nsdu(<<4, 0, 44, 0, 85, 0, 99, 48, 57, 255, 254>>)
  end

  test "decoding BACnet NSDU Router-Available-To-Network" do
    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :router_available_to_network,
              msg_type: nil,
              data: [44, 85, 99, 12_345, 65_534]
            }} =
             Protocol.decode_nsdu(<<5, 0, 44, 0, 85, 0, 99, 48, 57, 255, 254>>)
  end

  test "decoding BACnet NSDU Initialize-Routing-Table" do
    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :initialize_routing_table,
              msg_type: nil,
              data: [{44, 0, <<0, 99, 48, 57, 255, 254>>}, {45, 1, <<23, 24>>}]
            }} =
             Protocol.decode_nsdu(
               <<6, 2, 0, 44, 0, 6, 0, 99, 48, 57, 255, 254, 0, 45, 1, 2, 23, 24>>
             )
  end

  test "decoding BACnet NSDU Initialize-Routing-Table empty table" do
    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :initialize_routing_table,
              msg_type: nil,
              data: []
            }} =
             Protocol.decode_nsdu(<<6, 0>>)
  end

  test "decoding BACnet NSDU Initialize-Routing-Table-Ack" do
    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :initialize_routing_table_ack,
              msg_type: nil,
              data: [{44, 0, <<0, 99, 48, 57, 255, 254>>}, {45, 1, <<23, 24>>}]
            }} =
             Protocol.decode_nsdu(
               <<7, 2, 0, 44, 0, 6, 0, 99, 48, 57, 255, 254, 0, 45, 1, 2, 23, 24>>
             )
  end

  test "decoding BACnet NSDU Initialize-Routing-Table-Ack empty table" do
    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :initialize_routing_table_ack,
              msg_type: nil,
              data: []
            }} =
             Protocol.decode_nsdu(<<7, 0>>)
  end

  test "decoding BACnet NSDU Initialize-Routing-Table-Ack without data" do
    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :initialize_routing_table_ack,
              msg_type: nil,
              data: []
            }} = Protocol.decode_nsdu(<<7>>)

    assert {:error, :invalid_data} = Protocol.decode_nsdu(<<6>>)
  end

  test "decoding BACnet NSDU routing tables requires the advertised port count" do
    for code <- [6, 7],
        payload <- [
          <<0, 0, 44, 1, 0>>,
          <<1>>,
          <<2, 0, 44, 1, 0>>,
          <<1, 0, 44, 1, 0, 0, 45, 2, 0>>,
          <<255, 0, 44, 1, 0>>
        ] do
      assert {:error, :invalid_data} = Protocol.decode_nsdu(<<code, payload::binary>>)
    end
  end

  test "decoding BACnet NSDU routing tables rejects truncated entries and trailing bytes" do
    for code <- [6, 7],
        payload <- [
          <<0, 255>>,
          <<1, 0>>,
          <<1, 0, 44>>,
          <<1, 0, 44, 1>>,
          <<1, 0, 44, 1, 2>>,
          <<1, 0, 44, 1, 2, 7>>,
          <<1, 0, 44, 1, 0, 255>>,
          <<1, 0, 44, 1, 0, 0, 45>>,
          <<2, 0, 44, 1, 0, 0, 45, 2, 2, 7>>
        ] do
      assert {:error, :invalid_data} = Protocol.decode_nsdu(<<code, payload::binary>>)
    end
  end

  test "decoding BACnet NSDU routing tables with 255 ports" do
    ports = for port <- 0..254, do: {port + 1, port, <<>>}
    payload = for port <- 0..254, into: <<>>, do: <<port + 1::16, port, 0>>

    for {type, code} <- [{:initialize_routing_table, 6}, {:initialize_routing_table_ack, 7}] do
      assert {:ok,
              %NetworkLayerProtocolMessage{
                network_message_type: ^type,
                msg_type: nil,
                data: ^ports
              }} = Protocol.decode_nsdu(<<code, 255, payload::binary>>)
    end
  end

  test "decoding BACnet NSDU routing tables with maximum port info length" do
    info = :binary.copy(<<7>>, 255)

    for {type, code} <- [{:initialize_routing_table, 6}, {:initialize_routing_table_ack, 7}] do
      assert {:ok,
              %NetworkLayerProtocolMessage{
                network_message_type: ^type,
                msg_type: nil,
                data: [{44, 255, ^info}]
              }} = Protocol.decode_nsdu(<<code, 1, 0, 44, 255, 255, info::binary>>)
    end
  end

  test "decoding BACnet NSDU Establish-Connection-To-Network" do
    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :establish_connection_to_network,
              msg_type: nil,
              data: {44, 35}
            }} =
             Protocol.decode_nsdu(<<8, 0, 44, 35>>)
  end

  test "decoding BACnet NSDU Disonnect-Connection-To-Network" do
    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :disconnect_connection_to_network,
              msg_type: nil,
              data: 44
            }} =
             Protocol.decode_nsdu(<<9, 0, 44>>)
  end

  test "decoding BACnet NSDU What-Is-Network-Number" do
    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :what_is_network_number,
              msg_type: nil,
              data: nil
            }} =
             Protocol.decode_nsdu(<<18>>)
  end

  test "decoding BACnet NSDU Network-Number-Is" do
    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :network_number_is,
              msg_type: nil,
              data: {44, :configured}
            }} =
             Protocol.decode_nsdu(<<19, 0, 44, 1>>)

    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :network_number_is,
              msg_type: nil,
              data: {1, :learned}
            }} =
             Protocol.decode_nsdu(<<19, 0, 1, 0>>)
  end

  test "decoding BACnet NSDU reserved area" do
    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :reserved_area_start,
              msg_type: 0,
              data: <<32, 70, 15>>
            }} =
             Protocol.decode_nsdu(<<20, 32, 70, 15>>)
  end

  test "decoding BACnet NSDU reserved area 2" do
    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :reserved_area_start,
              msg_type: 4,
              data: <<32, 70, 15>>
            }} =
             Protocol.decode_nsdu(<<24, 32, 70, 15>>)
  end

  test "decoding BACnet NSDU vendor proprietary area" do
    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :vendor_proprietary_area_start,
              msg_type: 0,
              data: {8262, <<15>>}
            }} =
             Protocol.decode_nsdu(<<128, 32, 70, 15>>)
  end

  test "decoding BACnet NSDU vendor proprietary area 2" do
    assert {:ok,
            %NetworkLayerProtocolMessage{
              network_message_type: :vendor_proprietary_area_start,
              msg_type: 8,
              data: {8262, <<15>>}
            }} =
             Protocol.decode_nsdu(<<136, 32, 70, 15>>)
  end

  test "decoding BACnet NSDU failure" do
    assert {:error, :invalid_data} =
             Protocol.decode_nsdu(<<>>)
  end

  test "decoding BACnet NPDU NSDU" do
    assert {:ok, {:network, %NetworkLayerProtocolMessage{}}} =
             Protocol.decode_npdu(
               %NPCI{
                 priority: :normal,
                 expects_reply: false,
                 destination: nil,
                 source: nil,
                 hopcount: nil,
                 is_network_message: true
               },
               <<0>>
             )
  end

  test "decoding BACnet NPDU APDU" do
    assert {:ok, {:apdu, <<32, 70, 15>>}} ==
             Protocol.decode_npdu(
               %NPCI{
                 priority: :normal,
                 expects_reply: false,
                 destination: nil,
                 source: nil,
                 hopcount: nil,
                 is_network_message: false
               },
               <<32, 70, 15>>
             )
  end
end
