defmodule BACnet.Test.Protocol.Services.GetEnrollmentSummaryAckTest do
  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.APDU.SimpleACK
  alias BACnet.Protocol.EnrollmentSummary
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.Ack.GetEnrollmentSummaryAck

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service
  @moduletag :service_ack

  doctest GetEnrollmentSummaryAck

  test "decoding GetEnrollmentSummaryAck" do
    assert {:ok,
            %GetEnrollmentSummaryAck{
              summaries: [
                %EnrollmentSummary{
                  object_identifier: %ObjectIdentifier{
                    type: :analog_input,
                    instance: 2
                  },
                  event_type: :out_of_range,
                  event_state: :high_limit,
                  priority: 100,
                  notification_class: 4
                },
                %EnrollmentSummary{
                  object_identifier: %ObjectIdentifier{
                    type: :event_enrollment,
                    instance: 6
                  },
                  event_type: :change_of_state,
                  event_state: :normal,
                  priority: 50,
                  notification_class: 2
                }
              ]
            }} ==
             GetEnrollmentSummaryAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_enrollment_summary,
               payload: [
                 object_identifier: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 2
                 },
                 enumerated: 5,
                 enumerated: 3,
                 unsigned_integer: 100,
                 unsigned_integer: 4,
                 object_identifier: %ObjectIdentifier{
                   type: :event_enrollment,
                   instance: 6
                 },
                 enumerated: 1,
                 enumerated: 0,
                 unsigned_integer: 50,
                 unsigned_integer: 2
               ]
             })
  end

  test "decoding GetEnrollmentSummaryAck 2" do
    assert {:ok,
            %GetEnrollmentSummaryAck{
              summaries: [
                %EnrollmentSummary{
                  object_identifier: %ObjectIdentifier{
                    type: :analog_input,
                    instance: 2
                  },
                  event_type: :out_of_range,
                  event_state: :normal,
                  priority: 8,
                  notification_class: 4
                },
                %EnrollmentSummary{
                  object_identifier: %ObjectIdentifier{
                    type: :analog_input,
                    instance: 3
                  },
                  event_type: :out_of_range,
                  event_state: :normal,
                  priority: 8,
                  notification_class: 4
                },
                %EnrollmentSummary{
                  object_identifier: %ObjectIdentifier{
                    type: :analog_input,
                    instance: 4
                  },
                  event_type: :out_of_range,
                  event_state: :normal,
                  priority: 8,
                  notification_class: 4
                },
                %EnrollmentSummary{
                  object_identifier: %ObjectIdentifier{
                    type: :event_enrollment,
                    instance: 7
                  },
                  event_type: :floating_limit,
                  event_state: :normal,
                  priority: 3,
                  notification_class: 8
                }
              ]
            }} ==
             GetEnrollmentSummaryAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_enrollment_summary,
               payload: [
                 object_identifier: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 2
                 },
                 enumerated: 5,
                 enumerated: 0,
                 unsigned_integer: 8,
                 unsigned_integer: 4,
                 object_identifier: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 3
                 },
                 enumerated: 5,
                 enumerated: 0,
                 unsigned_integer: 8,
                 unsigned_integer: 4,
                 object_identifier: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 4
                 },
                 enumerated: 5,
                 enumerated: 0,
                 unsigned_integer: 8,
                 unsigned_integer: 4,
                 object_identifier: %ObjectIdentifier{
                   type: :event_enrollment,
                   instance: 7
                 },
                 enumerated: 4,
                 enumerated: 0,
                 unsigned_integer: 3,
                 unsigned_integer: 8
               ]
             })
  end

  test "decoding GetEnrollmentSummaryAck without optional" do
    assert {:ok,
            %GetEnrollmentSummaryAck{
              summaries: [
                %EnrollmentSummary{
                  object_identifier: %ObjectIdentifier{
                    type: :analog_input,
                    instance: 2
                  },
                  event_type: :out_of_range,
                  event_state: :high_limit,
                  priority: 100,
                  notification_class: nil
                }
              ]
            }} ==
             GetEnrollmentSummaryAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_enrollment_summary,
               payload: [
                 object_identifier: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 2
                 },
                 enumerated: 5,
                 enumerated: 3,
                 unsigned_integer: 100
               ]
             })
  end

  test "decoding GetEnrollmentSummaryAck invalid missing pattern" do
    assert {:error, :invalid_service_ack} =
             GetEnrollmentSummaryAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_enrollment_summary,
               payload: [
                 object_identifier: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 2
                 },
                 enumerated: 5,
                 enumerated: 0
               ]
             })
  end

  test "decoding GetEnrollmentSummaryAck invalid wrong ACK" do
    assert {:error, :invalid_service_ack} =
             GetEnrollmentSummaryAck.from_apdu(%SimpleACK{
               invoke_id: 0,
               service: :unconfirmed_service_request
             })
  end

  test "encoding GetEnrollmentSummaryAck" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 55,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :get_enrollment_summary,
              payload: [
                object_identifier: %ObjectIdentifier{
                  type: :analog_input,
                  instance: 2
                },
                enumerated: 5,
                enumerated: 3,
                unsigned_integer: 100,
                unsigned_integer: 4,
                object_identifier: %ObjectIdentifier{
                  type: :event_enrollment,
                  instance: 6
                },
                enumerated: 1,
                enumerated: 0,
                unsigned_integer: 50,
                unsigned_integer: 2
              ]
            }} ==
             GetEnrollmentSummaryAck.to_apdu(
               %GetEnrollmentSummaryAck{
                 summaries: [
                   %EnrollmentSummary{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_input,
                       instance: 2
                     },
                     event_type: :out_of_range,
                     event_state: :high_limit,
                     priority: 100,
                     notification_class: 4
                   },
                   %EnrollmentSummary{
                     object_identifier: %ObjectIdentifier{
                       type: :event_enrollment,
                       instance: 6
                     },
                     event_type: :change_of_state,
                     event_state: :normal,
                     priority: 50,
                     notification_class: 2
                   }
                 ]
               },
               55
             )
  end

  test "encoding GetEnrollmentSummaryAck 2" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 0,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :get_enrollment_summary,
              payload: [
                object_identifier: %ObjectIdentifier{
                  type: :analog_input,
                  instance: 2
                },
                enumerated: 5,
                enumerated: 0,
                unsigned_integer: 8,
                unsigned_integer: 4,
                object_identifier: %ObjectIdentifier{
                  type: :analog_input,
                  instance: 3
                },
                enumerated: 5,
                enumerated: 0,
                unsigned_integer: 8,
                unsigned_integer: 4,
                object_identifier: %ObjectIdentifier{
                  type: :analog_input,
                  instance: 4
                },
                enumerated: 5,
                enumerated: 0,
                unsigned_integer: 8,
                unsigned_integer: 4,
                object_identifier: %ObjectIdentifier{
                  type: :event_enrollment,
                  instance: 7
                },
                enumerated: 4,
                enumerated: 0,
                unsigned_integer: 3,
                unsigned_integer: 8
              ]
            }} ==
             GetEnrollmentSummaryAck.to_apdu(%GetEnrollmentSummaryAck{
               summaries: [
                 %EnrollmentSummary{
                   object_identifier: %ObjectIdentifier{
                     type: :analog_input,
                     instance: 2
                   },
                   event_type: :out_of_range,
                   event_state: :normal,
                   priority: 8,
                   notification_class: 4
                 },
                 %EnrollmentSummary{
                   object_identifier: %ObjectIdentifier{
                     type: :analog_input,
                     instance: 3
                   },
                   event_type: :out_of_range,
                   event_state: :normal,
                   priority: 8,
                   notification_class: 4
                 },
                 %EnrollmentSummary{
                   object_identifier: %ObjectIdentifier{
                     type: :analog_input,
                     instance: 4
                   },
                   event_type: :out_of_range,
                   event_state: :normal,
                   priority: 8,
                   notification_class: 4
                 },
                 %EnrollmentSummary{
                   object_identifier: %ObjectIdentifier{
                     type: :event_enrollment,
                     instance: 7
                   },
                   event_type: :floating_limit,
                   event_state: :normal,
                   priority: 3,
                   notification_class: 8
                 }
               ]
             })
  end

  test "encoding GetEnrollmentSummaryAck without optional" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 55,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :get_enrollment_summary,
              payload: [
                object_identifier: %ObjectIdentifier{
                  type: :analog_input,
                  instance: 2
                },
                enumerated: 5,
                enumerated: 3,
                unsigned_integer: 100
              ]
            }} ==
             GetEnrollmentSummaryAck.to_apdu(
               %GetEnrollmentSummaryAck{
                 summaries: [
                   %EnrollmentSummary{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_input,
                       instance: 2
                     },
                     event_type: :out_of_range,
                     event_state: :high_limit,
                     priority: 100,
                     notification_class: nil
                   }
                 ]
               },
               55
             )
  end

  test "encoding GetEnrollmentSummaryAck invalid invoke_id" do
    assert {:error, :invalid_parameter} ==
             GetEnrollmentSummaryAck.to_apdu(
               %GetEnrollmentSummaryAck{
                 summaries: [
                   %EnrollmentSummary{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_input,
                       instance: 2
                     },
                     event_type: :out_of_range,
                     event_state: :high_limit,
                     priority: 100,
                     notification_class: nil
                   }
                 ]
               },
               256
             )
  end

  test "encoding GetEnrollmentSummaryAck invalid event type" do
    assert {:error, {:unknown_type, :hello_there}} ==
             GetEnrollmentSummaryAck.to_apdu(%GetEnrollmentSummaryAck{
               summaries: [
                 %EnrollmentSummary{
                   object_identifier: %ObjectIdentifier{
                     type: :analog_input,
                     instance: 2
                   },
                   event_type: :hello_there,
                   event_state: :high_limit,
                   priority: 100,
                   notification_class: nil
                 }
               ]
             })
  end
end
