defmodule BACnet.Protocol.CovSubscriptionTest do
  alias BACnet.Protocol.CovSubscription
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectPropertyRef
  alias BACnet.Protocol.Recipient
  alias BACnet.Protocol.RecipientAddress

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest CovSubscription

  test "decode cov subscription" do
    assert {:ok,
            {%CovSubscription{
               recipient: %Recipient{
                 type: :address,
                 address: %RecipientAddress{network: 0, address: <<192, 168, 1, 73, 186, 192>>},
                 device: nil
               },
               recipient_process: 8_552_448,
               monitored_object_property: %ObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{
                   type: :calendar,
                   instance: 0
                 },
                 property_identifier: :present_value,
                 property_array_index: nil
               },
               issue_confirmed_notifications: false,
               time_remaining: 3474,
               cov_increment: nil
             }, []}} =
             CovSubscription.parse(
               constructed:
                 {0,
                  [
                    constructed:
                      {0,
                       {:constructed,
                        {1, [unsigned_integer: 0, octet_string: <<192, 168, 1, 73, 186, 192>>], 0}},
                       0},
                    tagged: {1, <<130, 128, 0>>, 3}
                  ], 0},
               constructed: {1, [tagged: {0, <<1, 128, 0, 0>>, 4}, tagged: {1, "U", 1}], 0},
               tagged: {2, <<0>>, 1},
               tagged: {3, <<13, 146>>, 2}
             )
  end

  test "decode cov subscription with cov increment" do
    assert {:ok,
            {%CovSubscription{
               recipient: %Recipient{
                 type: :address,
                 address: %RecipientAddress{network: 0, address: <<192, 168, 1, 73, 186, 192>>},
                 device: nil
               },
               recipient_process: 8_552_448,
               monitored_object_property: %ObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{
                   type: :calendar,
                   instance: 0
                 },
                 property_identifier: :present_value,
                 property_array_index: nil
               },
               issue_confirmed_notifications: false,
               time_remaining: 3474,
               cov_increment: 0.5
             }, []}} =
             CovSubscription.parse(
               constructed:
                 {0,
                  [
                    constructed:
                      {0,
                       {:constructed,
                        {1, [unsigned_integer: 0, octet_string: <<192, 168, 1, 73, 186, 192>>], 0}},
                       0},
                    tagged: {1, <<130, 128, 0>>, 3}
                  ], 0},
               constructed: {1, [tagged: {0, <<1, 128, 0, 0>>, 4}, tagged: {1, "U", 1}], 0},
               tagged: {2, <<0>>, 1},
               tagged: {3, <<13, 146>>, 2},
               tagged: {4, <<63, 0, 0, 0>>, 4}
             )
  end

  test "decode invalid cov subscription" do
    assert {:error, :invalid_tags} =
             CovSubscription.parse(
               constructed:
                 {0,
                  [
                    constructed:
                      {0,
                       {:constructed,
                        {1, [unsigned_integer: 0, octet_string: <<192, 168, 1, 73, 186, 192>>], 0}},
                       0},
                    tagged: {1, <<130, 128, 0>>, 3}
                  ], 0},
               constructed: {1, [tagged: {0, <<1, 128, 0, 0>>, 4}, tagged: {1, "U", 1}], 0}
             )
  end

  test "decode invalid cov subscription in constructed" do
    assert {:error, :invalid_tags} =
             CovSubscription.parse(
               constructed: {0, [], 0},
               constructed: {1, [tagged: {0, <<1, 128, 0, 0>>, 4}, tagged: {1, "U", 1}], 0}
             )
  end

  test "decode invalid cov subscription in recipient" do
    assert {:error, :invalid_tags} =
             CovSubscription.parse(
               constructed:
                 {0,
                  [
                    constructed:
                      {0,
                       {:constructed,
                        {1, [unsigned_integer: 0, octet_string: <<192, 168, 1, 73, 186, 192>>], 0}},
                       0},
                    tagged: {1, <<130, 128, 0>>, 3}
                  ], 0},
               constructed: {1, [], 0}
             )
  end

  test "encode cov subscription" do
    assert {:ok,
            [
              constructed:
                {0,
                 [
                   constructed:
                     {0,
                      {:constructed,
                       {1, [unsigned_integer: 0, octet_string: <<192, 168, 1, 73, 186, 192>>], 0}},
                      0},
                   tagged: {1, <<130, 128, 0>>, 3}
                 ], 0},
              constructed: {1, [tagged: {0, <<1, 128, 0, 0>>, 4}, tagged: {1, "U", 1}], 0},
              tagged: {2, <<0>>, 1},
              tagged: {3, <<13, 146>>, 2}
            ]} =
             CovSubscription.encode(%CovSubscription{
               recipient: %Recipient{
                 type: :address,
                 address: %RecipientAddress{network: 0, address: <<192, 168, 1, 73, 186, 192>>},
                 device: nil
               },
               recipient_process: 8_552_448,
               monitored_object_property: %ObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{
                   type: :calendar,
                   instance: 0
                 },
                 property_identifier: :present_value,
                 property_array_index: nil
               },
               issue_confirmed_notifications: false,
               time_remaining: 3474,
               cov_increment: nil
             })
  end

  test "encode cov subscription with cov increment" do
    assert {:ok,
            [
              constructed:
                {0,
                 [
                   constructed:
                     {0,
                      {:constructed,
                       {1, [unsigned_integer: 0, octet_string: <<192, 168, 1, 73, 186, 192>>], 0}},
                      0},
                   tagged: {1, <<130, 128, 0>>, 3}
                 ], 0},
              constructed: {1, [tagged: {0, <<1, 128, 0, 0>>, 4}, tagged: {1, "U", 1}], 0},
              tagged: {2, <<0>>, 1},
              tagged: {3, <<13, 146>>, 2},
              tagged: {4, <<63, 0, 0, 0>>, 4}
            ]} =
             CovSubscription.encode(%CovSubscription{
               recipient: %Recipient{
                 type: :address,
                 address: %RecipientAddress{network: 0, address: <<192, 168, 1, 73, 186, 192>>},
                 device: nil
               },
               recipient_process: 8_552_448,
               monitored_object_property: %ObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{
                   type: :calendar,
                   instance: 0
                 },
                 property_identifier: :present_value,
                 property_array_index: nil
               },
               issue_confirmed_notifications: false,
               time_remaining: 3474,
               cov_increment: 0.5
             })
  end

  test "encode invalid cov subscription" do
    assert {:error, :invalid_value} =
             CovSubscription.encode(%CovSubscription{
               recipient: %Recipient{
                 type: :address,
                 address: %RecipientAddress{network: 0, address: <<192, 168, 1, 73, 186, 192>>},
                 device: nil
               },
               recipient_process: :hello,
               monitored_object_property: %ObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{
                   type: :calendar,
                   instance: 0
                 },
                 property_identifier: :present_value,
                 property_array_index: nil
               },
               issue_confirmed_notifications: false,
               time_remaining: 3474,
               cov_increment: nil
             })
  end

  test "valid cov subscription" do
    assert true ==
             CovSubscription.valid?(%CovSubscription{
               recipient: %Recipient{
                 type: :address,
                 address: %RecipientAddress{network: 0, address: <<192, 168, 1, 73, 186, 192>>},
                 device: nil
               },
               recipient_process: 8_552_448,
               monitored_object_property: %ObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{
                   type: :calendar,
                   instance: 0
                 },
                 property_identifier: :present_value,
                 property_array_index: nil
               },
               issue_confirmed_notifications: false,
               time_remaining: 3474,
               cov_increment: nil
             })

    assert true ==
             CovSubscription.valid?(%CovSubscription{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               recipient_process: 8_552_448,
               monitored_object_property: %ObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{
                   type: :calendar,
                   instance: 0
                 },
                 property_identifier: :present_value,
                 property_array_index: nil
               },
               issue_confirmed_notifications: false,
               time_remaining: 3474,
               cov_increment: 0.5
             })

    assert true ==
             CovSubscription.valid?(%CovSubscription{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               recipient_process: 8_552_448,
               monitored_object_property: %ObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{
                   type: :calendar,
                   instance: 0
                 },
                 property_identifier: :present_value,
                 property_array_index: nil
               },
               issue_confirmed_notifications: false,
               time_remaining: 3474,
               cov_increment: 0.5
             })

    assert true ==
             CovSubscription.valid?(%CovSubscription{
               recipient: %Recipient{
                 type: :address,
                 address: %RecipientAddress{network: 0, address: :broadcast},
                 device: nil
               },
               recipient_process: 8_552_448,
               monitored_object_property: %ObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{
                   type: :calendar,
                   instance: 0
                 },
                 property_identifier: :present_value,
                 property_array_index: nil
               },
               issue_confirmed_notifications: false,
               time_remaining: 3474,
               cov_increment: 0.5
             })

    assert true ==
             CovSubscription.valid?(%CovSubscription{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               recipient_process: 8_552_448,
               monitored_object_property: %ObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{
                   type: :calendar,
                   instance: 0
                 },
                 property_identifier: :present_value,
                 property_array_index: nil
               },
               issue_confirmed_notifications: false,
               time_remaining: 3474,
               cov_increment: 0.5
             })

    assert true ==
             CovSubscription.valid?(%CovSubscription{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               recipient_process: 8_552_448,
               monitored_object_property: %ObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{
                   type: :calendar,
                   instance: 0
                 },
                 property_identifier: :present_value,
                 property_array_index: 52
               },
               issue_confirmed_notifications: false,
               time_remaining: 3474,
               cov_increment: 0.5
             })

    assert true ==
             CovSubscription.valid?(%CovSubscription{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               recipient_process: 8_552_448,
               monitored_object_property: %ObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{
                   type: :calendar,
                   instance: 0
                 },
                 property_identifier: :present_value,
                 property_array_index: nil
               },
               issue_confirmed_notifications: true,
               time_remaining: 3474,
               cov_increment: 0.5
             })
  end

  test "invalid cov subscription" do
    assert false ==
             CovSubscription.valid?(%CovSubscription{
               recipient: %Recipient{
                 type: :address,
                 address: :hello,
                 device: nil
               },
               recipient_process: 8_552_448,
               monitored_object_property: %ObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{
                   type: :calendar,
                   instance: 0
                 },
                 property_identifier: :present_value,
                 property_array_index: nil
               },
               issue_confirmed_notifications: false,
               time_remaining: 3474,
               cov_increment: 0.5
             })

    assert false ==
             CovSubscription.valid?(%CovSubscription{
               recipient: :hello,
               recipient_process: 8_552_448,
               monitored_object_property: %ObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{
                   type: :calendar,
                   instance: 0
                 },
                 property_identifier: :present_value,
                 property_array_index: nil
               },
               issue_confirmed_notifications: false,
               time_remaining: 3474,
               cov_increment: 0.5
             })

    assert false ==
             CovSubscription.valid?(%CovSubscription{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               recipient_process: :hello,
               monitored_object_property: %ObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{
                   type: :calendar,
                   instance: 0
                 },
                 property_identifier: :present_value,
                 property_array_index: nil
               },
               issue_confirmed_notifications: false,
               time_remaining: 3474,
               cov_increment: 0.5
             })

    assert false ==
             CovSubscription.valid?(%CovSubscription{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               recipient_process: 8_552_448,
               monitored_object_property: %ObjectPropertyRef{
                 object_identifier: :hello,
                 property_identifier: :present_value,
                 property_array_index: nil
               },
               issue_confirmed_notifications: false,
               time_remaining: 3474,
               cov_increment: 0.5
             })

    assert false ==
             CovSubscription.valid?(%CovSubscription{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               recipient_process: 8_552_448,
               monitored_object_property: :hello,
               issue_confirmed_notifications: false,
               time_remaining: 3474,
               cov_increment: 0.5
             })

    assert false ==
             CovSubscription.valid?(%CovSubscription{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               recipient_process: 8_552_448,
               monitored_object_property: %ObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{
                   type: :calendar,
                   instance: 0
                 },
                 property_identifier: :present_value,
                 property_array_index: nil
               },
               issue_confirmed_notifications: :hello,
               time_remaining: 3474,
               cov_increment: 0.5
             })

    assert false ==
             CovSubscription.valid?(%CovSubscription{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               recipient_process: 8_552_448,
               monitored_object_property: %ObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{
                   type: :calendar,
                   instance: 0
                 },
                 property_identifier: :present_value,
                 property_array_index: nil
               },
               issue_confirmed_notifications: false,
               time_remaining: :hello,
               cov_increment: 0.5
             })

    assert false ==
             CovSubscription.valid?(%CovSubscription{
               recipient: %Recipient{
                 type: :device,
                 address: nil,
                 device: %ObjectIdentifier{type: :device, instance: 100}
               },
               recipient_process: 8_552_448,
               monitored_object_property: %ObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{
                   type: :calendar,
                   instance: 0
                 },
                 property_identifier: :present_value,
                 property_array_index: nil
               },
               issue_confirmed_notifications: false,
               time_remaining: 3474,
               cov_increment: 5
             })
  end
end
