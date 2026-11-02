defmodule BACnet.Stack.SegmentationRolesTest do
  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.NPCI
  alias BACnet.Protocol.NpciTarget
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.WriteProperty
  alias BACnet.Stack.Client
  alias BACnet.Stack.EncoderProtocol
  alias BACnet.Stack.SegmentationEndpoint
  alias BACnet.Stack.Segmentator
  alias BACnet.Stack.SegmentsStore
  alias BACnet.Test.Stack.ApduFactory
  alias BACnet.Test.Stack.FakeTransport

  use BACnet.Test.Stack.Case, async: true

  @moduletag :stack
  @peer :peer

  setup do
    transport = start_supervised!({FakeTransport, owner: self()})
    sender = start_supervised!({Segmentator, apdu_timeout: 60_000, apdu_retries: 0})
    store = start_supervised!({SegmentsStore, apdu_timeout: 60_000})

    client =
      start_supervised!(
        {Client,
         transport: {FakeTransport, transport},
         segmentator: sender,
         segments_store: store,
         notification_receiver: self(),
         apdu_timeout: 60_000}
      )

    target = %NpciTarget{net: 10, address: 7}
    endpoint = SegmentationEndpoint.new(FakeTransport, transport, @peer, destination: target)

    %{
      client: client,
      transport: transport,
      sender: sender,
      store: store,
      target: target,
      endpoint: endpoint
    }
  end

  test "a client sends both roles concurrently and completion callbacks affect only the requester",
       context do
    for first_role <- [:requester, :responder] do
      {task, invoke_id} = open_role_pair(context)
      requester_key = {@peer, context.target, invoke_id}
      timer = :sys.get_state(context.client).apdu_timers[requester_key]
      assert timer.timer == nil

      for role <- [first_role] ++ ([:requester, :responder] -- [first_role]) do
        before = :sys.get_state(context.client).apdu_timers[requester_key]
        finish_role(context, role, invoke_id)
        after_completion = :sys.get_state(context.client).apdu_timers[requester_key]

        if role == :responder do
          assert after_completion == before
        else
          assert is_reference(after_completion.timer)
        end
      end

      deliver(context, ApduFactory.simple_ack(invoke_id, :write_property))
      assert {:ok, %APDU.SimpleACK{invoke_id: ^invoke_id}} = Task.await(task)
      assert :sys.get_state(context.sender).sequences == %{}
      assert :sys.get_state(context.client).apdu_timers == %{}
    end
  end

  test "responses retain the peer's invoke ID without consuming a local request ID", context do
    for response <- [ApduFactory.simple_ack(37), ApduFactory.complex_ack(37)] do
      before = :sys.get_state(context.client).free_invoke_ids
      assert :ok = Client.send(context.client, @peer, response, destination: context.target)
      assert_receive {:fake_transport_send, @peer, raw, _opts}
      assert {:ok, %{invoke_id: 37}} = APDU.decode(raw)
      assert :sys.get_state(context.client).free_invoke_ids == before
    end
  end

  test "direct Client.send preserves response invoke IDs with automatic and manual request IDs",
       context do
    for disabled <- [false, true] do
      client =
        start_supervised!(
          {Client,
           transport: {FakeTransport, context.transport},
           segmentator: context.sender,
           segments_store: context.store,
           notification_receiver: self(),
           apdu_timeout: 60_000,
           disable_invoke_id_management: disabled},
          id: {:direct_client, disabled}
        )

      current = %{context | client: client}

      task =
        Task.async(fn ->
          Client.send(client, @peer, %{long_request() | invoke_id: 29},
            destination: context.target,
            npci_id: context.target,
            max_apdu_length: 50,
            max_segments: 16,
            segmentation_supported: :segmented_both
          )
        end)

      assert_receive {:fake_transport_send, @peer, raw, _opts}
      assert {:incomplete, %{invoke_id: invoke_id}} = APDU.decode(IO.iodata_to_binary(raw))
      assert invoke_id == if(disabled, do: 29, else: 0)
      sync(client)
      state = :sys.get_state(client)

      response = %{
        ApduFactory.complex_ack(invoke_id, octet_string: :binary.copy(<<9>>, 80))
        | sequence_number: 0,
          proposed_window_size: 1
      }

      assert :ok =
               Client.send(client, @peer, response,
                 destination: context.target,
                 max_apdu_length: 50,
                 max_segments: 16,
                 segmentation_supported: :segmented_both
               )

      assert_receive {:fake_transport_send, @peer, raw, _opts}

      assert {:incomplete, %{invoke_id: ^invoke_id, server: false}} =
               APDU.decode(IO.iodata_to_binary(raw))

      assert :sys.get_state(client).free_invoke_ids == state.free_invoke_ids
      assert :sys.get_state(client).apdu_timers == state.apdu_timers

      # Unsegmented responses retain the peer's invoke ID and bypass requester duplicate detection too.
      assert :ok =
               Client.send(client, @peer, ApduFactory.simple_ack(invoke_id),
                 destination: context.target
               )

      assert_receive {:fake_transport_send, @peer, raw, _opts}
      assert {:ok, %APDU.SimpleACK{invoke_id: ^invoke_id}} = APDU.decode(raw)
      finish_role(current, :responder, invoke_id)
      assert :sys.get_state(client).apdu_timers == state.apdu_timers
      finish_role(current, :requester, invoke_id)
      deliver(current, ApduFactory.simple_ack(invoke_id, :write_property))
      assert {:ok, %APDU.SimpleACK{}} = Task.await(task)
    end
  end

  test "a responder timeout or client Abort cannot finish an outgoing requester transaction",
       context do
    for termination <- [:timeout, :abort] do
      {task, invoke_id} = open_role_pair(context)
      timers = :sys.get_state(context.client).apdu_timers
      requester_id = {context.endpoint, :requester, invoke_id}
      requester = :sys.get_state(context.sender).sequences[requester_id]

      case termination do
        :timeout ->
          send(context.sender, {:timer, {context.endpoint, :responder, invoke_id}})
          assert :ok = Segmentator.configure(context.sender, [])
          sync(context.client)

        :abort ->
          deliver(context, %{ApduFactory.abort(invoke_id) | sent_by_server: false})
      end

      assert :sys.get_state(context.client).apdu_timers == timers
      assert :sys.get_state(context.sender).sequences == %{requester_id => requester}
      finish_role(context, :requester, invoke_id)
      deliver(context, ApduFactory.simple_ack(invoke_id, :write_property))
      assert {:ok, %APDU.SimpleACK{invoke_id: ^invoke_id}} = Task.await(task)
    end
  end

  test "incoming request segments do not refresh a requester timer while response segments do",
       context do
    task =
      Task.async(fn ->
        Client.send(context.client, @peer, ApduFactory.read_property(),
          destination: context.target,
          npci_id: context.target
        )
      end)

    assert_receive {:fake_transport_send, @peer, raw, _opts}
    assert {:ok, %{invoke_id: invoke_id}} = APDU.decode(raw)
    sync(context.client)
    key = {@peer, context.target, invoke_id}
    original = :sys.get_state(context.client).apdu_timers[key].timer

    request = %{
      long_request()
      | invoke_id: invoke_id,
        sequence_number: 0,
        proposed_window_size: 1
    }

    response = %{
      ApduFactory.complex_ack(invoke_id, octet_string: :binary.copy(<<9>>, 80))
      | sequence_number: 0,
        proposed_window_size: 1
    }

    [request_first | request_rest] = EncoderProtocol.encode_segmented(request, 50)
    [response_first | response_rest] = EncoderProtocol.encode_segmented(response, 50)

    deliver_raw(context, request_first, true)
    assert :sys.get_state(context.client).apdu_timers[key].timer == original
    deliver_raw(context, response_first)
    assert :sys.get_state(context.client).apdu_timers[key].timer != original
    assert map_size(:sys.get_state(context.store).sequences) == 2

    for index <- 0..(max(length(request_rest), length(response_rest)) - 1) do
      for raw <- List.wrap(Enum.at(request_rest, index)), do: deliver_raw(context, raw, true)
      for raw <- List.wrap(Enum.at(response_rest, index)), do: deliver_raw(context, raw)
    end

    assert {:ok, %APDU.ComplexACK{invoke_id: ^invoke_id}} = Task.await(task)

    assert_receive {:bacnet_client, ref, %APDU.ConfirmedServiceRequest{invoke_id: ^invoke_id}, _,
                    _client}

    assert is_reference(ref)
    assert :sys.get_state(context.store).sequences == %{}

    assert :ok =
             Client.reply(context.client, ref, ApduFactory.simple_ack(invoke_id, :write_property))
  end

  test "client Abort releases only the matching pending responder reply, including without subscribers",
       context do
    other_portal = start_supervised!({FakeTransport, owner: self()}, id: :other_portal)

    for disabled <- [false, true] do
      assert :ok = Client.configure(context.client, disable_app_timeout: disabled)
      deliver(context, ApduFactory.read_property(invoke_id: 19), true)

      assert_receive {:bacnet_client, ref, %APDU.ConfirmedServiceRequest{invoke_id: 19}, _,
                      _client}

      key = {@peer, context.target, 19}
      reply = :sys.get_state(context.client).app_reply_timers[key]
      abort = %{ApduFactory.abort(19) | sent_by_server: false}
      # Another portal's client Abort must not invalidate this reply reference.
      deliver(%{context | transport: other_portal}, abort)
      assert :sys.get_state(context.client).app_reply_timers[key] == reply
      assert :ok = Client.unsubscribe(context.client, self())
      deliver(context, abort)
      state = :sys.get_state(context.client)
      assert state.app_reply_timers == %{}
      assert state.app_reply_mapping == %{}
      if reply.timer, do: assert(Process.read_timer(reply.timer) == false)

      assert {:error, :app_timeout} =
               Client.reply(context.client, ref, ApduFactory.simple_ack(19))

      assert :ok = Client.subscribe(context.client, self())
    end
  end

  defp open_role_pair(context) do
    task =
      Task.async(fn ->
        Client.send(context.client, @peer, long_request(),
          destination: context.target,
          npci_id: context.target,
          segmentation_supported: :segmented_both,
          max_apdu_length: 50,
          max_segments: 16
        )
      end)

    assert_receive {:fake_transport_send, @peer, first, _opts}
    assert {:incomplete, %{invoke_id: invoke_id}} = APDU.decode(IO.iodata_to_binary(first))

    incoming = %{
      ApduFactory.read_property(invoke_id: invoke_id)
      | max_apdu: 50,
        max_segments: 16,
        segmented_response_accepted: true
    }

    deliver(context, incoming, true)
    assert_receive {:bacnet_client, ref, %APDU.ConfirmedServiceRequest{}, _, _client}

    response = %{
      ApduFactory.complex_ack(invoke_id, octet_string: :binary.copy(<<9>>, 80))
      | sequence_number: 0,
        proposed_window_size: 1
    }

    assert :ok = Client.reply(context.client, ref, response)
    assert_receive {:fake_transport_send, @peer, first, _opts}

    assert {:incomplete, %{invoke_id: ^invoke_id, server: false}} =
             APDU.decode(IO.iodata_to_binary(first))

    sequences = :sys.get_state(context.sender).sequences

    for role <- [:requester, :responder] do
      assert sequences[{context.endpoint, role, invoke_id}].callback_msg ==
               {:apdu_timer_setup, context.endpoint, role, {@peer, context.target, invoke_id}}
    end

    {task, invoke_id}
  end

  defp finish_role(context, role, invoke_id) do
    id = {context.endpoint, role, invoke_id}
    sequences = :sys.get_state(context.sender).sequences
    last = map_size(sequences[id].segments) - 1
    other = Map.delete(sequences, id)

    for number <- 0..last do
      deliver(
        context,
        ApduFactory.segment_ack(invoke_id,
          sent_by_server: role == :requester,
          sequence_number: number,
          actual_window_size: 1
        )
      )

      assert Map.delete(:sys.get_state(context.sender).sequences, id) == other

      if number < last do
        assert_receive {:fake_transport_send, @peer, raw, _opts}
        assert {:incomplete, segment} = APDU.decode(IO.iodata_to_binary(raw))
        assert segment.sequence_number == number + 1
        assert segment.server == (role == :requester)
      end
    end

    refute Map.has_key?(:sys.get_state(context.sender).sequences, id)
    :ok
  end

  defp deliver(context, apdu, expects_reply \\ false) do
    deliver_raw(context, EncoderProtocol.encode(apdu), expects_reply)
  end

  defp deliver_raw(context, raw, expects_reply \\ false) do
    send(
      context.client,
      {:bacnet_transport, {:test, FakeTransport}, @peer,
       {:apdu, :original_unicast, NPCI.new(source: context.target, expects_reply: expects_reply),
        IO.iodata_to_binary(raw)}, context.transport}
    )

    sync(context.client)
  end

  defp sync(client) do
    Client.get_transport(client)
    Client.get_transport(client)
  end

  defp long_request() do
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
end
