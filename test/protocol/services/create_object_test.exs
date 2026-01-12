defmodule BACnet.Test.Protocol.Services.CreateObjectTest do
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.PropertyValue
  alias BACnet.Protocol.Services.CreateObject
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest CreateObject

  test "get name" do
    assert :create_object == CreateObject.get_name()
  end

  test "is confirmed" do
    assert true == CreateObject.is_confirmed()
  end

  test "decoding CreateObject with object type" do
    assert {:ok,
            %CreateObject{
              object_specifier: :file,
              initial_values: [
                %PropertyValue{
                  property_identifier: :object_name,
                  property_array_index: nil,
                  property_value: %Encoding{
                    encoding: :primitive,
                    extras: [],
                    type: :character_string,
                    value: "Trend 1"
                  },
                  priority: nil
                },
                %PropertyValue{
                  property_identifier: :file_access_method,
                  property_array_index: nil,
                  property_value: %Encoding{
                    encoding: :primitive,
                    extras: [],
                    type: :enumerated,
                    value: 0
                  },
                  priority: nil
                }
              ]
            }} =
             CreateObject.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :create_object,
               parameters: [
                 constructed: {0, {:tagged, {0, "\n", 1}}, 0},
                 constructed:
                   {1,
                    [
                      tagged: {0, "M", 1},
                      constructed: {2, {:character_string, "Trend 1"}, 0},
                      tagged: {0, ")", 1},
                      constructed: {2, {:enumerated, 0}, 0}
                    ], 0}
               ]
             })
  end

  test "decoding CreateObject with object identifier" do
    assert {:ok,
            %CreateObject{
              object_specifier: %ObjectIdentifier{type: :analog_input, instance: 15},
              initial_values: []
            }} =
             CreateObject.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :create_object,
               parameters: [
                 constructed: {0, {:tagged, {1, <<0, 0, 0, 15>>, 4}}, 0},
                 constructed: {1, [], 0}
               ]
             })
  end

  test "decoding CreateObject without optional list of initial values" do
    assert {:ok,
            %CreateObject{
              object_specifier: :file,
              initial_values: []
            }} =
             CreateObject.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :create_object,
               parameters: [
                 constructed: {0, {:tagged, {0, "\n", 1}}, 0}
               ]
             })
  end

  test "decoding CreateObject with invalid object type" do
    assert {:error, {:unknown_object_type, 255}} =
             CreateObject.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :create_object,
               parameters: [
                 constructed: {0, {:tagged, {0, <<255>>, 1}}, 0}
               ]
             })
  end

  # test "decoding CreateObject with invalid inital values" do
  #   assert {:error, :invalid_request_parameters} =
  #            CreateObject.from_apdu(%ConfirmedServiceRequest{
  #              segmented_response_accepted: true,
  #              max_apdu: 1476,
  #              max_segments: 4,
  #              invoke_id: 1,
  #              sequence_number: nil,
  #              proposed_window_size: nil,
  #              service: :create_object,
  #              parameters: [
  #                constructed: {0, {:tagged, {0, "\n", 1}}, 0},
  #                constructed: {1, {:real, 0.0}, 0}
  #              ]
  #            })
  # end

  test "decoding CreateObject invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             CreateObject.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :create_object,
               parameters: [
                 constructed: {0, nil, 0}
               ]
             })
  end

  test "decoding CreateObject invalid APDU" do
    assert {:error, :invalid_request} =
             CreateObject.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :delete_object,
               parameters: []
             })
  end

  test "encoding CreateObject with object type" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :create_object,
              parameters: [
                constructed: {0, {:tagged, {0, "\n", 1}}, 0},
                constructed:
                  {1,
                   [
                     tagged: {0, "M", 1},
                     constructed: {2, {:character_string, "Trend 1"}, 0},
                     tagged: {0, ")", 1},
                     constructed: {2, {:enumerated, 0}, 0}
                   ], 0}
              ]
            }} =
             CreateObject.to_apdu(
               %CreateObject{
                 object_specifier: :file,
                 initial_values: [
                   %PropertyValue{
                     property_identifier: :object_name,
                     property_array_index: nil,
                     property_value: %Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :character_string,
                       value: "Trend 1"
                     },
                     priority: nil
                   },
                   %PropertyValue{
                     property_identifier: :file_access_method,
                     property_array_index: nil,
                     property_value: %Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :enumerated,
                       value: 0
                     },
                     priority: nil
                   }
                 ]
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding CreateObject with object identifier" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :create_object,
              parameters: [
                constructed: {0, {:tagged, {1, <<0, 0, 0, 15>>, 4}}, 0}
              ]
            }} =
             CreateObject.to_apdu(
               %CreateObject{
                 object_specifier: %ObjectIdentifier{type: :analog_input, instance: 15},
                 initial_values: []
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding CreateObject invalid object identifier" do
    assert {:error, :unknown_object_type} =
             CreateObject.to_apdu(
               %CreateObject{
                 object_specifier: %ObjectIdentifier{type: 5124, instance: 15},
                 initial_values: []
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "protocol implementation get name" do
    assert :create_object ==
             ServicesProtocol.get_name(%CreateObject{
               object_specifier: :file,
               initial_values: []
             })
  end

  test "protocol implementation is confirmed" do
    assert true ==
             ServicesProtocol.is_confirmed(%CreateObject{
               object_specifier: :file,
               initial_values: []
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
              service: :create_object,
              parameters: [
                constructed: {0, {:tagged, {0, "\n", 1}}, 0},
                constructed:
                  {1,
                   [
                     tagged: {0, "M", 1},
                     constructed: {2, {:character_string, "Trend 1"}, 0},
                     tagged: {0, ")", 1},
                     constructed: {2, {:enumerated, 0}, 0}
                   ], 0}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %CreateObject{
                 object_specifier: :file,
                 initial_values: [
                   %PropertyValue{
                     property_identifier: :object_name,
                     property_array_index: nil,
                     property_value: %Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :character_string,
                       value: "Trend 1"
                     },
                     priority: nil
                   },
                   %PropertyValue{
                     property_identifier: :file_access_method,
                     property_array_index: nil,
                     property_value: %Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :enumerated,
                       value: 0
                     },
                     priority: nil
                   }
                 ]
               },
               invoke_id: 1,
               max_segments: 4
             )
  end
end
