defmodule BACnet.Stack.SegmentsStoreTest do
  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.IncompleteAPDU
  alias BACnet.Protocol.NPCI
  alias BACnet.Protocol.NpciTarget
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.WriteProperty
  alias BACnet.Stack.EncoderProtocol
  alias BACnet.Stack.SegmentationEndpoint
  alias BACnet.Stack.Segmentator
  alias BACnet.Stack.SegmentsStore
  alias BACnet.Test.Stack.ApduFactory
  alias BACnet.Test.Stack.FakeTransport
  alias BACnet.Test.Stack.FakeTransport.Limited

  use BACnet.Test.Stack.Case, async: true

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
    timer = :sys.get_state(store).sequences[key(transport, 2, :requester)].timer

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

    send(store, {:timeout, make_ref(), key(transport, 7)})
    assert :ok = SegmentsStore.configure(store, [])
    refute_received {:fake_transport_send, _, %APDU.Abort{}, _}
  end

  test "a repeated initial segment is NAK'd without dropping the sequence", %{
    store: store,
    transport: transport
  } do
    [first, last] = pieces(:request, 8, 1, 80)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 8, 0, 1, true)

    assert {:error, :segments_out_of_order, false} = feed(store, transport, first)
    assert_nak(@dest, 8, 0, 1, true)
    assert :sys.get_state(store).sequences[key(transport, 8)].count_segments == 1

    assert {:ok, binary} = feed(store, transport, last)
    assert_ack(@dest, 8, 1, 1, true)
    assert binary == joined([first, last])
    assert :sys.get_state(store).sequences == %{}
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

  for kind <- [:request, :ack],
      {segment_count, window} <- [{257, 1}, {520, 2}, {520, 7}, {520, 127}] do
    @tag sequence_rollover: true, capture_log: [level: :warning]
    test "#{kind} reassembles #{segment_count} segments with sequence rollover and window #{window}",
         %{store: store, transport: transport} do
      kind = unquote(kind)
      segment_count = unquote(segment_count)
      window = unquote(window)
      segments = rollover_pieces(kind, segment_count, window)
      assert length(segments) == segment_count

      for {segment, index} <- Enum.with_index(segments) do
        assert segment.sequence_number == rem(index, 256)
        assert segment.more_follows == index < segment_count - 1

        if segment.more_follows do
          assert :incomplete = feed(store, transport, segment)
        else
          assert {:ok, binary} = feed(store, transport, segment)
          assert binary == joined(segments)
          assert {:ok, %{invoke_id: 90}} = APDU.decode(binary)
        end

        # Window boundaries count received segments, including across 255 -> 0.
        if index == 0 or rem(index, window) == 0 or not segment.more_follows do
          assert_ack(@dest, 90, rem(index, 256), window, kind == :request)
        else
          refute_received {:fake_transport_send, @dest, _, _}
        end
      end

      assert :sys.get_state(store).sequences == %{}
      refute_received {:fake_transport_send, @dest, _, _}
    end
  end

  for kind <- [:request, :ack], missing <- [255, 256] do
    @tag sequence_rollover: true, capture_log: [level: :warning]
    test "#{kind} recovers a missing segment at absolute index #{missing} with a new ACK window",
         %{store: store, transport: transport} do
      kind = unquote(kind)
      missing = unquote(missing)
      segments = rollover_pieces(kind, 520, 7)
      feed_prefix(store, transport, Enum.take(segments, missing))

      assert {:error, :segments_out_of_order, false} =
               feed(store, transport, Enum.at(segments, missing + 1))

      assert_nak(@dest, 90, rem(missing - 1, 256), 7, kind == :request)

      role = if kind == :request, do: :responder, else: :requester
      sequence = :sys.get_state(store).sequences[key(transport, 90, role)]
      assert sequence.count_segments == missing
      assert sequence.initial_sequence_number == rem(missing - 1, 256)
      assert sequence.duplicate_count == 0

      assert finish_rollover(store, transport, segments, missing, missing - 1) == joined(segments)
      assert :sys.get_state(store).sequences == %{}
    end
  end

  for kind <- [:request, :ack] do
    @tag sequence_rollover: true, capture_log: [level: :warning]
    test "#{kind} discards duplicates throughout a window crossing 255 to 0",
         %{store: store, transport: transport} do
      kind = unquote(kind)
      segments = rollover_pieces(kind, 520, 7)
      feed_prefix(store, transport, Enum.take(segments, 257))
      role = if kind == :request, do: :responder, else: :requester
      id = key(transport, 90, role)

      # All these segments belong to the received portion of the current window,
      # including earlier duplicates rather than just the most recent segment.
      for {index, duplicate_count} <- Enum.with_index([253, 254, 255, 256, 253, 254, 255], 1) do
        assert {:error, :duplicated_segments, false} =
                 feed(store, transport, Enum.at(segments, index))

        sequence = :sys.get_state(store).sequences[id]
        assert sequence.count_segments == 257
        assert sequence.duplicate_count == duplicate_count
        refute_received {:fake_transport_send, @dest, _data, _opts}
      end

      assert {:error, :duplicated_segments, false} =
               feed(store, transport, Enum.at(segments, 256))

      assert_nak(@dest, 90, 0, 7, kind == :request)
      sequence = :sys.get_state(store).sequences[id]
      assert sequence.count_segments == 257
      assert sequence.duplicate_count == 0

      # The two receiving states specify different InitialSequenceNumber updates
      # for TooManyDuplicateSegmentsReceived (5.4.5.2 and 5.4.4.4).
      anchor = if kind == :request, do: 256, else: 252
      assert sequence.initial_sequence_number == rem(anchor, 256)
      assert finish_rollover(store, transport, segments, 257, anchor) == joined(segments)
      assert :sys.get_state(store).sequences == %{}
    end
  end

  for kind <- [:request, :ack] do
    @tag sequence_rollover: true, capture_log: [level: :warning]
    test "#{kind} recognizes a previous-window duplicate across rollover and resets its counter at the next ACK",
         %{store: store, transport: transport} do
      kind = unquote(kind)
      segments = rollover_pieces(kind, 520, 7)
      feed_prefix(store, transport, Enum.take(segments, 261))

      # DuplicateInWindow step (4): one segment of the new window is received;
      # a repeated segment from the previous window must still be discarded.
      assert {:error, :duplicated_segments, false} =
               feed(store, transport, Enum.at(segments, 255))

      refute_received {:fake_transport_send, @dest, _data, _opts}
      role = if kind == :request, do: :responder, else: :requester
      id = key(transport, 90, role)
      assert :sys.get_state(store).sequences[id].duplicate_count == 1

      assert finish_rollover(store, transport, Enum.take(segments, 267), 261, 259) == nil
      sequence = :sys.get_state(store).sequences[id]
      assert sequence.count_segments == 267
      assert sequence.initial_sequence_number == 10
      assert sequence.duplicate_count == 0

      assert finish_rollover(store, transport, segments, 267, 266) == joined(segments)
      assert :sys.get_state(store).sequences == %{}
    end
  end

  for kind <- [:request, :ack], drop_segment <- [false, true] do
    @tag sequence_rollover: true, capture_log: [level: :warning]
    test "#{kind} exchanges 520 segments with Segmentator, losing segment 255=#{drop_segment}",
         %{store: store, transport: transport} do
      kind = unquote(kind)
      drop_segment = unquote(drop_segment)
      # Losing the first segment of a window can produce a NAK for the previous
      # window. Recovery then uses Segmentator's retry timer rather than that NAK.
      sender = start_supervised!({Segmentator, apdu_timeout: 50, apdu_retries: 1})
      segments = rollover_pieces(kind, 520, 127)
      expected = joined(segments)
      assert {:ok, apdu} = APDU.decode(expected)
      apdu = %{apdu | sequence_number: 0, proposed_window_size: 127}
      apdu_size = @segment_payload_size + if(kind == :request, do: 6, else: 5)

      assert :ok =
               Segmentator.create_sequence(
                 sender,
                 {FakeTransport, transport, transport},
                 @dest,
                 apdu,
                 apdu_size,
                 0,
                 callback_to: self(),
                 callback_msg: :rollover_exchange
               )

      assert_receive {:fake_transport_postponed, @dest, []}

      result =
        exchange_segments(
          sender,
          store,
          transport,
          drop_segment,
          %{binary: nil, done: false, dropped: false},
          2_000
        )

      assert result.binary == expected
      assert result.dropped == drop_segment
      assert :sys.get_state(sender).sequences == %{}
      assert :sys.get_state(store).sequences == %{}
    end
  end

  for kind <- [:request, :ack] do
    @tag sequence_rollover: true, capture_log: [level: :warning]
    test "#{kind} keeps the total segment count when lowering the limit after rollover",
         %{store: store, transport: transport} do
      kind = unquote(kind)
      segments = rollover_pieces(kind, 520, 7)
      feed_prefix(store, transport, Enum.take(segments, 257))
      assert :ok = SegmentsStore.configure(store, max_segments: 64)

      assert {:error, :too_many_segments, true} = feed(store, transport, Enum.at(segments, 257))
      assert_abort(@dest, 90, :buffer_overflow, kind == :request)
      assert :sys.get_state(store).sequences == %{}
    end
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

  test "Ndup duplicates are silently dropped before the next duplicate sends a NAK", %{
    store: store,
    transport: transport
  } do
    [first, second, third | _remaining_segments] = pieces(:request, 17, 4, 200)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 17, 0, 4, true)
    assert :incomplete = feed(store, transport, second)

    for _attempt <- 1..4 do
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

    assert {:error, :segments_out_of_order, false} = feed(store, transport, second)
    assert_nak(@dest, 17, 1, 4, true)

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
      [first, second | _remaining_segments] = pieces(:ack, invoke, 1, 80)
      assert :incomplete = feed(store, transport, first)
      assert_ack(@dest, invoke, 0, 1, false)
      timer = :sys.get_state(store).sequences[key(transport, invoke, :requester)].timer

      assert :ok = SegmentsStore.cancel(store, @dest, canceller)
      assert :ok = SegmentsStore.configure(store, [])
      assert Process.read_timer(timer) == false

      assert {:error, :invalid_apdu_in_this_state_missing_id, true} =
               feed(store, transport, second)

      assert_abort(@dest, invoke, :invalid_apdu_in_this_state, false)
    end
  end

  test "a cancelled sequence ignores queued timers even after its ID is reused", %{
    store: store,
    transport: transport
  } do
    [first, last] = pieces(:request, 25, 1, 80)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 25, 0, 1, true)
    timer = :sys.get_state(store).sequences[key(transport, 25)].timer

    assert :ok =
             SegmentsStore.cancel(store, @dest, %{ApduFactory.abort(25) | sent_by_server: false})

    send(store, {:timeout, timer, key(transport, 25)})
    assert :ok = SegmentsStore.configure(store, [])
    assert Process.read_timer(timer) == false
    refute_received {:fake_transport_send, _, %APDU.Abort{}, _}

    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 25, 0, 1, true)
    sequence = :sys.get_state(store).sequences[key(transport, 25)]
    assert sequence.timer != timer
    send(store, {:timeout, timer, key(transport, 25)})
    assert :sys.get_state(store).sequences[key(transport, 25)] == sequence

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

    fire_timer(store, key(transport, 26))
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

    fire_timer(store, key(transport, 27))
    assert :ok = SegmentsStore.configure(store, [])
    assert :incomplete = feed(store, transport, second)
    refute_received {:fake_transport_send, @dest, %APDU.Abort{}, _}
  end

  test "consecutive timeouts reach the retry limit", %{transport: transport} do
    {:ok, store} = SegmentsStore.start_link(apdu_timeout: 60_000, apdu_retries: 2)
    [first, second | _remaining_segments] = pieces(:request, 33, 4, 160)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 33, 0, 4, true)

    fire_timer(store, key(transport, 33))
    fire_timer(store, key(transport, 33))
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

    fire_timer(store, key(transport, 36))
    assert :ok = SegmentsStore.configure(store, [])
    assert {:error, :segments_out_of_order, false} = feed(store, transport, third)
    assert {%APDU.SegmentACK{negative_ack: true, sequence_number: 0}, _opts} = take_ack()

    fire_timer(store, key(transport, 36))
    assert :ok = SegmentsStore.configure(store, [])
    assert {:error, :invalid_apdu_in_this_state_missing_id, true} = feed(store, transport, second)
    assert_abort(@dest, 36, :invalid_apdu_in_this_state, true)
  end

  test "a received segment restarts the timeout count", %{transport: transport} do
    {:ok, store} = SegmentsStore.start_link(apdu_timeout: 60_000, apdu_retries: 2)
    [first, second, third, fourth | _remaining_segments] = pieces(:request, 34, 4, 160)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 34, 0, 4, true)

    fire_timer(store, key(transport, 34))
    assert :ok = SegmentsStore.configure(store, [])
    assert :incomplete = feed(store, transport, second)

    fire_timer(store, key(transport, 34))
    assert :ok = SegmentsStore.configure(store, [])
    assert :incomplete = feed(store, transport, third)
    refute_received {:fake_transport_send, @dest, _, _}

    fire_timer(store, key(transport, 34))
    fire_timer(store, key(transport, 34))
    assert :ok = SegmentsStore.configure(store, [])
    assert {:error, :invalid_apdu_in_this_state_missing_id, true} = feed(store, transport, fourth)
    assert_abort(@dest, 34, :invalid_apdu_in_this_state, true)
  end

  test "the default retry count does not drop a sequence on one timeout", %{transport: transport} do
    {:ok, store} = SegmentsStore.start_link([])
    [first, second | _remaining_segments] = pieces(:request, 28, 4, 160)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 28, 0, 4, true)

    fire_timer(store, key(transport, 28))
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
      fire_timer(store, key(transport, 35))
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

  test "an unknown timer is ignored", %{store: store, transport: transport} do
    send(store, {:timeout, make_ref(), key(transport, 99)})
    assert :ok = SegmentsStore.configure(store, [])
    refute_received {:fake_transport_send, _, _, _}
  end

  test "replaying a handled timeout does not consume another retry", %{transport: transport} do
    {:ok, store} = SegmentsStore.start_link(apdu_timeout: 60_000, apdu_retries: 2)
    [first | _remaining_segments] = pieces(:request, 37, 4, 160)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 37, 0, 4, true)
    timer = :sys.get_state(store).sequences[key(transport, 37)].timer

    fire_timer(store, key(transport, 37))
    sequence = :sys.get_state(store).sequences[key(transport, 37)]
    assert sequence.timeout_count == 1
    assert sequence.timer != timer
    send(store, {:timeout, timer, key(transport, 37)})
    assert :sys.get_state(store).sequences[key(transport, 37)] == sequence

    fire_timer(store, key(transport, 37))
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
    [first, second | _remaining_segments] = pieces(:request, 32, 4, 160)
    assert :incomplete = feed(store, transport, first)
    assert_ack(@dest, 32, 0, 4, true)
    assert :incomplete = feed(store, transport, second)

    for _attempt <- 1..4 do
      assert {:error, :duplicated_segments, false} = feed(store, transport, second)
      refute_received {:fake_transport_send, @dest, _data, _opts}
    end

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
    timer = :sys.get_state(store).sequences[key(transport, 42, :requester)].timer
    # Move the next deadline far away without sleeping close to an expiry
    assert :ok = SegmentsStore.configure(store, apdu_timeout: 60_000)
    assert :incomplete = SegmentsStore.segment(store, second, FakeTransport, transport, :peer)
    assert Process.read_timer(timer) == false
    send(store, {:timeout, timer, key(transport, 42, :requester)})

    # This deliberate wait exercises delivery of any orphaned original timer
    Process.sleep(1_200)
    id = key(transport, 42, :requester)
    assert %{^id => sequence} = :sys.get_state(store).sequences
    assert sequence.count_segments == 2
    assert sequence.timeout_count == 0
  end

  test "the initial segment arms exactly one timeout", %{transport: transport} do
    {:ok, state, :hibernate} = SegmentsStore.init(%{apdu_timeout: 40, apdu_retries: 1})
    [first | _remaining_segments] = pieces(:request, 38, 1, 80)
    id = key(transport, 38)

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

  test "reassembly isolates networks, portals and transport modules", %{
    store: store,
    transport: transport
  } do
    other_portal = start_supervised!({FakeTransport, owner: self()})
    target = %NpciTarget{net: 10, address: <<7>>}

    endpoints = [
      SegmentationEndpoint.new(FakeTransport, transport, @dest, destination: target),
      SegmentationEndpoint.new(FakeTransport, transport, @dest, destination: %{target | net: 20}),
      SegmentationEndpoint.new(FakeTransport, other_portal, @dest, destination: target),
      SegmentationEndpoint.new(Limited, transport, @dest, destination: target)
    ]

    transfers =
      Enum.with_index(endpoints, fn endpoint, index ->
        segments = pieces(:ack, 60, 1, 80 + index)
        [first | _rest] = segments
        assert :incomplete = feed_endpoint(store, endpoint, first)
        assert [destination: endpoint.npci] == assert_ack(@dest, 60, 0, 1, false)
        {endpoint, segments}
      end)

    sequences = :sys.get_state(store).sequences
    assert map_size(sequences) == 4
    assert Enum.all?(endpoints, &(sequences[{&1, :requester, 60}].endpoint == &1))

    # Address-only cancellation must not pick one endpoint or cancel all of them.
    assert :ok = SegmentsStore.cancel(store, @dest, 60)
    assert :sys.get_state(store).sequences == sequences

    for {endpoint, [first, last]} <- Enum.reverse(transfers) do
      assert {:ok, binary} = feed_endpoint(store, endpoint, last)
      assert binary == joined([first, last])
      assert [destination: endpoint.npci] == assert_ack(@dest, 60, 1, 1, false)
    end

    assert :sys.get_state(store).sequences == %{}
  end

  test "cancellation, invalid segments and timeouts affect only the exact endpoint", %{
    store: store,
    transport: transport
  } do
    target = %NpciTarget{net: 10, address: <<7>>}

    first_endpoint =
      SegmentationEndpoint.new(FakeTransport, transport, @dest, destination: target)

    second_endpoint = %{first_endpoint | npci: %{target | net: 20}}
    [first, last] = pieces(:ack, 61, 1, 80)

    for canceller <- [
          ApduFactory.abort(61),
          ApduFactory.reject(61),
          ApduFactory.simple_ack(61),
          %APDU.Error{
            invoke_id: 61,
            service: :read_property,
            class: :device,
            code: :operational_problem,
            payload: []
          },
          61
        ] do
      for endpoint <- [first_endpoint, second_endpoint] do
        assert :incomplete = feed_endpoint(store, endpoint, first)
        assert_ack(@dest, 61, 0, 1, false)
      end

      sequences = :sys.get_state(store).sequences
      timer = sequences[{first_endpoint, :requester, 61}].timer
      assert :ok = SegmentsStore.cancel(store, first_endpoint, canceller)

      assert :sys.get_state(store).sequences ==
               Map.delete(sequences, {first_endpoint, :requester, 61})

      assert Process.read_timer(timer) == false
      assert {:ok, _binary} = feed_endpoint(store, second_endpoint, last)
      assert_ack(@dest, 61, 1, 1, false)
    end

    for endpoint <- [first_endpoint, second_endpoint] do
      assert :incomplete = feed_endpoint(store, endpoint, first)
      assert_ack(@dest, 61, 0, 1, false)
    end

    sequences = :sys.get_state(store).sequences

    assert {:error, :invalid_proposed_window_size, true} =
             feed_endpoint(store, first_endpoint, %{last | window_size: 0})

    assert [destination: target] == assert_abort(@dest, 61, :window_size_out_of_range, false)

    assert :sys.get_state(store).sequences ==
             Map.delete(sequences, {first_endpoint, :requester, 61})

    # Reuse the first endpoint and expire only its timer, leaving the other untouched.
    assert :incomplete = feed_endpoint(store, first_endpoint, first)
    assert_ack(@dest, 61, 0, 1, false)
    fire_timer(store, {first_endpoint, :requester, 61})

    assert :sys.get_state(store).sequences ==
             Map.delete(sequences, {first_endpoint, :requester, 61})

    assert {:ok, _binary} = feed_endpoint(store, second_endpoint, last)
    assert_ack(@dest, 61, 1, 1, false)
  end

  test "explicit NPCI destination scopes reassembly and overrides destination option", %{
    store: store,
    transport: transport
  } do
    target = %NpciTarget{net: 10, address: <<7>>}
    other_target = %{target | net: 20}
    [first, last] = pieces(:ack, 62, 1, 80)

    assert :incomplete =
             feed(store, transport, first,
               npci: NPCI.new(destination: target),
               destination: other_target
             )

    assert_ack(@dest, 62, 0, 1, false)
    assert :incomplete = feed(store, transport, first, destination: other_target)
    assert_ack(@dest, 62, 0, 1, false)
    assert {:ok, _binary} = feed(store, transport, last, destination: target)
    assert_ack(@dest, 62, 1, 1, false)
    assert {:ok, _binary} = feed(store, transport, last, destination: other_target)
    assert_ack(@dest, 62, 1, 1, false)
  end

  test "segmented requests and responses sharing an endpoint and invoke ID reassemble separately",
       %{
         store: store,
         transport: transport
       } do
    for first_role <- [:requester, :responder] do
      {endpoint, transfers} = open_role_pair(store, transport, 80)
      # An integer alone must not select one of the two roles, even for a complete endpoint.
      sequences = :sys.get_state(store).sequences

      for peer <- [@dest, endpoint] do
        assert :ok = SegmentsStore.cancel(store, peer, 80)
        assert :sys.get_state(store).sequences == sequences
      end

      for role <- [first_role] ++ ([:requester, :responder] -- [first_role]) do
        other = Map.delete(:sys.get_state(store).sequences, {endpoint, role, 80})
        [first, last] = transfers[role]
        assert {:ok, binary} = feed_endpoint(store, endpoint, last)
        assert binary == joined([first, last])
        assert_ack(@dest, 80, 1, 1, role == :responder)
        assert :sys.get_state(store).sequences == other
      end
    end
  end

  test "received terminal APDUs and explicit local cancellation remove only the matching role", %{
    store: store,
    transport: transport
  } do
    error = %APDU.Error{
      invoke_id: 81,
      service: :read_property,
      class: :device,
      code: :operational_problem,
      payload: []
    }

    cases = [
      {:requester, ApduFactory.abort(81)},
      {:responder, %{ApduFactory.abort(81) | sent_by_server: false}},
      {:requester, error},
      {:requester, ApduFactory.reject(81)},
      {:requester, ApduFactory.simple_ack(81)},
      {:requester, 81},
      {:responder, 81}
    ]

    for lookup <- [:address, :endpoint], {role, apdu} <- cases do
      {endpoint, transfers} = open_role_pair(store, transport, 81)
      peer = if lookup == :address, do: @dest, else: endpoint
      id = {endpoint, role, 81}
      sequences = :sys.get_state(store).sequences

      if is_integer(apdu) do
        assert :ok = SegmentsStore.cancel(store, peer, apdu, role)
      else
        assert :ok = SegmentsStore.cancel(store, peer, apdu)
      end

      assert :sys.get_state(store).sequences == Map.delete(sequences, id)
      assert Process.read_timer(sequences[id].timer) == false

      # Repeating a role-specific cancellation must leave the opposite transfer intact.
      assert :ok = SegmentsStore.cancel(store, peer, 81, role)
      assert :sys.get_state(store).sequences == Map.delete(sequences, id)
      [other_role] = [:requester, :responder] -- [role]
      assert {:ok, _binary} = feed_endpoint(store, endpoint, List.last(transfers[other_role]))
      assert_ack(@dest, 81, 1, 1, other_role == :responder)
    end
  end

  test "invalid windows, duplicate initial segments and timeouts isolate the receiving role", %{
    store: store,
    transport: transport
  } do
    for role <- [:requester, :responder], reason <- [:invalid_window, :duplicate, :timeout] do
      {endpoint, transfers} = open_role_pair(store, transport, 82)
      id = {endpoint, role, 82}
      sequences = :sys.get_state(store).sequences

      case reason do
        :invalid_window ->
          assert {:error, :invalid_proposed_window_size, true} =
                   feed_endpoint(store, endpoint, %{List.last(transfers[role]) | window_size: 0})

          assert_abort(@dest, 82, :window_size_out_of_range, role == :responder)

        :duplicate ->
          assert {:error, :segments_out_of_order, false} =
                   feed_endpoint(store, endpoint, hd(transfers[role]))

          assert_nak(@dest, 82, 0, 1, role == :responder)
          assert Map.delete(:sys.get_state(store).sequences, id) == Map.delete(sequences, id)
          assert {:ok, _binary} = feed_endpoint(store, endpoint, List.last(transfers[role]))
          assert_ack(@dest, 82, 1, 1, role == :responder)

        :timeout ->
          fire_timer(store, id)
      end

      assert :sys.get_state(store).sequences == Map.delete(sequences, id)
      [other_role] = [:requester, :responder] -- [role]
      assert {:ok, _binary} = feed_endpoint(store, endpoint, List.last(transfers[other_role]))
      assert_ack(@dest, 82, 1, 1, other_role == :responder)
    end
  end

  defp exchange_segments(
         _sender,
         _store,
         _transport,
         _drop,
         %{binary: binary, done: true} = result,
         _remaining
       )
       when is_binary(binary), do: result

  defp exchange_segments(sender, store, transport, drop, result, remaining) when remaining > 0 do
    result =
      receive do
        {:fake_transport_send, @dest, %APDU.SegmentACK{} = ack, _opts} ->
          assert :ok = Segmentator.handle_apdu(sender, @dest, ack)
          result

        {:fake_transport_send, @dest, bytes, _opts} when is_binary(bytes) or is_list(bytes) ->
          assert {:incomplete, segment} = APDU.decode(IO.iodata_to_binary(bytes))

          if drop and not result.dropped and segment.sequence_number == 255 do
            %{result | dropped: true}
          else
            case feed(store, transport, segment) do
              :incomplete ->
                result

              {:ok, binary} ->
                %{result | binary: binary}

              {:error, reason, false}
              when reason in [:segments_out_of_order, :duplicated_segments] ->
                result

              other ->
                flunk("Unexpected reassembly result: #{inspect(other)}")
            end
          end

        {:fake_transport_send, @dest, %APDU.Abort{} = abort, _opts} ->
          flunk("Unexpected abort: #{inspect(abort)}")

        {:done, :rollover_exchange} ->
          %{result | done: true}
      after
        1_000 -> flunk("Segment exchange stalled: #{inspect(result)}")
      end

    exchange_segments(sender, store, transport, drop, result, remaining - 1)
  end

  defp exchange_segments(_sender, _store, _transport, _drop, _result, 0),
    do: flunk("Segment exchange exceeded its message limit")

  defp feed_prefix(store, transport, segments) do
    for {segment, index} <- Enum.with_index(segments) do
      assert :incomplete = feed(store, transport, segment)

      if index == 0 or rem(index, segment.window_size) == 0 do
        assert_ack(
          @dest,
          segment.invoke_id,
          segment.sequence_number,
          segment.window_size,
          segment.server
        )
      else
        refute_received {:fake_transport_send, @dest, _data, _opts}
      end
    end
  end

  defp finish_rollover(store, transport, segments, first_index, anchor) do
    segments
    |> Enum.drop(first_index)
    |> Enum.with_index(first_index)
    |> Enum.reduce(nil, fn {segment, index}, _previous ->
      binary =
        if segment.more_follows do
          assert :incomplete = feed(store, transport, segment)
          nil
        else
          assert {:ok, binary} = feed(store, transport, segment)
          binary
        end

      if rem(index - anchor, segment.window_size) == 0 or not segment.more_follows do
        assert_ack(
          @dest,
          segment.invoke_id,
          segment.sequence_number,
          segment.window_size,
          segment.server
        )
      else
        refute_received {:fake_transport_send, @dest, _data, _opts}
      end

      binary
    end)
  end

  defp rollover_pieces(kind, segment_count, window) do
    payload =
      for index <- 0..(segment_count * @segment_payload_size - 21),
          into: <<>>,
          do: <<rem(div(index, @segment_payload_size), 251)>>

    segments = pieces(kind, 90, window, payload)
    assert length(segments) == segment_count
    segments
  end

  defp test_payload(payload, _value) when is_binary(payload), do: payload
  defp test_payload(bytes, value), do: :binary.copy(<<value>>, bytes)

  defp assert_nak(dest, invoke_id, sequence_number, window, server) do
    assert {%APDU.SegmentACK{
              negative_ack: true,
              sent_by_server: ^server,
              invoke_id: ^invoke_id,
              sequence_number: ^sequence_number,
              actual_window_size: ^window
            }, opts} = take_ack(dest)

    opts
  end

  defp open_role_pair(store, transport, invoke_id) do
    endpoint = SegmentationEndpoint.new(FakeTransport, transport, @dest)

    transfers = %{
      requester: pieces(:ack, invoke_id, 1, 80),
      responder: pieces(:request, invoke_id, 1, 80)
    }

    for {role, [first | _remaining]} <- transfers do
      assert :incomplete = feed_endpoint(store, endpoint, first)
      assert_ack(@dest, invoke_id, 0, 1, role == :responder)
    end

    {endpoint, transfers}
  end

  defp feed_endpoint(store, endpoint, segment) do
    SegmentsStore.segment(
      store,
      segment,
      endpoint.transport_module,
      endpoint.portal,
      endpoint.address,
      destination: endpoint.npci
    )
  end

  defp key(transport, invoke_id, role \\ :responder) do
    {SegmentationEndpoint.new(FakeTransport, transport, @dest), role, invoke_id}
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
    {:ok, value} = Encoding.create({:octet_string, test_payload(bytes, 7)})

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
      ApduFactory.complex_ack(invoke_id, [{:octet_string, test_payload(bytes, 9)}])
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
