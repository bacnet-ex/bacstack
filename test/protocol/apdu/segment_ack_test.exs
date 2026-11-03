defmodule BACnet.Test.Protocol.APDU.SegmentAckTest do
  alias BACnet.Protocol.APDU
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
             EncoderProtocol.request?(%SegmentACK{
               negative_ack: false,
               sent_by_server: true,
               invoke_id: 70,
               sequence_number: 2,
               actual_window_size: 16
             })
  end

  test "EncoderProtocol is response" do
    assert true ==
             EncoderProtocol.response?(%SegmentACK{
               negative_ack: false,
               sent_by_server: true,
               invoke_id: 70,
               sequence_number: 2,
               actual_window_size: 16
             })
  end

  test "EncoderProtocol supports segmentation" do
    assert false ==
             EncoderProtocol.supports_segmentation(%SegmentACK{
               negative_ack: false,
               sent_by_server: true,
               invoke_id: 70,
               sequence_number: 2,
               actual_window_size: 16
             })
  end

  test "EncoderProtocol encodes both acknowledgement bits" do
    ack = %SegmentACK{
      negative_ack: false,
      sent_by_server: true,
      invoke_id: 12,
      sequence_number: 3,
      actual_window_size: 16
    }

    assert raw(ack) == <<65, 12, 3, 16>>

    for negative_ack <- [false, true], sent_by_server <- [false, true] do
      apdu = %{ack | negative_ack: negative_ack, sent_by_server: sent_by_server}
      assert {:ok, ^apdu} = APDU.decode(raw(apdu))
    end

    for actual_window_size <- [0, 255] do
      apdu = %{ack | actual_window_size: actual_window_size}
      assert {:ok, ^apdu} = APDU.decode(raw(apdu))
    end

    assert_raise ArgumentError, ~r/Invoke ID/, fn ->
      EncoderProtocol.encode(%{ack | invoke_id: -1})
    end

    assert_raise ArgumentError, ~r/Sequence number/, fn ->
      EncoderProtocol.encode(%{ack | sequence_number: 256})
    end

    assert_raise ArgumentError, ~r/Actual window size/, fn ->
      EncoderProtocol.encode(%{ack | actual_window_size: -1})
    end

    refute_segmentation(ack)
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
