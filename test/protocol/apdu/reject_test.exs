defmodule BACnet.Test.Protocol.APDU.RejectTest do
  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.APDU.Reject
  alias BACnet.Protocol.Constants
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
             EncoderProtocol.request?(%Reject{
               invoke_id: 70,
               reason: :buffer_overflow
             })
  end

  test "EncoderProtocol is response" do
    assert true ==
             EncoderProtocol.response?(%Reject{
               invoke_id: 70,
               reason: :buffer_overflow
             })
  end

  test "EncoderProtocol supports segmentation" do
    assert false ==
             EncoderProtocol.supports_segmentation(%Reject{
               invoke_id: 70,
               reason: :buffer_overflow
             })
  end

  test "EncoderProtocol encodes the reason" do
    reject = %Reject{invoke_id: 9, reason: :buffer_overflow}

    assert raw(reject) == <<96, 9, 1>>
    assert {:ok, ^reject} = APDU.decode(raw(reject))

    reason = Constants.by_name!(:reject_reason, :buffer_overflow)
    assert raw(reject) == raw(%{reject | reason: reason})

    numbered = %{reject | invoke_id: 255, reason: 250}
    assert {:ok, ^numbered} = APDU.decode(raw(numbered))

    assert_raise ArgumentError, ~r/Invoke ID/, fn ->
      EncoderProtocol.encode(%{reject | invoke_id: -1})
    end

    refute_segmentation(reject)
  end

  defp refute_segmentation(apdu) do
    assert_raise RuntimeError, "Illegal function call, APDU can not be segmented", fn ->
      EncoderProtocol.encode_segmented(apdu, 50)
    end

    assert_raise RuntimeError, "Illegal function call, APDU can not be segmented", fn ->
      EncoderProtocol.encode_to_segmented(apdu, <<0>>, 50)
    end
  end

  defp raw(apdu), do: IO.iodata_to_binary(EncoderProtocol.encode(apdu))
end
