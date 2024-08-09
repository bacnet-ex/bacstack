defmodule BACnet.ProtocolTest do
  alias BACnet.Protocol
  alias BACnet.Protocol.Constants
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
             {2, %BACnet.Protocol.BvlcResult{result_code: :successful_completion}, <<1, 32>>}
           } ==
             Protocol.decode_bvll(
               Constants.macro_by_name(:bvll, :type_bacnet_ipv4),
               0,
               <<0, 0, 1, 32>>
             )
  end

  test "decoding BACnet Virtual Link Layer IPv4 unknown result code" do
    assert {:error, {:unknown_result_code, 65535}} =
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
             %BACnet.Protocol.BvlcForwardedNPDU{
               originating_ip: {192, 168, 1, 1},
               originating_port: 47_808
             },
             <<1, 32, 255, 255, 0, 255, 32, 1, 12>>}} ==
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
    assert {:ok, {2, %BACnet.Protocol.BvlcFunction{}, <<>>}} =
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
               source: %NpciTarget{net: 3, address: 108},
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
               destination: %NpciTarget{net: 2, address: 85},
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
             },
             <<1, 0, 44, 0, 85, 0, 99, 48, 57, 255, 254>>}} =
             Protocol.decode_npci(<<1, 128, 1, 0, 44, 0, 85, 0, 99, 48, 57, 255, 254>>)
  end

  test "decoding BACnet NSDU Who-Is-Router-To-Network" do
    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :who_is_router_to_network,
              data: nil
            }} =
             Protocol.decode_nsdu(<<0>>)
  end

  test "decoding BACnet NSDU Who-Is-Router-To-Network with DNET" do
    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :who_is_router_to_network,
              data: 44
            }} =
             Protocol.decode_nsdu(<<0, 0, 44>>)
  end

  test "decoding BACnet NSDU I-Am-Router-To-Network" do
    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :i_am_router_to_network,
              data: [44, 85, 99, 12345, 65534]
            }} =
             Protocol.decode_nsdu(<<1, 0, 44, 0, 85, 0, 99, 48, 57, 255, 254>>)
  end

  test "decoding BACnet NSDU I-Am-Router-To-Network empty list" do
    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :i_am_router_to_network,
              data: []
            }} =
             Protocol.decode_nsdu(<<1>>)
  end

  test "decoding BACnet NSDU I-Could-Be-Router-To-Network" do
    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :i_could_be_router_to_network,
              data: {44, 6}
            }} =
             Protocol.decode_nsdu(<<2, 0, 44, 6>>)
  end

  test "decoding BACnet NSDU Reject-Message-To-Network" do
    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :reject_message_to_network,
              data: {44, 0, "Other reason"}
            }} =
             Protocol.decode_nsdu(<<3, 0, 0, 44>>)

    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :reject_message_to_network,
              data: {44, 1, "The router is not directly connected to DNET" <> _rest}
            }} =
             Protocol.decode_nsdu(<<3, 1, 0, 44>>)

    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :reject_message_to_network,
              data: {44, 2, "The router is busy and unable" <> _rest}
            }} =
             Protocol.decode_nsdu(<<3, 2, 0, 44>>)

    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :reject_message_to_network,
              data: {44, 3, "It is an unknown network layer message type" <> _rest}
            }} =
             Protocol.decode_nsdu(<<3, 3, 0, 44>>)

    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :reject_message_to_network,
              data: {44, 4, "The message is too long" <> _rest}
            }} =
             Protocol.decode_nsdu(<<3, 4, 0, 44>>)

    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :reject_message_to_network,
              data:
                {44, 5, "The source message was rejected due to a BACnet security error" <> _rest}
            }} =
             Protocol.decode_nsdu(<<3, 5, 0, 44>>)

    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :reject_message_to_network,
              data:
                {44, 6,
                 "The source message was rejected due to errors in the addressing" <> _rest}
            }} =
             Protocol.decode_nsdu(<<3, 6, 0, 44>>)

    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :reject_message_to_network,
              data: {44, 7, :undefined}
            }} =
             Protocol.decode_nsdu(<<3, 7, 0, 44>>)
  end

  test "decoding BACnet NSDU Router-Busy-To-Network" do
    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :router_busy_to_network,
              data: [44, 85, 99, 12345, 65534]
            }} =
             Protocol.decode_nsdu(<<4, 0, 44, 0, 85, 0, 99, 48, 57, 255, 254>>)
  end

  test "decoding BACnet NSDU Router-Available-To-Network" do
    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :router_available_to_network,
              data: [44, 85, 99, 12345, 65534]
            }} =
             Protocol.decode_nsdu(<<5, 0, 44, 0, 85, 0, 99, 48, 57, 255, 254>>)
  end

  test "decoding BACnet NSDU Initialize-Routing-Table" do
    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :initialize_routing_table,
              data: [{44, 0, <<0, 99, 48, 57, 255, 254>>}, {45, 1, <<23, 24>>}]
            }} =
             Protocol.decode_nsdu(
               <<6, 2, 0, 44, 0, 6, 0, 99, 48, 57, 255, 254, 0, 45, 1, 2, 23, 24>>
             )
  end

  test "decoding BACnet NSDU Initialize-Routing-Table empty table" do
    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :initialize_routing_table,
              data: []
            }} =
             Protocol.decode_nsdu(<<6, 0>>)
  end

  test "decoding BACnet NSDU Initialize-Routing-Table-Ack" do
    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :initialize_routing_table_ack,
              data: [{44, 0, <<0, 99, 48, 57, 255, 254>>}, {45, 1, <<23, 24>>}]
            }} =
             Protocol.decode_nsdu(
               <<7, 2, 0, 44, 0, 6, 0, 99, 48, 57, 255, 254, 0, 45, 1, 2, 23, 24>>
             )
  end

  test "decoding BACnet NSDU Initialize-Routing-Table-Ack empty table" do
    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :initialize_routing_table_ack,
              data: []
            }} =
             Protocol.decode_nsdu(<<7, 0>>)
  end

  test "decoding BACnet NSDU Establish-Connection-To-Network" do
    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :establish_connection_to_network,
              data: {44, 35}
            }} =
             Protocol.decode_nsdu(<<8, 0, 44, 35>>)
  end

  test "decoding BACnet NSDU Disonnect-Connection-To-Network" do
    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :disconnect_connection_to_network,
              data: 44
            }} =
             Protocol.decode_nsdu(<<9, 0, 44>>)
  end

  test "decoding BACnet NSDU What-Is-Network-Number" do
    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :what_is_network_number,
              data: nil
            }} =
             Protocol.decode_nsdu(<<18>>)
  end

  test "decoding BACnet NSDU Network-Number-Is" do
    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :network_number_is,
              data: {44, :configured}
            }} =
             Protocol.decode_nsdu(<<19, 0, 44, 1>>)

    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :network_number_is,
              data: {1, :learned}
            }} =
             Protocol.decode_nsdu(<<19, 0, 1, 0>>)
  end

  test "decoding BACnet NSDU reserved area" do
    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :reserved_area_start,
              data: <<32, 70, 15>>
            }} =
             Protocol.decode_nsdu(<<20, 32, 70, 15>>)
  end

  test "decoding BACnet NSDU vendor proprietary area" do
    assert {:ok,
            %BACnet.Protocol.NetworkLayerProtocolMessage{
              network_message_type: :vendor_proprietary_area_start,
              data: {8262, <<15>>}
            }} =
             Protocol.decode_nsdu(<<128, 32, 70, 15>>)
  end

  test "decoding BACnet NSDU failure" do
    assert {:error, :invalid_data} =
             Protocol.decode_nsdu(<<>>)
  end

  test "decoding BACnet NPDU NSDU" do
    assert {:ok, {:network, %BACnet.Protocol.NetworkLayerProtocolMessage{}}} =
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
