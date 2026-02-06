defmodule BACnet.Test.Protocol.Services.UnconfirmedCovNotificationTest do
  alias BACnet.Protocol.APDU.UnconfirmedServiceRequest
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol
  alias BACnet.Protocol.Services.UnconfirmedCovNotification

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest UnconfirmedCovNotification

  test "get name" do
    assert :unconfirmed_cov_notification == UnconfirmedCovNotification.get_name()
  end

  test "is confirmed" do
    assert false == UnconfirmedCovNotification.is_confirmed()
  end

  test "decoding UnconfirmedCovNotification" do
    assert {:ok,
            %UnconfirmedCovNotification{
              process_identifier: 99,
              initiating_device: %BACnet.Protocol.ObjectIdentifier{
                type: :device,
                instance: 86_001
              },
              monitored_object: %BACnet.Protocol.ObjectIdentifier{
                type: :binary_input,
                instance: 102
              },
              time_remaining: 30,
              property_values: [
                %BACnet.Protocol.PropertyValue{
                  property_identifier: :present_value,
                  property_array_index: nil,
                  property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                    encoding: :primitive,
                    extras: [],
                    type: :enumerated,
                    value: 0
                  },
                  priority: nil
                },
                %BACnet.Protocol.PropertyValue{
                  property_identifier: :status_flags,
                  property_array_index: nil,
                  property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                    encoding: :primitive,
                    extras: [],
                    type: :bitstring,
                    value: {false, false, false, false}
                  },
                  priority: nil
                }
              ]
            }} =
             UnconfirmedCovNotification.from_apdu(%UnconfirmedServiceRequest{
               service: :unconfirmed_cov_notification,
               parameters: [
                 tagged: {0, "c", 1},
                 tagged: {1, <<2, 1, 79, 241>>, 4},
                 tagged: {2, <<0, 192, 0, 102>>, 4},
                 tagged: {3, <<30>>, 1},
                 constructed:
                   {4,
                    [
                      tagged: {0, "U", 1},
                      constructed: {2, {:enumerated, 0}, 0},
                      tagged: {0, "o", 1},
                      constructed: {2, {:bitstring, {false, false, false, false}}, 0}
                    ], 0}
               ]
             })
  end

  test "decoding UnconfirmedCovNotification invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             UnconfirmedCovNotification.from_apdu(%UnconfirmedServiceRequest{
               service: :unconfirmed_cov_notification,
               parameters: [
                 tagged: {0, "c", 1},
                 tagged: {1, <<2, 1, 79, 241>>, 4},
                 tagged: {2, <<0, 192, 0, 102>>, 4},
                 tagged: {3, <<30>>, 1}
               ]
             })
  end

  test "decoding UnconfirmedCovNotification invalid process identifier" do
    assert {:error, :invalid_process_identifier_value} =
             UnconfirmedCovNotification.from_apdu(%UnconfirmedServiceRequest{
               service: :unconfirmed_cov_notification,
               parameters: [
                 tagged: {0, <<255, 255, 255, 255, 255>>, 5},
                 tagged: {1, <<2, 1, 79, 241>>, 4},
                 tagged: {2, <<0, 192, 0, 102>>, 4},
                 tagged: {3, <<30>>, 1},
                 constructed:
                   {4,
                    [
                      tagged: {0, "U", 1},
                      constructed: {2, {:enumerated, 0}, 0},
                      tagged: {0, "o", 1},
                      constructed: {2, {:bitstring, {false, false, false, false}}, 0}
                    ], 0}
               ]
             })
  end

  test "decoding UnconfirmedCovNotification invalid APDU" do
    assert {:error, :invalid_request} =
             UnconfirmedCovNotification.from_apdu(%UnconfirmedServiceRequest{
               service: :unconfirmed_event_notification,
               parameters: []
             })
  end

  test "encoding UnconfirmedCovNotification" do
    assert {:ok,
            %UnconfirmedServiceRequest{
              service: :unconfirmed_cov_notification,
              parameters: [
                tagged: {0, "c", 1},
                tagged: {1, <<2, 1, 79, 241>>, 4},
                tagged: {2, <<0, 192, 0, 102>>, 4},
                tagged: {3, <<30>>, 1},
                constructed:
                  {4,
                   [
                     tagged: {0, "U", 1},
                     constructed: {2, {:enumerated, 0}, 0},
                     tagged: {0, "o", 1},
                     constructed: {2, {:bitstring, {false, false, false, false}}, 0}
                   ], 0}
              ]
            }} =
             UnconfirmedCovNotification.to_apdu(
               %UnconfirmedCovNotification{
                 process_identifier: 99,
                 initiating_device: %BACnet.Protocol.ObjectIdentifier{
                   type: :device,
                   instance: 86_001
                 },
                 monitored_object: %BACnet.Protocol.ObjectIdentifier{
                   type: :binary_input,
                   instance: 102
                 },
                 time_remaining: 30,
                 property_values: [
                   %BACnet.Protocol.PropertyValue{
                     property_identifier: :present_value,
                     property_array_index: nil,
                     property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :enumerated,
                       value: 0
                     },
                     priority: nil
                   },
                   %BACnet.Protocol.PropertyValue{
                     property_identifier: :status_flags,
                     property_array_index: nil,
                     property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :bitstring,
                       value: {false, false, false, false}
                     },
                     priority: nil
                   }
                 ]
               },
               []
             )
  end

  test "encoding UnconfirmedCovNotification invalid process identifier" do
    assert {:error, :invalid_process_identifier_value} =
             UnconfirmedCovNotification.to_apdu(
               %UnconfirmedCovNotification{
                 process_identifier: 99_512_512_532_530_350_342,
                 initiating_device: %BACnet.Protocol.ObjectIdentifier{
                   type: :device,
                   instance: 86_001
                 },
                 monitored_object: %BACnet.Protocol.ObjectIdentifier{
                   type: :binary_input,
                   instance: 102
                 },
                 time_remaining: 30,
                 property_values: [
                   %BACnet.Protocol.PropertyValue{
                     property_identifier: :present_value,
                     property_array_index: nil,
                     property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :enumerated,
                       value: 0
                     },
                     priority: nil
                   },
                   %BACnet.Protocol.PropertyValue{
                     property_identifier: :status_flags,
                     property_array_index: nil,
                     property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :bitstring,
                       value: {false, false, false, false}
                     },
                     priority: nil
                   }
                 ]
               },
               []
             )
  end

  test "protocol implementation get name" do
    assert :unconfirmed_cov_notification ==
             ServicesProtocol.get_name(%UnconfirmedCovNotification{
               process_identifier: 99,
               initiating_device: %BACnet.Protocol.ObjectIdentifier{
                 type: :device,
                 instance: 86_001
               },
               monitored_object: %BACnet.Protocol.ObjectIdentifier{
                 type: :binary_input,
                 instance: 102
               },
               time_remaining: 30,
               property_values: [
                 %BACnet.Protocol.PropertyValue{
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 0
                   },
                   priority: nil
                 },
                 %BACnet.Protocol.PropertyValue{
                   property_identifier: :status_flags,
                   property_array_index: nil,
                   property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :bitstring,
                     value: {false, false, false, false}
                   },
                   priority: nil
                 }
               ]
             })
  end

  test "protocol implementation is confirmed" do
    assert false ==
             ServicesProtocol.is_confirmed(%UnconfirmedCovNotification{
               process_identifier: 99,
               initiating_device: %BACnet.Protocol.ObjectIdentifier{
                 type: :device,
                 instance: 86_001
               },
               monitored_object: %BACnet.Protocol.ObjectIdentifier{
                 type: :binary_input,
                 instance: 102
               },
               time_remaining: 30,
               property_values: [
                 %BACnet.Protocol.PropertyValue{
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 0
                   },
                   priority: nil
                 },
                 %BACnet.Protocol.PropertyValue{
                   property_identifier: :status_flags,
                   property_array_index: nil,
                   property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :bitstring,
                     value: {false, false, false, false}
                   },
                   priority: nil
                 }
               ]
             })
  end

  test "protocol implementation to APDU" do
    assert {:ok,
            %UnconfirmedServiceRequest{
              service: :unconfirmed_cov_notification,
              parameters: [
                tagged: {0, "c", 1},
                tagged: {1, <<2, 1, 79, 241>>, 4},
                tagged: {2, <<0, 192, 0, 102>>, 4},
                tagged: {3, <<30>>, 1},
                constructed:
                  {4,
                   [
                     tagged: {0, "U", 1},
                     constructed: {2, {:enumerated, 0}, 0},
                     tagged: {0, "o", 1},
                     constructed: {2, {:bitstring, {false, false, false, false}}, 0}
                   ], 0}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %UnconfirmedCovNotification{
                 process_identifier: 99,
                 initiating_device: %BACnet.Protocol.ObjectIdentifier{
                   type: :device,
                   instance: 86_001
                 },
                 monitored_object: %BACnet.Protocol.ObjectIdentifier{
                   type: :binary_input,
                   instance: 102
                 },
                 time_remaining: 30,
                 property_values: [
                   %BACnet.Protocol.PropertyValue{
                     property_identifier: :present_value,
                     property_array_index: nil,
                     property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :enumerated,
                       value: 0
                     },
                     priority: nil
                   },
                   %BACnet.Protocol.PropertyValue{
                     property_identifier: :status_flags,
                     property_array_index: nil,
                     property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :bitstring,
                       value: {false, false, false, false}
                     },
                     priority: nil
                   }
                 ]
               },
               []
             )
  end
end
