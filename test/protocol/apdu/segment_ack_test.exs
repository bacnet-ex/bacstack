defmodule BACnet.Test.Protocol.APDU.SegmentAckTest do
  alias BACnet.Protocol.APDU.SegmentACK
  alias BACnet.Stack.EncoderProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu

  doctest SegmentACK

  test "EncoderProtocol expects reply" do
    assert false ==
             EncoderProtocol.expects_reply(%SegmentACK{
               negative_ack: false,
               sent_by_server: true,
               invoke_id: 70,
               sequence_number: 2,
               actual_window_size: 16
             })
  end

  test "EncoderProtocol is request" do
    assert false ==
             EncoderProtocol.is_request(%SegmentACK{
               negative_ack: false,
               sent_by_server: true,
               invoke_id: 70,
               sequence_number: 2,
               actual_window_size: 16
             })
  end

  test "EncoderProtocol is response" do
    assert true ==
             EncoderProtocol.is_response(%SegmentACK{
               negative_ack: false,
               sent_by_server: true,
               invoke_id: 70,
               sequence_number: 2,
               actual_window_size: 16
             })
  end
end
