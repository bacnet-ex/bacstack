defmodule BACnet.Test.Protocol.Services.GetAlarmSummaryAckTest do
  alias BACnet.Protocol.AlarmSummary
  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.APDU.SimpleACK
  alias BACnet.Protocol.EventTransitionBits
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.Ack.GetAlarmSummaryAck

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service
  @moduletag :service_ack

  doctest GetAlarmSummaryAck

  test "decoding GetAlarmSummaryAck" do
    assert {:ok,
            %GetAlarmSummaryAck{
              summaries: [
                %AlarmSummary{
                  object_identifier: %ObjectIdentifier{
                    type: :analog_input,
                    instance: 2
                  },
                  alarm_state: :high_limit,
                  acknowledged_transitions: %EventTransitionBits{
                    to_offnormal: false,
                    to_fault: true,
                    to_normal: true
                  }
                },
                %AlarmSummary{
                  object_identifier: %ObjectIdentifier{
                    type: :analog_input,
                    instance: 3
                  },
                  alarm_state: :low_limit,
                  acknowledged_transitions: %EventTransitionBits{
                    to_offnormal: true,
                    to_fault: true,
                    to_normal: true
                  }
                }
              ]
            }} ==
             GetAlarmSummaryAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_alarm_summary,
               payload: [
                 object_identifier: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 2
                 },
                 enumerated: 3,
                 bitstring: {false, true, true},
                 object_identifier: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 3
                 },
                 enumerated: 4,
                 bitstring: {true, true, true}
               ]
             })
  end

  test "decoding GetAlarmSummaryAck invalid missing pattern" do
    assert {:error, :invalid_service_ack} =
             GetAlarmSummaryAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_alarm_summary,
               payload: [
                 object_identifier: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 2
                 },
                 enumerated: 3,
                 bitstring: {false, true, true},
                 object_identifier: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 3
                 },
                 enumerated: 4
               ]
             })
  end

  test "decoding GetAlarmSummaryAck invalid tags" do
    assert {:error, :invalid_service_ack} ==
             GetAlarmSummaryAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_alarm_summary,
               payload: [
                 object_identifier: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 2
                 },
                 enumerated: 3
               ]
             })
  end

  test "decoding GetAlarmSummaryAck invalid wrong ACK" do
    assert {:error, :invalid_service_ack} =
             GetAlarmSummaryAck.from_apdu(%SimpleACK{
               invoke_id: 0,
               service: :unconfirmed_service_request
             })
  end

  test "encoding GetAlarmSummaryAck" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 55,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :get_alarm_summary,
              payload: [
                object_identifier: %ObjectIdentifier{
                  type: :analog_input,
                  instance: 2
                },
                enumerated: 3,
                bitstring: {false, true, true},
                object_identifier: %ObjectIdentifier{
                  type: :analog_input,
                  instance: 3
                },
                enumerated: 4,
                bitstring: {true, true, true}
              ]
            }} ==
             GetAlarmSummaryAck.to_apdu(
               %GetAlarmSummaryAck{
                 summaries: [
                   %AlarmSummary{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_input,
                       instance: 2
                     },
                     alarm_state: :high_limit,
                     acknowledged_transitions: %EventTransitionBits{
                       to_offnormal: false,
                       to_fault: true,
                       to_normal: true
                     }
                   },
                   %AlarmSummary{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_input,
                       instance: 3
                     },
                     alarm_state: :low_limit,
                     acknowledged_transitions: %EventTransitionBits{
                       to_offnormal: true,
                       to_fault: true,
                       to_normal: true
                     }
                   }
                 ]
               },
               55
             )
  end

  test "encoding GetAlarmSummaryAck with optional invoke_id" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 0,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :get_alarm_summary,
              payload: [
                object_identifier: %ObjectIdentifier{
                  type: :analog_input,
                  instance: 2
                },
                enumerated: 3,
                bitstring: {false, true, true}
              ]
            }} ==
             GetAlarmSummaryAck.to_apdu(%GetAlarmSummaryAck{
               summaries: [
                 %AlarmSummary{
                   object_identifier: %ObjectIdentifier{
                     type: :analog_input,
                     instance: 2
                   },
                   alarm_state: :high_limit,
                   acknowledged_transitions: %EventTransitionBits{
                     to_offnormal: false,
                     to_fault: true,
                     to_normal: true
                   }
                 }
               ]
             })
  end

  test "encoding GetAlarmSummaryAck invalid summary alarm state" do
    assert {:error, {:unknown_state, :hello_there}} ==
             GetAlarmSummaryAck.to_apdu(%GetAlarmSummaryAck{
               summaries: [
                 %AlarmSummary{
                   object_identifier: %ObjectIdentifier{
                     type: :analog_input,
                     instance: 2
                   },
                   alarm_state: :hello_there,
                   acknowledged_transitions: %EventTransitionBits{
                     to_offnormal: false,
                     to_fault: true,
                     to_normal: true
                   }
                 }
               ]
             })
  end

  test "encoding GetAlarmSummaryAck invalid invoke_id" do
    assert {:error, :invalid_parameter} ==
             GetAlarmSummaryAck.to_apdu(
               %GetAlarmSummaryAck{
                 summaries: [
                   %AlarmSummary{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_input,
                       instance: 2
                     },
                     alarm_state: :high_limit,
                     acknowledged_transitions: %EventTransitionBits{
                       to_offnormal: false,
                       to_fault: true,
                       to_normal: true
                     }
                   }
                 ]
               },
               256
             )
  end
end
