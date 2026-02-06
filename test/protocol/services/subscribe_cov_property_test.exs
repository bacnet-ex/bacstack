defmodule BACnet.Test.Protocol.Services.SubscribeCovPropertyTest do
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.PropertyRef
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol
  alias BACnet.Protocol.Services.SubscribeCovProperty

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest SubscribeCovProperty

  test "get name" do
    assert :subscribe_cov_property == SubscribeCovProperty.get_name()
  end

  test "is confirmed" do
    assert true == SubscribeCovProperty.is_confirmed()
  end

  test "decoding SubscribeCovProperty" do
    assert {:ok,
            %SubscribeCovProperty{
              process_identifier: 18,
              monitored_object: %ObjectIdentifier{
                type: :analog_input,
                instance: 10
              },
              issue_confirmed_notifications: true,
              lifetime: 60,
              monitored_property: %PropertyRef{
                property_identifier: :present_value,
                property_array_index: nil
              },
              cov_increment: 1.0
            }} =
             SubscribeCovProperty.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :subscribe_cov_property,
               parameters: [
                 tagged: {0, <<18>>, 1},
                 tagged: {1, <<0, 0, 0, 10>>, 4},
                 tagged: {2, <<1>>, 1},
                 tagged: {3, "<", 1},
                 constructed: {4, {:tagged, {0, "U", 1}}, 0},
                 tagged: {5, <<63, 128, 0, 0>>, 4}
               ]
             })
  end

  test "decoding SubscribeCovProperty with array index" do
    assert {:ok,
            %SubscribeCovProperty{
              process_identifier: 18,
              monitored_object: %ObjectIdentifier{
                type: :analog_input,
                instance: 10
              },
              issue_confirmed_notifications: true,
              lifetime: 60,
              monitored_property: %PropertyRef{
                property_identifier: :present_value,
                property_array_index: 97
              },
              cov_increment: 1.0
            }} =
             SubscribeCovProperty.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :subscribe_cov_property,
               parameters: [
                 tagged: {0, <<18>>, 1},
                 tagged: {1, <<0, 0, 0, 10>>, 4},
                 tagged: {2, <<1>>, 1},
                 tagged: {3, "<", 1},
                 constructed: {4, [{:tagged, {0, "U", 1}}, {:tagged, {1, "a", 1}}], 0},
                 tagged: {5, <<63, 128, 0, 0>>, 4}
               ]
             })
  end

  test "decoding SubscribeCovProperty without COV" do
    assert {:ok,
            %SubscribeCovProperty{
              process_identifier: 18,
              monitored_object: %ObjectIdentifier{
                type: :analog_input,
                instance: 10
              },
              issue_confirmed_notifications: false,
              lifetime: 60,
              monitored_property: %PropertyRef{
                property_identifier: :present_value,
                property_array_index: nil
              },
              cov_increment: nil
            }} =
             SubscribeCovProperty.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :subscribe_cov_property,
               parameters: [
                 tagged: {0, <<18>>, 1},
                 tagged: {1, <<0, 0, 0, 10>>, 4},
                 tagged: {2, <<0>>, 1},
                 tagged: {3, "<", 1},
                 constructed: {4, {:tagged, {0, "U", 1}}, 0}
               ]
             })
  end

  test "decoding SubscribeCovProperty cancellation" do
    assert {:ok,
            %SubscribeCovProperty{
              process_identifier: 18,
              monitored_object: %ObjectIdentifier{
                type: :analog_input,
                instance: 10
              },
              issue_confirmed_notifications: nil,
              lifetime: nil,
              monitored_property: %PropertyRef{
                property_identifier: :present_value,
                property_array_index: nil
              },
              cov_increment: nil
            }} =
             SubscribeCovProperty.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :subscribe_cov_property,
               parameters: [
                 tagged: {0, <<18>>, 1},
                 tagged: {1, <<0, 0, 0, 10>>, 4},
                 constructed: {4, {:tagged, {0, "U", 1}}, 0}
               ]
             })
  end

  test "decoding SubscribeCovProperty invalid unknown encoding" do
    assert {:error, :unknown_tag_encoding} =
             SubscribeCovProperty.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :subscribe_cov_property,
               parameters: [
                 tagged: {0, <<>>, 0},
                 tagged: {1, <<0, 0, 0, 10>>, 4}
               ]
             })
  end

  test "decoding SubscribeCovProperty invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             SubscribeCovProperty.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :subscribe_cov_property,
               parameters: [
                 tagged: {0, <<18>>, 1},
                 tagged: {1, <<0, 0, 0, 10>>, 4}
               ]
             })
  end

  test "decoding SubscribeCovProperty invalid process identifier" do
    assert {:error, :invalid_process_identifier_value} =
             SubscribeCovProperty.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :subscribe_cov_property,
               parameters: [
                 tagged: {0, <<255, 255, 255, 255, 255>>, 5},
                 tagged: {1, <<0, 0, 0, 10>>, 4},
                 tagged: {2, <<1>>, 1},
                 tagged: {3, "<", 1},
                 constructed: {4, {:tagged, {0, "U", 1}}, 0},
                 tagged: {5, <<63, 128, 0, 0>>, 4}
               ]
             })
  end

  test "decoding SubscribeCovProperty invalid APDU" do
    assert {:error, :invalid_request} =
             SubscribeCovProperty.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :subscribe_cov,
               parameters: []
             })
  end

  test "encoding SubscribeCovProperty" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :subscribe_cov_property,
              parameters: [
                tagged: {0, <<18>>, 1},
                tagged: {1, <<0, 0, 0, 10>>, 4},
                tagged: {2, <<1>>, 1},
                tagged: {3, "<", 1},
                constructed: {4, [{:tagged, {0, "U", 1}}], 0},
                tagged: {5, <<63, 128, 0, 0>>, 4}
              ]
            }} =
             SubscribeCovProperty.to_apdu(
               %SubscribeCovProperty{
                 process_identifier: 18,
                 monitored_object: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 10
                 },
                 issue_confirmed_notifications: true,
                 lifetime: 60,
                 monitored_property: %PropertyRef{
                   property_identifier: :present_value,
                   property_array_index: nil
                 },
                 cov_increment: 1.0
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding SubscribeCovProperty with array index" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :subscribe_cov_property,
              parameters: [
                tagged: {0, <<18>>, 1},
                tagged: {1, <<0, 0, 0, 10>>, 4},
                tagged: {2, <<1>>, 1},
                tagged: {3, "<", 1},
                constructed: {4, [{:tagged, {0, "U", 1}}, {:tagged, {1, "a", 1}}], 0},
                tagged: {5, <<63, 128, 0, 0>>, 4}
              ]
            }} =
             SubscribeCovProperty.to_apdu(
               %SubscribeCovProperty{
                 process_identifier: 18,
                 monitored_object: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 10
                 },
                 issue_confirmed_notifications: true,
                 lifetime: 60,
                 monitored_property: %PropertyRef{
                   property_identifier: :present_value,
                   property_array_index: 97
                 },
                 cov_increment: 1.0
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding SubscribeCovProperty cancellation" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :subscribe_cov_property,
              parameters: [
                tagged: {0, <<18>>, 1},
                tagged: {1, <<0, 0, 0, 10>>, 4},
                constructed: {4, [{:tagged, {0, "U", 1}}], 0}
              ]
            }} =
             SubscribeCovProperty.to_apdu(
               %SubscribeCovProperty{
                 process_identifier: 18,
                 monitored_object: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 10
                 },
                 issue_confirmed_notifications: nil,
                 lifetime: nil,
                 monitored_property: %PropertyRef{
                   property_identifier: :present_value,
                   property_array_index: nil
                 },
                 cov_increment: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding SubscribeCovProperty invalid property" do
    assert {:error, :invalid_value} =
             SubscribeCovProperty.to_apdu(
               %SubscribeCovProperty{
                 process_identifier: 18,
                 monitored_object: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 10
                 },
                 issue_confirmed_notifications: true,
                 lifetime: 60,
                 monitored_property: %PropertyRef{
                   property_identifier: :present_value,
                   property_array_index: :hello
                 },
                 cov_increment: 1.0
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding SubscribeCovProperty invalid process identifier" do
    assert {:error, :invalid_process_identifier_value} =
             SubscribeCovProperty.to_apdu(
               %SubscribeCovProperty{
                 process_identifier: 18_512_124_421_234_053,
                 monitored_object: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 10
                 },
                 issue_confirmed_notifications: true,
                 lifetime: 60,
                 monitored_property: %PropertyRef{
                   property_identifier: :present_value,
                   property_array_index: nil
                 },
                 cov_increment: 1.0
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "protocol implementation get name" do
    assert :subscribe_cov_property ==
             ServicesProtocol.get_name(%SubscribeCovProperty{
               process_identifier: 18,
               monitored_object: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 10
               },
               issue_confirmed_notifications: nil,
               lifetime: nil,
               monitored_property: %PropertyRef{
                 property_identifier: :present_value,
                 property_array_index: nil
               },
               cov_increment: nil
             })
  end

  test "protocol implementation is confirmed" do
    assert true ==
             ServicesProtocol.is_confirmed(%SubscribeCovProperty{
               process_identifier: 18,
               monitored_object: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 10
               },
               issue_confirmed_notifications: nil,
               lifetime: nil,
               monitored_property: %PropertyRef{
                 property_identifier: :present_value,
                 property_array_index: nil
               },
               cov_increment: nil
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
              service: :subscribe_cov_property,
              parameters: [
                tagged: {0, <<18>>, 1},
                tagged: {1, <<0, 0, 0, 10>>, 4},
                constructed: {4, [{:tagged, {0, "U", 1}}], 0}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %SubscribeCovProperty{
                 process_identifier: 18,
                 monitored_object: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 10
                 },
                 issue_confirmed_notifications: nil,
                 lifetime: nil,
                 monitored_property: %PropertyRef{
                   property_identifier: :present_value,
                   property_array_index: nil
                 },
                 cov_increment: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end
end
