defmodule BACnet.Protocol.EventLogRecordTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.BACnetTimestamp
  alias BACnet.Protocol.EventLogRecord
  alias BACnet.Protocol.LogStatus
  alias BACnet.Protocol.NotificationParameters.ComplexEventType
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.PropertyValue
  alias BACnet.Protocol.Services.ConfirmedEventNotification

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest EventLogRecord

  test "decode invalid record missing pattern" do
    assert {:error, :invalid_tags} =
             EventLogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {2, {:tagged, {0, <<4, 0>>, 2}}, 0}
             )
  end

  test "decode invalid record invalid date time" do
    assert {:error, :invalid_tags} =
             EventLogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), date: BACnetTime.utc_now()], 0}
             )
  end

  test "decode invalid record invalid tagged encoding" do
    assert {:error, :unknown_tag_encoding} =
             EventLogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {0, <<>>, 0}}, 0}
             )
  end

  test "decode invalid record unknown tag number" do
    assert {:error, :invalid_tags} =
             EventLogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {255, <<>>, 0}}, 0}
             )
  end

  test "decode record with status" do
    assert {:ok,
            {%EventLogRecord{
               timestamp: %BACnetDateTime{},
               log_datum: %LogStatus{
                 log_disabled: false,
                 buffer_purged: false,
                 log_interrupted: false
               }
             }, []}} =
             EventLogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {0, <<5, 0>>, 2}}, 0}
             )
  end

  test "decode invalid record with status invalid bitstring" do
    assert {:error, :invalid_tags} =
             EventLogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {0, <<4, 0>>, 2}}, 0}
             )
  end

  test "decode record with event" do
    assert {:ok,
            {%EventLogRecord{
               timestamp: %BACnetDateTime{},
               log_datum: %ConfirmedEventNotification{
                 process_identifier: 123,
                 notification_class: 1,
                 priority: 200,
                 event_type: :complex_event_type
               }
             }, []}} =
             EventLogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed:
                 {1,
                  {:constructed,
                   {1,
                    [
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
                    ], 0}}, 0}
             )
  end

  test "decode invalid record with event" do
    assert {:error, :invalid_request_parameters} =
             EventLogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:constructed, {1, [], 0}}, 0}
             )
  end

  test "decode record with time change" do
    assert {:ok,
            {%EventLogRecord{
               timestamp: %BACnetDateTime{},
               log_datum: {:time_change, +0.0}
             }, []}} =
             EventLogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {2, <<0, 0, 0, 0>>, 4}}, 0}
             )
  end

  test "decode invalid record with time change" do
    assert {:error, :invalid_tags} =
             EventLogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {2, <<0, 0>>, 2}}, 0}
             )
  end

  test "decode invalid record with time change invalid value" do
    assert {:error, :invalid_data} =
             EventLogRecord.parse(
               constructed: {0, [date: BACnetDate.utc_today(), time: BACnetTime.utc_now()], 0},
               constructed: {1, {:tagged, {2, <<>>, 4}}, 0}
             )
  end

  test "encode record with status" do
    assert {:ok,
            [
              constructed: {0, [date: %BACnetDate{}, time: %BACnetTime{}], 0},
              constructed: {1, {:tagged, {0, <<5, 0>>, 2}}, 0}
            ]} =
             EventLogRecord.encode(%EventLogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %LogStatus{
                 log_disabled: false,
                 buffer_purged: false,
                 log_interrupted: false
               }
             })
  end

  test "encode record with event" do
    assert {:ok,
            [
              constructed: {0, [date: %BACnetDate{}, time: %BACnetTime{}], 0},
              constructed:
                {1,
                 {:constructed,
                  {1,
                   [
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
                   ], 0}}, 0}
            ]} =
             EventLogRecord.encode(%EventLogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %ConfirmedEventNotification{
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
               }
             })
  end

  test "encode record with time change" do
    assert {:ok,
            [
              constructed: {0, [date: %BACnetDate{}, time: %BACnetTime{}], 0},
              constructed: {1, {:tagged, {2, <<0, 0, 0, 0>>, 4}}, 0}
            ]} =
             EventLogRecord.encode(%EventLogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: {:time_change, +0.0}
             })
  end

  test "encode invalid record with event" do
    assert {:error, :invalid_value} =
             EventLogRecord.encode(%EventLogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %ConfirmedEventNotification{
                 process_identifier: 21,
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
                 notification_class: :hello,
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
               }
             })
  end

  test "valid record" do
    assert true ==
             EventLogRecord.valid?(%EventLogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %LogStatus{
                 log_disabled: false,
                 buffer_purged: false,
                 log_interrupted: false
               }
             })

    assert true ==
             EventLogRecord.valid?(%EventLogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %ConfirmedEventNotification{
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
               }
             })

    assert true ==
             EventLogRecord.valid?(%EventLogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: {:time_change, +0.0}
             })
  end

  test "invalid record" do
    assert false ==
             EventLogRecord.valid?(%EventLogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: :hello
             })

    assert false ==
             EventLogRecord.valid?(%EventLogRecord{
               timestamp: :hello,
               log_datum: %LogStatus{
                 log_disabled: false,
                 buffer_purged: false,
                 log_interrupted: false
               }
             })

    assert false ==
             EventLogRecord.valid?(%EventLogRecord{
               timestamp: %BACnetDateTime{
                 date: :hello,
                 time: BACnetTime.utc_now()
               },
               log_datum: %LogStatus{
                 log_disabled: false,
                 buffer_purged: false,
                 log_interrupted: false
               }
             })

    assert false ==
             EventLogRecord.valid?(%EventLogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: :hello
             })

    assert false ==
             EventLogRecord.valid?(%EventLogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: %LogStatus{
                 log_disabled: :hello,
                 buffer_purged: false,
                 log_interrupted: false
               }
             })

    assert false ==
             EventLogRecord.valid?(%EventLogRecord{
               timestamp: :hello,
               log_datum: %ConfirmedEventNotification{
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
               }
             })

    assert false ==
             EventLogRecord.valid?(%EventLogRecord{
               timestamp: %BACnetDateTime{
                 date: :hello,
                 time: BACnetTime.utc_now()
               },
               log_datum: %ConfirmedEventNotification{
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
               }
             })

    assert false ==
             EventLogRecord.valid?(%EventLogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: :hello
             })

    assert false ==
             EventLogRecord.valid?(%EventLogRecord{
               timestamp: :hello,
               log_datum: {:time_change, +0.0}
             })

    assert false ==
             EventLogRecord.valid?(%EventLogRecord{
               timestamp: %BACnetDateTime{
                 date: :hello,
                 time: BACnetTime.utc_now()
               },
               log_datum: {:time_change, +0.0}
             })

    assert false ==
             EventLogRecord.valid?(%EventLogRecord{
               timestamp: BACnetDateTime.utc_now(),
               log_datum: {:time_change, 0}
             })
  end
end
