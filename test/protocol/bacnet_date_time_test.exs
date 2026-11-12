defmodule BACnet.Protocol.BACnetDateTimeTest do
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetTime

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest BACnetDateTime

  test "compare datetime eq" do
    date1 = BACnetDateTime.utc_now()
    assert :eq = BACnetDateTime.compare(date1, date1)
  end

  test "compare datetime lt" do
    date1 = BACnetDateTime.utc_now()
    date2 = BACnetDateTime.from_datetime(DateTime.add(BACnetDateTime.to_datetime!(date1), 60))
    assert :lt = BACnetDateTime.compare(date1, date2)
  end

  test "compare datetime gt" do
    date1 = BACnetDateTime.utc_now()
    date2 = BACnetDateTime.from_datetime(DateTime.add(BACnetDateTime.to_datetime!(date1), -60))
    assert :gt = BACnetDateTime.compare(date1, date2)
  end

  test "encode datetime" do
    date = BACnetDate.utc_today()
    time = BACnetTime.utc_now()

    assert {:ok, [date: ^date, time: ^time]} =
             BACnetDateTime.encode(%BACnetDateTime{date: date, time: time})
  end

  test "parse datetime" do
    date = BACnetDate.utc_today()
    time = BACnetTime.utc_now()

    assert {:ok, {%BACnetDateTime{date: ^date, time: ^time}, []}} =
             BACnetDateTime.parse(date: date, time: time)
  end

  test "parse invalid datetime" do
    assert {:error, :invalid_tags} = BACnetDateTime.parse([])
  end

  test "from datetime" do
    dt = ~U[2026-11-09 12:34:56.123456Z]
    weekday = Date.day_of_week(DateTime.to_date(dt))

    assert %BACnetDateTime{
             date: %BACnetDate{
               day: dt.day,
               month: dt.month,
               year: dt.year,
               weekday: weekday
             },
             time: %BACnetTime{
               hour: dt.hour,
               minute: dt.minute,
               second: dt.second,
               hundredth: 12
             }
           } == BACnetDateTime.from_datetime(dt)
  end

  test "from naive datetime" do
    dt = ~N[2026-11-09 12:34:56.123456]
    weekday = Date.day_of_week(NaiveDateTime.to_date(dt))

    assert %BACnetDateTime{
             date: %BACnetDate{
               day: dt.day,
               month: dt.month,
               year: dt.year,
               weekday: weekday
             },
             time: %BACnetTime{
               hour: dt.hour,
               minute: dt.minute,
               second: dt.second,
               hundredth: 12
             }
           } == BACnetDateTime.from_naive_datetime(dt)
  end

  test "datetime conversions preserve millisecond times at BACnet hundredth resolution" do
    datetime = BACnetDateTime.from_datetime(~U[2026-11-09 12:34:56.334Z])
    naive = BACnetDateTime.from_naive_datetime(~N[2026-11-09 12:34:56.334])

    assert datetime == naive
    assert datetime.time == %BACnetTime{hour: 12, minute: 34, second: 56, hundredth: 33}
    assert BACnetDateTime.valid?(datetime)
  end

  test "to datetime" do
    dt = DateTime.utc_now()
    bdt = BACnetDateTime.from_datetime(dt)

    assert {:ok, %DateTime{}} = BACnetDateTime.to_datetime(bdt)
  end

  test "to datetime!" do
    dt = DateTime.utc_now()
    bdt = BACnetDateTime.from_datetime(dt)

    assert %DateTime{} = BACnetDateTime.to_datetime!(bdt)
  end

  test "to naive datetime" do
    dt = DateTime.utc_now()
    bdt = BACnetDateTime.from_datetime(dt)

    assert {:ok, %NaiveDateTime{}} = BACnetDateTime.to_naive_datetime(bdt)
  end

  test "to naive datetime!" do
    dt = DateTime.utc_now()
    bdt = BACnetDateTime.from_datetime(dt)

    assert %NaiveDateTime{} = BACnetDateTime.to_naive_datetime!(bdt)
  end

  test "specific datetime" do
    assert true ==
             BACnetDateTime.specific?(%BACnetDateTime{
               date: BACnetDate.utc_today(),
               time: BACnetTime.utc_now()
             })

    assert false ==
             BACnetDateTime.specific?(%BACnetDateTime{
               date: %{BACnetDate.utc_today() | year: :unspecified},
               time: %{BACnetTime.utc_now() | hour: :unspecified}
             })
  end

  test "utc now datetime" do
    dt = DateTime.utc_now()
    day = dt.day
    month = dt.month
    year = dt.year
    weekday = Date.day_of_week(DateTime.to_date(dt))
    hour = dt.hour
    minute = dt.minute
    second = dt.second

    assert %BACnetDateTime{
             date: %BACnetDate{
               day: ^day,
               month: ^month,
               year: ^year,
               weekday: ^weekday
             },
             time: %BACnetTime{
               hour: ^hour,
               minute: ^minute,
               second: ^second
             }
           } = BACnetDateTime.utc_now()
  end

  test "valid datetime" do
    assert true == BACnetDateTime.valid?(BACnetDateTime.utc_now())
    assert true == BACnetDateTime.valid?(BACnetDateTime.from_datetime(DateTime.utc_now()))

    assert true ==
             BACnetDateTime.valid?(%BACnetDateTime{
               date: BACnetDate.utc_today(),
               time: BACnetTime.utc_now()
             })
  end

  test "invalid datetime" do
    assert false ==
             BACnetDateTime.valid?(%BACnetDateTime{date: :hello, time: BACnetTime.utc_now()})

    assert false ==
             BACnetDateTime.valid?(%BACnetDateTime{date: BACnetDate.utc_today(), time: :hello})

    assert false ==
             BACnetDateTime.valid?(%BACnetDateTime{
               date: %BACnetDate{year: :hello, month: :odd, day: :odd, weekday: 1},
               time: BACnetTime.utc_now()
             })

    assert false ==
             BACnetDateTime.valid?(%BACnetDateTime{
               date: BACnetDate.utc_today(),
               time: %BACnetTime{hour: 23, minute: :hello, second: 5, hundredth: 0}
             })
  end
end
