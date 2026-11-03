defmodule BACnet.Test.Protocol.APDU.ErrorTest do
  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.APDU.Error
  alias BACnet.Protocol.Constants
  alias BACnet.Stack.EncoderProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu

  doctest Error

  test "EncoderProtocol expects reply" do
    assert false ==
             EncoderProtocol.expects_reply(%Error{
               class: :services,
               code: :password_failure,
               invoke_id: 2,
               payload: [
                 tagged: {1, <<1, 76>>, 2},
                 tagged: {2, <<0>>, 1},
                 constructed: {3, {:octet_string, <<11, 22>>}, 0}
               ],
               service: :confirmed_private_transfer
             })
  end

  test "EncoderProtocol is request" do
    assert false ==
             EncoderProtocol.request?(%Error{
               class: :services,
               code: :password_failure,
               invoke_id: 2,
               payload: [
                 tagged: {1, <<1, 76>>, 2},
                 tagged: {2, <<0>>, 1},
                 constructed: {3, {:octet_string, <<11, 22>>}, 0}
               ],
               service: :confirmed_private_transfer
             })
  end

  test "EncoderProtocol is response" do
    assert true ==
             EncoderProtocol.response?(%Error{
               class: :services,
               code: :password_failure,
               invoke_id: 2,
               payload: [
                 tagged: {1, <<1, 76>>, 2},
                 tagged: {2, <<0>>, 1},
                 constructed: {3, {:octet_string, <<11, 22>>}, 0}
               ],
               service: :confirmed_private_transfer
             })
  end

  test "EncoderProtocol supports segmentation" do
    assert false ==
             EncoderProtocol.supports_segmentation(%Error{
               class: :services,
               code: :password_failure,
               invoke_id: 2,
               payload: [],
               service: :confirmed_private_transfer
             })
  end

  test "EncoderProtocol encodes class, code, and payload" do
    error = %Error{
      invoke_id: 5,
      service: :write_property,
      class: :property,
      code: :write_access_denied,
      payload: []
    }

    assert raw(error) == <<80, 5, 15, 145, 2, 145, 40>>
    assert {:ok, ^error} = APDU.decode(raw(error))

    assert raw(error) ==
             raw(%{
               error
               | service: Constants.by_name!(:confirmed_service_choice, :write_property),
                 class: Constants.by_name!(:error_class, :property),
                 code: Constants.by_name!(:error_code, :write_access_denied)
             })

    with_payload = %{error | payload: [boolean: true]}
    assert {:ok, decoded} = APDU.decode(raw(with_payload))
    assert decoded.invoke_id == 5
    assert decoded.service == :write_property
    assert decoded.class == :property
    assert decoded.code == :write_access_denied
    assert decoded.payload == [boolean: true]

    numbered = %{error | invoke_id: 255, service: 250, class: 200, code: 201}
    assert {:ok, ^numbered} = APDU.decode(raw(numbered))

    assert_raise RuntimeError, ~r/Unable to encode payload in error encode/, fn ->
      EncoderProtocol.encode(%{error | payload: [{:constructed, :bad}]})
    end

    assert_raise ArgumentError, ~r/Invoke ID/, fn ->
      EncoderProtocol.encode(%{error | invoke_id: -1})
    end

    refute_segmentation(error)
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
