defmodule BACnet.Test.Protocol.Services.ReadPropertyMultipleTest do
  alias BACnet.Protocol.AccessSpecification
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol
  alias BACnet.Protocol.Services.ReadPropertyMultiple

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest ReadPropertyMultiple

  test "get name" do
    assert :read_property_multiple == ReadPropertyMultiple.get_name()
  end

  test "is confirmed" do
    assert true == ReadPropertyMultiple.is_confirmed()
  end

  test "decoding ReadPropertyMultiple" do
    assert {:ok,
            %ReadPropertyMultiple{
              list: [
                %AccessSpecification{
                  object_identifier: %ObjectIdentifier{
                    type: :analog_input,
                    instance: 16
                  },
                  properties: [
                    %AccessSpecification.Property{
                      property_identifier: :present_value,
                      property_array_index: nil,
                      property_value: nil
                    },
                    %AccessSpecification.Property{
                      property_identifier: :reliability,
                      property_array_index: nil,
                      property_value: nil
                    }
                  ]
                }
              ]
            }} =
             ReadPropertyMultiple.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_property_multiple,
               parameters: [
                 tagged: {0, <<0, 0, 0, 16>>, 4},
                 constructed: {1, [tagged: {0, "U", 1}, tagged: {0, "g", 1}], 0}
               ]
             })
  end

  test "decoding ReadPropertyMultiple multi" do
    assert {:ok,
            %ReadPropertyMultiple{
              list: [
                %AccessSpecification{
                  object_identifier: %ObjectIdentifier{
                    type: :analog_input,
                    instance: 16
                  },
                  properties: [
                    %AccessSpecification.Property{
                      property_identifier: :present_value,
                      property_array_index: nil,
                      property_value: nil
                    },
                    %AccessSpecification.Property{
                      property_identifier: :reliability,
                      property_array_index: nil,
                      property_value: nil
                    }
                  ]
                },
                %AccessSpecification{
                  object_identifier: %ObjectIdentifier{
                    type: :analog_input,
                    instance: 16
                  },
                  properties: [
                    %AccessSpecification.Property{
                      property_identifier: :present_value,
                      property_array_index: nil,
                      property_value: nil
                    },
                    %AccessSpecification.Property{
                      property_identifier: :reliability,
                      property_array_index: nil,
                      property_value: nil
                    }
                  ]
                }
              ]
            }} =
             ReadPropertyMultiple.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_property_multiple,
               parameters: [
                 tagged: {0, <<0, 0, 0, 16>>, 4},
                 constructed: {1, [tagged: {0, "U", 1}, tagged: {0, "g", 1}], 0},
                 tagged: {0, <<0, 0, 0, 16>>, 4},
                 constructed: {1, [tagged: {0, "U", 1}, tagged: {0, "g", 1}], 0}
               ]
             })
  end

  test "decoding ReadPropertyMultiple invalid unknown tag encoding" do
    assert {:error, :unknown_tag_encoding} =
             ReadPropertyMultiple.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_property_multiple,
               parameters: [
                 tagged: {0, <<>>, 0}
               ]
             })
  end

  test "decoding ReadPropertyMultiple invalid missing tags" do
    assert {:error, :invalid_tags} =
             ReadPropertyMultiple.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_property_multiple,
               parameters: [
                 tagged: {0, <<0, 0, 0, 16>>, 4}
               ]
             })
  end

  test "decoding ReadPropertyMultiple invalid APDU" do
    assert {:error, :invalid_request} =
             ReadPropertyMultiple.from_apdu(%ConfirmedServiceRequest{
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

  test "encoding ReadPropertyMultiple" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :read_property_multiple,
              parameters: [
                tagged: {0, <<0, 0, 0, 16>>, 4},
                constructed:
                  {1,
                   [
                     tagged: {0, "W", 1},
                     tagged: {1, <<15>>, 1},
                     tagged: {0, "g", 1}
                   ], 0}
              ]
            }} =
             ReadPropertyMultiple.to_apdu(
               %ReadPropertyMultiple{
                 list: [
                   %AccessSpecification{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_input,
                       instance: 16
                     },
                     properties: [
                       %AccessSpecification.Property{
                         property_identifier: :priority_array,
                         property_array_index: 15,
                         property_value: nil
                       },
                       %AccessSpecification.Property{
                         property_identifier: :reliability,
                         property_array_index: nil,
                         property_value: nil
                       }
                     ]
                   }
                 ]
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding ReadPropertyMultiple multi" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :read_property_multiple,
              parameters: [
                tagged: {0, <<0, 0, 0, 16>>, 4},
                constructed:
                  {1,
                   [
                     tagged: {0, "W", 1},
                     tagged: {1, <<15>>, 1},
                     tagged: {0, "g", 1}
                   ], 0},
                tagged: {0, <<0, 0, 0, 16>>, 4},
                constructed:
                  {1,
                   [
                     tagged: {0, "W", 1},
                     tagged: {1, <<15>>, 1},
                     tagged: {0, "g", 1}
                   ], 0}
              ]
            }} =
             ReadPropertyMultiple.to_apdu(
               %ReadPropertyMultiple{
                 list: [
                   %AccessSpecification{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_input,
                       instance: 16
                     },
                     properties: [
                       %AccessSpecification.Property{
                         property_identifier: :priority_array,
                         property_array_index: 15,
                         property_value: nil
                       },
                       %AccessSpecification.Property{
                         property_identifier: :reliability,
                         property_array_index: nil,
                         property_value: nil
                       }
                     ]
                   },
                   %AccessSpecification{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_input,
                       instance: 16
                     },
                     properties: [
                       %AccessSpecification.Property{
                         property_identifier: :priority_array,
                         property_array_index: 15,
                         property_value: nil
                       },
                       %AccessSpecification.Property{
                         property_identifier: :reliability,
                         property_array_index: nil,
                         property_value: nil
                       }
                     ]
                   }
                 ]
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding ReadPropertyMultiple invalid specification" do
    assert {:error, :invalid_value} =
             ReadPropertyMultiple.to_apdu(
               %ReadPropertyMultiple{
                 list: [
                   %AccessSpecification{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_input,
                       instance: 16
                     },
                     properties: [
                       %AccessSpecification.Property{
                         property_identifier: :priority_array,
                         property_array_index: :hello,
                         property_value: nil
                       }
                     ]
                   }
                 ]
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "protocol implementation get name" do
    assert :read_property_multiple ==
             ServicesProtocol.get_name(%ReadPropertyMultiple{
               list: [
                 %AccessSpecification{
                   object_identifier: %ObjectIdentifier{
                     type: :analog_input,
                     instance: 16
                   },
                   properties: []
                 }
               ]
             })
  end

  test "protocol implementation is confirmed" do
    assert true ==
             ServicesProtocol.is_confirmed(%ReadPropertyMultiple{
               list: [
                 %AccessSpecification{
                   object_identifier: %ObjectIdentifier{
                     type: :analog_input,
                     instance: 16
                   },
                   properties: []
                 }
               ]
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
              service: :read_property_multiple,
              parameters: [
                tagged: {0, <<0, 0, 0, 16>>, 4},
                constructed:
                  {1,
                   [
                     tagged: {0, "W", 1},
                     tagged: {1, <<15>>, 1},
                     tagged: {0, "g", 1}
                   ], 0}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %ReadPropertyMultiple{
                 list: [
                   %AccessSpecification{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_input,
                       instance: 16
                     },
                     properties: [
                       %AccessSpecification.Property{
                         property_identifier: :priority_array,
                         property_array_index: 15,
                         property_value: nil
                       },
                       %AccessSpecification.Property{
                         property_identifier: :reliability,
                         property_array_index: nil,
                         property_value: nil
                       }
                     ]
                   }
                 ]
               },
               invoke_id: 1,
               max_segments: 4
             )
  end
end
