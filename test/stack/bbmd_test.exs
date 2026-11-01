defmodule BACnet.Stack.BBMDTest do
  alias BACnet.Protocol.BroadcastDistributionTableEntry
  alias BACnet.Protocol.BvlcForwardedNPDU
  alias BACnet.Protocol.BvlcFunction
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ForeignDeviceTableEntry
  alias BACnet.Protocol.NPCI
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.IAm
  alias BACnet.Protocol.Services.IHave
  alias BACnet.Protocol.Services.WhoIs
  alias BACnet.Stack.BBMD
  alias BACnet.Stack.Client
  alias BACnet.Stack.EncoderProtocol
  alias BACnet.Stack.Segmentator
  alias BACnet.Stack.SegmentsStore
  alias BACnet.Test.Stack.FakeTransport

  require Constants

  use BACnet.Test.Stack.Case, async: true

  @moduletag :stack
  @moduletag :bbmd

  @local {{10, 0, 0, 8}, 47_808}
  @broadcast {{10, 0, 0, 255}, 47_808}
  @fd {{192, 168, 5, 5}, 47_810}
  @other_fd {{10, 9, 9, 9}, 47_808}
  @origin {{192, 168, 2, 10}, 47_808}

  setup do
    {transport, client} = start_client(@local, @broadcast)
    {:ok, who_is} = WhoIs.to_apdu(%WhoIs{device_id_low_limit: nil, device_id_high_limit: nil}, [])
    %{transport: transport, client: client, who_is: who_is}
  end

  test "start_link rejects bad options", %{client: client} do
    assert_raise ArgumentError, ~r/keyword list/, fn ->
      BBMD.start_link(%{})
    end

    assert_raise ArgumentError, ~r/bdt/, fn ->
      BBMD.start_link(client: client, bdt: [%{}])
    end

    assert_raise ArgumentError, ~r/bdt_readonly/, fn ->
      BBMD.start_link(client: client, bdt_readonly: :yes)
    end

    assert_raise ArgumentError, ~r/client/, fn ->
      BBMD.start_link(client: "nope")
    end

    assert_raise ArgumentError, ~r/max_fd_registrations/, fn ->
      BBMD.start_link(client: client, max_fd_registrations: 0)
    end

    assert_raise ArgumentError, ~r/override_port/, fn ->
      BBMD.start_link(client: client, override_port: 47_807)
    end

    assert_raise ArgumentError, ~r/paused/, fn ->
      BBMD.start_link(client: client, paused: :yes)
    end

    assert_raise ArgumentError, ~r/proxy_mode/, fn ->
      BBMD.start_link(client: client, proxy_mode: :yes)
    end
  end

  test "a transport without an IPv4 local address stops the server" do
    {_transport, client} = start_client(:local, @broadcast)

    assert {:error, {%ArgumentError{message: message}, _stack}} =
             isolated(fn -> BBMD.start_link(client: client) end)

    assert message =~ "IPv4"
  end

  test "a transport without an IPv4 broadcast address stops the server" do
    {_transport, client} = start_client(@local, :broadcast)

    assert {:error, {%ArgumentError{message: message}, _stack}} =
             isolated(fn -> BBMD.start_link(client: client) end)

    assert message =~ "IPv4"
  end

  test "a client that rejects the subscription stops startup", %{transport: transport} do
    parent = self()

    fake =
      spawn(fn ->
        reply_loop(fn
          :get_transport -> {FakeTransport, transport, transport}
          {:subscribe, _pid} -> {:error, :rejected}
        end)

        send(parent, :fake_done)
      end)

    result = isolated(fn -> BBMD.start_link(client: fake) end)
    assert {:error, :rejected} = result
    refute_received :fake_done
  end

  test "a named server keeps the broadcast distribution table it was given", %{client: client} do
    entry = bdt({192, 168, 1, 1}, 47_808)
    name = :"bbmd_#{System.unique_integer([:positive])}"

    assert {:ok, pid} =
             BBMD.start_link(name: name, client: client, bdt: [entry], override_port: 47_808)

    assert Process.whereis(name) == pid
    assert BBMD.get_broadcast_distribution_table(name) == [entry]
    assert BBMD.get_foreign_device_table(pid) == []
  end

  test "broadcast distribution table entries can be added and removed", %{client: client} do
    bbmd = start_bbmd!(client)
    first = bdt({192, 168, 1, 1}, 47_808)
    second = bdt({192, 168, 1, 2}, 47_809, {255, 255, 255, 255})

    assert :ok = BBMD.add_bdt_entry(bbmd, first)
    assert :ok = BBMD.add_bdt_entry(bbmd, second)
    assert :ok = BBMD.add_bdt_entry(bbmd, first)
    assert BBMD.get_broadcast_distribution_table(bbmd) == [first, second, first]

    assert :ok = BBMD.remove_bdt_entry(bbmd, first)
    assert BBMD.get_broadcast_distribution_table(bbmd) == [second, first]

    assert :ok = BBMD.remove_bdt_entry(bbmd, bdt({1, 2, 3, 4}, 1))
    assert BBMD.get_broadcast_distribution_table(bbmd) == [second, first]

    assert_raise ArgumentError, ~r/broadcast distribution table entry/, fn ->
      BBMD.add_bdt_entry(bbmd, bdt({1, 2, 3}, 47_808))
    end

    assert_raise ArgumentError, ~r/broadcast distribution table entry/, fn ->
      BBMD.add_bdt_entry(bbmd, bdt({1, 2, 3, 4}, 0))
    end

    assert_raise ArgumentError, ~r/broadcast distribution table entry/, fn ->
      BBMD.add_bdt_entry(bbmd, bdt({1, 2, 3, 4}, 47_808, {255, 256, 0, 0}))
    end

    assert BBMD.get_broadcast_distribution_table(bbmd) == [second, first]
  end

  test "paused registration rejects a new device until it is resumed", %{
    client: client,
    transport: transport
  } do
    bbmd = start_bbmd!(client, paused: true)
    send(bbmd, bvlc_msg(transport, @fd, register_function(60)))
    assert_nak(bbmd, @fd, :register_foreign_device_nak)
    assert BBMD.get_foreign_device_table(bbmd) == []

    assert :ok = BBMD.resume_fd_registration(bbmd)
    register!(bbmd, transport, @fd, 60)

    assert [%ForeignDeviceTableEntry{ip: {192, 168, 5, 5}, port: 47_810, time_to_live: 60}] =
             BBMD.get_foreign_device_table(bbmd)

    assert :ok = BBMD.pause_fd_registration(bbmd)
    send(bbmd, bvlc_msg(transport, @other_fd, register_function(30)))
    assert_nak(bbmd, @other_fd, :register_foreign_device_nak)
    assert fd_row(bbmd, {192, 168, 5, 5}, 47_810)
    refute fd_row(bbmd, {10, 9, 9, 9}, 47_808)
  end

  test "a paused server naks registration from any source shape", %{
    client: client,
    transport: transport
  } do
    bbmd = start_bbmd!(client, paused: true)

    for source <- [{{1, 2, 3, 4}, 47_808}, {8, 8, 8, 8}, :other] do
      send(bbmd, bvlc_msg(transport, source, register_function(60)))
      assert_nak(bbmd, source, :register_foreign_device_nak)
    end

    assert BBMD.get_foreign_device_table(bbmd) == []
  end

  test "registration past the maximum is rejected and a renewal is accepted", %{
    client: client,
    transport: transport
  } do
    bbmd = start_bbmd!(client, max_fd_registrations: 1)
    register!(bbmd, transport, @fd, 60)
    send(bbmd, bvlc_msg(transport, @other_fd, register_function(60)))
    assert_nak(bbmd, @other_fd, :register_foreign_device_nak)
    refute fd_row(bbmd, {10, 9, 9, 9}, 47_808)

    register!(bbmd, transport, @fd, 90)
    assert [%ForeignDeviceTableEntry{time_to_live: 90}] = BBMD.get_foreign_device_table(bbmd)
  end

  test "a registration is acknowledged with the ttl plus the grace period", %{
    client: client,
    transport: transport
  } do
    bbmd = start_bbmd!(client)
    register!(bbmd, transport, @fd, 60)

    assert %ForeignDeviceTableEntry{time_to_live: 60, remaining_time: remaining} =
             fd_row(bbmd, {192, 168, 5, 5}, 47_810)

    assert remaining in 85..90

    send(bbmd, {:fd_reg_timer, @fd})
    assert fd_row(bbmd, {192, 168, 5, 5}, 47_810)
  end

  test "a renewed registration keeps the later expiry", %{client: client, transport: transport} do
    bbmd = start_bbmd!(client)
    register!(bbmd, transport, @fd, -29)
    register!(bbmd, transport, @fd, 60)

    assert %ForeignDeviceTableEntry{time_to_live: 60, remaining_time: remaining} =
             fd_row(bbmd, {192, 168, 5, 5}, 47_810)

    assert remaining in 85..90
    Process.sleep(1_300)
    send(bbmd, {:fd_reg_timer, @fd})
    assert fd_row(bbmd, {192, 168, 5, 5}, 47_810).time_to_live == 60
  end

  test "an expired registration is removed", %{client: client, transport: transport} do
    bbmd = start_bbmd!(client)
    register!(bbmd, transport, @fd, -29)
    send(bbmd, {:fd_reg_timer, @fd})
    assert fd_row(bbmd, {192, 168, 5, 5}, 47_810)

    Process.sleep(1_500)
    send(bbmd, {:fd_reg_timer, @fd})
    BBMD.get_foreign_device_table(bbmd)
    refute fd_row(bbmd, {192, 168, 5, 5}, 47_810)

    send(bbmd, {:fd_reg_timer, @other_fd})
    assert BBMD.get_foreign_device_table(bbmd) == []
  end

  test "delete foreign device removes a row and acknowledges a missing one", %{
    client: client,
    transport: transport
  } do
    bbmd = start_bbmd!(client)
    register!(bbmd, transport, @fd, 60)
    register!(bbmd, transport, @other_fd, 30)

    send(bbmd, bvlc_msg(transport, @origin, delete_function(@fd)))
    assert_result(bbmd, @origin, :successful_completion)
    refute fd_row(bbmd, {192, 168, 5, 5}, 47_810)
    assert fd_row(bbmd, {10, 9, 9, 9}, 47_808)

    send(bbmd, bvlc_msg(transport, @origin, delete_function(@fd)))
    assert_result(bbmd, @origin, :successful_completion)
    assert fd_row(bbmd, {10, 9, 9, 9}, 47_808)
  end

  test "remove_foreign_device removes that registration", %{
    client: client,
    transport: transport
  } do
    bbmd = start_bbmd!(client)
    register!(bbmd, transport, @fd, 60)
    register!(bbmd, transport, @other_fd, 30)
    assert %ForeignDeviceTableEntry{} = entry = fd_row(bbmd, {192, 168, 5, 5}, 47_810)

    assert :ok = BBMD.remove_foreign_device(bbmd, entry)
    refute fd_row(bbmd, {192, 168, 5, 5}, 47_810)
    assert fd_row(bbmd, {10, 9, 9, 9}, 47_808).time_to_live == 30

    assert :ok = BBMD.remove_foreign_device(bbmd, entry)
    assert fd_row(bbmd, {10, 9, 9, 9}, 47_808).time_to_live == 30
  end

  test "the foreign device table can be read and an unencodable row is rejected", %{
    client: client,
    transport: transport
  } do
    bbmd = start_bbmd!(client)
    send(bbmd, bvlc_msg(transport, @origin, read_function(:bvlc_read_foreign_device_table)))
    BBMD.get_foreign_device_table(bbmd)
    assert_received {:fake_transport_send, @origin, <<>>, opts}
    assert opts[:npci] == false

    assert opts[:bvlc] ==
             <<Constants.macro_by_name(:bvlc_result_purpose, :bvlc_read_foreign_device_table_ack)>>

    register!(bbmd, transport, @fd, 60)
    send(bbmd, bvlc_msg(transport, @origin, read_function(:bvlc_read_foreign_device_table)))
    BBMD.get_foreign_device_table(bbmd)
    assert_received {:fake_transport_send, @origin, data, opts}

    assert opts[:bvlc] ==
             <<Constants.macro_by_name(:bvlc_result_purpose, :bvlc_read_foreign_device_table_ack)>>

    assert <<192, 168, 5, 5, 47_810::16, 60::16, remaining::16>> = data
    assert remaining in 85..90

    bad = {{1, 2, 3}, 47_808}
    register!(bbmd, transport, bad, 15)
    send(bbmd, bvlc_msg(transport, @origin, read_function(:bvlc_read_foreign_device_table)))
    assert_nak(bbmd, @origin, :read_foreign_device_table_nak)
    assert fd_row(bbmd, {1, 2, 3}, 47_808).time_to_live == 15
  end

  test "the broadcast distribution table can be read and an unencodable row is rejected", %{
    client: client,
    transport: transport
  } do
    entry = bdt({192, 168, 1, 20}, 47_808)
    bbmd = start_bbmd!(client, bdt: [entry])

    send(
      bbmd,
      bvlc_msg(transport, @origin, read_function(:bvlc_read_broadcast_distribution_table))
    )

    BBMD.get_foreign_device_table(bbmd)
    assert_received {:fake_transport_send, @origin, data, opts}
    assert opts[:npci] == false

    assert opts[:bvlc] ==
             <<Constants.macro_by_name(
                 :bvlc_result_purpose,
                 :bvlc_read_broadcast_distribution_table_ack
               )>>

    assert {:ok, <<192, 168, 1, 20, 47_808::16, 255, 255, 255, 0>>} ==
             BroadcastDistributionTableEntry.encode(entry)

    assert data == <<192, 168, 1, 20, 47_808::16, 255, 255, 255, 0>>

    {_transport, bare} = start_client(@local, @broadcast)

    bad_bbmd =
      start_bbmd!(bare, bdt: [bdt({1, 2, 3}, 47_808)])

    send(
      bad_bbmd,
      bvlc_msg(transport, @origin, read_function(:bvlc_read_broadcast_distribution_table))
    )

    assert_nak(bad_bbmd, @origin, :read_broadcast_distribution_table_nak)
    assert BBMD.get_broadcast_distribution_table(bad_bbmd) == [bdt({1, 2, 3}, 47_808)]
  end

  test "write broadcast distribution table replaces, rejects invalid payloads, and honours readonly",
       %{client: client, transport: transport} do
    original = bdt({192, 168, 1, 1}, 47_808)
    bbmd = start_bbmd!(client, bdt: [original])
    replacement = [bdt({172, 16, 0, 9}, 47_808, {255, 255, 255, 255}), bdt({10, 1, 0, 1}, 47_809)]

    send(bbmd, bvlc_msg(transport, @origin, write_function(replacement)))
    assert_result(bbmd, @origin, :successful_completion)
    assert BBMD.get_broadcast_distribution_table(bbmd) == replacement

    send(bbmd, bvlc_msg(transport, @origin, write_function([])))
    assert_result(bbmd, @origin, :successful_completion)
    assert BBMD.get_broadcast_distribution_table(bbmd) == []

    for payload <- [
          :nope,
          [bdt({1, 2, 3, 4}, 0)],
          [bdt({1, 2, 3, 4}, 1, {255, 256, 0, 0})],
          [:nope]
        ] do
      send(bbmd, bvlc_msg(transport, @origin, write_function(payload)))
      assert_nak(bbmd, @origin, :write_broadcast_distribution_table_nak)
    end

    assert BBMD.get_broadcast_distribution_table(bbmd) == []

    readonly = start_bbmd!(client, bdt: [original], bdt_readonly: true)
    send(readonly, bvlc_msg(transport, @origin, write_function(replacement)))
    assert_nak(readonly, @origin, :write_broadcast_distribution_table_nak)
    assert BBMD.get_broadcast_distribution_table(readonly) == [original]
    assert :ok = BBMD.add_bdt_entry(readonly, hd(replacement))
    assert BBMD.get_broadcast_distribution_table(readonly) == [original, hd(replacement)]
  end

  test "an original broadcast is forwarded to other foreign devices", %{
    client: client,
    transport: transport,
    who_is: who_is
  } do
    bbmd =
      start_bbmd!(client,
        bdt: [
          bdt({10, 0, 0, 8}, 47_808),
          bdt({127, 0, 0, 1}, 47_808, {255, 0, 0, 0}),
          bdt({192, 168, 1, 0}, 47_808)
        ]
      )

    register!(bbmd, transport, @fd, 60)
    register!(bbmd, transport, @other_fd, 60)

    send(bbmd, client_msg(who_is, @origin, :original_broadcast, npci()))
    assert BBMD.get_foreign_device_table(bbmd) != []

    sent = drain()

    for dest <- [@fd, @other_fd] do
      assert Enum.any?(sent, fn item -> match_forward(item, dest, who_is, @origin) end)
    end

    refute Enum.any?(sent, fn {dest, _data, _opts} -> dest == {{192, 168, 1, 255}, 47_808} end)
  end

  test "a routed broadcast is sent to foreign subnets and skipped for the origin subnet", %{
    client: client,
    transport: transport,
    who_is: who_is
  } do
    :ok = FakeTransport.set_routed(transport, [@origin])

    bbmd =
      start_bbmd!(client,
        bdt: [
          bdt({10, 0, 0, 8}, 47_808),
          bdt({127, 0, 0, 1}, 47_808, {255, 0, 0, 0}),
          bdt({192, 168, 1, 0}, 47_808),
          bdt({192, 168, 2, 0}, 47_808),
          bdt({192, 168, 2, 0}, 47_809),
          bdt({172, 16, 0, 9}, 47_808, {255, 255, 255, 255})
        ]
      )

    register!(bbmd, transport, @fd, 60)
    register!(bbmd, transport, @origin, 60)
    send(bbmd, client_msg(who_is, @origin, :original_broadcast, npci()))
    BBMD.get_broadcast_distribution_table(bbmd)

    sent = drain()

    for dest <- [
          {{192, 168, 1, 255}, 47_808},
          {{192, 168, 2, 255}, 47_809},
          {{172, 16, 0, 9}, 47_808},
          @fd
        ] do
      assert Enum.any?(sent, fn item -> match_forward(item, dest, who_is, @origin) end),
             "missing forward to #{inspect(dest)}"
    end

    refute Enum.any?(sent, fn {dest, _data, _opts} -> dest == {{192, 168, 2, 255}, 47_808} end)
    refute Enum.any?(sent, fn {dest, _data, _opts} -> dest == @origin end)
    refute Enum.any?(sent, fn {dest, _data, _opts} -> dest == @broadcast end)
  end

  test "a broadcast distribution send error leaves the server running", %{
    client: client,
    transport: transport,
    who_is: who_is
  } do
    :ok = FakeTransport.set_routed(transport, [@origin])
    :ok = FakeTransport.set_send_result(transport, {:error, :unreachable})
    bbmd = start_bbmd!(client, bdt: [bdt({192, 168, 1, 0}, 47_808)])
    register!(bbmd, transport, @fd, 60)

    send(bbmd, client_msg(who_is, @origin, :original_broadcast, npci()))
    assert BBMD.get_broadcast_distribution_table(bbmd) == [bdt({192, 168, 1, 0}, 47_808)]

    sent = drain()
    assert Enum.any?(sent, fn {dest, _data, _opts} -> dest == {{192, 168, 1, 255}, 47_808} end)
    assert Enum.any?(sent, fn {dest, _data, _opts} -> dest == @fd end)
  end

  test "an original broadcast with an address that cannot be forwarded is dropped", %{
    client: client,
    transport: transport,
    who_is: who_is
  } do
    bbmd = start_bbmd!(client, bdt: [bdt({192, 168, 1, 0}, 47_808)])
    register!(bbmd, transport, @fd, 60)
    send(bbmd, client_msg(who_is, {{1, 2, 3}, 47_808}, :original_broadcast, npci()))
    BBMD.get_foreign_device_table(bbmd)
    assert drain() == []
    assert fd_row(bbmd, {192, 168, 5, 5}, 47_810)
  end

  test "distribute broadcast from an unknown device is rejected", %{
    client: client,
    who_is: who_is
  } do
    bbmd = start_bbmd!(client)
    send(bbmd, client_msg(who_is, @fd, :distribute_broadcast_to_network, npci()))
    assert_nak(bbmd, @fd, :distribute_broadcast_to_network_nak)
    BBMD.get_foreign_device_table(bbmd)
    assert drain() == []
  end

  test "distribute broadcast from a registered device is forwarded and broadcast", %{
    client: client,
    transport: transport,
    who_is: who_is
  } do
    :ok = FakeTransport.set_routed(transport, [@fd])
    bbmd = start_bbmd!(client, bdt: [bdt({192, 168, 1, 0}, 47_808)])
    register!(bbmd, transport, @fd, 60)
    register!(bbmd, transport, @other_fd, 60)

    send(bbmd, client_msg(who_is, @fd, :distribute_broadcast_to_network, npci()))
    BBMD.get_foreign_device_table(bbmd)
    sent = drain()

    for dest <- [{{192, 168, 1, 255}, 47_808}, @other_fd, @broadcast] do
      assert Enum.any?(sent, fn item -> match_forward(item, dest, who_is, @fd) end)
    end

    refute Enum.any?(sent, fn {dest, _data, _opts} -> dest == @fd end)
  end

  test "distribute broadcast with an address that cannot be encoded is rejected", %{
    client: client,
    transport: transport,
    who_is: who_is
  } do
    bbmd = start_bbmd!(client)
    source = {{1, 2, 3}, 47_808}
    register!(bbmd, transport, source, 60)
    send(bbmd, client_msg(who_is, source, :distribute_broadcast_to_network, npci()))
    assert_nak(bbmd, source, :distribute_broadcast_to_network_nak)
    BBMD.get_foreign_device_table(bbmd)
    assert drain() == []
  end

  test "a failed local broadcast of a distributed apdu is rejected", %{
    client: client,
    transport: transport,
    who_is: who_is
  } do
    :ok =
      FakeTransport.set_send_result(transport, fn
        @broadcast, _data, _opts -> {:error, :down}
        _dest, _data, _opts -> :ok
      end)

    bbmd = start_bbmd!(client)
    register!(bbmd, transport, @fd, 60)
    send(bbmd, client_msg(who_is, @fd, :distribute_broadcast_to_network, npci()))
    assert_nak(bbmd, @fd, :distribute_broadcast_to_network_nak)
    assert fd_row(bbmd, {192, 168, 5, 5}, 47_810)

    assert Enum.any?(drain(), fn {dest, data, _opts} ->
             dest == @broadcast and data == encoded(who_is)
           end)
  end

  test "proxy mode broadcasts a distribution without a forwarded header", %{
    client: client,
    transport: transport,
    who_is: who_is
  } do
    bbmd = start_bbmd!(client, proxy_mode: true)
    register!(bbmd, transport, @fd, 60)
    register!(bbmd, transport, @other_fd, 60)
    send(bbmd, client_msg(who_is, @fd, :distribute_broadcast_to_network, npci()))
    BBMD.get_foreign_device_table(bbmd)
    sent = drain()

    assert Enum.any?(sent, fn item -> match_forward(item, @other_fd, who_is, @fd) end)

    assert {_destination, data, opts} =
             Enum.find(sent, fn {dest, _data, _opts} -> dest == @broadcast end)

    assert data == encoded(who_is)
    assert opts[:bvlc] == nil
  end

  test "proxy mode still broadcasts when the origin address cannot be encoded", %{
    client: client,
    transport: transport,
    who_is: who_is
  } do
    bbmd = start_bbmd!(client, proxy_mode: true)
    source = {{1, 2, 3}, 47_808}
    register!(bbmd, transport, source, 60)
    send(bbmd, client_msg(who_is, source, :distribute_broadcast_to_network, npci()))
    BBMD.get_foreign_device_table(bbmd)
    assert [{@broadcast, data, opts}] = drain()
    assert data == encoded(who_is)
    assert opts[:bvlc] == nil
  end

  test "a forwarded npdu is sent to foreign devices and broadcast when the peer is routed", %{
    client: client,
    transport: transport,
    who_is: who_is
  } do
    bbmd = start_bbmd!(client)
    register!(bbmd, transport, @fd, 60)
    npdu = %BvlcForwardedNPDU{originating_ip: {192, 168, 9, 9}, originating_port: 47_808}
    origin = {{192, 168, 9, 9}, 47_808}

    send(bbmd, client_msg(who_is, {{1, 2, 3, 4}, 47_808}, npdu, npci()))
    BBMD.get_foreign_device_table(bbmd)
    assert [sent] = drain()
    assert_forward(sent, @fd, who_is, origin)

    send(bbmd, client_msg(who_is, {:routed, :peer}, npdu, npci()))
    BBMD.get_foreign_device_table(bbmd)
    sent = drain()
    assert Enum.any?(sent, fn item -> match_forward(item, @fd, who_is, origin) end)
    assert Enum.any?(sent, fn item -> match_forward(item, @broadcast, who_is, origin) end)
  end

  test "a forwarded npdu with an address that cannot be encoded is dropped", %{
    client: client,
    transport: transport,
    who_is: who_is
  } do
    bbmd = start_bbmd!(client)
    register!(bbmd, transport, @fd, 60)

    send(
      bbmd,
      client_msg(
        who_is,
        @origin,
        %BvlcForwardedNPDU{originating_ip: {1, 2, 3}, originating_port: 47_808},
        npci()
      )
    )

    BBMD.get_foreign_device_table(bbmd)
    assert drain() == []
  end

  test "a failed rebroadcast of a forwarded npdu leaves the server running", %{
    client: client,
    transport: transport,
    who_is: who_is
  } do
    :ok =
      FakeTransport.set_send_result(transport, fn
        @broadcast, _data, _opts -> {:error, :down}
        _dest, _data, _opts -> :ok
      end)

    bbmd = start_bbmd!(client)
    register!(bbmd, transport, @fd, 60)
    npdu = %BvlcForwardedNPDU{originating_ip: {192, 168, 9, 9}, originating_port: 47_808}

    send(bbmd, client_msg(who_is, {:routed, :peer}, npdu, npci()))
    assert fd_row(bbmd, {192, 168, 5, 5}, 47_810)
    sent = drain()
    assert Enum.any?(sent, fn {dest, _data, _opts} -> dest == @fd end)
    assert Enum.any?(sent, fn {dest, _data, _opts} -> dest == @broadcast end)
  end

  test "proxy mode forwards I-Am and I-Have to other foreign devices", %{
    client: client,
    transport: transport
  } do
    bbmd = start_bbmd!(client, proxy_mode: true)
    register!(bbmd, transport, @fd, 60)
    register!(bbmd, transport, @other_fd, 60)
    iam = iam()
    ihave = ihave()

    send(bbmd, client_msg(iam, @fd, :original_unicast, npci()))
    BBMD.get_foreign_device_table(bbmd)
    assert [sent] = drain()
    assert_forward(sent, @other_fd, iam, @fd)

    send(bbmd, client_msg(ihave, @other_fd, :original_unicast, npci()))
    BBMD.get_foreign_device_table(bbmd)
    assert [sent] = drain()
    assert_forward(sent, @fd, ihave, @other_fd)
  end

  test "proxy forwarding ignores local, confirmed, and unrelated unicasts", %{
    client: client,
    transport: transport,
    who_is: who_is
  } do
    bbmd = start_bbmd!(client, proxy_mode: true)
    register!(bbmd, transport, @fd, 60)
    iam = iam()

    send(bbmd, client_msg(iam, @local, :original_unicast, npci()))
    send(bbmd, client_msg(iam, @other_fd, :original_unicast, npci(true)))
    send(bbmd, client_msg(who_is, @other_fd, :original_unicast, npci()))
    send(bbmd, client_msg(who_is, @local, :original_broadcast, npci(true)))
    BBMD.get_foreign_device_table(bbmd)
    assert drain() == []

    plain = start_bbmd!(client)
    register!(plain, transport, @fd, 60)
    send(plain, client_msg(iam, @other_fd, :original_unicast, npci()))
    BBMD.get_foreign_device_table(plain)
    assert drain() == []
  end

  test "proxy unicast with an address that cannot be encoded is dropped", %{
    client: client,
    transport: transport
  } do
    bbmd = start_bbmd!(client, proxy_mode: true)
    register!(bbmd, transport, @fd, 60)
    send(bbmd, client_msg(iam(), {{192, 168, 4, 4}, 0}, :original_unicast, npci()))
    BBMD.get_foreign_device_table(bbmd)
    assert drain() == []
  end

  test "override_port replaces the port used for local broadcasts", %{
    transport: transport,
    who_is: who_is
  } do
    {_transport, client} = start_client(@local, @broadcast)
    bbmd = start_bbmd!(client, override_port: 47_809, proxy_mode: true)
    register!(bbmd, transport, @fd, 60)
    send(bbmd, client_msg(who_is, @fd, :distribute_broadcast_to_network, npci()))
    BBMD.get_foreign_device_table(bbmd)
    assert [{{10, 0, 0, 255}, 47_809}] == Enum.map(drain(), fn {dest, _data, _opts} -> dest end)
  end

  test "unknown messages leave both tables unchanged", %{client: client, transport: transport} do
    bbmd = start_bbmd!(client, bdt: [bdt({192, 168, 1, 1}, 47_808)])
    send(bbmd, :unused)
    GenServer.cast(bbmd, :unused)

    send(
      bbmd,
      {:bacnet_transport, {:bacnet_ipv4, FakeTransport}, @fd, {:bvlc, :not_a_function}, transport}
    )

    parent = self()

    spawn(fn ->
      result =
        try do
          GenServer.call(bbmd, :unused, 40)
        catch
          :exit, reason -> {:exit, reason}
        end

      send(parent, {:call, result})
    end)

    assert_receive {:call, {:exit, {:timeout, _}}}, 500
    assert BBMD.get_broadcast_distribution_table(bbmd) == [bdt({192, 168, 1, 1}, 47_808)]
    assert BBMD.get_foreign_device_table(bbmd) == []
  end

  test "a stop request shuts the server down", %{client: client} do
    bbmd = start_bbmd!(client)
    ref = Process.monitor(bbmd)
    assert :ok = GenServer.call(bbmd, :stop)
    assert_receive {:DOWN, ^ref, :process, ^bbmd, :normal}
  end

  defp start_client(local, broadcast) do
    {:ok, transport} = FakeTransport.start_link(local: local, broadcast: broadcast)
    {:ok, segmentator} = Segmentator.start_link(apdu_timeout: 60_000, apdu_retries: 0)
    {:ok, store} = SegmentsStore.start_link(apdu_timeout: 60_000, apdu_retries: 0)

    {:ok, client} =
      Client.start_link(
        transport: {FakeTransport, transport},
        segmentator: segmentator,
        segments_store: store
      )

    {transport, client}
  end

  defp start_bbmd!(client, opts \\ []) do
    {:ok, bbmd} = BBMD.start_link([client: client] ++ opts)
    bbmd
  end

  defp isolated(fun) do
    parent = self()

    spawn(fn ->
      Process.flag(:trap_exit, true)

      result =
        try do
          fun.()
        rescue
          error -> {:raised, error}
        catch
          kind, reason -> {:caught, kind, reason}
        end

      send(parent, {:isolated, result})
    end)

    assert_receive {:isolated, result}, 1_000
    result
  end

  defp reply_loop(fun) do
    receive do
      {:"$gen_call", from, message} ->
        GenServer.reply(from, fun.(message))
        reply_loop(fun)
    after
      1_000 -> :ok
    end
  end

  defp bdt(ip, port, mask \\ {255, 255, 255, 0}) do
    %BroadcastDistributionTableEntry{ip: ip, port: port, mask: mask}
  end

  defp register_function(ttl) do
    %BvlcFunction{
      function: Constants.macro_assert_name(:bvlc_result_purpose, :bvlc_register_foreign_device),
      data: ttl
    }
  end

  defp delete_function({ip, port}) do
    %BvlcFunction{
      function:
        Constants.macro_assert_name(
          :bvlc_result_purpose,
          :bvlc_delete_foreign_device_table_entry
        ),
      data: %ForeignDeviceTableEntry{
        ip: ip,
        port: port,
        time_to_live: nil,
        remaining_time: nil
      }
    }
  end

  defp read_function(name) do
    %BvlcFunction{
      function: Constants.assert_name!(:bvlc_result_purpose, name),
      data: nil
    }
  end

  defp write_function(bdt) do
    %BvlcFunction{
      function:
        Constants.macro_assert_name(
          :bvlc_result_purpose,
          :bvlc_write_broadcast_distribution_table
        ),
      data: bdt
    }
  end

  defp bvlc_msg(transport, source, bvlc) do
    {:bacnet_transport, {:bacnet_ipv4, FakeTransport}, source, {:bvlc, bvlc}, transport}
  end

  defp client_msg(apdu, source, kind, npci) do
    {:bacnet_client, make_ref(), apdu, {source, kind, npci}, self()}
  end

  defp npci(expects_reply \\ false) do
    NPCI.new(expects_reply: expects_reply)
  end

  defp register!(bbmd, transport, source, ttl) do
    send(bbmd, bvlc_msg(transport, source, register_function(ttl)))
    assert_result(bbmd, source, :successful_completion)
    bbmd
  end

  defp assert_result(bbmd, source, name) do
    # BBMD sends its transport replies synchronously before handling this call.
    BBMD.get_foreign_device_table(bbmd)
    assert_received {:fake_transport_send, ^source, data, opts}
    assert data == <<Constants.by_name!(:bvlc_result_format, name)::size(16)>>
    assert opts[:bvlc] == <<Constants.macro_by_name(:bvlc_result_purpose, :bvlc_result)>>
    assert opts[:npci] == false
    bbmd
  end

  defp assert_nak(bbmd, source, name) do
    assert_result(bbmd, source, name)
  end

  defp fd_row(bbmd, ip, port) do
    Enum.find(BBMD.get_foreign_device_table(bbmd), &(&1.ip == ip and &1.port == port))
  end

  defp encoded(apdu) do
    IO.iodata_to_binary(EncoderProtocol.encode(apdu))
  end

  defp forwarded_bvlc({{ip_a, ip_b, ip_c, ip_d}, port}) do
    <<Constants.macro_by_name(:bvlc_result_purpose, :bvlc_forwarded_npdu), ip_a, ip_b, ip_c, ip_d,
      port::size(16)>>
  end

  defp match_forward({dest, data, opts}, dest, apdu, origin) do
    data == encoded(apdu) and opts[:bvlc] == forwarded_bvlc(origin) and opts[:npci] == npci()
  end

  defp match_forward(_other, _dest, _apdu, _origin), do: false

  defp assert_forward({dest, data, opts}, dest, apdu, origin) do
    assert data == encoded(apdu)
    assert opts[:bvlc] == forwarded_bvlc(origin)
    assert opts[:npci] == npci()
  end

  defp drain() do
    do_drain([])
  end

  defp do_drain(acc) do
    receive do
      {:fake_transport_send, dest, data, opts} -> do_drain([{dest, data, opts} | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  defp iam() do
    {:ok, apdu} =
      IAm.to_apdu(
        %IAm{
          device: %ObjectIdentifier{type: :device, instance: 7},
          max_apdu: 1476,
          segmentation_supported: :segmented_both,
          vendor_id: 42
        },
        []
      )

    apdu
  end

  defp ihave() do
    {:ok, apdu} =
      IHave.to_apdu(
        %IHave{
          device: %ObjectIdentifier{type: :device, instance: 7},
          object: %ObjectIdentifier{type: :analog_input, instance: 2},
          object_name: "AI"
        },
        []
      )

    apdu
  end
end
