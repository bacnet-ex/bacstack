defmodule BACnet.Test.Stack.Transport.ScTransport.ConnectionTest do
  alias BACnet.Protocol.SecureConnect.BVLC
  alias BACnet.Stack.Transport.ScTransport.Connection
  alias BACnet.Stack.Transport.ScTransport.Credentials
  alias BACnet.Stack.Transport.ScTransport.Hub

  use BACnet.Test.Stack.Case, async: false

  @moduletag skip: not BACstack.MixProject.sc_enabled?()

  @vmac <<2, 0, 0, 0, 0, 1>>
  @peer <<2, 0, 0, 0, 0, 2>>
  @config %{
    vmac: @vmac,
    device_uuid: <<1::size(128)>>,
    connect_wait_timeout: 10,
    heartbeat_timeout: 300,
    disconnect_wait_timeout: 10
  }

  test "rejects sends during handshake and handles malformed or unsupported WebSocket frames" do
    connection = open()

    pending = %BVLC{
      function: :heartbeat_request,
      id: 9,
      source: nil,
      destination: nil,
      destination_options: [],
      data_options: [],
      payload: <<>>
    }

    assert {:error, :not_connected} = GenServer.call(connection, :flush)
    assert {:error, :not_connected} = GenServer.call(connection, {:send_frame, pending})

    assert {:error, :not_connected} =
             GenServer.call(connection, {:send_npdu, @peer, <<1, 0>>, []})

    GenServer.cast(connection, :ignored)
    send(connection, :ignored)
    incoming(connection, :ping)
    incoming(connection, {:binary, :binary.copy(<<0>>, 65_536)})
    incoming(connection, {:binary, <<255, 0, 0, 9>>})

    assert %BVLC{function: :result, id: 9, payload: <<255, 1, 0, 7::size(16), 143::size(16)>>} =
             outgoing()

    incoming(connection, {:binary, <<1>>})

    incoming(connection, %{pending | destination_options: [{1, true, nil}]})

    assert %BVLC{function: :result, id: 9, payload: <<10, 1, 65, 7::size(16), 146::size(16)>>} =
             outgoing()

    incoming(connection, pending)
    incoming(connection, {:text, "invalid for BACnet/SC"})
    assert_receive {:sc_send, {:close, 1003, ""}}
    expire_timer(connection)
    assert_receive {:sc_connection, ^connection, {:closed, :unsupported_data}}
  end

  test "applies advertised send limits and correlates liveness and disconnect requests" do
    connection = open()
    establish(connection, 30, 5)

    large_npdu = %BVLC{
      function: :npdu,
      id: 31,
      source: nil,
      destination: @peer,
      destination_options: [],
      data_options: [],
      payload: <<1, 0, 0, 0, 0, 0>>
    }

    assert {:error, :peer_npdu_too_long} = GenServer.call(connection, {:send_frame, large_npdu})

    assert {:error, :peer_npdu_too_long} =
             GenServer.call(connection, {:send_npdu, @peer, large_npdu.payload, []})

    Connection.transmit(connection, large_npdu)
    refute_receive {:sc_send, _frame}, 25

    assert {:error, :peer_bvlc_too_long} =
             GenServer.call(
               connection,
               {:send_npdu, @peer, <<1, 0>>, [{2, false, :binary.copy(<<0>>, 16)}]}
             )

    expire_timer(connection)
    assert %BVLC{function: :heartbeat_request} = heartbeat = outgoing()
    incoming(connection, BVLC.response(heartbeat, :heartbeat_ack))
    assert %{phase: :connected} = :sys.get_state(connection)

    flush = Task.async(fn -> GenServer.call(connection, :flush) end)
    assert %BVLC{function: :heartbeat_request, id: flush_id} = outgoing()
    send(connection, {:flush_timeout, flush_id})
    assert {:error, :heartbeat_timeout} = Task.await(flush)

    Connection.disconnect(connection)
    assert %BVLC{function: :disconnect_request} = request = outgoing()
    incoming(connection, BVLC.nak(request, 80))
    assert_receive {:sc_send, {:close, 1000, ""}}
    incoming(connection, :close)
    assert_receive {:sc_connection, ^connection, {:closed, :closed}}
  end

  test "closes the WebSocket when the handshake or disconnect acknowledgment is overdue" do
    incomplete = open()
    expire_timer(incomplete)
    assert_receive {:sc_send, {:close, 1000, ""}}
    incoming(incomplete, :close)
    assert_receive {:sc_connection, ^incomplete, {:closed, :connect_timeout}}

    connected = open()
    establish(connected, 65_535, 1497)
    Connection.disconnect(connected)
    assert %BVLC{function: :disconnect_request} = outgoing()
    expire_timer(connected)
    assert_receive {:sc_send, {:close, 1000, ""}}
    incoming(connected, :close)
    assert_receive {:sc_connection, ^connected, {:closed, :closed}}
  end

  test "dials IPv4 and IPv6 hubs, flushes traffic, and reports HTTP upgrade failures" do
    assert Connection.subprotocol() == "hub.bsc.bacnet.org"
    assert Connection.websocket_limit() == 131_072
    credentials = make_credentials()
    config = Map.put(@config, :credentials, credentials)

    for {ip, host} <- [{{127, 0, 0, 1}, "127.0.0.1"}, {{0, 0, 0, 0, 0, 0, 0, 1}, "[::1]"}] do
      hub = start_hub(ip, credentials)
      uri = URI.parse("wss://#{host}:#{Hub.port(hub)}/")
      {:ok, connection} = Connection.start(self(), {:client, :primary, uri}, config)
      assert_receive {:sc_connection, ^connection, {:ready, %{vmac: @peer}}}
      assert :ok = GenServer.call(connection, :flush)

      frame = frame(:npdu, <<1, 0>>)
      assert :ok = GenServer.call(connection, {:send_frame, frame})
      assert_receive {:sc_connection, ^connection, {:frame, %BVLC{function: :result, id: 21}}}
      assert :ok = GenServer.call(connection, {:send_npdu, @peer, <<1, 0>>, []})

      GenServer.cast(connection, {:advertise, nil, <<1, 0, 65_535::16, 1497::16>>})
      assert_receive {:sc_connection, ^connection, {:frame, %BVLC{function: :result}}}

      Connection.disconnect(connection)
      assert_receive {:sc_connection, ^connection, {:closed, :closed}}

      {:ok, rejected} =
        Connection.start(
          self(),
          {:client, :primary, %{uri | host: "localhost", path: "/missing"}},
          Map.put(config, :ip_family, family(ip))
        )

      assert_receive {:sc_connection, ^rejected, {:closed, {:http_status, 404}}}
      :ok = Hub.close(hub)
    end
  end

  test "routes established server traffic, answers heartbeats, and acknowledges peer disconnects" do
    connection = open()
    establish(connection, 65_535, 1497)
    request = frame(:npdu, <<1, 0>>)
    Connection.transmit(connection, request)
    assert ^request = outgoing()
    incoming(connection, request)
    assert_receive {:"$gen_call", from, {:route, ^connection, ^request}}
    GenServer.reply(from, :ok)

    incoming(connection, frame(:heartbeat_request, <<>>))
    assert %BVLC{function: :heartbeat_ack, id: 21} = outgoing()
    incoming(connection, frame(:disconnect_request, <<>>))
    assert %BVLC{function: :disconnect_ack, id: 21} = outgoing()
    assert_receive {:sc_send, {:close, 1000, ""}}
    incoming(connection, {:close, 1000, ""})
    assert_receive {:sc_connection, ^connection, {:closed, :closed}}
  end

  test "reports why the client transport closed before any BACnet disconnect exchange" do
    credentials = make_credentials()
    config = Map.put(@config, :credentials, credentials)
    hub = start_hub({127, 0, 0, 1}, credentials)
    uri = URI.parse("wss://127.0.0.1:#{Hub.port(hub)}/")

    failures = [
      {fn socket, stream -> {:gun_error, socket, stream, :econnreset} end,
       {:gun_error, :econnreset}},
      {fn socket, _stream -> {:gun_error, socket, :timeout} end, {:gun_error, :timeout}},
      {fn socket, _stream -> {:gun_error, socket, {:shutdown, {:options, {:key, :private}}}} end,
       {:gun_error, {:shutdown, :invalid_options}}},
      {fn socket, _stream -> {:gun_down, socket, :ws, :closed, []} end, {:gun_down, :closed}},
      {fn socket, stream -> {:gun_ws, socket, stream, {:close, 1000, ""}} end,
       {:websocket_closed, 1000}},
      {fn socket, _stream -> :gun.close(socket) end, {:gun_process_down, :shutdown}}
    ]

    for {notify, reason} <- failures do
      {:ok, connection} = Connection.start(self(), {:client, :primary, uri}, config)
      assert_receive {:sc_connection, ^connection, {:ready, %{vmac: @peer}}}
      %{socket: socket, stream: stream} = :sys.get_state(connection)

      case notify.(socket, stream) do
        :ok -> :ok
        message -> send(connection, message)
      end

      assert_receive {:sc_connection, ^connection, {:closed, ^reason}}
    end

    {:ok, rejected} =
      Connection.start(self(), {:client, :primary, uri}, %{config | connect_wait_timeout: -1})

    assert_receive {:sc_connection, ^rejected, {:closed, {:gun_open, :invalid_options}}}
    :ok = Hub.close(hub)
  end

  test "rejects a Connect-Request when the hub cannot register the peer" do
    connection = open()
    incoming(connection, frame(:connect_request, BVLC.identity(@peer, <<2::128>>)))
    assert_receive {:"$gen_call", from, {:register, ^connection, %{vmac: @peer}}}
    GenServer.reply(from, {:error, 151})
    assert %BVLC{function: :result, id: 21, payload: <<6, 1, 0, 0, 7, 0, 151>>} = outgoing()
    assert_receive {:sc_send, {:close, 1000, ""}}
    incoming(connection, :close)
    assert_receive {:sc_connection, ^connection, {:closed, {:connect_rejected, 151}}}
  end

  test "retains a malformed Connect-Request error even if the peer times out" do
    connection = open()
    incoming(connection, {:binary, <<6, 0, 0, 21>>})
    assert %BVLC{function: :result, id: 21} = outgoing()
    assert_receive {:sc_connection, ^connection, {:connect_failed, 149}}

    expire_timer(connection)
    assert_receive {:sc_send, {:close, 1000, ""}}
    incoming(connection, :close)
    assert_receive {:sc_connection, ^connection, {:closed, {:connect_rejected, 149}}}
  end

  test "retains Gun's TCP stage for a failed dial" do
    credentials = make_credentials()
    {:ok, socket} = :gen_tcp.listen(0, ip: {127, 0, 0, 1})
    {:ok, port} = :inet.port(socket)
    :ok = :gen_tcp.close(socket)
    uri = URI.parse("wss://127.0.0.1:#{port}/")

    {:ok, connection} =
      Connection.start(
        self(),
        {:client, :primary, uri},
        Map.put(@config, :credentials, credentials)
      )

    assert_receive {:sc_connection, ^connection, {:closed, {:dial_error, :tcp, :econnrefused}}}
  end

  test "expires a heartbeat and tolerates a repeated disconnect command" do
    connection = open()
    establish(connection, 65_535, 1497)

    _log =
      ExUnit.CaptureLog.capture_log([level: :debug], fn ->
        expire_timer(connection)
        assert %BVLC{function: :heartbeat_request} = outgoing()
        expire_timer(connection)
        assert %BVLC{function: :disconnect_request} = request = outgoing()
        Connection.disconnect(connection)
        incoming(connection, BVLC.response(request, :disconnect_ack))
        assert_receive {:sc_send, {:close, 1000, ""}}
        incoming(connection, :close)
        assert_receive {:sc_connection, ^connection, {:closed, :heartbeat_timeout}}
      end)

    # assert log =~ "in connected - Entering probing"
    # assert log =~ "in probing - Entering disconnecting"
    # assert log =~ "in disconnecting - Entering closing"
    # assert log =~ "in closing - Ended session with :heartbeat_timeout"
  end

  test "closes when its owner or WebSocket disappears and redacts runtime diagnostics" do
    assert %{state: :redacted, message: :redacted, log: []} =
             Connection.format_status(%{state: :secret, message: :secret, log: [:secret]})

    owner =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    {:ok, connection} = Connection.start(owner, {:server, self()}, @config)
    send(owner, :stop)
    assert_receive {:sc_send, {:close, 1000, ""}}
    incoming(connection, :close)

    websocket =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    {:ok, connection} = Connection.start(self(), {:server, websocket}, @config)
    send(websocket, :stop)
    assert_receive {:sc_connection, ^connection, {:closed, :normal}}
  end

  defp make_credentials() do
    ca_key = X509.PrivateKey.new_ec(:secp256r1)
    ca = X509.Certificate.self_signed(ca_key, "/CN=Connection CA", template: :root_ca)
    key = X509.PrivateKey.new_ec(:secp256r1)

    cert =
      X509.Certificate.new(X509.PublicKey.derive(key), "/CN=Connection peer", ca, ca_key,
        template: :server
      )

    {:ok, credentials} =
      Credentials.from_pem(X509.Certificate.to_pem(cert), X509.PrivateKey.to_pem(key), [
        X509.Certificate.to_pem(ca)
      ])

    credentials
  end

  defp start_hub(ip, credentials) do
    opts = [ip: ip, port: 0, credentials: credentials, vmac: @peer, device_uuid: <<2::128>>]
    start_supervised!(Supervisor.child_spec({Hub, opts}, id: make_ref(), restart: :temporary))
  end

  defp family(ip), do: if(tuple_size(ip) == 8, do: :inet6, else: :inet)

  defp frame(function, payload) do
    %BVLC{
      function: function,
      id: 21,
      payload: payload,
      source: nil,
      destination: nil,
      destination_options: [],
      data_options: []
    }
  end

  defp open() do
    {:ok, connection} = Connection.start(self(), {:server, self()}, @config)
    connection
  end

  defp establish(connection, max_bvlc, max_npdu) do
    request = %BVLC{
      function: :connect_request,
      id: 8,
      source: nil,
      destination: nil,
      destination_options: [],
      data_options: [],
      payload: <<@peer::binary, 2::size(128), max_bvlc::size(16), max_npdu::size(16)>>
    }

    incoming(connection, request)
    assert_receive {:"$gen_call", from, {:register, ^connection, %{max_npdu: ^max_npdu}}}
    GenServer.reply(from, :ok)
    assert %BVLC{function: :connect_accept, id: 8} = outgoing()
  end

  defp incoming(connection, %BVLC{} = frame),
    do: incoming(connection, {:binary, BVLC.encode(frame)})

  defp incoming(connection, frame), do: send(connection, {:sc_websocket, self(), frame})

  defp outgoing() do
    assert_receive {:sc_send, {:binary, binary}}
    assert {:ok, frame} = BVLC.decode(binary)
    frame
  end

  defp expire_timer(connection) do
    %{timer: {timer, token}} = :sys.get_state(connection)
    Process.cancel_timer(timer)
    send(connection, {:sc_timeout, token})
  end
end
