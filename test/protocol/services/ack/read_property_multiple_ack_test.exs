defmodule BACnet.Test.Protocol.Services.ReadPropertyMultipleAckTest do
  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.APDU.SimpleACK
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ReadAccessResult
  alias BACnet.Protocol.Services.Ack.ReadPropertyMultipleAck

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service
  @moduletag :service_ack

  doctest ReadPropertyMultipleAck

  test "decoding ReadPropertyMultipleAck" do
    assert {:ok,
            %ReadPropertyMultipleAck{
              results: [
                %ReadAccessResult{
                  object_identifier: %ObjectIdentifier{
                    type: :analog_input,
                    instance: 16
                  },
                  results: [
                    %ReadAccessResult.ReadResult{
                      property_identifier: :present_value,
                      property_array_index: nil,
                      property_value: %Encoding{
                        encoding: :primitive,
                        extras: [],
                        type: :real,
                        value: 72.3
                      },
                      error: nil
                    },
                    %ReadAccessResult.ReadResult{
                      property_identifier: :reliability,
                      property_array_index: nil,
                      property_value: %Encoding{
                        encoding: :primitive,
                        extras: [],
                        type: :enumerated,
                        value: 0
                      },
                      error: nil
                    }
                  ]
                }
              ]
            }} ==
             ReadPropertyMultipleAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_property_multiple,
               payload: [
                 tagged: {0, <<0, 0, 0, 16>>, 4},
                 constructed:
                   {1,
                    [
                      tagged: {2, "U", 1},
                      constructed: {4, {:real, 72.3}, 0},
                      tagged: {2, "g", 1},
                      constructed: {4, {:enumerated, 0}, 0}
                    ], 0}
               ]
             })
  end

  test "decoding ReadPropertyMultipleAck with several objects" do
    assert {:ok,
            %ReadPropertyMultipleAck{
              results: [
                %ReadAccessResult{
                  object_identifier: %ObjectIdentifier{
                    type: :analog_input,
                    instance: 33
                  },
                  results: [
                    %ReadAccessResult.ReadResult{
                      property_identifier: :present_value,
                      property_array_index: nil,
                      property_value: %Encoding{
                        encoding: :primitive,
                        extras: [],
                        type: :real,
                        value: 42.3
                      },
                      error: nil
                    }
                  ]
                },
                %ReadAccessResult{
                  object_identifier: %ObjectIdentifier{
                    type: :analog_input,
                    instance: 50
                  },
                  results: [
                    %ReadAccessResult.ReadResult{
                      property_identifier: :present_value,
                      property_array_index: nil,
                      property_value: nil,
                      error: %BACnetError{
                        class: :object,
                        code: :unknown_object
                      }
                    }
                  ]
                },
                %ReadAccessResult{
                  object_identifier: %ObjectIdentifier{
                    type: :analog_input,
                    instance: 35
                  },
                  results: [
                    %ReadAccessResult.ReadResult{
                      property_identifier: :present_value,
                      property_array_index: nil,
                      property_value: %Encoding{
                        encoding: :primitive,
                        extras: [],
                        type: :real,
                        value: 435.7
                      },
                      error: nil
                    }
                  ]
                }
              ]
            }} ==
             ReadPropertyMultipleAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_property_multiple,
               payload: [
                 tagged: {0, <<0, 0, 0, 33>>, 4},
                 constructed:
                   {1,
                    [
                      tagged: {2, "U", 1},
                      constructed: {4, {:real, 42.3}, 0}
                    ], 0},
                 tagged: {0, <<0, 0, 0, 50>>, 4},
                 constructed:
                   {1,
                    [
                      tagged: {2, "U", 1},
                      constructed: {5, [enumerated: 1, enumerated: 31], 0}
                    ], 0},
                 tagged: {0, <<0, 0, 0, 35>>, 4},
                 constructed:
                   {1,
                    [
                      tagged: {2, "U", 1},
                      constructed: {4, {:real, 435.7}, 0}
                    ], 0}
               ]
             })
  end

  test "decoding ReadPropertyMultipleAck invalid missing pattern" do
    assert {:error, :invalid_service_ack} =
             ReadPropertyMultipleAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_property_multiple,
               payload: [
                 tagged: {0, <<0, 0, 0, 16>>, 4},
                 constructed:
                   {1,
                    [
                      tagged: {2, "U", 1}
                    ], 0}
               ]
             })
  end

  test "decoding ReadPropertyMultipleAck invalid data" do
    assert {:error, :invalid_data} ==
             ReadPropertyMultipleAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_property_multiple,
               payload: [
                 tagged: {0, <<0, 0, 0, 16>>, 4},
                 constructed:
                   {1,
                    [
                      tagged: {2, "", 1}
                    ], 0}
               ]
             })
  end

  test "decoding ReadPropertyMultipleAck invalid result" do
    assert {:error, :invalid_service_ack} ==
             ReadPropertyMultipleAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_property_multiple,
               payload: [
                 tagged: {0, <<0, 0, 0, 16>>, 4},
                 constructed:
                   {1,
                    [
                      tagged: {2, "U", 1},
                      constructed: {4, {:real, 72.3}, 0},
                      tagged: {2, "g", 1}
                    ], 0}
               ]
             })
  end

  test "decoding ReadPropertyMultipleAck invalid wrong ACK" do
    assert {:error, :invalid_service_ack} =
             ReadPropertyMultipleAck.from_apdu(%SimpleACK{
               invoke_id: 0,
               service: :unconfirmed_service_request
             })
  end

  test "encoding ReadPropertyMultipleAck" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 55,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :read_property_multiple,
              payload: [
                tagged: {0, <<0, 0, 0, 16>>, 4},
                constructed:
                  {1,
                   [
                     tagged: {2, "U", 1},
                     constructed: {4, {:real, 72.3}, 0},
                     tagged: {2, "g", 1},
                     constructed: {4, {:enumerated, 0}, 0}
                   ], 0}
              ]
            }} ==
             ReadPropertyMultipleAck.to_apdu(
               %ReadPropertyMultipleAck{
                 results: [
                   %ReadAccessResult{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_input,
                       instance: 16
                     },
                     results: [
                       %ReadAccessResult.ReadResult{
                         property_identifier: :present_value,
                         property_array_index: nil,
                         property_value: %Encoding{
                           encoding: :primitive,
                           extras: [],
                           type: :real,
                           value: 72.3
                         },
                         error: nil
                       },
                       %ReadAccessResult.ReadResult{
                         property_identifier: :reliability,
                         property_array_index: nil,
                         property_value: %Encoding{
                           encoding: :primitive,
                           extras: [],
                           type: :enumerated,
                           value: 0
                         },
                         error: nil
                       }
                     ]
                   }
                 ]
               },
               55
             )
  end

  test "encoding ReadPropertyMultipleAck with optional invoke_id" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 0,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :read_property_multiple,
              payload: [
                tagged: {0, <<0, 0, 0, 16>>, 4},
                constructed:
                  {1,
                   [
                     tagged: {2, "U", 1},
                     constructed: {4, {:real, 72.3}, 0},
                     tagged: {2, "g", 1},
                     constructed: {4, {:enumerated, 0}, 0}
                   ], 0}
              ]
            }} ==
             ReadPropertyMultipleAck.to_apdu(%ReadPropertyMultipleAck{
               results: [
                 %ReadAccessResult{
                   object_identifier: %ObjectIdentifier{
                     type: :analog_input,
                     instance: 16
                   },
                   results: [
                     %ReadAccessResult.ReadResult{
                       property_identifier: :present_value,
                       property_array_index: nil,
                       property_value: %Encoding{
                         encoding: :primitive,
                         extras: [],
                         type: :real,
                         value: 72.3
                       },
                       error: nil
                     },
                     %ReadAccessResult.ReadResult{
                       property_identifier: :reliability,
                       property_array_index: nil,
                       property_value: %Encoding{
                         encoding: :primitive,
                         extras: [],
                         type: :enumerated,
                         value: 0
                       },
                       error: nil
                     }
                   ]
                 }
               ]
             })
  end

  test "encoding ReadPropertyMultipleAck with several objects" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 55,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :read_property_multiple,
              payload: [
                tagged: {0, <<0, 0, 0, 33>>, 4},
                constructed:
                  {1,
                   [
                     tagged: {2, "U", 1},
                     constructed: {4, {:real, 42.3}, 0}
                   ], 0},
                tagged: {0, <<0, 0, 0, 50>>, 4},
                constructed:
                  {1,
                   [
                     tagged: {2, "U", 1},
                     constructed: {5, [enumerated: 1, enumerated: 31], 0}
                   ], 0},
                tagged: {0, <<0, 0, 0, 35>>, 4},
                constructed:
                  {1,
                   [
                     tagged: {2, "U", 1},
                     constructed: {4, {:real, 435.7}, 0}
                   ], 0}
              ]
            }} ==
             ReadPropertyMultipleAck.to_apdu(
               %ReadPropertyMultipleAck{
                 results: [
                   %ReadAccessResult{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_input,
                       instance: 33
                     },
                     results: [
                       %ReadAccessResult.ReadResult{
                         property_identifier: :present_value,
                         property_array_index: nil,
                         property_value: %Encoding{
                           encoding: :primitive,
                           extras: [],
                           type: :real,
                           value: 42.3
                         },
                         error: nil
                       }
                     ]
                   },
                   %ReadAccessResult{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_input,
                       instance: 50
                     },
                     results: [
                       %ReadAccessResult.ReadResult{
                         property_identifier: :present_value,
                         property_array_index: nil,
                         property_value: nil,
                         error: %BACnetError{
                           class: :object,
                           code: :unknown_object
                         }
                       }
                     ]
                   },
                   %ReadAccessResult{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_input,
                       instance: 35
                     },
                     results: [
                       %ReadAccessResult.ReadResult{
                         property_identifier: :present_value,
                         property_array_index: nil,
                         property_value: %Encoding{
                           encoding: :primitive,
                           extras: [],
                           type: :real,
                           value: 435.7
                         },
                         error: nil
                       }
                     ]
                   }
                 ]
               },
               55
             )
  end

  test "encoding ReadPropertyMultipleAck invalid result" do
    assert {:error, :invalid_value_and_error} ==
             ReadPropertyMultipleAck.to_apdu(%ReadPropertyMultipleAck{
               results: [
                 %ReadAccessResult{
                   object_identifier: %ObjectIdentifier{
                     type: :analog_input,
                     instance: 16
                   },
                   results: [
                     %ReadAccessResult.ReadResult{
                       property_identifier: :present_value,
                       property_array_index: nil,
                       property_value: nil,
                       error: nil
                     }
                   ]
                 }
               ]
             })
  end

  test "encoding ReadPropertyMultipleAck invalid invoke_id" do
    assert {:error, :invalid_parameter} ==
             ReadPropertyMultipleAck.to_apdu(
               %ReadPropertyMultipleAck{
                 results: [
                   %ReadAccessResult{
                     object_identifier: %ObjectIdentifier{
                       type: :analog_input,
                       instance: 33
                     },
                     results: [
                       %ReadAccessResult.ReadResult{
                         property_identifier: :present_value,
                         property_array_index: nil,
                         property_value: %Encoding{
                           encoding: :primitive,
                           extras: [],
                           type: :real,
                           value: 42.3
                         },
                         error: nil
                       }
                     ]
                   }
                 ]
               },
               256
             )
  end
end
