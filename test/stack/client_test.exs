defmodule BACnet.Stack.ClientTest do
  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.NPCI
  alias BACnet.Protocol.NpciTarget
  alias BACnet.Stack.Client
  alias BACnet.Stack.EncoderProtocol
  alias BACnet.Stack.Segmentator
  alias BACnet.Stack.SegmentsStore
  alias BACnet.Test.Stack.ApduFactory
  alias BACnet.Test.Stack.FakeTransport

  use BACnet.Test.Stack.Case, async: true

  @moduletag :stack
  @moduletag :client

  @dest :peer

  setup do
    {:ok, transport} = FakeTransport.start_link()
    {:ok, segmentator} = Segmentator.start_link(apdu_timeout: 60_000, apdu_retries: 1)
    {:ok, store} = SegmentsStore.start_link(apdu_timeout: 60_000, apdu_retries: 1)

    {:ok, client} =
      Client.start_link(
        transport: {FakeTransport, transport},
        segmentator: segmentator,
        segments_store: store,
        notification_receiver: self(),
        apdu_timeout: 60_000,
        apdu_retries: 1
      )

    %{
      client: client,
      transport: transport,
      segmentator: segmentator,
      store: store
    }
  end

  describe "start_link/1 and configure/2" do
    test "rejects a non-keyword" do
      assert_raise ArgumentError, ~r/start_link\/1 expected a keyword list/, fn ->
        Client.start_link(%{})
      end
    end

    test "rejects a missing transport" do
      assert_raise ArgumentError, ~r/transport module nil is not loaded/, fn ->
        Client.start_link(segmentator: self(), segments_store: self())
      end
    end

    test "rejects a transport that does not implement the behaviour" do
      assert_raise ArgumentError, ~r/does not implement the BACnet transport behaviour/, fn ->
        Client.start_link(
          transport: {__MODULE__, self()},
          segmentator: self(),
          segments_store: self()
        )
      end
    end

    test "configure updates supported options and rejects the rest", %{client: client} do
      assert :ok =
               Client.configure(client,
                 apdu_retries: 0,
                 apdu_timeout: 40,
                 disable_app_timeout: true,
                 npci_source: %NpciTarget{net: 1, address: nil},
                 segmented_rcv_window_overwrite: true
               )

      assert_raise ArgumentError, ~r/does not support option :transport/, fn ->
        Client.configure(client, transport: {FakeTransport, self()})
      end

      assert_raise ArgumentError, ~r/configure\/2 expected opts to be a keyword list/, fn ->
        Client.configure(client, [:apdu_timeout])
      end
    end

    test "get_transport returns the module, transport, and portal", %{
      client: client,
      transport: transport
    } do
      assert {FakeTransport, ^transport, ^transport} = Client.get_transport(client)
    end

    test "get_broadcast_address and transport_call go through the transport", %{
      client: client
    } do
      assert {:ok, :broadcast} = GenServer.call(client, :get_broadcast_address)

      assert {:ok, :bacnet_ipv4} =
               GenServer.call(client, {:transport_call, :bacnet_protocol, []})

      assert {:ok, 480} = GenServer.call(client, {:transport_call, :max_apdu_length, []})

      assert {:error, {:undef, [_frame | _remaining_frames]}} =
               GenServer.call(client, {:transport_call, :missing, []})
    end
  end

  describe "send/4" do
    test "sends an unconfirmed request and returns :ok", %{client: client} do
      assert :ok = Client.send(client, @dest, ApduFactory.who_is())

      assert_received {:fake_transport_send, @dest, data, opts}
      assert opts[:is_broadcast] == false
      assert {:ok, %APDU.UnconfirmedServiceRequest{service: :who_is}} = APDU.decode(data)
    end

    test "copies npci_source into send opts when the caller omits source", %{
      client: client
    } do
      source = %NpciTarget{net: 2, address: 9}
      assert :ok = Client.configure(client, npci_source: source)
      assert :ok = Client.send(client, @dest, ApduFactory.who_is())

      assert_received {:fake_transport_send, @dest, _data, opts}
      assert opts[:source] == source
    end

    test "a caller source wins over npci_source", %{client: client} do
      configured = %NpciTarget{net: 2, address: 9}
      caller = %NpciTarget{net: 3, address: 4}
      assert :ok = Client.configure(client, npci_source: configured)
      assert :ok = Client.send(client, @dest, ApduFactory.who_is(), source: caller)

      assert_received {:fake_transport_send, @dest, _data, opts}
      assert opts[:source] == caller
    end

    test "confirmed request completes when a simple ack arrives", %{
      client: client,
      transport: transport
    } do
      task = Task.async(fn -> Client.send(client, @dest, ApduFactory.read_property()) end)

      assert_receive {:fake_transport_send, @dest, data, _opts}
      {:ok, %APDU.ConfirmedServiceRequest{invoke_id: 0}} = APDU.decode(data)

      sync(client)
      deliver(client, @dest, ApduFactory.simple_ack(0), transport)

      assert {:ok, %APDU.SimpleACK{invoke_id: 0}} = Task.await(task)
      refute_received {:bacnet_client, _, %APDU.SimpleACK{}, _, _}
    end

    test "the next confirmed request reuses invoke id 0", %{
      client: client,
      transport: transport
    } do
      complete_read(client, transport, @dest, 0)
      task = Task.async(fn -> Client.send(client, @dest, ApduFactory.read_property()) end)
      assert_receive {:fake_transport_send, @dest, data, _opts}
      {:ok, %APDU.ConfirmedServiceRequest{invoke_id: 0}} = APDU.decode(data)
      sync(client)
      deliver(client, @dest, ApduFactory.simple_ack(0), transport)
      assert {:ok, %APDU.SimpleACK{}} = Task.await(task)
    end

    test "an abort for an in-flight request is returned as ok", %{
      client: client,
      transport: transport
    } do
      task = Task.async(fn -> Client.send(client, @dest, ApduFactory.read_property()) end)
      assert_receive {:fake_transport_send, @dest, _data, _opts}
      sync(client)
      deliver(client, @dest, ApduFactory.abort(0, :other), transport)
      assert {:ok, %APDU.Abort{invoke_id: 0}} = Task.await(task)
    end

    test "a simple ack with no in-flight request is delivered to the subscriber", %{
      client: client,
      transport: transport
    } do
      deliver(client, @dest, ApduFactory.simple_ack(3), transport)
      sync(client)

      assert_received {:bacnet_client, nil, %APDU.SimpleACK{invoke_id: 3}, {@dest, _, %NPCI{}},
                       ^client}
    end

    test "invalid destination sends nothing", %{client: client} do
      assert {:error, :invalid_destination} =
               Client.send(client, :invalid, ApduFactory.who_is())

      refute_received {:fake_transport_send, _, _, _}
    end

    test "valid_destination raising is returned", %{client: client} do
      assert {:error, {%ArgumentError{message: "boom"}, _stack}} =
               Client.send(client, {:raise_valid, "boom"}, ApduFactory.who_is())
    end

    test "disable_invoke_id_management rejects a duplicate in-flight id", %{
      client: client
    } do
      assert :ok = Client.configure(client, apdu_retries: 1)

      {:ok, managed, managed_transport} =
        start_client(disable_invoke_id_management: true, apdu_timeout: 60_000)

      req = ApduFactory.read_property(invoke_id: 4)
      task = Task.async(fn -> Client.send(managed, @dest, req) end)
      assert_receive {:fake_transport_send, @dest, data, _opts}
      {:ok, %APDU.ConfirmedServiceRequest{invoke_id: 4}} = APDU.decode(data)

      assert {:error, :duplicate_invoke_id} = Client.send(managed, @dest, req)
      sync(managed)
      deliver(managed, @dest, ApduFactory.simple_ack(4), managed_transport)
      assert {:ok, %APDU.SimpleACK{}} = Task.await(task)
    end

    test "a transport send error does not consume the invoke id", %{
      client: client,
      transport: transport
    } do
      assert :ok = FakeTransport.set_send_result(transport, {:error, :down})

      assert {:error, :down} = Client.send(client, @dest, ApduFactory.read_property())

      assert :ok = FakeTransport.set_send_result(transport, :ok)
      complete_read(client, transport, @dest, 0)
    end

    test "validation failure does not send", %{client: client} do
      bad = %APDU.ConfirmedServiceRequest{
        segmented_response_accepted: true,
        max_apdu: 1476,
        max_segments: :unspecified,
        invoke_id: 1,
        sequence_number: nil,
        proposed_window_size: nil,
        service: :read_property,
        parameters: []
      }

      assert {:error, {:invalid_apdu, {:validation, :invalid_request_parameters}, ^bad}} =
               Client.send(client, @dest, bad)

      refute_received {:fake_transport_send, _, _, _}
    end

    test "bad send opts raise", %{client: client} do
      assert_raise ArgumentError, ~r/NpciTarget/, fn ->
        Client.send(client, @dest, ApduFactory.who_is(), npci_id: 15)
      end

      assert_raise ArgumentError, ~r/npci_id/, fn ->
        Client.send(client, @dest, ApduFactory.who_is(), npci_id: -1)
      end

      assert_raise ArgumentError, ~r/keyword list/, fn ->
        Client.send(client, @dest, ApduFactory.who_is(), [:npci_id])
      end
    end

    test "apdu timer resends once and then times out", %{client: client} do
      task = Task.async(fn -> Client.send(client, @dest, ApduFactory.read_property()) end)
      assert_receive {:fake_transport_send, @dest, _data, _opts}

      send(client, {:apdu_timer, {@dest, nil, 0}})
      assert_receive {:fake_transport_send, @dest, data, _opts}
      {:ok, %APDU.ConfirmedServiceRequest{invoke_id: 0}} = APDU.decode(data)

      send(client, {:apdu_timer, {@dest, nil, 0}})
      assert {:error, :apdu_timeout} = Task.await(task)
    end

    test "segmentator timeout completes the caller with apdu_timeout", %{
      client: client,
      transport: transport
    } do
      assert :ok =
               FakeTransport.set_send_result(transport, fn @dest, raw, _opts ->
                 {:ok, %APDU.ConfirmedServiceRequest{invoke_id: invoke_id}} = APDU.decode(raw)

                 # The client handles this after the send completes and installs its timer.
                 send(client, {:timeout, {:apdu_timer_setup, {@dest, nil, invoke_id}}})
                 :ok
               end)

      assert {:error, :apdu_timeout} = Client.send(client, @dest, ApduFactory.read_property())
      assert_received {:fake_transport_send, @dest, _data, _opts}
    end

    test "routed targets with the same address on different networks have independent transactions",
         %{
           client: client,
           transport: transport
         } do
      req = ApduFactory.read_property()
      target_a = %NpciTarget{net: 10, address: 7}
      target_b = %NpciTarget{net: 20, address: 7}

      task_a =
        Task.async(fn ->
          Client.send(client, @dest, req, destination: target_a, npci_id: target_a)
        end)

      assert_receive {:fake_transport_send, @dest, data_a, _opts}
      {:ok, %APDU.ConfirmedServiceRequest{invoke_id: 0}} = APDU.decode(data_a)

      task_b =
        Task.async(fn ->
          Client.send(client, @dest, req, destination: target_b, npci_id: target_b)
        end)

      assert_receive {:fake_transport_send, @dest, data_b, _opts}
      {:ok, %APDU.ConfirmedServiceRequest{invoke_id: 0}} = APDU.decode(data_b)

      sync(client)
      deliver(client, @dest, ApduFactory.simple_ack(0), transport, NPCI.new(source: target_b))

      assert {:ok, %APDU.SimpleACK{invoke_id: 0}} = Task.await(task_b)
      deliver(client, @dest, ApduFactory.simple_ack(0), transport, NPCI.new(source: target_a))
      assert {:ok, %APDU.SimpleACK{invoke_id: 0}} = Task.await(task_a)

      # Completing both transactions returns each target's invoke ID independently.
      for target <- [target_a, target_b] do
        task =
          Task.async(fn ->
            Client.send(client, @dest, req, destination: target, npci_id: target)
          end)

        assert_receive {:fake_transport_send, @dest, data, _opts}
        assert {:ok, %APDU.ConfirmedServiceRequest{invoke_id: 0}} = APDU.decode(data)
        deliver(client, @dest, ApduFactory.simple_ack(0), transport, NPCI.new(source: target))
        assert {:ok, %APDU.SimpleACK{invoke_id: 0}} = Task.await(task)
      end
    end
  end

  describe "incoming frames" do
    test "forwards bvlc, network, and proprietary frames", %{client: client} do
      bvlc = {:bacnet_transport, {:test, FakeTransport}, @dest, {:bvlc, :result}, self()}
      network = {:bacnet_transport, {:test, FakeTransport}, @dest, {:network, :b, :n, :s}, self()}

      proprietary =
        {:bacnet_transport, {:test, FakeTransport}, @dest, {:proprietary, 128, 1, <<1>>}, self()}

      send(client, bvlc)
      send(client, network)
      send(client, proprietary)

      assert_receive ^bvlc
      assert_receive ^network
      assert_receive ^proprietary
    end

    test "a confirmed request is delivered with a reference and can be replied to", %{
      client: client,
      transport: transport
    } do
      raw = IO.iodata_to_binary(EncoderProtocol.encode(ApduFactory.read_property(invoke_id: 8)))

      send(
        client,
        {:bacnet_transport, {:test, FakeTransport}, @dest,
         {:apdu, :original_unicast, NPCI.new(expects_reply: true), raw}, transport}
      )

      sync(client)

      assert_received {:bacnet_client, ref, %APDU.ConfirmedServiceRequest{invoke_id: 8},
                       {@dest, :original_unicast, %NPCI{}}, ^client}
                      when is_reference(ref)

      assert :ok = Client.reply(client, ref, ApduFactory.simple_ack(8))
      assert_received {:fake_transport_send, @dest, reply, opts}
      assert {:ok, %APDU.SimpleACK{invoke_id: 8}} = APDU.decode(reply)
      assert opts[:is_broadcast] == false
      assert {:error, :app_timeout} = Client.reply(client, ref, ApduFactory.simple_ack(8))
    end

    test "a confirmed request with no receiver is rejected", %{
      transport: transport,
      store: store,
      segmentator: segmentator
    } do
      {:ok, client} =
        Client.start_link(
          transport: {FakeTransport, transport},
          segmentator: segmentator,
          segments_store: store,
          apdu_timeout: 60_000
        )

      raw = IO.iodata_to_binary(EncoderProtocol.encode(ApduFactory.read_property(invoke_id: 2)))

      send(
        client,
        {:bacnet_transport, {:test, FakeTransport}, @dest,
         {:apdu, :original_unicast, NPCI.new(expects_reply: true), raw}, transport}
      )

      sync(client)
      assert_received {:fake_transport_send, @dest, data, _opts}
      assert {:ok, %APDU.Reject{invoke_id: 2, reason: :other}} = APDU.decode(data)
    end

    test "an unconfirmed request with no receiver is dropped", %{
      transport: transport,
      store: store,
      segmentator: segmentator
    } do
      {:ok, client} =
        Client.start_link(
          transport: {FakeTransport, transport},
          segmentator: segmentator,
          segments_store: store
        )

      raw = IO.iodata_to_binary(EncoderProtocol.encode(ApduFactory.who_is()))

      send(
        client,
        {:bacnet_transport, {:test, FakeTransport}, @dest,
         {:apdu, :original_unicast, NPCI.new([]), raw}, self()}
      )

      refute_receive {:fake_transport_send, _, _, _}, 50
      assert {FakeTransport, ^transport, ^transport} = Client.get_transport(client)
    end

    test "nil npci crashes the client", %{client: client} do
      Process.unlink(client)
      ref = Process.monitor(client)

      send(
        client,
        {:bacnet_transport, {:test, FakeTransport}, @dest,
         {:apdu, :original_unicast, nil, <<16, 8>>}, self()}
      )

      assert_receive {:DOWN, ^ref, :process, ^client, {:function_clause, _stack}}, 1_000
    end

    test "per-source apdu timeouts round-trip", %{client: client} do
      target = %NpciTarget{net: 10, address: 5}
      assert :ok = Client.add_apdu_timeout(client, @dest, nil, 250)
      assert {:ok, %{{@dest, nil} => 250}} = Client.get_apdu_timeouts(client)
      assert :ok = Client.set_apdu_timeouts(client, %{{@dest, target} => 10})
      assert {:ok, %{{@dest, ^target} => 10}} = Client.get_apdu_timeouts(client)
      assert :ok = Client.remove_apdu_timeout(client, @dest, nil)
      assert {:ok, %{{@dest, ^target} => 10}} = Client.get_apdu_timeouts(client)
      assert :ok = Client.remove_apdu_timeout(client, @dest, target)
      assert {:ok, %{}} = Client.get_apdu_timeouts(client)

      assert_raise FunctionClauseError, fn ->
        Client.add_apdu_timeout(client, @dest, -1, 10)
      end

      assert_raise FunctionClauseError, fn ->
        Client.add_apdu_timeout(client, @dest, 5, 10)
      end

      assert_raise FunctionClauseError, fn ->
        Client.remove_apdu_timeout(client, @dest, 5)
      end
    end

    test "subscribe is idempotent and down removes a pid", %{client: client} do
      subscriber =
        spawn_link(fn ->
          receive do
            :stop ->
              :ok
          end
        end)

      assert :ok = Client.subscribe(client, subscriber)
      monitor_ref = :sys.get_state(client).notification_recv_monitors[subscriber]
      assert is_reference(monitor_ref)
      assert :ok = Client.subscribe(client, subscriber)
      assert :sys.get_state(client).notification_receiver == [subscriber, self()]
      assert :sys.get_state(client).notification_recv_monitors[subscriber] == monitor_ref
      assert {:monitors, monitors} = Process.info(client, :monitors)
      assert Enum.count(monitors, &(&1 == {:process, subscriber})) == 1

      raw = IO.iodata_to_binary(EncoderProtocol.encode(ApduFactory.who_is()))
      frame(client, raw)
      sync(client)

      # The synchronous call above completes after the client sends every notification.
      assert_received {:bacnet_client, nil, %APDU.UnconfirmedServiceRequest{}, _, ^client}
      refute_received {:bacnet_client, _, _, _, _}

      assert {:messages,
              [
                {:bacnet_client, nil, %APDU.UnconfirmedServiceRequest{}, _source_metadata,
                 ^client}
              ]} =
               Process.info(subscriber, :messages)

      ref = Process.monitor(subscriber)
      send(subscriber, :stop)
      assert_receive {:DOWN, ^ref, :process, ^subscriber, :normal}, 1_000

      # The client and this test receive independent DOWN signals.
      assert wait_for_subscriber_removal(client, subscriber) == [self()]
      refute Map.has_key?(:sys.get_state(client).notification_recv_monitors, subscriber)

      frame(client, raw)
      sync(client)
      assert_received {:bacnet_client, nil, %APDU.UnconfirmedServiceRequest{}, _, ^client}
      refute_received {:bacnet_client, _, _, _, _}
    end

    test "unsubscribe stops delivery", %{client: client} do
      assert :ok = Client.unsubscribe(client, self())
      frame(client, IO.iodata_to_binary(EncoderProtocol.encode(ApduFactory.who_is())))

      refute_receive {:bacnet_client, _, _, _, _}, 50
      assert :ok = Client.subscribe(client, self())
    end

    test "repeated subscribe and unsubscribe cycles leave no monitors behind", %{client: client} do
      subscriber = start_subscriber()
      assert {:monitors, baseline} = Process.info(client, :monitors)

      for _cycle <- 1..20 do
        assert :ok = Client.subscribe(client, subscriber)
        assert :ok = Client.subscribe(client, subscriber)
        assert {:monitors, monitors} = Process.info(client, :monitors)
        assert Enum.sort(monitors) == Enum.sort([{:process, subscriber} | baseline])

        assert :ok = Client.unsubscribe(client, subscriber)
        assert :ok = Client.unsubscribe(client, subscriber)
        refute subscriber in :sys.get_state(client).notification_receiver
        refute Map.has_key?(:sys.get_state(client).notification_recv_monitors, subscriber)
        assert {:monitors, monitors} = Process.info(client, :monitors)
        assert Enum.sort(monitors) == Enum.sort(baseline)
      end
    end

    test "a stale or unrelated DOWN cannot remove a current subscription", %{client: client} do
      subscriber = start_subscriber()
      assert :ok = Client.subscribe(client, subscriber)
      old_ref = :sys.get_state(client).notification_recv_monitors[subscriber]
      assert :ok = Client.unsubscribe(client, subscriber)
      assert :ok = Client.subscribe(client, subscriber)
      current_ref = :sys.get_state(client).notification_recv_monitors[subscriber]
      assert current_ref != old_ref

      send(client, {:DOWN, old_ref, :process, subscriber, :normal})
      send(client, {:DOWN, make_ref(), :process, subscriber, :normal})
      send(client, {:DOWN, current_ref, :process, self(), :normal})
      sync(client)

      state = :sys.get_state(client)
      assert subscriber in state.notification_receiver
      assert self() in state.notification_receiver
      assert state.notification_recv_monitors[subscriber] == current_ref
      assert {:monitors, monitors} = Process.info(client, :monitors)
      assert Enum.count(monitors, &(&1 == {:process, subscriber})) == 1

      ref = Process.monitor(subscriber)
      send(subscriber, :stop)
      assert_receive {:DOWN, ^ref, :process, ^subscriber, :normal}, 1_000
      assert wait_for_subscriber_removal(client, subscriber) == [self()]
      refute Map.has_key?(:sys.get_state(client).notification_recv_monitors, subscriber)
    end

    test "startup PID receivers are deduplicated and monitored while names are left unmonitored" do
      subscriber = start_subscriber()
      name = :client_named_receiver

      {:ok, client, _transport} =
        start_client(notification_receiver: [subscriber, subscriber, name])

      state = :sys.get_state(client)
      assert state.notification_receiver == [subscriber, name]
      assert [subscriber] == Map.keys(state.notification_recv_monitors)
      assert {:monitors, [{:process, ^subscriber}]} = Process.info(client, :monitors)

      assert :ok = Client.subscribe(client, subscriber)
      assert :ok = Client.subscribe(client, name)
      assert :sys.get_state(client).notification_recv_monitors == state.notification_recv_monitors

      ref = Process.monitor(subscriber)
      send(subscriber, :stop)
      assert_receive {:DOWN, ^ref, :process, ^subscriber, :normal}, 1_000
      assert wait_for_subscriber_removal(client, subscriber) == [name]
      assert :sys.get_state(client).notification_recv_monitors == %{}
      assert :ok = Client.unsubscribe(client, name)
      assert :sys.get_state(client).notification_receiver == []
    end

    test "subscribing an already dead PID is cleaned up", %{client: client} do
      subscriber = spawn(fn -> :ok end)
      ref = Process.monitor(subscriber)
      assert_receive {:DOWN, ^ref, :process, ^subscriber, _reason}, 1_000

      assert :ok = Client.subscribe(client, subscriber)
      assert wait_for_subscriber_removal(client, subscriber) == [self()]
      refute Map.has_key?(:sys.get_state(client).notification_recv_monitors, subscriber)
    end

    test "unknown call times out and the client stays up", %{client: client, transport: transport} do
      assert catch_exit(GenServer.call(client, :nope, 50))
      assert {FakeTransport, ^transport, ^transport} = Client.get_transport(client)
    end

    test "unknown info and cast leave the transport in place", %{
      client: client,
      transport: transport
    } do
      send(client, :noise)
      GenServer.cast(client, :noise)
      assert {FakeTransport, ^transport, ^transport} = Client.get_transport(client)
    end
  end

  defp start_subscriber() do
    start_supervised!(
      {Task,
       fn ->
         receive do
           :stop -> :ok
         end
       end}
    )
  end

  defp start_client(extra) do
    {:ok, transport} = FakeTransport.start_link()
    {:ok, segmentator} = Segmentator.start_link(apdu_timeout: 60_000, apdu_retries: 1)
    {:ok, store} = SegmentsStore.start_link(apdu_timeout: 60_000, apdu_retries: 1)

    {:ok, client} =
      Client.start_link(
        [
          transport: {FakeTransport, transport},
          segmentator: segmentator,
          segments_store: store,
          notification_receiver: self()
        ] ++ extra
      )

    {:ok, client, transport}
  end

  defp complete_read(client, portal, dest, invoke_id) do
    task = Task.async(fn -> Client.send(client, dest, ApduFactory.read_property()) end)
    assert_receive {:fake_transport_send, ^dest, data, _opts}
    {:ok, %APDU.ConfirmedServiceRequest{invoke_id: ^invoke_id}} = APDU.decode(data)
    sync(client)
    deliver(client, dest, ApduFactory.simple_ack(invoke_id), portal)
    assert {:ok, %APDU.SimpleACK{invoke_id: ^invoke_id}} = Task.await(task)
  end

  defp sync(client) do
    Client.get_transport(client)
  end

  defp wait_for_subscriber_removal(client, subscriber, attempts \\ 100) do
    receivers = :sys.get_state(client).notification_receiver

    if subscriber in receivers and attempts > 0 do
      Process.sleep(10)
      wait_for_subscriber_removal(client, subscriber, attempts - 1)
    else
      receivers
    end
  end

  defp deliver(client, source, apdu, portal, npci \\ NPCI.new([])) do
    raw = IO.iodata_to_binary(EncoderProtocol.encode(apdu))

    send(
      client,
      {:bacnet_transport, {:bacnet_ipv4, FakeTransport}, source,
       {:apdu, :original_unicast, npci, raw}, portal}
    )
  end

  defp frame(client, raw) do
    send(
      client,
      {:bacnet_transport, {:test, FakeTransport}, @dest,
       {:apdu, :original_unicast, NPCI.new([]), raw}, self()}
    )
  end
end
