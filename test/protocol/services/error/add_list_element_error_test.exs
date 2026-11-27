defmodule BACnet.Test.Protocol.Services.AddListElementErrorTest do
  alias BACnet.Protocol.APDU.Error
  alias BACnet.Protocol.Services.Error.AddListElementError

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service
  @moduletag :service_error

  doctest AddListElementError

  test "decoding AddListElementError with the context-tagged element number" do
    assert {:ok,
            %AddListElementError{
              error_class: :property,
              error_code: :invalid_datatype,
              first_failed_element_number: 258
            }} ==
             AddListElementError.from_apdu(%Error{
               invoke_id: 55,
               service: :add_list_element,
               class: :property,
               code: :invalid_datatype,
               payload: [tagged: {1, <<0x01, 0x02>>, 2}]
             })
  end

  test "decoding AddListElementError rejects an application-tagged element number" do
    assert {:error, :invalid_service_error} =
             AddListElementError.from_apdu(%Error{
               invoke_id: 55,
               service: :add_list_element,
               class: :property,
               code: :invalid_datatype,
               payload: [unsigned_integer: 258]
             })
  end

  test "encoding AddListElementError with the context-tagged element number" do
    assert {:ok,
            %Error{
              invoke_id: 55,
              service: :add_list_element,
              class: :property,
              code: :invalid_datatype,
              payload: [tagged: {1, <<0x01, 0x02>>, 2}]
            } = apdu} =
             AddListElementError.to_apdu(
               %AddListElementError{
                 error_class: :property,
                 error_code: :invalid_datatype,
                 first_failed_element_number: 258
               },
               55
             )

    assert {:ok, <<0x50, 55, 0x08, 0x0E, 0x91, 0x02, 0x91, 0x09, 0x0F, 0x1A, 0x01, 0x02>>} =
             Error.encode(apdu)
  end
end
