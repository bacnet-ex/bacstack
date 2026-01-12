defmodule BACnet.Test.Protocol.Services.SubscribeCovTest do
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol
  alias BACnet.Protocol.Services.SubscribeCov

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest SubscribeCov

  test "get name" do
    assert :subscribe_cov == SubscribeCov.get_name()
  end

  test "is confirmed" do
    assert true == SubscribeCov.is_confirmed()
  end

  test "decoding SubscribeCov" do
    assert {:ok,
            %SubscribeCov{
              process_identifier: 18,
              monitored_object: %ObjectIdentifier{
                type: :analog_input,
                instance: 10
              },
              issue_confirmed_notifications: true,
              lifetime: 0
            }} =
             SubscribeCov.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :subscribe_cov,
               parameters: [
                 tagged: {0, <<18>>, 1},
                 tagged: {1, <<0, 0, 0, 10>>, 4},
                 tagged: {2, <<1>>, 1},
                 tagged: {3, <<0>>, 1}
               ]
             })
  end

  test "decoding SubscribeCov without lifetime" do
    assert {:ok,
            %SubscribeCov{
              process_identifier: 18,
              monitored_object: %ObjectIdentifier{
                type: :analog_input,
                instance: 10
              },
              issue_confirmed_notifications: false,
              lifetime: nil
            }} =
             SubscribeCov.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :subscribe_cov,
               parameters: [
                 tagged: {0, <<18>>, 1},
                 tagged: {1, <<0, 0, 0, 10>>, 4},
                 tagged: {2, <<0>>, 1}
               ]
             })
  end

  test "decoding SubscribeCov cancellation" do
    assert {:ok,
            %SubscribeCov{
              process_identifier: 18,
              monitored_object: %ObjectIdentifier{
                type: :analog_input,
                instance: 10
              },
              issue_confirmed_notifications: nil,
              lifetime: nil
            }} =
             SubscribeCov.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :subscribe_cov,
               parameters: [
                 tagged: {0, <<18>>, 1},
                 tagged: {1, <<0, 0, 0, 10>>, 4}
               ]
             })
  end

  test "decoding SubscribeCov invalid encoding" do
    assert {:error, :unknown_tag_encoding} =
             SubscribeCov.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :subscribe_cov,
               parameters: [
                 tagged: {0, <<>>, 0}
               ]
             })
  end

  test "decoding SubscribeCov invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             SubscribeCov.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :subscribe_cov,
               parameters: [
                 tagged: {0, <<18>>, 1}
               ]
             })
  end

  test "decoding SubscribeCov invalid process identifier" do
    assert {:error, :invalid_process_identifier_value} =
             SubscribeCov.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :subscribe_cov,
               parameters: [
                 tagged: {0, <<255, 255, 255, 255, 255>>, 5},
                 tagged: {1, <<0, 0, 0, 10>>, 4},
                 tagged: {2, <<1>>, 1},
                 tagged: {3, <<0>>, 1}
               ]
             })
  end

  test "decoding SubscribeCov invalid APDU" do
    assert {:error, :invalid_request} =
             SubscribeCov.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :subscribe_cov_property,
               parameters: []
             })
  end

  test "encoding SubscribeCov" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :subscribe_cov,
              parameters: [
                tagged: {0, <<18>>, 1},
                tagged: {1, <<0, 0, 0, 10>>, 4},
                tagged: {2, <<1>>, 1},
                tagged: {3, <<0>>, 1}
              ]
            }} =
             SubscribeCov.to_apdu(
               %SubscribeCov{
                 process_identifier: 18,
                 monitored_object: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 10
                 },
                 issue_confirmed_notifications: true,
                 lifetime: 0
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding SubscribeCov cancellation" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :subscribe_cov,
              parameters: [
                tagged: {0, <<18>>, 1},
                tagged: {1, <<0, 0, 0, 10>>, 4}
              ]
            }} =
             SubscribeCov.to_apdu(
               %SubscribeCov{
                 process_identifier: 18,
                 monitored_object: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 10
                 },
                 issue_confirmed_notifications: nil,
                 lifetime: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding SubscribeCov invalid process identifier" do
    assert {:error, :invalid_process_identifier_value} =
             SubscribeCov.to_apdu(
               %SubscribeCov{
                 process_identifier: 18_124_431_242_149_042,
                 monitored_object: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 10
                 },
                 issue_confirmed_notifications: true,
                 lifetime: 0
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "protocol implementation get name" do
    assert :subscribe_cov ==
             ServicesProtocol.get_name(%SubscribeCov{
               process_identifier: 18,
               monitored_object: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 10
               },
               issue_confirmed_notifications: nil,
               lifetime: nil
             })
  end

  test "protocol implementation is confirmed" do
    assert true ==
             ServicesProtocol.is_confirmed(%SubscribeCov{
               process_identifier: 18,
               monitored_object: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 10
               },
               issue_confirmed_notifications: nil,
               lifetime: nil
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
              service: :subscribe_cov,
              parameters: [
                tagged: {0, <<18>>, 1},
                tagged: {1, <<0, 0, 0, 10>>, 4}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %SubscribeCov{
                 process_identifier: 18,
                 monitored_object: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 10
                 },
                 issue_confirmed_notifications: nil,
                 lifetime: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end
end
