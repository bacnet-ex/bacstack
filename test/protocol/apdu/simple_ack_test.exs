defmodule BACnet.Test.Protocol.APDU.SimpleAckTest do
  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.APDU.SimpleACK
  alias BACnet.Protocol.Constants
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
             EncoderProtocol.request?(%SimpleACK{
               service: :write_property,
               invoke_id: 70
             })
  end

  test "EncoderProtocol is response" do
    assert true ==
             EncoderProtocol.response?(%SimpleACK{
               service: :write_property,
               invoke_id: 70
             })
  end

  test "EncoderProtocol supports segmentation" do
    assert false ==
             EncoderProtocol.supports_segmentation(%SimpleACK{
               service: :write_property,
               invoke_id: 70
             })
  end

  test "EncoderProtocol encodes the service" do
    ack = %SimpleACK{invoke_id: 70, service: :write_property}

    assert raw(ack) == <<32, 70, 15>>
    assert {:ok, ^ack} = APDU.decode(raw(ack))

    service = Constants.by_name!(:confirmed_service_choice, :write_property)
    assert raw(ack) == raw(%{ack | service: service})

    numbered = %{ack | invoke_id: 0, service: 250}
    assert {:ok, ^numbered} = APDU.decode(raw(numbered))

    assert_raise ArgumentError, ~r/Invoke ID/, fn ->
      EncoderProtocol.encode(%{ack | invoke_id: -1})
    end

    assert_raise ArgumentError, ~r/Invoke ID/, fn ->
      EncoderProtocol.encode(%{ack | invoke_id: 256})
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
