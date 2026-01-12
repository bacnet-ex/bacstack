defmodule BACnet.Protocol.CalendarEntryTest do
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.DateRange
  alias BACnet.Protocol.CalendarEntry
  alias BACnet.Protocol.WeekNDay

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest CalendarEntry

  test "decode calendar entry date" do
    assert {:ok,
            {%CalendarEntry{
               type: :date,
               date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 11,
                 weekday: 4
               },
               date_range: nil,
               week_n_day: nil
             }, []}} = CalendarEntry.parse(tagged: {0, <<123, 5, 11, 4>>, 4})
  end

  test "decode calendar entry date range" do
    assert {:ok,
            {%CalendarEntry{
               type: :date_range,
               date: nil,
               date_range: %DateRange{
                 start_date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 5,
                   weekday: 5
                 },
                 end_date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 20,
                   weekday: 6
                 }
               },
               week_n_day: nil
             }, []}} =
             CalendarEntry.parse(
               constructed:
                 {1,
                  [
                    date: %BACnetDate{year: 2023, month: 5, day: 5, weekday: 5},
                    date: %BACnetDate{
                      year: 2023,
                      month: 5,
                      day: 20,
                      weekday: 6
                    }
                  ], 0}
             )
  end

  test "decode calendar entry weeknday" do
    assert {:ok,
            {%CalendarEntry{
               type: :week_n_day,
               date: nil,
               date_range: nil,
               week_n_day: %WeekNDay{
                 month: :unspecified,
                 week_of_month: 1,
                 weekday: :unspecified
               }
             }, []}} = CalendarEntry.parse(tagged: {2, <<255, 1, 255>>, 3})
  end

  test "decode invalid calendar entry" do
    assert {:error, :invalid_tags} = CalendarEntry.parse(tagged: {5, <<255, 1, 255>>, 3})
  end

  test "encode calendar entry date" do
    assert {:ok, [tagged: {0, <<123, 5, 11, 4>>, 4}]} =
             CalendarEntry.encode(%CalendarEntry{
               type: :date,
               date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 11,
                 weekday: 4
               },
               date_range: nil,
               week_n_day: nil
             })
  end

  test "encode calendar entry date range" do
    assert {:ok,
            [
              constructed:
                {1,
                 [
                   date: %BACnetDate{year: 2023, month: 5, day: 5, weekday: 5},
                   date: %BACnetDate{
                     year: 2023,
                     month: 5,
                     day: 20,
                     weekday: 6
                   }
                 ], 0}
            ]} =
             CalendarEntry.encode(%CalendarEntry{
               type: :date_range,
               date: nil,
               date_range: %DateRange{
                 start_date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 5,
                   weekday: 5
                 },
                 end_date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 20,
                   weekday: 6
                 }
               },
               week_n_day: nil
             })
  end

  test "encode calendar entry weeknday" do
    assert {:ok, [tagged: {2, <<255, 1, 255>>, 3}]} =
             CalendarEntry.encode(%CalendarEntry{
               type: :week_n_day,
               date: nil,
               date_range: nil,
               week_n_day: %WeekNDay{
                 month: :unspecified,
                 week_of_month: 1,
                 weekday: :unspecified
               }
             })
  end

  test "valid calendar entry" do
    assert true ==
             CalendarEntry.valid?(%CalendarEntry{
               type: :date,
               date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 11,
                 weekday: 4
               },
               date_range: nil,
               week_n_day: nil
             })

    assert true ==
             CalendarEntry.valid?(%CalendarEntry{
               type: :date_range,
               date: nil,
               date_range: %DateRange{
                 start_date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 5,
                   weekday: 5
                 },
                 end_date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 20,
                   weekday: 6
                 }
               },
               week_n_day: nil
             })

    assert true ==
             CalendarEntry.valid?(%CalendarEntry{
               type: :week_n_day,
               date: nil,
               date_range: nil,
               week_n_day: %WeekNDay{
                 month: :unspecified,
                 week_of_month: 1,
                 weekday: :unspecified
               }
             })
  end

  test "invalid calendar entry" do
    assert false ==
             CalendarEntry.valid?(%CalendarEntry{
               type: :date,
               date: :hello,
               date_range: nil,
               week_n_day: nil
             })

    assert false ==
             CalendarEntry.valid?(%CalendarEntry{
               type: :date,
               date: %BACnetDate{
                 year: 2023,
                 month: 5,
                 day: 55,
                 weekday: 4
               },
               date_range: nil,
               week_n_day: nil
             })

    assert false ==
             CalendarEntry.valid?(%CalendarEntry{
               type: :date_range,
               date: nil,
               date_range: :hello,
               week_n_day: nil
             })

    assert false ==
             CalendarEntry.valid?(%CalendarEntry{
               type: :date_range,
               date: nil,
               date_range: %DateRange{
                 start_date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 55,
                   weekday: 5
                 },
                 end_date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 5,
                   weekday: 6
                 }
               },
               week_n_day: nil
             })

    assert false ==
             CalendarEntry.valid?(%CalendarEntry{
               type: :date_range,
               date: nil,
               date_range: %DateRange{
                 start_date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 5,
                   weekday: 5
                 },
                 end_date: %BACnetDate{
                   year: 2023,
                   month: 5,
                   day: 55,
                   weekday: 6
                 }
               },
               week_n_day: nil
             })

    assert false ==
             CalendarEntry.valid?(%CalendarEntry{
               type: :week_n_day,
               date: nil,
               date_range: nil,
               week_n_day: :hello
             })

    assert false ==
             CalendarEntry.valid?(%CalendarEntry{
               type: :week_n_day,
               date: nil,
               date_range: nil,
               week_n_day: %WeekNDay{
                 month: :unspecified,
                 week_of_month: 10,
                 weekday: :unspecified
               }
             })
  end
end
