defmodule BACnet.Test.Protocol.Services.GetEventInformationAckTest do
  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.APDU.SimpleACK
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.BACnetTimestamp
  alias BACnet.Protocol.EventInformation
  alias BACnet.Protocol.EventTimestamps
  alias BACnet.Protocol.EventTransitionBits
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.Ack.GetEventInformationAck

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service
  @moduletag :service_ack

  doctest GetEventInformationAck

  test "decoding GetEventInformationAck" do
    assert {:ok,
            %GetEventInformationAck{
              events: [
                %EventInformation{
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
                },
                %EventInformation{
                  object_identifier: %ObjectIdentifier{
                    type: :analog_input,
                    instance: 3
                  },
                  event_state: :normal,
                  acknowledged_transitions: %EventTransitionBits{
                    to_offnormal: true,
                    to_fault: true,
                    to_normal: false
                  },
                  event_timestamps: %EventTimestamps{
                    to_offnormal: %BACnetTimestamp{
                      type: :time,
                      time: %BACnetTime{
                        hour: 15,
                        minute: 40,
                        second: 0,
                        hundredth: 0
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
                        hour: 15,
                        minute: 45,
                        second: 30,
                        hundredth: 30
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
                }
              ],
              more_events: false
            }} ==
             GetEventInformationAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_event_information,
               payload: [
                 constructed:
                   {0,
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
                        {6, [unsigned_integer: 15, unsigned_integer: 15, unsigned_integer: 20], 0},
                      tagged: {0, <<0, 0, 0, 3>>, 4},
                      tagged: {1, <<0>>, 1},
                      tagged: {2, <<5, 192>>, 2},
                      constructed:
                        {3,
                         [
                           tagged: {0, <<15, 40, 0, 0>>, 4},
                           tagged: {0, <<255, 255, 255, 255>>, 4},
                           tagged: {0, <<15, 45, 30, 30>>, 4}
                         ], 0},
                      tagged: {4, <<0>>, 1},
                      tagged: {5, <<5, 224>>, 2},
                      constructed:
                        {6, [unsigned_integer: 15, unsigned_integer: 15, unsigned_integer: 20], 0}
                    ], 0},
                 tagged: {1, <<0>>, 1}
               ]
             })
  end

  test "decoding GetEventInformationAck invalid missing pattern" do
    assert {:error, :invalid_service_ack} =
             GetEventInformationAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_event_information,
               payload: [
                 constructed:
                   {0,
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
                        {6, [unsigned_integer: 15, unsigned_integer: 15, unsigned_integer: 20], 0},
                      tagged: {0, <<0, 0, 0, 3>>, 4},
                      tagged: {1, <<0>>, 1},
                      tagged: {2, <<5, 192>>, 2},
                      constructed:
                        {3,
                         [
                           tagged: {0, <<15, 40, 0, 0>>, 4},
                           tagged: {0, <<255, 255, 255, 255>>, 4},
                           tagged: {0, <<15, 45, 30, 30>>, 4}
                         ], 0},
                      tagged: {4, <<0>>, 1},
                      tagged: {5, <<5, 224>>, 2},
                      constructed:
                        {6, [unsigned_integer: 15, unsigned_integer: 15, unsigned_integer: 20], 0}
                    ], 0}
               ]
             })
  end

  test "decoding GetEventInformationAck invalid 2" do
    assert {:error, :invalid_service_ack} =
             GetEventInformationAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_event_information,
               payload: [
                 constructed:
                   {0,
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
                      tagged: {5, <<5, 224>>, 2}
                    ], 0},
                 tagged: {1, <<0>>, 1}
               ]
             })
  end

  test "decoding GetEventInformationAck invalid data" do
    assert {:error, :invalid_data} =
             GetEventInformationAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_event_information,
               payload: [
                 constructed: {0, [tagged: {0, <<>>, 4}], 0},
                 tagged: {1, <<0>>, 1}
               ]
             })
  end

  test "decoding GetEventInformationAck invalid wrong ACK" do
    assert {:error, :invalid_service_ack} =
             GetEventInformationAck.from_apdu(%SimpleACK{
               invoke_id: 0,
               service: :unconfirmed_service_request
             })
  end

  test "encoding GetEventInformationAck" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 55,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :get_event_information,
              payload: [
                constructed:
                  {0,
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
                       {6, [unsigned_integer: 15, unsigned_integer: 15, unsigned_integer: 20], 0},
                     tagged: {0, <<0, 0, 0, 3>>, 4},
                     tagged: {1, <<0>>, 1},
                     tagged: {2, <<5, 192>>, 2},
                     constructed:
                       {3,
                        [
                          tagged: {0, <<15, 40, 0, 0>>, 4},
                          tagged: {0, <<255, 255, 255, 255>>, 4},
                          tagged: {0, <<15, 45, 30, 30>>, 4}
                        ], 0},
                     tagged: {4, <<0>>, 1},
                     tagged: {5, <<5, 224>>, 2},
                     constructed:
                       {6, [unsigned_integer: 15, unsigned_integer: 15, unsigned_integer: 20], 0}
                   ], 0},
                tagged: {1, <<0>>, 1}
              ]
            }} ==
             GetEventInformationAck.to_apdu(
               %GetEventInformationAck{
                 events: [
                   %EventInformation{
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
                   },
                   %EventInformation{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_input,
                       instance: 3
                     },
                     event_state: :normal,
                     acknowledged_transitions: %EventTransitionBits{
                       to_offnormal: true,
                       to_fault: true,
                       to_normal: false
                     },
                     event_timestamps: %EventTimestamps{
                       to_offnormal: %BACnetTimestamp{
                         type: :time,
                         time: %BACnetTime{
                           hour: 15,
                           minute: 40,
                           second: 0,
                           hundredth: 0
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
                           hour: 15,
                           minute: 45,
                           second: 30,
                           hundredth: 30
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
                   }
                 ],
                 more_events: false
               },
               55
             )
  end

  test "encoding GetEventInformationAck with optional invoke_id" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 0,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :get_event_information,
              payload: [
                constructed:
                  {0,
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
                   ], 0},
                tagged: {1, <<1>>, 1}
              ]
            }} ==
             GetEventInformationAck.to_apdu(%GetEventInformationAck{
               events: [
                 %EventInformation{
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
                 }
               ],
               more_events: true
             })
  end

  test "encoding GetEventInformationAck invalid event" do
    assert {:error, :invalid_value} ==
             GetEventInformationAck.to_apdu(%GetEventInformationAck{
               events: [
                 %EventInformation{
                   object_identifier: :hello_there,
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
                 }
               ],
               more_events: true
             })
  end

  test "encoding GetEventInformationAck invalid invoke_id" do
    assert {:error, :invalid_parameter} ==
             GetEventInformationAck.to_apdu(
               %GetEventInformationAck{
                 events: [],
                 more_events: false
               },
               256
             )
  end
end
