defmodule BACnet.Test.Protocol.APDU.AbortTest do
  alias BACnet.Protocol.APDU.Abort
  alias BACnet.Stack.EncoderProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu

  doctest Abort

  test "EncoderProtocol expects reply" do
    assert false ==
             EncoderProtocol.expects_reply(%Abort{
               sent_by_server: true,
               invoke_id: 70,
               reason: :application_exceeded_reply_time
             })
  end

  test "EncoderProtocol is request" do
    assert false ==
             EncoderProtocol.is_request(%Abort{
               sent_by_server: true,
               invoke_id: 70,
               reason: :application_exceeded_reply_time
             })
  end

  test "EncoderProtocol is response" do
    assert true ==
             EncoderProtocol.is_response(%Abort{
               sent_by_server: true,
               invoke_id: 70,
               reason: :application_exceeded_reply_time
             })
  end
end
