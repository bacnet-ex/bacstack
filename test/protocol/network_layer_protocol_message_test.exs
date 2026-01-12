defmodule BACnet.Protocol.NetworkLayerProtocolMessageTest do
  alias BACnet.Protocol.NetworkLayerProtocolMessage

  use ExUnit.Case, async: true

  @moduletag :protocol
  @moduletag :network_layer

  doctest BACnet.Protocol.NetworkLayerProtocolMessage

  test "encoding BACnet NSDU Who-Is-Router-To-Network" do
    assert {:ok, <<0>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :who_is_router_to_network,
               msg_type: nil,
               data: nil
             })
  end

  test "encoding BACnet NSDU Who-Is-Router-To-Network with DNET" do
    assert {:ok, <<0, 0, 44>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :who_is_router_to_network,
               msg_type: nil,
               data: 44
             })
  end

  test "encoding BACnet NSDU I-Am-Router-To-Network" do
    assert {:ok, <<1, 0, 44, 0, 85, 0, 99, 48, 57, 255, 254>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :i_am_router_to_network,
               msg_type: nil,
               data: [44, 85, 99, 12345, 65_534]
             })
  end

  test "encoding BACnet NSDU I-Am-Router-To-Network invalid dnet" do
    assert {:error, :invalid_dnet} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :i_am_router_to_network,
               msg_type: nil,
               data: [44, 65_536]
             })
  end

  test "encoding BACnet NSDU I-Am-Router-To-Network empty list" do
    assert {:ok, <<1>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :i_am_router_to_network,
               msg_type: nil,
               data: []
             })
  end

  test "encoding BACnet NSDU I-Could-Be-Router-To-Network" do
    assert {:ok, <<2, 0, 44, 6>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :i_could_be_router_to_network,
               msg_type: nil,
               data: {44, 6}
             })
  end

  test "encoding BACnet NSDU Reject-Message-To-Network" do
    assert {:ok, <<3, 0, 0, 44>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :reject_message_to_network,
               msg_type: nil,
               data: {44, 0, "Other reason"}
             })

    assert {:ok, <<3, 1, 0, 44>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :reject_message_to_network,
               msg_type: nil,
               data: {44, 1, "The router is not directly connected to DNET"}
             })

    assert {:ok, <<3, 2, 0, 44>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :reject_message_to_network,
               msg_type: nil,
               data: {44, 2, "The router is busy and unable"}
             })

    assert {:ok, <<3, 3, 0, 44>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :reject_message_to_network,
               msg_type: nil,
               data: {44, 3, "It is an unknown network layer message type"}
             })

    assert {:ok, <<3, 4, 0, 44>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :reject_message_to_network,
               msg_type: nil,
               data: {44, 4, "The message is too long"}
             })

    assert {:ok, <<3, 5, 0, 44>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :reject_message_to_network,
               msg_type: nil,
               data: {44, 5, "The source message was rejected due to a BACnet security error"}
             })

    assert {:ok, <<3, 6, 0, 44>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :reject_message_to_network,
               msg_type: nil,
               data: {44, 6, "The source message was rejected due to errors in the addressing"}
             })

    assert {:ok, <<3, 7, 0, 44>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :reject_message_to_network,
               msg_type: nil,
               data: {44, 7, :undefined}
             })
  end

  test "encoding BACnet NSDU Router-Busy-To-Network" do
    assert {:ok, <<4, 0, 44, 0, 85, 0, 99, 48, 57, 255, 254>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :router_busy_to_network,
               msg_type: nil,
               data: [44, 85, 99, 12345, 65_534]
             })
  end

  test "encoding BACnet NSDU Router-Busy-To-Network invalid dnet" do
    assert {:error, :invalid_dnet} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :router_busy_to_network,
               msg_type: nil,
               data: [44, 65_536]
             })
  end

  test "encoding BACnet NSDU Router-Available-To-Network" do
    assert {:ok, <<5, 0, 44, 0, 85, 0, 99, 48, 57, 255, 254>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :router_available_to_network,
               msg_type: nil,
               data: [44, 85, 99, 12345, 65_534]
             })
  end

  test "encoding BACnet NSDU Router-Available-To-Network invalid dnet" do
    assert {:error, :invalid_dnet} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :router_available_to_network,
               msg_type: nil,
               data: [44, 65_536]
             })
  end

  test "encoding BACnet NSDU Initialize-Routing-Table" do
    assert {:ok, <<6, 2, 0, 44, 0, 6, 0, 99, 48, 57, 255, 254, 0, 45, 1, 2, 23, 24>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :initialize_routing_table,
               msg_type: nil,
               data: [{44, 0, <<0, 99, 48, 57, 255, 254>>}, {45, 1, <<23, 24>>}]
             })
  end

  test "encoding BACnet NSDU Initialize-Routing-Table empty table" do
    assert {:ok, <<6, 0>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :initialize_routing_table,
               msg_type: nil,
               data: []
             })
  end

  test "encoding BACnet NSDU Initialize-Routing-Table invalid ports info" do
    assert {:error, :invalid_ports_info} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :initialize_routing_table,
               msg_type: nil,
               data: [{128_534_243, 0, <<0, 99, 48, 57, 255, 254>>}, {45, 1, <<23, 24>>}]
             })

    assert {:error, :invalid_ports_info} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :initialize_routing_table,
               msg_type: nil,
               data: [{23, 256, <<0, 99, 48, 57, 255, 254>>}, {45, 1, <<23, 24>>}]
             })

    assert {:error, :invalid_ports_info} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :initialize_routing_table,
               msg_type: nil,
               data: [{35, 1, :binary.copy(<<99>>, 256)}, {45, 1, <<23, 24>>}]
             })
  end

  test "encoding BACnet NSDU Initialize-Routing-Table-Ack" do
    assert {:ok, <<7, 2, 0, 44, 0, 6, 0, 99, 48, 57, 255, 254, 0, 45, 1, 2, 23, 24>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :initialize_routing_table_ack,
               msg_type: nil,
               data: [{44, 0, <<0, 99, 48, 57, 255, 254>>}, {45, 1, <<23, 24>>}]
             })
  end

  test "encoding BACnet NSDU Initialize-Routing-Table-Ack empty table" do
    assert {:ok, <<7, 0>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :initialize_routing_table_ack,
               msg_type: nil,
               data: []
             })
  end

  test "encoding BACnet NSDU Initialize-Routing-Table-Ack invalid port info" do
    assert {:error, :invalid_ports_info} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :initialize_routing_table_ack,
               msg_type: nil,
               data: [{128_534_243, 0, <<0, 99, 48, 57, 255, 254>>}, {45, 1, <<23, 24>>}]
             })

    assert {:error, :invalid_ports_info} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :initialize_routing_table_ack,
               msg_type: nil,
               data: [{23, 256, <<0, 99, 48, 57, 255, 254>>}, {45, 1, <<23, 24>>}]
             })

    assert {:error, :invalid_ports_info} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :initialize_routing_table_ack,
               msg_type: nil,
               data: [{35, 1, :binary.copy(<<99>>, 256)}, {45, 1, <<23, 24>>}]
             })
  end

  test "encoding BACnet NSDU Establish-Connection-To-Network" do
    assert {:ok, <<8, 0, 44, 35>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :establish_connection_to_network,
               msg_type: nil,
               data: {44, 35}
             })
  end

  test "encoding BACnet NSDU Disonnect-Connection-To-Network" do
    assert {:ok, <<9, 0, 44>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :disconnect_connection_to_network,
               msg_type: nil,
               data: 44
             })
  end

  test "encoding BACnet NSDU What-Is-Network-Number" do
    assert {:ok, <<18>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :what_is_network_number,
               msg_type: nil,
               data: nil
             })
  end

  test "encoding BACnet NSDU Network-Number-Is" do
    assert {:ok, <<19, 0, 44, 1>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :network_number_is,
               msg_type: nil,
               data: {44, :configured}
             })

    assert {:ok, <<19, 0, 1, 0>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :network_number_is,
               msg_type: nil,
               data: {1, :learned}
             })
  end

  test "encoding BACnet NSDU Network-Number-Is invalid flag" do
    assert {:error, :invalid_data} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :network_number_is,
               msg_type: nil,
               data: {44, :other}
             })
  end

  test "encoding BACnet NSDU reserved area" do
    assert {:ok, <<20, 32, 70, 15>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :reserved_area_start,
               msg_type: 0,
               data: <<32, 70, 15>>
             })
  end

  test "encoding BACnet NSDU reserved area 2" do
    assert {:ok, <<24, 32, 70, 15>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :reserved_area_start,
               msg_type: 4,
               data: <<32, 70, 15>>
             })
  end

  test "encoding BACnet NSDU reserved area invalid msg type" do
    assert {:error, :invalid_data} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :reserved_area_start,
               msg_type: 222,
               data: <<32, 70, 15>>
             })
  end

  test "encoding BACnet NSDU vendor proprietary area" do
    assert {:ok, <<128, 32, 70, 15>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :vendor_proprietary_area_start,
               msg_type: 0,
               data: {8262, <<15>>}
             })
  end

  test "encoding BACnet NSDU vendor proprietary area 2" do
    assert {:ok, <<136, 32, 70, 15>>} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :vendor_proprietary_area_start,
               msg_type: 8,
               data: {8262, <<15>>}
             })
  end

  test "encoding BACnet NSDU vendor proprietary area invalid msg type" do
    assert {:error, :invalid_data} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :vendor_proprietary_area_start,
               msg_type: 222,
               data: {8262, <<15>>}
             })
  end

  test "encoding BACnet NSDU failure" do
    assert {:error, :invalid_data} =
             NetworkLayerProtocolMessage.encode(%NetworkLayerProtocolMessage{
               network_message_type: :other,
               msg_type: nil,
               data: <<>>
             })
  end
end
