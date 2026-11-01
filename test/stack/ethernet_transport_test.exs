defmodule BACnet.Stack.Transport.EthernetTransportTest do
  alias BACnet.Protocol.NetworkLayerProtocolMessage
  alias BACnet.Protocol.NPCI
  alias BACnet.Stack.EncoderProtocol
  alias BACnet.Stack.Transport.EthernetTransport
  alias BACnet.Test.Stack.ApduFactory

  use BACnet.Test.Stack.Case, async: false

  import ExUnit.CaptureLog

  @moduletag :stack
  @moduletag :ethernet_transport

  # OTP 24.0's socket NIF cannot decode native AF_PACKET addresses. Argument
  # validation still runs there; only tests that bind a raw socket are skipped.
  @raw_socket_skip if String.to_integer(System.otp_release()) < 25,
                     do: "native AF_PACKET addresses require OTP 24.1+",
                     else: false

  @broadcast <<0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF>>
  @lo_mac <<0, 0, 0, 0, 0, 0>>
  @peer_mac <<2, 0, 0, 0, 0, 1>>
  @mac <<9, 9, 9, 9, 9, 9>>
  @portal {:not_a_socket, 1, <<1, 2, 3, 4, 5, 6>>}
  @who_is <<0x01, 0x00, 16, 8>>
  @llc <<0x82, 0x82, 0x03>>

  test "reports protocol limits and validates destinations" do
    assert EthernetTransport.bacnet_protocol() == :bacnet_ethernet
    assert EthernetTransport.max_apdu_length() == 1476
    assert EthernetTransport.max_npdu_length() == 1476

    assert EthernetTransport.valid_destination?(@mac)
    assert EthernetTransport.valid_destination?(@broadcast)
    refute EthernetTransport.valid_destination?(<<1, 2, 3, 4, 5>>)
    refute EthernetTransport.valid_destination?([1, 2, 3, 4, 5, 6])
    refute EthernetTransport.valid_destination?(:peer)

    assert EthernetTransport.get_broadcast_address(self()) == @broadcast
    assert EthernetTransport.get_broadcast_address(nil) == @broadcast
    refute EthernetTransport.destination_routed?(self(), @mac)
    assert EthernetTransport.destination_routed?(self(), :remote)
    assert EthernetTransport.destination_routed?(self(), <<1, 2, 3>>)
  end

  test "child_spec points open at the callback and options" do
    opts = [eth_ifname: "lo"]
    spec = EthernetTransport.child_spec([self(), opts])
    assert spec.id == EthernetTransport
    assert spec.start == {EthernetTransport, :open, [self(), opts]}
    assert EthernetTransport.child_spec(self(), opts).start == spec.start
  end

  test "open rejects bad arguments" do
    assert_raise ArgumentError, ~r/keyword list/, fn ->
      EthernetTransport.open(self(), %{})
    end

    assert_raise ArgumentError, ~r/callback/, fn ->
      EthernetTransport.open(fn _one -> :ok end, [])
    end

    assert_raise ArgumentError, ~r/callback/, fn ->
      EthernetTransport.open(123, [])
    end

    assert_raise ArgumentError, ~r/not exported/, fn ->
      EthernetTransport.open({__MODULE__, :missing_callback, 3}, [])
    end

    assert_raise ArgumentError, ~r/eth_ifname/, fn ->
      EthernetTransport.open(self(), eth_ifname: :lo)
    end

    assert_raise ArgumentError, ~r/supervisor/, fn ->
      EthernetTransport.open(self(), supervisor: "nope")
    end
  end

  test "a missing interface stops startup" do
    assert {:error, {%RuntimeError{message: message}, _stack}} =
             isolated(fn ->
               EthernetTransport.open(self(), eth_ifname: "no-such-if-bacstack")
             end)

    assert message =~ "no-such-if-bacstack"
  end

  @tag skip: @raw_socket_skip
  test "the first enumerated interface is loopback" do
    assert {:ok, transport} = EthernetTransport.open(self())

    on_exit(fn ->
      if Process.alive?(transport) do
        try do
          EthernetTransport.close(transport)
        catch
          :exit, _reason -> :ok
        end
      end
    end)

    assert EthernetTransport.get_local_address(transport) == @lo_mac
    assert :ok = EthernetTransport.close(transport)
  end

  @tag skip: @raw_socket_skip
  test "a loopback transport reports its address and accepts supervisor shapes" do
    transport = start_lo!()
    assert EthernetTransport.get_local_address(transport) == @lo_mac
    assert EthernetTransport.get_broadcast_address(transport) == @broadcast

    {socket, ifindex, mac} = EthernetTransport.get_portal(transport)
    assert is_tuple(socket)
    assert ifindex > 0
    assert mac == @lo_mac

    ref = Process.monitor(transport)
    assert :ok = EthernetTransport.close(transport)
    assert_receive {:DOWN, ^ref, :process, ^transport, :normal}

    for supervisor <- [:eth_sup, {:global, :eth_sup}, {:via, Agent, :eth_sup}, {:eth_sup, node()}] do
      started = start_lo!(supervisor: supervisor)
      assert EthernetTransport.get_local_address(started) == @lo_mac
      assert :ok = EthernetTransport.close(started)
    end

    {:ok, sup} = Task.Supervisor.start_link()
    started = start_lo!(supervisor: sup)
    assert EthernetTransport.get_local_address(started) == @lo_mac
    assert :ok = EthernetTransport.close(started)
  end

  test "send rejects a bad destination, an empty payload, and an oversized apdu" do
    assert_raise ArgumentError, ~r/keyword list/, fn ->
      EthernetTransport.send(@portal, @mac, <<16, 8>>, [1])
    end

    assert {:error, :invalid_destination} = EthernetTransport.send(@portal, "short", <<16, 8>>)
    assert {:error, :data_empty} = EthernetTransport.send(@portal, @mac, <<>>)
    assert {:error, :data_empty} = EthernetTransport.send(@portal, @mac, [])

    assert {:error, :apdu_too_long} =
             EthernetTransport.send(@portal, @mac, :binary.copy(<<1>>, 1477))

    assert {:error, :invalid_expects_reply_for_broadcast} =
             EthernetTransport.send(@portal, @broadcast, ApduFactory.read_property())
  end

  test "a built frame is handed to the socket" do
    assert_raise ArgumentError, ~r/argument error/, fn ->
      EthernetTransport.send(@portal, @mac, <<16, 8>>)
    end

    assert_raise ArgumentError, ~r/argument error/, fn ->
      EthernetTransport.send(@portal, @mac, [16, 0, 16, 8])
    end

    assert_raise ArgumentError, ~r/argument error/, fn ->
      EthernetTransport.send(@portal, @broadcast, ApduFactory.who_is())
    end

    assert_raise ArgumentError, ~r/argument error/, fn ->
      EthernetTransport.send(@portal, @mac, ApduFactory.who_is(), skip_headers: true)
    end
  end

  @tag skip: @raw_socket_skip
  test "a broadcast who-is is delivered and a unicast reply is written" do
    transport = start_lo!()
    peer = open_peer!(transport)

    write_frame!(peer, transport, @broadcast, @peer_mac, @who_is)

    assert {:apdu, :original_broadcast, %NPCI{}, <<16, 8>>} =
             await_payload(@peer_mac, transport)

    portal = EthernetTransport.get_portal(transport)
    drain_peer(peer)
    assert :ok = EthernetTransport.send(portal, @peer_mac, <<16, 8>>)

    frame = await_outgoing(peer, @peer_mac, @lo_mac)
    assert :binary.part(frame, 0, 6) == @peer_mac
    assert :binary.part(frame, 6, 6) == @lo_mac
    assert :binary.part(frame, 12, 9) == <<7::16, @llc, 1, 0, 16, 8>>

    drain_peer(peer)
    assert :ok = EthernetTransport.send(portal, @broadcast, [16, 8], skip_headers: true)
    skipped = await_outgoing(peer, @broadcast, @lo_mac)
    assert :binary.part(skipped, 0, 6) == @broadcast
    assert :binary.part(skipped, 6, 6) == @lo_mac
    assert :binary.part(skipped, 12, 4) == <<2::16, 16, 8>>

    encoded = IO.iodata_to_binary(EncoderProtocol.encode(ApduFactory.who_is()))
    drain_peer(peer)
    assert :ok = EthernetTransport.send(portal, @peer_mac, ApduFactory.who_is())
    struct_frame = await_outgoing(peer, @peer_mac, @lo_mac)
    assert :binary.part(struct_frame, 14, 3) == @llc
    assert binary_contains?(struct_frame, encoded)
  end

  @tag skip: @raw_socket_skip
  test "a delayed outgoing burst keeps Ethernet packet boundaries" do
    transport = start_lo!()
    peer = open_peer!(transport)
    portal = EthernetTransport.get_portal(transport)
    second_destination = <<2, 0, 0, 0, 0, 2>>

    task =
      Task.async(fn ->
        # Start the receive while the socket is empty, then deliver two packets.
        Process.sleep(20)
        :ok = EthernetTransport.send(portal, @peer_mac, <<16, 8>>)
        :ok = EthernetTransport.send(portal, second_destination, <<16, 9>>)
      end)

    assert <<@peer_mac, @lo_mac, 7::16, @llc, 1, 0, 16, 8>> ==
             await_outgoing(peer, @peer_mac, @lo_mac)

    assert <<second_destination::binary, @lo_mac, 7::16, @llc, 1, 0, 16, 9>> ==
             await_outgoing(peer, second_destination, @lo_mac)

    assert :ok = Task.await(task)
  end

  @tag skip: @raw_socket_skip
  test "frames that are not for this interface are ignored" do
    transport = start_lo!()
    peer = open_peer!(transport)

    write_frame!(peer, transport, <<1, 2, 3, 4, 5, 6>>, @peer_mac, @who_is)
    write_frame!(peer, transport, @broadcast, @lo_mac, @who_is)
    write_raw!(peer, transport, [@peer_mac, @lo_mac, <<0, 64>>, :binary.copy(<<0>>, 20)])

    refute_receive {:bacnet_transport, _, _, _, _}, 150

    write_frame!(peer, transport, @lo_mac, @peer_mac, @who_is)

    assert {:apdu, :original_unicast, %NPCI{}, <<16, 8>>} =
             await_payload(@peer_mac, transport)

    assert EthernetTransport.get_local_address(transport) == @lo_mac
  end

  @tag skip: @raw_socket_skip
  test "a padded payload is cut to the length field" do
    transport = start_lo!()
    peer = open_peer!(transport)
    write_frame!(peer, transport, @broadcast, @peer_mac, @who_is <> <<0, 0, 0, 0, 0>>, 4)

    assert {:apdu, :original_broadcast, %NPCI{}, <<16, 8>>} =
             await_payload(@peer_mac, transport)
  end

  @tag skip: @raw_socket_skip
  test "an undecodable payload and a zero hop count are discarded" do
    transport = start_lo!()
    peer = open_peer!(transport)
    nonce = System.unique_integer([:positive, :monotonic])
    source_mac = <<2, nonce::32, 1>>
    probe_mac = <<2, nonce::32, 2>>

    log =
      capture_log(fn ->
        write_frame!(peer, transport, @lo_mac, source_mac, <<0xFF, 0x00>>)
        write_frame!(peer, transport, @lo_mac, source_mac, <<0x01, 0x20, 0, 1, 0, 0, 16, 8>>)

        # This probe follows both discarded frames. Its distinct source keeps
        # loopback duplicates separate from any incorrectly delivered payloads.
        write_frame!(peer, transport, @broadcast, probe_mac, @who_is)

        assert {:apdu, :original_broadcast, %NPCI{}, <<16, 8>>} =
                 await_payload(probe_mac, transport)
      end)

    assert log =~ "decoding IEEE 802.3"

    refute_received {:bacnet_transport, {:bacnet_ethernet, EthernetTransport}, ^source_mac, _data,
                     _portal}
  end

  @tag skip: @raw_socket_skip
  test "a network-layer message is delivered" do
    transport = start_lo!()
    peer = open_peer!(transport)
    npci = IO.iodata_to_binary(NPCI.encode(NPCI.new(is_network_message: true)))
    write_frame!(peer, transport, @lo_mac, @peer_mac, npci <> <<0, 0, 1>>)

    assert {:network, :original_unicast, %NPCI{is_network_message: true},
            %NetworkLayerProtocolMessage{}} = await_payload(@peer_mac, transport)
  end

  @tag skip: @raw_socket_skip
  test "a function, an mfa, and a dead name can be the callback" do
    parent = self()

    transport =
      start_lo!(
        callback: fn source, data, portal -> send(parent, {:cb, source, data, portal}) end
      )

    peer = open_peer!(transport)
    write_frame!(peer, transport, @broadcast, @peer_mac, @who_is)

    assert_receive {:cb, @peer_mac, {:apdu, :original_broadcast, %NPCI{}, <<16, 8>>}, portal},
                   1_000

    assert portal == EthernetTransport.get_portal(transport)
    drain_callbacks()

    Process.register(self(), :eth_cb_parent)

    on_exit(fn ->
      if Process.whereis(:eth_cb_parent) == self(), do: Process.unregister(:eth_cb_parent)
    end)

    mfa = start_lo!(callback: {__MODULE__, :ethernet_callback, 3})
    mfa_peer = open_peer!(mfa)
    write_frame!(mfa_peer, mfa, @lo_mac, @peer_mac, @who_is)
    assert_receive {:mfa, @peer_mac, {:apdu, :original_unicast, %NPCI{}, <<16, 8>>}, _}, 1_000

    dead = start_lo!(callback: :eth_missing_callback)
    dead_peer = open_peer!(dead)
    write_frame!(dead_peer, dead, @broadcast, @peer_mac, @who_is)
    refute_receive {:bacnet_transport, _, _, _, _}, 150
    assert EthernetTransport.get_local_address(dead) == @lo_mac

    {:ok, sup} = Task.Supervisor.start_link()

    tasked =
      start_lo!(
        supervisor: sup,
        callback: fn source, data, portal -> send(parent, {:task, source, data, portal}) end
      )

    task_peer = open_peer!(tasked)
    write_frame!(task_peer, tasked, @broadcast, @peer_mac, @who_is)
    assert_receive {:task, @peer_mac, {:apdu, :original_broadcast, %NPCI{}, <<16, 8>>}, _}, 1_000
  end

  @tag skip: @raw_socket_skip
  test "unknown messages leave the transport running" do
    transport = start_lo!()
    send(transport, :unused)
    GenServer.cast(transport, :unused)
    assert {:timeout, _call} = catch_exit(GenServer.call(transport, :unused, 40))
    assert EthernetTransport.get_local_address(transport) == @lo_mac
  end

  @tag skip: @raw_socket_skip
  test "closing the socket from outside stops the transport" do
    transport = start_lo!()
    {socket, _ifindex, _mac} = EthernetTransport.get_portal(transport)
    Process.unlink(transport)
    ref = Process.monitor(transport)
    assert :ok = :socket.close(socket)
    assert_receive {:DOWN, ^ref, :process, ^transport, {:error, :closed}}, 1_000
  end

  def ethernet_callback(source, data, portal) do
    if pid = Process.whereis(:eth_cb_parent), do: send(pid, {:mfa, source, data, portal})
  end

  defp start_lo!(opts \\ []) do
    {callback, opts} = Keyword.pop(opts, :callback, self())

    {:ok, transport} =
      EthernetTransport.open(callback, [eth_ifname: "lo"] ++ opts)

    on_exit(fn ->
      if Process.alive?(transport) do
        try do
          EthernetTransport.close(transport)
        catch
          :exit, _reason -> :ok
        end
      end
    end)

    transport
  end

  defp open_peer!(transport) do
    {_socket, ifindex, _mac} = EthernetTransport.get_portal(transport)
    {:ok, peer} = :socket.open(17, 3, 3)
    :ok = :socket.bind(peer, %{family: 17, addr: <<3::16, ifindex::32-native, 0::112>>})
    :socket.setopt(peer, :socket, :rcvbuf, 1_048_576)

    on_exit(fn ->
      try do
        :socket.close(peer)
      catch
        _kind, _reason -> :ok
      end
    end)

    peer
  end

  defp write_frame!(peer, transport, dst, src, payload, len \\ nil) do
    {_socket, ifindex, _mac} = EthernetTransport.get_portal(transport)
    len = len || byte_size(payload)
    frame = [dst, src, <<len::16>>, @llc, payload]
    assert :ok = :socket.sendto(peer, frame, packet_addr(ifindex), [], 1_000)
  end

  defp write_raw!(peer, transport, frame) do
    {_socket, ifindex, _mac} = EthernetTransport.get_portal(transport)
    assert :ok = :socket.sendto(peer, frame, packet_addr(ifindex), [], 1_000)
  end

  defp packet_addr(ifindex) do
    %{family: 17, addr: <<0::16, ifindex::32-native, 0::128>>}
  end

  defp await_payload(source, transport, deadline \\ System.monotonic_time(:millisecond) + 1_000) do
    receive do
      {:bacnet_transport, {:bacnet_ethernet, EthernetTransport}, ^source, data, _portal} ->
        data
    after
      0 ->
        assert System.monotonic_time(:millisecond) < deadline,
               "expected an Ethernet callback from #{inspect(source)}"

        # Address queries schedule an immediate receive pass, draining queued
        # loopback traffic without waiting for each 50 ms receive timeout.
        assert EthernetTransport.get_local_address(transport) == @lo_mac
        await_payload(source, transport, deadline)
    end
  end

  defp drain_callbacks() do
    receive do
      {:bacnet_transport, _protocol, _source, _message, _transport} -> drain_callbacks()
    after
      150 -> :ok
    end
  end

  defp drain_peer(peer) do
    case :socket.recvfrom(peer, 2_000, [], 0) do
      {:ok, {_address, _packet}} -> drain_peer(peer)
      _other -> :ok
    end
  end

  defp await_outgoing(peer, dst, src) do
    await_outgoing(peer, dst, src, 80)
  end

  defp await_outgoing(peer, dst, src, attempts) do
    # AF_PACKET carries individual Ethernet frames. A sized recv/4 can wait
    # for more bytes and return concatenated frames inside a timeout result.
    case :socket.recvfrom(peer, 2_000, [], 100) do
      {:ok, {_address, <<^dst::binary-size(6), ^src::binary-size(6), _rest::binary>> = frame}} ->
        frame

      {:ok, _other} when attempts > 1 ->
        await_outgoing(peer, dst, src, attempts - 1)

      {:error, :timeout} when attempts > 1 ->
        await_outgoing(peer, dst, src, attempts - 1)

      other ->
        flunk(
          "expected a frame from #{inspect(src)} to #{inspect(dst)}, last result #{inspect(other)}"
        )
    end
  end

  defp binary_contains?(frame, needle) do
    :binary.match(frame, needle) != :nomatch
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
end
