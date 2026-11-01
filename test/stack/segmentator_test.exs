defmodule BACnet.Stack.SegmentatorTest do
  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.IncompleteAPDU
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.WriteProperty
  alias BACnet.Stack.EncoderProtocol
  alias BACnet.Stack.Segmentator
  alias BACnet.Test.Stack.ApduFactory
  alias BACnet.Test.Stack.FakeTransport
  alias BACnet.Test.Stack.FakeTransport.Limited

  use ExUnit.Case, async: true

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

    send(segmentator, {:timer, {@dest, 1}})
    send(segmentator, {:timer, {@dest, 1}})
    send(segmentator, {:timer, {@dest, 1}})
    assert_sequence(@dest, 0)
    assert_sequence(@dest, 0)
    assert_sequence(@dest, 0)

    send(segmentator, {:timer, {@dest, 1}})
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
    send(segmentator, {:timer, {@dest, 2}})
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
    assert :ok = Segmentator.handle_apdu(segmentator, @dest, ApduFactory.segment_ack(1))

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(1, actual_window_size: 0)
             )

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(1, negative_ack: true)
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
               ApduFactory.segment_ack(16, sequence_number: 1, actual_window_size: 1)
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
               ApduFactory.segment_ack(17, sequence_number: 1)
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
               ApduFactory.segment_ack(18, sequence_number: 0, actual_window_size: 1)
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
               ApduFactory.segment_ack(19, sequence_number: 0, actual_window_size: 4)
             )

    assert_sequence(@dest, 1)
    assert_sequence(@dest, 2, 1_000)
    assert_sequence(@dest, 3, 1_000)
    assert_sequence(@dest, 4, 1_000)

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(19, sequence_number: 4, actual_window_size: 1)
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
               ApduFactory.segment_ack(21, actual_window_size: 0, sent_by_server: false)
             )

    assert_receive {:fake_transport_send, @dest,
                    %APDU.Abort{
                      invoke_id: 21,
                      reason: :window_size_out_of_range,
                      sent_by_server: true
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

    send(segmentator, {:timer, {@dest, 25}})
    assert_sequence(@dest, 0)

    send(segmentator, {:timer, {@dest, 25}})
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
    send(segmentator, {:timer, {@dest, 26}})
    assert_sequence(@dest, 0)

    assert :ok = FakeTransport.set_send_result(transport, :ok)

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(26, sequence_number: 1)
             )

    assert_receive {:done, :retry_err}
  end

  test "unknown timer messages are ignored", %{segmentator: segmentator, transport: transport} do
    send(segmentator, {:timer, {@dest, 99}})
    send(segmentator, {:seq_timer, {@dest, 99}, 1, 2})

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
               ApduFactory.segment_ack(30, sequence_number: 4, actual_window_size: 1)
             )

    assert_receive {:done, :complete}
    refute_receive {:fake_transport_send, @dest, _, _}, 30

    open_window(segmentator, transport, 31, :again)

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(31, sequence_number: 0, actual_window_size: 1)
             )

    assert_sequence(@dest, 1)

    open_window(segmentator, transport, 32, :nak)

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(32,
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
               ApduFactory.segment_ack(33, actual_window_size: 128)
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
    send(segmentator, {:timer, {@dest, 35}})
    assert_receive {:timeout, :final}
    refute_receive {:fake_transport_send, @dest, %APDU.Abort{}, _}, 0

    {:ok, segmentator} = Segmentator.start_link(apdu_timeout: 60_000, apdu_retries: 2)
    open_window(segmentator, transport, 36, :retry)
    assert :ok = FakeTransport.set_send_result(transport, {:error, :down})
    send(segmentator, {:timer, {@dest, 36}})

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
               ApduFactory.segment_ack(37, sequence_number: 0, actual_window_size: 2)
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
    send(segmentator, {:timer, {:peer, 1}})
    assert_segment(1)
    assert_segment(2)
    refute_receive {:DOWN, ^monitor, :process, ^segmentator, _reason}, 200

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               :peer,
               ApduFactory.segment_ack(1, sequence_number: 2, actual_window_size: 4)
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
    send(segmentator, {:timer, {:peer, 1}})
    assert_segment(1)
    assert_segment(2)
    refute_receive {:DOWN, ^monitor, :process, ^segmentator, _reason}, 200

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               :peer,
               ApduFactory.segment_ack(1, sequence_number: 2, actual_window_size: 4)
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
               ApduFactory.segment_ack(38, sequence_number: 1, actual_window_size: 2)
             )

    assert_sequence(@dest, 2)

    assert :ok =
             Segmentator.handle_apdu(
               segmentator,
               @dest,
               ApduFactory.segment_ack(38, sequence_number: 2, actual_window_size: 2)
             )

    assert_receive {:done, :bounded_window}
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
               ApduFactory.segment_ack(invoke_id, sequence_number: 0, actual_window_size: 2)
             )

    assert_sequence(@dest, 1)
  end

  defp assert_sequence(dest, sequence_number, timeout \\ 100) do
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
