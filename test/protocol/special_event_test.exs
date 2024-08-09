defmodule BACnet.Protocol.SpecialEventTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.CalendarEntry
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.SpecialEvent
  alias BACnet.Protocol.TimeValue

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest SpecialEvent

  test "decode special event calendar entry empty" do
    assert {:ok,
            {%SpecialEvent{
               period: %CalendarEntry{
                 type: :date,
                 date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 11,
                   weekday: 4
                 }
               },
               list: [],
               priority: 16
             },
             []}} =
             SpecialEvent.parse(
               constructed: {0, {:tagged, {0, <<123, 5, 11, 4>>, 4}}, 0},
               constructed: {2, [], 0},
               tagged: {3, <<16>>, 1}
             )
  end

  test "decode special event calendar ref empty" do
    assert {:ok,
            {%SpecialEvent{
               period: %ObjectIdentifier{
                 type: :calendar,
                 instance: 0
               },
               list: [],
               priority: 1
             },
             []}} =
             SpecialEvent.parse(
               tagged: {1, <<1, 128, 0, 0>>, 4},
               constructed: {2, [], 0},
               tagged: {3, <<1>>, 1}
             )
  end

  test "decode special event calendar entry" do
    assert {:ok,
            {%SpecialEvent{
               period: %CalendarEntry{
                 type: :date,
                 date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 11,
                   weekday: 4
                 }
               },
               list: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 0,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :null,
                     value: nil
                   }
                 }
               ],
               priority: 16
             },
             []}} =
             SpecialEvent.parse(
               constructed: {0, {:tagged, {0, <<123, 5, 11, 4>>, 4}}, 0},
               constructed:
                 {2,
                  [
                    time: %BACnetTime{
                      hour: 0,
                      minute: 0,
                      second: 0,
                      hundredth: 0
                    },
                    null: nil
                  ], 0},
               tagged: {3, <<16>>, 1}
             )
  end

  test "decode special event calendar ref" do
    assert {:ok,
            {%SpecialEvent{
               period: %ObjectIdentifier{
                 type: :calendar,
                 instance: 0
               },
               list: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 2,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 0
                   }
                 }
               ],
               priority: 1
             },
             []}} =
             SpecialEvent.parse(
               tagged: {1, <<1, 128, 0, 0>>, 4},
               constructed:
                 {2,
                  [
                    time: %BACnetTime{
                      hour: 2,
                      minute: 0,
                      second: 0,
                      hundredth: 0
                    },
                    enumerated: 0
                  ], 0},
               tagged: {3, <<1>>, 1}
             )
  end

  test "decode special event calendar multiple time values" do
    assert {:ok,
            {%SpecialEvent{
               period: %ObjectIdentifier{
                 type: :calendar,
                 instance: 0
               },
               list: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 2,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 0
                   }
                 },
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 6,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 1
                   }
                 },
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 18,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 2
                   }
                 },
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 22,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 0
                   }
                 }
               ],
               priority: 1
             },
             []}} =
             SpecialEvent.parse(
               tagged: {1, <<1, 128, 0, 0>>, 4},
               constructed:
                 {2,
                  [
                    time: %BACnetTime{
                      hour: 2,
                      minute: 0,
                      second: 0,
                      hundredth: 0
                    },
                    enumerated: 0,
                    time: %BACnetTime{
                      hour: 6,
                      minute: 0,
                      second: 0,
                      hundredth: 0
                    },
                    enumerated: 1,
                    time: %BACnetTime{
                      hour: 18,
                      minute: 0,
                      second: 0,
                      hundredth: 0
                    },
                    enumerated: 2,
                    time: %BACnetTime{
                      hour: 22,
                      minute: 0,
                      second: 0,
                      hundredth: 0
                    },
                    enumerated: 0
                  ], 0},
               tagged: {3, <<1>>, 1}
             )
  end

  test "decode special event invalid missing priority" do
    assert {:error, :invalid_tags} =
             SpecialEvent.parse(
               constructed: {0, {:tagged, {0, <<123, 5, 11, 4>>, 4}}, 0},
               constructed: {2, [], 0}
             )
  end

  test "decode special event invalid missing period" do
    assert {:error, :invalid_tags} = SpecialEvent.parse(constructed: {2, [], 0})
  end

  test "decode special event invalid time value" do
    assert {:error, :invalid_tags} =
             SpecialEvent.parse(
               tagged: {1, <<1, 128, 0, 0>>, 4},
               constructed:
                 {2,
                  [
                    time: %BACnetTime{
                      hour: 2,
                      minute: 0,
                      second: 0,
                      hundredth: 0
                    },
                    enumerated: 0,
                    time: %BACnetTime{
                      hour: 6,
                      minute: 0,
                      second: 0,
                      hundredth: 0
                    }
                  ], 0},
               tagged: {3, <<1>>, 1}
             )
  end

  test "encode special event calendar entry empty" do
    assert {:ok,
            [
              constructed: {0, {:tagged, {0, <<123, 5, 11, 4>>, 4}}, 0},
              constructed: {2, [], 0},
              tagged: {3, <<16>>, 1}
            ]} =
             SpecialEvent.encode(%SpecialEvent{
               period: %CalendarEntry{
                 type: :date,
                 date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 11,
                   weekday: 4
                 },
                 date_range: nil,
                 week_n_day: nil
               },
               list: [],
               priority: 16
             })
  end

  test "encode special event calendar ref empty" do
    assert {:ok,
            [
              tagged: {1, <<1, 128, 0, 0>>, 4},
              constructed: {2, [], 0},
              tagged: {3, <<1>>, 1}
            ]} =
             SpecialEvent.encode(%SpecialEvent{
               period: %ObjectIdentifier{
                 type: :calendar,
                 instance: 0
               },
               list: [],
               priority: 1
             })
  end

  test "encode special event calendar entry" do
    assert {:ok,
            [
              constructed: {0, {:tagged, {0, <<123, 5, 11, 4>>, 4}}, 0},
              constructed:
                {2,
                 [
                   time: %BACnetTime{
                     hour: 0,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   null: nil
                 ], 0},
              tagged: {3, <<16>>, 1}
            ]} =
             SpecialEvent.encode(%SpecialEvent{
               period: %CalendarEntry{
                 type: :date,
                 date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 11,
                   weekday: 4
                 },
                 date_range: nil,
                 week_n_day: nil
               },
               list: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 0,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :null,
                     value: nil
                   }
                 }
               ],
               priority: 16
             })
  end

  test "encode special event calendar ref" do
    assert {:ok,
            [
              tagged: {1, <<1, 128, 0, 0>>, 4},
              constructed:
                {2,
                 [
                   time: %BACnetTime{
                     hour: 2,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   enumerated: 0
                 ], 0},
              tagged: {3, <<1>>, 1}
            ]} =
             SpecialEvent.encode(%SpecialEvent{
               period: %ObjectIdentifier{
                 type: :calendar,
                 instance: 0
               },
               list: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 2,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 0
                   }
                 }
               ],
               priority: 1
             })
  end

  test "encode special event calendar multiple time values" do
    assert {:ok,
            [
              tagged: {1, <<1, 128, 0, 0>>, 4},
              constructed:
                {2,
                 [
                   time: %BACnetTime{
                     hour: 2,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   enumerated: 0,
                   time: %BACnetTime{
                     hour: 6,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   enumerated: 1,
                   time: %BACnetTime{
                     hour: 18,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   enumerated: 2,
                   time: %BACnetTime{
                     hour: 22,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   enumerated: 0
                 ], 0},
              tagged: {3, <<1>>, 1}
            ]} =
             SpecialEvent.encode(%SpecialEvent{
               period: %ObjectIdentifier{
                 type: :calendar,
                 instance: 0
               },
               list: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 2,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 0
                   }
                 },
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 6,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 1
                   }
                 },
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 18,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 2
                   }
                 },
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 22,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 0
                   }
                 }
               ],
               priority: 1
             })
  end

  test "encode special event invalid period" do
    assert {:error, :invalid_period} =
             SpecialEvent.encode(%SpecialEvent{
               period: :hello_there,
               list: [],
               priority: 1
             })
  end

  test "encode special event invalid time value" do
    assert {:error, :invalid_time_value} =
             SpecialEvent.encode(%SpecialEvent{
               period: %ObjectIdentifier{
                 type: :calendar,
                 instance: 0
               },
               list: [
                 :hello_there
               ],
               priority: 1
             })
  end

  test "encode special event invalid time value 2" do
    assert {:error, :invalid_time_value} =
             SpecialEvent.encode(%SpecialEvent{
               period: %ObjectIdentifier{
                 type: :calendar,
                 instance: 0
               },
               list: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 2,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 0
                   }
                 },
                 :hello_there
               ],
               priority: 1
             })
  end

  test "encode special event invalid time value error" do
    assert {:error, :invalid_value} =
             SpecialEvent.encode(%SpecialEvent{
               period: %ObjectIdentifier{
                 type: :calendar,
                 instance: 0
               },
               list: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 2,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :hello_there,
                     extras: [],
                     type: :enumerated,
                     value: 0
                   }
                 }
               ],
               priority: 1
             })
  end

  test "encode special event invalid priority" do
    assert {:error, :invalid_value} =
             SpecialEvent.encode(%SpecialEvent{
               period: %ObjectIdentifier{
                 type: :calendar,
                 instance: 0
               },
               list: [],
               priority: :hello_there
             })
  end

  test "valid special event" do
    assert true ==
             SpecialEvent.valid?(%SpecialEvent{
               period: %CalendarEntry{
                 type: :date,
                 date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 11,
                   weekday: 4
                 },
                 date_range: nil,
                 week_n_day: nil
               },
               list: [],
               priority: 16
             })

    assert true ==
             SpecialEvent.valid?(%SpecialEvent{
               period: %ObjectIdentifier{
                 type: :calendar,
                 instance: 0
               },
               list: [],
               priority: 1
             })

    assert true ==
             SpecialEvent.valid?(%SpecialEvent{
               period: %CalendarEntry{
                 type: :date,
                 date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 11,
                   weekday: 4
                 },
                 date_range: nil,
                 week_n_day: nil
               },
               list: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 2,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 0
                   }
                 },
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 6,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 1
                   }
                 },
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 18,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 2
                   }
                 },
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 22,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 0
                   }
                 }
               ],
               priority: 15
             })

    assert true ==
             SpecialEvent.valid?(%SpecialEvent{
               period: %ObjectIdentifier{
                 type: :calendar,
                 instance: 0
               },
               list: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 2,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 0
                   }
                 },
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 6,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 1
                   }
                 },
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 18,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 2
                   }
                 },
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 22,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 0
                   }
                 }
               ],
               priority: 2
             })
  end

  test "invalid special event calendar entry" do
    assert false ==
             SpecialEvent.valid?(%SpecialEvent{
               period: :hello_there,
               list: [],
               priority: 16
             })

    assert false ==
             SpecialEvent.valid?(%SpecialEvent{
               period: %CalendarEntry{
                 type: :date,
                 date: nil,
                 date_range: nil,
                 week_n_day: nil
               },
               list: [],
               priority: 16
             })

    assert false ==
             SpecialEvent.valid?(%SpecialEvent{
               period: %CalendarEntry{
                 type: :date,
                 date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 11,
                   weekday: 4
                 },
                 date_range: nil,
                 week_n_day: nil
               },
               list: :hello_there,
               priority: 16
             })

    assert false ==
             SpecialEvent.valid?(%SpecialEvent{
               period: %CalendarEntry{
                 type: :date,
                 date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 11,
                   weekday: 4
                 },
                 date_range: nil,
                 week_n_day: nil
               },
               list: [:hello_there],
               priority: 16
             })

    assert false ==
             SpecialEvent.valid?(%SpecialEvent{
               period: %CalendarEntry{
                 type: :date,
                 date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 11,
                   weekday: 4
                 },
                 date_range: nil,
                 week_n_day: nil
               },
               list: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 22,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: :hello_there
                 }
               ],
               priority: 16
             })

    assert false ==
             SpecialEvent.valid?(%SpecialEvent{
               period: %CalendarEntry{
                 type: :date,
                 date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 11,
                   weekday: 4
                 },
                 date_range: nil,
                 week_n_day: nil
               },
               list: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 22,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 0
                   }
                 },
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 22,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: :hello_there
                 }
               ],
               priority: 16
             })

    assert false ==
             SpecialEvent.valid?(%SpecialEvent{
               period: %CalendarEntry{
                 type: :date,
                 date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 11,
                   weekday: 4
                 },
                 date_range: nil,
                 week_n_day: nil
               },
               list: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 22,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 0
                   }
                 },
                 :hello_there
               ],
               priority: 16
             })

    assert false ==
             SpecialEvent.valid?(%SpecialEvent{
               period: %CalendarEntry{
                 type: :date,
                 date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 11,
                   weekday: 4
                 },
                 date_range: nil,
                 week_n_day: nil
               },
               list: [],
               priority: 0
             })

    assert false ==
             SpecialEvent.valid?(%SpecialEvent{
               period: %CalendarEntry{
                 type: :date,
                 date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 11,
                   weekday: 4
                 },
                 date_range: nil,
                 week_n_day: nil
               },
               list: [],
               priority: 17
             })

    assert false ==
             SpecialEvent.valid?(%SpecialEvent{
               period: %CalendarEntry{
                 type: :date,
                 date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 11,
                   weekday: 4
                 },
                 date_range: nil,
                 week_n_day: nil
               },
               list: [],
               priority: -1
             })
  end

  test "invalid special event calendar ref" do
    assert false ==
             SpecialEvent.valid?(%SpecialEvent{
               period: %ObjectIdentifier{
                 type: :hello_there,
                 instance: 0
               },
               list: [],
               priority: 1
             })

    assert false ==
             SpecialEvent.valid?(%SpecialEvent{
               period: %ObjectIdentifier{
                 type: :calendar,
                 instance: 0
               },
               list: :hello_there,
               priority: 16
             })

    assert false ==
             SpecialEvent.valid?(%SpecialEvent{
               period: %ObjectIdentifier{
                 type: :calendar,
                 instance: 0
               },
               list: [:hello_there],
               priority: 16
             })

    assert false ==
             SpecialEvent.valid?(%SpecialEvent{
               period: %ObjectIdentifier{
                 type: :calendar,
                 instance: 0
               },
               list: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 22,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: :hello_there
                 }
               ],
               priority: 16
             })

    assert false ==
             SpecialEvent.valid?(%SpecialEvent{
               period: %ObjectIdentifier{
                 type: :calendar,
                 instance: 0
               },
               list: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 22,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 0
                   }
                 },
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 22,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: :hello_there
                 }
               ],
               priority: 16
             })

    assert false ==
             SpecialEvent.valid?(%SpecialEvent{
               period: %ObjectIdentifier{
                 type: :calendar,
                 instance: 0
               },
               list: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 22,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 0
                   }
                 },
                 :hello_there
               ],
               priority: 16
             })

    assert false ==
             SpecialEvent.valid?(%SpecialEvent{
               period: %ObjectIdentifier{
                 type: :calendar,
                 instance: 0
               },
               list: [],
               priority: 0
             })

    assert false ==
             SpecialEvent.valid?(%SpecialEvent{
               period: %ObjectIdentifier{
                 type: :calendar,
                 instance: 0
               },
               list: [],
               priority: 17
             })

    assert false ==
             SpecialEvent.valid?(%SpecialEvent{
               period: %ObjectIdentifier{
                 type: :calendar,
                 instance: 0
               },
               list: [],
               priority: -1
             })
  end
end
