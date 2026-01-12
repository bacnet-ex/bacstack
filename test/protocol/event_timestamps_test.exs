defmodule BACnet.Protocol.EventTimestampsTest do
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.BACnetTimestamp
  alias BACnet.Protocol.EventTimestamps

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest EventTimestamps

  test "decode timestamps" do
    assert {:ok,
            {%EventTimestamps{
               to_offnormal: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: %BACnetDateTime{}
               },
               to_fault: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: %BACnetDateTime{}
               },
               to_normal: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: %BACnetDateTime{}
               }
             }, []}} =
             EventTimestamps.parse(
               constructed:
                 {2,
                  [
                    date: %BACnetDate{
                      year: :unspecified,
                      month: :unspecified,
                      day: :unspecified,
                      weekday: :unspecified
                    },
                    time: %BACnetTime{
                      hour: :unspecified,
                      minute: :unspecified,
                      second: :unspecified,
                      hundredth: :unspecified
                    }
                  ], 0},
               constructed:
                 {2,
                  [
                    date: %BACnetDate{
                      year: :unspecified,
                      month: :unspecified,
                      day: :unspecified,
                      weekday: :unspecified
                    },
                    time: %BACnetTime{
                      hour: :unspecified,
                      minute: :unspecified,
                      second: :unspecified,
                      hundredth: :unspecified
                    }
                  ], 0},
               constructed:
                 {2,
                  [
                    date: %BACnetDate{
                      year: :unspecified,
                      month: :unspecified,
                      day: :unspecified,
                      weekday: :unspecified
                    },
                    time: %BACnetTime{
                      hour: :unspecified,
                      minute: :unspecified,
                      second: :unspecified,
                      hundredth: :unspecified
                    }
                  ], 0}
             )
  end

  test "decode invalid timestamps missing pattern" do
    assert {:error, :invalid_tags} =
             EventTimestamps.parse(
               constructed:
                 {2,
                  [
                    date: %BACnetDate{
                      year: :unspecified,
                      month: :unspecified,
                      day: :unspecified,
                      weekday: :unspecified
                    },
                    time: %BACnetTime{
                      hour: :unspecified,
                      minute: :unspecified,
                      second: :unspecified,
                      hundredth: :unspecified
                    }
                  ], 0}
             )
  end

  test "decode invalid timestamps invalid timestamp" do
    assert {:error, :invalid_tags} =
             EventTimestamps.parse(
               constructed: {3, [], 0},
               constructed: {3, [], 0},
               constructed: {3, [], 0}
             )
  end

  test "encode timestamps" do
    assert {:ok,
            [
              constructed:
                {2,
                 [
                   date: %BACnetDate{},
                   time: %BACnetTime{}
                 ], 0},
              constructed:
                {2,
                 [
                   date: %BACnetDate{},
                   time: %BACnetTime{}
                 ], 0},
              constructed:
                {2,
                 [
                   date: %BACnetDate{},
                   time: %BACnetTime{}
                 ], 0}
            ]} =
             EventTimestamps.encode(%EventTimestamps{
               to_offnormal: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: %BACnetDateTime{
                   date: %BACnetDate{
                     year: :unspecified,
                     month: :unspecified,
                     day: :unspecified,
                     weekday: :unspecified
                   },
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   }
                 }
               },
               to_fault: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: %BACnetDateTime{
                   date: %BACnetDate{
                     year: :unspecified,
                     month: :unspecified,
                     day: :unspecified,
                     weekday: :unspecified
                   },
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   }
                 }
               },
               to_normal: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: %BACnetDateTime{
                   date: %BACnetDate{
                     year: :unspecified,
                     month: :unspecified,
                     day: :unspecified,
                     weekday: :unspecified
                   },
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   }
                 }
               }
             })
  end

  test "encode invalid timestamps" do
    assert {:error, :invalid_value} =
             EventTimestamps.encode(%EventTimestamps{
               to_offnormal: %BACnetTimestamp{
                 type: :sequence_number,
                 time: nil,
                 sequence_number: 5.0,
                 datetime: nil
               },
               to_fault: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: %BACnetDateTime{
                   date: %BACnetDate{
                     year: :unspecified,
                     month: :unspecified,
                     day: :unspecified,
                     weekday: :unspecified
                   },
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   }
                 }
               },
               to_normal: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: %BACnetDateTime{
                   date: %BACnetDate{
                     year: :unspecified,
                     month: :unspecified,
                     day: :unspecified,
                     weekday: :unspecified
                   },
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   }
                 }
               }
             })
  end

  test "valid timestamps" do
    assert true ==
             EventTimestamps.valid?(%EventTimestamps{
               to_offnormal: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: %BACnetDateTime{
                   date: %BACnetDate{
                     year: :unspecified,
                     month: :unspecified,
                     day: :unspecified,
                     weekday: :unspecified
                   },
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   }
                 }
               },
               to_fault: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: %BACnetDateTime{
                   date: %BACnetDate{
                     year: :unspecified,
                     month: :unspecified,
                     day: :unspecified,
                     weekday: :unspecified
                   },
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   }
                 }
               },
               to_normal: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: %BACnetDateTime{
                   date: %BACnetDate{
                     year: :unspecified,
                     month: :unspecified,
                     day: :unspecified,
                     weekday: :unspecified
                   },
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   }
                 }
               }
             })
  end

  test "invalid timestamps" do
    assert false ==
             EventTimestamps.valid?(%EventTimestamps{
               to_offnormal: :hello,
               to_fault: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: %BACnetDateTime{
                   date: %BACnetDate{
                     year: :unspecified,
                     month: :unspecified,
                     day: :unspecified,
                     weekday: :unspecified
                   },
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   }
                 }
               },
               to_normal: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: %BACnetDateTime{
                   date: %BACnetDate{
                     year: :unspecified,
                     month: :unspecified,
                     day: :unspecified,
                     weekday: :unspecified
                   },
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   }
                 }
               }
             })

    assert false ==
             EventTimestamps.valid?(%EventTimestamps{
               to_offnormal: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: :hello
               },
               to_fault: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: %BACnetDateTime{
                   date: %BACnetDate{
                     year: :unspecified,
                     month: :unspecified,
                     day: :unspecified,
                     weekday: :unspecified
                   },
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   }
                 }
               },
               to_normal: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: %BACnetDateTime{
                   date: %BACnetDate{
                     year: :unspecified,
                     month: :unspecified,
                     day: :unspecified,
                     weekday: :unspecified
                   },
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   }
                 }
               }
             })

    assert false ==
             EventTimestamps.valid?(%EventTimestamps{
               to_offnormal: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: %BACnetDateTime{
                   date: %BACnetDate{
                     year: :unspecified,
                     month: :unspecified,
                     day: :unspecified,
                     weekday: :unspecified
                   },
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   }
                 }
               },
               to_fault: :hello,
               to_normal: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: %BACnetDateTime{
                   date: %BACnetDate{
                     year: :unspecified,
                     month: :unspecified,
                     day: :unspecified,
                     weekday: :unspecified
                   },
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   }
                 }
               }
             })

    assert false ==
             EventTimestamps.valid?(%EventTimestamps{
               to_offnormal: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: %BACnetDateTime{
                   date: %BACnetDate{
                     year: :unspecified,
                     month: :unspecified,
                     day: :unspecified,
                     weekday: :unspecified
                   },
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   }
                 }
               },
               to_fault: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: :hello
               },
               to_normal: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: %BACnetDateTime{
                   date: %BACnetDate{
                     year: :unspecified,
                     month: :unspecified,
                     day: :unspecified,
                     weekday: :unspecified
                   },
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   }
                 }
               }
             })

    assert false ==
             EventTimestamps.valid?(%EventTimestamps{
               to_offnormal: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: %BACnetDateTime{
                   date: %BACnetDate{
                     year: :unspecified,
                     month: :unspecified,
                     day: :unspecified,
                     weekday: :unspecified
                   },
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   }
                 }
               },
               to_fault: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: %BACnetDateTime{
                   date: %BACnetDate{
                     year: :unspecified,
                     month: :unspecified,
                     day: :unspecified,
                     weekday: :unspecified
                   },
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   }
                 }
               },
               to_normal: :hello
             })

    assert false ==
             EventTimestamps.valid?(%EventTimestamps{
               to_offnormal: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: %BACnetDateTime{
                   date: %BACnetDate{
                     year: :unspecified,
                     month: :unspecified,
                     day: :unspecified,
                     weekday: :unspecified
                   },
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   }
                 }
               },
               to_fault: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: %BACnetDateTime{
                   date: %BACnetDate{
                     year: :unspecified,
                     month: :unspecified,
                     day: :unspecified,
                     weekday: :unspecified
                   },
                   time: %BACnetTime{
                     hour: :unspecified,
                     minute: :unspecified,
                     second: :unspecified,
                     hundredth: :unspecified
                   }
                 }
               },
               to_normal: %BACnetTimestamp{
                 type: :datetime,
                 time: nil,
                 sequence_number: nil,
                 datetime: :hello
               }
             })
  end
end
