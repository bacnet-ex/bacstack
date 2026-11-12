defmodule BACnet.Protocol.CalendarEntryMatchingTest do
  use ExUnit.Case, async: true

  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.CalendarEntry
  alias BACnet.Protocol.DateRange
  alias BACnet.Protocol.SpecialEvent
  alias BACnet.Protocol.WeekNDay

  @moduletag :protocol_data_structures

  @any %BACnetDate{
    year: :unspecified,
    month: :unspecified,
    day: :unspecified,
    weekday: :unspecified
  }

  test "every specified date component is an independent constraint" do
    date = ~D[2026-11-08]
    pattern = %BACnetDate{year: 2026, month: :odd, day: :even, weekday: 7}
    assert CalendarEntry.matches_date?(entry(:date, pattern), date)

    for {key, value} <- [year: 2025, month: :even, day: :odd, weekday: 1] do
      refute CalendarEntry.matches_date?(entry(:date, Map.put(pattern, key, value)), date)
    end

    assert CalendarEntry.matches_date?(entry(:date, @any), date)
    refute CalendarEntry.matches_date?(entry(:date, %{pattern | weekday: 1}), date)
  end

  test "last-day and odd/even patterns respect real Gregorian month lengths" do
    for year <- [1900, 2000, 2023, 2024, 2100, 2154], month <- 1..12 do
      first = Date.new!(year, month, 1)
      last = Date.end_of_month(first)
      assert CalendarEntry.matches_date?(entry(:date, %{@any | day: :last}), last)
      refute CalendarEntry.matches_date?(entry(:date, %{@any | day: :last}), Date.add(last, -1))

      for day <- 1..last.day do
        date = Date.new!(year, month, day)

        assert CalendarEntry.matches_date?(entry(:date, %{@any | day: :odd}), date) ==
                 (rem(day, 2) == 1)

        assert CalendarEntry.matches_date?(entry(:date, %{@any | month: :even}), date) ==
                 (rem(month, 2) == 0)
      end
    end
  end

  test "impossible patterns do not clamp into a match" do
    pattern = %{@any | month: 2, day: 30}
    assert CalendarEntry.valid_for_matching?(entry(:date, pattern))
    refute CalendarEntry.matches_date?(entry(:date, pattern), ~D[2024-02-29])
    refute CalendarEntry.matches_date?(entry(:date, pattern), ~D[2023-02-28])
    leap_day = entry(:date, %{@any | month: 2, day: 29})
    assert CalendarEntry.matches_date?(leap_day, ~D[2024-02-29])
    refute CalendarEntry.matches_date?(leap_day, ~D[2023-02-28])
  end

  test "numbered and month-end WeekNDay blocks match their specified bounds" do
    for year <- [1900, 2000, 2023, 2024, 2100, 2154], month <- 1..12 do
      last = Date.days_in_month(Date.new!(year, month, 1))

      bounds = [
        {1, 7},
        {8, 14},
        {15, 21},
        {22, 28},
        {29, 31},
        {last - 6, last},
        {last - 13, last - 7},
        {last - 20, last - 14},
        {last - 27, last - 21}
      ]

      for {{first, final}, week} <- Enum.with_index(bounds, 1), day <- 1..last do
        pattern =
          entry(:week_n_day, %WeekNDay{
            month: :unspecified,
            week_of_month: week,
            weekday: :unspecified
          })

        assert CalendarEntry.matches_date?(pattern, Date.new!(year, month, day)) ==
                 (day >= first and day <= final)
      end
    end
  end

  test "week patterns constrain month and weekday independently and Sunday is 7" do
    pattern = %WeekNDay{month: :odd, week_of_month: 2, weekday: 7}
    assert CalendarEntry.matches_date?(entry(:week_n_day, pattern), ~D[2026-11-08])
    refute CalendarEntry.matches_date?(entry(:week_n_day, pattern), ~D[2026-11-09])

    refute CalendarEntry.matches_date?(
             entry(:week_n_day, %{pattern | month: :even}),
             ~D[2026-11-08]
           )

    assert CalendarEntry.matches_date?(
             entry(
               :week_n_day,
               %{pattern | week_of_month: :unspecified}
             ),
             ~D[2026-11-29]
           )

    assert CalendarEntry.matches_date?(
             entry(
               :week_n_day,
               %{
                 pattern
                 | month: :unspecified,
                   week_of_month: :unspecified,
                   weekday: :unspecified
               }
             ),
             ~D[2024-02-29]
           )
  end

  test "inclusive ranges support specific, open and fully unspecified endpoints" do
    start = BACnetDate.from_date(~D[2026-12-24])
    finish = BACnetDate.from_date(~D[2027-01-02])
    closed = entry(:date_range, %DateRange{start_date: start, end_date: finish})

    for date <- [~D[2026-12-24], ~D[2026-12-31], ~D[2027-01-02]] do
      assert CalendarEntry.matches_date?(closed, date)
    end

    for date <- [~D[2026-12-23], ~D[2027-01-03]] do
      refute CalendarEntry.matches_date?(closed, date)
    end

    assert CalendarEntry.matches_date?(
             entry(
               :date_range,
               %DateRange{start_date: @any, end_date: finish}
             ),
             ~D[1900-01-01]
           )

    assert CalendarEntry.matches_date?(
             entry(
               :date_range,
               %DateRange{start_date: start, end_date: @any}
             ),
             ~D[2154-12-31]
           )

    assert CalendarEntry.matches_date?(
             entry(
               :date_range,
               %DateRange{start_date: @any, end_date: @any}
             ),
             ~D[2024-02-29]
           )

    same_day = entry(:date_range, %DateRange{start_date: start, end_date: start})
    assert CalendarEntry.matches_date?(same_day, ~D[2026-12-24])
    refute CalendarEntry.matches_date?(same_day, ~D[2026-12-25])
  end

  test "range validation rejects partial patterns, special values, impossible and reversed dates" do
    start = BACnetDate.from_date(~D[2026-02-01])
    finish = BACnetDate.from_date(~D[2026-03-01])

    invalid = [
      %{start | year: :unspecified},
      %{start | month: :odd},
      %{start | weekday: :unspecified},
      %{start | day: :last},
      %{start | day: 30},
      %{start | day: 0}
    ]

    for endpoint <- invalid, which <- [:start_date, :end_date] do
      range = Map.put(%DateRange{start_date: start, end_date: finish}, which, endpoint)
      refute CalendarEntry.valid_for_matching?(entry(:date_range, range))
      refute CalendarEntry.matches_date?(entry(:date_range, range), ~D[2026-02-28])
    end

    reversed = entry(:date_range, %DateRange{start_date: finish, end_date: start})
    refute CalendarEntry.valid_for_matching?(reversed)
    refute CalendarEntry.matches_date?(reversed, ~D[2026-02-28])
  end

  test "range endpoint weekday inconsistencies use the documented year/month/day policy" do
    range = %DateRange{
      start_date: %BACnetDate{year: 2026, month: 1, day: 1, weekday: 1},
      end_date: %BACnetDate{year: 2026, month: 1, day: 2, weekday: 1}
    }

    assert CalendarEntry.valid_for_matching?(entry(:date_range, range))
    assert CalendarEntry.matches_date?(entry(:date_range, range), ~D[2026-01-02])
  end

  test "matching accepts all supported weeks and rejects incoherent choices or invalid values" do
    for week <- 1..9 do
      pattern =
        entry(:week_n_day, %WeekNDay{
          month: :unspecified,
          week_of_month: week,
          weekday: :unspecified
        })

      assert CalendarEntry.valid_for_matching?(pattern)
    end

    for invalid <- [
          %{entry(:date, @any) | date_range: %DateRange{start_date: @any, end_date: @any}},
          entry(:date, %{@any | weekday: 8}),
          entry(:date, nil),
          entry(:unknown, nil)
        ] do
      refute CalendarEntry.valid_for_matching?(invalid)
      refute CalendarEntry.matches_date?(invalid, ~D[2026-11-07])
    end
  end

  test "new WeekNDay forms round-trip through both containing codecs" do
    for week <- 7..9 do
      pattern = entry(:week_n_day, %WeekNDay{month: :odd, week_of_month: week, weekday: 7})
      assert CalendarEntry.valid?(pattern)
      assert {:ok, tags} = CalendarEntry.encode(pattern)
      assert {:ok, {^pattern, []}} = CalendarEntry.parse(tags)
      event = %SpecialEvent{period: pattern, list: [], priority: 1}
      assert SpecialEvent.valid?(event)
      assert {:ok, tags} = SpecialEvent.encode(event)
      assert {:ok, {^event, []}} = SpecialEvent.parse(tags)
    end
  end

  defp entry(type, value) do
    %CalendarEntry{
      type: type,
      date: if(type == :date, do: value),
      date_range: if(type == :date_range, do: value),
      week_n_day: if(type == :week_n_day, do: value)
    }
  end
end
