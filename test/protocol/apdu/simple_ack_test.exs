defmodule BACnet.Test.Protocol.APDU.SimpleAckTest do
  alias BACnet.Protocol.APDU.SimpleACK
  alias BACnet.Stack.EncoderProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu

  doctest SimpleACK

  test "EncoderProtocol expects reply" do
    assert false ==
             EncoderProtocol.expects_reply(%SimpleACK{
               service: :write_property,
               invoke_id: 70
             })
  end

  test "EncoderProtocol is request" do
    assert false ==
             EncoderProtocol.is_request(%SimpleACK{
               service: :write_property,
               invoke_id: 70
             })
  end

  test "EncoderProtocol is response" do
    assert true ==
             EncoderProtocol.is_response(%SimpleACK{
               service: :write_property,
               invoke_id: 70
             })
  end
end
