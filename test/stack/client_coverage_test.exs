defmodule BACnet.Stack.ClientCoverageTest do
  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BvlcForwardedNPDU
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.NPCI
  alias BACnet.Protocol.NpciTarget
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.WriteProperty
  alias BACnet.Stack.Client
  alias BACnet.Stack.EncoderProtocol
  alias BACnet.Stack.Segmentator
  alias BACnet.Stack.SegmentsStore
  alias BACnet.Test.Stack.ApduFactory
  alias BACnet.Test.Stack.FakeTransport
  alias BACnet.Test.Stack.FakeTransport.Limited

  require Constants

  use BACnet.Test.Stack.Case, async: true

  @moduletag :stack
  @moduletag :client

  @dest :peer

  setup do
    {:ok, transport} = FakeTransport.start_link()
    {:ok, segmentator} = Segmentator.start_link(apdu_timeout: 60_000, apdu_retries: 0)
    {:ok, store} = SegmentsStore.start_link(apdu_timeout: 60_000, apdu_retries: 1)

    opts = [
      transport: {FakeTransport, transport},
      segmentator: segmentator,
      segments_store: store,
      notification_receiver: self(),
      apdu_timeout: 60_000,
      apdu_retries: 1
    ]

    {:ok, client} = Client.start_link(opts)

    %{
      client: client,
      transport: transport,
      segmentator: segmentator,
      store: store,
      opts: opts
    }
  end

  test "transport module atom is used as the registered process", %{
    segmentator: segmentator,
    store: store
  } do
    name = FakeTransport
    {:ok, _pid} = FakeTransport.start_link(name: name)

    assert {:ok, client} =
             Client.start_link(
               transport: name,
               segmentator: segmentator,
               segments_store: store,
               apdu_timeout: 60_000
             )

    assert {^name, ^name, ^name} = Client.get_transport(client)
  end

  test "start_link accepts every documented server shape and rejects the rest", %{
    transport: transport,
    segmentator: segmentator,
    store: store
  } do
    base = [transport: {FakeTransport, transport}, apdu_timeout: 60_000]

    assert {:ok, _client} =
             Client.start_link(
               base ++
                 [
                   segmentator: segmentator,
                   segments_store: store,
                   notification_receiver: :client_coverage_receiver,
                   npci_source: %NpciTarget{net: 1, address: nil}
                 ]
             )

    assert {:ok, _client} =
             Client.start_link(
               base ++
                 [
                   segmentator: {__MODULE__, node()},
                   segments_store: {:via, __MODULE__, :client_coverage_store}
                 ]
             )

    port = Port.open({:spawn, "cat"}, [:binary])

    assert {:ok, _client} =
             Client.start_link(
               base ++
                 [
                   segmentator: segmentator,
                   segments_store: store,
                   notification_receiver: port
                 ]
             )

    Port.close(port)

    assert {:ok, _client} =
             Client.start_link(
               base ++
                 [
                   segmentator: segmentator,
                   segments_store: store,
                   notification_receiver: [self(), :client_coverage_dead_name]
                 ]
             )

    raw = IO.iodata_to_binary(EncoderProtocol.encode(ApduFactory.who_is()))

    {:ok, with_dead} =
      Client.start_link(
        base ++
          [
            segmentator: segmentator,
            segments_store: store,
            notification_receiver: [self(), :client_coverage_dead_name]
          ]
      )

    send(
      with_dead,
      {:bacnet_transport, {:test, FakeTransport}, @dest,
       {:apdu, :original_unicast, NPCI.new([]), raw}, transport}
    )

    sync(with_dead)
    assert_received {:bacnet_client, nil, %APDU.UnconfirmedServiceRequest{}, _, ^with_dead}

    assert_raise ArgumentError, ~r/apdu_retries/, fn ->
      Client.start_link(
        base ++ [segmentator: segmentator, segments_store: store, apdu_retries: -1]
      )
    end

    assert_raise ArgumentError, ~r/apdu_timeout/, fn ->
      Client.start_link(
        transport: {FakeTransport, transport},
        segmentator: segmentator,
        segments_store: store,
        apdu_timeout: 0
      )
    end

    assert_raise ArgumentError, ~r/disable_app_timeout/, fn ->
      Client.start_link(
        base ++ [segmentator: segmentator, segments_store: store, disable_app_timeout: :yes]
      )
    end

    assert_raise ArgumentError, ~r/disable_invoke_id_management/, fn ->
      Client.start_link(
        base ++
          [segmentator: segmentator, segments_store: store, disable_invoke_id_management: :yes]
      )
    end

    assert_raise ArgumentError, ~r/notification_receiver/, fn ->
      Client.start_link(
        base ++ [segmentator: segmentator, segments_store: store, notification_receiver: "no"]
      )
    end

    assert_raise ArgumentError, ~r/notification_receiver/, fn ->
      Client.start_link(
        base ++ [segmentator: segmentator, segments_store: store, notification_receiver: ["no"]]
      )
    end

    assert_raise ArgumentError, ~r/npci_source/, fn ->
      Client.start_link(
        base ++ [segmentator: segmentator, segments_store: store, npci_source: :no]
      )
    end

    assert_raise ArgumentError, ~r/segmentator/, fn ->
      Client.start_link(base ++ [segmentator: "no", segments_store: store])
    end

    assert_raise ArgumentError, ~r/segments_store/, fn ->
      Client.start_link(base ++ [segmentator: segmentator, segments_store: "no"])
    end

    assert_raise ArgumentError, ~r/segmented_rcv_window_overwrite/, fn ->
      Client.start_link(
        base ++
          [segmentator: segmentator, segments_store: store, segmented_rcv_window_overwrite: :no]
      )
    end

    assert_raise ArgumentError, ~r/transport/, fn ->
      Client.start_link(segmentator: segmentator, segments_store: store, transport: "no")
    end

    assert_raise ArgumentError, ~r/not loaded/, fn ->
      Client.start_link(
        segmentator: segmentator,
        segments_store: store,
        transport: {NotALoadedTransport, self()}
      )
    end

    port = Port.open({:spawn, "cat"}, [:binary])
    parent = self()

    # init calls the transport with the port. That raises inside the new
    # process, and the link would kill this process before it can report
    # the start result
    spawn(fn ->
      Process.flag(:trap_exit, true)

      send(
        parent,
        {:port_transport,
         Client.start_link(
           segmentator: self(),
           segments_store: self(),
           transport: {FakeTransport, port}
         )}
      )
    end)

    assert_receive {:port_transport, {:error, {:function_clause, stack}}}, 1_000
    assert {GenServer, :whereis, _arity, _location} = hd(stack)
    Port.close(port)
  end

  test "start_link accepts tuple server names", %{
    transport: _transport,
    segmentator: segmentator,
    store: store
  } do
    reg = :"client_coverage_reg_#{System.unique_integer([:positive])}"
    {:ok, _registry} = Registry.start_link(keys: :unique, name: reg)
    via = {:via, Registry, {reg, :transport}}
    {:ok, _transport} = FakeTransport.start_link(name: via)

    assert {:ok, via_client} =
             Client.start_link(
               transport: {FakeTransport, via},
               segmentator: segmentator,
               segments_store: store,
               apdu_timeout: 60_000
             )

    assert {FakeTransport, ^via, ^via} = Client.get_transport(via_client)

    name = :"client_coverage_named_#{System.unique_integer([:positive])}"
    {:ok, _transport} = FakeTransport.start_link(name: name)

    assert {:ok, named} =
             Client.start_link(
               transport: {FakeTransport, name},
               segmentator: {:via, Registry, {reg, :segmentator}},
               segments_store: {__MODULE__, node()},
               notification_receiver: {__MODULE__, node()},
               apdu_timeout: 60_000
             )

    assert {FakeTransport, ^name, ^name} = Client.get_transport(named)

    local = {name, node()}

    assert {:ok, local_client} =
             Client.start_link(
               transport: {FakeTransport, local},
               segmentator: segmentator,
               segments_store: store,
               apdu_timeout: 60_000
             )

    assert {FakeTransport, ^local, ^local} = Client.get_transport(local_client)
  end

  test "send option validation", %{client: client} do
    assert_raise ArgumentError, ~r/max_apdu_length/, fn ->
      Client.send(client, @dest, ApduFactory.who_is(), max_apdu_length: 0)
    end

    assert_raise ArgumentError, ~r/max_segments/, fn ->
      Client.send(client, @dest, ApduFactory.who_is(), max_segments: 0)
    end

    assert_raise ArgumentError, ~r/segmentation_supported/, fn ->
      Client.send(client, @dest, ApduFactory.who_is(), segmentation_supported: :nope)
    end

    assert_raise ArgumentError, ~r/reply\/4/, fn ->
      Client.reply(client, make_ref(), ApduFactory.simple_ack(1), [:not_a_keyword])
    end
  end

  test "transport_call passes ok and error tuples through", %{client: client} do
    assert {:ok, :from_transport} =
             GenServer.call(client, {:transport_call, :scripted, [{:ok, :from_transport}]})

    assert {:error, :from_transport} =
             GenServer.call(client, {:transport_call, :scripted, [{:error, :from_transport}]})
  end

  test "get_broadcast_address returns the transport exception", %{
    client: client,
    transport: transport
  } do
    Process.unlink(transport)
    assert :ok = FakeTransport.set_crash_broadcast(transport, true)

    assert {:error, wrapped} = GenServer.call(client, :get_broadcast_address)
    assert inspect(wrapped) =~ "broadcast unavailable"
  end

  test "to_service raising is an invalid apdu and nothing is sent", %{client: client} do
    bad = %APDU.UnconfirmedServiceRequest{
      service: :who_is,
      parameters: [{:tagged, {0, <<1>>, 2}}, {:tagged, {1, <<1>>, 2}}]
    }

    assert {:error, {:invalid_apdu, {:rescue, %MatchError{}, _stack}, ^bad}} =
             Client.send(client, @dest, bad)

    refute_received {:fake_transport_send, _, _, _}
  end

  test "encode failure is returned from the server", %{opts: opts} do
    {:ok, client} = Client.start_link(Keyword.put(opts, :disable_invoke_id_management, true))
    ack = %{ApduFactory.complex_ack(1) | invoke_id: 300}

    assert {:error, {%ArgumentError{}, _stack}} = Client.send(client, @dest, ack)
    refute_received {:fake_transport_send, _, _, _}
  end

  test "a response that cannot be segmented sends abort apdu_too_long", %{client: client} do
    error = %APDU.Error{
      invoke_id: 3,
      service: :read_property,
      class: :device,
      code: :operational_problem,
      payload: [{:octet_string, :binary.copy(<<1>>, 80)}]
    }

    assert {:error, :apdu_too_long} =
             Client.send(client, @dest, error, max_apdu_length: 50)

    assert_received {:fake_transport_send, @dest, %APDU.Abort{reason: :apdu_too_long}, _opts}
  end

  test "a segmentable request the remote cannot accept returns segmentation_not_supported", %{
    client: client
  } do
    assert {:error, :segmentation_not_supported} =
             Client.send(client, @dest, long_confirmed_request(), max_apdu_length: 50)

    refute_received {:fake_transport_send, _, _, _}
  end

  test "a segmentable confirmed request is tracked without an apdu timer", %{
    client: client,
    transport: transport
  } do
    request = %{long_confirmed_request() | sequence_number: 0, proposed_window_size: 4}

    task =
      Task.async(fn ->
        Client.send(client, @dest, request,
          max_apdu_length: 80,
          max_segments: 16,
          segmentation_supported: Constants.macro_assert_name(:segmentation, :segmented_both)
        )
      end)

    assert_receive {:fake_transport_send, @dest, segment, _opts}

    assert {:incomplete, %BACnet.Protocol.IncompleteAPDU{sequence_number: 0}} =
             APDU.decode(segment)

    sync(client)
    deliver(client, @dest, ApduFactory.simple_ack(0), transport)
    assert {:ok, %APDU.SimpleACK{invoke_id: 0}} = Task.await(task)
  end

  test "a request that cannot be segmented returns apdu_too_long and sends nothing", %{
    client: client
  } do
    who_is = %{
      ApduFactory.who_is()
      | parameters: [{:octet_string, :binary.copy(<<1>>, 80)}]
    }

    assert {:error, :apdu_too_long} =
             Client.send(client, @dest, who_is, max_apdu_length: 50)

    refute_received {:fake_transport_send, _, _, _}
  end

  test "a response the remote cannot accept segmented sends abort segmentation_not_supported", %{
    client: client
  } do
    ack = large_ack()

    assert {:error, :segmentation_not_supported} =
             Client.send(client, @dest, ack, max_apdu_length: 50)

    assert_received {:fake_transport_send, @dest,
                     %APDU.Abort{reason: :segmentation_not_supported}, _opts}
  end

  test "a segmentable response is handed to the segmentator", %{client: client} do
    assert :ok =
             Client.send(client, @dest, large_ack(),
               max_apdu_length: 80,
               max_segments: 16,
               segmentation_supported: Constants.macro_assert_name(:segmentation, :segmented_both)
             )

    assert_received {:fake_transport_send, @dest, segment, _opts}

    assert {:incomplete, %BACnet.Protocol.IncompleteAPDU{sequence_number: 0}} =
             APDU.decode(segment)
  end

  test "segmented receive is rejected when the remote segment count is too small", %{
    client: client
  } do
    assert {:error, :too_many_segments} =
             Client.send(client, @dest, large_ack(),
               max_apdu_length: 80,
               max_segments: 1,
               segmentation_supported:
                 Constants.macro_assert_name(:segmentation, :segmented_receive)
             )

    assert_received {:fake_transport_send, @dest, abort, _opts}
    assert %APDU.Abort{reason: :buffer_overflow} = abort
  end

  test "limited transport uses max_npdu_length when extended length is not exported" do
    {:ok, transport} = FakeTransport.start_link()
    {:ok, segmentator} = Segmentator.start_link(apdu_timeout: 60_000)
    {:ok, store} = SegmentsStore.start_link(apdu_timeout: 60_000)

    {:ok, client} =
      Client.start_link(
        transport: {Limited, transport},
        segmentator: segmentator,
        segments_store: store,
        apdu_timeout: 60_000
      )

    assert :ok = Client.send(client, @dest, ApduFactory.who_is(), max_apdu_length: 400)
  end

  test "timer address comes from destination and from npci", %{
    client: client,
    transport: transport
  } do
    req = ApduFactory.read_property()
    target = %NpciTarget{net: 4, address: 9}

    task =
      Task.async(fn ->
        Client.send(client, @dest, req, destination: target, npci_id: target)
      end)

    assert_receive {:fake_transport_send, @dest, data, opts}
    assert opts[:destination] == target
    {:ok, %APDU.ConfirmedServiceRequest{invoke_id: 0}} = APDU.decode(data)
    sync(client)

    deliver(client, @dest, ApduFactory.simple_ack(0), transport, NPCI.new(source: target))
    assert {:ok, %APDU.SimpleACK{}} = Task.await(task)

    npci = NPCI.new(destination: %NpciTarget{net: 4, address: 9})

    task =
      Task.async(fn ->
        Client.send(client, @dest, req, npci: npci, destination: %NpciTarget{net: 99, address: 9})
      end)

    assert_receive {:fake_transport_send, @dest, data, _opts}
    {:ok, %APDU.ConfirmedServiceRequest{invoke_id: 0}} = APDU.decode(data)
    sync(client)

    deliver(
      client,
      @dest,
      ApduFactory.simple_ack(0),
      transport,
      NPCI.new(source: %NpciTarget{net: 4, address: 9})
    )

    assert {:ok, %APDU.SimpleACK{}} = Task.await(task)

    npci = NPCI.new(destination: %NpciTarget{net: 4, address: nil})

    task =
      Task.async(fn ->
        Client.send(client, @dest, req, npci: npci)
      end)

    assert_receive {:fake_transport_send, @dest, data, _opts}
    {:ok, %APDU.ConfirmedServiceRequest{invoke_id: 0}} = APDU.decode(data)
    sync(client)
    deliver(client, @dest, ApduFactory.simple_ack(0), transport)
    assert {:ok, %APDU.SimpleACK{}} = Task.await(task)
  end

  test "a response npci source falls back to the nil npci target timer", %{
    client: client,
    transport: transport
  } do
    task = Task.async(fn -> Client.send(client, @dest, ApduFactory.read_property()) end)
    assert_receive {:fake_transport_send, @dest, _data, _opts}
    sync(client)

    deliver(
      client,
      @dest,
      ApduFactory.simple_ack(0),
      transport,
      NPCI.new(source: %NpciTarget{net: 1, address: 9})
    )

    assert {:ok, %APDU.SimpleACK{}} = Task.await(task)
  end

  test "returning one invoke id while others are in flight keeps the queue", %{
    client: client,
    transport: transport
  } do
    first = Task.async(fn -> Client.send(client, @dest, ApduFactory.read_property()) end)
    assert_receive {:fake_transport_send, @dest, _, _}
    second = Task.async(fn -> Client.send(client, @dest, ApduFactory.read_property()) end)
    assert_receive {:fake_transport_send, @dest, _, _}
    sync(client)
    deliver(client, @dest, ApduFactory.simple_ack(0), transport)
    assert {:ok, %APDU.SimpleACK{invoke_id: 0}} = Task.await(first)
    deliver(client, @dest, ApduFactory.simple_ack(1), transport)
    assert {:ok, %APDU.SimpleACK{invoke_id: 1}} = Task.await(second)
  end

  test "the 257th confirmed send waits for a free invoke id", %{client: client} do
    tasks =
      for _request_index <- 1..256 do
        task = Task.async(fn -> Client.send(client, @dest, ApduFactory.read_property()) end)
        assert_receive {:fake_transport_send, @dest, _data, _opts}, 1_000
        task
      end

    overflow = Task.async(fn -> Client.send(client, @dest, ApduFactory.read_property()) end)
    sync(client)
    refute_receive {:fake_transport_send, @dest, _, _}, 50
    assert Process.alive?(overflow.pid)

    Enum.each(tasks, &Task.shutdown(&1, :brutal_kill))
    Task.shutdown(overflow, :brutal_kill)
  end

  test "timed out requests release invoke ids beyond the allocation capacity", %{
    client: client,
    transport: transport
  } do
    assert :ok = Client.configure(client, apdu_retries: 0)

    for _request_index <- 1..257 do
      task = Task.async(fn -> Client.send(client, @dest, ApduFactory.read_property()) end)
      assert_receive {:fake_transport_send, @dest, data, _opts}, 1_000
      assert {:ok, %APDU.ConfirmedServiceRequest{invoke_id: invoke_id}} = APDU.decode(data)

      send(client, {:apdu_timer, {@dest, nil, invoke_id}})
      assert {:error, :apdu_timeout} = Task.await(task)
    end

    task = Task.async(fn -> Client.send(client, @dest, ApduFactory.read_property()) end)
    assert_receive {:fake_transport_send, @dest, data, _opts}, 1_000
    assert {:ok, %APDU.ConfirmedServiceRequest{invoke_id: invoke_id}} = APDU.decode(data)
    deliver(client, @dest, ApduFactory.simple_ack(invoke_id), transport)
    assert {:ok, %APDU.SimpleACK{invoke_id: ^invoke_id}} = Task.await(task)
  end

  test "segmentator done rearms the apdu timer and the next tick times out", %{client: client} do
    task = Task.async(fn -> Client.send(client, @dest, ApduFactory.read_property()) end)
    assert_receive {:fake_transport_send, @dest, _, _}
    sync(client)

    send(client, {:done, {:apdu_timer_setup, {@dest, nil, 0}}})
    sync(client)
    send(client, {:apdu_timer, {@dest, nil, 0}})
    assert {:error, :apdu_timeout} = Task.await(task)
  end

  test "segmentator cancel drops the timer without answering", %{client: client} do
    task = Task.async(fn -> Client.send(client, @dest, ApduFactory.read_property()) end)
    assert_receive {:fake_transport_send, @dest, _, _}
    sync(client)
    send(client, {:cancelled, {:apdu_timer_setup, {@dest, nil, 0}}})
    sync(client)
    refute_receive {:fake_transport_send, _, _, _}, 20
    Task.shutdown(task, :brutal_kill)
    assert {FakeTransport, _transport, _portal} = Client.get_transport(client)
  end

  test "an unknown segmentator timer key is ignored", %{client: client, transport: transport} do
    send(client, {:done, {:apdu_timer_setup, {:missing, nil, 4}}})
    send(client, {:apdu_timer, {:missing, nil, 4}})
    assert {FakeTransport, ^transport, ^transport} = Client.get_transport(client)
  end

  test "resend failure retries the request and completes on a later response", %{
    client: client,
    transport: transport
  } do
    task = Task.async(fn -> Client.send(client, @dest, ApduFactory.read_property()) end)
    assert_receive {:fake_transport_send, @dest, original, _}

    attempts = :counters.new(1, [])

    assert :ok =
             FakeTransport.set_send_result(transport, fn @dest, _data, _opts ->
               :counters.add(attempts, 1, 1)
               if :counters.get(attempts, 1) == 1, do: {:error, :down}, else: :ok
             end)

    send(client, {:apdu_timer, {@dest, nil, 0}})
    assert_receive {:fake_transport_send, @dest, ^original, _}
    assert_receive {:fake_transport_send, @dest, ^original, _}
    sync(client)
    assert :counters.get(attempts, 1) == 2
    assert Process.alive?(task.pid)

    deliver(client, @dest, ApduFactory.simple_ack(0), transport)
    assert {:ok, %APDU.SimpleACK{invoke_id: 0}} = Task.await(task)
  end

  test "a consumed reply reference cannot answer a new request with the same invoke id", %{
    client: client,
    transport: transport
  } do
    old_ref = deliver_request(client, transport, 5)
    assert :ok = Client.reply(client, old_ref, ApduFactory.simple_ack(5))
    assert_received {:fake_transport_send, @dest, _, _}

    new_ref = deliver_request(client, transport, 5)
    assert new_ref != old_ref
    assert {:error, :app_timeout} = Client.reply(client, old_ref, ApduFactory.simple_ack(5))
    refute_received {:fake_transport_send, @dest, _, _}

    assert :ok = Client.reply(client, new_ref, ApduFactory.simple_ack(5))
    assert_received {:fake_transport_send, @dest, _, _}
  end

  test "reply to a forwarded npdu uses the originating address", %{
    client: client,
    transport: transport
  } do
    forwarded = %BvlcForwardedNPDU{originating_ip: {10, 1, 2, 3}, originating_port: 47_808}
    raw = IO.iodata_to_binary(EncoderProtocol.encode(ApduFactory.read_property(invoke_id: 6)))

    send(
      client,
      {:bacnet_transport, {:test, FakeTransport}, @dest,
       {:apdu, forwarded, NPCI.new(expects_reply: true), raw}, transport}
    )

    sync(client)

    assert_received {:bacnet_client, ref, %APDU.ConfirmedServiceRequest{invoke_id: 6}, _, ^client}
    assert :ok = Client.reply(client, ref, ApduFactory.simple_ack(6))
    assert_received {:fake_transport_send, {{10, 1, 2, 3}, 47_808}, _reply, _opts}
  end

  test "reply send failure keeps the request so a later reply can succeed", %{
    client: client,
    transport: transport
  } do
    ref = deliver_request(client, transport, 5)
    assert :ok = FakeTransport.set_send_result(transport, {:error, :busy})
    assert {:error, :busy} = Client.reply(client, ref, ApduFactory.simple_ack(5))
    assert :ok = FakeTransport.set_send_result(transport, :ok)
    assert :ok = Client.reply(client, ref, ApduFactory.simple_ack(5))
    assert_received {:fake_transport_send, @dest, reply, _opts}
    assert {:ok, %APDU.SimpleACK{invoke_id: 5}} = APDU.decode(reply)
  end

  test "unspecified max segments on the request becomes 2 for the reply", %{
    client: client,
    transport: transport
  } do
    request = %{
      ApduFactory.read_property(invoke_id: 4)
      | max_segments: :unspecified,
        max_apdu: 128
    }

    raw = IO.iodata_to_binary(EncoderProtocol.encode(request))

    send(
      client,
      {:bacnet_transport, {:test, FakeTransport}, @dest,
       {:apdu, :original_unicast, NPCI.new(expects_reply: true), raw}, transport}
    )

    sync(client)
    assert_received {:bacnet_client, ref, _, _, ^client}

    ack = %{large_ack() | payload: [{:octet_string, :binary.copy(<<7>>, 400)}]}
    assert {:error, :too_many_segments} = Client.reply(client, ref, ack)
    assert_received {:fake_transport_send, @dest, abort, _opts}
    assert %APDU.Abort{reason: :buffer_overflow} = abort
  end

  test "reply timer sends abort and a later reply is an app timeout", %{
    client: client,
    transport: transport
  } do
    _ref = deliver_request(client, transport, 7)
    send(client, {:reply_timer, {@dest, nil, 7}})
    assert_receive {:fake_transport_send, @dest, abort, _opts}
    assert {:ok, %APDU.Abort{reason: :application_exceeded_reply_time}} = APDU.decode(abort)
    assert {:error, :app_timeout} = Client.reply(client, make_ref(), ApduFactory.simple_ack(7))
  end

  test "reply timer send failure retries once", %{client: client, transport: transport} do
    ref = deliver_request(client, transport, 8)
    assert :ok = FakeTransport.set_send_result(transport, {:error, :down})
    send(client, {:reply_timer, {@dest, nil, 8}})
    sync(client)
    send(client, {:reply_timer, {@dest, nil, 8}})
    sync(client)
    assert :ok = FakeTransport.set_send_result(transport, :ok)
    assert {:error, :app_timeout} = Client.reply(client, ref, ApduFactory.simple_ack(8))
  end

  test "an unknown reply timer key is ignored", %{client: client, transport: transport} do
    send(client, {:reply_timer, {:missing, nil, 1}})
    assert {FakeTransport, ^transport, ^transport} = Client.get_transport(client)
  end

  test "duplicate confirmed requests are delivered once", %{client: client, transport: transport} do
    raw = IO.iodata_to_binary(EncoderProtocol.encode(ApduFactory.read_property(invoke_id: 3)))

    frame =
      {:bacnet_transport, {:test, FakeTransport}, @dest,
       {:apdu, :original_unicast,
        NPCI.new(expects_reply: true, source: %NpciTarget{net: 2, address: 15}), raw}, transport}

    send(client, frame)
    send(client, frame)
    sync(client)

    assert_received {:bacnet_client, ref, %APDU.ConfirmedServiceRequest{invoke_id: 3}, _, ^client}
    refute_received {:bacnet_client, _, _, _, _}
    assert :ok = Client.reply(client, ref, ApduFactory.simple_ack(3))
  end

  test "per-source timeout is selected for the matching npci target", %{
    client: client,
    transport: transport
  } do
    assert :ok = Client.add_apdu_timeout(client, @dest, %NpciTarget{net: 2, address: 15}, 1)
    raw = IO.iodata_to_binary(EncoderProtocol.encode(ApduFactory.read_property(invoke_id: 2)))

    send(
      client,
      {:bacnet_transport, {:test, FakeTransport}, @dest,
       {:apdu, :original_unicast,
        NPCI.new(expects_reply: true, source: %NpciTarget{net: 2, address: 15}), raw}, transport}
    )

    sync(client)
    assert_received {:bacnet_client, _ref, %APDU.ConfirmedServiceRequest{}, _, ^client}
    assert_receive {:fake_transport_send, @dest, abort, _opts}, 1_000
    assert {:ok, %APDU.Abort{reason: :application_exceeded_reply_time}} = APDU.decode(abort)

    assert :ok = Client.add_apdu_timeout(client, :other, nil, 60_000)
    assert :ok = Client.add_apdu_timeout(client, @dest, nil, 1)

    send(
      client,
      {:bacnet_transport, {:test, FakeTransport}, @dest,
       {:apdu, :original_unicast,
        NPCI.new(expects_reply: true, source: %NpciTarget{net: 2, address: 21}), raw}, transport}
    )

    sync(client)

    assert_received {:bacnet_client, _ref, %APDU.ConfirmedServiceRequest{invoke_id: 2}, _,
                     ^client}

    assert_receive {:fake_transport_send, @dest, fallback_abort, _opts}, 1_000

    assert {:ok, %APDU.Abort{reason: :application_exceeded_reply_time}} =
             APDU.decode(fallback_abort)
  end

  test "incoming requests distinguish networks while deduplicating the same complete target", %{
    client: client,
    transport: transport
  } do
    target_a = %NpciTarget{net: 10, address: 7}
    target_b = %NpciTarget{net: 20, address: 7}
    request = ApduFactory.read_property(invoke_id: 3)

    for target <- [target_a, target_b, target_a] do
      deliver(client, @dest, request, transport, NPCI.new(expects_reply: true, source: target))
    end

    sync(client)

    assert_received {:bacnet_client, ref_a, %APDU.ConfirmedServiceRequest{invoke_id: 3},
                     {@dest, _, %NPCI{source: ^target_a}}, ^client}

    assert_received {:bacnet_client, ref_b, %APDU.ConfirmedServiceRequest{invoke_id: 3},
                     {@dest, _, %NPCI{source: ^target_b}}, ^client}

    assert ref_a != ref_b
    refute_received {:bacnet_client, _, _, _, _}

    for {ref, target} <- [{ref_a, target_a}, {ref_b, target_b}] do
      assert :ok = Client.reply(client, ref, ApduFactory.simple_ack(3))
      assert_received {:fake_transport_send, @dest, reply, opts}
      assert {:ok, %APDU.SimpleACK{invoke_id: 3}} = APDU.decode(reply)
      assert opts[:destination] == target
    end
  end

  test "an exact network timeout overrides the generic fallback without affecting another network",
       %{
         client: client,
         transport: transport
       } do
    target_a = %NpciTarget{net: 10, address: 7}
    target_b = %NpciTarget{net: 20, address: 7}
    assert :ok = Client.add_apdu_timeout(client, @dest, nil, 60_000)
    assert :ok = Client.add_apdu_timeout(client, @dest, target_a, 1)
    request = ApduFactory.read_property(invoke_id: 3)

    deliver(client, @dest, request, transport, NPCI.new(expects_reply: true, source: target_a))
    sync(client)
    assert_received {:bacnet_client, _, %APDU.ConfirmedServiceRequest{}, _, ^client}
    assert_receive {:fake_transport_send, @dest, abort, opts}, 1_000
    assert {:ok, %APDU.Abort{reason: :application_exceeded_reply_time}} = APDU.decode(abort)
    assert opts[:destination] == target_a

    deliver(client, @dest, request, transport, NPCI.new(expects_reply: true, source: target_b))
    sync(client)
    assert_received {:bacnet_client, ref, %APDU.ConfirmedServiceRequest{}, _, ^client}
    assert :ok = Client.reply(client, ref, ApduFactory.simple_ack(3))
    assert_received {:fake_transport_send, @dest, reply, opts}
    assert {:ok, %APDU.SimpleACK{}} = APDU.decode(reply)
    assert opts[:destination] == target_b
  end

  test "a routed request timeout releases its target's invoke id", %{
    client: client,
    transport: transport
  } do
    target = %NpciTarget{net: 10, address: 7}
    assert :ok = Client.configure(client, apdu_retries: 0)

    task =
      Task.async(fn ->
        Client.send(client, @dest, ApduFactory.read_property(),
          destination: target,
          npci_id: target
        )
      end)

    assert_receive {:fake_transport_send, @dest, data, _opts}
    assert {:ok, %APDU.ConfirmedServiceRequest{invoke_id: 0}} = APDU.decode(data)
    send(client, {:apdu_timer, {@dest, target, 0}})
    assert {:error, :apdu_timeout} = Task.await(task)

    task =
      Task.async(fn ->
        Client.send(client, @dest, ApduFactory.read_property(),
          destination: target,
          npci_id: target
        )
      end)

    assert_receive {:fake_transport_send, @dest, data, _opts}
    assert {:ok, %APDU.ConfirmedServiceRequest{invoke_id: 0}} = APDU.decode(data)
    deliver(client, @dest, ApduFactory.simple_ack(0), transport, NPCI.new(source: target))
    assert {:ok, %APDU.SimpleACK{invoke_id: 0}} = Task.await(task)
  end

  test "abort, error, and reject with no in-flight request are delivered", %{
    client: client,
    transport: transport
  } do
    deliver(client, @dest, ApduFactory.abort(1), transport)
    deliver(client, @dest, ApduFactory.reject(1), transport)

    deliver(
      client,
      @dest,
      %APDU.Error{
        invoke_id: 1,
        service: :read_property,
        class: :device,
        code: :operational_problem,
        payload: []
      },
      transport
    )

    sync(client)
    assert_received {:bacnet_client, nil, %APDU.Abort{}, _, ^client}
    assert_received {:bacnet_client, nil, %APDU.Reject{}, _, ^client}
    assert_received {:bacnet_client, nil, %APDU.Error{}, _, ^client}

    deliver(
      client,
      @dest,
      ApduFactory.simple_ack(4),
      transport,
      NPCI.new(source: %NpciTarget{net: 2, address: 15})
    )

    sync(client)
    assert_received {:bacnet_client, nil, %APDU.SimpleACK{invoke_id: 4}, _, ^client}
  end

  test "segment ack for an unknown sequence is ignored", %{client: client, transport: transport} do
    deliver(client, @dest, ApduFactory.segment_ack(4), transport)
    refute_receive {:bacnet_client, _, _, _, _}, 30
    assert {FakeTransport, ^transport, ^transport} = Client.get_transport(client)
  end

  test "a segmented confirmed request is joined and then dropped", %{
    client: client,
    transport: transport
  } do
    segments = segmented_request()
    assert length(segments) > 1

    for segment <- segments do
      send(client, incoming(transport, segment))
      sync(client)
    end

    assert_receive {:fake_transport_send, @dest,
                    %APDU.SegmentACK{invoke_id: 9, sequence_number: 0}, _opts}

    assert_receive {:fake_transport_send, @dest,
                    %APDU.SegmentACK{invoke_id: 9, sequence_number: last}, _opts}

    assert last == length(segments) - 1
    refute_receive {:bacnet_client, _, _, _, _}, 30
    assert {FakeTransport, ^transport, ^transport} = Client.get_transport(client)
  end

  test "a segmented complex ack is reassembled and completes the request", %{
    client: client,
    transport: transport
  } do
    task = Task.async(fn -> Client.send(client, @dest, ApduFactory.read_property()) end)
    assert_receive {:fake_transport_send, @dest, request, _opts}
    assert {:ok, %APDU.ConfirmedServiceRequest{invoke_id: 0}} = APDU.decode(request)
    sync(client)

    for segment <- segmented_complex_ack(0) do
      send(client, incoming(transport, segment))
      sync(client)
    end

    assert {:ok,
            %APDU.ComplexACK{
              invoke_id: 0,
              service: :read_property,
              payload: [
                unsigned_integer: 1,
                unsigned_integer: 2,
                unsigned_integer: 3,
                octet_string: "\t\t\t\t\t\t\t\t\t\t\t\t"
              ]
            }} = Task.await(task)

    target = %NpciTarget{net: 2, address: 15}

    task =
      Task.async(fn ->
        Client.send(client, @dest, ApduFactory.read_property(), destination: target)
      end)

    assert_receive {:fake_transport_send, @dest, request, _opts} when is_binary(request)
    assert {:ok, %APDU.ConfirmedServiceRequest{invoke_id: 0}} = APDU.decode(request)
    sync(client)

    for segment <- segmented_complex_ack(0) do
      send(client, incoming(transport, segment, NPCI.new(source: target)))
      sync(client)
    end

    assert {:ok, %APDU.ComplexACK{invoke_id: 0, service: :read_property}} = Task.await(task)
  end

  test "a segmented request while a confirmed send is open refreshes the apdu timer", %{
    client: client,
    transport: transport
  } do
    task = Task.async(fn -> Client.send(client, @dest, ApduFactory.read_property()) end)
    assert_receive {:fake_transport_send, @dest, _, _}
    sync(client)

    send(client, incoming(transport, hd(segmented_request())))
    sync(client)
    deliver(client, @dest, ApduFactory.simple_ack(0), transport)
    assert {:ok, %APDU.SimpleACK{}} = Task.await(task)
  end

  test "routed segmented receives are stored with window size 1", %{
    client: client,
    transport: transport
  } do
    assert :ok = Client.configure(client, segmented_rcv_window_overwrite: true)
    [first | _remaining_segments] = segmented_request(window: 4)
    source = {:routed, @dest}

    send(
      client,
      {:bacnet_transport, {:test, FakeTransport}, source,
       {:apdu, :original_unicast, NPCI.new([]), IO.iodata_to_binary(first)}, transport}
    )

    sync(client)

    assert_received {:fake_transport_send, ^source, %APDU.SegmentACK{actual_window_size: 1},
                     _opts}
  end

  test "a segmented sequence that the store rejects is not delivered", %{
    client: client,
    transport: transport
  } do
    segments = segmented_request()
    send(client, incoming(transport, List.last(segments)))
    sync(client)

    assert_received {:fake_transport_send, @dest,
                     %APDU.Abort{reason: :invalid_apdu_in_this_state}, _opts}

    refute_receive {:bacnet_client, _, _, _, _}, 30
  end

  test "invalid apdu data is dropped", %{client: client, transport: transport} do
    send(client, incoming(transport, <<0xF0, 0x00>>))
    refute_receive {:bacnet_client, _, _, _, _}, 30
    refute_received {:fake_transport_send, _, _, _}
    assert {FakeTransport, ^transport, ^transport} = Client.get_transport(client)
  end

  test "no listener reject is skipped when the transport send fails", %{
    transport: transport,
    segmentator: segmentator,
    store: store
  } do
    assert :ok = FakeTransport.set_send_result(transport, {:error, :down})

    {:ok, client} =
      Client.start_link(
        transport: {FakeTransport, transport},
        segmentator: segmentator,
        segments_store: store,
        apdu_timeout: 60_000
      )

    raw = IO.iodata_to_binary(EncoderProtocol.encode(ApduFactory.read_property(invoke_id: 1)))
    send(client, incoming(transport, raw, NPCI.new(expects_reply: true)))
    sync(client)
    assert {FakeTransport, ^transport, ^transport} = Client.get_transport(client)
    assert_receive {:fake_transport_send, @dest, _failed_reject, failed_opts}
    assert failed_opts[:destination] == nil

    assert :ok = FakeTransport.set_send_result(transport, :ok)
    source = %NpciTarget{net: 2, address: 15}

    send(
      client,
      incoming(transport, raw, NPCI.new(expects_reply: true, source: source))
    )

    sync(client)
    assert_received {:fake_transport_send, @dest, reject, opts}
    assert {:ok, %APDU.Reject{invoke_id: 1, reason: :other}} = APDU.decode(reject)
    assert opts[:destination] == source
  end

  test "a 50-byte peer APDU limit includes segment headers without routing", %{
    client: client,
    transport: transport
  } do
    assert :ok =
             Client.send(client, @dest, large_ack(),
               max_apdu_length: 50,
               max_segments: 16,
               segmentation_supported: :segmented_both
             )

    segments = collect_outgoing_segments(client, transport)
    assert length(segments) == 2
    assert Enum.max(Enum.map(segments, &IO.iodata_length/1)) == 50
    assert Enum.all?(segments, &(IO.iodata_length(&1) <= 50))
  end

  test "a 50-byte peer APDU limit includes segment headers with routing", %{
    client: client,
    transport: transport
  } do
    assert :ok =
             Client.send(client, @dest, large_ack(),
               source: %NpciTarget{net: 1, address: 1},
               destination: %NpciTarget{net: 2, address: 2},
               max_apdu_length: 50,
               max_segments: 16,
               segmentation_supported: :segmented_both
             )

    segments = collect_outgoing_segments(client, transport)
    assert length(segments) == 2
    assert Enum.max(Enum.map(segments, &IO.iodata_length/1)) == 50
    assert Enum.all?(segments, &(IO.iodata_length(&1) <= 50))
  end

  test "an APDU exactly at the peer limit stays unsegmented", %{client: client} do
    ack = ApduFactory.complex_ack(0, octet_string: :binary.copy(<<7>>, 45))
    assert :ok = Client.send(client, @dest, ack, max_apdu_length: 50)
    assert_receive {:fake_transport_send, @dest, bytes, _opts}
    assert IO.iodata_length(bytes) == 50
    assert {:ok, ^ack} = APDU.decode(IO.iodata_to_binary(bytes))
  end

  defp collect_outgoing_segments(client, transport, next_sequence \\ 0) do
    assert_receive {:fake_transport_send, @dest, bytes, _opts}, 1_000
    assert {:incomplete, segment} = APDU.decode(IO.iodata_to_binary(bytes))
    assert segment.sequence_number == next_sequence

    deliver(
      client,
      @dest,
      ApduFactory.segment_ack(segment.invoke_id,
        sequence_number: next_sequence,
        actual_window_size: 1
      ),
      transport
    )

    if segment.more_follows do
      [bytes | collect_outgoing_segments(client, transport, next_sequence + 1)]
    else
      sync(client)
      [bytes]
    end
  end

  defp long_confirmed_request() do
    {:ok, value} = Encoding.create({:octet_string, :binary.copy(<<7>>, 80)})

    {:ok, request} =
      WriteProperty.to_apdu(
        %WriteProperty{
          object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1},
          property_identifier: :present_value,
          property_array_index: nil,
          property_value: value,
          priority: nil
        },
        []
      )

    request
  end

  defp large_ack() do
    %{
      ApduFactory.complex_ack(1)
      | payload: [{:octet_string, :binary.copy(<<7>>, 80)}],
        sequence_number: 0,
        proposed_window_size: 4
    }
  end

  defp segmented_complex_ack(invoke_id) do
    ack = %{
      ApduFactory.complex_ack(invoke_id, [
        {:unsigned_integer, 1},
        {:unsigned_integer, 2},
        {:unsigned_integer, 3},
        {:octet_string, :binary.copy(<<9>>, 12)}
      ])
      | sequence_number: 0,
        proposed_window_size: 1
    }

    EncoderProtocol.encode_segmented(ack, 9)
  end

  defp segmented_request(opts \\ []) do
    window = Keyword.get(opts, :window, 1)

    request = %{
      ApduFactory.read_property(invoke_id: 9)
      | sequence_number: 0,
        proposed_window_size: window,
        parameters: ApduFactory.read_property().parameters
    }

    EncoderProtocol.encode_segmented(request, 12)
  end

  defp incoming(portal, raw, npci \\ NPCI.new([])) do
    {:bacnet_transport, {:test, FakeTransport}, @dest,
     {:apdu, :original_unicast, npci, IO.iodata_to_binary(raw)}, portal}
  end

  defp deliver(client, source, apdu, portal, npci \\ NPCI.new([])) do
    send(client, incoming_from(portal, source, EncoderProtocol.encode(apdu), npci))
  end

  defp incoming_from(portal, source, raw, npci) do
    {:bacnet_transport, {:bacnet_ipv4, FakeTransport}, source,
     {:apdu, :original_unicast, npci, IO.iodata_to_binary(raw)}, portal}
  end

  defp deliver_request(client, portal, invoke_id) do
    raw =
      IO.iodata_to_binary(EncoderProtocol.encode(ApduFactory.read_property(invoke_id: invoke_id)))

    send(
      client,
      {:bacnet_transport, {:test, FakeTransport}, @dest,
       {:apdu, :original_unicast, NPCI.new(expects_reply: true), raw}, portal}
    )

    sync(client)

    assert_received {:bacnet_client, ref, %APDU.ConfirmedServiceRequest{invoke_id: ^invoke_id}, _,
                     ^client}

    ref
  end

  # The client handles incoming frames and sends notifications in its own process.
  # A call from the frame sender is a barrier before inspecting the test mailbox.
  defp sync(client), do: Client.get_transport(client)
end
