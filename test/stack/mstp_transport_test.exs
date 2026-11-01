defmodule BACnet.Stack.Transport.MstpTransportTest do
  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.NPCI
  alias BACnet.Stack.EncoderProtocol
  alias BACnet.Stack.Transport.MstpTransport
  alias BACnet.Stack.Transport.MstpTransport.EncodingTools
  alias BACnet.Test.Stack.ApduFactory
  alias Circuits.UART

  use ExUnit.Case, async: false

  @moduletag :stack
  @moduletag :mstp_transport

  @who_is <<0x01, 0x00, 16, 8>>

  test "reports protocol limits and validates destinations" do
    assert MstpTransport.bacnet_protocol() == :bacnet_mstp
    assert MstpTransport.max_apdu_length() == 501
    assert MstpTransport.max_npdu_length() == 501
    assert MstpTransport.max_ext_apdu_length() == 1476
    assert MstpTransport.max_ext_npdu_length() == 1476

    assert MstpTransport.valid_destination?(0)
    assert MstpTransport.valid_destination?(255)
    refute MstpTransport.valid_destination?(-1)
    refute MstpTransport.valid_destination?(256)
    refute MstpTransport.valid_destination?(:peer)
  end

  test "open rejects bad arguments" do
    assert_raise ArgumentError, ~r/keyword list/, fn ->
      MstpTransport.open(self(), %{})
    end

    assert_raise ArgumentError, ~r/callback/, fn ->
      MstpTransport.open(fn _one -> :ok end, port_name: "x", local_address: 1)
    end

    assert_raise ArgumentError, ~r/not exported/, fn ->
      MstpTransport.open({__MODULE__, :missing, 3}, port_name: "x", local_address: 1)
    end

    assert_raise ArgumentError, ~r/local_address/, fn ->
      MstpTransport.open(self(), port_name: "pty", local_address: 255)
    end

    assert_raise ArgumentError, ~r/port_name/, fn ->
      MstpTransport.open(self(), local_address: 1)
    end

    assert_raise ArgumentError, ~r/baudrate/, fn ->
      MstpTransport.open(self(), port_name: "pty", local_address: 1, baudrate: -1)
    end

    assert_raise ArgumentError, ~r/max_master_address/, fn ->
      MstpTransport.open(self(), port_name: "pty", local_address: 1, max_master_address: 0)
    end

    assert_raise ArgumentError, ~r/max_info_frames/, fn ->
      MstpTransport.open(self(), port_name: "pty", local_address: 1, max_info_frames: 0)
    end

    assert_raise ArgumentError, ~r/log_communication/, fn ->
      MstpTransport.open(self(), port_name: "pty", local_address: 1, log_communication: :yes)
    end
  end

  test "child_spec points open at the callback and options" do
    opts = [port_name: "pty", local_address: 1]
    spec = MstpTransport.child_spec([self(), opts])
    assert spec.id == MstpTransport
    assert spec.start == {MstpTransport, :open, [self(), opts]}
    assert MstpTransport.child_spec(self(), opts).start == spec.start
  end

  test "a missing serial port stops startup" do
    assert {:error, :enoent} =
             isolated(fn ->
               MstpTransport.open(self(),
                 port_name: "/dev/does-not-exist-mstp",
                 local_address: 1
               )
             end)
  end

  test "a master on a pty reports its address and accepts a broadcast who-is" do
    %{transport: transport, peer: peer} = start_master!(local_address: 5, max_master_address: 8)

    assert MstpTransport.get_local_address(transport) == 5
    assert MstpTransport.get_broadcast_address(transport) == 255
    assert MstpTransport.get_portal(transport) == transport
    assert MstpTransport.get_baudrate(transport) == 38_400
    assert MstpTransport.get_state(transport) == :idle
    refute MstpTransport.destination_routed?(transport, 5)
    assert MstpTransport.destination_routed?(transport, :remote)

    write_frame!(peer, data_frame(6, 255, 9, @who_is))

    assert_receive {:bacnet_transport, {:bacnet_mstp, MstpTransport}, 9,
                    {:apdu, :original_broadcast, %NPCI{}, <<16, 8>>}, ^transport},
                   1_000

    assert :ok = MstpTransport.set_maintenance_pfm(transport, false)
    assert :ok = MstpTransport.set_maintenance_pfm(transport, true)
    assert :ok = MstpTransport.disable_token_passing(transport)
    assert {:error, :token_passing_disabled} = MstpTransport.send(transport, 9, <<16, 8>>)
    assert {:error, :token_passing_disabled} = MstpTransport.send_test(transport, 9, "ping")
  end

  test "a confirmed request can be postponed and a later reply is sent" do
    %{transport: transport, peer: peer} = start_master!(local_address: 4, max_master_address: 4)
    request = confirmed_npdu()
    write_frame!(peer, data_frame(5, 4, 8, request))

    assert_receive {:bacnet_transport, {:bacnet_mstp, MstpTransport}, 8,
                    {:apdu, :original_unicast, %NPCI{expects_reply: true}, raw}, ^transport},
                   1_000

    assert {:ok, %APDU.ConfirmedServiceRequest{invoke_id: 3}} = APDU.decode(raw)
    assert MstpTransport.get_state(transport) == :answer_data_request

    assert {:error, :destination_is_not_expecting_reply} =
             MstpTransport.reply_postponed(transport, 1)

    assert :ok = MstpTransport.reply_postponed(transport, 8)
    assert MstpTransport.get_state(transport) == :idle
    assert_receive {:circuits_uart, ^peer, reply}, 1_000
    assert :binary.at(reply, 2) == 7
  end

  test "configure changes the baudrate and rejects unsupported options" do
    %{transport: transport} = start_master!([])
    assert :ok = MstpTransport.configure(transport, baudrate: 9600, max_info_frames: 2)
    assert MstpTransport.get_baudrate(transport) == 9600

    assert_raise ArgumentError, ~r/does not support option/, fn ->
      MstpTransport.configure(transport, local_address: 2)
    end

    assert_raise ArgumentError, ~r/keyword list/, fn ->
      MstpTransport.configure(transport, [1])
    end
  end

  test "a queued send is transmitted after a token" do
    %{transport: transport, peer: peer} = start_master!(local_address: 3, max_master_address: 3)
    assert :ok = MstpTransport.send(transport, 255, <<16, 8>>, is_broadcast: true)
    write_frame!(peer, token_frame(3, 1))

    assert_receive {:circuits_uart, ^peer, frame}, 1_000
    assert :binary.at(frame, 2) == 6
    assert :binary.at(frame, 3) == 255
    assert :binary.at(frame, 4) == 3
  end

  test "a slave rejects token passing and unsolicited sends" do
    %{transport: transport, peer: peer} = start_slave!()
    assert {:error, :slave_mode} = MstpTransport.disable_token_passing(transport)
    assert {:error, :slave_mode} = MstpTransport.send(transport, 1, <<16, 8>>)
    assert {:error, :slave_mode} = MstpTransport.send_test(transport, 1, "ping")
    assert {:error, :slave_mode} = MstpTransport.reply_postponed(transport, 1)
    assert MstpTransport.get_local_address(transport) == 200

    write_frame!(peer, data_frame(6, 200, 4, @who_is))

    assert_receive {:bacnet_transport, {:bacnet_mstp, MstpTransport}, 4,
                    {:apdu, :original_unicast, _, <<16, 8>>}, ^transport},
                   1_000
  end

  test "autobaud starts on the first standard baudrate" do
    %{transport: transport} = start_master!(baudrate: :auto)
    assert {:auto, 9600} = MstpTransport.get_baudrate(transport)
    assert MstpTransport.get_state(transport) == :autobaud_detection

    send(transport, :autobaud_timer)
    assert {:auto, baud} = MstpTransport.get_baudrate(transport)
    assert baud in [9600, 19_200]
  end

  test "a bad header is discarded and the transport stays up" do
    %{transport: transport, peer: peer} = start_master!([])
    write_frame!(peer, <<0x55, 0xFF, 0, 5, 9, 0, 0, 0>>)
    Process.sleep(50)
    assert MstpTransport.get_state(transport) == :idle
    refute_received {:bacnet_transport, _, _, _, _}
  end

  test "a uart error shuts the transport down" do
    %{transport: transport} = start_master!([])
    Process.unlink(transport)
    ref = Process.monitor(transport)
    send(transport, {:serial_crash, :eio})
    assert_receive {:DOWN, ^ref, :process, ^transport, {:uart_error, :eio}}, 1_000
  end

  test "close stops the transport" do
    %{transport: transport} = start_master!([])
    ref = Process.monitor(transport)
    assert :ok = MstpTransport.close(transport)
    assert_receive {:DOWN, ^ref, :process, ^transport, :normal}
  end

  test "a poll for master is answered and a test request is echoed" do
    %{transport: transport, peer: peer} = start_master!(local_address: 6)
    write_frame!(peer, token_frame_type(1, 6, 2))
    assert_receive {:circuits_uart, ^peer, reply}, 1_000
    assert :binary.at(reply, 2) == 2
    assert :binary.at(reply, 3) == 2
    assert :binary.at(reply, 4) == 6

    write_frame!(peer, data_frame(3, 6, 2, "ping"))
    assert_receive {:circuits_uart, ^peer, response}, 1_000
    assert :binary.at(response, 2) == 4
    assert :binary.match(response, "ping") != :nomatch
    assert MstpTransport.get_state(transport) == :idle
  end

  test "a test exchange completes after the token arrives" do
    %{transport: transport, peer: peer} = start_master!(local_address: 6)
    parent = self()

    task =
      Task.async(fn ->
        send(parent, :calling)
        MstpTransport.send_test(transport, 2)
      end)

    assert_receive :calling
    write_frame!(peer, token_frame(6, 1))
    assert_receive {:circuits_uart, ^peer, request}, 1_000
    assert :binary.at(request, 2) == 3

    write_frame!(peer, data_frame(4, 6, 2, "Hello World"))
    assert {:ok, "Hello World"} = Task.await(task)
  end

  test "losing the token makes the master poll and then transmit" do
    %{transport: transport, peer: peer} =
      start_master!(local_address: 1, max_master_address: 2)

    assert :ok = MstpTransport.send(transport, 2, <<16, 8>>)
    send(transport, :timer_lost_token)
    assert MstpTransport.get_state(transport) == :no_token

    Process.sleep(40)
    assert MstpTransport.get_state(transport) == :poll_for_master

    send(transport, :timer_rcv_timeout)
    MstpTransport.get_state(transport)
    send(transport, :timer_rcv_timeout)

    assert MstpTransport.get_state(transport) in [
             :use_token,
             :done_with_token,
             :poll_for_master,
             :pass_token
           ]

    assert_receive {:circuits_uart, ^peer, _frame}, 1_000
    assert Process.alive?(transport)
  end

  test "a reply to poll for master becomes the successor" do
    %{transport: transport, peer: peer} =
      start_master!(local_address: 1, max_master_address: 2)

    send(transport, :timer_lost_token)
    Process.sleep(40)
    assert MstpTransport.get_state(transport) == :poll_for_master
    flush_uart(peer)
    write_frame!(peer, token_frame_type(2, 1, 2))
    assert_receive {:circuits_uart, ^peer, token}, 1_000
    assert :binary.at(token, 2) == 0
    assert MstpTransport.get_state(transport) == :pass_token
  end

  test "autobaud falls back to 38400 after every standard baudrate" do
    %{transport: transport} = start_master!(baudrate: :auto)

    for _step <- 1..6 do
      send(transport, :autobaud_timer)
      MstpTransport.get_baudrate(transport)
    end

    assert MstpTransport.get_baudrate(transport) == 38_400
    assert MstpTransport.get_state(transport) == :idle
  end

  test "proprietary, skipped, and extended frames are handled" do
    %{transport: transport, peer: peer} = start_master!(local_address: 5)

    write_frame!(peer, data_frame(128, 5, 9, <<0, 42, "hi">>))

    assert_receive {:bacnet_transport, {:bacnet_mstp, MstpTransport}, 9,
                    {:proprietary, {128, 42}, 5, "hi"}, ^transport},
                   1_000

    write_frame!(peer, data_frame(6, 9, 3, @who_is))
    refute_receive {:bacnet_transport, _, _, _, _}, 40

    write_frame!(peer, cobs_frame(33, 255, 9, @who_is))

    assert_receive {:bacnet_transport, _, 9, {:apdu, :original_broadcast, %NPCI{}, <<16, 8>>},
                    ^transport},
                   1_000

    bad = data_frame(6, 5, 9, @who_is)
    <<head::binary-size(8), _byte, tail::binary>> = bad
    write_frame!(peer, head <> <<0>> <> tail)
    refute_receive {:bacnet_transport, _, _, _, _}, 40
    assert MstpTransport.get_state(transport) == :idle
  end

  test "open and send reject the remaining bad options" do
    assert_raise ArgumentError, ~r/local_address/, fn ->
      MstpTransport.open(self())
    end

    assert_raise ArgumentError, ~r/port_name/, fn ->
      MstpTransport.open(self(), port_name: :pty, local_address: 1)
    end

    assert_raise ArgumentError, ~r/log_communication_rcv/, fn ->
      MstpTransport.open(self(), port_name: "pty", local_address: 1, log_communication_rcv: :yes)
    end

    assert_raise ArgumentError, ~r/supervisor/, fn ->
      MstpTransport.open(self(), port_name: "pty", local_address: 1, supervisor: "nope")
    end

    for supervisor <- [
          :mstp_sup,
          {:global, :mstp_sup},
          {:via, Agent, :mstp_sup},
          {:mstp_sup, node()}
        ] do
      assert {:error, :enoent} =
               isolated(fn ->
                 MstpTransport.open(self(),
                   port_name: "/dev/does-not-exist-mstp",
                   local_address: 1,
                   supervisor: supervisor
                 )
               end)
    end

    %{transport: transport} = start_master!([])

    assert_raise ArgumentError, ~r/allow_extended_apdu/, fn ->
      MstpTransport.send(transport, 1, <<16, 8>>, use_extended_apdu: true)
    end

    assert_raise ArgumentError, ~r/minimum/, fn ->
      MstpTransport.send(transport, 1, <<16, 8>>,
        allow_extended_apdu: true,
        use_extended_apdu: true
      )
    end

    assert {:error, :apdu_too_long} =
             MstpTransport.send(transport, 1, :binary.copy(<<1>>, 600))

    assert_raise ArgumentError, ~r/less than/, fn ->
      MstpTransport.send_test(transport, 1, :binary.copy(<<1>>, 502))
    end

    assert :ok = MstpTransport.send(transport, 4, <<16, 8>>)

    assert_raise ArgumentError, ~r/baudrate/, fn ->
      MstpTransport.configure(transport, baudrate: :fast)
    end

    assert_raise ArgumentError, ~r/max_info_frames/, fn ->
      MstpTransport.configure(transport, max_info_frames: 0)
    end

    assert_raise ArgumentError, ~r/max_master_address/, fn ->
      MstpTransport.configure(transport, max_master_address: 128)
    end

    assert_raise ArgumentError, ~r/log_communication to be/, fn ->
      MstpTransport.configure(transport, log_communication: :yes)
    end

    assert_raise ArgumentError, ~r/log_communication_rcv/, fn ->
      MstpTransport.configure(transport, log_communication_rcv: :yes)
    end

    assert_raise ArgumentError, ~r/keyword list/, fn ->
      MstpTransport.send(transport, 1, <<16, 8>>, [1])
    end
  end

  test "raw and extended frames leave the wire when the token arrives" do
    %{transport: transport, peer: peer} =
      start_master!(local_address: 4, max_info_frames: 3, log_communication: true)

    assert :ok = MstpTransport.send(transport, 7, <<9, 9, 9, 9>>, raw: true)

    extended = :binary.copy(<<16, 8>>, 3)

    assert :ok =
             MstpTransport.send(transport, 7, extended,
               allow_extended_apdu: true,
               use_extended_apdu: true
             )

    assert :ok = MstpTransport.send(transport, 7, <<16, 8>>, npci: nil)
    write_frame!(peer, token_frame(4, 1))

    assert_receive {:circuits_uart, ^peer, raw}, 1_000
    assert raw == <<9, 9, 9, 9>>
    assert_receive {:circuits_uart, ^peer, ext}, 1_000
    assert :binary.at(ext, 2) == 33
    assert_receive {:circuits_uart, ^peer, plain}, 1_000
    assert :binary.at(plain, 2) == 6
  end

  test "a confirmed send waits for a reply and then gives up" do
    %{transport: transport, peer: peer} = start_master!(local_address: 4)
    assert :ok = MstpTransport.send(transport, 8, ApduFactory.read_property())
    write_frame!(peer, token_frame(4, 1))
    request = await_uart(peer)
    assert :binary.at(request, 2) == 5
    assert MstpTransport.get_state(transport) == :wait_for_reply

    send(transport, :timer_rcv_timeout)
    poll = await_uart(peer)
    assert :binary.at(poll, 2) == 1
    assert MstpTransport.get_state(transport) == :poll_for_master

    write_frame!(peer, data_frame(6, 4, 9, @who_is))
    refute_receive {:bacnet_transport, _, _, _, _}, 40
    assert MstpTransport.get_state(transport) == :idle
  end

  test "a reply postponed frame ends the wait and polls for a successor" do
    %{transport: transport, peer: peer} = start_master!(local_address: 4)
    assert :ok = MstpTransport.send(transport, 8, ApduFactory.read_property())
    write_frame!(peer, token_frame(4, 1))
    request = await_uart(peer)
    assert :binary.at(request, 2) == 5
    assert MstpTransport.get_state(transport) == :wait_for_reply

    write_frame!(peer, token_frame_type(7, 4, 8))
    poll = await_uart(peer)
    assert :binary.at(poll, 2) == 1
    assert MstpTransport.get_state(transport) == :poll_for_master
  end

  test "a reply received while waiting is delivered before the token is passed" do
    %{transport: transport, peer: peer} = start_master!(local_address: 4)
    assert :ok = MstpTransport.send(transport, 8, ApduFactory.read_property())
    write_frame!(peer, token_frame(4, 1))
    request = await_uart(peer)
    assert :binary.at(request, 2) == 5
    assert MstpTransport.get_state(transport) == :wait_for_reply

    write_frame!(peer, data_frame(6, 4, 8, <<0x01, 0x00, 16, 8>>))

    assert_receive {:bacnet_transport, {:bacnet_mstp, MstpTransport}, 8,
                    {:apdu, :original_unicast, _, <<16, 8>>}, ^transport},
                   1_000

    assert MstpTransport.get_state(transport) == :wait_for_reply

    send(transport, :timer_rcv_timeout)
    poll = await_uart(peer)
    assert :binary.at(poll, 2) == 1
    assert MstpTransport.get_state(transport) == :poll_for_master
  end

  test "an unexpected frame while waiting returns the master to idle" do
    %{transport: transport, peer: peer} = start_master!(local_address: 4)
    assert :ok = MstpTransport.send(transport, 8, ApduFactory.read_property())
    write_frame!(peer, token_frame(4, 1))
    request = await_uart(peer)
    assert :binary.at(request, 2) == 5

    write_frame!(peer, token_frame(4, 9))
    refute_receive {:circuits_uart, ^peer, _frame}, 40
    assert MstpTransport.get_state(transport) == :idle
  end

  test "answering a request transmits the simple ack" do
    %{transport: transport, peer: peer} = start_master!(local_address: 4)

    assert {:error, :destination_is_not_expecting_reply} =
             MstpTransport.reply_postponed(transport, 8)

    request = confirmed_npdu()
    {:ok, invoke_id} = APDU.get_invoke_id_from_raw_apdu(request)
    write_frame!(peer, data_frame(5, 4, 8, request))

    assert_receive {:bacnet_transport, {:bacnet_mstp, MstpTransport}, 8,
                    {:apdu, :original_unicast, %NPCI{expects_reply: true}, _raw}, ^transport},
                   1_000

    assert MstpTransport.get_state(transport) == :answer_data_request

    write_frame!(peer, data_frame(6, 4, 8, <<0x01, 0x00, 16, 8>>))
    refute_receive {:bacnet_transport, _, _, _, _}, 40
    assert MstpTransport.get_state(transport) == :answer_data_request

    assert :ok = MstpTransport.send(transport, 8, ApduFactory.simple_ack(invoke_id))
    ack = await_uart(peer)
    assert :binary.at(ack, 2) == 6
    assert :binary.at(ack, 3) == 8
    assert MstpTransport.get_state(transport) == :idle
    assert {:error, :no_reply_pending} = MstpTransport.reply_postponed(transport, 8)
  end

  test "a slave cannot send a deferred reply" do
    %{transport: transport} = start_slave!()
    assert {:error, :app_timeout} = MstpTransport.send(transport, 1, ApduFactory.simple_ack(1))
  end

  test "the token is passed to a discovered successor and retried" do
    %{transport: transport, peer: peer} =
      start_master!(local_address: 1, max_master_address: 4)

    write_frame!(peer, token_frame(1, 3))
    poll = await_uart(peer)
    assert :binary.at(poll, 2) == 1
    assert :binary.at(poll, 3) == 2
    assert MstpTransport.get_state(transport) == :poll_for_master

    write_frame!(peer, token_frame_type(2, 1, 2))
    token = await_uart(peer)
    assert :binary.at(token, 2) == 0
    assert :binary.at(token, 3) == 2
    assert MstpTransport.get_state(transport) == :pass_token

    # Bytes on the wire while the token is offered return the master to idle
    # and keep the successor. The next token is then offered again
    write_frame!(peer, token_frame(1, 3))
    token = await_uart(peer)
    assert :binary.at(token, 2) == 0
    assert :binary.at(token, 3) == 2
    assert MstpTransport.get_state(transport) == :pass_token

    send(transport, :timer_rcv_timeout)
    send(transport, {:timer_retry_token_handoff, 2})
    retried = await_uart(peer)
    assert :binary.at(retried, 2) == 0
    assert :binary.at(retried, 3) == 2
    assert MstpTransport.get_state(transport) == :pass_token

    send(transport, :timer_rcv_timeout)
    poll = await_uart(peer)
    assert :binary.at(poll, 2) == 1
    assert :binary.at(poll, 3) == 3
    assert MstpTransport.get_state(transport) == :poll_for_master
  end

  test "configure can enter autobaud and a poll is still answered" do
    %{transport: transport, peer: peer} = start_master!([])
    assert :ok = MstpTransport.configure(transport, baudrate: :auto)
    assert {:auto, 9600} = MstpTransport.get_baudrate(transport)
    assert MstpTransport.get_state(transport) == :autobaud_detection

    write_frame!(peer, token_frame_type(1, 5, 2))
    assert_receive {:circuits_uart, ^peer, reply}, 1_000
    assert :binary.at(reply, 2) == 2
    assert is_integer(MstpTransport.get_baudrate(transport))
  end

  test "a function callback and a dead name both receive or ignore a frame" do
    parent = self()

    %{transport: transport, peer: peer} =
      start_master!(
        local_address: 5,
        callback: fn source, data, portal -> send(parent, {:cb, source, data, portal}) end
      )

    write_frame!(peer, data_frame(6, 255, 9, @who_is))
    assert_receive {:cb, 9, {:apdu, :original_broadcast, _, <<16, 8>>}, ^transport}, 1_000

    %{peer: dead_peer} = start_master!(local_address: 5, callback: :mstp_missing_callback)
    write_frame!(dead_peer, data_frame(6, 255, 9, @who_is))
    refute_receive {:bacnet_transport, _, _, _, _}, 50

    {:ok, sup} = Task.Supervisor.start_link()

    %{transport: task_transport, peer: task_peer} =
      start_master!(
        local_address: 5,
        supervisor: sup,
        callback: fn source, data, portal -> send(parent, {:task, source, data, portal}) end
      )

    write_frame!(task_peer, data_frame(6, 5, 9, @who_is))
    assert_receive {:task, 9, {:apdu, :original_unicast, _, <<16, 8>>}, ^task_transport}, 1_000
  end

  test "an undecodable payload is discarded" do
    %{transport: transport, peer: peer} = start_master!(local_address: 5)
    write_frame!(peer, data_frame(6, 5, 9, <<0xFF, 0x00>>))
    write_frame!(peer, data_frame(6, 5, 9, <<0x01, 0x20, 0, 1, 0, 0, 16, 8>>))
    refute_receive {:bacnet_transport, _, _, _, _}, 50
    assert MstpTransport.get_state(transport) == :idle
    send(transport, :wakeup_use_token)
    assert MstpTransport.get_state(transport) == :poll_for_master
  end

  test "binary and iodata payloads leave in queue order" do
    %{transport: transport, peer: peer} =
      start_master!(local_address: 4, max_info_frames: 3)

    confirmed = IO.iodata_to_binary(EncoderProtocol.encode(ApduFactory.read_property()))
    unconfirmed = IO.iodata_to_binary(EncoderProtocol.encode(ApduFactory.who_is()))

    assert :ok = MstpTransport.send(transport, 9, [[], [16, 0, 16, 8]])
    assert :ok = MstpTransport.send(transport, 255, unconfirmed, is_broadcast: true)
    assert :ok = MstpTransport.send(transport, 8, confirmed)
    write_frame!(peer, token_frame(4, 1))

    first = await_uart(peer)
    assert :binary.at(first, 2) == 6
    assert :binary.at(first, 3) == 9
    second = await_uart(peer)
    assert :binary.at(second, 2) == 6
    assert :binary.at(second, 3) == 255
    third = await_uart(peer)
    assert :binary.at(third, 2) == 5
    assert :binary.at(third, 3) == 8
    assert MstpTransport.get_state(transport) == :wait_for_reply

    assert :ok =
             MstpTransport.send(transport, 8, ApduFactory.read_property(),
               allow_extended_apdu: true,
               use_extended_apdu: true
             )

    send(transport, :timer_rcv_timeout)
    poll = await_uart(peer)
    assert :binary.at(poll, 2) == 1
    assert MstpTransport.get_state(transport) == :poll_for_master

    write_frame!(peer, token_frame(4, 1))
    refute_receive {:circuits_uart, ^peer, _dropped}, 20
    assert MstpTransport.get_state(transport) == :idle

    write_frame!(peer, token_frame(4, 1))
    extended = await_uart(peer)
    assert :binary.at(extended, 2) == 32
    assert :binary.at(extended, 3) == 8
    assert MstpTransport.get_state(transport) == :wait_for_reply
  end

  test "an empty payload and a forced reply bit share one token" do
    %{transport: transport, peer: peer} =
      start_master!(local_address: 4, max_info_frames: 4)

    assert :ok = MstpTransport.send(transport, 7, [])

    raw_unknown = [8, 7, 4, 0, 0]
    raw_unknown = raw_unknown ++ [0xFF - EncodingTools.calculate_header_crc(raw_unknown, 0xFF)]

    raw_proprietary = [128, 7, 4, 0, 0]

    raw_proprietary =
      raw_proprietary ++ [0xFF - EncodingTools.calculate_header_crc(raw_proprietary, 0xFF)]

    assert :ok = MstpTransport.send(transport, 7, [0x55, 0xFF, raw_unknown], raw: true)
    assert :ok = MstpTransport.send(transport, 7, [0x55, 0xFF, raw_proprietary], raw: true)

    assert :ok =
             MstpTransport.send(transport, 8, <<16, 8>>, npci: NPCI.new(expects_reply: true))

    write_frame!(peer, token_frame(4, 1))
    empty = await_uart(peer)
    assert :binary.at(empty, 2) == 6
    unknown = await_uart(peer)
    assert :binary.at(unknown, 2) == 8
    proprietary = await_uart(peer)
    assert :binary.at(proprietary, 2) == 128
    forced = await_uart(peer)
    assert :binary.at(forced, 2) == 5
    assert MstpTransport.get_state(transport) == :wait_for_reply
  end

  test "a segmented complex ack binary expects a reply" do
    %{transport: transport, peer: peer} = start_master!(local_address: 4)
    assert :ok = MstpTransport.send(transport, 8, <<0x34, 1, 0>>)
    write_frame!(peer, token_frame(4, 1))
    frame = await_uart(peer)
    assert :binary.at(frame, 2) == 5
    assert MstpTransport.get_state(transport) == :wait_for_reply
  end

  test "a test request reports timeout, conflict, and an invalid response" do
    %{transport: transport, peer: peer} = start_master!(local_address: 6)
    parent = self()

    timeout_task =
      Task.async(fn ->
        send(parent, :calling_timeout)
        MstpTransport.send_test(transport, 2, "ping")
      end)

    assert_receive :calling_timeout
    write_frame!(peer, token_frame(6, 1))
    request = await_uart(peer)
    assert :binary.at(request, 2) == 3
    send(transport, :timer_rcv_timeout)
    assert {:error, :apdu_timeout} = Task.await(timeout_task)
    poll = await_uart(peer)
    assert :binary.at(poll, 2) == 1
    assert MstpTransport.get_state(transport) == :poll_for_master
  end

  test "a test request reports a line conflict and an invalid response" do
    %{transport: transport, peer: peer} = start_master!(local_address: 6)
    parent = self()

    conflict_task =
      Task.async(fn ->
        send(parent, :calling_conflict)
        MstpTransport.send_test(transport, 2, "ping")
      end)

    assert_receive :calling_conflict
    write_frame!(peer, token_frame(6, 1))
    request = await_uart(peer)
    assert :binary.at(request, 2) == 3
    write_frame!(peer, token_frame(6, 9))
    assert {:error, :transport_line_access_conflict} = Task.await(conflict_task)
    assert MstpTransport.get_state(transport) == :idle

    invalid_task =
      Task.async(fn ->
        send(parent, :calling_invalid)
        MstpTransport.send_test(transport, 2, "ping")
      end)

    assert_receive :calling_invalid
    write_frame!(peer, token_frame(6, 1))
    request = await_uart(peer)
    assert :binary.at(request, 2) == 3
    write_frame!(peer, bad_header(6, 9))
    assert {:error, :invalid_frame_response} = Task.await(invalid_task)
    poll = await_uart(peer)
    assert :binary.at(poll, 2) == 1
    assert MstpTransport.get_state(transport) == :poll_for_master
  end

  test "maintenance polling reaches the known successor and can be skipped" do
    %{transport: transport, peer: peer} =
      start_master!(local_address: 1, max_master_address: 5)

    write_frame!(peer, token_frame(1, 4))
    poll = await_uart(peer)
    assert :binary.at(poll, 2) == 1
    assert :binary.at(poll, 3) == 2

    send(transport, :timer_rcv_timeout)
    poll = await_uart(peer)
    assert :binary.at(poll, 3) == 3

    write_frame!(peer, token_frame_type(2, 1, 3))
    token = await_uart(peer)
    assert :binary.at(token, 2) == 0
    assert :binary.at(token, 3) == 3
    assert MstpTransport.get_state(transport) == :pass_token

    write_frame!(peer, token_frame(1, 4))
    poll = await_uart(peer)
    assert :binary.at(poll, 2) == 1
    assert :binary.at(poll, 3) == 2
    assert MstpTransport.get_state(transport) == :poll_for_master

    send(transport, :timer_rcv_timeout)
    token = await_uart(peer)
    assert :binary.at(token, 2) == 0
    assert :binary.at(token, 3) == 3
    assert MstpTransport.get_state(transport) == :pass_token

    assert :ok = MstpTransport.set_maintenance_pfm(transport, false)
    write_frame!(peer, token_frame(1, 4))
    skipped = await_uart(peer)
    assert :binary.at(skipped, 2) == 0
    assert :binary.at(skipped, 3) == 3
    assert MstpTransport.get_state(transport) == :pass_token
  end

  test "a successor just below this station is replaced after one timeout" do
    %{transport: transport, peer: peer} =
      start_master!(local_address: 1, max_master_address: 3)

    write_frame!(peer, token_frame(1, 2))
    poll = await_uart(peer)
    assert :binary.at(poll, 3) == 2

    send(transport, :timer_rcv_timeout)
    poll = await_uart(peer)
    assert :binary.at(poll, 3) == 3

    send(transport, :timer_rcv_timeout)
    poll = await_uart(peer)
    assert :binary.at(poll, 3) == 0

    write_frame!(peer, token_frame_type(2, 1, 0))
    token = await_uart(peer)
    assert :binary.at(token, 2) == 0
    assert :binary.at(token, 3) == 0

    send(transport, :timer_rcv_timeout)
    poll = await_uart(peer)
    assert :binary.at(poll, 2) == 1
    assert :binary.at(poll, 3) == 2
    assert MstpTransport.get_state(transport) == :poll_for_master
  end

  test "an invalid frame while this station is the sole master keeps the token" do
    %{transport: transport, peer: peer} =
      start_master!(local_address: 1, max_master_address: 2)

    write_frame!(peer, token_frame(1, 2))
    poll = await_uart(peer)
    assert :binary.at(poll, 3) == 2

    send(transport, :timer_rcv_timeout)
    poll = await_uart(peer)
    assert :binary.at(poll, 3) == 0

    send(transport, :timer_rcv_timeout)
    poll = await_uart(peer)
    assert :binary.at(poll, 3) == 2
    assert MstpTransport.get_state(transport) == :poll_for_master

    write_frame!(peer, bad_header(1, 9))
    poll = await_uart(peer)
    assert :binary.at(poll, 2) == 1
    assert :binary.at(poll, 3) == 0
    assert MstpTransport.get_state(transport) == :poll_for_master
  end

  test "disabling token passing drops generation and a later handoff retry" do
    %{transport: transport, peer: peer} = start_master!(local_address: 5)

    assert :ok = MstpTransport.disable_token_passing(transport)
    send(transport, :timer_rcv_timeout)
    assert MstpTransport.get_state(transport) == :no_token
    send(transport, :timer_lost_token)
    assert MstpTransport.get_state(transport) == :no_token

    send(transport, {:timer_generate_token, System.monotonic_time(:millisecond)})
    assert MstpTransport.get_state(transport) == :no_token
    refute_receive {:circuits_uart, ^peer, _frame}, 80

    %{transport: passing, peer: passing_peer} =
      start_master!(local_address: 1, max_master_address: 2)

    write_frame!(passing_peer, token_frame(1, 2))
    poll = await_uart(passing_peer)
    assert :binary.at(poll, 3) == 2
    write_frame!(passing_peer, token_frame_type(2, 1, 2))
    assert await_state(passing, :pass_token) == :pass_token
    send(passing, {:timer_retry_token_handoff, 2})

    handoff = await_uart(passing_peer)
    retried = await_uart(passing_peer)

    assert :binary.at(handoff, 2) == 0
    assert :binary.at(handoff, 3) == 2
    assert :binary.at(retried, 2) == 0
    assert :binary.at(retried, 3) == 2
    assert MstpTransport.get_state(passing) == :pass_token

    assert :ok = MstpTransport.disable_token_passing(passing)
    send(passing, {:timer_retry_token_handoff, 2})
    assert MstpTransport.get_state(passing) == :no_token
    refute_receive {:circuits_uart, ^passing_peer, _frame}, 20
  end

  test "the answer timer postpones a master and expires quietly on a slave" do
    %{transport: transport, peer: peer} = start_master!(local_address: 4)
    write_frame!(peer, data_frame(5, 4, 8, confirmed_npdu()))

    assert_receive {:bacnet_transport, _, 8, {:apdu, :original_unicast, _, _raw}, ^transport},
                   1_000

    assert MstpTransport.get_state(transport) == :answer_data_request
    send(transport, :timer_answer_timeout)
    send(transport, :timer_answer_timeout)
    postponed = await_uart(peer)
    assert :binary.at(postponed, 2) == 7
    assert :binary.at(postponed, 3) == 8
    assert MstpTransport.get_state(transport) == :idle

    %{transport: slave, peer: slave_peer} = start_slave!()
    write_frame!(slave_peer, data_frame(5, 200, 8, confirmed_npdu()))

    assert_receive {:bacnet_transport, _, 8, {:apdu, :original_unicast, _, _raw}, ^slave}, 1_000

    assert MstpTransport.get_state(slave) == :answer_data_request
    send(slave, :timer_answer_timeout)
    assert MstpTransport.get_state(slave) == :idle
    refute_receive {:circuits_uart, ^slave_peer, _frame}, 40
  end

  test "a slave ignores a token and a poll for master" do
    %{transport: transport, peer: peer} = start_slave!()
    write_frame!(peer, token_frame(200, 1))
    write_frame!(peer, token_frame_type(1, 200, 1))
    write_frame!(peer, data_frame(6, 200, 4, @who_is))

    assert_receive {:bacnet_transport, _, 4, {:apdu, :original_unicast, _, <<16, 8>>},
                    ^transport},
                   1_000

    refute_receive {:circuits_uart, ^peer, _frame}, 40
    assert MstpTransport.get_state(transport) == :idle
  end

  test "token passing stays disabled when a token or a poll arrives" do
    %{transport: transport, peer: peer} = start_master!(local_address: 5)
    assert :ok = MstpTransport.disable_token_passing(transport)
    write_frame!(peer, token_frame(5, 3))
    write_frame!(peer, token_frame_type(1, 5, 3))
    write_frame!(peer, data_frame(6, 255, 9, @who_is))

    assert_receive {:bacnet_transport, _, 9, {:apdu, :original_broadcast, _, <<16, 8>>},
                    ^transport},
                   1_000

    refute_receive {:circuits_uart, ^peer, _frame}, 40
    assert MstpTransport.get_state(transport) == :idle
  end

  test "a test response with nobody waiting still passes the token onward" do
    %{transport: transport, peer: peer} = start_master!(local_address: 5)
    write_frame!(peer, data_frame(4, 5, 2, "pong"))
    poll = await_uart(peer)
    assert :binary.at(poll, 2) == 1
    assert MstpTransport.get_state(transport) == :poll_for_master
  end

  test "broadcast, unknown, and short proprietary frames are classified" do
    %{transport: transport, peer: peer} = start_master!(local_address: 5)
    write_frame!(peer, data_frame(128, 5, 9, <<42>>))

    assert_receive {:bacnet_transport, _, 9, {:proprietary, {128, 0}, 5, <<42>>}, ^transport},
                   1_000

    write_frame!(peer, token_frame(255, 3))
    write_frame!(peer, data_frame(8, 5, 9, @who_is))
    write_frame!(peer, data_frame(5, 255, 9, confirmed_npdu()))
    write_frame!(peer, data_frame(6, 255, 9, @who_is))

    assert_receive {:bacnet_transport, _, 9, {:apdu, :original_broadcast, _, <<16, 8>>},
                    ^transport},
                   1_000

    refute_receive {:bacnet_transport, _, _, _, _}, 40
    refute_receive {:circuits_uart, ^peer, _frame}, 20
    assert MstpTransport.get_state(transport) == :idle
  end

  test "an extended confirmed request is postponed when the answer timer fires" do
    %{transport: transport, peer: peer} = start_master!(local_address: 4)
    write_frame!(peer, cobs_frame(32, 4, 8, confirmed_npdu()))

    assert_receive {:bacnet_transport, _, 8,
                    {:apdu, :original_unicast, %NPCI{expects_reply: true}, raw}, ^transport},
                   1_000

    assert {:ok, %APDU.ConfirmedServiceRequest{invoke_id: 3}} = APDU.decode(raw)
    assert MstpTransport.get_state(transport) == :answer_data_request
    send(transport, :timer_answer_timeout)
    postponed = await_uart(peer)
    assert :binary.at(postponed, 2) == 7
    assert :binary.at(postponed, 3) == 8
    assert MstpTransport.get_state(transport) == :idle
  end

  test "skipping maintenance passes the token straight to the successor" do
    %{transport: transport, peer: peer} =
      start_master!(local_address: 1, max_master_address: 5)

    write_frame!(peer, token_frame(1, 4))
    poll = await_uart(peer)
    assert :binary.at(poll, 3) == 2
    send(transport, :timer_rcv_timeout)
    poll = await_uart(peer)
    assert :binary.at(poll, 3) == 3

    write_frame!(peer, token_frame_type(2, 1, 3))
    assert await_state(transport, :pass_token) == :pass_token
    assert :ok = MstpTransport.set_maintenance_pfm(transport, false)
    write_frame!(peer, token_frame(1, 4))

    handoff = await_uart(peer)
    passed = await_uart(peer)
    assert :binary.at(handoff, 2) == 0
    assert :binary.at(handoff, 3) == 3
    assert :binary.at(passed, 2) == 0
    assert :binary.at(passed, 3) == 3
    assert MstpTransport.get_state(transport) == :pass_token
  end

  test "a disabled master drops the token when the successor is not adjacent" do
    %{transport: transport, peer: peer} =
      start_master!(local_address: 1, max_master_address: 5)

    write_frame!(peer, token_frame(1, 4))
    poll = await_uart(peer)
    assert :binary.at(poll, 3) == 2
    send(transport, :timer_rcv_timeout)
    poll = await_uart(peer)
    assert :binary.at(poll, 3) == 3
    write_frame!(peer, token_frame_type(2, 1, 3))
    assert await_state(transport, :pass_token) == :pass_token
    handoff = await_uart(peer)
    assert :binary.at(handoff, 2) == 0
    assert :binary.at(handoff, 3) == 3

    write_frame!(peer, data_frame(6, 1, 9, @who_is))

    assert_receive {:bacnet_transport, _, 9, {:apdu, :original_unicast, _, <<16, 8>>},
                    ^transport},
                   1_000

    assert MstpTransport.get_state(transport) == :idle
    assert :ok = MstpTransport.disable_token_passing(transport)
    send(transport, :wakeup_use_token)
    refute_receive {:circuits_uart, ^peer, _frame}, 20
    assert MstpTransport.get_state(transport) == :no_token
  end

  test "an invalid frame moves an unknown-successor poll to the next station" do
    %{transport: transport, peer: peer} =
      start_master!(local_address: 1, max_master_address: 4)

    write_frame!(peer, token_frame(1, 3))
    poll = await_uart(peer)
    assert :binary.at(poll, 3) == 2
    write_frame!(peer, bad_header(1, 9))
    poll = await_uart(peer)
    assert :binary.at(poll, 2) == 1
    assert :binary.at(poll, 3) == 3
    assert MstpTransport.get_state(transport) == :poll_for_master
  end

  test "an invalid frame during maintenance passes the token to the successor" do
    %{transport: transport, peer: peer} =
      start_master!(local_address: 1, max_master_address: 5)

    write_frame!(peer, token_frame(1, 4))
    _poll = await_uart(peer)
    send(transport, :timer_rcv_timeout)
    _poll = await_uart(peer)
    write_frame!(peer, token_frame_type(2, 1, 3))
    _token = await_uart(peer)
    write_frame!(peer, token_frame(1, 4))
    poll = await_uart(peer)
    assert :binary.at(poll, 2) == 1
    assert :binary.at(poll, 3) == 2

    write_frame!(peer, bad_header(1, 9))
    token = await_uart(peer)
    assert :binary.at(token, 2) == 0
    assert :binary.at(token, 3) == 3
    assert MstpTransport.get_state(transport) == :pass_token
  end

  test "a data expecting reply without an invoke id stays idle" do
    %{transport: transport, peer: peer} = start_master!(local_address: 5)
    write_frame!(peer, data_frame(5, 5, 9, @who_is))

    assert_receive {:bacnet_transport, _, 9, {:apdu, :original_unicast, _, <<16, 8>>},
                    ^transport},
                   1_000

    assert MstpTransport.get_state(transport) == :answer_data_request
    assert :ok = MstpTransport.send(transport, 9, ApduFactory.simple_ack(16))
    ack = await_uart(peer)
    assert :binary.at(ack, 2) == 6
    assert :binary.at(ack, 3) == 9
    assert MstpTransport.get_state(transport) == :idle
  end

  test "a network-layer message is discarded" do
    %{transport: transport, peer: peer} = start_master!(local_address: 5)
    npci = IO.iodata_to_binary(NPCI.encode(NPCI.new(is_network_message: true)))
    write_frame!(peer, data_frame(6, 5, 9, npci <> <<0, 0, 1>>))
    write_frame!(peer, data_frame(6, 255, 4, @who_is))

    assert_receive {:bacnet_transport, _, 4, {:apdu, :original_broadcast, _, <<16, 8>>},
                    ^transport},
                   1_000

    refute_receive {:bacnet_transport, _, _, _, _}, 20
    assert MstpTransport.get_state(transport) == :idle
  end

  test "a duplicate lost-token notice still generates one token" do
    %{transport: transport, peer: peer} =
      start_master!(local_address: 1, max_master_address: 2)

    send(transport, :timer_lost_token)
    send(transport, {:timer_generate_token, System.monotonic_time(:millisecond)})
    assert await_state(transport, :no_token) == :no_token
    poll = await_uart(peer)
    assert :binary.at(poll, 2) == 1
    assert MstpTransport.get_state(transport) == :poll_for_master
  end

  test "an idle receive timeout leaves the master idle" do
    %{transport: transport} = start_master!(local_address: 5)
    send(transport, :timer_rcv_timeout)
    assert MstpTransport.get_state(transport) == :idle
  end

  test "a proprietary frame is ignored while token passing is disabled" do
    %{transport: transport, peer: peer} = start_master!(local_address: 5)
    assert :ok = MstpTransport.disable_token_passing(transport)
    write_frame!(peer, data_frame(128, 5, 9, <<0, 42, "hi">>))
    write_frame!(peer, data_frame(6, 255, 4, @who_is))

    assert_receive {:bacnet_transport, _, 4, {:apdu, :original_broadcast, _, <<16, 8>>},
                    ^transport},
                   1_000

    refute_receive {:bacnet_transport, _, _, {:proprietary, _, _, _}, _}, 20
    assert MstpTransport.get_state(transport) == :idle
  end

  test "a sole master poll timeout keeps the token" do
    %{transport: transport, peer: peer} =
      start_master!(local_address: 1, max_master_address: 2)

    write_frame!(peer, token_frame(1, 2))
    poll = await_uart(peer)
    assert :binary.at(poll, 3) == 2
    send(transport, :timer_rcv_timeout)
    poll = await_uart(peer)
    assert :binary.at(poll, 3) == 0
    send(transport, :timer_rcv_timeout)
    poll = await_uart(peer)
    assert :binary.at(poll, 3) == 2

    send(transport, :timer_rcv_timeout)
    poll = await_uart(peer)
    assert :binary.at(poll, 2) == 1
    assert :binary.at(poll, 3) == 0
    assert MstpTransport.get_state(transport) == :poll_for_master
  end

  test "a slave ignores a lost-token notice" do
    %{transport: transport, peer: peer} = start_slave!()
    send(transport, :timer_lost_token)
    assert MstpTransport.get_state(transport) == :idle
    write_frame!(peer, data_frame(6, 200, 4, @who_is))

    assert_receive {:bacnet_transport, _, 4, {:apdu, :original_unicast, _, <<16, 8>>},
                    ^transport},
                   1_000
  end

  test "an mfa callback receives the frame" do
    Process.register(self(), :mstp_cb_parent)

    on_exit(fn ->
      if Process.whereis(:mstp_cb_parent) == self() do
        Process.unregister(:mstp_cb_parent)
      end
    end)

    %{transport: transport, peer: peer} =
      start_master!(local_address: 5, callback: {__MODULE__, :mstp_test_callback, 3})

    write_frame!(peer, data_frame(6, 255, 9, @who_is))

    assert_receive {:mfa, 9, {:apdu, :original_broadcast, _, <<16, 8>>}, ^transport}, 1_000
  end

  test "invalid headers walk autobaud and a fixed baudrate leaves it" do
    %{transport: transport, peer: peer} = start_master!(baudrate: :auto)
    assert {:auto, 9600} = MstpTransport.get_baudrate(transport)

    for baud <- [19_200, 38_400, 57_600, 76_800, 115_200] do
      write_frame!(peer, bad_header(5, 9))
      assert {:auto, ^baud} = await_baud(transport, {:auto, baud})
    end

    write_frame!(peer, bad_header(5, 9))
    assert 38_400 = await_baud(transport, 38_400)
    assert MstpTransport.get_state(transport) == :idle

    %{transport: again} = start_master!(baudrate: :auto)
    assert :ok = MstpTransport.configure(again, baudrate: 19_200, log_communication: true)
    assert MstpTransport.get_baudrate(again) == 19_200
    assert MstpTransport.get_state(again) == :idle
  end

  def mstp_test_callback(source, data, portal) do
    send(:mstp_cb_parent, {:mfa, source, data, portal})
  end

  test "unknown messages leave the transport running" do
    %{transport: transport} = start_master!([])
    send(transport, :unused)
    GenServer.cast(transport, :unused)

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
    assert MstpTransport.get_state(transport) == :idle
  end

  defp start_master!(opts) do
    {callback, opts} = Keyword.pop(opts, :callback, self())
    {mine, peer_path, socat_pid} = pty_pair()
    {:ok, peer} = UART.start_link()
    :ok = UART.open(peer, peer_path, uart_opts())

    {:ok, transport} =
      MstpTransport.open(
        callback,
        [
          port_name: mine,
          local_address: 5,
          max_master_address: 8,
          baudrate: 38_400,
          log_communication: true
        ] ++ opts
      )

    on_exit(fn ->
      if Process.alive?(transport) do
        try do
          MstpTransport.close(transport)
        catch
          :exit, _reason -> :ok
        end
      end

      if Process.alive?(peer) do
        try do
          UART.stop(peer)
        catch
          :exit, _reason -> :ok
        end
      end

      stop_socat(socat_pid)
    end)

    %{transport: transport, peer: peer}
  end

  defp start_slave!() do
    start_master!(local_address: 200)
  end

  defp pty_pair() do
    socat =
      Port.open({:spawn, "socat -d -d pty,rawer,echo=0 pty,rawer,echo=0"}, [
        :binary,
        :stderr_to_stdout,
        :exit_status
      ])

    os_pid = Keyword.fetch!(Port.info(socat), :os_pid)
    paths = await_ptys(socat, [], "")
    [first, second] = Enum.take(paths, 2)
    drain_port(socat)
    Process.sleep(50)
    drain_port(socat)
    {first, second, os_pid}
  end

  defp await_ptys(socat, found, output) do
    if length(found) >= 2 do
      Enum.reverse(found)
    else
      receive do
        {^socat, {:data, data}} ->
          more =
            Enum.map(Regex.scan(~r/PTY is (\S+)/, data), fn [_all, path] -> path end)

          await_ptys(socat, more ++ found, output <> data)

        {^socat, {:exit_status, status}} ->
          raise "socat exited with status #{status} before two PTYs: #{output}"
      after
        1_000 ->
          raise "socat did not report two PTYs, got #{inspect(found)}: #{output}"
      end
    end
  end

  defp stop_socat(os_pid) when is_integer(os_pid) do
    System.cmd("kill", ["-TERM", Integer.to_string(os_pid)], stderr_to_stdout: true)
  end

  defp uart_opts() do
    [
      active: true,
      speed: 38_400,
      data_bits: 8,
      stop_bits: 1,
      parity: :none,
      flow_control: :none,
      framing: {UART.Framing.None, []},
      id: :pid
    ]
  end

  defp drain_port(port) do
    receive do
      {^port, _msg} -> drain_port(port)
    after
      0 -> :ok
    end
  end

  defp flush_uart(peer) do
    receive do
      {:circuits_uart, ^peer, _data} -> flush_uart(peer)
    after
      20 -> :ok
    end
  end

  defp write_frame!(peer, frame) do
    assert :ok = UART.write(peer, frame)
  end

  defp await_uart(peer) do
    assert_receive {:circuits_uart, ^peer, frame}, 1_000
    frame
  end

  defp await_state(transport, expected, attempts \\ 15) do
    state = MstpTransport.get_state(transport)

    cond do
      state == expected ->
        state

      attempts <= 1 ->
        state

      true ->
        Process.sleep(2)
        await_state(transport, expected, attempts - 1)
    end
  end

  defp await_baud(transport, expected, attempts \\ 25) do
    baud = MstpTransport.get_baudrate(transport)

    cond do
      baud == expected ->
        baud

      attempts <= 1 ->
        flunk("expected baud #{inspect(expected)}, got #{inspect(baud)}")

      true ->
        Process.sleep(10)
        await_baud(transport, expected, attempts - 1)
    end
  end

  defp bad_header(dest, src), do: <<0x55, 0xFF, 0, dest, src, 0, 0, 0>>

  defp token_frame(dest, src), do: token_frame_type(0, dest, src)

  defp token_frame_type(type, dest, src) do
    header = <<type, dest, src, 0, 0>>
    crc = 0xFF - EncodingTools.calculate_header_crc(header, 0xFF)
    <<0x55, 0xFF, header::binary, crc>>
  end

  defp cobs_frame(type, dest, src, data) do
    {:ok, cobs} = EncodingTools.encode_cobs(data)
    cobs = IO.iodata_to_binary(cobs)
    header = <<type, dest, src, byte_size(cobs) - 2::16>>
    header_crc = 0xFF - EncodingTools.calculate_header_crc(header, 0xFF)
    <<0x55, 0xFF, header::binary, header_crc, cobs::binary>>
  end

  defp data_frame(type, dest, src, data) do
    header = <<type, dest, src, byte_size(data)::16>>
    header_crc = 0xFF - EncodingTools.calculate_header_crc(header, 0xFF)
    data_crc = 0xFFFF - EncodingTools.calculate_data_crc(data, 0xFFFF)
    <<0x55, 0xFF, header::binary, header_crc, data::binary, data_crc::little-16>>
  end

  defp confirmed_npdu() do
    apdu = ApduFactory.read_property(invoke_id: 3)
    npci = IO.iodata_to_binary(NPCI.encode(NPCI.new(expects_reply: true)))
    npci <> IO.iodata_to_binary(EncoderProtocol.encode(apdu))
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
