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
    assert true == CreateObject.confirmed?()
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

  test "decoding CreateObject with the first proprietary object type" do
    assert {:ok, %CreateObject{object_specifier: 128, initial_values: []}} =
             CreateObject.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :create_object,
               parameters: [
                 constructed: {0, {:tagged, {0, <<0x80>>, 1}}, 0}
               ]
             })
  end

  test "decoding CreateObject with the last proprietary object type" do
    assert {:ok, %CreateObject{object_specifier: 1023, initial_values: []}} =
             CreateObject.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :create_object,
               parameters: [
                 constructed: {0, {:tagged, {0, <<0x03, 0xFF>>, 2}}, 0}
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

  test "decoding CreateObject rejects ALL in the list of initial values" do
    assert {:error, :invalid_property_identifier} =
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
                   {1, [tagged: {0, <<0x08>>, 1}, constructed: {2, {:enumerated, 0}, 0}], 0}
               ]
             })
  end

  test "decoding CreateObject rejects REQUIRED in the list of initial values" do
    assert {:error, :invalid_property_identifier} =
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
                   {1, [tagged: {0, <<0x69>>, 1}, constructed: {2, {:enumerated, 0}, 0}], 0}
               ]
             })
  end

  test "decoding CreateObject rejects OPTIONAL in the list of initial values" do
    assert {:error, :invalid_property_identifier} =
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
                   {1, [tagged: {0, <<0x50>>, 1}, constructed: {2, {:enumerated, 0}, 0}], 0}
               ]
             })
  end

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

  test "encoding CreateObject with the first proprietary object type" do
    assert {:ok,
            %ConfirmedServiceRequest{
              service: :create_object,
              parameters: [constructed: {0, {:tagged, {0, <<0x80>>, 1}}, 0}]
            }} =
             CreateObject.to_apdu(%CreateObject{object_specifier: 128, initial_values: []}, [])
  end

  test "encoding CreateObject with the last proprietary object type" do
    assert {:ok,
            %ConfirmedServiceRequest{
              service: :create_object,
              parameters: [constructed: {0, {:tagged, {0, <<0x03, 0xFF>>, 2}}, 0}]
            }} =
             CreateObject.to_apdu(%CreateObject{object_specifier: 1023, initial_values: []}, [])
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
                 object_specifier: %ObjectIdentifier{type: -5124, instance: 15},
                 initial_values: []
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding CreateObject rejects ALL in the list of initial values" do
    assert {:error, :invalid_property_identifier} =
             CreateObject.to_apdu(
               %CreateObject{
                 object_specifier: :file,
                 initial_values: [
                   %PropertyValue{
                     property_identifier: :all,
                     property_array_index: nil,
                     property_value: Encoding.create!({:enumerated, 0}),
                     priority: nil
                   }
                 ]
               },
               []
             )
  end

  test "encoding CreateObject rejects numeric ALL in the list of initial values" do
    assert {:error, :invalid_property_identifier} =
             CreateObject.to_apdu(
               %CreateObject{
                 object_specifier: :file,
                 initial_values: [
                   %PropertyValue{
                     property_identifier: 0x08,
                     property_array_index: nil,
                     property_value: Encoding.create!({:enumerated, 0}),
                     priority: nil
                   }
                 ]
               },
               []
             )
  end

  test "encoding CreateObject rejects REQUIRED in the list of initial values" do
    assert {:error, :invalid_property_identifier} =
             CreateObject.to_apdu(
               %CreateObject{
                 object_specifier: :file,
                 initial_values: [
                   %PropertyValue{
                     property_identifier: :required,
                     property_array_index: nil,
                     property_value: Encoding.create!({:enumerated, 0}),
                     priority: nil
                   }
                 ]
               },
               []
             )
  end

  test "encoding CreateObject rejects numeric REQUIRED in the list of initial values" do
    assert {:error, :invalid_property_identifier} =
             CreateObject.to_apdu(
               %CreateObject{
                 object_specifier: :file,
                 initial_values: [
                   %PropertyValue{
                     property_identifier: 0x69,
                     property_array_index: nil,
                     property_value: Encoding.create!({:enumerated, 0}),
                     priority: nil
                   }
                 ]
               },
               []
             )
  end

  test "encoding CreateObject rejects OPTIONAL in the list of initial values" do
    assert {:error, :invalid_property_identifier} =
             CreateObject.to_apdu(
               %CreateObject{
                 object_specifier: :file,
                 initial_values: [
                   %PropertyValue{
                     property_identifier: :optional,
                     property_array_index: nil,
                     property_value: Encoding.create!({:enumerated, 0}),
                     priority: nil
                   }
                 ]
               },
               []
             )
  end

  test "encoding CreateObject rejects numeric OPTIONAL in the list of initial values" do
    assert {:error, :invalid_property_identifier} =
             CreateObject.to_apdu(
               %CreateObject{
                 object_specifier: :file,
                 initial_values: [
                   %PropertyValue{
                     property_identifier: 0x50,
                     property_array_index: nil,
                     property_value: Encoding.create!({:enumerated, 0}),
                     priority: nil
                   }
                 ]
               },
               []
             )
  end

  test "encoding CreateObject preserves segmented_response_accepted=false" do
    service = %CreateObject{
      object_specifier: %ObjectIdentifier{type: :analog_input, instance: 1},
      initial_values: []
    }

    assert {:ok, %ConfirmedServiceRequest{segmented_response_accepted: false} = apdu} =
             CreateObject.to_apdu(service, segmented_response_accepted: false)

    assert {:ok, ^apdu} =
             ServicesProtocol.to_apdu(service, segmented_response_accepted: false)
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
             ServicesProtocol.confirmed?(%CreateObject{
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
