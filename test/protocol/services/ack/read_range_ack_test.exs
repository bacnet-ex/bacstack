defmodule BACnet.Test.Protocol.Services.ReadRangeAckTest do
  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.APDU.ComplexACK
  alias BACnet.Protocol.APDU.SimpleACK
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.LogRecord
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ResultFlags
  alias BACnet.Protocol.Services.Ack.ReadRangeAck

  use ExUnit.Case, async: true

  @moduletag :apdu
  @moduletag :service
  @moduletag :service_ack

  doctest ReadRangeAck

  test "decoding ReadRangeAck" do
    assert {:ok,
            %ReadRangeAck{
              object_identifier: %ObjectIdentifier{
                type: :trend_log,
                instance: 1
              },
              property_identifier: :log_buffer,
              property_array_index: nil,
              result_flags: %ResultFlags{
                first_item: true,
                last_item: true,
                more_items: false
              },
              item_count: 2,
              item_data: [
                %Encoding{
                  encoding: :constructed,
                  extras: [tag_number: 0],
                  type: nil,
                  value: [
                    date: %BACnetDate{
                      year: 1998,
                      month: 3,
                      day: 23,
                      weekday: 1
                    },
                    time: %BACnetTime{
                      hour: 19,
                      minute: 54,
                      second: 27,
                      hundredth: 0
                    }
                  ]
                },
                %Encoding{
                  encoding: :constructed,
                  extras: [tag_number: 1],
                  type: nil,
                  value: {:tagged, {2, <<65, 144, 0, 0>>, 4}}
                },
                %Encoding{
                  encoding: :tagged,
                  extras: [tag_number: 2],
                  type: nil,
                  value: <<4, 0>>
                },
                %Encoding{
                  encoding: :constructed,
                  extras: [tag_number: 0],
                  type: nil,
                  value: [
                    date: %BACnetDate{
                      year: 1998,
                      month: 3,
                      day: 23,
                      weekday: 1
                    },
                    time: %BACnetTime{
                      hour: 19,
                      minute: 56,
                      second: 27,
                      hundredth: 0
                    }
                  ]
                },
                %Encoding{
                  encoding: :constructed,
                  extras: [tag_number: 1],
                  type: nil,
                  value: {:tagged, {2, <<65, 144, 204, 205>>, 4}}
                },
                %Encoding{
                  encoding: :tagged,
                  extras: [tag_number: 2],
                  type: nil,
                  value: <<4, 0>>
                }
              ],
              first_sequence_number: 79_201
            }} =
             ReadRangeAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               payload: [
                 tagged: {0, <<5, 0, 0, 1>>, 4},
                 tagged: {1, <<131>>, 1},
                 tagged: {3, <<5, 192>>, 2},
                 tagged: {4, <<2>>, 1},
                 constructed:
                   {5,
                    [
                      constructed:
                        {0,
                         [
                           date: %BACnetDate{
                             year: 1998,
                             month: 3,
                             day: 23,
                             weekday: 1
                           },
                           time: %BACnetTime{
                             hour: 19,
                             minute: 54,
                             second: 27,
                             hundredth: 0
                           }
                         ], 0},
                      constructed: {1, {:tagged, {2, <<65, 144, 0, 0>>, 4}}, 0},
                      tagged: {2, <<4, 0>>, 2},
                      constructed:
                        {0,
                         [
                           date: %BACnetDate{
                             year: 1998,
                             month: 3,
                             day: 23,
                             weekday: 1
                           },
                           time: %BACnetTime{
                             hour: 19,
                             minute: 56,
                             second: 27,
                             hundredth: 0
                           }
                         ], 0},
                      constructed: {1, {:tagged, {2, <<65, 144, 204, 205>>, 4}}, 0},
                      tagged: {2, <<4, 0>>, 2}
                    ], 0},
                 tagged: {6, <<1, 53, 97>>, 3}
               ]
             })
  end

  test "decoding ReadRangeAck with array index" do
    assert {:ok,
            %ReadRangeAck{
              object_identifier: %ObjectIdentifier{
                type: :trend_log,
                instance: 1
              },
              property_identifier: :log_buffer,
              property_array_index: 97,
              result_flags: %ResultFlags{
                first_item: true,
                last_item: true,
                more_items: false
              },
              item_count: 0,
              item_data: [],
              first_sequence_number: 79_201
            }} =
             ReadRangeAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               payload: [
                 tagged: {0, <<5, 0, 0, 1>>, 4},
                 tagged: {1, <<131>>, 1},
                 tagged: {2, "a", 1},
                 tagged: {3, <<5, 192>>, 2},
                 tagged: {4, <<0>>, 1},
                 constructed: {5, [], 0},
                 tagged: {6, <<1, 53, 97>>, 3}
               ]
             })
  end

  test "decoding ReadRangeAck invalid missing pattern" do
    assert {:error, :invalid_service_ack} =
             ReadRangeAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               payload: [
                 tagged: {0, <<5, 0, 0, 1>>, 4},
                 tagged: {1, <<131>>, 1},
                 tagged: {3, <<5, 192>>, 2},
                 tagged: {4, <<2>>, 1}
               ]
             })
  end

  test "decoding ReadRangeAck invalid data" do
    assert {:error, :invalid_data} =
             ReadRangeAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               payload: [
                 tagged: {0, <<>>, 4}
               ]
             })
  end

  test "decoding ReadRangeAck invalid wrong ACK" do
    assert {:error, :invalid_service_ack} =
             ReadRangeAck.from_apdu(%SimpleACK{
               invoke_id: 0,
               service: :unconfirmed_service_request
             })
  end

  test "decoding ReadRangeAck invalid first seq number" do
    assert {:error, :invalid_first_sequence_number_value} =
             ReadRangeAck.from_apdu(%ComplexACK{
               invoke_id: 0,
               sequence_number: nil,
               proposed_window_size: nil,
               service: :read_range,
               payload: [
                 tagged: {0, <<5, 0, 0, 1>>, 4},
                 tagged: {1, <<131>>, 1},
                 tagged: {3, <<5, 192>>, 2},
                 tagged: {4, <<2>>, 1},
                 constructed:
                   {5,
                    [
                      constructed:
                        {0,
                         [
                           date: %BACnetDate{
                             year: 1998,
                             month: 3,
                             day: 23,
                             weekday: 1
                           },
                           time: %BACnetTime{
                             hour: 19,
                             minute: 54,
                             second: 27,
                             hundredth: 0
                           }
                         ], 0},
                      constructed: {1, {:tagged, {2, <<65, 144, 0, 0>>, 4}}, 0},
                      tagged: {2, <<4, 0>>, 2},
                      constructed:
                        {0,
                         [
                           date: %BACnetDate{
                             year: 1998,
                             month: 3,
                             day: 23,
                             weekday: 1
                           },
                           time: %BACnetTime{
                             hour: 19,
                             minute: 56,
                             second: 27,
                             hundredth: 0
                           }
                         ], 0},
                      constructed: {1, {:tagged, {2, <<65, 144, 204, 205>>, 4}}, 0},
                      tagged: {2, <<4, 0>>, 2}
                    ], 0},
                 tagged: {6, <<1, 53, 97, 255, 255, 255>>, 6}
               ]
             })
  end

  test "encoding ReadRangeAck" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 55,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :read_range,
              payload: [
                tagged: {0, <<5, 0, 0, 1>>, 4},
                tagged: {1, <<131>>, 1},
                tagged: {3, <<5, 192>>, 2},
                tagged: {4, <<2>>, 1},
                constructed:
                  {5,
                   [
                     constructed:
                       {0,
                        [
                          date: %BACnetDate{
                            year: 1998,
                            month: 3,
                            day: 23,
                            weekday: 1
                          },
                          time: %BACnetTime{
                            hour: 19,
                            minute: 54,
                            second: 27,
                            hundredth: 0
                          }
                        ], 0},
                     constructed: {1, {:tagged, {2, <<65, 144, 0, 0>>, 4}}, 0},
                     tagged: {2, <<4, 0>>, 2},
                     constructed:
                       {0,
                        [
                          date: %BACnetDate{
                            year: 1998,
                            month: 3,
                            day: 23,
                            weekday: 1
                          },
                          time: %BACnetTime{
                            hour: 19,
                            minute: 56,
                            second: 27,
                            hundredth: 0
                          }
                        ], 0},
                     constructed: {1, {:tagged, {2, <<65, 144, 204, 205>>, 4}}, 0},
                     tagged: {2, <<4, 0>>, 2}
                   ], 0},
                tagged: {6, <<1, 53, 97>>, 3}
              ]
            }} =
             ReadRangeAck.to_apdu(
               %ReadRangeAck{
                 object_identifier: %ObjectIdentifier{
                   type: :trend_log,
                   instance: 1
                 },
                 property_identifier: :log_buffer,
                 property_array_index: nil,
                 result_flags: %ResultFlags{
                   first_item: true,
                   last_item: true,
                   more_items: false
                 },
                 item_count: 2,
                 item_data: [
                   %Encoding{
                     encoding: :constructed,
                     extras: [tag_number: 0],
                     type: nil,
                     value: [
                       date: %BACnetDate{
                         year: 1998,
                         month: 3,
                         day: 23,
                         weekday: 1
                       },
                       time: %BACnetTime{
                         hour: 19,
                         minute: 54,
                         second: 27,
                         hundredth: 0
                       }
                     ]
                   },
                   %Encoding{
                     encoding: :constructed,
                     extras: [tag_number: 1],
                     type: nil,
                     value: {:tagged, {2, <<65, 144, 0, 0>>, 4}}
                   },
                   %Encoding{
                     encoding: :tagged,
                     extras: [tag_number: 2],
                     type: nil,
                     value: <<4, 0>>
                   },
                   %Encoding{
                     encoding: :constructed,
                     extras: [tag_number: 0],
                     type: nil,
                     value: [
                       date: %BACnetDate{
                         year: 1998,
                         month: 3,
                         day: 23,
                         weekday: 1
                       },
                       time: %BACnetTime{
                         hour: 19,
                         minute: 56,
                         second: 27,
                         hundredth: 0
                       }
                     ]
                   },
                   %Encoding{
                     encoding: :constructed,
                     extras: [tag_number: 1],
                     type: nil,
                     value: {:tagged, {2, <<65, 144, 204, 205>>, 4}}
                   },
                   %Encoding{
                     encoding: :tagged,
                     extras: [tag_number: 2],
                     type: nil,
                     value: <<4, 0>>
                   }
                 ],
                 first_sequence_number: 79_201
               },
               55
             )
  end

  test "encoding ReadRangeAck with array index" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 55,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :read_range,
              payload: [
                tagged: {0, <<5, 0, 0, 1>>, 4},
                tagged: {1, <<131>>, 1},
                tagged: {2, "a", 1},
                tagged: {3, <<5, 192>>, 2},
                tagged: {4, <<0>>, 1},
                constructed: {5, [], 0},
                tagged: {6, <<1, 53, 97>>, 3}
              ]
            }} =
             ReadRangeAck.to_apdu(
               %ReadRangeAck{
                 object_identifier: %ObjectIdentifier{
                   type: :trend_log,
                   instance: 1
                 },
                 property_identifier: :log_buffer,
                 property_array_index: 97,
                 result_flags: %ResultFlags{
                   first_item: true,
                   last_item: true,
                   more_items: false
                 },
                 item_count: 0,
                 item_data: [],
                 first_sequence_number: 79_201
               },
               55
             )
  end

  test "encoding ReadRangeAck with optional invoke_id" do
    assert {:ok,
            %ComplexACK{
              invoke_id: 0,
              sequence_number: nil,
              proposed_window_size: nil,
              service: :read_range,
              payload: [
                tagged: {0, <<5, 0, 0, 1>>, 4},
                tagged: {1, <<131>>, 1},
                tagged: {3, <<5, 192>>, 2},
                tagged: {4, <<2>>, 1},
                constructed:
                  {5,
                   [
                     constructed:
                       {0,
                        [
                          date: %BACnetDate{
                            year: 1998,
                            month: 3,
                            day: 23,
                            weekday: 1
                          },
                          time: %BACnetTime{
                            hour: 19,
                            minute: 54,
                            second: 27,
                            hundredth: 0
                          }
                        ], 0},
                     constructed: {1, {:tagged, {2, <<65, 144, 0, 0>>, 4}}, 0},
                     tagged: {2, <<4, 0>>, 2},
                     constructed:
                       {0,
                        [
                          date: %BACnetDate{
                            year: 1998,
                            month: 3,
                            day: 23,
                            weekday: 1
                          },
                          time: %BACnetTime{
                            hour: 19,
                            minute: 56,
                            second: 27,
                            hundredth: 0
                          }
                        ], 0},
                     constructed: {1, {:tagged, {2, <<65, 144, 204, 205>>, 4}}, 0},
                     tagged: {2, <<4, 0>>, 2}
                   ], 0},
                tagged: {6, <<1, 53, 97>>, 3}
              ]
            }} =
             ReadRangeAck.to_apdu(%ReadRangeAck{
               object_identifier: %ObjectIdentifier{
                 type: :trend_log,
                 instance: 1
               },
               property_identifier: :log_buffer,
               property_array_index: nil,
               result_flags: %ResultFlags{
                 first_item: true,
                 last_item: true,
                 more_items: false
               },
               item_count: 2,
               item_data: [
                 %Encoding{
                   encoding: :constructed,
                   extras: [tag_number: 0],
                   type: nil,
                   value: [
                     date: %BACnetDate{
                       year: 1998,
                       month: 3,
                       day: 23,
                       weekday: 1
                     },
                     time: %BACnetTime{
                       hour: 19,
                       minute: 54,
                       second: 27,
                       hundredth: 0
                     }
                   ]
                 },
                 %Encoding{
                   encoding: :constructed,
                   extras: [tag_number: 1],
                   type: nil,
                   value: {:tagged, {2, <<65, 144, 0, 0>>, 4}}
                 },
                 %Encoding{
                   encoding: :tagged,
                   extras: [tag_number: 2],
                   type: nil,
                   value: <<4, 0>>
                 },
                 %Encoding{
                   encoding: :constructed,
                   extras: [tag_number: 0],
                   type: nil,
                   value: [
                     date: %BACnetDate{
                       year: 1998,
                       month: 3,
                       day: 23,
                       weekday: 1
                     },
                     time: %BACnetTime{
                       hour: 19,
                       minute: 56,
                       second: 27,
                       hundredth: 0
                     }
                   ]
                 },
                 %Encoding{
                   encoding: :constructed,
                   extras: [tag_number: 1],
                   type: nil,
                   value: {:tagged, {2, <<65, 144, 204, 205>>, 4}}
                 },
                 %Encoding{
                   encoding: :tagged,
                   extras: [tag_number: 2],
                   type: nil,
                   value: <<4, 0>>
                 }
               ],
               first_sequence_number: 79_201
             })
  end

  test "encoding ReadRangeAck invalid encoding struct" do
    assert {:error, :invalid_value} =
             ReadRangeAck.to_apdu(%ReadRangeAck{
               object_identifier: %ObjectIdentifier{
                 type: :trend_log,
                 instance: 1
               },
               property_identifier: :log_buffer,
               property_array_index: nil,
               result_flags: %ResultFlags{
                 first_item: true,
                 last_item: true,
                 more_items: false
               },
               item_count: 2,
               item_data: [
                 %Encoding{
                   encoding: :hello_there,
                   extras: [tag_number: 1],
                   type: nil,
                   value: {:tagged, {2, <<65, 144, 0, 0>>, 4}}
                 }
               ],
               first_sequence_number: 79_201
             })
  end

  test "encoding ReadRangeAck invalid invoke_id" do
    assert {:error, :invalid_parameter} =
             ReadRangeAck.to_apdu(
               %ReadRangeAck{
                 object_identifier: %ObjectIdentifier{
                   type: :trend_log,
                   instance: 1
                 },
                 property_identifier: :log_buffer,
                 property_array_index: nil,
                 result_flags: %ResultFlags{
                   first_item: true,
                   last_item: true,
                   more_items: false
                 },
                 item_count: 1,
                 item_data: [
                   %Encoding{
                     encoding: :tagged,
                     extras: [tag_number: 2],
                     type: nil,
                     value: <<4, 0>>
                   }
                 ],
                 first_sequence_number: 79_201
               },
               256
             )
  end

  test "encoding ReadRangeAck invalid first seq number" do
    assert {:error, :invalid_first_sequence_number_value} =
             ReadRangeAck.to_apdu(
               %ReadRangeAck{
                 object_identifier: %ObjectIdentifier{
                   type: :trend_log,
                   instance: 1
                 },
                 property_identifier: :log_buffer,
                 property_array_index: nil,
                 result_flags: %ResultFlags{
                   first_item: true,
                   last_item: true,
                   more_items: false
                 },
                 item_count: 0,
                 item_data: [],
                 first_sequence_number: 79_201_214_421_124
               },
               55
             )
  end

  test "ReadRangeAck with 0 primitive items survives a wire round trip" do
    items = []

    ack = %ReadRangeAck{
      object_identifier: %ObjectIdentifier{type: :trend_log, instance: 1},
      property_identifier: :log_buffer,
      property_array_index: nil,
      result_flags: %ResultFlags{first_item: true, last_item: true, more_items: false},
      item_count: 0,
      item_data: items,
      first_sequence_number: nil
    }

    assert {:ok, apdu} = ReadRangeAck.to_apdu(ack, 42)
    assert {:ok, bytes} = APDU.ComplexACK.encode(apdu)
    assert {:ok, decoded} = APDU.decode(IO.iodata_to_binary(bytes))
    assert {:ok, ^ack} = ReadRangeAck.from_apdu(decoded)
  end

  test "ReadRangeAck with 1 primitive item survives a wire round trip" do
    items = [Encoding.create!({:unsigned_integer, 7})]

    ack = %ReadRangeAck{
      object_identifier: %ObjectIdentifier{type: :trend_log, instance: 1},
      property_identifier: :log_buffer,
      property_array_index: nil,
      result_flags: %ResultFlags{first_item: true, last_item: true, more_items: false},
      item_count: 1,
      item_data: items,
      first_sequence_number: nil
    }

    assert {:ok, apdu} = ReadRangeAck.to_apdu(ack, 42)
    assert {:ok, bytes} = APDU.ComplexACK.encode(apdu)
    assert {:ok, decoded} = APDU.decode(IO.iodata_to_binary(bytes))
    assert {:ok, ^ack} = ReadRangeAck.from_apdu(decoded)
  end

  test "ReadRangeAck with 2 primitive items survives a wire round trip" do
    items = [Encoding.create!({:unsigned_integer, 7}), Encoding.create!({:unsigned_integer, 8})]

    ack = %ReadRangeAck{
      object_identifier: %ObjectIdentifier{type: :trend_log, instance: 1},
      property_identifier: :log_buffer,
      property_array_index: nil,
      result_flags: %ResultFlags{first_item: true, last_item: true, more_items: false},
      item_count: 2,
      item_data: items,
      first_sequence_number: nil
    }

    assert {:ok, apdu} = ReadRangeAck.to_apdu(ack, 42)
    assert {:ok, bytes} = APDU.ComplexACK.encode(apdu)
    assert {:ok, decoded} = APDU.decode(IO.iodata_to_binary(bytes))
    assert {:ok, ^ack} = ReadRangeAck.from_apdu(decoded)
  end

  test "ReadRangeAck with one log record survives a wire round trip" do
    record = %LogRecord{
      timestamp: BACnetDateTime.from_datetime(~U[2026-01-01 12:34:56Z]),
      log_datum: Encoding.create!({:unsigned_integer, 7}),
      status_flags: nil
    }

    assert {:ok, tags} = LogRecord.encode(record)

    ack = %ReadRangeAck{
      object_identifier: %ObjectIdentifier{type: :trend_log, instance: 1},
      property_identifier: :log_buffer,
      property_array_index: nil,
      result_flags: %ResultFlags{first_item: true, last_item: true, more_items: false},
      item_count: 1,
      item_data: Enum.map(tags, &Encoding.create!/1),
      first_sequence_number: 101
    }

    assert {:ok, apdu} = ReadRangeAck.to_apdu(ack, 42)
    assert {:ok, bytes} = APDU.ComplexACK.encode(apdu)
    assert {:ok, decoded} = APDU.decode(IO.iodata_to_binary(bytes))
    assert {:ok, decoded_ack} = ReadRangeAck.from_apdu(decoded)
    assert decoded_ack == ack
    decoded_tags = Enum.map(decoded_ack.item_data, &Encoding.to_encoding!/1)
    assert {:ok, {decoded_record, []}} = LogRecord.parse(decoded_tags)
    assert decoded_record.timestamp == record.timestamp
    assert decoded_record.status_flags == nil
    assert %Encoding{type: :unsigned_integer, value: 7} = decoded_record.log_datum
  end
end
