defmodule BACnet.Test.Protocol.Services.RemoveListElementErrorTest do
  alias BACnet.Protocol.APDU.Error
  alias BACnet.Protocol.Services.Error.RemoveListElementError

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service
  @moduletag :service_error

  doctest RemoveListElementError

  test "decoding RemoveListElementError with the context-tagged element number" do
    assert {:ok,
            %RemoveListElementError{
              error_class: :property,
              error_code: :invalid_datatype,
              first_failed_element_number: 258
            }} ==
             RemoveListElementError.from_apdu(%Error{
               invoke_id: 55,
               service: :remove_list_element,
               class: :property,
               code: :invalid_datatype,
               payload: [tagged: {1, <<0x01, 0x02>>, 2}]
             })
  end

  test "decoding RemoveListElementError rejects an application-tagged element number" do
    assert {:error, :invalid_service_error} =
             RemoveListElementError.from_apdu(%Error{
               invoke_id: 55,
               service: :remove_list_element,
               class: :property,
               code: :invalid_datatype,
               payload: [unsigned_integer: 258]
             })
  end

  test "encoding RemoveListElementError with the context-tagged element number" do
    assert {:ok,
            %Error{
              invoke_id: 55,
              service: :remove_list_element,
              class: :property,
              code: :invalid_datatype,
              payload: [tagged: {1, <<0x01, 0x02>>, 2}]
            } = apdu} =
             RemoveListElementError.to_apdu(
               %RemoveListElementError{
                 error_class: :property,
                 error_code: :invalid_datatype,
                 first_failed_element_number: 258
               },
               55
             )

    assert {:ok, <<0x50, 55, 0x09, 0x0E, 0x91, 0x02, 0x91, 0x09, 0x0F, 0x1A, 0x01, 0x02>>} =
             Error.encode(apdu)
  end
end
