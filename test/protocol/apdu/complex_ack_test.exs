defmodule BACnet.Test.Protocol.APDU.ComplexAckTest do
  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Stack.EncoderProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu

  doctest ComplexACK

  test "EncoderProtocol expects reply" do
    assert false ==
             EncoderProtocol.expects_reply(%ComplexACK{
               invoke_id: 70,
               service: :atomic_write_file,
               payload: [tagged: {0, <<1, 184>>, 2}],
               proposed_window_size: nil,
               sequence_number: nil
             })
  end

  test "EncoderProtocol is request" do
    assert false ==
             EncoderProtocol.is_request(%ComplexACK{
               invoke_id: 70,
               service: :atomic_write_file,
               payload: [tagged: {0, <<1, 184>>, 2}],
               proposed_window_size: nil,
               sequence_number: nil
             })
  end

  test "EncoderProtocol is response" do
    assert true ==
             EncoderProtocol.is_response(%ComplexACK{
               invoke_id: 70,
               service: :atomic_write_file,
               payload: [tagged: {0, <<1, 184>>, 2}],
               proposed_window_size: nil,
               sequence_number: nil
             })
  end
end
