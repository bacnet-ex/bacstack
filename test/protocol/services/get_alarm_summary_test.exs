defmodule BACnet.Test.Protocol.Services.GetAlarmSummaryTest do
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.Services.GetAlarmSummary
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest GetAlarmSummary

  test "get name" do
    assert :get_alarm_summary == GetAlarmSummary.get_name()
  end

  test "is confirmed" do
    assert true == GetAlarmSummary.is_confirmed()
  end

  test "decoding GetAlarmSummary" do
    assert {:ok, %GetAlarmSummary{}} ==
             GetAlarmSummary.from_apdu(%ConfirmedServiceRequest{
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

  test "decoding GetAlarmSummary invalid APDU" do
    assert {:error, :invalid_request} =
             GetAlarmSummary.from_apdu(%ConfirmedServiceRequest{
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

  test "encoding GetAlarmSummary" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :get_alarm_summary,
              parameters: []
            }} =
             GetAlarmSummary.to_apdu(
               %GetAlarmSummary{},
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "protocol implementation get name" do
    assert :get_alarm_summary == ServicesProtocol.get_name(%GetAlarmSummary{})
  end

  test "protocol implementation is confirmed" do
    assert true == ServicesProtocol.is_confirmed(%GetAlarmSummary{})
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
              service: :get_alarm_summary,
              parameters: []
            }} =
             ServicesProtocol.to_apdu(
               %GetAlarmSummary{},
               invoke_id: 1,
               max_segments: 4
             )
  end
end
