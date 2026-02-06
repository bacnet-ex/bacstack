defmodule BACnet.Test.Protocol.Services.ReadPropertyAckTest do
  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.APDU.SimpleACK
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.Ack.ReadPropertyAck

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service
  @moduletag :service_ack

  doctest ReadPropertyAck

  test "decoding ReadPropertyAck" do
    assert {:ok,
            %ReadPropertyAck{
              object_identifier: %ObjectIdentifier{
                type: :analog_input,
                instance: 5
              },
              property_identifier: :present_value,
              property_array_index: nil,
              property_value: %Encoding{
                encoding: :primitive,
                extras: [],
                type: :real,
                value: 72.3
              }
            }} ==
             ReadPropertyAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_property,
               payload: [
                 tagged: {0, <<0, 0, 0, 5>>, 4},
                 tagged: {1, "U", 1},
                 constructed: {3, {:real, 72.3}, 0}
               ]
             })
  end

  test "decoding ReadPropertyAck list" do
    assert {:ok,
            %ReadPropertyAck{
              object_identifier: %ObjectIdentifier{
                type: :analog_input,
                instance: 5
              },
              property_identifier: :present_value,
              property_array_index: nil,
              property_value: [
                %Encoding{
                  encoding: :primitive,
                  extras: [],
                  type: :real,
                  value: 72.3
                }
              ]
            }} ==
             ReadPropertyAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_property,
               payload: [
                 tagged: {0, <<0, 0, 0, 5>>, 4},
                 tagged: {1, "U", 1},
                 constructed: {3, [{:real, 72.3}], 0}
               ]
             })
  end

  test "decoding ReadPropertyAck with array index" do
    assert {:ok,
            %ReadPropertyAck{
              object_identifier: %ObjectIdentifier{
                type: :analog_input,
                instance: 5
              },
              property_identifier: :present_value,
              property_array_index: 97,
              property_value: %Encoding{
                encoding: :primitive,
                extras: [],
                type: :real,
                value: 72.3
              }
            }} ==
             ReadPropertyAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_property,
               payload: [
                 tagged: {0, <<0, 0, 0, 5>>, 4},
                 tagged: {1, "U", 1},
                 tagged: {2, "a", 1},
                 constructed: {3, {:real, 72.3}, 0}
               ]
             })
  end

  test "decoding ReadPropertyAck invalid missing pattern" do
    assert {:error, :invalid_service_ack} =
             ReadPropertyAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_property,
               payload: [
                 tagged: {0, <<0, 0, 0, 5>>, 4},
                 tagged: {1, "U", 1}
               ]
             })
  end

  test "decoding ReadPropertyAck invalid data" do
    assert {:error, :invalid_data} =
             ReadPropertyAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_property,
               payload: [
                 tagged: {0, <<0, 0, 0, 5>>, 4},
                 tagged: {1, "U", 1},
                 tagged: {2, <<>>, 1}
               ]
             })
  end

  test "decoding ReadPropertyAck invalid wrong ACK" do
    assert {:error, :invalid_service_ack} =
             ReadPropertyAck.from_apdu(%SimpleACK{
               invoke_id: 0,
               service: :unconfirmed_service_request
             })
  end

  test "encoding ReadPropertyAck" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 55,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :read_property,
              payload: [
                tagged: {0, <<0, 0, 0, 5>>, 4},
                tagged: {1, "U", 1},
                constructed: {3, {:real, 72.3}, 0}
              ]
            }} ==
             ReadPropertyAck.to_apdu(
               %ReadPropertyAck{
                 object_identifier: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 5
                 },
                 property_identifier: :present_value,
                 property_array_index: nil,
                 property_value: %Encoding{
                   encoding: :primitive,
                   extras: [],
                   type: :real,
                   value: 72.3
                 }
               },
               55
             )
  end

  test "encoding ReadPropertyAck list" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 55,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :read_property,
              payload: [
                tagged: {0, <<0, 0, 0, 5>>, 4},
                tagged: {1, "U", 1},
                constructed: {3, [{:real, 72.3}], 0}
              ]
            }} ==
             ReadPropertyAck.to_apdu(
               %ReadPropertyAck{
                 object_identifier: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 5
                 },
                 property_identifier: :present_value,
                 property_array_index: nil,
                 property_value: [
                   %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :real,
                     value: 72.3
                   }
                 ]
               },
               55
             )
  end

  test "encoding ReadPropertyAck with array index" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 55,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :read_property,
              payload: [
                tagged: {0, <<0, 0, 0, 5>>, 4},
                tagged: {1, "U", 1},
                tagged: {2, "a", 1},
                constructed: {3, {:real, 72.3}, 0}
              ]
            }} ==
             ReadPropertyAck.to_apdu(
               %ReadPropertyAck{
                 object_identifier: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 5
                 },
                 property_identifier: :present_value,
                 property_array_index: 97,
                 property_value: %Encoding{
                   encoding: :primitive,
                   extras: [],
                   type: :real,
                   value: 72.3
                 }
               },
               55
             )
  end

  test "encoding ReadPropertyAck with optional invoke_id" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 0,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :read_property,
              payload: [
                tagged: {0, <<0, 0, 0, 5>>, 4},
                tagged: {1, "U", 1},
                constructed: {3, {:real, 72.3}, 0}
              ]
            }} ==
             ReadPropertyAck.to_apdu(%ReadPropertyAck{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 5
               },
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: %Encoding{
                 encoding: :primitive,
                 extras: [],
                 type: :real,
                 value: 72.3
               }
             })
  end

  test "encoding ReadPropertyAck invalid list" do
    assert {:error, :invalid_value} ==
             ReadPropertyAck.to_apdu(
               %ReadPropertyAck{
                 object_identifier: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 5
                 },
                 property_identifier: :present_value,
                 property_array_index: nil,
                 property_value: [
                   %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :real,
                     value: 72.3
                   },
                   %Encoding{
                     encoding: :hello_there,
                     extras: [],
                     type: :real,
                     value: 72.3
                   }
                 ]
               },
               55
             )
  end

  test "encoding ReadPropertyAck invalid invoke_id" do
    assert {:error, :invalid_parameter} ==
             ReadPropertyAck.to_apdu(
               %ReadPropertyAck{
                 object_identifier: %ObjectIdentifier{
                   type: :analog_input,
                   instance: 5
                 },
                 property_identifier: :present_value,
                 property_array_index: nil,
                 property_value: %Encoding{
                   encoding: :primitive,
                   extras: [],
                   type: :real,
                   value: 72.3
                 }
               },
               256
             )
  end
end
