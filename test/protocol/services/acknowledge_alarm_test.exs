defmodule BACnet.Test.Protocol.Services.AcknowledgeAlarmTest do
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.Services.AcknowledgeAlarm
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest AcknowledgeAlarm

  test "get name" do
    assert :acknowledge_alarm == AcknowledgeAlarm.get_name()
  end

  test "is confirmed" do
    assert true == AcknowledgeAlarm.is_confirmed()
  end

  test "decoding AcknowledgeAlarm" do
    assert {:ok,
            %AcknowledgeAlarm{
              process_identifier: 13_580,
              event_object: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 13_580},
              event_state_acknowledged: :normal,
              event_timestamp: %BACnet.Protocol.BACnetTimestamp{
                type: :time,
                time: %BACnet.Protocol.BACnetTime{hour: 2, minute: 12, second: 49, hundredth: 0},
                sequence_number: nil,
                datetime: nil
              },
              acknowledge_source: "Hello World",
              time_of_ack: %BACnet.Protocol.BACnetTimestamp{
                type: :time,
                time: %BACnet.Protocol.BACnetTime{hour: 5, minute: 19, second: 11, hundredth: 15},
                sequence_number: nil,
                datetime: nil
              }
            }} =
             AcknowledgeAlarm.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :acknowledge_alarm,
               parameters: [
                 {:tagged, {0, <<0, 0, 53, 12>>, 4}},
                 {:tagged, {1, <<2, 0, 53, 12>>, 4}},
                 {:tagged, {2, <<0>>, 1}},
                 {:constructed, {3, {:tagged, {0, <<2, 12, 49, 0>>, 4}}, 0}},
                 {:tagged, {4, "\0Hello World", 12}},
                 {:constructed, {5, {:tagged, {0, <<5, 19, 11, 15>>, 4}}, 0}}
               ]
             })
  end

  test "decoding AcknowledgeAlarm unsupported charset" do
    assert {:ok,
            %AcknowledgeAlarm{
              process_identifier: 13_580,
              event_object: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 13_580},
              event_state_acknowledged: :fault,
              event_timestamp: %BACnet.Protocol.BACnetTimestamp{
                type: :time,
                time: %BACnet.Protocol.BACnetTime{hour: 2, minute: 12, second: 49, hundredth: 0},
                sequence_number: nil,
                datetime: nil
              },
              acknowledge_source: "",
              time_of_ack: %BACnet.Protocol.BACnetTimestamp{
                type: :time,
                time: %BACnet.Protocol.BACnetTime{hour: 5, minute: 19, second: 11, hundredth: 15},
                sequence_number: nil,
                datetime: nil
              }
            }} =
             AcknowledgeAlarm.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :acknowledge_alarm,
               parameters: [
                 {:tagged, {0, <<0, 0, 53, 12>>, 4}},
                 {:tagged, {1, <<2, 0, 53, 12>>, 4}},
                 {:tagged, {2, <<1>>, 1}},
                 {:constructed, {3, {:tagged, {0, <<2, 12, 49, 0>>, 4}}, 0}},
                 {:tagged, {4, "\x15Hello World", 12}},
                 {:constructed, {5, {:tagged, {0, <<5, 19, 11, 15>>, 4}}, 0}}
               ]
             })
  end

  test "decoding AcknowledgeAlarm invalid missing source" do
    assert {:error, :invalid_request_parameters} =
             AcknowledgeAlarm.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :acknowledge_alarm,
               parameters: [
                 {:tagged, {0, <<0, 0, 53, 12>>, 4}},
                 {:tagged, {1, <<2, 0, 53, 12>>, 4}},
                 {:tagged, {2, <<1>>, 1}},
                 {:constructed, {3, {:tagged, {0, <<2, 12, 49, 0>>, 4}}, 0}}
               ]
             })
  end

  test "decoding AcknowledgeAlarm invalid unknown tag encoding" do
    assert {:error, :unknown_tag_encoding} =
             AcknowledgeAlarm.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :acknowledge_alarm,
               parameters: [{:tagged, {0, <<>>, 0}}]
             })
  end

  test "decoding AcknowledgeAlarm invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             AcknowledgeAlarm.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :acknowledge_alarm,
               parameters: [{:tagged, {0, <<0, 0, 53, 12>>, 4}}]
             })
  end

  test "decoding AcknowledgeAlarm invalid process identifier" do
    assert {:error, :invalid_process_identifier_value} =
             AcknowledgeAlarm.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :acknowledge_alarm,
               parameters: [
                 {:tagged, {0, <<255, 255, 255, 255, 255, 255>>, 6}},
                 {:tagged, {1, <<2, 0, 53, 12>>, 4}},
                 {:tagged, {2, <<0>>, 1}},
                 {:constructed, {3, {:tagged, {0, <<2, 12, 49, 0>>, 4}}, 0}},
                 {:tagged, {4, "\0Hello World", 12}},
                 {:constructed, {5, {:tagged, {0, <<5, 19, 11, 15>>, 4}}, 0}}
               ]
             })
  end

  test "decoding AcknowledgeAlarm invalid APDU" do
    assert {:error, :invalid_request} =
             AcknowledgeAlarm.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_alarm_summary,
               parameters: []
             })
  end

  test "encoding AcknowledgeAlarm" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :acknowledge_alarm,
              parameters: [
                {:tagged, {0, <<53, 12>>, 2}},
                {:tagged, {1, <<2, 0, 53, 12>>, 4}},
                {:tagged, {2, <<0>>, 1}},
                {:constructed, {3, {:tagged, {0, <<2, 12, 49, 0>>, 4}}, 0}},
                {:tagged, {4, "\0Hello World", 12}},
                {:constructed, {5, {:tagged, {0, <<5, 19, 11, 15>>, 4}}, 0}}
              ]
            }} =
             AcknowledgeAlarm.to_apdu(
               %AcknowledgeAlarm{
                 process_identifier: 13_580,
                 event_object: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 13_580},
                 event_state_acknowledged: :normal,
                 event_timestamp: %BACnet.Protocol.BACnetTimestamp{
                   type: :time,
                   time: %BACnet.Protocol.BACnetTime{
                     hour: 2,
                     minute: 12,
                     second: 49,
                     hundredth: 0
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 acknowledge_source: "Hello World",
                 time_of_ack: %BACnet.Protocol.BACnetTimestamp{
                   type: :time,
                   time: %BACnet.Protocol.BACnetTime{
                     hour: 5,
                     minute: 19,
                     second: 11,
                     hundredth: 15
                   },
                   sequence_number: nil,
                   datetime: nil
                 }
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding AcknowledgeAlarm invalid process identifier" do
    assert {:error, :invalid_process_identifier_value} =
             AcknowledgeAlarm.to_apdu(
               %AcknowledgeAlarm{
                 process_identifier: 13_580_850_125_533_124_512,
                 event_object: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 13_580},
                 event_state_acknowledged: :normal,
                 event_timestamp: %BACnet.Protocol.BACnetTimestamp{
                   type: :time,
                   time: %BACnet.Protocol.BACnetTime{
                     hour: 2,
                     minute: 12,
                     second: 49,
                     hundredth: 0
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 acknowledge_source: "Hello World",
                 time_of_ack: %BACnet.Protocol.BACnetTimestamp{
                   type: :time,
                   time: %BACnet.Protocol.BACnetTime{
                     hour: 5,
                     minute: 19,
                     second: 11,
                     hundredth: 15
                   },
                   sequence_number: nil,
                   datetime: nil
                 }
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "protocol implementation get name" do
    assert :acknowledge_alarm ==
             ServicesProtocol.get_name(%AcknowledgeAlarm{
               process_identifier: 13_580,
               event_object: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 13_580},
               event_state_acknowledged: :normal,
               event_timestamp: %BACnet.Protocol.BACnetTimestamp{
                 type: :time,
                 time: %BACnet.Protocol.BACnetTime{
                   hour: 2,
                   minute: 12,
                   second: 49,
                   hundredth: 0
                 },
                 sequence_number: nil,
                 datetime: nil
               },
               acknowledge_source: "Hello World",
               time_of_ack: %BACnet.Protocol.BACnetTimestamp{
                 type: :time,
                 time: %BACnet.Protocol.BACnetTime{
                   hour: 5,
                   minute: 19,
                   second: 11,
                   hundredth: 15
                 },
                 sequence_number: nil,
                 datetime: nil
               }
             })
  end

  test "protocol implementation is confirmed" do
    assert true ==
             ServicesProtocol.is_confirmed(%AcknowledgeAlarm{
               process_identifier: 13_580,
               event_object: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 13_580},
               event_state_acknowledged: :normal,
               event_timestamp: %BACnet.Protocol.BACnetTimestamp{
                 type: :time,
                 time: %BACnet.Protocol.BACnetTime{
                   hour: 2,
                   minute: 12,
                   second: 49,
                   hundredth: 0
                 },
                 sequence_number: nil,
                 datetime: nil
               },
               acknowledge_source: "Hello World",
               time_of_ack: %BACnet.Protocol.BACnetTimestamp{
                 type: :time,
                 time: %BACnet.Protocol.BACnetTime{
                   hour: 5,
                   minute: 19,
                   second: 11,
                   hundredth: 15
                 },
                 sequence_number: nil,
                 datetime: nil
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
              service: :acknowledge_alarm,
              parameters: [
                {:tagged, {0, <<53, 12>>, 2}},
                {:tagged, {1, <<2, 0, 53, 12>>, 4}},
                {:tagged, {2, <<0>>, 1}},
                {:constructed, {3, {:tagged, {0, <<2, 12, 49, 0>>, 4}}, 0}},
                {:tagged, {4, "\0Hello World", 12}},
                {:constructed, {5, {:tagged, {0, <<5, 19, 11, 15>>, 4}}, 0}}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %AcknowledgeAlarm{
                 process_identifier: 13_580,
                 event_object: %BACnet.Protocol.ObjectIdentifier{type: :device, instance: 13_580},
                 event_state_acknowledged: :normal,
                 event_timestamp: %BACnet.Protocol.BACnetTimestamp{
                   type: :time,
                   time: %BACnet.Protocol.BACnetTime{
                     hour: 2,
                     minute: 12,
                     second: 49,
                     hundredth: 0
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 acknowledge_source: "Hello World",
                 time_of_ack: %BACnet.Protocol.BACnetTimestamp{
                   type: :time,
                   time: %BACnet.Protocol.BACnetTime{
                     hour: 5,
                     minute: 19,
                     second: 11,
                     hundredth: 15
                   },
                   sequence_number: nil,
                   datetime: nil
                 }
               },
               invoke_id: 1,
               max_segments: 4
             )
  end
end
