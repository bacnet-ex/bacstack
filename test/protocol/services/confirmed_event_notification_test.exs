defmodule BACnet.Test.Protocol.Services.ConfirmedEventNotificationTest do
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.BACnetTimestamp
  alias BACnet.Protocol.NotificationParameters.ComplexEventType
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.PropertyValue
  alias BACnet.Protocol.Services.ConfirmedEventNotification
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest ConfirmedEventNotification

  test "get name" do
    assert :confirmed_event_notification == ConfirmedEventNotification.get_name()
  end

  test "is confirmed" do
    assert true == ConfirmedEventNotification.is_confirmed()
  end

  test "decoding ConfirmedEventNotification" do
    assert {:ok,
            %ConfirmedEventNotification{
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
             ConfirmedEventNotification.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_event_notification,
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

  test "decoding ConfirmedEventNotification 2" do
    assert {:ok,
            %ConfirmedEventNotification{
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
                    property_identifier: :alarm_value,
                    property_array_index: nil,
                    property_value: %Encoding{
                      encoding: :primitive,
                      extras: [],
                      type: :character_string,
                      value: "StockingNAE"
                    },
                    priority: 5
                  }
                ]
              }
            }} =
             ConfirmedEventNotification.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_event_notification,
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
                        tagged: {0, <<6>>, 1},
                        constructed: {2, {:character_string, "StockingNAE"}, 0},
                        tagged: {3, <<5>>, 1}
                      ], 0}}, 0}
               ]
             })
  end

  test "decoding ConfirmedEventNotification invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             ConfirmedEventNotification.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_event_notification,
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

  test "decoding ConfirmedEventNotification invalid process identifier" do
    assert {:error, :invalid_process_identifier_value} =
             ConfirmedEventNotification.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_event_notification,
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

  test "decoding ConfirmedEventNotification invalid priority" do
    assert {:error, :invalid_priority_value} =
             ConfirmedEventNotification.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_event_notification,
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

  test "decoding ConfirmedEventNotification invalid APDU" do
    assert {:error, :invalid_request} =
             ConfirmedEventNotification.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_text_notification,
               parameters: []
             })
  end

  test "encoding ConfirmedEventNotification" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :confirmed_event_notification,
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
             ConfirmedEventNotification.to_apdu(
               %ConfirmedEventNotification{
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
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding ConfirmedEventNotification 2" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :confirmed_event_notification,
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
                       tagged: {0, <<6>>, 1},
                       constructed: {2, {:character_string, "StockingNAE"}, 0},
                       tagged: {3, <<5>>, 1}
                     ], 0}}, 0}
              ]
            }} =
             ConfirmedEventNotification.to_apdu(
               %ConfirmedEventNotification{
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
                       property_identifier: :alarm_value,
                       property_array_index: nil,
                       property_value: %Encoding{
                         encoding: :primitive,
                         extras: [],
                         type: :character_string,
                         value: "StockingNAE"
                       },
                       priority: 5
                     }
                   ]
                 }
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding ConfirmedEventNotification invalid process identifier" do
    assert {:error, :invalid_process_identifier_value} =
             ConfirmedEventNotification.to_apdu(
               %ConfirmedEventNotification{
                 process_identifier: 123_531_124_053_125_532,
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
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding ConfirmedEventNotification invalid priority" do
    assert {:error, :invalid_priority_value} =
             ConfirmedEventNotification.to_apdu(
               %ConfirmedEventNotification{
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
                 priority: 512,
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
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "protocol implementation get name" do
    assert :confirmed_event_notification ==
             ServicesProtocol.get_name(%ConfirmedEventNotification{
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
    assert true ==
             ServicesProtocol.is_confirmed(%ConfirmedEventNotification{
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
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :confirmed_event_notification,
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
                       tagged: {0, <<6>>, 1},
                       constructed: {2, {:character_string, "StockingNAE"}, 0},
                       tagged: {3, <<5>>, 1}
                     ], 0}}, 0}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %ConfirmedEventNotification{
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
                       property_identifier: :alarm_value,
                       property_array_index: nil,
                       property_value: %Encoding{
                         encoding: :primitive,
                         extras: [],
                         type: :character_string,
                         value: "StockingNAE"
                       },
                       priority: 5
                     }
                   ]
                 }
               },
               invoke_id: 1,
               max_segments: 4
             )
  end
end
