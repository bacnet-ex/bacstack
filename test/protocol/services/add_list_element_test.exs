defmodule BACnet.Test.Protocol.Services.AddListElementTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.AddListElement
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest AddListElement

  test "get name" do
    assert :add_list_element == AddListElement.get_name()
  end

  test "is confirmed" do
    assert true == AddListElement.is_confirmed()
  end

  test "decoding AddListElement" do
    assert {:ok,
            %AddListElement{
              object_identifier: %ObjectIdentifier{
                type: :group,
                instance: 3
              },
              property_identifier: :list_of_group_members,
              property_array_index: nil,
              elements: [
                %Encoding{
                  encoding: :tagged,
                  extras: [tag_number: 0],
                  type: nil,
                  value: <<0, 0, 0, 15>>
                },
                %Encoding{
                  encoding: :constructed,
                  extras: [tag_number: 1],
                  type: nil,
                  value: [tagged: {0, "U", 1}, tagged: {0, "g", 1}]
                }
              ]
            }} =
             AddListElement.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :add_list_element,
               parameters: [
                 tagged: {0, <<2, 192, 0, 3>>, 4},
                 tagged: {1, "5", 1},
                 constructed:
                   {3,
                    [
                      tagged: {0, <<0, 0, 0, 15>>, 4},
                      constructed: {1, [tagged: {0, "U", 1}, tagged: {0, "g", 1}], 0}
                    ], 0}
               ]
             })
  end

  test "decoding AddListElement with array index" do
    assert {:ok,
            %AddListElement{
              object_identifier: %ObjectIdentifier{
                type: :group,
                instance: 3
              },
              property_identifier: :list_of_group_members,
              property_array_index: 97,
              elements: [
                %Encoding{
                  encoding: :tagged,
                  extras: [tag_number: 0],
                  type: nil,
                  value: <<0, 0, 0, 15>>
                },
                %Encoding{
                  encoding: :constructed,
                  extras: [tag_number: 1],
                  type: nil,
                  value: [tagged: {0, "U", 1}, tagged: {0, "g", 1}]
                }
              ]
            }} =
             AddListElement.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :add_list_element,
               parameters: [
                 tagged: {0, <<2, 192, 0, 3>>, 4},
                 tagged: {1, "5", 1},
                 tagged: {2, "a", 1},
                 constructed:
                   {3,
                    [
                      tagged: {0, <<0, 0, 0, 15>>, 4},
                      constructed: {1, [tagged: {0, "U", 1}, tagged: {0, "g", 1}], 0}
                    ], 0}
               ]
             })
  end

  test "decoding AddListElement invalid unknown tag encoding" do
    assert {:error, :unknown_tag_encoding} =
             AddListElement.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :add_list_element,
               parameters: [tagged: {0, <<>>, 0}]
             })
  end

  test "decoding AddListElement invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             AddListElement.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :add_list_element,
               parameters: [
                 tagged: {0, <<2, 192, 0, 3>>, 4},
                 tagged: {1, "5", 1}
               ]
             })
  end

  test "decoding AddListElement invalid APDU" do
    assert {:error, :invalid_request} =
             AddListElement.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :remove_list_element,
               parameters: []
             })
  end

  test "encoding AddListElement" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :add_list_element,
              parameters: [
                tagged: {0, <<2, 192, 0, 3>>, 4},
                tagged: {1, "5", 1},
                constructed:
                  {3,
                   [
                     tagged: {0, <<0, 0, 0, 15>>, 4},
                     constructed: {1, [tagged: {0, "U", 1}, tagged: {0, "g", 1}], 0}
                   ], 0}
              ]
            }} =
             AddListElement.to_apdu(
               %AddListElement{
                 object_identifier: %ObjectIdentifier{
                   type: :group,
                   instance: 3
                 },
                 property_identifier: :list_of_group_members,
                 property_array_index: nil,
                 elements: [
                   %Encoding{
                     encoding: :tagged,
                     extras: [tag_number: 0],
                     type: nil,
                     value: <<0, 0, 0, 15>>
                   },
                   %Encoding{
                     encoding: :constructed,
                     extras: [tag_number: 1],
                     type: nil,
                     value: [tagged: {0, "U", 1}, tagged: {0, "g", 1}]
                   }
                 ]
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding AddListElement with array index" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :add_list_element,
              parameters: [
                tagged: {0, <<2, 192, 0, 3>>, 4},
                tagged: {1, "5", 1},
                tagged: {2, "a", 1},
                constructed:
                  {3,
                   [
                     tagged: {0, <<0, 0, 0, 15>>, 4},
                     constructed: {1, [tagged: {0, "U", 1}, tagged: {0, "g", 1}], 0}
                   ], 0}
              ]
            }} =
             AddListElement.to_apdu(
               %AddListElement{
                 object_identifier: %ObjectIdentifier{
                   type: :group,
                   instance: 3
                 },
                 property_identifier: :list_of_group_members,
                 property_array_index: 97,
                 elements: [
                   %Encoding{
                     encoding: :tagged,
                     extras: [tag_number: 0],
                     type: nil,
                     value: <<0, 0, 0, 15>>
                   },
                   %Encoding{
                     encoding: :constructed,
                     extras: [tag_number: 1],
                     type: nil,
                     value: [tagged: {0, "U", 1}, tagged: {0, "g", 1}]
                   }
                 ]
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "protocol implementation get name" do
    assert :add_list_element ==
             ServicesProtocol.get_name(%AddListElement{
               object_identifier: %ObjectIdentifier{
                 type: :group,
                 instance: 3
               },
               property_identifier: :list_of_group_members,
               property_array_index: nil,
               elements: []
             })
  end

  test "protocol implementation is confirmed" do
    assert true ==
             ServicesProtocol.is_confirmed(%AddListElement{
               object_identifier: %ObjectIdentifier{
                 type: :group,
                 instance: 3
               },
               property_identifier: :list_of_group_members,
               property_array_index: nil,
               elements: []
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
              service: :add_list_element,
              parameters: [
                tagged: {0, <<2, 192, 0, 3>>, 4},
                tagged: {1, "5", 1},
                constructed:
                  {3,
                   [
                     tagged: {0, <<0, 0, 0, 15>>, 4},
                     constructed: {1, [tagged: {0, "U", 1}, tagged: {0, "g", 1}], 0}
                   ], 0}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %AddListElement{
                 object_identifier: %ObjectIdentifier{
                   type: :group,
                   instance: 3
                 },
                 property_identifier: :list_of_group_members,
                 property_array_index: nil,
                 elements: [
                   %Encoding{
                     encoding: :tagged,
                     extras: [tag_number: 0],
                     type: nil,
                     value: <<0, 0, 0, 15>>
                   },
                   %Encoding{
                     encoding: :constructed,
                     extras: [tag_number: 1],
                     type: nil,
                     value: [tagged: {0, "U", 1}, tagged: {0, "g", 1}]
                   }
                 ]
               },
               invoke_id: 1,
               max_segments: 4
             )
  end
end
