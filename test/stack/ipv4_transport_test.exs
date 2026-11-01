defmodule BACnet.Stack.Transport.IPv4TransportTest do
  alias BACnet.Protocol.BvlcResult
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.NetworkLayerProtocolMessage
  alias BACnet.Protocol.NPCI
  alias BACnet.Protocol.NpciTarget
  alias BACnet.Stack.EncoderProtocol
  alias BACnet.Stack.Transport.IPv4Transport
  alias BACnet.Test.Stack.ApduFactory

  require Constants

  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  @moduletag :stack
  @moduletag :ipv4_transport

  @sink BACnet.Stack.Transport.IPv4TransportTest.Sink

  test "reports protocol limits and validates destinations" do
    assert IPv4Transport.bacnet_protocol() == :bacnet_ipv4
    assert IPv4Transport.max_apdu_length() == 1476
    assert IPv4Transport.max_npdu_length() == 1462

    assert IPv4Transport.valid_destination?({{1, 2, 3, 4}, 47_808})
    assert IPv4Transport.valid_destination?({{255, 255, 255, 255}, 65_535})
    refute IPv4Transport.valid_destination?({{0, 0, 0, 1}, 1})
    refute IPv4Transport.valid_destination?({{1, 2, 3, 0}, 1})
    refute IPv4Transport.valid_destination?({{1, 2, 3, 4}, 0})
    refute IPv4Transport.valid_destination?(:peer)
  end

  test "enumerates interfaces and looks up an interface address" do
    assert {:ok, ifs} = IPv4Transport.getifaddrs()
    assert is_map(ifs)
    assert {:ok, {127, 0, 0, 1}} = IPv4Transport.get_address_for_ifname("lo")
    assert {:error, :not_found} = IPv4Transport.get_address_for_ifname("no-such-if-bacstack")
  end

  test "open rejects bad arguments" do
    assert_raise ArgumentError, ~r/keyword list/, fn ->
      IPv4Transport.open(self(), %{})
    end

    assert_raise ArgumentError, ~r/callback/, fn ->
      IPv4Transport.open(fn _one -> :ok end, [])
    end

    assert_raise ArgumentError, ~r/callback/, fn ->
      IPv4Transport.open(123, [])
    end

    assert_raise ArgumentError, ~r/not exported/, fn ->
      IPv4Transport.open({__MODULE__, :missing_callback, 3}, [])
    end

    assert_raise ArgumentError, ~r/bacnet_port/, fn ->
      IPv4Transport.open(self(), bacnet_port: 0)
    end

    assert_raise ArgumentError, ~r/local_ip/, fn ->
      IPv4Transport.open(self(), local_ip: {1, 2, 3, 255})
    end

    assert_raise ArgumentError, ~r/recbuffer_size/, fn ->
      IPv4Transport.open(self(), recbuffer_size: 0)
    end

    assert_raise ArgumentError, ~r/supervisor/, fn ->
      IPv4Transport.open(self(), supervisor: "nope")
    end
  end

  test "a port outside the BACnet range warns and still opens" do
    port = free_port(20_000..20_200)

    log =
      capture_log(fn ->
        {transport, ^port} = open!(self(), bacnet_port: port)
        assert IPv4Transport.get_local_address(transport) == {{0, 0, 0, 0}, port}
      end)

    assert log =~ "outside of the port range"
  end

  test "child_spec points open at the callback and options" do
    opts = [local_ip: :none, bacnet_port: 50_001]
    spec = IPv4Transport.child_spec([self(), opts])
    assert spec.id == IPv4Transport
    assert spec.start == {IPv4Transport, :open, [self(), opts]}
    assert IPv4Transport.child_spec(self(), opts).start == spec.start
  end

  test "an unbound transport reports the wildcard address and routes foreign hosts" do
    {transport, port} = open!(self(), [])
    assert IPv4Transport.get_local_address(transport) == {{0, 0, 0, 0}, port}
    assert IPv4Transport.get_broadcast_address(transport) == {{255, 255, 255, 255}, port}
    assert is_port(IPv4Transport.get_portal(transport))

    assert IPv4Transport.destination_routed?(transport, {{192, 168, 1, 9}, 1})
    assert IPv4Transport.destination_routed?(transport, {{127, 0, 0, 2}, 1})
    refute IPv4Transport.destination_routed?(transport, {{255, 255, 255, 255}, 1})
    assert IPv4Transport.destination_routed?(transport, :not_an_ip)
    assert IPv4Transport.destination_routed?(transport, {{256, 0, 0, 1}, 1})

    name = :"ipv4_#{System.unique_integer([:positive])}"
    {named, named_port} = open!(self(), name: name)
    assert Process.whereis(name) == named
    assert IPv4Transport.get_local_address(named) == {{0, 0, 0, 0}, named_port}
  end

  test "send wraps a unicast, a broadcast, a custom BVLC, and raw bytes" do
    {transport, _port} = open!(self(), [])
    portal = IPv4Transport.get_portal(transport)
    {:ok, peer, peer_port} = peer_socket()

    assert :ok = IPv4Transport.send(portal, {{127, 0, 0, 1}, peer_port}, <<16, 8>>)
    assert <<0x81, 0x0A, _len::16, rest::binary>> = recv_udp(peer)
    assert binary_part(rest, byte_size(rest) - 2, 2) == <<16, 8>>

    who_is = ApduFactory.who_is()

    assert :ok =
             IPv4Transport.send(portal, {{127, 0, 0, 1}, peer_port}, who_is, is_broadcast: true)

    assert <<0x81, 0x0B, _len::16, rest::binary>> = recv_udp(peer)
    assert binary_part(rest, byte_size(rest) - 2, 2) == encoded(who_is)

    assert :ok =
             IPv4Transport.send(portal, {{127, 0, 0, 1}, peer_port}, <<16, 8>>,
               bvlc: <<0x09, 1, 2>>,
               destination: %NpciTarget{net: 65_535, address: nil},
               source: %NpciTarget{net: 1, address: 9}
             )

    assert <<0x81, 0x09, _len::16, 1, 2, rest::binary>> = recv_udp(peer)
    assert binary_part(rest, byte_size(rest) - 2, 2) == <<16, 8>>

    assert :ok =
             IPv4Transport.send(portal, {{127, 0, 0, 1}, peer_port}, <<16, 8>>,
               skip_headers: true,
               npci: NPCI.new([])
             )

    assert recv_udp(peer) == <<16, 8>>

    assert :ok =
             IPv4Transport.send(portal, {{127, 0, 0, 1}, peer_port}, <<>>, bvlc: <<0x0A>>)

    assert <<0x81, 0x0A, _len::16, _rest::binary>> = recv_udp(peer)

    assert :ok =
             IPv4Transport.send(portal, {{255, 255, 255, 255}, peer_port}, [<<16>>, 8], [])
  end

  test "send reports invalid input without transmitting" do
    {transport, _port} = open!(self(), [])
    portal = IPv4Transport.get_portal(transport)
    {:ok, peer, peer_port} = peer_socket()
    destination = {{127, 0, 0, 1}, peer_port}

    assert {:error, :invalid_destination} = IPv4Transport.send(portal, {:peer, 1}, <<16, 8>>, [])

    assert {:error, :invalid_destination} =
             IPv4Transport.send(portal, {{0, 1, 2, 3}, 1}, <<1>>, [])

    assert {:error, :apdu_too_long} =
             IPv4Transport.send(portal, destination, :binary.copy(<<0>>, 1477), [])

    assert {:error, :data_empty} = IPv4Transport.send(portal, destination, <<>>, [])

    assert {:error, :invalid_expects_reply_for_broadcast} =
             IPv4Transport.send(portal, destination, ApduFactory.read_property(),
               is_broadcast: true
             )

    assert_raise ArgumentError, ~r/keyword list/, fn ->
      IPv4Transport.send(portal, destination, <<16, 8>>, [1])
    end

    assert_raise ArgumentError, ~r/bvlc/, fn ->
      IPv4Transport.send(portal, destination, <<16, 8>>, bvlc: :nope)
    end

    assert_raise ArgumentError, ~r/destination/, fn ->
      IPv4Transport.send(portal, destination, <<16, 8>>, destination: :nope)
    end

    assert_raise ArgumentError, ~r/source/, fn ->
      IPv4Transport.send(portal, destination, <<16, 8>>, source: :nope)
    end

    assert_raise MatchError, fn ->
      IPv4Transport.send(portal, destination, <<16, 8>>, bvlc: <<>>)
    end

    refute_received {:udp, ^peer, _, _, _}
  end

  test "a learned own address changes routing and ignores further copies" do
    {transport, port} = open!(self(), [])
    portal = IPv4Transport.get_portal(transport)
    assert :ok = :gen_udp.send(portal, {127, 0, 0, 1}, port, <<0x81, 0x0A, 0, 0>>)

    assert await_local(transport, {{127, 0, 0, 1}, port})
    assert IPv4Transport.get_broadcast_address(transport) == {{127, 255, 255, 255}, port}
    refute IPv4Transport.destination_routed?(transport, {{127, 0, 0, 2}, 1})
    assert IPv4Transport.destination_routed?(transport, {{8, 8, 8, 8}, 1})
    refute_received {:bacnet_transport, _, _, _, _}

    assert :ok = :gen_udp.send(portal, {127, 0, 0, 1}, port, <<0x81, 0x0A, 0, 0>>)
    {:ok, peer, _peer_port} = peer_socket()
    assert :ok = :gen_udp.send(peer, {127, 0, 0, 1}, port, unicast_who_is())

    assert_receive {:bacnet_transport, {:bacnet_ipv4, IPv4Transport}, {{127, 0, 0, 1}, _peer},
                    {:apdu, :original_unicast, %NPCI{}, <<16, 8>>}, ^portal},
                   500

    refute_received {:bacnet_transport, _, _, _, _}
    assert IPv4Transport.get_local_address(transport) == {{127, 0, 0, 1}, port}
  end

  test "incoming frames are delivered to a pid, a function, and an MFA" do
    frame = unicast_who_is()
    {transport, port} = open!(self(), [])
    {:ok, peer, _peer_port} = peer_socket()
    assert :ok = :gen_udp.send(peer, {127, 0, 0, 1}, port, frame)

    assert_receive {:bacnet_transport, {:bacnet_ipv4, IPv4Transport}, {{127, 0, 0, 1}, _},
                    {:apdu, :original_unicast, %NPCI{is_network_message: false}, <<16, 8>>},
                    portal}

    assert portal == IPv4Transport.get_portal(transport)

    parent = self()

    {fun_transport, fun_port} =
      open!(fn source, data, fun_portal -> send(parent, {:fun, source, data, fun_portal}) end, [])

    assert :ok = :gen_udp.send(peer, {127, 0, 0, 1}, fun_port, frame)
    assert_receive {:fun, {{127, 0, 0, 1}, _}, {:apdu, :original_unicast, _, <<16, 8>>}, _}, 500
    assert Process.alive?(fun_transport)

    Process.register(self(), @sink)
    on_exit(fn -> if Process.whereis(@sink), do: Process.unregister(@sink) end)
    {_mfa_transport, mfa_port} = open!({__MODULE__, :deliver_frame, 3}, [])
    assert :ok = :gen_udp.send(peer, {127, 0, 0, 1}, mfa_port, frame)
    assert_receive {:mfa, {{127, 0, 0, 1}, _}, {:apdu, _, _, <<16, 8>>}, _}, 500
  end

  test "a task supervisor runs the callback" do
    {:ok, sup} = Task.Supervisor.start_link()
    parent = self()

    {_transport, port} =
      open!(
        fn source, data, portal -> send(parent, {:task, source, data, portal}) end,
        supervisor: sup
      )

    {:ok, peer, _peer_port} = peer_socket()
    assert :ok = :gen_udp.send(peer, {127, 0, 0, 1}, port, unicast_who_is())
    assert_receive {:task, {{127, 0, 0, 1}, _}, {:apdu, :original_unicast, _, <<16, 8>>}, _}, 500
  end

  test "network, result, and management frames keep their decoded shape" do
    {transport, port} = open!(self(), [])
    portal = IPv4Transport.get_portal(transport)
    {:ok, peer, _peer_port} = peer_socket()

    push(peer, port, frame(0x0A, <<0x01, 0x80, 0x00, 0x00, 0x01>>))

    assert_receive {:bacnet_transport, _, {{127, 0, 0, 1}, _},
                    {:network, :original_unicast, %NPCI{is_network_message: true}, message},
                    ^portal},
                   500

    assert %NetworkLayerProtocolMessage{
             network_message_type: :who_is_router_to_network,
             data: 1
           } = message

    push(peer, port, frame(0x00, <<0x00, 0x00>>))

    assert_receive {:bacnet_transport, _, _,
                    {:bvlc, %BvlcResult{result_code: :successful_completion}}, ^portal},
                   500

    push(peer, port, frame(0x05, <<0, 60>>))

    assert_receive {:bacnet_transport, _, _, {:bvlc, %BACnet.Protocol.BvlcFunction{data: 60}},
                    ^portal},
                   500
  end

  test "malformed frames are discarded and the socket stays active" do
    {transport, port} = open!(self(), [])
    portal = IPv4Transport.get_portal(transport)
    {:ok, peer, _peer_port} = peer_socket()

    log =
      capture_log(fn ->
        push(peer, port, <<0x81, 0x0A, 99::16, 0x01, 0x00>>)
        push(peer, port, <<0x81, 0x00, 6::16, 0xFF, 0xFF>>)
        push(peer, port, frame(0x0A, <<0xFF, 0x00>>))
        refute_receive {:bacnet_transport, _protocol, _source, _message, _transport}, 80
      end)

    assert log =~ "decoding UDP packet"

    push(peer, port, <<1, 2, 3>>)
    push(peer, port, <<0x81, 0x0A>> <> :binary.copy(<<0>>, 1600))
    push(peer, port, frame(0x0A, <<0x01, 0x20, 0xFFFF::16, 0, 0, 16, 8>>))
    refute_receive {:bacnet_transport, _, _, _, _}, 80

    push(peer, port, unicast_who_is())

    assert_receive {:bacnet_transport, _, _, {:apdu, :original_unicast, _, <<16, 8>>}, ^portal},
                   500

    send(transport, {:udp_error, portal, :econnreset})
    send(transport, {:udp_passive, portal})
    {:ok, other} = :gen_udp.open(0, [:inet])
    send(transport, {:udp_passive, other})
    :gen_udp.close(other)
    send(transport, :unused)
    GenServer.cast(transport, :unused)
    assert IPv4Transport.get_local_address(transport) == {{0, 0, 0, 0}, port}
  end

  test "the active window is refilled after a burst of frames" do
    {transport, port} = open!(self(), [])
    portal = IPv4Transport.get_portal(transport)
    {:ok, peer, _peer_port} = peer_socket()

    for n <- 1..12 do
      push(peer, port, frame(0x0A, <<0x01, 0x00, 16, n>>))
    end

    payloads =
      for _n <- 1..12 do
        assert_receive {:bacnet_transport, _protocol, _source,
                        {:apdu, :original_unicast, _npci, <<16, n>>}, ^portal},
                       500

        n
      end

    assert Enum.sort(payloads) == Enum.to_list(1..12)
  end

  test "an unknown call times out and close shuts the socket" do
    {transport, port} = open!(self(), [])
    parent = self()

    spawn(fn ->
      result =
        try do
          GenServer.call(transport, :unused, 40)
        catch
          :exit, reason -> {:exit, reason}
        end

      send(parent, {:call, result})
    end)

    assert_receive {:call, {:exit, {:timeout, _}}}, 500
    ref = Process.monitor(transport)
    assert :ok = IPv4Transport.close(transport)
    assert_receive {:DOWN, ^ref, :process, ^transport, :normal}

    {:ok, probe} = :gen_udp.open(port, [:inet])
    :gen_udp.close(probe)
  end

  test "a closed portal returns a send error" do
    {transport, _port} = open!(self(), [])
    portal = IPv4Transport.get_portal(transport)
    assert :ok = IPv4Transport.close(transport)

    assert {:error, error} =
             IPv4Transport.send(portal, {{127, 0, 0, 1}, 9}, <<16, 8>>, [])

    assert error in [:closed, :einval]
  end

  test "the persistent term selects the broadcast address" do
    previous = Application.get_env(:bacstack, :client_broadcast_addr_in_persistent_term)
    Application.put_env(:bacstack, :client_broadcast_addr_in_persistent_term, true)

    on_exit(fn ->
      if previous == nil do
        Application.delete_env(:bacstack, :client_broadcast_addr_in_persistent_term)
      else
        Application.put_env(:bacstack, :client_broadcast_addr_in_persistent_term, previous)
      end
    end)

    {transport, _port} = open!(self(), [])
    portal = IPv4Transport.get_portal(transport)
    :persistent_term.put({IPv4Transport, portal}, {{127, 0, 0, 1}, 1})
    {:ok, peer, peer_port} = peer_socket()

    assert :ok = IPv4Transport.send(portal, {{127, 0, 0, 1}, peer_port}, <<16, 8>>, [])
    assert <<0x81, 0x0B, _len::16, _rest::binary>> = recv_udp(peer)

    assert :ok = IPv4Transport.close(transport)
    assert :persistent_term.get({IPv4Transport, portal}, :missing) == :missing
  end

  test "binding an address that is already taken stops startup" do
    {_transport, port} = open!(self(), [])

    assert {:error, :eaddrinuse} =
             isolated(fn ->
               IPv4Transport.open(self(), local_ip: :none, bacnet_port: port)
             end)
  end

  test "an interface name selects that interface address" do
    {transport, port} = open!(self(), local_ip: "lo")
    assert IPv4Transport.get_local_address(transport) == {{127, 0, 0, 1}, port}
    assert IPv4Transport.get_broadcast_address(transport) == {{127, 255, 255, 255}, port}
  end

  test "the first private address is used when no local address is given" do
    port = free_port()
    {:ok, transport} = IPv4Transport.open(self(), bacnet_port: port)

    on_exit(fn ->
      if Process.alive?(transport) do
        try do
          IPv4Transport.close(transport)
        catch
          :exit, _reason -> :ok
        end
      end
    end)

    assert {ip, ^port} = IPv4Transport.get_local_address(transport)
    assert private_ip?(ip)
    assert IPv4Transport.destination_routed?(transport, {{8, 8, 8, 8}, 1})
    refute IPv4Transport.destination_routed?(transport, {ip, 1})
  end

  test "an address without a local subnet stops startup" do
    assert {:error, {%RuntimeError{message: message}, _stack}} =
             isolated(fn ->
               IPv4Transport.open(self(), local_ip: {1, 2, 3, 4}, bacnet_port: free_port())
             end)

    assert message =~ "No broadcast address"
  end

  test "supervisor references are accepted when they only name a supervisor" do
    for supervisor <- [
          :ipv4_sup,
          {:global, :ipv4_sup},
          {:via, Agent, :ipv4_sup},
          {:ipv4_sup, node()}
        ] do
      {transport, port} = open!(self(), supervisor: supervisor)
      assert IPv4Transport.get_local_address(transport) == {{0, 0, 0, 0}, port}
    end
  end

  test "a missing interface name stops startup" do
    assert {:error, {%RuntimeError{message: message}, _stack}} =
             isolated(fn ->
               IPv4Transport.open(self(),
                 local_ip: "no-such-if-bacstack",
                 bacnet_port: free_port()
               )
             end)

    assert message =~ "no-such-if-bacstack"
  end

  test "binding loopback opens the broadcast socket and receives directed frames" do
    {transport, port} = open!(self(), local_ip: {127, 0, 0, 1})
    assert IPv4Transport.get_local_address(transport) == {{127, 0, 0, 1}, port}
    assert IPv4Transport.get_broadcast_address(transport) == {{127, 255, 255, 255}, port}
    refute IPv4Transport.destination_routed?(transport, {{127, 1, 2, 3}, 1})
    assert IPv4Transport.destination_routed?(transport, {{10, 0, 0, 1}, 1})

    portal = IPv4Transport.get_portal(transport)
    assert :inet.getopts(portal, [:reuseaddr]) == {:ok, [reuseaddr: false]}

    {:ok, peer, _peer_port} = peer_socket()
    push(peer, port, unicast_who_is())

    assert_receive {:bacnet_transport, _, {{127, 0, 0, 1}, _},
                    {:apdu, :original_unicast, _, <<16, 8>>}, ^portal},
                   500

    assert :ok = :gen_udp.send(portal, {127, 0, 0, 1}, port, unicast_who_is())
    refute_receive {:bacnet_transport, _, _, _, _}, 80

    assert :ok = IPv4Transport.close(transport)
    {:ok, rebound} = :gen_udp.open(port, [:inet, {:ip, {127, 0, 0, 1}}])
    :gen_udp.close(rebound)
  end

  test "reuseaddr, a receive buffer, and the socket backend are accepted" do
    {transport, port} =
      open!(self(), reuseaddr: true, recbuffer_size: 8192, inet_backend: :inet)

    portal = IPv4Transport.get_portal(transport)
    assert {:ok, [reuseaddr: true]} = :inet.getopts(portal, [:reuseaddr])
    assert {:ok, [recbuf: size]} = :inet.getopts(portal, [:recbuf])
    assert size >= 8192

    {socket_transport, socket_port} =
      open!(self(), inet_backend: :socket, reuseport: true, reuseaddr: true)

    socket_portal = IPv4Transport.get_portal(socket_transport)
    refute is_port(socket_portal)
    {:ok, peer, _peer_port} = peer_socket()
    push(peer, socket_port, unicast_who_is())

    assert_receive {:bacnet_transport, {:bacnet_ipv4, IPv4Transport}, {{127, 0, 0, 1}, _},
                    {:apdu, :original_unicast, _, <<16, 8>>}, ^socket_portal},
                   500

    assert IPv4Transport.get_broadcast_address(transport) == {{255, 255, 255, 255}, port}
  end

  test "a callback atom that is not registered is ignored" do
    {transport, port} = open!(:bacstack_ipv4_missing_callback, [])
    {:ok, peer, _peer_port} = peer_socket()
    push(peer, port, unicast_who_is())
    refute_receive {:bacnet_transport, _, _, _, _}, 80
    assert IPv4Transport.get_broadcast_address(transport) == {{255, 255, 255, 255}, port}
  end

  def deliver_frame(source, data, portal) do
    case Process.whereis(@sink) do
      pid when is_pid(pid) -> send(pid, {:mfa, source, data, portal})
      nil -> :ok
    end
  end

  defp open!(callback, opts) do
    port = Keyword.get(opts, :bacnet_port) || free_port()
    opts = Keyword.put(opts, :bacnet_port, port)
    {:ok, transport} = IPv4Transport.open(callback, Keyword.put_new(opts, :local_ip, :none))

    on_exit(fn ->
      if Process.alive?(transport) do
        try do
          IPv4Transport.close(transport)
        catch
          :exit, _reason -> :ok
        end
      end
    end)

    {transport, port}
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

  defp free_port(range \\ 50_000..65_000) do
    Enum.find_value(1..30, fn _attempt ->
      port = Enum.random(range)

      case :gen_udp.open(port, [:inet]) do
        {:ok, sock} ->
          :gen_udp.close(sock)
          port

        {:error, _reason} ->
          nil
      end
    end) || raise "no free UDP port in #{inspect(range)}"
  end

  defp peer_socket() do
    {:ok, peer} = :gen_udp.open(0, [:binary, :inet, {:active, true}])
    {:ok, peer_port} = :inet.port(peer)
    {:ok, peer, peer_port}
  end

  defp recv_udp(peer) do
    assert_receive {:udp, ^peer, _ip, _port, data}, 500
    data
  end

  defp push(peer, port, packet) do
    assert :ok = :gen_udp.send(peer, {127, 0, 0, 1}, port, packet)
  end

  defp frame(function, payload) do
    <<0x81, function, 4 + byte_size(payload)::16, payload::binary>>
  end

  defp unicast_who_is() do
    frame(0x0A, <<0x01, 0x00, 16, 8>>)
  end

  defp encoded(apdu) do
    IO.iodata_to_binary(EncoderProtocol.encode(apdu))
  end

  defp private_ip?({10, _second, _third, _fourth}), do: true
  defp private_ip?({172, second, _third, _fourth}) when second in 16..31, do: true
  defp private_ip?({192, 168, _third, _fourth}), do: true
  defp private_ip?(_other), do: false

  defp await_local(transport, expected, attempts \\ 20) do
    case IPv4Transport.get_local_address(transport) do
      ^expected ->
        expected

      _other when attempts > 0 ->
        Process.sleep(25)
        await_local(transport, expected, attempts - 1)

      other ->
        other
    end
  end
end
