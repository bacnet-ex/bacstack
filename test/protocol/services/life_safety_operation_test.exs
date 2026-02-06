defmodule BACnet.Test.Protocol.Services.LifeSafetyOperationTest do
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.LifeSafetyOperation
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest LifeSafetyOperation

  test "get name" do
    assert :life_safety_operation == LifeSafetyOperation.get_name()
  end

  test "is confirmed" do
    assert true == LifeSafetyOperation.is_confirmed()
  end

  test "decoding LifeSafetyOperation" do
    assert {:ok,
            %LifeSafetyOperation{
              requesting_process_identifier: 18,
              requesting_source: "MDL",
              request: :reset,
              object_identifier: %ObjectIdentifier{
                type: :life_safety_point,
                instance: 1
              }
            }} =
             LifeSafetyOperation.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :life_safety_operation,
               parameters: [
                 tagged: {0, <<18>>, 1},
                 tagged: {1, <<0, 77, 68, 76>>, 4},
                 tagged: {2, <<4>>, 1},
                 tagged: {3, <<5, 64, 0, 1>>, 4}
               ]
             })
  end

  test "decoding LifeSafetyOperation without optional" do
    assert {:ok,
            %LifeSafetyOperation{
              requesting_process_identifier: 18,
              requesting_source: "MDL",
              request: :reset,
              object_identifier: nil
            }} =
             LifeSafetyOperation.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :life_safety_operation,
               parameters: [
                 tagged: {0, <<18>>, 1},
                 tagged: {1, <<0, 77, 68, 76>>, 4},
                 tagged: {2, <<4>>, 1}
               ]
             })
  end

  test "decoding LifeSafetyOperation invalid unknown tag encoding" do
    assert {:error, :unknown_tag_encoding} =
             LifeSafetyOperation.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :life_safety_operation,
               parameters: [
                 tagged: {0, <<>>, 0},
                 tagged: {1, <<0, 77, 68, 76>>, 4}
               ]
             })
  end

  test "decoding LifeSafetyOperation invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             LifeSafetyOperation.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :life_safety_operation,
               parameters: [
                 tagged: {0, <<18>>, 1},
                 tagged: {1, <<0, 77, 68, 76>>, 4}
               ]
             })
  end

  test "decoding LifeSafetyOperation invalid" do
    assert {:error, :invalid_request} =
             LifeSafetyOperation.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_property,
               parameters: []
             })
  end

  test "decoding LifeSafetyOperation unknown operation" do
    assert {:error, {:unknown_life_safety_operation, 255}} =
             LifeSafetyOperation.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :life_safety_operation,
               parameters: [
                 tagged: {0, <<18>>, 1},
                 tagged: {1, <<0, 77, 68, 76>>, 4},
                 tagged: {2, <<255>>, 1},
                 tagged: {3, <<5, 64, 0, 1>>, 4}
               ]
             })
  end

  test "decoding LifeSafetyOperation invalid process identifier" do
    assert {:error, :invalid_process_identifier_value} =
             LifeSafetyOperation.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :life_safety_operation,
               parameters: [
                 tagged: {0, <<255, 255, 255, 255, 255>>, 5},
                 tagged: {1, <<0, 77, 68, 76>>, 4},
                 tagged: {2, <<4>>, 1},
                 tagged: {3, <<5, 64, 0, 1>>, 4}
               ]
             })
  end

  test "encoding LifeSafetyOperation" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :life_safety_operation,
              parameters: [
                tagged: {0, <<18>>, 1},
                tagged: {1, <<0, 77, 68, 76>>, 4},
                tagged: {2, <<4>>, 1},
                tagged: {3, <<5, 64, 0, 1>>, 4}
              ]
            }} =
             LifeSafetyOperation.to_apdu(
               %LifeSafetyOperation{
                 requesting_process_identifier: 18,
                 requesting_source: "MDL",
                 request: :reset,
                 object_identifier: %ObjectIdentifier{
                   type: :life_safety_point,
                   instance: 1
                 }
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding LifeSafetyOperation without optional" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :life_safety_operation,
              parameters: [
                tagged: {0, <<18>>, 1},
                tagged: {1, <<0, 77, 68, 76>>, 4},
                tagged: {2, <<4>>, 1}
              ]
            }} =
             LifeSafetyOperation.to_apdu(
               %LifeSafetyOperation{
                 requesting_process_identifier: 18,
                 requesting_source: "MDL",
                 request: :reset,
                 object_identifier: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding LifeSafetyOperation unknown life safety operation" do
    assert {:error, {:unknown_life_safety_operation, :hello_there}} =
             LifeSafetyOperation.to_apdu(
               %LifeSafetyOperation{
                 requesting_process_identifier: 18,
                 requesting_source: "MDL",
                 request: :hello_there,
                 object_identifier: %ObjectIdentifier{
                   type: :life_safety_point,
                   instance: 1
                 }
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding LifeSafetyOperation invalid process identifier" do
    assert {:error, :invalid_process_identifier_value} =
             LifeSafetyOperation.to_apdu(
               %LifeSafetyOperation{
                 requesting_process_identifier: 18_352_129_053_912_524,
                 requesting_source: "MDL",
                 request: :reset,
                 object_identifier: %ObjectIdentifier{
                   type: :life_safety_point,
                   instance: 1
                 }
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "protocol implementation get name" do
    assert :life_safety_operation ==
             ServicesProtocol.get_name(%LifeSafetyOperation{
               requesting_process_identifier: 18,
               requesting_source: "MDL",
               request: :reset,
               object_identifier: nil
             })
  end

  test "protocol implementation is confirmed" do
    assert true ==
             ServicesProtocol.is_confirmed(%LifeSafetyOperation{
               requesting_process_identifier: 18,
               requesting_source: "MDL",
               request: :reset,
               object_identifier: nil
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
              service: :life_safety_operation,
              parameters: [
                tagged: {0, <<18>>, 1},
                tagged: {1, <<0, 77, 68, 76>>, 4},
                tagged: {2, <<4>>, 1}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %LifeSafetyOperation{
                 requesting_process_identifier: 18,
                 requesting_source: "MDL",
                 request: :reset,
                 object_identifier: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end
end
