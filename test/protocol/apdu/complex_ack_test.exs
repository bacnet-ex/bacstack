defmodule BACnet.Test.Protocol.APDU.ComplexAckTest do
  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.IncompleteAPDU
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
             EncoderProtocol.request?(%ComplexACK{
               invoke_id: 70,
               service: :atomic_write_file,
               payload: [tagged: {0, <<1, 184>>, 2}],
               proposed_window_size: nil,
               sequence_number: nil
             })
  end

  test "EncoderProtocol is response" do
    assert true ==
             EncoderProtocol.response?(%ComplexACK{
               invoke_id: 70,
               service: :atomic_write_file,
               payload: [tagged: {0, <<1, 184>>, 2}],
               proposed_window_size: nil,
               sequence_number: nil
             })
  end

  test "EncoderProtocol supports segmentation" do
    assert true ==
             EncoderProtocol.supports_segmentation(%ComplexACK{
               invoke_id: 70,
               service: :atomic_write_file,
               payload: [tagged: {0, <<1, 184>>, 2}],
               proposed_window_size: nil,
               sequence_number: nil
             })
  end

  test "EncoderProtocol encodes the payload" do
    ack = %ComplexACK{
      invoke_id: 12,
      service: :read_property,
      sequence_number: nil,
      proposed_window_size: nil,
      payload: [
        tagged: {0, <<0, 0x80, 0, 0>>, 4},
        tagged: {1, <<0x55>>, 1},
        constructed: {3, [{:real, 23.5}], 0}
      ]
    }

    assert raw(ack) ==
             <<0x30, 0x0C, 0x0C, 0x0C, 0x00, 0x80, 0x00, 0x00, 0x19, 0x55, 0x3E, 0x44, 0x41, 0xBC,
               0x00, 0x00, 0x3F>>

    assert {:ok, decoded} = APDU.decode(raw(ack))
    assert decoded.invoke_id == 12
    assert decoded.service == :read_property
    assert decoded.sequence_number == nil
    assert decoded.proposed_window_size == nil
    assert decoded.payload != []

    plain = %ComplexACK{
      invoke_id: 12,
      sequence_number: nil,
      proposed_window_size: nil,
      service: :read_property,
      payload: []
    }

    service = Constants.by_name!(:confirmed_service_choice, :read_property)
    assert raw(%{plain | service: service}) == raw(plain)

    numbered = %{plain | invoke_id: 0, service: 250}
    assert {:ok, ^numbered} = APDU.decode(raw(numbered))

    assert_raise RuntimeError, ~r/Unable to encode service ack in complex ack encode/, fn ->
      EncoderProtocol.encode(%{plain | payload: [{:constructed, :bad}]})
    end

    assert_raise ArgumentError, ~r/Invoke ID/, fn ->
      EncoderProtocol.encode(%{plain | invoke_id: 256})
    end
  end

  test "EncoderProtocol segments a payload and rejects a short maximum" do
    empty = %ComplexACK{
      invoke_id: 12,
      sequence_number: nil,
      proposed_window_size: 1,
      service: :read_property,
      payload: []
    }

    assert [segment] = EncoderProtocol.encode_segmented(empty, 50)
    assert {:ok, decoded} = APDU.decode(IO.iodata_to_binary(segment))
    assert decoded.invoke_id == empty.invoke_id
    assert decoded.service == :read_property
    assert decoded.payload == []
    assert decoded.sequence_number == nil
    assert EncoderProtocol.encode_to_segmented(empty, segment, 50) == []

    ack = %ComplexACK{
      invoke_id: 12,
      sequence_number: nil,
      proposed_window_size: 127,
      service: :read_property,
      payload: [unsigned_integer: 1, unsigned_integer: 2]
    }

    assert_split(ack, 3, 6)

    assert_raise ArgumentError, ~r/segmented header size of 5/, fn ->
      EncoderProtocol.encode_segmented(ack, 5)
    end
  end

  defp assert_split(apdu, header_size, apdu_size) do
    full = raw(apdu)
    payload = binary_part(full, header_size, byte_size(full) - header_size)
    assert byte_size(payload) > 1

    segments = EncoderProtocol.encode_segmented(apdu, apdu_size)
    header = binary_part(full, 0, header_size)

    assert segments ==
             EncoderProtocol.encode_to_segmented(apdu, [header, payload], apdu_size)

    payload_limit = apdu_size - header_size - 2

    assert length(segments) ==
             div(byte_size(payload) + payload_limit - 1, payload_limit)

    joined =
      segments
      |> Enum.with_index()
      |> Enum.map(fn {segment, index} ->
        assert {:incomplete, %IncompleteAPDU{} = incomplete} =
                 APDU.decode(IO.iodata_to_binary(segment))

        assert incomplete.sequence_number == index
        assert incomplete.window_size == apdu.proposed_window_size
        assert incomplete.invoke_id == apdu.invoke_id
        assert incomplete.more_follows == index < length(segments) - 1
        assert :binary.last(incomplete.header) == service_byte(apdu.service)
        incomplete.data
      end)
      |> IO.iodata_to_binary()

    assert joined == payload
    segments
  end

  defp service_byte(service) when is_atom(service) do
    Constants.by_name!(:confirmed_service_choice, service)
  end

  defp service_byte(service) when is_integer(service), do: service

  defp raw(apdu), do: IO.iodata_to_binary(EncoderProtocol.encode(apdu))
end
