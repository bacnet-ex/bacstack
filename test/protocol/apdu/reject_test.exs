defmodule BACnet.Test.Protocol.APDU.RejectTest do
  alias BACnet.Protocol.APDU.Reject
  alias BACnet.Stack.EncoderProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu

  doctest Reject

  test "EncoderProtocol expects reply" do
    assert false ==
             EncoderProtocol.expects_reply(%Reject{
               invoke_id: 70,
               reason: :buffer_overflow
             })
  end

  test "EncoderProtocol is request" do
    assert false ==
             EncoderProtocol.is_request(%Reject{
               invoke_id: 70,
               reason: :buffer_overflow
             })
  end

  test "EncoderProtocol is response" do
    assert true ==
             EncoderProtocol.is_response(%Reject{
               invoke_id: 70,
               reason: :buffer_overflow
             })
  end
end
