defmodule BACnet.Protocol.EventInformationTest do
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.BACnetTimestamp
  alias BACnet.Protocol.EventInformation
  alias BACnet.Protocol.EventTimestamps
  alias BACnet.Protocol.EventTransitionBits
  alias BACnet.Protocol.ObjectIdentifier

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest EventInformation

  test "decode event info" do
    assert {:ok,
            {%EventInformation{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               event_state: :high_limit,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: true,
                 to_normal: true
               },
               event_timestamps: %EventTimestamps{
                 to_offnormal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: 15,
                     minute: 35,
                     second: 0,
                     hundredth: 20
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_fault: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_normal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 }
               },
               notify_type: :alarm,
               event_enable: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               event_priorities: {15, 15, 20}
             }, []}} =
             EventInformation.parse(
               tagged: {0, <<0, 0, 0, 2>>, 4},
               tagged: {1, <<3>>, 1},
               tagged: {2, <<5, 96>>, 2},
               constructed:
                 {3,
                  [
                    tagged: {0, <<15, 35, 0, 20>>, 4},
                    tagged: {0, <<255, 255, 255, 255>>, 4},
                    tagged: {0, <<255, 255, 255, 255>>, 4}
                  ], 0},
               tagged: {4, <<0>>, 1},
               tagged: {5, <<5, 224>>, 2},
               constructed:
                 {6, [unsigned_integer: 15, unsigned_integer: 15, unsigned_integer: 20], 0}
             )
  end

  test "decode invalid event info wrong timestamps" do
    assert {:error, :invalid_tags} =
             EventInformation.parse(
               tagged: {0, <<0, 0, 0, 2>>, 4},
               tagged: {1, <<3>>, 1},
               tagged: {2, <<5, 96>>, 2},
               constructed: {3, [], 0},
               tagged: {4, <<0>>, 1},
               tagged: {5, <<5, 224>>, 2},
               constructed:
                 {6, [unsigned_integer: 15, unsigned_integer: 15, unsigned_integer: 20], 0}
             )
  end

  test "decode invalid event info missing tags" do
    assert {:error, :invalid_tags} =
             EventInformation.parse(
               tagged: {0, <<0, 0, 0, 2>>, 4},
               tagged: {1, <<3>>, 1},
               tagged: {2, <<5, 96>>, 2},
               constructed:
                 {3,
                  [
                    tagged: {5, <<15, 35, 0, 20>>, 4},
                    tagged: {0, <<255, 255, 255, 255>>, 4},
                    tagged: {0, <<255, 255, 255, 255>>, 4}
                  ], 0},
               tagged: {4, <<0>>, 1},
               tagged: {5, <<5, 224>>, 2},
               constructed:
                 {6, [unsigned_integer: 15, unsigned_integer: 15, unsigned_integer: 20], 0}
             )
  end

  test "decode invalid event info invalid timestamp" do
    assert {:error, :invalid_tags} =
             EventInformation.parse(
               tagged: {0, <<0, 0, 0, 2>>, 4},
               tagged: {1, <<3>>, 1},
               tagged: {2, <<5, 96>>, 2}
             )
  end

  test "decode invalid event info unknown state" do
    assert {:error, {:unknown_state, 255}} =
             EventInformation.parse(
               tagged: {0, <<0, 0, 0, 2>>, 4},
               tagged: {1, <<255>>, 1},
               tagged: {2, <<5, 96>>, 2},
               constructed:
                 {3,
                  [
                    tagged: {0, <<15, 35, 0, 20>>, 4},
                    tagged: {0, <<255, 255, 255, 255>>, 4},
                    tagged: {0, <<255, 255, 255, 255>>, 4}
                  ], 0},
               tagged: {4, <<0>>, 1},
               tagged: {5, <<5, 224>>, 2},
               constructed:
                 {6, [unsigned_integer: 15, unsigned_integer: 15, unsigned_integer: 20], 0}
             )
  end

  test "decode invalid event info unknown notify type" do
    assert {:error, {:unknown_notify_type, 255}} =
             EventInformation.parse(
               tagged: {0, <<0, 0, 0, 2>>, 4},
               tagged: {1, <<3>>, 1},
               tagged: {2, <<5, 96>>, 2},
               constructed:
                 {3,
                  [
                    tagged: {0, <<15, 35, 0, 20>>, 4},
                    tagged: {0, <<255, 255, 255, 255>>, 4},
                    tagged: {0, <<255, 255, 255, 255>>, 4}
                  ], 0},
               tagged: {4, <<255>>, 1},
               tagged: {5, <<5, 224>>, 2},
               constructed:
                 {6, [unsigned_integer: 15, unsigned_integer: 15, unsigned_integer: 20], 0}
             )
  end

  test "encode event info" do
    assert {:ok,
            [
              tagged: {0, <<0, 0, 0, 2>>, 4},
              tagged: {1, <<3>>, 1},
              tagged: {2, <<5, 96>>, 2},
              constructed:
                {3,
                 [
                   tagged: {0, <<15, 35, 0, 20>>, 4},
                   tagged: {0, <<255, 255, 255, 255>>, 4},
                   tagged: {0, <<255, 255, 255, 255>>, 4}
                 ], 0},
              tagged: {4, <<0>>, 1},
              tagged: {5, <<5, 224>>, 2},
              constructed:
                {6, [unsigned_integer: 15, unsigned_integer: 15, unsigned_integer: 20], 0}
            ]} =
             EventInformation.encode(%EventInformation{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               event_state: :high_limit,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: true,
                 to_normal: true
               },
               event_timestamps: %EventTimestamps{
                 to_offnormal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: 15,
                     minute: 35,
                     second: 0,
                     hundredth: 20
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_fault: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_normal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 }
               },
               notify_type: :alarm,
               event_enable: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               event_priorities: {15, 15, 20}
             })
  end

  test "encode event info unknown state" do
    assert {:error, {:unknown_state, :hello_there}} =
             EventInformation.encode(%EventInformation{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               event_state: :hello_there,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: true,
                 to_normal: true
               },
               event_timestamps: %EventTimestamps{
                 to_offnormal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: 15,
                     minute: 35,
                     second: 0,
                     hundredth: 20
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_fault: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_normal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 }
               },
               notify_type: :alarm,
               event_enable: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               event_priorities: {15, 15, 20}
             })
  end

  test "encode event info unknown notify type" do
    assert {:error, {:unknown_notify_type, :hello_there}} =
             EventInformation.encode(%EventInformation{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               event_state: :high_limit,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: true,
                 to_normal: true
               },
               event_timestamps: %EventTimestamps{
                 to_offnormal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: 15,
                     minute: 35,
                     second: 0,
                     hundredth: 20
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_fault: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_normal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 }
               },
               notify_type: :hello_there,
               event_enable: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               event_priorities: {15, 15, 20}
             })
  end

  test "valid event information" do
    assert true ==
             EventInformation.valid?(%EventInformation{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               event_state: :high_limit,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: true,
                 to_normal: true
               },
               event_timestamps: %EventTimestamps{
                 to_offnormal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: 15,
                     minute: 35,
                     second: 0,
                     hundredth: 20
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_fault: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_normal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 }
               },
               notify_type: :alarm,
               event_enable: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               event_priorities: {15, 15, 20}
             })

    assert true ==
             EventInformation.valid?(%EventInformation{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               event_state: :high_limit,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: true,
                 to_normal: true
               },
               event_timestamps: %EventTimestamps{
                 to_offnormal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: 15,
                     minute: 35,
                     second: 0,
                     hundredth: 20
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_fault: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_normal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 }
               },
               notify_type: :event,
               event_enable: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               event_priorities: {255, 255, 255}
             })
  end

  test "invalid event information" do
    assert false ==
             EventInformation.valid?(%EventInformation{
               object_identifier: :hello,
               event_state: :high_limit,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: true,
                 to_normal: true
               },
               event_timestamps: %EventTimestamps{
                 to_offnormal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: 15,
                     minute: 35,
                     second: 0,
                     hundredth: 20
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_fault: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_normal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 }
               },
               notify_type: :alarm,
               event_enable: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               event_priorities: {15, 15, 20}
             })

    assert false ==
             EventInformation.valid?(%EventInformation{
               object_identifier: %ObjectIdentifier{
                 type: :hello,
                 instance: 2
               },
               event_state: :high_limit,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: true,
                 to_normal: true
               },
               event_timestamps: %EventTimestamps{
                 to_offnormal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: 15,
                     minute: 35,
                     second: 0,
                     hundredth: 20
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_fault: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_normal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 }
               },
               notify_type: :alarm,
               event_enable: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               event_priorities: {15, 15, 20}
             })

    assert false ==
             EventInformation.valid?(%EventInformation{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               event_state: :hello,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: true,
                 to_normal: true
               },
               event_timestamps: %EventTimestamps{
                 to_offnormal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: 15,
                     minute: 35,
                     second: 0,
                     hundredth: 20
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_fault: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_normal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 }
               },
               notify_type: :event,
               event_enable: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               event_priorities: {255, 255, 255}
             })

    assert false ==
             EventInformation.valid?(%EventInformation{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               event_state: :high_limit,
               acknowledged_transitions: :hello,
               event_timestamps: %EventTimestamps{
                 to_offnormal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: 15,
                     minute: 35,
                     second: 0,
                     hundredth: 20
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_fault: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_normal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 }
               },
               notify_type: :alarm,
               event_enable: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               event_priorities: {15, 15, 20}
             })

    assert false ==
             EventInformation.valid?(%EventInformation{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               event_state: :high_limit,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: :hello,
                 to_fault: true,
                 to_normal: true
               },
               event_timestamps: %EventTimestamps{
                 to_offnormal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: 15,
                     minute: 35,
                     second: 0,
                     hundredth: 20
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_fault: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_normal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 }
               },
               notify_type: :alarm,
               event_enable: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               event_priorities: {15, 15, 20}
             })

    assert false ==
             EventInformation.valid?(%EventInformation{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               event_state: :high_limit,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: true,
                 to_normal: true
               },
               event_timestamps: :hello,
               notify_type: :alarm,
               event_enable: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               event_priorities: {15, 15, 20}
             })

    assert false ==
             EventInformation.valid?(%EventInformation{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               event_state: :high_limit,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: true,
                 to_normal: true
               },
               event_timestamps: %EventTimestamps{
                 to_offnormal: :hello,
                 to_fault: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_normal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 }
               },
               notify_type: :alarm,
               event_enable: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               event_priorities: {15, 15, 20}
             })

    assert false ==
             EventInformation.valid?(%EventInformation{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               event_state: :high_limit,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: true,
                 to_normal: true
               },
               event_timestamps: %EventTimestamps{
                 to_offnormal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: 15,
                     minute: 35,
                     second: 0,
                     hundredth: 20
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_fault: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_normal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 }
               },
               notify_type: :hello,
               event_enable: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               event_priorities: {15, 15, 20}
             })

    assert false ==
             EventInformation.valid?(%EventInformation{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               event_state: :high_limit,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: true,
                 to_normal: true
               },
               event_timestamps: %EventTimestamps{
                 to_offnormal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: 15,
                     minute: 35,
                     second: 0,
                     hundredth: 20
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_fault: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_normal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 }
               },
               notify_type: :alarm,
               event_enable: :hello,
               event_priorities: {15, 15, 20}
             })

    assert false ==
             EventInformation.valid?(%EventInformation{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               event_state: :high_limit,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: true,
                 to_normal: true
               },
               event_timestamps: %EventTimestamps{
                 to_offnormal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: 15,
                     minute: 35,
                     second: 0,
                     hundredth: 20
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_fault: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_normal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 }
               },
               notify_type: :alarm,
               event_enable: %EventTransitionBits{
                 to_offnormal: :hello,
                 to_fault: true,
                 to_normal: true
               },
               event_priorities: {15, 15, 20}
             })

    assert false ==
             EventInformation.valid?(%EventInformation{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               event_state: :high_limit,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: true,
                 to_normal: true
               },
               event_timestamps: %EventTimestamps{
                 to_offnormal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: 15,
                     minute: 35,
                     second: 0,
                     hundredth: 20
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_fault: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_normal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 }
               },
               notify_type: :alarm,
               event_enable: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               event_priorities: {-1, 15, 20}
             })

    assert false ==
             EventInformation.valid?(%EventInformation{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               event_state: :high_limit,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: true,
                 to_normal: true
               },
               event_timestamps: %EventTimestamps{
                 to_offnormal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: 15,
                     minute: 35,
                     second: 0,
                     hundredth: 20
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_fault: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_normal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 }
               },
               notify_type: :alarm,
               event_enable: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               event_priorities: {15, 256, 20}
             })

    assert false ==
             EventInformation.valid?(%EventInformation{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               event_state: :high_limit,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: true,
                 to_normal: true
               },
               event_timestamps: %EventTimestamps{
                 to_offnormal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: 15,
                     minute: 35,
                     second: 0,
                     hundredth: 20
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_fault: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 },
                 to_normal: %BACnetTimestamp{
                   type: :time,
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   },
                   sequence_number: nil,
                   datetime: nil
                 }
               },
               notify_type: :alarm,
               event_enable: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: true
               },
               event_priorities: :hello
             })
  end
end
