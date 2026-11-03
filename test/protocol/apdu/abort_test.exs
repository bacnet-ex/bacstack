defmodule BACnet.Test.Protocol.APDU.AbortTest do
  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.APDU.Abort
  alias BACnet.Protocol.Constants
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
             EncoderProtocol.request?(%Abort{
               sent_by_server: true,
               invoke_id: 70,
               reason: :application_exceeded_reply_time
             })
  end

  test "EncoderProtocol is response" do
    assert true ==
             EncoderProtocol.response?(%Abort{
               sent_by_server: true,
               invoke_id: 70,
               reason: :application_exceeded_reply_time
             })
  end

  test "EncoderProtocol supports segmentation" do
    assert false ==
             EncoderProtocol.supports_segmentation(%Abort{
               sent_by_server: true,
               invoke_id: 70,
               reason: :application_exceeded_reply_time
             })
  end

  test "EncoderProtocol encodes the server bit" do
    abort = %Abort{
      sent_by_server: true,
      invoke_id: 7,
      reason: :segmentation_not_supported
    }

    assert raw(abort) == <<0x71, 0x07, 0x04>>
    assert {:ok, ^abort} = APDU.decode(raw(abort))

    reason = Constants.by_name!(:abort_reason, :segmentation_not_supported)
    assert raw(abort) == raw(%{abort | reason: reason})

    client = %{abort | sent_by_server: false, invoke_id: 0, reason: 250}
    assert {:ok, ^client} = APDU.decode(raw(client))

    assert_raise ArgumentError, ~r/Invoke ID/, fn ->
      EncoderProtocol.encode(%{abort | invoke_id: 256})
    end

    refute_segmentation(abort)
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
