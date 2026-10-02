defmodule BACnet.Protocol.DailyScheduleTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.DailySchedule
  alias BACnet.Protocol.TimeValue

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest DailySchedule

  test "decode daily schedule" do
    assert {:ok,
            {%DailySchedule{
               schedule: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 8,
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
                 }
               ]
             }, []}} =
             DailySchedule.parse(
               constructed:
                 {0,
                  [
                    time: %BACnetTime{
                      hour: 8,
                      minute: 0,
                      second: 0,
                      hundredth: 0
                    },
                    enumerated: 1
                  ], 0}
             )
  end

  test "decode daily schedule two" do
    assert {:ok,
            {%DailySchedule{
               schedule: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 8,
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
                     hour: 20,
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
               ]
             }, []}} =
             DailySchedule.parse(
               constructed:
                 {0,
                  [
                    time: %BACnetTime{
                      hour: 8,
                      minute: 0,
                      second: 0,
                      hundredth: 0
                    },
                    enumerated: 1,
                    time: %BACnetTime{
                      hour: 20,
                      minute: 0,
                      second: 0,
                      hundredth: 0
                    },
                    enumerated: 0
                  ], 0}
             )
  end

  test "decode empty daily schedule" do
    assert {:ok,
            {%DailySchedule{
               schedule: []
             }, []}} = DailySchedule.parse(constructed: {0, [], 0})
  end

  test "decode invalid daily schedule" do
    assert {:error, :invalid_tags} = DailySchedule.parse([])
  end

  test "decode invalid daily schedule in time value" do
    assert {:error, :invalid_tags} = DailySchedule.parse(constructed: {0, [enumerated: 1], 0})
  end

  test "encode daily schedule" do
    assert {:ok,
            [
              constructed:
                {0,
                 [
                   time: %BACnetTime{
                     hour: 8,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   enumerated: 1
                 ], 0}
            ]} =
             DailySchedule.encode(%DailySchedule{
               schedule: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 8,
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
                 }
               ]
             })
  end

  test "encode daily schedule two" do
    assert {:ok,
            [
              constructed:
                {0,
                 [
                   time: %BACnetTime{
                     hour: 8,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   enumerated: 1,
                   time: %BACnetTime{
                     hour: 20,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   enumerated: 0
                 ], 0}
            ]} =
             DailySchedule.encode(%DailySchedule{
               schedule: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 8,
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
                     hour: 20,
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
               ]
             })
  end

  test "encode empty daily schedule" do
    assert {:ok,
            [
              constructed: {0, [], 0}
            ]} =
             DailySchedule.encode(%DailySchedule{
               schedule: []
             })
  end

  test "encode invalid daily schedule" do
    assert {:error, :invalid_value} =
             DailySchedule.encode(%DailySchedule{
               schedule: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 8,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: nil,
                     extras: [],
                     type: nil,
                     value: nil
                   }
                 }
               ]
             })
  end

  test "valid daily schedule" do
    assert true ==
             DailySchedule.valid?(%DailySchedule{
               schedule: []
             })

    assert true ==
             DailySchedule.valid?(%DailySchedule{
               schedule: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 8,
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
                     hour: 20,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :real,
                     value: 1.0
                   }
                 }
               ]
             })
  end

  test "invalid daily schedule" do
    assert false ==
             DailySchedule.valid?(%DailySchedule{
               schedule: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 8,
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
                   time: :hello,
                   value: %Encoding{
                     encoding: :primitive,
                     extras: [],
                     type: :enumerated,
                     value: 0
                   }
                 }
               ]
             })

    assert false ==
             DailySchedule.valid?(%DailySchedule{
               schedule: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 8,
                     minute: 0,
                     second: 0,
                     hundredth: 0
                   },
                   value: :hello
                 }
               ]
             })

    assert false ==
             DailySchedule.valid?(%DailySchedule{
               schedule: [
                 %TimeValue{
                   time: %BACnetTime{
                     hour: 8,
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
                 :hello
               ]
             })

    assert false ==
             DailySchedule.valid?(%DailySchedule{
               schedule: :hello
             })
  end
end
