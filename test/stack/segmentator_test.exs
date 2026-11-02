defmodule BACnet.Stack.SegmentatorTest do
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
  alias BACnet.Test.Stack.ApduFactory
  alias BACnet.Test.Stack.FakeTransport
  alias BACnet.Test.Stack.FakeTransport.Limited

  use BACnet.Test.Stack.Case, async: true

  @moduletag :stack
  @moduletag :segmentator

  @dest :peer

  setup do
    {:ok, transport} = FakeTransport.start_link()
    {:ok, segmentator} = Segmentator.start_link(apdu_timeout: 60_000, apdu_retries: 1)
    %{transport: transport, segmentator: segmentator}
  end

  test "start_link rejects bad options" do
    assert_raise ArgumentError, ~r/keyword list/, fn ->
      Segmentator.start_link(%{})
    end

    assert_raise ArgumentError, ~r/apdu_retries/, fn ->
      Segmentator.start_link(apdu_retries: :no)
    end

    assert_raise ArgumentError, ~r/apdu_timeout/, fn ->
      Segmentator.start_link(apdu_timeout: :no)
    end
  end

  test "the default retry count resends three times and then times out locally", %{
    transport: transport
  } do
    {:ok, segmentator} = Segmentator.start_link([])
    apdu = confirmed_request(1, 1)

    assert :ok = Segmentator.create_sequence(segmentator, trip(transport), @dest, apdu, 50, 16)

    assert_receive {:fake_transport_postponed, @dest, []}
    assert_sequence(@dest, 0)

    send(segmentator, {:timer, key(transport, 1)})
    send(segmentator, {:timer, key(transport, 1)})
    send(segmentator, {:timer, key(transport, 1)})
    assert_sequence(@dest, 0)
    assert_sequence(@dest, 0)
    assert_sequence(@dest, 0)

    send(segmentator, {:timer, key(transport, 1)})
    refute_receive {:fake_transport_send, _, _, _}, 30
    refute_receive {:fake_transport_send, _, %APDU.Abort{}, _}, 0
  end

  test "configure replaces retries and rejects unsupported options", %{transport: transport} do
    {:ok, segmentator} = Segmentator.start_link(apdu_retries: 5, apdu_timeout: 60_000)

    assert :ok =
             Segmentator.create_sequence(
               segmentator,
               trip(transport),
               @dest,
               confirmed_request(2, 1),
               50,
               16,
               callback_to: self(),
               callback_msg: :configured
             )

    assert_receive {:fake_transport_postponed, @dest, []}
    assert_sequence(@dest, 0)

    assert :ok = Segmentator.configure(segmentator, apdu_retries: 0, apdu_timeout: 60_000)
    send(segmentator, {:timer, key(transport, 2)})
    assert_receive {:timeout, :configured}
    refute_receive {:fake_transport_send, _, %APDU.Abort{}, _}, 0

    assert_raise ArgumentError, ~r/keyword list/, fn ->
      Segmentator.configure(segmentator, [1])
    end

    assert_raise ArgumentError, ~r/apdu_retries/, fn ->
      Segmentator.configure(segmentator, apdu_retries: :no)
    end

    assert_raise ArgumentError, ~r/apdu_timeout/, fn ->
      Segmentator.configure(segmentator, apdu_timeout: :no)
    end

    assert_raise ArgumentError, ~r/does not support option :transport/, fn ->
      Segmentator.configure(segmentator, transport: self())
    end
  end

  test "a registered name is the server", %{transport: transport} do
    name = :"segmentator_coverage_#{System.unique_integer([:positive])}"
    {:ok, pid} = Segmentator.start_link(name: name, apdu_timeout: 60_000, apdu_retries: 0)
    assert Process.whereis(name) == pid

    assert :ok =
             Segmentator.create_sequence(
               name,
               trip(transport),
               @dest,
               confirmed_request(3, 1),
               50,
               2
             )

    assert_receive {:fake_transport_postponed, @dest, []}
    assert_sequence(@dest, 0)
  end

  test "a confirmed request sends the first segment without callback options", %{
    segmentator: segmentator,
    transport: transport
  } do
    apdu = confirmed_request(4, 4)

    assert :ok =
             Segmentator.create_sequence(
               segmentator,
               trip(transport),
               @dest,
               apdu,
               50,
               16,
               callback_to: self(),
               callback_msg: :req,
               track: true
             )

    assert_receive {:fake_transport_postponed, @dest, []}
    assert {%IncompleteAPDU{window_size: 4, more_follows: true}, opts} = assert_sequence(@dest, 0)
    assert opts[:track] == true
    assert opts[:callback_to] == nil
    assert opts[:callback_msg] == nil

    assert_raise ArgumentError, ~r/keyword list/, fn ->
      Segmentator.create_sequence(segmentator, trip(transport), @dest, apdu, 50, 16, [1])
    end

    assert_raise ArgumentError, ~r/keyword list/, fn ->
      Segmentator.create_sequence(
        segmentator,
        trip(transport),
        @dest,
        {apdu, <<0, 0, 0, 0>>},
        50,
        16,
        [1]
      )
    end
  end

  test "a complex ack is segmented and an undersized remote is aborted", %{
    segmentator: segmentator,
    transport: transport
  } do
    ack = complex_ack(5, 2)

    assert :ok = Segmentator.create_sequence(segmentator, trip(transport), @dest, ack, 50, 16)
    assert_receive {:fake_transport_postponed, @dest, []}
    assert_sequence(@dest, 0)

    assert {:error, :too_many_segments} =
             Segmentator.create_sequence(
               segmentator,
               trip(transport),
               :other,
               ack,
               50,
               1,
               callback_to: self(),
               callback_msg: :ignored
             )

    assert_receive {:fake_transport_send, :other,
                    %APDU.Abort{invoke_id: 5, reason: :buffer_overflow, sent_by_server: true},
                    _opts}

    refute_receive {:fake_transport_postponed, :other, _}, 0
  end

  test "preencoded confirmed requests and complex acks are segmented", %{
    segmentator: segmentator,
    transport: transport
  } do
    request = confirmed_request(6, 2)
    raw = IO.iodata_to_binary(EncoderProtocol.encode(request))
    assert length(EncoderProtocol.encode_to_segmented(request, raw, 50)) > 1

    assert :ok =
             Segmentator.create_sequence(
               segmentator,
               trip(transport),
               @dest,
               {request, raw},
               50,
               16
             )

    assert_receive {:fake_transport_postponed, @dest, []}
    assert {%IncompleteAPDU{more_follows: true}, _opts} = assert_sequence(@dest, 0)

    ack = complex_ack(6, 2)
    raw_ack = IO.iodata_to_binary(EncoderProtocol.encode(ack))

    assert :ok =
             Segmentator.create_sequence(
               segmentator,
               trip(transport),
               :ack_peer,
               {ack, raw_ack},
               50,
               16
             )

    assert_receive {:fake_transport_postponed, :ack_peer, []}
    assert_sequence(:ack_peer, 0)
  end

  test "encode failures are returned and nothing is sent", %{
    segmentator: segmentator,
    transport: transport
  } do
    request = confirmed_request(7, 1)

    assert {:error, {{:badmatch, <<1, 2>>}, _stack}} =
             Segmentator.create_sequence(
               segmentator,
               trip(transport),
               @dest,
               {request, <<1, 2>>},
               50,
               16
             )

    refute_receive {:fake_transport_postponed, _, _}, 0
    refute_receive {:fake_transport_send, _, _, _}, 0

    bad = confirmed_request(300, 1)

    assert {:error, {%ArgumentError{}, _stack}} =
             Segmentator.create_sequence(segmentator, trip(transport), @dest, bad, 50, 16)

    refute_receive {:fake_transport_send, _, _, _}, 0
  end

  test "a second sequence for the same destination and invoke id is rejected", %{
    segmentator: segmentator,
    transport: transport
  } do
    apdu = confirmed_request(8, 1)
    assert :ok = Segmentator.create_sequence(segmentator, trip(transport), @dest, apdu, 50, 16)
    assert_receive {:fake_transport_postponed, @dest, []}
    assert_sequence(@dest, 0)

    assert {:error, :already_exists} =
             Segmentator.create_sequence(segmentator, trip(transport), @dest, apdu, 50, 16)

    refute_receive {:fake_transport_postponed, _, _}, 0
    refute_receive {:fake_transport_send, _, _, _}, 0
  end

  test "max_segments 0 does not limit the sequence", %{
    segmentator: segmentator,
    transport: transport
  } do
    assert :ok =
             Segmentator.create_sequence(
               segmentator,
               trip(transport),
               @dest,
               confirmed_request(9, 1),
               50,
               0
             )

    assert_receive {:fake_transport_postponed, @dest, []}
    assert {%IncompleteAPDU{more_follows: true}, _opts} = assert_sequence(@dest, 0)
  end

  test "a failed abort for too many segments is still reported to the caller", %{
    segmentator: segmentator,
    transport: transport
  } do
    assert :ok = FakeTransport.set_send_result(transport, {:error, :nope})

    assert {:error, :too_many_segments} =
             Segmentator.create_sequence(
               segmentator,
               trip(transport),
               @dest,
               confirmed_request(10, 1),
               50,
               1
             )

    assert_receive {:fake_transport_send, @dest,
                    %APDU.Abort{invoke_id: 10, reason: :buffer_overflow, sent_by_server: false},
                    _opts}
  end

  test "routed destinations are sent with window size 1", %{
    segmentator: segmentator,
    transport: transport
  } do
    dest = {:routed, @dest}

    assert :ok =
             Segmentator.create_sequence(
               segmentator,
               trip(transport),
               dest,
               confirmed_request(11, 4),
               50,
               16
             )

    assert_receive {:fake_transport_postponed, ^dest, []}
    assert {%IncompleteAPDU{window_size: 1}, _opts} = assert_sequence(dest, 0)
  end

  test "a transport without reply_postponed still sends the first segment", %{
    transport: transport
  } do
    {:ok, segmentator} = Segmentator.start_link(apdu_timeout: 60_000, apdu_retries: 0)

    assert :ok =
             Segmentator.create_sequence(
               segmentator,
               {Limited, transport, transport},
               @dest,
               confirmed_request(12, 1),
               50,
               16
             )

    refute_receive {:fake_transport_postponed, _, _}, 30
    assert_sequence(@dest, 0)
  end

  test "continuable reply_postponed errors still send the first segment", %{
    segmentator: segmentator,
    transport: transport
  } do
    for dest <- [
          {:postponed, :no_reply_pending},
          {:postponed, :not_expecting}
        ] do
      assert :ok =
               Segmentator.create_sequence(
                 segmentator,
                 trip(transport),
                 dest,
                 confirmed_request(13, 1),
                 50,
                 16
               )

      assert_receive {:fake_transport_postponed, ^dest, []}
      assert_sequence(dest, 0)
    end
  end

  test "a fatal reply_postponed error sends nothing", %{
    segmentator: segmentator,
    transport: transport
  } do
    dest = {:postponed, :slave_mode}

    assert {:error, :slave_mode} =
             Segmentator.create_sequence(
               segmentator,
               trip(transport),
               dest,
               confirmed_request(14, 1),
               50,
               16
             )

    assert_receive {:fake_transport_postponed, ^dest, []}
    refute_receive {:fake_transport_send, _, _, _}, 30
  end

  test "a failed first send does not keep the sequence", %{
    segmentator: segmentator,
    transport: transport
  } do
    apdu = confirmed_request(15, 1)
    assert :ok = FakeTransport.set_send_result(transport, {:error, :down})

    assert {:error, :down} =
             Segmentator.create_sequence(segmentator, trip(transport), @dest, apdu, 50, 16)

    assert_receive {:fake_transport_postponed, @dest, []}
    assert_receive {:fake_transport_send, @dest, _data, _opts}

    assert :ok = FakeTransport.set_send_result(transport, :ok)

    assert :ok = Segmentator.create_sequence(segmentator, trip(transport), @dest, apdu, 50, 16)
    assert_receive {:fake_transport_postponed, @dest, []}
    assert_sequence(@dest, 0)
  end

  test "acks for an unknown sequence are ignored", %{segmentator: segmentator} do
    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(1, sent_by_server: true)
             )

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(1, sent_by_server: true, actual_window_size: 0)
             )

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(1, sent_by_server: true, negative_ack: true)
             )

    assert :ok = Segmentator.handle_apdu(segmentator, @dest, ApduFactory.abort(1))
    assert :ok = Segmentator.handle_apdu(segmentator, @dest, ApduFactory.reject(1))

    assert :ok =
             Segmentator.handle_apdu(segmentator, @dest, %APDU.Error{
               invoke_id: 1,
               service: :read_property,
               class: :device,
               code: :operational_problem,
               payload: []
             })

    refute_receive {:fake_transport_send, _, _, _}, 30
  end

  test "the last segment ack completes the sequence", %{
    segmentator: segmentator,
    transport: transport
  } do
    open_pair(segmentator, transport, 16, callback_msg: :finished)

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(16,
                 sent_by_server: true,
                 sequence_number: 1,
                 actual_window_size: 1
               )
             )

    assert_receive {:done, :finished}
    refute_receive {:fake_transport_send, _, _, _}, 30
  end

  test "completion without a pid callback sends no message", %{
    segmentator: segmentator,
    transport: transport
  } do
    open_pair(segmentator, transport, 17,
      send_opts: [callback_to: :not_a_pid, callback_msg: :nope]
    )

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(17, sent_by_server: true, sequence_number: 1)
             )

    refute_receive {:done, _}, 30
  end

  test "a positive ack sends the next segment", %{
    segmentator: segmentator,
    transport: transport
  } do
    open_pair(segmentator, transport, 18)

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(18,
                 sent_by_server: true,
                 sequence_number: 0,
                 actual_window_size: 1
               )
             )

    assert_sequence(@dest, 1)
  end

  test "a wider window is paced by the sequence timer", %{
    segmentator: segmentator,
    transport: transport
  } do
    apdu = confirmed_request(19, 4, 200)
    assert length(EncoderProtocol.encode_segmented(apdu, 50)) == 5

    assert :ok =
             Segmentator.create_sequence(
               segmentator,
               trip(transport),
               @dest,
               apdu,
               50,
               16,
               callback_to: self(),
               callback_msg: :window
             )

    assert_receive {:fake_transport_postponed, @dest, []}
    assert_sequence(@dest, 0)

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(19,
                 sent_by_server: true,
                 sequence_number: 0,
                 actual_window_size: 4
               )
             )

    assert_sequence(@dest, 1)
    assert_sequence(@dest, 2, 1_000)
    assert_sequence(@dest, 3, 1_000)
    assert_sequence(@dest, 4, 1_000)

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(19,
                 sent_by_server: true,
                 sequence_number: 4,
                 actual_window_size: 1
               )
             )

    assert_receive {:done, :window}
  end

  test "a negative ack resends from the given sequence number", %{
    segmentator: segmentator,
    transport: transport
  } do
    open_pair(segmentator, transport, 20)

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(20,
                 sent_by_server: true,
                 negative_ack: true,
                 sequence_number: 0,
                 actual_window_size: 1
               )
             )

    assert_sequence(@dest, 0)
  end

  test "an out of range window aborts the sequence", %{
    segmentator: segmentator,
    transport: transport
  } do
    open_pair(segmentator, transport, 21, callback_msg: :bad_window)

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(21, actual_window_size: 0, sent_by_server: true)
             )

    assert_receive {:fake_transport_send, @dest,
                    %APDU.Abort{
                      invoke_id: 21,
                      reason: :window_size_out_of_range,
                      sent_by_server: false
                    }, _opts}

    refute_receive {:done, _}, 0

    assert :ok =
             Segmentator.create_sequence(
               segmentator,
               trip(transport),
               @dest,
               confirmed_request(21, 1),
               50,
               16
             )
  end

  test "abort, error, and reject cancel the sequence", %{
    segmentator: segmentator,
    transport: transport
  } do
    open_pair(segmentator, transport, 22, callback_msg: :stop)

    assert :ok = Segmentator.handle_apdu(segmentator, @dest, ApduFactory.abort(22))
    assert_receive {:cancelled, :stop}
    refute_receive {:fake_transport_send, _, %APDU.Abort{}, _}, 0

    open_pair(segmentator, transport, 23, callback_msg: :stop)

    assert :ok =
             Segmentator.handle_apdu(segmentator, @dest, %APDU.Error{
               invoke_id: 23,
               service: :read_property,
               class: :device,
               code: :operational_problem,
               payload: []
             })

    assert_receive {:cancelled, :stop}

    open_pair(segmentator, transport, 24, callback_msg: :stop)
    assert :ok = Segmentator.handle_apdu(segmentator, @dest, ApduFactory.reject(24))
    assert_receive {:cancelled, :stop}
  end

  test "the apdu timer resends once and the final timeout stays local", %{transport: transport} do
    {:ok, segmentator} = Segmentator.start_link(apdu_timeout: 60_000, apdu_retries: 1)

    assert :ok =
             Segmentator.create_sequence(
               segmentator,
               trip(transport),
               @dest,
               confirmed_request(25, 1),
               50,
               16,
               callback_to: self(),
               callback_msg: :timed
             )

    assert_receive {:fake_transport_postponed, @dest, []}
    assert_sequence(@dest, 0)

    send(segmentator, {:timer, key(transport, 25)})
    assert_sequence(@dest, 0)

    send(segmentator, {:timer, key(transport, 25)})
    assert_receive {:timeout, :timed}
    refute_receive {:fake_transport_send, _, %APDU.Abort{}, _}, 0
    refute_receive {:fake_transport_send, _, _, _}, 0
  end

  test "a resend failure leaves the sequence open", %{
    segmentator: segmentator,
    transport: transport
  } do
    open_pair(segmentator, transport, 26, callback_msg: :retry_err)
    assert :ok = FakeTransport.set_send_result(transport, {:error, :down})
    send(segmentator, {:timer, key(transport, 26)})
    assert_sequence(@dest, 0)

    assert :ok = FakeTransport.set_send_result(transport, :ok)

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(26, sent_by_server: true, sequence_number: 1)
             )

    assert_receive {:done, :retry_err}
  end

  test "unknown timer messages are ignored", %{segmentator: segmentator, transport: transport} do
    send(segmentator, {:timer, key(transport, 99)})
    send(segmentator, {:seq_timer, key(transport, 99), 1, 2})

    assert :ok =
             Segmentator.create_sequence(
               segmentator,
               trip(transport),
               @dest,
               confirmed_request(27, 1),
               50,
               16
             )

    assert_receive {:fake_transport_postponed, @dest, []}
    assert_sequence(@dest, 0)
  end

  test "an open window can be completed, restarted, or rejected", %{
    segmentator: segmentator,
    transport: transport
  } do
    open_window(segmentator, transport, 30, :complete)

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(30,
                 sent_by_server: true,
                 sequence_number: 4,
                 actual_window_size: 1
               )
             )

    assert_receive {:done, :complete}
    refute_receive {:fake_transport_send, @dest, _, _}, 30

    open_window(segmentator, transport, 31, :again)

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(31,
                 sent_by_server: true,
                 sequence_number: 0,
                 actual_window_size: 1
               )
             )

    assert_sequence(@dest, 1)

    open_window(segmentator, transport, 32, :nak)

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(32,
                 sent_by_server: true,
                 negative_ack: true,
                 sequence_number: 2,
                 actual_window_size: 1
               )
             )

    assert_sequence(@dest, 2)

    open_window(segmentator, transport, 33, :range)

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(33, sent_by_server: true, actual_window_size: 128)
             )

    assert_receive {:fake_transport_send, @dest, %APDU.Abort{reason: :window_size_out_of_range},
                    _opts}

    open_window(segmentator, transport, 34, :remote)

    assert :ok = Segmentator.handle_apdu(segmentator, @dest, ApduFactory.reject(34))
    assert_receive {:cancelled, :remote}
    refute_receive {:fake_transport_send, @dest, _, _}, 30
  end

  test "the final timeout and a retry cancel a running sequence timer", %{transport: transport} do
    {:ok, segmentator} = Segmentator.start_link(apdu_timeout: 60_000, apdu_retries: 0)
    open_window(segmentator, transport, 35, :final)
    send(segmentator, {:timer, key(transport, 35)})
    assert_receive {:timeout, :final}
    refute_receive {:fake_transport_send, @dest, %APDU.Abort{}, _}, 0

    {:ok, segmentator} = Segmentator.start_link(apdu_timeout: 60_000, apdu_retries: 2)
    open_window(segmentator, transport, 36, :retry)
    assert :ok = FakeTransport.set_send_result(transport, {:error, :down})
    send(segmentator, {:timer, key(transport, 36)})

    # Retry the outstanding window from its first segment, not its last one
    assert_sequence(@dest, 1)

    assert :ok = FakeTransport.set_send_result(transport, :ok)
    assert :ok = Segmentator.handle_apdu(segmentator, @dest, ApduFactory.abort(36))
    assert_receive {:cancelled, :retry}
  end

  test "a failed send inside an open window keeps the sequence", %{
    segmentator: segmentator,
    transport: transport
  } do
    apdu = confirmed_request(37, 4, 200)
    assert length(EncoderProtocol.encode_segmented(apdu, 50)) == 5

    assert :ok =
             Segmentator.create_sequence(
               segmentator,
               trip(transport),
               @dest,
               apdu,
               50,
               16,
               callback_to: self(),
               callback_msg: :wide_err
             )

    assert_receive {:fake_transport_postponed, @dest, []}
    assert_sequence(@dest, 0)
    assert :ok = FakeTransport.set_send_result(transport, {:error, :down})

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(37,
                 sent_by_server: true,
                 sequence_number: 0,
                 actual_window_size: 2
               )
             )

    assert_sequence(@dest, 1)
    assert :ok = FakeTransport.set_send_result(transport, :ok)
    assert :ok = Segmentator.handle_apdu(segmentator, @dest, ApduFactory.abort(37))
    assert_receive {:cancelled, :wide_err}
  end

  test "final partial window survives delayed ACK (negative_ack=false)" do
    transport = start_supervised!({FakeTransport, owner: self()})
    segmentator = start_supervised!({Segmentator, apdu_timeout: 60_000})
    monitor = Process.monitor(segmentator)

    apdu = %{
      ApduFactory.complex_ack(1, octet_string: :binary.copy(<<7>>, 100))
      | sequence_number: 0,
        proposed_window_size: 4
    }

    assert :ok =
             Segmentator.create_sequence(
               segmentator,
               {FakeTransport, transport, transport},
               :peer,
               apdu,
               50,
               16,
               callback_to: self(),
               callback_msg: :completed
             )

    assert_segment(0)

    ack =
      ApduFactory.segment_ack(1,
        sent_by_server: false,
        negative_ack: false,
        sequence_number: 0,
        actual_window_size: 4
      )

    assert :ok = Segmentator.handle_apdu(segmentator, :peer, ack)
    assert_segment(1)
    assert_segment(2)

    # Withhold the final ACK past the pacing interval. The sender must stop
    # at the real final segment instead of trying to send map key 3
    refute_receive {:DOWN, ^monitor, :process, ^segmentator, _reason}, 200
    assert Process.alive?(segmentator)

    # A retry must repeat this partial window, without returning to the
    # previous window or starting beyond the final segment
    send(
      segmentator,
      {:timer, {SegmentationEndpoint.new(FakeTransport, transport, @dest), :responder, 1}}
    )

    assert_segment(1)
    assert_segment(2)
    refute_receive {:DOWN, ^monitor, :process, ^segmentator, _reason}, 200

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               :peer,
               ApduFactory.segment_ack(1,
                 sent_by_server: false,
                 sequence_number: 2,
                 actual_window_size: 4
               )
             )

    assert_receive {:done, :completed}
  end

  test "final partial window survives delayed ACK (negative_ack=true)" do
    transport = start_supervised!({FakeTransport, owner: self()})
    segmentator = start_supervised!({Segmentator, apdu_timeout: 60_000})
    monitor = Process.monitor(segmentator)

    apdu = %{
      ApduFactory.complex_ack(1, octet_string: :binary.copy(<<7>>, 100))
      | sequence_number: 0,
        proposed_window_size: 4
    }

    assert :ok =
             Segmentator.create_sequence(
               segmentator,
               {FakeTransport, transport, transport},
               :peer,
               apdu,
               50,
               16,
               callback_to: self(),
               callback_msg: :completed
             )

    assert_segment(0)

    ack =
      ApduFactory.segment_ack(1,
        sent_by_server: false,
        negative_ack: true,
        sequence_number: 1,
        actual_window_size: 4
      )

    assert :ok = Segmentator.handle_apdu(segmentator, :peer, ack)
    assert_segment(1)
    assert_segment(2)

    # Withhold the final ACK past the pacing interval. The sender must stop
    # at the real final segment instead of trying to send map key 3
    refute_receive {:DOWN, ^monitor, :process, ^segmentator, _reason}, 200
    assert Process.alive?(segmentator)

    # A retry must repeat this partial window, without returning to the
    # previous window or starting beyond the final segment
    send(
      segmentator,
      {:timer, {SegmentationEndpoint.new(FakeTransport, transport, @dest), :responder, 1}}
    )

    assert_segment(1)
    assert_segment(2)
    refute_receive {:DOWN, ^monitor, :process, ^segmentator, _reason}, 200

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               :peer,
               ApduFactory.segment_ack(1,
                 sent_by_server: false,
                 sequence_number: 2,
                 actual_window_size: 4
               )
             )

    assert_receive {:done, :completed}
  end

  test "a negative ack resends only the negotiated number of segments", %{
    segmentator: segmentator,
    transport: transport
  } do
    apdu = %{complex_ack(38, 4) | payload: [octet_string: :binary.copy(<<7>>, 100)]}

    assert :ok =
             Segmentator.create_sequence(segmentator, trip(transport), @dest, apdu, 50, 16,
               callback_to: self(),
               callback_msg: :bounded_window
             )

    assert_sequence(@dest, 0)

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(38,
                 sent_by_server: false,
                 negative_ack: true,
                 sequence_number: 0,
                 actual_window_size: 2
               )
             )

    assert_sequence(@dest, 0)
    assert_sequence(@dest, 1, 1_000)
    refute_receive {:fake_transport_send, @dest, _, _}, 150

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(38,
                 sent_by_server: false,
                 sequence_number: 1,
                 actual_window_size: 2
               )
             )

    assert_sequence(@dest, 2)

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(38,
                 sent_by_server: false,
                 sequence_number: 2,
                 actual_window_size: 2
               )
             )

    assert_receive {:done, :bounded_window}
  end

  test "ACKs, NAKs, completion and callbacks isolate networks, portals and modules", %{
    segmentator: segmentator,
    transport: transport
  } do
    other_portal = start_supervised!({FakeTransport, owner: self()})
    target = %NpciTarget{net: 10, address: 7}

    endpoints = [
      SegmentationEndpoint.new(FakeTransport, transport, @dest, destination: target),
      SegmentationEndpoint.new(FakeTransport, transport, @dest, destination: %{target | net: 20}),
      SegmentationEndpoint.new(FakeTransport, other_portal, @dest, destination: target),
      SegmentationEndpoint.new(Limited, transport, @dest, destination: target)
    ]

    for endpoint <- endpoints do
      assert :ok = create_endpoint_sequence(segmentator, endpoint, transport, 60)
      assert_sequence(@dest, 0)
    end

    sequences = :sys.get_state(segmentator).sequences
    assert map_size(sequences) == 4
    assert :ok = Segmentator.handle_apdu(segmentator, @dest, ApduFactory.abort(60))
    assert :sys.get_state(segmentator).sequences == sequences

    for endpoint <- Enum.reverse(endpoints) do
      other_sequences =
        Map.delete(:sys.get_state(segmentator).sequences, {endpoint, :requester, 60})

      assert :ok =
               Segmentator.handle_apdu(
                 segmentator,
                 endpoint,
                 ApduFactory.segment_ack(60,
                   sent_by_server: true,
                   sequence_number: 0,
                   actual_window_size: 1
                 )
               )

      assert {%IncompleteAPDU{}, opts} = assert_sequence(@dest, 1)
      assert opts[:destination] == endpoint.npci

      assert Map.delete(:sys.get_state(segmentator).sequences, {endpoint, :requester, 60}) ==
               other_sequences

      assert :ok =
               Segmentator.handle_apdu(
                 segmentator,
                 endpoint,
                 ApduFactory.segment_ack(60,
                   sent_by_server: true,
                   negative_ack: true,
                   sequence_number: 1,
                   actual_window_size: 1
                 )
               )

      assert_sequence(@dest, 1)

      last = map_size(sequences[{endpoint, :requester, 60}].segments) - 1

      assert :ok =
               Segmentator.handle_apdu(
                 segmentator,
                 endpoint,
                 ApduFactory.segment_ack(60,
                   sent_by_server: true,
                   sequence_number: last,
                   actual_window_size: 1
                 )
               )

      assert_receive {:done, ^endpoint}
      assert :sys.get_state(segmentator).sequences == other_sequences
    end
  end

  test "remote failures and invalid ACK windows cancel only the exact endpoint", %{
    segmentator: segmentator,
    transport: transport
  } do
    first =
      SegmentationEndpoint.new(FakeTransport, transport, @dest,
        destination: %NpciTarget{net: 10, address: 7}
      )

    second = %{first | npci: %{first.npci | net: 20}}

    for canceller <- [
          ApduFactory.abort(61),
          ApduFactory.reject(61),
          %APDU.Error{
            invoke_id: 61,
            service: :read_property,
            class: :device,
            code: :operational_problem,
            payload: []
          },
          ApduFactory.segment_ack(61, sent_by_server: true, actual_window_size: 0)
        ] do
      for endpoint <- [first, second] do
        assert :ok = create_endpoint_sequence(segmentator, endpoint, transport, 61)
        assert_sequence(@dest, 0)
      end

      sequences = :sys.get_state(segmentator).sequences
      assert :ok = Segmentator.handle_apdu(segmentator, first, canceller)
      assert Process.read_timer(sequences[{first, :requester, 61}].timer) == false

      assert :sys.get_state(segmentator).sequences ==
               Map.delete(sequences, {first, :requester, 61})

      if is_struct(canceller, APDU.SegmentACK) do
        assert_receive {:fake_transport_send, @dest,
                        %APDU.Abort{reason: :window_size_out_of_range}, opts}

        assert opts[:destination] == first.npci
      else
        assert_receive {:cancelled, ^first}
      end

      assert :ok = Segmentator.handle_apdu(segmentator, second, ApduFactory.abort(61))
      assert_receive {:cancelled, ^second}
    end
  end

  test "retry, window pacing and timeout messages retain the complete endpoint", %{
    transport: transport
  } do
    segmentator = start_supervised!({Segmentator, apdu_timeout: 60_000, apdu_retries: 1})

    first =
      SegmentationEndpoint.new(FakeTransport, transport, @dest,
        destination: %NpciTarget{net: 10, address: 7}
      )

    second = %{first | npci: %{first.npci | net: 20}}

    for endpoint <- [first, second] do
      assert :ok = create_endpoint_sequence(segmentator, endpoint, transport, 62)
      assert_sequence(@dest, 0)
    end

    sequences = :sys.get_state(segmentator).sequences

    send(segmentator, {:timer, {first, :requester, 62}})
    assert_sequence(@dest, 0)
    assert :sys.get_state(segmentator).sequences[{first, :requester, 62}].retry_count == 1

    assert :sys.get_state(segmentator).sequences[{second, :requester, 62}] ==
             sequences[{second, :requester, 62}]

    send(segmentator, {:timer, {first, :requester, 62}})
    assert_receive {:timeout, ^first}
    assert :sys.get_state(segmentator).sequences == Map.delete(sequences, {first, :requester, 62})

    # A paced window must send every segment with the selected endpoint's options.
    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               second,
               ApduFactory.segment_ack(62,
                 sent_by_server: true,
                 actual_window_size: 4,
                 sequence_number: 0
               )
             )

    assert {_segment, opts} = assert_sequence(@dest, 1)
    assert opts[:destination] == second.npci
    assert {_segment, opts} = assert_sequence(@dest, 2)
    assert opts[:destination] == second.npci
    assert {_segment, opts} = assert_sequence(@dest, 3)
    assert opts[:destination] == second.npci
    assert {_segment, opts} = assert_sequence(@dest, 4)
    assert opts[:destination] == second.npci

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               second,
               ApduFactory.segment_ack(62,
                 sent_by_server: true,
                 actual_window_size: 4,
                 sequence_number: 4
               )
             )

    assert_receive {:done, ^second}
    assert :sys.get_state(segmentator).sequences == %{}
  end

  test "explicit NPCI destination scopes creation and overrides the destination option", %{
    segmentator: segmentator,
    transport: transport
  } do
    target = %NpciTarget{net: 10, address: 7}
    other_target = %{target | net: 20}
    endpoint = SegmentationEndpoint.new(FakeTransport, transport, @dest, destination: target)

    assert :ok =
             Segmentator.create_sequence(
               segmentator,
               trip(transport),
               @dest,
               confirmed_request(63, 1),
               50,
               16,
               npci: NPCI.new(destination: target),
               destination: other_target
             )

    assert_sequence(@dest, 0)

    assert {:error, :already_exists} =
             Segmentator.create_sequence(
               segmentator,
               trip(transport),
               @dest,
               confirmed_request(63, 1),
               50,
               16,
               destination: target
             )

    assert :ok =
             Segmentator.create_sequence(
               segmentator,
               trip(transport),
               @dest,
               confirmed_request(63, 1),
               50,
               16,
               destination: other_target
             )

    assert_sequence(@dest, 0)
    assert :ok = Segmentator.handle_apdu(segmentator, endpoint, ApduFactory.abort(63))
    assert map_size(:sys.get_state(segmentator).sequences) == 1
  end

  test "both local roles progress independently at one endpoint and invoke ID", %{
    segmentator: sender,
    transport: transport
  } do
    for lookup <- [:address, :endpoint] do
      endpoint = open_role_pair(sender, transport, 80)
      peer = if lookup == :address, do: @dest, else: endpoint

      for role <- [:responder, :requester] do
        id = {endpoint, role, 80}
        other = Map.delete(:sys.get_state(sender).sequences, id)
        last = map_size(:sys.get_state(sender).sequences[id].segments) - 1
        ack = ApduFactory.segment_ack(80, sent_by_server: role == :requester)
        assert :ok = Segmentator.handle_apdu(sender, peer, ack)
        assert {%IncompleteAPDU{server: server}, _opts} = assert_sequence(@dest, 1)
        assert server == (role == :requester)
        assert Map.delete(:sys.get_state(sender).sequences, id) == other

        assert :ok =
                 Segmentator.handle_apdu(sender, peer, %{
                   ack
                   | negative_ack: true,
                     sequence_number: 1
                 })

        assert_sequence(@dest, 1)
        timer = :sys.get_state(sender).sequences[id].timer

        for number <- 1..last do
          assert :ok = Segmentator.handle_apdu(sender, peer, %{ack | sequence_number: number})
          if number < last, do: assert_sequence(@dest, number + 1)
        end

        assert_receive {:done, {^role, 80}}
        assert Process.read_timer(timer) == false
        assert :sys.get_state(sender).sequences == other
        # Replaying an ACK for the removed role must not complete the opposite role.
        assert :ok = Segmentator.handle_apdu(sender, peer, %{ack | sequence_number: last})
        assert :sys.get_state(sender).sequences == other
      end
    end
  end

  test "terminal APDUs and invalid windows select their role with either peer representation", %{
    segmentator: sender,
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
      {:requester, ApduFactory.reject(81)},
      {:requester, error},
      {:requester, ApduFactory.segment_ack(81, sent_by_server: true, actual_window_size: 0)},
      {:responder, ApduFactory.segment_ack(81, sent_by_server: false, actual_window_size: 0)}
    ]

    for lookup <- [:address, :endpoint], {role, apdu} <- cases do
      endpoint = open_role_pair(sender, transport, 81)
      peer = if lookup == :address, do: @dest, else: endpoint
      id = {endpoint, role, 81}
      sequences = :sys.get_state(sender).sequences
      assert :ok = Segmentator.handle_apdu(sender, peer, apdu)
      assert :sys.get_state(sender).sequences == Map.delete(sequences, id)
      assert Process.read_timer(sequences[id].timer) == false

      if is_struct(apdu, APDU.SegmentACK) do
        assert_receive {:fake_transport_send, @dest, %APDU.Abort{} = abort, _opts}
        assert abort.sent_by_server == (role == :responder)
      else
        assert_receive {:cancelled, {^role, 81}}
      end

      # A repeated terminal message cannot cancel the other role either.
      assert :ok = Segmentator.handle_apdu(sender, peer, apdu)
      assert :sys.get_state(sender).sequences == Map.delete(sequences, id)

      for remaining_role <- [:requester, :responder] -- [role] do
        assert :ok =
                 Segmentator.handle_apdu(sender, endpoint, %{
                   ApduFactory.abort(81)
                   | sent_by_server: remaining_role == :requester
                 })

        assert_receive {:cancelled, {^remaining_role, 81}}
      end
    end
  end

  test "paced windows, retries and final timeouts remain local to each role", %{
    transport: transport
  } do
    sender = start_supervised!({Segmentator, apdu_timeout: 60_000, apdu_retries: 1})

    for role <- [:requester, :responder] do
      endpoint = open_role_pair(sender, transport, 82, 4, 200)
      id = {endpoint, role, 82}
      other = Map.delete(:sys.get_state(sender).sequences, id)

      assert :ok =
               Segmentator.handle_apdu(
                 sender,
                 endpoint,
                 ApduFactory.segment_ack(82,
                   sent_by_server: role == :requester,
                   actual_window_size: 2
                 )
               )

      assert_sequence(@dest, 1)
      assert_sequence(@dest, 2)
      assert Map.delete(:sys.get_state(sender).sequences, id) == other
      send(sender, {:timer, id})
      assert_sequence(@dest, 1)
      assert_sequence(@dest, 2)
      assert Map.delete(:sys.get_state(sender).sequences, id) == other
      send(sender, {:timer, id})
      assert_receive {:timeout, {^role, 82}}
      assert :sys.get_state(sender).sequences == other
      [{{_endpoint, other_role, 82}, _sequence}] = Map.to_list(other)

      assert :ok =
               Segmentator.handle_apdu(sender, endpoint, %{
                 ApduFactory.abort(82)
                 | sent_by_server: other_role == :requester
               })

      assert_receive {:cancelled, {^other_role, 82}}
    end
  end

  defp open_role_pair(sender, transport, invoke_id, window \\ 1, bytes \\ 80) do
    endpoint = SegmentationEndpoint.new(FakeTransport, transport, @dest)

    response = %{
      complex_ack(invoke_id, window)
      | payload: [octet_string: :binary.copy(<<9>>, bytes)]
    }

    for {role, apdu} <- [
          {:requester, confirmed_request(invoke_id, window, bytes)},
          {:responder, response}
        ] do
      assert :ok =
               Segmentator.create_sequence(sender, trip(transport), @dest, apdu, 50, 16,
                 callback_to: self(),
                 callback_msg: {role, invoke_id}
               )

      assert_sequence(@dest, 0)
    end

    endpoint
  end

  defp create_endpoint_sequence(segmentator, endpoint, transport, invoke_id) do
    Segmentator.create_sequence(
      segmentator,
      {endpoint.transport_module, transport, endpoint.portal},
      endpoint.address,
      confirmed_request(invoke_id, 4, 200),
      50,
      16,
      destination: endpoint.npci,
      callback_to: self(),
      callback_msg: endpoint
    )
  end

  defp key(transport, invoke_id) do
    {SegmentationEndpoint.new(FakeTransport, transport, @dest), :requester, invoke_id}
  end

  defp assert_segment(number) do
    assert_receive {:fake_transport_send, :peer, bytes, _opts}, 1_000
    assert {:incomplete, %{sequence_number: ^number}} = APDU.decode(IO.iodata_to_binary(bytes))
  end

  defp open_pair(segmentator, transport, invoke_id, opts \\ []) do
    send_opts =
      Keyword.get(opts, :send_opts,
        callback_to: self(),
        callback_msg: Keyword.get(opts, :callback_msg, :pair)
      )

    assert :ok =
             Segmentator.create_sequence(
               segmentator,
               trip(transport),
               @dest,
               confirmed_request(invoke_id, 1),
               50,
               16,
               send_opts
             )

    assert_receive {:fake_transport_postponed, @dest, []}
    assert_sequence(@dest, 0)
  end

  defp open_window(segmentator, transport, invoke_id, msg) do
    apdu = confirmed_request(invoke_id, 4, 200)
    assert length(EncoderProtocol.encode_segmented(apdu, 50)) == 5

    assert :ok =
             Segmentator.create_sequence(
               segmentator,
               trip(transport),
               @dest,
               apdu,
               50,
               16,
               callback_to: self(),
               callback_msg: msg
             )

    assert_receive {:fake_transport_postponed, @dest, []}
    assert_sequence(@dest, 0)

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(invoke_id,
                 sent_by_server: true,
                 sequence_number: 0,
                 actual_window_size: 2
               )
             )

    assert_sequence(@dest, 1)
  end

  defp assert_sequence(dest, sequence_number, timeout \\ 1_000) do
    assert_receive {:fake_transport_send, ^dest, data, opts}, timeout

    assert {:incomplete, %IncompleteAPDU{sequence_number: ^sequence_number} = incomplete} =
             APDU.decode(IO.iodata_to_binary(data))

    {incomplete, opts}
  end

  defp trip(transport), do: {FakeTransport, transport, transport}

  # Keep the default fixture within two complete 50-byte APDUs, including headers
  defp confirmed_request(invoke_id, window, bytes \\ 70) do
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

    %{request | sequence_number: 0, proposed_window_size: window}
  end

  defp complex_ack(invoke_id, window) do
    %{
      ApduFactory.complex_ack(invoke_id, [{:octet_string, :binary.copy(<<9>>, 80)}])
      | sequence_number: 0,
        proposed_window_size: window
    }
  end
end
