defmodule BACnet.Test.Protocol.Services.ConfirmedPrivateTransferErrorTest do
  alias BACnet.Protocol.APDU.Error
  alias BACnet.Protocol.Services.Error.ConfirmedPrivateTransferError

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service
  @moduletag :service_error

  doctest ConfirmedPrivateTransferError

  test "decoding ConfirmedPrivateTransferError with a single error parameter" do
    assert {:ok,
            %ConfirmedPrivateTransferError{
              invoke_id: 1,
              error_class: :services,
              error_code: :other,
              vendor_id: 25,
              service_number: 8,
              parameters: [unsigned_integer: 42]
            }} =
             ConfirmedPrivateTransferError.from_apdu(%Error{
               invoke_id: 1,
               service: :confirmed_private_transfer,
               class: :services,
               code: :other,
               payload: [
                 tagged: {1, <<25>>, 1},
                 tagged: {2, <<8>>, 1},
                 constructed: {3, {:unsigned_integer, 42}, 0}
               ]
             })
  end
end
