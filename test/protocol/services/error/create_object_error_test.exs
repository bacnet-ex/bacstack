defmodule BACnet.Test.Protocol.Services.CreateObjectErrorTest do
  alias BACnet.Protocol.APDU.Error
  alias BACnet.Protocol.Services.Error.CreateObjectError

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service
  @moduletag :service_error

  doctest CreateObjectError

  test "decoding CreateObjectError with the context-tagged element number" do
    assert {:ok,
            %CreateObjectError{
              error_class: :property,
              error_code: :invalid_datatype,
              first_failed_element_number: 258
            }} ==
             CreateObjectError.from_apdu(%Error{
               invoke_id: 55,
               service: :create_object,
               class: :property,
               code: :invalid_datatype,
               payload: [tagged: {1, <<0x01, 0x02>>, 2}]
             })
  end

  test "decoding CreateObjectError rejects an application-tagged element number" do
    assert {:error, :invalid_service_error} =
             CreateObjectError.from_apdu(%Error{
               invoke_id: 55,
               service: :create_object,
               class: :property,
               code: :invalid_datatype,
               payload: [unsigned_integer: 258]
             })
  end

  test "encoding CreateObjectError with the context-tagged element number" do
    assert {:ok,
            %Error{
              invoke_id: 55,
              service: :create_object,
              class: :property,
              code: :invalid_datatype,
              payload: [tagged: {1, <<0x01, 0x02>>, 2}]
            } = apdu} =
             CreateObjectError.to_apdu(
               %CreateObjectError{
                 error_class: :property,
                 error_code: :invalid_datatype,
                 first_failed_element_number: 258
               },
               55
             )

    assert {:ok, <<0x50, 55, 0x0A, 0x0E, 0x91, 0x02, 0x91, 0x09, 0x0F, 0x1A, 0x01, 0x02>>} =
             Error.encode(apdu)
  end
end
