defmodule BACnet.Test.Protocol.Services.ReadRangeTest do
  alias BACnet.Protocol.APDU.ConfirmedServiceRequest
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.Services.Protocol, as: ServicesProtocol
  alias BACnet.Protocol.Services.ReadRange

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service

  doctest ReadRange

  test "get name" do
    assert :read_range == ReadRange.get_name()
  end

  test "is confirmed" do
    assert true == ReadRange.is_confirmed()
  end

  test "decoding ReadRange by position" do
    assert {:ok,
            %ReadRange{
              object_identifier: %ObjectIdentifier{
                type: :trend_log,
                instance: 1
              },
              property_identifier: :log_buffer,
              property_array_index: nil,
              range: {:by_position, {512, 1}}
            }} =
             ReadRange.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               parameters: [
                 tagged: {0, <<5, 0, 0, 1>>, 4},
                 tagged: {1, <<131>>, 1},
                 constructed:
                   {3,
                    [
                      unsigned_integer: 512,
                      signed_integer: 1
                    ], 0}
               ]
             })
  end

  test "decoding ReadRange by position with array index" do
    assert {:ok,
            %ReadRange{
              object_identifier: %ObjectIdentifier{
                type: :trend_log,
                instance: 1
              },
              property_identifier: :log_buffer,
              property_array_index: 97,
              range: {:by_position, {512, 1}}
            }} =
             ReadRange.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               parameters: [
                 tagged: {0, <<5, 0, 0, 1>>, 4},
                 tagged: {1, <<131>>, 1},
                 tagged: {2, "a", 1},
                 constructed:
                   {3,
                    [
                      unsigned_integer: 512,
                      signed_integer: 1
                    ], 0}
               ]
             })
  end

  test "decoding ReadRange by sequence number" do
    assert {:ok,
            %ReadRange{
              object_identifier: %ObjectIdentifier{
                type: :trend_log,
                instance: 51
              },
              property_identifier: :log_buffer,
              property_array_index: nil,
              range: {:by_seq_number, {5, 12}}
            }} =
             ReadRange.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               parameters: [
                 tagged: {0, <<5, 0, 0, 51>>, 4},
                 tagged: {1, <<131>>, 1},
                 constructed:
                   {6,
                    [
                      unsigned_integer: 5,
                      signed_integer: 12
                    ], 0}
               ]
             })
  end

  test "decoding ReadRange by time" do
    assert {:ok,
            %ReadRange{
              object_identifier: %ObjectIdentifier{
                type: :trend_log,
                instance: 1
              },
              property_identifier: :log_buffer,
              property_array_index: nil,
              range:
                {:by_time,
                 {%BACnetDateTime{
                    date: %BACnetDate{
                      year: 1998,
                      month: 3,
                      day: 23,
                      weekday: 1
                    },
                    time: %BACnetTime{
                      hour: 19,
                      minute: 52,
                      second: 34,
                      hundredth: 0
                    }
                  }, 4}}
            }} =
             ReadRange.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               parameters: [
                 tagged: {0, <<5, 0, 0, 1>>, 4},
                 tagged: {1, <<131>>, 1},
                 constructed:
                   {7,
                    [
                      date: %BACnet.Protocol.BACnetDate{
                        year: 1998,
                        month: 3,
                        day: 23,
                        weekday: 1
                      },
                      time: %BACnet.Protocol.BACnetTime{
                        hour: 19,
                        minute: 52,
                        second: 34,
                        hundredth: 0
                      },
                      signed_integer: 4
                    ], 0}
               ]
             })
  end

  test "decoding ReadRange without range" do
    assert {:ok,
            %ReadRange{
              object_identifier: %ObjectIdentifier{
                type: :trend_log,
                instance: 1
              },
              property_identifier: :log_buffer,
              property_array_index: nil,
              range: nil
            }} =
             ReadRange.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               parameters: [
                 tagged: {0, <<5, 0, 0, 1>>, 4},
                 tagged: {1, <<131>>, 1}
               ]
             })
  end

  test "decoding ReadRange invalid range" do
    assert {:error, :invalid_range_param} =
             ReadRange.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               parameters: [
                 tagged: {0, <<5, 0, 0, 1>>, 4},
                 tagged: {1, <<131>>, 1},
                 constructed: {10, [], 0}
               ]
             })
  end

  test "decoding ReadRange invalid unknown tag encoding" do
    assert {:error, :unknown_tag_encoding} =
             ReadRange.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               parameters: [
                 tagged: {0, <<>>, 0},
                 tagged: {1, <<131>>, 1},
                 constructed:
                   {3,
                    [
                      unsigned_integer: 512,
                      signed_integer: 1
                    ], 0}
               ]
             })
  end

  test "decoding ReadRange invalid property identifier (special atom)" do
    assert {:error, :invalid_property_identifier} =
             ReadRange.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               parameters: [
                 tagged: {0, <<5, 0, 0, 1>>, 4},
                 tagged: {1, <<Constants.by_name!(:property_identifier, :all)>>, 1},
                 constructed:
                   {3,
                    [
                      unsigned_integer: 512,
                      signed_integer: 1
                    ], 0}
               ]
             })
  end

  test "decoding ReadRange invalid missing pattern" do
    assert {:error, :invalid_request_parameters} =
             ReadRange.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               parameters: [
                 tagged: {0, <<5, 0, 0, 1>>, 4}
               ]
             })
  end

  test "decoding ReadRange by position invalid count" do
    assert {:error, :invalid_range_param} =
             ReadRange.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               parameters: [
                 tagged: {0, <<5, 0, 0, 1>>, 4},
                 tagged: {1, <<131>>, 1},
                 constructed:
                   {3,
                    [
                      unsigned_integer: 512,
                      signed_integer: 0
                    ], 0}
               ]
             })

    assert {:error, :invalid_range_param} =
             ReadRange.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               parameters: [
                 tagged: {0, <<5, 0, 0, 1>>, 4},
                 tagged: {1, <<131>>, 1},
                 constructed:
                   {3,
                    [
                      unsigned_integer: 512,
                      signed_integer: -65_535
                    ], 0}
               ]
             })

    assert {:error, :invalid_range_param} =
             ReadRange.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               parameters: [
                 tagged: {0, <<5, 0, 0, 1>>, 4},
                 tagged: {1, <<131>>, 1},
                 constructed:
                   {3,
                    [
                      unsigned_integer: 512,
                      signed_integer: 65_535
                    ], 0}
               ]
             })
  end

  test "decoding ReadRange by sequence number invalid count" do
    assert {:error, :invalid_range_param} =
             ReadRange.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               parameters: [
                 tagged: {0, <<5, 0, 0, 51>>, 4},
                 tagged: {1, <<131>>, 1},
                 constructed:
                   {6,
                    [
                      unsigned_integer: 5,
                      signed_integer: 0
                    ], 0}
               ]
             })

    assert {:error, :invalid_range_param} =
             ReadRange.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               parameters: [
                 tagged: {0, <<5, 0, 0, 51>>, 4},
                 tagged: {1, <<131>>, 1},
                 constructed:
                   {6,
                    [
                      unsigned_integer: 5,
                      signed_integer: -65_535
                    ], 0}
               ]
             })

    assert {:error, :invalid_range_param} =
             ReadRange.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               parameters: [
                 tagged: {0, <<5, 0, 0, 51>>, 4},
                 tagged: {1, <<131>>, 1},
                 constructed:
                   {6,
                    [
                      unsigned_integer: 5,
                      signed_integer: 65_535
                    ], 0}
               ]
             })
  end

  test "decoding ReadRange by time invalid count" do
    assert {:error, :invalid_range_param} =
             ReadRange.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               parameters: [
                 tagged: {0, <<5, 0, 0, 1>>, 4},
                 tagged: {1, <<131>>, 1},
                 constructed:
                   {7,
                    [
                      date: %BACnet.Protocol.BACnetDate{
                        year: 1998,
                        month: 3,
                        day: 23,
                        weekday: 1
                      },
                      time: %BACnet.Protocol.BACnetTime{
                        hour: 19,
                        minute: 52,
                        second: 34,
                        hundredth: 0
                      },
                      signed_integer: 0
                    ], 0}
               ]
             })

    assert {:error, :invalid_range_param} =
             ReadRange.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               parameters: [
                 tagged: {0, <<5, 0, 0, 1>>, 4},
                 tagged: {1, <<131>>, 1},
                 constructed:
                   {7,
                    [
                      date: %BACnet.Protocol.BACnetDate{
                        year: 1998,
                        month: 3,
                        day: 23,
                        weekday: 1
                      },
                      time: %BACnet.Protocol.BACnetTime{
                        hour: 19,
                        minute: 52,
                        second: 34,
                        hundredth: 0
                      },
                      signed_integer: -65_535
                    ], 0}
               ]
             })

    assert {:error, :invalid_range_param} =
             ReadRange.from_apdu(%ConfirmedServiceRequest{
               segmented_response_accepted: true,
               max_apdu: 1476,
               max_segments: 4,
               invoke_id: 1,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               parameters: [
                 tagged: {0, <<5, 0, 0, 1>>, 4},
                 tagged: {1, <<131>>, 1},
                 constructed:
                   {7,
                    [
                      date: %BACnet.Protocol.BACnetDate{
                        year: 1998,
                        month: 3,
                        day: 23,
                        weekday: 1
                      },
                      time: %BACnet.Protocol.BACnetTime{
                        hour: 19,
                        minute: 52,
                        second: 34,
                        hundredth: 0
                      },
                      signed_integer: 65_535
                    ], 0}
               ]
             })
  end

  test "decoding ReadRange invalid APDU" do
    assert {:error, :invalid_request} =
             ReadRange.from_apdu(%ConfirmedServiceRequest{
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

  test "encoding ReadRange by position" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :read_range,
              parameters: [
                tagged: {0, <<5, 0, 0, 1>>, 4},
                tagged: {1, <<131>>, 1},
                constructed:
                  {3,
                   [
                     unsigned_integer: 512,
                     signed_integer: 1
                   ], 0}
              ]
            }} =
             ReadRange.to_apdu(
               %ReadRange{
                 object_identifier: %ObjectIdentifier{
                   type: :trend_log,
                   instance: 1
                 },
                 property_identifier: :log_buffer,
                 property_array_index: nil,
                 range: {:by_position, {512, 1}}
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding ReadRange by position with array index" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :read_range,
              parameters: [
                tagged: {0, <<5, 0, 0, 1>>, 4},
                tagged: {1, <<131>>, 1},
                tagged: {2, "a", 1},
                constructed:
                  {3,
                   [
                     unsigned_integer: 512,
                     signed_integer: 1
                   ], 0}
              ]
            }} =
             ReadRange.to_apdu(
               %ReadRange{
                 object_identifier: %ObjectIdentifier{
                   type: :trend_log,
                   instance: 1
                 },
                 property_identifier: :log_buffer,
                 property_array_index: 97,
                 range: {:by_position, {512, 1}}
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding ReadRange by sequence number" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :read_range,
              parameters: [
                tagged: {0, <<5, 0, 0, 51>>, 4},
                tagged: {1, <<131>>, 1},
                constructed:
                  {6,
                   [
                     unsigned_integer: 5,
                     signed_integer: 12
                   ], 0}
              ]
            }} =
             ReadRange.to_apdu(
               %ReadRange{
                 object_identifier: %ObjectIdentifier{
                   type: :trend_log,
                   instance: 51
                 },
                 property_identifier: :log_buffer,
                 property_array_index: nil,
                 range: {:by_seq_number, {5, 12}}
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding ReadRange by time" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :read_range,
              parameters: [
                tagged: {0, <<5, 0, 0, 1>>, 4},
                tagged: {1, <<131>>, 1},
                constructed:
                  {7,
                   [
                     date: %BACnet.Protocol.BACnetDate{
                       year: 1998,
                       month: 3,
                       day: 23,
                       weekday: 1
                     },
                     time: %BACnet.Protocol.BACnetTime{
                       hour: 19,
                       minute: 52,
                       second: 34,
                       hundredth: 0
                     },
                     signed_integer: 4
                   ], 0}
              ]
            }} =
             ReadRange.to_apdu(
               %ReadRange{
                 object_identifier: %ObjectIdentifier{
                   type: :trend_log,
                   instance: 1
                 },
                 property_identifier: :log_buffer,
                 property_array_index: nil,
                 range:
                   {:by_time,
                    {%BACnetDateTime{
                       date: %BACnetDate{
                         year: 1998,
                         month: 3,
                         day: 23,
                         weekday: 1
                       },
                       time: %BACnetTime{
                         hour: 19,
                         minute: 52,
                         second: 34,
                         hundredth: 0
                       }
                     }, 4}}
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding ReadRange without range" do
    assert {:ok,
            %ConfirmedServiceRequest{
              segmented_response_accepted: true,
              max_apdu: 1476,
              max_segments: 4,
              invoke_id: 1,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :read_range,
              parameters: [
                tagged: {0, <<5, 0, 0, 1>>, 4},
                tagged: {1, <<131>>, 1}
              ]
            }} =
             ReadRange.to_apdu(
               %ReadRange{
                 object_identifier: %ObjectIdentifier{
                   type: :trend_log,
                   instance: 1
                 },
                 property_identifier: :log_buffer,
                 property_array_index: nil,
                 range: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding ReadRange invalid property identifier (special atom)" do
    assert {:error, :invalid_property_identifier} =
             ReadRange.to_apdu(
               %ReadRange{
                 object_identifier: %ObjectIdentifier{
                   type: :trend_log,
                   instance: 1
                 },
                 property_identifier: :all,
                 property_array_index: nil,
                 range: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding ReadRange invalid range specifier" do
    assert {:error, :invalid_range} =
             ReadRange.to_apdu(
               %ReadRange{
                 object_identifier: %ObjectIdentifier{
                   type: :trend_log,
                   instance: 1
                 },
                 property_identifier: :log_buffer,
                 property_array_index: nil,
                 range: :hello
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding ReadRange by position invalid count" do
    assert {:error, :invalid_range} =
             ReadRange.to_apdu(
               %ReadRange{
                 object_identifier: %ObjectIdentifier{
                   type: :trend_log,
                   instance: 1
                 },
                 property_identifier: :log_buffer,
                 property_array_index: nil,
                 range: {:by_position, {512, 0}}
               },
               invoke_id: 1,
               max_segments: 4
             )

    assert {:error, :invalid_range} =
             ReadRange.to_apdu(
               %ReadRange{
                 object_identifier: %ObjectIdentifier{
                   type: :trend_log,
                   instance: 1
                 },
                 property_identifier: :log_buffer,
                 property_array_index: nil,
                 range: {:by_position, {512, -65_535}}
               },
               invoke_id: 1,
               max_segments: 4
             )

    assert {:error, :invalid_range} =
             ReadRange.to_apdu(
               %ReadRange{
                 object_identifier: %ObjectIdentifier{
                   type: :trend_log,
                   instance: 1
                 },
                 property_identifier: :log_buffer,
                 property_array_index: nil,
                 range: {:by_position, {512, 65_535}}
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding ReadRange by sequence number invalid count" do
    assert {:error, :invalid_range} =
             ReadRange.to_apdu(
               %ReadRange{
                 object_identifier: %ObjectIdentifier{
                   type: :trend_log,
                   instance: 51
                 },
                 property_identifier: :log_buffer,
                 property_array_index: nil,
                 range: {:by_seq_number, {5, 0}}
               },
               invoke_id: 1,
               max_segments: 4
             )

    assert {:error, :invalid_range} =
             ReadRange.to_apdu(
               %ReadRange{
                 object_identifier: %ObjectIdentifier{
                   type: :trend_log,
                   instance: 51
                 },
                 property_identifier: :log_buffer,
                 property_array_index: nil,
                 range: {:by_seq_number, {5, 65_535}}
               },
               invoke_id: 1,
               max_segments: 4
             )

    assert {:error, :invalid_range} =
             ReadRange.to_apdu(
               %ReadRange{
                 object_identifier: %ObjectIdentifier{
                   type: :trend_log,
                   instance: 51
                 },
                 property_identifier: :log_buffer,
                 property_array_index: nil,
                 range: {:by_seq_number, {5, 65_535}}
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "encoding ReadRange by time invalid count" do
    assert {:error, :invalid_range} =
             ReadRange.to_apdu(
               %ReadRange{
                 object_identifier: %ObjectIdentifier{
                   type: :trend_log,
                   instance: 1
                 },
                 property_identifier: :log_buffer,
                 property_array_index: nil,
                 range:
                   {:by_time,
                    {%BACnetDateTime{
                       date: %BACnetDate{
                         year: 1998,
                         month: 3,
                         day: 23,
                         weekday: 1
                       },
                       time: %BACnetTime{
                         hour: 19,
                         minute: 52,
                         second: 34,
                         hundredth: 0
                       }
                     }, 0}}
               },
               invoke_id: 1,
               max_segments: 4
             )

    assert {:error, :invalid_range} =
             ReadRange.to_apdu(
               %ReadRange{
                 object_identifier: %ObjectIdentifier{
                   type: :trend_log,
                   instance: 1
                 },
                 property_identifier: :log_buffer,
                 property_array_index: nil,
                 range:
                   {:by_time,
                    {%BACnetDateTime{
                       date: %BACnetDate{
                         year: 1998,
                         month: 3,
                         day: 23,
                         weekday: 1
                       },
                       time: %BACnetTime{
                         hour: 19,
                         minute: 52,
                         second: 34,
                         hundredth: 0
                       }
                     }, -65_535}}
               },
               invoke_id: 1,
               max_segments: 4
             )

    assert {:error, :invalid_range} =
             ReadRange.to_apdu(
               %ReadRange{
                 object_identifier: %ObjectIdentifier{
                   type: :trend_log,
                   instance: 1
                 },
                 property_identifier: :log_buffer,
                 property_array_index: nil,
                 range:
                   {:by_time,
                    {%BACnetDateTime{
                       date: %BACnetDate{
                         year: 1998,
                         month: 3,
                         day: 23,
                         weekday: 1
                       },
                       time: %BACnetTime{
                         hour: 19,
                         minute: 52,
                         second: 34,
                         hundredth: 0
                       }
                     }, 65_535}}
               },
               invoke_id: 1,
               max_segments: 4
             )
  end

  test "protocol implementation get name" do
    assert :read_range ==
             ServicesProtocol.get_name(%ReadRange{
               object_identifier: %ObjectIdentifier{
                 type: :trend_log,
                 instance: 1
               },
               property_identifier: :log_buffer,
               property_array_index: nil,
               range: nil
             })
  end

  test "protocol implementation is confirmed" do
    assert true ==
             ServicesProtocol.is_confirmed(%ReadRange{
               object_identifier: %ObjectIdentifier{
                 type: :trend_log,
                 instance: 1
               },
               property_identifier: :log_buffer,
               property_array_index: nil,
               range: nil
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
              service: :read_range,
              parameters: [
                tagged: {0, <<5, 0, 0, 1>>, 4},
                tagged: {1, <<131>>, 1}
              ]
            }} =
             ServicesProtocol.to_apdu(
               %ReadRange{
                 object_identifier: %ObjectIdentifier{
                   type: :trend_log,
                   instance: 1
                 },
                 property_identifier: :log_buffer,
                 property_array_index: nil,
                 range: nil
               },
               invoke_id: 1,
               max_segments: 4
             )
  end
end
