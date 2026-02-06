defmodule BACnet.Test.Protocol.Services.UnconfirmedEventNotificationTest do
  alias BACnet.Protocol.APDU.UnconfirmedServiceRequest
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.BACnetTimestamp
  alias BACnet.Protocol.NotificationParameters.ComplexEventType
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.PropertyValue
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol
  alias BACnet.Protocol.Services.UnconfirmedEventNotification

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest UnconfirmedEventNotification

  test "get name" do
    assert :unconfirmed_event_notification == UnconfirmedEventNotification.get_name()
  end

  test "is confirmed" do
    assert false == UnconfirmedEventNotification.is_confirmed()
  end

  test "decoding UnconfirmedEventNotification" do
    assert {:ok,
            %UnconfirmedEventNotification{
              process_identifier: 123,
              initiating_device: %ObjectIdentifier{
                type: :device,
                instance: 1_041_000
              },
              event_object: %ObjectIdentifier{
                type: :analog_input,
                instance: 3_000_016
              },
              timestamp: %BACnetTimestamp{
                type: :time,
                time: %BACnetTime{
                  hour: 2,
                  minute: 12,
                  second: 49,
                  hundredth: 0
                },
                sequence_number: nil,
                datetime: nil
              },
              notification_class: 1,
              priority: 200,
              event_type: :complex_event_type,
              message_text: nil,
              notify_type: :alarm,
              ack_required: true,
              from_state: :high_limit,
              to_state: :normal,
              event_values: %ComplexEventType{
                property_values: [
                  %PropertyValue{
                    property_identifier: :present_value,
                    property_array_index: nil,
                    property_value: %Encoding{
                      encoding: :primitive,
                      extras: [],
                      type: :real,
                      value: 1.0
                    },
                    priority: 7
                  }
                ]
              }
            }} =
             UnconfirmedEventNotification.from_apdu(%UnconfirmedServiceRequest{
               service: :unconfirmed_event_notification,
               parameters: [
                 tagged: {0, "{", 1},
                 tagged: {1, <<2, 15, 226, 104>>, 4},
                 tagged: {2, <<0, 45, 198, 208>>, 4},
                 constructed: {3, {:tagged, {0, <<2, 12, 49, 0>>, 4}}, 0},
                 tagged: {4, <<1>>, 1},
                 tagged: {5, <<200>>, 1},
                 tagged: {6, <<6>>, 1},
                 tagged: {8, <<0>>, 1},
                 tagged: {9, <<1>>, 1},
                 tagged: {10, <<3>>, 1},
                 tagged: {11, <<0>>, 1},
                 constructed:
                   {12,
                    {:constructed,
                     {6,
                      [
                        tagged: {0, "U", 1},
                        constructed: {2, {:real, 1.0}, 0},
                        tagged: {3, "\a", 1}
                      ], 0}}, 0}
               ]
             })
  end

  test "decoding UnconfirmedEventNotification invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             UnconfirmedEventNotification.from_apdu(%UnconfirmedServiceRequest{
               service: :unconfirmed_event_notification,
               parameters: [
                 tagged: {0, "{", 1},
                 tagged: {1, <<2, 15, 226, 104>>, 4},
                 tagged: {2, <<0, 45, 198, 208>>, 4},
                 constructed: {3, {:tagged, {0, <<2, 12, 49, 0>>, 4}}, 0},
                 tagged: {4, <<1>>, 1},
                 tagged: {5, <<200>>, 1},
                 tagged: {6, <<6>>, 1},
                 tagged: {8, <<0>>, 1},
                 tagged: {9, <<1>>, 1},
                 tagged: {10, <<3>>, 1},
                 tagged: {11, <<0>>, 1}
               ]
             })
  end

  test "decoding UnconfirmedEventNotification invalid process identifier" do
    assert {:error, :invalid_process_identifier_value} =
             UnconfirmedEventNotification.from_apdu(%UnconfirmedServiceRequest{
               service: :unconfirmed_event_notification,
               parameters: [
                 tagged: {0, <<255, 255, 255, 255, 255>>, 5},
                 tagged: {1, <<2, 15, 226, 104>>, 4},
                 tagged: {2, <<0, 45, 198, 208>>, 4},
                 constructed: {3, {:tagged, {0, <<2, 12, 49, 0>>, 4}}, 0},
                 tagged: {4, <<1>>, 1},
                 tagged: {5, <<200>>, 1},
                 tagged: {6, <<6>>, 1},
                 tagged: {8, <<0>>, 1},
                 tagged: {9, <<1>>, 1},
                 tagged: {10, <<3>>, 1},
                 tagged: {11, <<0>>, 1},
                 constructed:
                   {12,
                    {:constructed,
                     {6,
                      [
                        tagged: {0, "U", 1},
                        constructed: {2, {:real, 1.0}, 0},
                        tagged: {3, "\a", 1}
                      ], 0}}, 0}
               ]
             })
  end

  test "decoding UnconfirmedEventNotification invalid priority" do
    assert {:error, :invalid_priority_value} =
             UnconfirmedEventNotification.from_apdu(%UnconfirmedServiceRequest{
               service: :unconfirmed_event_notification,
               parameters: [
                 tagged: {0, "{", 1},
                 tagged: {1, <<2, 15, 226, 104>>, 4},
                 tagged: {2, <<0, 45, 198, 208>>, 4},
                 constructed: {3, {:tagged, {0, <<2, 12, 49, 0>>, 4}}, 0},
                 tagged: {4, <<1>>, 1},
                 tagged: {5, <<200, 10>>, 2},
                 tagged: {6, <<6>>, 1},
                 tagged: {8, <<0>>, 1},
                 tagged: {9, <<1>>, 1},
                 tagged: {10, <<3>>, 1},
                 tagged: {11, <<0>>, 1},
                 constructed:
                   {12,
                    {:constructed,
                     {6,
                      [
                        tagged: {0, "U", 1},
                        constructed: {2, {:real, 1.0}, 0},
                        tagged: {3, "\a", 1}
                      ], 0}}, 0}
               ]
             })
  end

  test "decoding UnconfirmedEventNotification invalid APDU" do
    assert {:error, :invalid_request} =
             UnconfirmedEventNotification.from_apdu(%UnconfirmedServiceRequest{
               service: :unconfirmed_text_notification,
               parameters: []
             })
  end

  test "encoding UnconfirmedEventNotification" do
    assert {:ok,
            %UnconfirmedServiceRequest{
              service: :unconfirmed_event_notification,
              parameters: [
                tagged: {0, "{", 1},
                tagged: {1, <<2, 15, 226, 104>>, 4},
                tagged: {2, <<0, 45, 198, 208>>, 4},
                constructed: {3, {:tagged, {0, <<2, 12, 49, 0>>, 4}}, 0},
                tagged: {4, <<1>>, 1},
                tagged: {5, <<200>>, 1},
                tagged: {6, <<6>>, 1},
                tagged: {8, <<0>>, 1},
                tagged: {9, <<1>>, 1},
                tagged: {10, <<3>>, 1},
                tagged: {11, <<0>>, 1},
                constructed:
                  {12,
                   {:constructed,
                    {6,
                     [
                       tagged: {0, "U", 1},
                       constructed: {2, {:real, 1.0}, 0},
                       tagged: {3, "\a", 1}
                     ], 0}}, 0}
              ]
            }} =
             UnconfirmedEventNotification.to_apdu(
               %UnconfirmedEventNotification{
                 process_identifier: 123,
                 initiating_device: %ObjectIdentifier{
                   type: :device,
                   instance: 1_041_000
                 },
                 event_object: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 3_000_016
                 },
                 timestamp: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: 2,
                     minute: 12,
                     second: 49,
                     hundredth: 0
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 notification_class: 1,
                 priority: 200,
                 event_type: :complex_event_type,
                 message_text: nil,
                 notify_type: :alarm,
                 ack_required: true,
                 from_state: :high_limit,
                 to_state: :normal,
                 event_values: %ComplexEventType{
                   property_values: [
                     %PropertyValue{
                       property_identifier: :present_value,
                       property_array_index: nil,
                       property_value: %Encoding{
                         encoding: :primitive,
                         extras: [],
                         type: :real,
                         value: 1.0
                       },
                       priority: 7
                     }
                   ]
                 }
               },
               []
             )
  end

  test "encoding UnconfirmedEventNotification invalid process identifier" do
    assert {:error, :invalid_process_identifier_value} =
             UnconfirmedEventNotification.to_apdu(
               %UnconfirmedEventNotification{
                 process_identifier: 123_125_532_034_235_532,
                 initiating_device: %ObjectIdentifier{
                   type: :device,
                   instance: 1_041_000
                 },
                 event_object: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 3_000_016
                 },
                 timestamp: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: 2,
                     minute: 12,
                     second: 49,
                     hundredth: 0
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 notification_class: 1,
                 priority: 200,
                 event_type: :complex_event_type,
                 message_text: nil,
                 notify_type: :alarm,
                 ack_required: true,
                 from_state: :high_limit,
                 to_state: :normal,
                 event_values: %ComplexEventType{
                   property_values: [
                     %PropertyValue{
                       property_identifier: :present_value,
                       property_array_index: nil,
                       property_value: %Encoding{
                         encoding: :primitive,
                         extras: [],
                         type: :real,
                         value: 1.0
                       },
                       priority: 7
                     }
                   ]
                 }
               },
               []
             )
  end

  test "encoding UnconfirmedEventNotification invalid priority" do
    assert {:error, :invalid_priority_value} =
             UnconfirmedEventNotification.to_apdu(
               %UnconfirmedEventNotification{
                 process_identifier: 123,
                 initiating_device: %ObjectIdentifier{
                   type: :device,
                   instance: 1_041_000
                 },
                 event_object: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 3_000_016
                 },
                 timestamp: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: 2,
                     minute: 12,
                     second: 49,
                     hundredth: 0
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 notification_class: 1,
                 priority: 513,
                 event_type: :complex_event_type,
                 message_text: nil,
                 notify_type: :alarm,
                 ack_required: true,
                 from_state: :high_limit,
                 to_state: :normal,
                 event_values: %ComplexEventType{
                   property_values: [
                     %PropertyValue{
                       property_identifier: :present_value,
                       property_array_index: nil,
                       property_value: %Encoding{
                         encoding: :primitive,
                         extras: [],
                         type: :real,
                         value: 1.0
                       },
                       priority: 7
                     }
                   ]
                 }
               },
               []
             )
  end

  test "protocol implementation get name" do
    assert :unconfirmed_event_notification ==
             ServicesProtocol.get_name(%UnconfirmedEventNotification{
               process_identifier: 123,
               initiating_device: %ObjectIdentifier{
                 type: :device,
                 instance: 1_041_000
               },
               event_object: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 3_000_016
               },
               timestamp: %BACnetTimestamp{
                 type: :time,
                 time: %BACnetTime{
                   hour: 2,
                   minute: 12,
                   second: 49,
                   hundredth: 0
                 },
                 sequence_number: nil,
                 datetime: nil
               },
               notification_class: 1,
               priority: 200,
               event_type: :complex_event_type,
               message_text: nil,
               notify_type: :alarm,
               ack_required: true,
               from_state: :high_limit,
               to_state: :normal,
               event_values: %ComplexEventType{
                 property_values: [
                   %PropertyValue{
                     property_identifier: :present_value,
                     property_array_index: nil,
                     property_value: %Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :real,
                       value: 1.0
                     },
                     priority: 7
                   }
                 ]
               }
             })
  end

  test "protocol implementation is confirmed" do
    assert false ==
             ServicesProtocol.is_confirmed(%UnconfirmedEventNotification{
               process_identifier: 123,
               initiating_device: %ObjectIdentifier{
                 type: :device,
                 instance: 1_041_000
               },
               event_object: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 3_000_016
               },
               timestamp: %BACnetTimestamp{
                 type: :time,
                 time: %BACnetTime{
                   hour: 2,
                   minute: 12,
                   second: 49,
                   hundredth: 0
                 },
                 sequence_number: nil,
                 datetime: nil
               },
               notification_class: 1,
               priority: 200,
               event_type: :complex_event_type,
               message_text: nil,
               notify_type: :alarm,
               ack_required: true,
               from_state: :high_limit,
               to_state: :normal,
               event_values: %ComplexEventType{
                 property_values: [
                   %PropertyValue{
                     property_identifier: :present_value,
                     property_array_index: nil,
                     property_value: %Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :real,
                       value: 1.0
                     },
                     priority: 7
                   }
                 ]
               }
             })
  end

  test "protocol implementation to APDU" do
    assert {:ok,
            %UnconfirmedServiceRequest{
              service: :unconfirmed_event_notification,
              parameters: [
                tagged: {0, "{", 1},
                tagged: {1, <<2, 15, 226, 104>>, 4},
                tagged: {2, <<0, 45, 198, 208>>, 4},
                constructed: {3, {:tagged, {0, <<2, 12, 49, 0>>, 4}}, 0},
                tagged: {4, <<1>>, 1},
                tagged: {5, <<200>>, 1},
                tagged: {6, <<6>>, 1},
                tagged: {8, <<0>>, 1},
                tagged: {9, <<1>>, 1},
                tagged: {10, <<3>>, 1},
                tagged: {11, <<0>>, 1},
                constructed:
                  {12,
                   {:constructed,
                    {6,
                     [
                       tagged: {0, "U", 1},
                       constructed: {2, {:real, 1.0}, 0},
                       tagged: {3, "\a", 1}
                     ], 0}}, 0}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %UnconfirmedEventNotification{
                 process_identifier: 123,
                 initiating_device: %ObjectIdentifier{
                   type: :device,
                   instance: 1_041_000
                 },
                 event_object: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 3_000_016
                 },
                 timestamp: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: 2,
                     minute: 12,
                     second: 49,
                     hundredth: 0
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 notification_class: 1,
                 priority: 200,
                 event_type: :complex_event_type,
                 message_text: nil,
                 notify_type: :alarm,
                 ack_required: true,
                 from_state: :high_limit,
                 to_state: :normal,
                 event_values: %ComplexEventType{
                   property_values: [
                     %PropertyValue{
                       property_identifier: :present_value,
                       property_array_index: nil,
                       property_value: %Encoding{
                         encoding: :primitive,
                         extras: [],
                         type: :real,
                         value: 1.0
                       },
                       priority: 7
                     }
                   ]
                 }
               },
               []
             )
  end
end
