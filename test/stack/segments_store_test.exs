defmodule BACnet.Stack.SegmentsStoreTest do
  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.IncompleteAPDU
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.WriteProperty
  alias BACnet.Stack.EncoderProtocol
  alias BACnet.Stack.SegmentsStore
  alias BACnet.Test.Stack.ApduFactory
  alias BACnet.Test.Stack.FakeTransport

  use ExUnit.Case, async: true

  @moduletag :stack
  @moduletag :segments_store

  @dest :peer
  @segment_payload_size 50

  setup do
    {:ok, transport} = FakeTransport.start_link()

    {:ok, store} =
      SegmentsStore.start_link(apdu_timeout: 60_000, apdu_retries: 1, max_segments: :more_than_64)

    %{transport: transport, store: store}
  end

  test "start_link and configure reject bad options" do
    assert_raise ArgumentError, ~r/keyword list/, fn ->
      SegmentsStore.start_link(%{})
    end

    assert_raise ArgumentError, ~r/apdu_retries/, fn ->
      SegmentsStore.start_link(apdu_retries: :no)
    end

    assert_raise ArgumentError, ~r/apdu_timeout/, fn ->
      SegmentsStore.start_link(apdu_timeout: :no)
    end

    for bad <- [1, 3, 65, :nope] do
      assert_raise ArgumentError, ~r/max_segments/, fn ->
        SegmentsStore.start_link(max_segments: bad)
      end
    end

    for good <- [2, 4, 8, 16, 32, 64, :more_than_64, :unspecified] do
      assert {:ok, _store} = SegmentsStore.start_link(max_segments: good, apdu_timeout: 60_000)
    end

    {:ok, store} = SegmentsStore.start_link(max_segments: 64, apdu_timeout: 60_000)

    assert :ok = SegmentsStore.configure(store, apdu_timeout: 60_000, max_segments: :unspecified)

    assert_raise ArgumentError, ~r/keyword list/, fn ->
      SegmentsStore.configure(store, [1])
    end

    assert_raise ArgumentError, ~r/apdu_timeout/, fn ->
      SegmentsStore.configure(store, apdu_timeout: :no)
    end

    assert_raise ArgumentError, ~r/max_segments/, fn ->
      SegmentsStore.configure(store, max_segments: 3)
    end

    assert_raise ArgumentError, ~r/does not support option :apdu_retries/, fn ->
      SegmentsStore.configure(store, apdu_retries: 1)
    end

    assert_raise ArgumentError, ~r/does not support option :transport/, fn ->
      SegmentsStore.configure(store, transport: self())
    end
  end

  test "a registered name is the server", %{transport: transport} do
    name = :"segments_store_#{System.unique_integer([:positive])}"
    {:ok, pid} = SegmentsStore.start_link(name: name, apdu_timeout: 60_000, apdu_retries: 1)
    assert Process.whereis(name) == pid

    [first | _remaining_segments] = pieces(:request, 1, 1, 80)
    assert :incomplete = SegmentsStore.segment(name, first, FakeTransport, transport, @dest)
    assert_ack(@dest, 1, 0, 1, true)
  end

  test "the first segment is acknowledged and the original send options are kept", %{
    store: store,
    transport: transport
  } do
    [first, last] = pieces(:ack, 2, 1, 80)
    assert first.server == false

    assert :incomplete = feed(store, transport, first, track: :first)
    assert [track: :first] == assert_ack(@dest, 2, 0, 1, false)
    timer = :sys.get_state(store).sequences[{@dest, 2}].timer

    assert {:ok, binary} = feed(store, transport, last, track: :later)
    assert Process.read_timer(timer) == false
    assert [track: :first] == assert_ack(@dest, 2, 1, 1, false)
    assert binary == joined([first, last])

    assert {:ok,
            %APDU.ComplexACK{
              invoke_id: 2,
              service: :read_property,
              payload: [octet_string: payload]
            }} = APDU.decode(binary)

    assert payload == :binary.copy(<<9>>, 80)
  end

  test "segment/5 sends the initial ack with empty options", %{store: store, transport: transport} do
    [first | _remaining_segments] = pieces(:request, 3, 4, 200)
    assert :incomplete = SegmentsStore.segment(store, first, FakeTransport, transport, @dest)
    assert [] == assert_ack(@dest, 3, 0, 4, true)
  end

  test "an invalid destination is rejected before a sequence is created", %{
    store: store,
    transport: transport
  } do
    [first | _remaining_segments] = pieces(:request, 4, 1, 80)

    assert {:error, :invalid_source_address, true} =
             SegmentsStore.segment(store, first, FakeTransport, transport, :invalid)

    refute_received {:fake_transport_send, _, _, _}

    assert_raise ArgumentError, "bad dest", fn ->
      SegmentsStore.segment(store, first, FakeTransport, transport, {:raise_valid, "bad dest"})
    end
  end

  test "a proposed window outside 1..127 aborts", %{store: store, transport: transport} do
    [first | _remaining_segments] = pieces(:request, 5, 1, 80)

    assert {:error, :invalid_proposed_window_size, true} =
             feed(store, transport, %{first | window_size: 0})

    assert_abort(@dest, 5, :window_size_out_of_range, true)

    [again | _remaining_segments] = pieces(:ack, 6, 1, 80)

    assert {:error, :invalid_proposed_window_size, true} =
             feed(store, transport, %{again | window_size: 128})

    assert_abort(@dest, 6, :window_size_out_of_range, false)
  end

  test "a bad window aborts an existing sequence", %{store: store, transport: transport} do
    [first, second | _remaining_segments] = pieces(:request, 7, 4, 200)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 7, 0, 4, true)

    assert {:error, :invalid_proposed_window_size, true} =
             feed(store, transport, %{second | window_size: 0}, track: :abort)

    assert [track: :abort] == assert_abort(@dest, 7, :window_size_out_of_range, true)

    send(store, {:timeout, make_ref(), {@dest, 7}})
    assert :ok = SegmentsStore.configure(store, [])
    refute_received {:fake_transport_send, _, %APDU.Abort{}, _}
  end

  test "sequence 0 is rejected once a sequence exists", %{store: store, transport: transport} do
    [first, second | _remaining_segments] = pieces(:request, 8, 1, 80)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 8, 0, 1, true)

    assert {:error, :invalid_apdu_in_this_state_already_present, true} =
             feed(store, transport, first)

    assert_abort(@dest, 8, :invalid_apdu_in_this_state, true)

    assert {:error, :invalid_apdu_in_this_state_missing_id, true} = feed(store, transport, second)
    assert_abort(@dest, 8, :invalid_apdu_in_this_state, true)
  end

  test "a non-zero sequence without a stored sequence is rejected", %{
    store: store,
    transport: transport
  } do
    [_first, second | _remaining_segments] = pieces(:request, 9, 1, 80)

    assert {:error, :invalid_apdu_in_this_state_missing_id, true} =
             feed(store, transport, second, track: :missing)

    assert [track: :missing] == assert_abort(@dest, 9, :invalid_apdu_in_this_state, true)
    refute_received {:fake_transport_send, _, %APDU.SegmentACK{}, _}
  end

  test "a window acknowledges every boundary and the final segment", %{
    store: store,
    transport: transport
  } do
    segments = pieces(:request, 10, 2, 160)
    assert length(segments) == 4
    [first, second, third, fourth] = segments

    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 10, 0, 2, true)

    assert :incomplete = feed(store, transport, second)
    refute_received {:fake_transport_send, @dest, _, _}

    assert :incomplete = feed(store, transport, third)
    assert_ack(@dest, 10, 2, 2, true)

    assert {:ok, binary} = feed(store, transport, fourth)
    assert_ack(@dest, 10, 3, 2, true)
    assert binary == joined(segments)
  end

  test "overwriting the window size makes every segment acknowledged", %{
    store: store,
    transport: transport
  } do
    [first, last] = pieces(:request, 11, 4, 80)
    first = IncompleteAPDU.set_window_size(first, 1)

    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 11, 0, 1, true)

    assert {:ok, _binary} = feed(store, transport, last)
    assert_ack(@dest, 11, 1, 1, true)
  end

  test "a sequence that finishes on the segment limit is returned", %{transport: transport} do
    {:ok, store} =
      SegmentsStore.start_link(apdu_timeout: 60_000, apdu_retries: 1, max_segments: 2)

    [first, last] = pieces(:ack, 12, 1, 80)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 12, 0, 1, false)

    assert {:ok, binary} = feed(store, transport, last)
    assert {:ok, %APDU.ComplexACK{invoke_id: 12}} = APDU.decode(binary)
  end

  test "more segments than the limit abort while more follows", %{transport: transport} do
    {:ok, store} =
      SegmentsStore.start_link(apdu_timeout: 60_000, apdu_retries: 1, max_segments: 2)

    [first, second | _remaining_segments] = pieces(:request, 13, 4, 160)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 13, 0, 4, true)

    assert {:error, :too_many_segments, true} = feed(store, transport, second)
    assert_abort(@dest, 13, :buffer_overflow, true)
    refute_received {:fake_transport_send, @dest, %APDU.SegmentACK{}, _}
  end

  test "lowering max_segments aborts a sequence that is already past the new limit", %{
    store: store,
    transport: transport
  } do
    [first, second, third, fourth | _remaining_segments] = pieces(:request, 14, 4, 200)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 14, 0, 4, true)
    assert :incomplete = feed(store, transport, second)
    assert :incomplete = feed(store, transport, third)
    refute_received {:fake_transport_send, @dest, _, _}

    assert :ok = SegmentsStore.configure(store, max_segments: 2)
    assert {:error, :too_many_segments, true} = feed(store, transport, fourth)
    assert_abort(@dest, 14, :buffer_overflow, true)
  end

  test ":unspecified and :more_than_64 do not limit reassembly", %{transport: transport} do
    {:ok, store} =
      SegmentsStore.start_link(apdu_timeout: 60_000, apdu_retries: 1, max_segments: :unspecified)

    [first, last] = pieces(:ack, 15, 1, 80)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 15, 0, 1, false)
    assert {:ok, binary} = feed(store, transport, last)
    assert_ack(@dest, 15, 1, 1, false)
    assert {:ok, %APDU.ComplexACK{invoke_id: 15}} = APDU.decode(binary)

    assert :ok = SegmentsStore.configure(store, max_segments: :more_than_64)
    [first, last] = pieces(:ack, 16, 1, 80)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 16, 0, 1, false)
    assert {:ok, binary} = feed(store, transport, last)
    assert_ack(@dest, 16, 1, 1, false)
    assert {:ok, %APDU.ComplexACK{invoke_id: 16}} = APDU.decode(binary)
  end

  test "duplicates are counted and a full window sends a nak", %{
    store: store,
    transport: transport
  } do
    [first, second, third | _remaining_segments] = pieces(:request, 17, 4, 200)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 17, 0, 4, true)
    assert :incomplete = feed(store, transport, second)

    for _attempt <- 1..3 do
      assert {:error, :duplicated_segments, false} = feed(store, transport, second)
      refute_received {:fake_transport_send, @dest, _, _}
    end

    assert {:error, :duplicated_segments, false} = feed(store, transport, second)

    assert {%APDU.SegmentACK{
              negative_ack: true,
              sent_by_server: true,
              invoke_id: 17,
              sequence_number: 1,
              actual_window_size: 4
            }, _opts} = take_ack()

    assert {:error, :duplicated_segments, false} = feed(store, transport, second)
    refute_received {:fake_transport_send, @dest, _, _}

    assert :incomplete = feed(store, transport, third)
  end

  test "an out of order segment is nak'd and the sequence continues", %{
    store: store,
    transport: transport
  } do
    [first, second, third | _remaining_segments] = pieces(:request, 18, 4, 200)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 18, 0, 4, true)

    assert {:error, :segments_out_of_order, false} = feed(store, transport, third)

    assert {%APDU.SegmentACK{
              negative_ack: true,
              invoke_id: 18,
              sequence_number: 0,
              actual_window_size: 4
            }, _opts} = take_ack()

    assert :incomplete = feed(store, transport, second)
  end

  test "cancel drops the sequence for every supported apdu", %{store: store, transport: transport} do
    assert :ok = SegmentsStore.cancel(store, @dest, 90)
    assert :ok = SegmentsStore.configure(store, [])

    cancellers = [
      {20, ApduFactory.abort(20)},
      {21, ApduFactory.reject(21)},
      {22, ApduFactory.simple_ack(22)},
      {23,
       %APDU.Error{
         invoke_id: 23,
         service: :read_property,
         class: :device,
         code: :operational_problem,
         payload: []
       }},
      {24, 24}
    ]

    for {invoke, canceller} <- cancellers do
      [first, second | _remaining_segments] = pieces(:request, invoke, 1, 80)
      assert :incomplete = feed(store, transport, first)
      assert_ack(@dest, invoke, 0, 1, true)
      timer = :sys.get_state(store).sequences[{@dest, invoke}].timer

      assert :ok = SegmentsStore.cancel(store, @dest, canceller)
      assert :ok = SegmentsStore.configure(store, [])
      assert Process.read_timer(timer) == false

      assert {:error, :invalid_apdu_in_this_state_missing_id, true} =
               feed(store, transport, second)

      assert_abort(@dest, invoke, :invalid_apdu_in_this_state, true)
    end
  end

  test "a cancelled sequence ignores queued timers even after its ID is reused", %{
    store: store,
    transport: transport
  } do
    [first, last] = pieces(:request, 25, 1, 80)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 25, 0, 1, true)
    timer = :sys.get_state(store).sequences[{@dest, 25}].timer

    assert :ok = SegmentsStore.cancel(store, @dest, ApduFactory.abort(25))
    send(store, {:timeout, timer, {@dest, 25}})
    assert :ok = SegmentsStore.configure(store, [])
    assert Process.read_timer(timer) == false
    refute_received {:fake_transport_send, _, %APDU.Abort{}, _}

    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 25, 0, 1, true)
    sequence = :sys.get_state(store).sequences[{@dest, 25}]
    assert sequence.timer != timer
    send(store, {:timeout, timer, {@dest, 25}})
    assert :sys.get_state(store).sequences[{@dest, 25}] == sequence

    assert {:ok, binary} = feed(store, transport, last)
    assert_ack(@dest, 25, 1, 1, true)
    assert binary == joined([first, last])
  end

  test "the first timeout drops the sequence when apdu_retries is 1", %{
    store: store,
    transport: transport
  } do
    [first, second | _remaining_segments] = pieces(:request, 26, 1, 80)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 26, 0, 1, true)

    fire_timer(store, {@dest, 26})
    assert :ok = SegmentsStore.configure(store, [])
    refute_received {:fake_transport_send, _, %APDU.Abort{}, _}

    assert {:error, :invalid_apdu_in_this_state_missing_id, true} = feed(store, transport, second)
    assert_abort(@dest, 26, :invalid_apdu_in_this_state, true)
  end

  test "the first timeout leaves the sequence open when apdu_retries is 2", %{
    transport: transport
  } do
    {:ok, store} = SegmentsStore.start_link(apdu_timeout: 60_000, apdu_retries: 2)

    [first, second | _remaining_segments] = pieces(:request, 27, 4, 160)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 27, 0, 4, true)

    fire_timer(store, {@dest, 27})
    assert :ok = SegmentsStore.configure(store, [])
    assert :incomplete = feed(store, transport, second)
    refute_received {:fake_transport_send, @dest, %APDU.Abort{}, _}
  end

  test "consecutive timeouts reach the retry limit", %{transport: transport} do
    {:ok, store} = SegmentsStore.start_link(apdu_timeout: 60_000, apdu_retries: 2)
    [first, second | _remaining_segments] = pieces(:request, 33, 4, 160)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 33, 0, 4, true)

    fire_timer(store, {@dest, 33})
    fire_timer(store, {@dest, 33})
    assert :ok = SegmentsStore.configure(store, [])
    refute_received {:fake_transport_send, _, %APDU.Abort{}, _}

    assert {:error, :invalid_apdu_in_this_state_missing_id, true} = feed(store, transport, second)
    assert_abort(@dest, 33, :invalid_apdu_in_this_state, true)
  end

  test "an out of order segment does not restart the timeout count", %{transport: transport} do
    {:ok, store} = SegmentsStore.start_link(apdu_timeout: 60_000, apdu_retries: 2)
    [first, second, third | _remaining_segments] = pieces(:request, 36, 4, 160)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 36, 0, 4, true)

    fire_timer(store, {@dest, 36})
    assert :ok = SegmentsStore.configure(store, [])
    assert {:error, :segments_out_of_order, false} = feed(store, transport, third)
    assert {%APDU.SegmentACK{negative_ack: true, sequence_number: 0}, _opts} = take_ack()

    fire_timer(store, {@dest, 36})
    assert :ok = SegmentsStore.configure(store, [])
    assert {:error, :invalid_apdu_in_this_state_missing_id, true} = feed(store, transport, second)
    assert_abort(@dest, 36, :invalid_apdu_in_this_state, true)
  end

  test "a received segment restarts the timeout count", %{transport: transport} do
    {:ok, store} = SegmentsStore.start_link(apdu_timeout: 60_000, apdu_retries: 2)
    [first, second, third, fourth | _remaining_segments] = pieces(:request, 34, 4, 160)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 34, 0, 4, true)

    fire_timer(store, {@dest, 34})
    assert :ok = SegmentsStore.configure(store, [])
    assert :incomplete = feed(store, transport, second)

    fire_timer(store, {@dest, 34})
    assert :ok = SegmentsStore.configure(store, [])
    assert :incomplete = feed(store, transport, third)
    refute_received {:fake_transport_send, @dest, _, _}

    fire_timer(store, {@dest, 34})
    fire_timer(store, {@dest, 34})
    assert :ok = SegmentsStore.configure(store, [])
    assert {:error, :invalid_apdu_in_this_state_missing_id, true} = feed(store, transport, fourth)
    assert_abort(@dest, 34, :invalid_apdu_in_this_state, true)
  end

  test "the default retry count does not drop a sequence on one timeout", %{transport: transport} do
    {:ok, store} = SegmentsStore.start_link([])
    [first, second | _remaining_segments] = pieces(:request, 28, 4, 160)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 28, 0, 4, true)

    fire_timer(store, {@dest, 28})
    assert :ok = SegmentsStore.configure(store, [])
    assert :incomplete = feed(store, transport, second)
  end

  test "the fourth timeout drops the sequence at the default retry count", %{
    transport: transport
  } do
    {:ok, store} = SegmentsStore.start_link([])
    [first, second | _remaining_segments] = pieces(:request, 35, 4, 160)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 35, 0, 4, true)

    for _attempt <- 1..4 do
      fire_timer(store, {@dest, 35})
    end

    assert :ok = SegmentsStore.configure(store, [])
    refute_received {:fake_transport_send, _, %APDU.Abort{}, _}

    assert {:error, :invalid_apdu_in_this_state_missing_id, true} = feed(store, transport, second)
    assert_abort(@dest, 35, :invalid_apdu_in_this_state, true)
  end

  test "configure apdu_timeout is used the next time the timer is armed", %{
    store: store,
    transport: transport
  } do
    [first, second, third | _remaining_segments] = pieces(:request, 29, 4, 160)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 29, 0, 4, true)

    assert :ok = SegmentsStore.configure(store, apdu_timeout: 40)
    assert :incomplete = feed(store, transport, second)
    Process.sleep(200)

    assert {:error, :invalid_apdu_in_this_state_missing_id, true} = feed(store, transport, third)
    assert_abort(@dest, 29, :invalid_apdu_in_this_state, true)
  end

  test "an unknown timer is ignored", %{store: store} do
    send(store, {:timeout, make_ref(), {@dest, 99}})
    assert :ok = SegmentsStore.configure(store, [])
    refute_received {:fake_transport_send, _, _, _}
  end

  test "replaying a handled timeout does not consume another retry", %{transport: transport} do
    {:ok, store} = SegmentsStore.start_link(apdu_timeout: 60_000, apdu_retries: 2)
    [first | _remaining_segments] = pieces(:request, 37, 4, 160)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 37, 0, 4, true)
    timer = :sys.get_state(store).sequences[{@dest, 37}].timer

    fire_timer(store, {@dest, 37})
    sequence = :sys.get_state(store).sequences[{@dest, 37}]
    assert sequence.timeout_count == 1
    assert sequence.timer != timer
    send(store, {:timeout, timer, {@dest, 37}})
    assert :sys.get_state(store).sequences[{@dest, 37}] == sequence

    fire_timer(store, {@dest, 37})
    assert :sys.get_state(store).sequences == %{}
  end

  test "a failed transport send is logged and the sequence continues", %{
    store: store,
    transport: transport
  } do
    [first, last] = pieces(:ack, 30, 1, 80)
    assert :ok = FakeTransport.set_send_result(transport, {:error, :down})
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 30, 0, 1, false)

    assert :ok = FakeTransport.set_send_result(transport, :ok)
    assert {:ok, binary} = feed(store, transport, last)
    assert {:ok, %APDU.ComplexACK{invoke_id: 30}} = APDU.decode(binary)
  end

  test "a failed abort send still returns the window error", %{store: store, transport: transport} do
    [first | _remaining_segments] = pieces(:request, 31, 1, 80)
    assert :ok = FakeTransport.set_send_result(transport, {:error, :down})

    assert {:error, :invalid_proposed_window_size, true} =
             feed(store, transport, %{first | window_size: 0})

    assert_abort(@dest, 31, :window_size_out_of_range, true)
  end

  test "a failed nak send still reports the duplicate", %{store: store, transport: transport} do
    [first, second | _remaining_segments] = pieces(:request, 32, 1, 160)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 32, 0, 1, true)
    assert :incomplete = feed(store, transport, second)
    assert_ack(@dest, 32, 1, 1, true)

    assert :ok = FakeTransport.set_send_result(transport, {:error, :down})
    assert {:error, :duplicated_segments, false} = feed(store, transport, second)
    assert {%APDU.SegmentACK{negative_ack: true, sequence_number: 1}, _opts} = take_ack()
  end

  test "receiving another segment replaces the original timeout" do
    transport = start_supervised!({FakeTransport, owner: self()})
    store = start_supervised!({SegmentsStore, apdu_timeout: 1_000, apdu_retries: 1})

    apdu = %{
      ApduFactory.complex_ack(42, octet_string: :binary.copy(<<7>>, 200))
      | sequence_number: 0,
        proposed_window_size: 1
    }

    [first_bytes, second_bytes | _remaining_segments] = EncoderProtocol.encode_segmented(apdu, 50)
    assert {:incomplete, first} = APDU.decode(first_bytes)
    assert {:incomplete, second} = APDU.decode(second_bytes)

    assert :incomplete = SegmentsStore.segment(store, first, FakeTransport, transport, :peer)
    timer = :sys.get_state(store).sequences[{:peer, 42}].timer
    # Move the next deadline far away without sleeping close to an expiry
    assert :ok = SegmentsStore.configure(store, apdu_timeout: 60_000)
    assert :incomplete = SegmentsStore.segment(store, second, FakeTransport, transport, :peer)
    assert Process.read_timer(timer) == false
    send(store, {:timeout, timer, {:peer, 42}})

    # This deliberate wait exercises delivery of any orphaned original timer
    Process.sleep(1_200)
    assert %{{:peer, 42} => sequence} = :sys.get_state(store).sequences
    assert sequence.count_segments == 2
    assert sequence.timeout_count == 0
  end

  test "the initial segment arms exactly one timeout", %{transport: transport} do
    {:ok, state, :hibernate} = SegmentsStore.init(%{apdu_timeout: 40, apdu_retries: 1})
    [first | _remaining_segments] = pieces(:request, 38, 1, 80)
    id = {@dest, 38}

    assert {:reply, :incomplete, state} =
             SegmentsStore.handle_call(
               {:segment, first, {FakeTransport, transport}, @dest, []},
               nil,
               state
             )

    timer = state.sequences[id].timer
    assert is_reference(timer)
    assert_receive {:timeout, ^timer, ^id}, 500
    refute_receive {:timeout, _other_timer, ^id}, 80
  end

  defp fire_timer(store, id) do
    timer = :sys.get_state(store).sequences[id].timer
    Process.cancel_timer(timer)
    send(store, {:timeout, timer, id})
    assert :ok = SegmentsStore.configure(store, [])
  end

  defp feed(store, transport, incomplete, opts \\ []) do
    SegmentsStore.segment(store, incomplete, FakeTransport, transport, @dest, opts)
  end

  defp assert_ack(dest, invoke_id, sequence_number, window, server) do
    assert {%APDU.SegmentACK{
              negative_ack: false,
              sent_by_server: ^server,
              invoke_id: ^invoke_id,
              sequence_number: ^sequence_number,
              actual_window_size: ^window
            }, opts} = take_ack(dest)

    opts
  end

  defp assert_abort(dest, invoke_id, reason, server) do
    assert_receive {:fake_transport_send, ^dest, abort, opts}
    assert %APDU.Abort{sent_by_server: ^server, invoke_id: ^invoke_id, reason: ^reason} = abort
    opts
  end

  defp take_ack(dest \\ @dest) do
    assert_receive {:fake_transport_send, ^dest, %APDU.SegmentACK{} = ack, opts}
    {ack, opts}
  end

  defp joined(segments) do
    IO.iodata_to_binary([List.last(segments).header | Enum.map(segments, & &1.data)])
  end

  defp pieces(:request, invoke_id, window, bytes) do
    {:ok, value} = Encoding.create({:octet_string, :binary.copy(<<7>>, bytes)})

    {:ok, request} =
      WriteProperty.to_apdu(
        %WriteProperty{
          object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1},
          property_identifier: :present_value,
          property_array_index: nil,
          property_value: value,
          priority: nil
        },
        invoke_id: invoke_id
      )

    segment(%{request | sequence_number: 0, proposed_window_size: window})
  end

  defp pieces(:ack, invoke_id, window, bytes) do
    ack = %{
      ApduFactory.complex_ack(invoke_id, [{:octet_string, :binary.copy(<<9>>, bytes)}])
      | sequence_number: 0,
        proposed_window_size: window
    }

    segment(ack)
  end

  defp segment(apdu) do
    header_size = if is_struct(apdu, APDU.ConfirmedServiceRequest), do: 6, else: 5

    apdu
    |> EncoderProtocol.encode_segmented(@segment_payload_size + header_size)
    |> Enum.map(fn binary ->
      assert {:incomplete, %IncompleteAPDU{} = incomplete} =
               APDU.decode(IO.iodata_to_binary(binary))

      incomplete
    end)
  end
end
