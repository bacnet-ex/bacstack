defmodule BACnet.Stack.Transport.MstpTransport.ReceiveFSMTest do
  alias BACnet.Protocol.NPCI
  alias BACnet.Stack.Transport.MstpTransport
  alias BACnet.Stack.Transport.MstpTransport.EncodingTools
  alias BACnet.Stack.Transport.MstpTransport.ReceiveFSM
  alias Circuits.UART

  use BACnet.Test.Stack.Case, async: false

  @moduletag :stack
  @moduletag :transport
  @moduletag :mstp_transport

  @who_is <<0x01, 0x00, 16, 8>>

  test "the receive fsm accepts the remaining frame shapes and uart errors" do
    %{transport: transport, peer: peer} =
      start_master!(local_address: 5, log_communication_rcv: true)

    assert :ok = MstpTransport.disable_token_passing(transport)
    fsm = fsm_pid(transport)

    send(fsm, {:circuits_uart, peer, {:error, :eagain}})
    send(fsm, {:circuits_uart, peer, {:error, :eintr}})
    send(fsm, {:circuits_uart, peer, <<>>})
    assert MstpTransport.get_state(transport) == :idle

    write_frame!(peer, <<0x00, 0x55, 0x55>>)
    Process.sleep(80)
    write_frame!(peer, data_frame(6, 255, 9, @who_is))

    assert_receive {:bacnet_transport, {:bacnet_mstp, MstpTransport}, 9,
                    {:apdu, :original_broadcast, _, <<16, 8>>}, ^transport},
                   1_000

    write_frame!(peer, token_frame(9, 3))
    write_frame!(peer, data_frame(6, 9, 3, @who_is))
    write_frame!(peer, too_long_frame(6, 5, 9))
    refute_receive {:bacnet_transport, _, _, _, _}, 50

    write_frame!(peer, flipped_data_frame(3, 5, 2, "ping"))
    assert_receive {:circuits_uart, ^peer, response}, 1_000
    assert :binary.at(response, 2) == 4

    write_frame!(peer, cobs_frame(32, 5, 9, @who_is))
    write_frame!(peer, bad_cobs_frame(33, 5, 9))
    write_frame!(peer, token_frame_type(8, 5, 2))
    write_frame!(peer, token_frame_type(7, 5, 2))
    Process.sleep(50)
    assert Process.alive?(fsm)
    assert Process.alive?(transport)

    Process.unlink(transport)
    ref = Process.monitor(transport)
    send(fsm, {:circuits_uart, peer, {:error, :eio}})
    assert_receive {:DOWN, ^ref, :process, ^transport, {:uart_error, :eio}}, 1_000
  end

  test "an extended frame is delivered to the callback" do
    %{transport: transport, peer: peer} =
      start_master!(local_address: 5, log_communication_rcv: true)

    write_frame!(peer, cobs_frame(32, 5, 9, @who_is))

    assert_receive {:bacnet_transport, {:bacnet_mstp, MstpTransport}, 9,
                    {:apdu, :original_unicast, %NPCI{}, <<16, 8>>}, ^transport},
                   1_000
  end

  test "a valid header during autobaud selects that baudrate" do
    %{transport: transport, peer: peer} =
      start_master!(baudrate: :auto, log_communication_rcv: true)

    write_frame!(peer, token_frame(5, 1))
    assert await_baud(transport, 9600) == 9600
  end

  test "the receiver accepts an autobaud header before the transport initializes" do
    {mine, peer_path, socat_pid} = pty_pair()
    {:ok, peer} = UART.start_link()
    :ok = UART.open(peer, peer_path, uart_opts())

    on_exit(fn ->
      if Process.alive?(peer), do: UART.stop(peer)
      stop_socat(socat_pid)
    end)

    parent = self()

    task =
      Task.async(fn ->
        # Hold the transport between init/1 and its :initialize continuation.
        # UART data can already reach the receiver in this window.
        {:ok, state, {:continue, :initialize}} =
          MstpTransport.init({parent, %{port_name: mine, local_address: 5, baudrate: :auto}})

        try do
          send(parent, :receiver_ready)

          receive do
            :received_valid_frame_autobaud -> :ok
          after
            1_000 -> :header_not_received
          end
        after
          ReceiveFSM.close(state.receive_fsm)
          UART.stop(state.uart_pid)
        end
      end)

    assert_receive :receiver_ready
    write_frame!(peer, token_frame(5, 1))
    assert :ok = Task.await(task)
  end

  test "an invalid frame during autobaud tries the next baudrate" do
    %{transport: transport, peer: peer} = start_master!(baudrate: :auto)
    write_frame!(peer, <<0x55, 0xFF, 0, 5, 9, 0, 0, 0>>)
    assert await_baud(transport, {:auto, 19_200}) == {:auto, 19_200}
    assert MstpTransport.get_state(transport) == :autobaud_detection
  end

  test "the receive fsm accepts configure, reset, and an unknown message" do
    %{transport: transport, peer: peer} = start_master!(log_communication_rcv: true)
    write_frame!(peer, <<0x00, 0x11>>)
    Process.sleep(30)
    assert MstpTransport.get_state(transport) == :idle

    fsm = fsm_pid(transport)
    assert :ok = ReceiveFSM.configure(fsm, %{log_communication: true, baudrate: 9600})
    assert :ok = ReceiveFSM.reset_event_count(fsm)
    send(fsm, :unused)
    assert Process.alive?(fsm)
  end

  defp start_master!(opts) do
    {mine, peer_path, socat_pid} = pty_pair()
    {:ok, peer} = UART.start_link()
    :ok = UART.open(peer, peer_path, uart_opts())

    {:ok, transport} =
      MstpTransport.open(
        self(),
        [
          port_name: mine,
          local_address: 5,
          max_master_address: 8,
          baudrate: 38_400
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

  defp await_baud(transport, expected, attempts \\ 20) do
    case MstpTransport.get_baudrate(transport) do
      ^expected ->
        expected

      _other when attempts > 0 ->
        Process.sleep(25)
        await_baud(transport, expected, attempts - 1)

      other ->
        other
    end
  end

  defp write_frame!(peer, frame) do
    assert :ok = UART.write(peer, frame)
  end

  defp token_frame(dest, src), do: token_frame_type(0, dest, src)

  defp token_frame_type(type, dest, src) do
    header = <<type, dest, src, 0, 0>>
    crc = 0xFF - EncodingTools.calculate_header_crc(header, 0xFF)
    <<0x55, 0xFF, header::binary, crc>>
  end

  defp too_long_frame(type, dest, src) do
    header = <<type, dest, src, 502::size(16)>>
    header_crc = 0xFF - EncodingTools.calculate_header_crc(header, 0xFF)
    <<0x55, 0xFF, header::binary, header_crc, 0::size(504 * 8)>>
  end

  defp flipped_data_frame(type, dest, src, data) do
    <<head::binary-size(8), byte, tail::binary>> = data_frame(type, dest, src, data)
    head <> <<Bitwise.bxor(byte, 0xFF)>> <> tail
  end

  defp bad_cobs_frame(type, dest, src) do
    header = <<type, dest, src, 3::size(16)>>
    header_crc = 0xFF - EncodingTools.calculate_header_crc(header, 0xFF)
    <<0x55, 0xFF, header::binary, header_crc, 1, 1, 1, 1, 1>>
  end

  defp cobs_frame(type, dest, src, data) do
    {:ok, cobs} = EncodingTools.encode_cobs(data)
    cobs = IO.iodata_to_binary(cobs)
    header = <<type, dest, src, byte_size(cobs) - 2::size(16)>>
    header_crc = 0xFF - EncodingTools.calculate_header_crc(header, 0xFF)
    <<0x55, 0xFF, header::binary, header_crc, cobs::binary>>
  end

  defp data_frame(type, dest, src, data) do
    header = <<type, dest, src, byte_size(data)::size(16)>>
    header_crc = 0xFF - EncodingTools.calculate_header_crc(header, 0xFF)
    data_crc = 0xFFFF - EncodingTools.calculate_data_crc(data, 0xFFFF)
    <<0x55, 0xFF, header::binary, header_crc, data::binary, data_crc::little-16>>
  end

  defp fsm_pid(transport) do
    {:links, links} = Process.info(transport, :links)

    Enum.find(links, fn pid ->
      case Process.info(pid, :dictionary) do
        {:dictionary, dict} ->
          dict[:"$initial_call"] == {ReceiveFSM, :init, 1}

        nil ->
          false
      end
    end) || raise "receive fsm is not linked"
  end
end
