defmodule BACnet.Test.Protocol.Services.WritePropertyMultipleTest do
  alias BACnet.Protocol.AccessSpecification
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol
  alias BACnet.Protocol.Services.WritePropertyMultiple

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest WritePropertyMultiple

  test "get name" do
    assert :write_property_multiple == WritePropertyMultiple.get_name()
  end

  test "is confirmed" do
    assert true == WritePropertyMultiple.is_confirmed()
  end

  test "decoding WritePropertyMultiple" do
    assert {:ok,
            %WritePropertyMultiple{
              list: [
                %AccessSpecification{
                  object_identifier: %ObjectIdentifier{
                    type: :analog_value,
                    instance: 5
                  },
                  properties: [
                    %AccessSpecification.Property{
                      property_identifier: :present_value,
                      property_array_index: nil,
                      property_value: %Encoding{
                        encoding: :primitive,
                        extras: [],
                        type: :real,
                        value: 67.0
                      }
                    }
                  ]
                },
                %AccessSpecification{
                  object_identifier: %ObjectIdentifier{
                    type: :analog_value,
                    instance: 6
                  },
                  properties: [
                    %AccessSpecification.Property{
                      property_identifier: :present_value,
                      property_array_index: nil,
                      property_value: %Encoding{
                        encoding: :primitive,
                        extras: [],
                        type: :real,
                        value: 67.0
                      }
                    }
                  ]
                },
                %AccessSpecification{
                  object_identifier: %ObjectIdentifier{
                    type: :analog_value,
                    instance: 7
                  },
                  properties: [
                    %AccessSpecification.Property{
                      property_identifier: :present_value,
                      property_array_index: nil,
                      property_value: %Encoding{
                        encoding: :primitive,
                        extras: [],
                        type: :real,
                        value: 72.0
                      }
                    }
                  ]
                }
              ]
            }} =
             WritePropertyMultiple.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property_multiple,
               parameters: [
                 tagged: {0, <<0, 128, 0, 5>>, 4},
                 constructed: {1, [tagged: {0, "U", 1}, constructed: {2, {:real, 67.0}, 0}], 0},
                 tagged: {0, <<0, 128, 0, 6>>, 4},
                 constructed: {1, [tagged: {0, "U", 1}, constructed: {2, {:real, 67.0}, 0}], 0},
                 tagged: {0, <<0, 128, 0, 7>>, 4},
                 constructed: {1, [tagged: {0, "U", 1}, constructed: {2, {:real, 72.0}, 0}], 0}
               ]
             })
  end

  test "decoding WritePropertyMultiple invalid missing pattern" do
    assert {:error, :invalid_tags} =
             WritePropertyMultiple.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :write_property_multiple,
               parameters: [
                 tagged: {0, <<0, 128, 0, 5>>, 4}
               ]
             })
  end

  test "decoding WritePropertyMultiple invalid APDU" do
    assert {:error, :invalid_request} =
             WritePropertyMultiple.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :i_am,
               parameters: [
                 tagged: {0, <<0, 128, 0, 1>>, 4},
                 tagged: {1, "U", 1}
               ]
             })
  end

  test "encoding WritePropertyMultiple" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :write_property_multiple,
              parameters: [
                tagged: {0, <<0, 128, 0, 5>>, 4},
                constructed: {1, [tagged: {0, "U", 1}, constructed: {2, {:real, 67.0}, 0}], 0},
                tagged: {0, <<0, 128, 0, 6>>, 4},
                constructed: {1, [tagged: {0, "U", 1}, constructed: {2, {:real, 67.0}, 0}], 0},
                tagged: {0, <<0, 128, 0, 7>>, 4},
                constructed: {1, [tagged: {0, "U", 1}, constructed: {2, {:real, 72.0}, 0}], 0}
              ]
            }} =
             WritePropertyMultiple.to_apdu(
               %WritePropertyMultiple{
                 list: [
                   %AccessSpecification{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_value,
                       instance: 5
                     },
                     properties: [
                       %AccessSpecification.Property{
                         property_identifier: :present_value,
                         property_array_index: nil,
                         property_value: %Encoding{
                           encoding: :primitive,
                           extras: [],
                           type: :real,
                           value: 67.0
                         }
                       }
                     ]
                   },
                   %AccessSpecification{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_value,
                       instance: 6
                     },
                     properties: [
                       %AccessSpecification.Property{
                         property_identifier: :present_value,
                         property_array_index: nil,
                         property_value: %Encoding{
                           encoding: :primitive,
                           extras: [],
                           type: :real,
                           value: 67.0
                         }
                       }
                     ]
                   },
                   %AccessSpecification{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_value,
                       instance: 7
                     },
                     properties: [
                       %AccessSpecification.Property{
                         property_identifier: :present_value,
                         property_array_index: nil,
                         property_value: %Encoding{
                           encoding: :primitive,
                           extras: [],
                           type: :real,
                           value: 72.0
                         }
                       }
                     ]
                   }
                 ]
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding WritePropertyMultiple invalid specification" do
    assert {:error, :invalid_value} =
             WritePropertyMultiple.to_apdu(
               %WritePropertyMultiple{
                 list: [
                   %AccessSpecification{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_value,
                       instance: 5
                     },
                     properties: [
                       %AccessSpecification.Property{
                         property_identifier: :present_value,
                         property_array_index: :hello,
                         property_value: %Encoding{
                           encoding: :primitive,
                           extras: [],
                           type: :real,
                           value: 67.0
                         }
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
    assert :write_property_multiple ==
             ServicesProtocol.get_name(%WritePropertyMultiple{
               list: []
             })
  end

  test "protocol implementation is confirmed" do
    assert true ==
             ServicesProtocol.is_confirmed(%WritePropertyMultiple{
               list: []
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
              service: :write_property_multiple,
              parameters: [
                tagged: {0, <<0, 128, 0, 5>>, 4},
                constructed: {1, [tagged: {0, "U", 1}, constructed: {2, {:real, 67.0}, 0}], 0},
                tagged: {0, <<0, 128, 0, 6>>, 4},
                constructed: {1, [tagged: {0, "U", 1}, constructed: {2, {:real, 67.0}, 0}], 0},
                tagged: {0, <<0, 128, 0, 7>>, 4},
                constructed: {1, [tagged: {0, "U", 1}, constructed: {2, {:real, 72.0}, 0}], 0}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %WritePropertyMultiple{
                 list: [
                   %AccessSpecification{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_value,
                       instance: 5
                     },
                     properties: [
                       %AccessSpecification.Property{
                         property_identifier: :present_value,
                         property_array_index: nil,
                         property_value: %Encoding{
                           encoding: :primitive,
                           extras: [],
                           type: :real,
                           value: 67.0
                         }
                       }
                     ]
                   },
                   %AccessSpecification{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_value,
                       instance: 6
                     },
                     properties: [
                       %AccessSpecification.Property{
                         property_identifier: :present_value,
                         property_array_index: nil,
                         property_value: %Encoding{
                           encoding: :primitive,
                           extras: [],
                           type: :real,
                           value: 67.0
                         }
                       }
                     ]
                   },
                   %AccessSpecification{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_value,
                       instance: 7
                     },
                     properties: [
                       %AccessSpecification.Property{
                         property_identifier: :present_value,
                         property_array_index: nil,
                         property_value: %Encoding{
                           encoding: :primitive,
                           extras: [],
                           type: :real,
                           value: 72.0
                         }
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
