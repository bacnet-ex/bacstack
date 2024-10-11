defmodule BACnet.Test.Protocol.APDU.ErrorTest do
  alias BACnet.Protocol.APDU.Error
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
             EncoderProtocol.is_request(%Error{
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
             EncoderProtocol.is_response(%Error{
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
end
