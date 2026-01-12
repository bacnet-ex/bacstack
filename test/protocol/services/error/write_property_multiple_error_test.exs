defmodule BACnet.Test.Protocol.Services.WritePropertyMultipleErrorTest do
  alias BACnet.Protocol.APDU.Error
  alias BACnet.Protocol.Services.Error.WritePropertyMultipleError

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service
  @moduletag :service_error

  doctest WritePropertyMultipleError

  test "decoding WritePropertyMultipleError" do
    assert {:ok,
            %WritePropertyMultipleError{
              error_class: :property,
              error_code: :write_access_denied,
              first_failed_write_attempt: %BACnet.Protocol.ObjectPropertyRef{
                object_identifier: %BACnet.Protocol.ObjectIdentifier{
                  type: :schedule,
                  instance: 0
                },
                property_identifier: :present_value,
                property_array_index: nil
              }
            }} ==
             WritePropertyMultipleError.from_apdu(%Error{
               invoke_id: 0,
               service: :write_property_multiple,
               class: :property,
               code: :write_access_denied,
               payload: [
                 constructed: {1, [tagged: {0, <<4, 64, 0, 0>>, 4}, tagged: {1, "U", 1}], 0}
               ]
             })
  end

  test "decoding WritePropertyMultipleError invalid payload" do
    assert {:error, :invalid_service_error} ==
             WritePropertyMultipleError.from_apdu(%Error{
               invoke_id: 0,
               service: :write_property_multiple,
               class: :property,
               code: :write_access_denied,
               payload: []
             })
  end

  test "encoding WritePropertyMultipleError" do
    assert {:ok,
            %Error{
              invoke_id: 55,
              service: :write_property_multiple,
              class: :property,
              code: :write_access_denied,
              payload: [
                constructed: {1, [tagged: {0, <<4, 64, 0, 0>>, 4}, tagged: {1, "U", 1}], 0}
              ]
            }} ==
             WritePropertyMultipleError.to_apdu(
               %WritePropertyMultipleError{
                 error_class: :property,
                 error_code: :write_access_denied,
                 first_failed_write_attempt: %BACnet.Protocol.ObjectPropertyRef{
                   object_identifier: %BACnet.Protocol.ObjectIdentifier{
                     type: :schedule,
                     instance: 0
                   },
                   property_identifier: :present_value,
                   property_array_index: nil
                 }
               },
               55
             )
  end

  test "encoding WritePropertyMultipleError with optional invoke_id" do
    assert {:ok,
            %Error{
              invoke_id: 0,
              service: :write_property_multiple,
              class: :property,
              code: :write_access_denied,
              payload: [
                constructed: {1, [tagged: {0, <<4, 64, 0, 0>>, 4}, tagged: {1, "U", 1}], 0}
              ]
            }} ==
             WritePropertyMultipleError.to_apdu(%WritePropertyMultipleError{
               error_class: :property,
               error_code: :write_access_denied,
               first_failed_write_attempt: %BACnet.Protocol.ObjectPropertyRef{
                 object_identifier: %BACnet.Protocol.ObjectIdentifier{
                   type: :schedule,
                   instance: 0
                 },
                 property_identifier: :present_value,
                 property_array_index: nil
               }
             })
  end

  test "encoding AtomicReadFileAck invalid invoke_id" do
    assert {:error, :invalid_parameter} ==
             WritePropertyMultipleError.to_apdu(
               %WritePropertyMultipleError{
                 error_class: :property,
                 error_code: :write_access_denied,
                 first_failed_write_attempt: %BACnet.Protocol.ObjectPropertyRef{
                   object_identifier: %BACnet.Protocol.ObjectIdentifier{
                     type: :schedule,
                     instance: 0
                   },
                   property_identifier: :present_value,
                   property_array_index: nil
                 }
               },
               256
             )
  end
end
