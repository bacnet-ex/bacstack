defmodule BACnet.Stack.ForeignDeviceTest do
  alias BACnet.Protocol.BroadcastDistributionTableEntry
  alias BACnet.Protocol.BvlcFunction
  alias BACnet.Protocol.BvlcResult
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ForeignDeviceTableEntry
  alias BACnet.Protocol.NPCI
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.IAm
  alias BACnet.Protocol.Services.WhoIs
  alias BACnet.Stack.Client
  alias BACnet.Stack.EncoderProtocol
  alias BACnet.Stack.ForeignDevice
  alias BACnet.Stack.Segmentator
  alias BACnet.Stack.SegmentsStore
  alias BACnet.Test.Stack.FakeTransport

  require Constants

  use ExUnit.Case, async: true

  @moduletag :stack
  @moduletag :foreign_device

  @bbmd {{192, 168, 1, 20}, 47_808}
  @local {{10, 0, 0, 8}, 47_808}
  @broadcast {{10, 0, 0, 255}, 47_808}

  setup do
    {:ok, transport} =
      FakeTransport.start_link(local: @local, broadcast: @broadcast)

    {:ok, segmentator} = Segmentator.start_link(apdu_timeout: 60_000, apdu_retries: 0)
    {:ok, store} = SegmentsStore.start_link(apdu_timeout: 60_000, apdu_retries: 0)

    {:ok, client} =
      Client.start_link(
        transport: {FakeTransport, transport},
        segmentator: segmentator,
        segments_store: store
      )

    %{transport: transport, client: client}
  end

  test "start_link rejects bad options", %{client: client} do
    assert_raise ArgumentError, ~r/keyword list/, fn ->
      ForeignDevice.start_link(%{})
    end

    assert_raise ArgumentError, ~r/bbmd/, fn ->
      ForeignDevice.start_link(bbmd: {{1, 2, 3, 4}, 0}, client: client)
    end

    assert_raise ArgumentError, ~r/client/, fn ->
      ForeignDevice.start_link(bbmd: @bbmd, client: "nope")
    end

    assert_raise ArgumentError, ~r/reply_rfd/, fn ->
      ForeignDevice.start_link(bbmd: @bbmd, client: client, reply_rfd: :yes)
    end

    assert_raise ArgumentError, ~r/ttl/, fn ->
      ForeignDevice.start_link(bbmd: @bbmd, client: client, ttl: 0)
    end
  end

  test "a transport without an IPv4 local address stops the server" do
    {:ok, transport} = FakeTransport.start_link(local: :local, broadcast: :broadcast)
    {:ok, segmentator} = Segmentator.start_link(apdu_timeout: 60_000, apdu_retries: 0)
    {:ok, store} = SegmentsStore.start_link(apdu_timeout: 60_000, apdu_retries: 0)

    {:ok, bare} =
      Client.start_link(
        transport: {FakeTransport, transport},
        segmentator: segmentator,
        segments_store: store
      )

    parent = self()

    spawn(fn ->
      Process.flag(:trap_exit, true)
      send(parent, {:started, ForeignDevice.start_link(bbmd: @bbmd, client: bare)})
    end)

    assert_receive {:started, {:error, :invalid_local_address}}, 500
  end

  test "registration is acknowledged and a later timer leaves it registered", %{
    client: client,
    transport: transport
  } do
    fd = start_fd!(client)
    assert ForeignDevice.get_status(fd) == :waiting_for_ack

    ack(fd, transport, :successful_completion)
    assert ForeignDevice.get_status(fd) == :registered

    send(fd, :fd_reg_timer)
    assert ForeignDevice.get_status(fd) == :registered
    refute_received {:fake_transport_send, @bbmd, _data, _opts}
  end

  test "a negative acknowledgement is retried", %{client: client, transport: transport} do
    fd = start_fd!(client, ttl: 30)
    ack(fd, transport, :register_foreign_device_nak)
    assert ForeignDevice.get_status(fd) == :uninitialized

    send(fd, :fd_reg_retry)
    assert ForeignDevice.get_status(fd) == :waiting_for_ack
    assert_registration(transport)
  end

  test "a failed registration send stays uninitialized and renew reports the error", %{
    client: client,
    transport: transport
  } do
    assert :ok = FakeTransport.set_send_result(transport, {:error, :down})
    fd = start_fd!(client)
    assert ForeignDevice.get_status(fd) == :uninitialized
    assert {:error, :down} = ForeignDevice.renew(fd)
  end

  test "an unanswered registration is sent again when its timer fires", %{
    client: client,
    transport: transport
  } do
    fd = start_fd!(client)
    send(fd, :fd_reg_timer)
    assert ForeignDevice.get_status(fd) == :waiting_for_ack
    assert_registration(transport)
  end

  test "a foreign device registration request is rejected", %{
    client: client,
    transport: transport
  } do
    fd = start_fd!(client)

    send(fd, bvlc_frame(transport, @bbmd, register_request()))
    assert_receive {:fake_transport_send, @bbmd, nak, opts}
    assert opts[:npci] == false
    assert is_binary(nak)

    ipv6 = {1, 2, 3, 4, 5, 6, 7, 8}
    send(fd, bvlc_frame(transport, ipv6, register_request()))
    assert_receive {:fake_transport_send, ^ipv6, _nak, _opts}

    send(fd, bvlc_frame(transport, {ipv6, 47_808}, register_request()))
    assert_receive {:fake_transport_send, {^ipv6, 47_808}, _nak, _opts}

    send(fd, bvlc_frame(transport, :somewhere, register_request()))
    assert_receive {:fake_transport_send, :somewhere, _nak, _opts}
  end

  test "reply_rfd false ignores a foreign registration request", %{
    client: client,
    transport: transport
  } do
    fd = start_fd!(client, reply_rfd: false)
    send(fd, bvlc_frame(transport, @bbmd, register_request()))
    assert ForeignDevice.get_status(fd) == :waiting_for_ack
    refute_received {:fake_transport_send, _, _, _}
  end

  test "stop deletes an active registration and shuts down", %{
    client: client,
    transport: transport
  } do
    fd = start_fd!(client)
    ack(fd, transport, :successful_completion)
    ref = Process.monitor(fd)

    assert :ok = ForeignDevice.stop(fd)
    assert_receive {:DOWN, ^ref, :process, ^fd, :normal}
    assert_receive {:fake_transport_send, @bbmd, _data, opts}
    assert opts[:npci] == false
  end

  test "stop before registration does not delete an entry", %{client: client} do
    fd = start_fd!(client)
    ref = Process.monitor(fd)
    assert :ok = ForeignDevice.stop(fd)
    assert_receive {:DOWN, ^ref, :process, ^fd, :normal}
    refute_received {:fake_transport_send, @bbmd, _, _}
  end

  test "distribute_broadcast returns ok when the BBMD stays silent", %{client: client} do
    fd = start_fd!(client)
    {:ok, apdu} = WhoIs.to_apdu(%WhoIs{device_id_low_limit: nil, device_id_high_limit: nil}, [])

    assert :ok = ForeignDevice.distribute_broadcast(fd, apdu, receive_timeout: 40)
  end

  test "distribute_broadcast returns a negative result", %{client: client, transport: transport} do
    fd = start_fd!(client)
    {:ok, apdu} = WhoIs.to_apdu(%WhoIs{device_id_low_limit: 1, device_id_high_limit: 2}, [])

    task =
      Task.async(fn -> ForeignDevice.distribute_broadcast(fd, apdu, receive_timeout: 2_000) end)

    assert_receive {:fake_transport_send, @bbmd, _apdu, opts}, 1_000
    assert opts[:bvlc] != nil

    send(
      client,
      bvlc_frame(transport, @bbmd, %BvlcResult{
        result_code:
          Constants.macro_assert_name(:bvlc_result_format, :distribute_broadcast_to_network_nak)
      })
    )

    assert {:error, %BvlcResult{}} = Task.await(task)
  end

  test "distribute_broadcast rejects a request that expects a reply", %{client: client} do
    fd = start_fd!(client)
    {:ok, apdu} = WhoIs.to_apdu(%WhoIs{device_id_low_limit: nil, device_id_high_limit: nil}, [])

    assert_raise ArgumentError, ~r/expects reply/, fn ->
      ForeignDevice.distribute_broadcast(fd, apdu, expects_reply: true)
    end

    assert_raise ArgumentError, ~r/keyword list/, fn ->
      ForeignDevice.distribute_broadcast(fd, apdu, [1])
    end
  end

  test "the broadcast distribution table can be read and written", %{
    client: client,
    transport: transport
  } do
    fd = start_fd!(client)

    entry = %BroadcastDistributionTableEntry{
      ip: {192, 168, 1, 1},
      port: 47_808,
      mask: {255, 255, 255, 0}
    }

    # Successful table exchanges are driven by the test, with Task.await/1
    # bounding completion. A short protocol timeout races coverage and CI load.
    task = Task.async(fn -> ForeignDevice.read_broadcast_distribution_table(fd) end)

    assert_receive {:fake_transport_send, @bbmd, _data, opts}, 1_000
    assert opts[:npci] == false

    send(
      client,
      bvlc_frame(transport, @bbmd, %BvlcFunction{
        function:
          Constants.macro_assert_name(
            :bvlc_result_purpose,
            :bvlc_read_broadcast_distribution_table_ack
          ),
        data: [entry]
      })
    )

    assert {:ok, [^entry]} = Task.await(task)

    task = Task.async(fn -> ForeignDevice.write_broadcast_distribution_table(fd, [entry]) end)

    assert_receive {:fake_transport_send, @bbmd, _data, _opts}, 1_000

    send(client, bvlc_frame(transport, @bbmd, %BvlcResult{result_code: :successful_completion}))
    assert :ok = Task.await(task)

    assert_raise ArgumentError, ~r/BroadcastDistributionTableEntry/, fn ->
      ForeignDevice.write_broadcast_distribution_table(fd, [:nope])
    end

    assert_raise ArgumentError, ~r/keyword list/, fn ->
      ForeignDevice.read_broadcast_distribution_table(fd, [1])
    end
  end

  test "table reads and writes report a negative result", %{client: client, transport: transport} do
    fd = start_fd!(client)
    task = Task.async(fn -> ForeignDevice.read_foreign_device_table(fd) end)

    assert_receive {:fake_transport_send, @bbmd, _data, _opts}, 1_000

    send(
      client,
      bvlc_frame(transport, @bbmd, %BvlcResult{
        result_code:
          Constants.macro_assert_name(:bvlc_result_format, :read_foreign_device_table_nak)
      })
    )

    assert {:error, %BvlcResult{}} = Task.await(task)

    task = Task.async(fn -> ForeignDevice.read_broadcast_distribution_table(fd) end)

    assert_receive {:fake_transport_send, @bbmd, _data, _opts}, 1_000

    send(
      client,
      bvlc_frame(transport, @bbmd, %BvlcResult{
        result_code:
          Constants.macro_assert_name(
            :bvlc_result_format,
            :read_broadcast_distribution_table_nak
          )
      })
    )

    assert {:error, %BvlcResult{}} = Task.await(task)

    entry = %BroadcastDistributionTableEntry{
      ip: {1, 2, 3, 4},
      port: 47_808,
      mask: {255, 255, 255, 255}
    }

    task = Task.async(fn -> ForeignDevice.write_broadcast_distribution_table(fd, [entry]) end)

    assert_receive {:fake_transport_send, @bbmd, _data, _opts}, 1_000

    send(
      client,
      bvlc_frame(transport, @bbmd, %BvlcResult{
        result_code:
          Constants.macro_assert_name(
            :bvlc_result_format,
            :write_broadcast_distribution_table_nak
          )
      })
    )

    assert {:error, %BvlcResult{}} = Task.await(task)
  end

  test "a table read times out", %{client: client} do
    fd = start_fd!(client)
    assert {:error, :timeout} = ForeignDevice.read_foreign_device_table(fd, timeout: 20)
  end

  test "send_whois collects an I-Am and stops at max", %{client: client, transport: transport} do
    fd = start_fd!(client)
    parent = self()

    spawn(fn ->
      send(parent, {:who, ForeignDevice.send_whois(fd, 200, max: 1, receive_timeout: 30)})
    end)

    assert_receive {:fake_transport_send, @bbmd, _apdu, _opts}, 500
    raw = i_am_binary()

    send(
      client,
      {:bacnet_transport, :bacnet_ipv4, @bbmd, {:apdu, nil, NPCI.new([]), raw}, transport}
    )

    assert_receive {:who, {:ok, [{@bbmd, %IAm{vendor_id: 42}}]}}, 500

    assert_raise ArgumentError, ~r/keyword list/, fn ->
      ForeignDevice.send_whois(fd, 100, [1])
    end
  end

  test "renew sends another registration", %{client: client, transport: transport} do
    fd = start_fd!(client)
    ack(fd, transport, :successful_completion)
    assert :ok = ForeignDevice.renew(fd)
    assert ForeignDevice.get_status(fd) == :waiting_for_ack
    assert_registration(transport)
  end

  test "a registration that has expired is renewed", %{client: client, transport: transport} do
    fd = start_fd!(client, ttl: 1)
    ack(fd, transport, :successful_completion)
    Process.sleep(1_100)
    send(fd, :fd_reg_timer)
    assert ForeignDevice.get_status(fd) == :waiting_for_ack
    assert_registration(transport)
  end

  test "a retry and an expiry resend report a transport error", %{
    client: client,
    transport: transport
  } do
    fd = start_fd!(client)
    ack(fd, transport, :register_foreign_device_nak)
    assert :ok = FakeTransport.set_send_result(transport, {:error, :busy})
    send(fd, :fd_reg_retry)
    assert ForeignDevice.get_status(fd) == :uninitialized

    assert :ok = FakeTransport.set_send_result(transport, :ok)
    expiring = start_fd!(client, ttl: 1)
    ack(expiring, transport, :successful_completion)
    assert :ok = FakeTransport.set_send_result(transport, {:error, :busy})
    Process.sleep(1_100)
    send(expiring, :fd_reg_timer)
    assert ForeignDevice.get_status(expiring) == :registered
  end

  test "stop still shuts down when deleting the registration fails", %{
    client: client,
    transport: transport
  } do
    fd = start_fd!(client)
    ack(fd, transport, :successful_completion)
    assert :ok = FakeTransport.set_send_result(transport, {:error, :down})
    ref = Process.monitor(fd)
    assert :ok = ForeignDevice.stop(fd)
    assert_receive {:DOWN, ^ref, :process, ^fd, :normal}
  end

  test "killing a registered server deletes its table entry", %{
    client: client,
    transport: transport
  } do
    fd = start_fd!(client)
    ack(fd, transport, :successful_completion)
    assert ForeignDevice.get_status(fd) == :registered
    Process.unlink(fd)
    parent = self()

    spawn(fn ->
      Process.flag(:trap_exit, true)
      send(parent, {:stopped, GenServer.stop(fd, :shutdown)})
    end)

    assert_receive {:stopped, :ok}, 1_000
    assert_received {:fake_transport_send, @bbmd, _data, opts}
    assert opts[:npci] == false
  end

  test "the foreign device table can be read", %{client: client, transport: transport} do
    fd = start_fd!(client)

    entry = %ForeignDeviceTableEntry{
      ip: {10, 0, 0, 8},
      port: 47_808,
      time_to_live: 60,
      remaining_time: 40
    }

    task = Task.async(fn -> ForeignDevice.read_foreign_device_table(fd) end)

    assert_receive {:fake_transport_send, @bbmd, _data, _opts}, 1_000

    send(
      client,
      bvlc_frame(transport, @bbmd, %BvlcFunction{
        function:
          Constants.macro_assert_name(
            :bvlc_result_purpose,
            :bvlc_read_foreign_device_table_ack
          ),
        data: [entry]
      })
    )

    assert {:ok, [^entry]} = Task.await(task)

    assert_raise ArgumentError, ~r/keyword list/, fn ->
      ForeignDevice.read_foreign_device_table(fd, [1])
    end

    assert_raise ArgumentError, ~r/keyword list/, fn ->
      ForeignDevice.write_broadcast_distribution_table(fd, [], [1])
    end
  end

  test "send_whois returns when its timer fires", %{client: client} do
    fd = start_fd!(client)
    assert {:ok, []} = ForeignDevice.send_whois(fd, 100, receive_timeout: 20, max: 0)
  end

  test "unknown messages are ignored", %{client: client} do
    fd = start_fd!(client)
    send(fd, :unused)
    GenServer.cast(fd, :unused)

    parent = self()

    spawn(fn ->
      result =
        try do
          GenServer.call(fd, :unused, 40)
        catch
          :exit, reason -> {:exit, reason}
        end

      send(parent, {:call, result})
    end)

    assert_receive {:call, {:exit, {:timeout, _}}}, 500
    assert ForeignDevice.get_status(fd) in [:waiting_for_ack, :uninitialized, :registered]
  end

  test "a registered name is the server", %{client: client} do
    name = :"foreign_device_#{System.unique_integer([:positive])}"
    assert {:ok, pid} = ForeignDevice.start_link(name: name, bbmd: @bbmd, client: client)
    assert Process.whereis(name) == pid
    assert ForeignDevice.get_status(name) == :waiting_for_ack
  end

  defp start_fd!(client, opts \\ []) do
    {:ok, fd} = ForeignDevice.start_link([bbmd: @bbmd, client: client] ++ opts)
    assert_receive {:fake_transport_send, @bbmd, _data, _opts}
    fd
  end

  defp assert_registration(transport) do
    assert_receive {:fake_transport_send, @bbmd, data, opts}
    assert is_binary(data)
    assert opts[:npci] == false
    assert opts[:bvlc] != nil
    transport
  end

  defp ack(fd, transport, code) do
    send(fd, bvlc_frame(transport, @bbmd, %BvlcResult{result_code: code}))
    assert ForeignDevice.get_status(fd)
  end

  defp bvlc_frame(transport, source, bvlc) do
    {:bacnet_transport, :bacnet_ipv4, source, {:bvlc, bvlc}, transport}
  end

  defp register_request() do
    %BvlcFunction{
      function: Constants.macro_assert_name(:bvlc_result_purpose, :bvlc_register_foreign_device),
      data: 60
    }
  end

  defp i_am_binary() do
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

    IO.iodata_to_binary(EncoderProtocol.encode(apdu))
  end
end
