defmodule BACnet.Test.Protocol.Services.GetEnrollmentSummaryTest do
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Recipient
  alias BACnet.Protocol.Services.GetEnrollmentSummary
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest GetEnrollmentSummary

  test "get name" do
    assert :get_enrollment_summary == GetEnrollmentSummary.get_name()
  end

  test "is confirmed" do
    assert true == GetEnrollmentSummary.is_confirmed()
  end

  test "decoding GetEnrollmentSummary" do
    assert {:ok,
            %GetEnrollmentSummary{
              acknowledgment_filter: :not_acked,
              enrollment_filter: nil,
              event_state_filter: nil,
              event_type_filter: nil,
              priority_filter: nil,
              notification_class_filter: nil
            }} =
             GetEnrollmentSummary.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_enrollment_summary,
               parameters: [tagged: {0, <<2>>, 1}]
             })
  end

  test "decoding GetEnrollmentSummary with acked" do
    assert {:ok,
            %GetEnrollmentSummary{
              acknowledgment_filter: :acked,
              enrollment_filter: nil,
              event_state_filter: nil,
              event_type_filter: nil,
              priority_filter: nil,
              notification_class_filter: nil
            }} =
             GetEnrollmentSummary.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_enrollment_summary,
               parameters: [tagged: {0, <<1>>, 1}]
             })
  end

  test "decoding GetEnrollmentSummary with all fields" do
    assert {:ok,
            %GetEnrollmentSummary{
              acknowledgment_filter: :all,
              enrollment_filter:
                {9,
                 %Recipient{
                   type: :device,
                   address: nil,
                   device: %ObjectIdentifier{type: :device, instance: 17}
                 }},
              event_state_filter: :fault,
              event_type_filter: :out_of_range,
              priority_filter: {6, 10},
              notification_class_filter: 94
            }} =
             GetEnrollmentSummary.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_enrollment_summary,
               parameters: [
                 tagged: {0, <<0>>, 1},
                 constructed:
                   {1,
                    [
                      constructed: {0, {:tagged, {0, <<2, 0, 0, 17>>, 4}}, 0},
                      tagged: {1, "\t", 1}
                    ], 0},
                 tagged: {2, <<1>>, 1},
                 tagged: {3, <<5>>, 1},
                 constructed: {4, [tagged: {0, <<6>>, 1}, tagged: {1, "\n", 1}], 0},
                 tagged: {5, <<94>>, 1}
               ]
             })
  end

  test "decoding GetEnrollmentSummary invalid recipient process" do
    assert {:error, :invalid_recipient_process_param} =
             GetEnrollmentSummary.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_enrollment_summary,
               parameters: [
                 tagged: {0, <<0>>, 1},
                 constructed: {1, [], 0},
                 tagged: {2, <<1>>, 1},
                 tagged: {3, <<5>>, 1},
                 constructed: {4, [tagged: {0, <<6>>, 1}, tagged: {1, "\n", 1}], 0},
                 tagged: {5, <<94>>, 1}
               ]
             })
  end

  test "decoding GetEnrollmentSummary invalid recipient process identifier" do
    assert {:error, :invalid_process_identifier_value} =
             GetEnrollmentSummary.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_enrollment_summary,
               parameters: [
                 tagged: {0, <<0>>, 1},
                 constructed:
                   {1,
                    [
                      constructed: {0, {:tagged, {0, <<2, 0, 0, 17>>, 4}}, 0},
                      tagged: {1, <<255, 255, 255, 255, 255>>, 5}
                    ], 0},
                 tagged: {2, <<1>>, 1},
                 tagged: {3, <<5>>, 1},
                 constructed: {4, [tagged: {0, <<6>>, 1}, tagged: {1, "\n", 1}], 0},
                 tagged: {5, <<94>>, 1}
               ]
             })
  end

  test "decoding GetEnrollmentSummary invalid priority" do
    assert {:error, :invalid_priority_param} =
             GetEnrollmentSummary.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_enrollment_summary,
               parameters: [
                 tagged: {0, <<0>>, 1},
                 constructed:
                   {1,
                    [
                      constructed: {0, {:tagged, {0, <<2, 0, 0, 17>>, 4}}, 0},
                      tagged: {1, "\t", 1}
                    ], 0},
                 tagged: {2, <<1>>, 1},
                 tagged: {3, <<5>>, 1},
                 constructed: {4, [], 0},
                 tagged: {5, <<94>>, 1}
               ]
             })
  end

  test "decoding GetEnrollmentSummary invalid unknown tag encoding" do
    assert {:error, :unknown_tag_encoding} =
             GetEnrollmentSummary.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_enrollment_summary,
               parameters: [tagged: {0, <<>>, 0}]
             })
  end

  test "decoding GetEnrollmentSummary invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             GetEnrollmentSummary.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_enrollment_summary,
               parameters: []
             })
  end

  test "decoding GetEnrollmentSummary invalid APDU" do
    assert {:error, :invalid_request} =
             GetEnrollmentSummary.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :get_event_information,
               parameters: []
             })
  end

  test "encoding GetEnrollmentSummary" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :get_enrollment_summary,
              parameters: [tagged: {0, <<2>>, 1}]
            }} =
             GetEnrollmentSummary.to_apdu(
               %GetEnrollmentSummary{
                 acknowledgment_filter: :not_acked,
                 enrollment_filter: nil,
                 event_state_filter: nil,
                 event_type_filter: nil,
                 priority_filter: nil,
                 notification_class_filter: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding GetEnrollmentSummary with acked" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :get_enrollment_summary,
              parameters: [tagged: {0, <<1>>, 1}]
            }} =
             GetEnrollmentSummary.to_apdu(
               %GetEnrollmentSummary{
                 acknowledgment_filter: :acked,
                 enrollment_filter: nil,
                 event_state_filter: nil,
                 event_type_filter: nil,
                 priority_filter: nil,
                 notification_class_filter: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding GetEnrollmentSummary with all fields" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :get_enrollment_summary,
              parameters: [
                tagged: {0, <<0>>, 1},
                constructed:
                  {1,
                   [
                     constructed: {0, {:tagged, {0, <<2, 0, 0, 17>>, 4}}, 0},
                     tagged: {1, "\t", 1}
                   ], 0},
                tagged: {2, <<1>>, 1},
                tagged: {3, <<5>>, 1},
                constructed: {4, [tagged: {0, <<6>>, 1}, tagged: {1, "\n", 1}], 0},
                tagged: {5, <<94>>, 1}
              ]
            }} =
             GetEnrollmentSummary.to_apdu(
               %GetEnrollmentSummary{
                 acknowledgment_filter: :all,
                 enrollment_filter:
                   {9,
                    %Recipient{
                      type: :device,
                      address: nil,
                      device: %ObjectIdentifier{type: :device, instance: 17}
                    }},
                 event_state_filter: :fault,
                 event_type_filter: :out_of_range,
                 priority_filter: {6, 10},
                 notification_class_filter: 94
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding GetEnrollmentSummary invalid recipient" do
    assert {:error, :invalid_enrollment_filter} =
             GetEnrollmentSummary.to_apdu(
               %GetEnrollmentSummary{
                 acknowledgment_filter: :all,
                 enrollment_filter:
                   {nil,
                    %Recipient{
                      type: :device,
                      address: nil,
                      device: %ObjectIdentifier{type: :device, instance: 17}
                    }},
                 event_state_filter: :fault,
                 event_type_filter: :out_of_range,
                 priority_filter: {6, 10},
                 notification_class_filter: 94
               },
               invoke_id: 1,
               max_segments: 4
             )

    assert {:error, :invalid_enrollment_filter} =
             GetEnrollmentSummary.to_apdu(
               %GetEnrollmentSummary{
                 acknowledgment_filter: :all,
                 enrollment_filter: {5, nil},
                 event_state_filter: :fault,
                 event_type_filter: :out_of_range,
                 priority_filter: {6, 10},
                 notification_class_filter: 94
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding GetEnrollmentSummary invalid recipient process identifier" do
    assert {:error, :invalid_process_identifier_value} =
             GetEnrollmentSummary.to_apdu(
               %GetEnrollmentSummary{
                 acknowledgment_filter: :all,
                 enrollment_filter:
                   {432_421_412_904_120_421,
                    %Recipient{
                      type: :device,
                      address: nil,
                      device: %ObjectIdentifier{type: :device, instance: 17}
                    }},
                 event_state_filter: :fault,
                 event_type_filter: :out_of_range,
                 priority_filter: {6, 10},
                 notification_class_filter: 94
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "protocol implementation get name" do
    assert :get_enrollment_summary ==
             ServicesProtocol.get_name(%GetEnrollmentSummary{
               acknowledgment_filter: :not_acked,
               enrollment_filter: nil,
               event_state_filter: nil,
               event_type_filter: nil,
               priority_filter: nil,
               notification_class_filter: nil
             })
  end

  test "protocol implementation is confirmed" do
    assert true ==
             ServicesProtocol.is_confirmed(%GetEnrollmentSummary{
               acknowledgment_filter: :not_acked,
               enrollment_filter: nil,
               event_state_filter: nil,
               event_type_filter: nil,
               priority_filter: nil,
               notification_class_filter: nil
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
              service: :get_enrollment_summary,
              parameters: [tagged: {0, <<2>>, 1}]
            }} =
             ServicesProtocol.to_apdu(
               %GetEnrollmentSummary{
                 acknowledgment_filter: :not_acked,
                 enrollment_filter: nil,
                 event_state_filter: nil,
                 event_type_filter: nil,
                 priority_filter: nil,
                 notification_class_filter: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end
end
