defmodule BACnet.Test.Protocol.Services.ConfirmedCovNotificationTest do
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.Services.ConfirmedCovNotification
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest ConfirmedCovNotification

  test "get name" do
    assert :confirmed_cov_notification == ConfirmedCovNotification.get_name()
  end

  test "is confirmed" do
    assert true == ConfirmedCovNotification.is_confirmed()
  end

  test "decoding ConfirmedCovNotification" do
    assert {:ok,
            %ConfirmedCovNotification{
              process_identifier: 99,
              initiating_device: %BACnet.Protocol.ObjectIdentifier{
                type: :device,
                instance: 86_001
              },
              monitored_object: %BACnet.Protocol.ObjectIdentifier{
                type: :binary_input,
                instance: 102
              },
              time_remaining: 30,
              property_values: [
                %BACnet.Protocol.PropertyValue{
                  property_identifier: :present_value,
                  property_array_index: nil,
                  property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                    encoding: :primitive,
                    extras: [],
                    type: :enumerated,
                    value: 0
                  },
                  priority: nil
                },
                %BACnet.Protocol.PropertyValue{
                  property_identifier: :status_flags,
                  property_array_index: nil,
                  property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                    encoding: :primitive,
                    extras: [],
                    type: :bitstring,
                    value: {false, false, false, false}
                  },
                  priority: nil
                }
              ]
            }} =
             ConfirmedCovNotification.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_cov_notification,
               parameters: [
                 tagged: {0, "c", 1},
                 tagged: {1, <<2, 1, 79, 241>>, 4},
                 tagged: {2, <<0, 192, 0, 102>>, 4},
                 tagged: {3, <<30>>, 1},
                 constructed:
                   {4,
                    [
                      tagged: {0, "U", 1},
                      constructed: {2, {:enumerated, 0}, 0},
                      tagged: {0, "o", 1},
                      constructed: {2, {:bitstring, {false, false, false, false}}, 0}
                    ], 0}
               ]
             })
  end

  test "decoding ConfirmedCovNotification invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             ConfirmedCovNotification.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_cov_notification,
               parameters: [
                 tagged: {0, "c", 1},
                 tagged: {1, <<2, 1, 79, 241>>, 4},
                 tagged: {2, <<0, 192, 0, 102>>, 4},
                 tagged: {3, <<30>>, 1}
               ]
             })
  end

  test "decoding ConfirmedCovNotification invalid process identifier" do
    assert {:error, :invalid_process_identifier_value} =
             ConfirmedCovNotification.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_cov_notification,
               parameters: [
                 tagged: {0, <<255, 255, 255, 255, 255>>, 5},
                 tagged: {1, <<2, 1, 79, 241>>, 4},
                 tagged: {2, <<0, 192, 0, 102>>, 4},
                 tagged: {3, <<30>>, 1},
                 constructed:
                   {4,
                    [
                      tagged: {0, "U", 1},
                      constructed: {2, {:enumerated, 0}, 0},
                      tagged: {0, "o", 1},
                      constructed: {2, {:bitstring, {false, false, false, false}}, 0}
                    ], 0}
               ]
             })
  end

  test "decoding ConfirmedCovNotification invalid APDU" do
    assert {:error, :invalid_request} =
             ConfirmedCovNotification.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :confirmed_event_notification,
               parameters: []
             })
  end

  test "encoding ConfirmedCovNotification" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :confirmed_cov_notification,
              parameters: [
                tagged: {0, "c", 1},
                tagged: {1, <<2, 1, 79, 241>>, 4},
                tagged: {2, <<0, 192, 0, 102>>, 4},
                tagged: {3, <<30>>, 1},
                constructed:
                  {4,
                   [
                     tagged: {0, "U", 1},
                     constructed: {2, {:enumerated, 0}, 0},
                     tagged: {0, "o", 1},
                     constructed: {2, {:bitstring, {false, false, false, false}}, 0}
                   ], 0}
              ]
            }} =
             ConfirmedCovNotification.to_apdu(
               %ConfirmedCovNotification{
                 process_identifier: 99,
                 initiating_device: %BACnet.Protocol.ObjectIdentifier{
                   type: :device,
                   instance: 86_001
                 },
                 monitored_object: %BACnet.Protocol.ObjectIdentifier{
                   type: :binary_input,
                   instance: 102
                 },
                 time_remaining: 30,
                 property_values: [
                   %BACnet.Protocol.PropertyValue{
                     property_identifier: :present_value,
                     property_array_index: nil,
                     property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :enumerated,
                       value: 0
                     },
                     priority: nil
                   },
                   %BACnet.Protocol.PropertyValue{
                     property_identifier: :status_flags,
                     property_array_index: nil,
                     property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :bitstring,
                       value: {false, false, false, false}
                     },
                     priority: nil
                   }
                 ]
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding ConfirmedCovNotification invalid process identifier" do
    assert {:error, :invalid_process_identifier_value} =
             ConfirmedCovNotification.to_apdu(
               %ConfirmedCovNotification{
                 process_identifier: 99_532_543_215_543_235,
                 initiating_device: %BACnet.Protocol.ObjectIdentifier{
                   type: :device,
                   instance: 86_001
                 },
                 monitored_object: %BACnet.Protocol.ObjectIdentifier{
                   type: :binary_input,
                   instance: 102
                 },
                 time_remaining: 30,
                 property_values: [
                   %BACnet.Protocol.PropertyValue{
                     property_identifier: :present_value,
                     property_array_index: nil,
                     property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :enumerated,
                       value: 0
                     },
                     priority: nil
                   },
                   %BACnet.Protocol.PropertyValue{
                     property_identifier: :status_flags,
                     property_array_index: nil,
                     property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :bitstring,
                       value: {false, false, false, false}
                     },
                     priority: nil
                   }
                 ]
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "protocol implementation get name" do
    assert :confirmed_cov_notification ==
             ServicesProtocol.get_name(%ConfirmedCovNotification{
               process_identifier: 99,
               initiating_device: %BACnet.Protocol.ObjectIdentifier{
                 type: :device,
                 instance: 86_001
               },
               monitored_object: %BACnet.Protocol.ObjectIdentifier{
                 type: :binary_input,
                 instance: 102
               },
               time_remaining: 30,
               property_values: [
                 %BACnet.Protocol.PropertyValue{
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 0
                   },
                   priority: nil
                 },
                 %BACnet.Protocol.PropertyValue{
                   property_identifier: :status_flags,
                   property_array_index: nil,
                   property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :bitstring,
                     value: {false, false, false, false}
                   },
                   priority: nil
                 }
               ]
             })
  end

  test "protocol implementation is confirmed" do
    assert true ==
             ServicesProtocol.is_confirmed(%ConfirmedCovNotification{
               process_identifier: 99,
               initiating_device: %BACnet.Protocol.ObjectIdentifier{
                 type: :device,
                 instance: 86_001
               },
               monitored_object: %BACnet.Protocol.ObjectIdentifier{
                 type: :binary_input,
                 instance: 102
               },
               time_remaining: 30,
               property_values: [
                 %BACnet.Protocol.PropertyValue{
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 0
                   },
                   priority: nil
                 },
                 %BACnet.Protocol.PropertyValue{
                   property_identifier: :status_flags,
                   property_array_index: nil,
                   property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :bitstring,
                     value: {false, false, false, false}
                   },
                   priority: nil
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
              service: :confirmed_cov_notification,
              parameters: [
                tagged: {0, "c", 1},
                tagged: {1, <<2, 1, 79, 241>>, 4},
                tagged: {2, <<0, 192, 0, 102>>, 4},
                tagged: {3, <<30>>, 1},
                constructed:
                  {4,
                   [
                     tagged: {0, "U", 1},
                     constructed: {2, {:enumerated, 0}, 0},
                     tagged: {0, "o", 1},
                     constructed: {2, {:bitstring, {false, false, false, false}}, 0}
                   ], 0}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %ConfirmedCovNotification{
                 process_identifier: 99,
                 initiating_device: %BACnet.Protocol.ObjectIdentifier{
                   type: :device,
                   instance: 86_001
                 },
                 monitored_object: %BACnet.Protocol.ObjectIdentifier{
                   type: :binary_input,
                   instance: 102
                 },
                 time_remaining: 30,
                 property_values: [
                   %BACnet.Protocol.PropertyValue{
                     property_identifier: :present_value,
                     property_array_index: nil,
                     property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :enumerated,
                       value: 0
                     },
                     priority: nil
                   },
                   %BACnet.Protocol.PropertyValue{
                     property_identifier: :status_flags,
                     property_array_index: nil,
                     property_value: %BACnet.Protocol.ApplicationTags.Encoding{
                       encoding: :primitive,
                       extras: [],
                       type: :bitstring,
                       value: {false, false, false, false}
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
