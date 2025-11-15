defmodule BACnet.Protocol.BACnetDateTest do
  alias BACnet.Protocol.BACnetDate

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest BACnetDate

  test "compare date eq" do
    date1 = BACnetDate.utc_today()
    assert :eq = BACnetDate.compare(date1, date1)
  end

  test "compare date lt" do
    date1 = BACnetDate.utc_today()
    date2 = BACnetDate.from_date(Date.add(BACnetDate.to_date!(date1), 60))
    assert :lt = BACnetDate.compare(date1, date2)
  end

  test "compare date gt" do
    date1 = BACnetDate.utc_today()
    date2 = BACnetDate.from_date(Date.add(BACnetDate.to_date!(date1), -60))
    assert :gt = BACnetDate.compare(date1, date2)
  end

  test "encode date" do
    date = BACnetDate.utc_today()

    assert {:ok, [date: ^date]} = BACnetDate.encode(date)
  end

  test "parse date" do
    date = BACnetDate.utc_today()

    assert {:ok, {^date, []}} = BACnetDate.parse(date: date)
  end

  test "parse invalid date" do
    assert {:error, :invalid_tags} = BACnetDate.parse([])
  end

  test "from date" do
    dt = Date.utc_today()
    weekday = Date.day_of_week(dt)

    assert %BACnetDate{
             day: dt.day,
             month: dt.month,
             year: dt.year,
             weekday: weekday
           } == BACnetDate.from_date(dt)
  end

  test "to date" do
    dt = Date.utc_today()
    bdt = BACnetDate.from_date(dt)

    assert {:ok, ^dt} = BACnetDate.to_date(bdt)
  end

  test "to date unspecified year" do
    dt = Date.utc_today()
    bdt = BACnetDate.from_date(dt)

    assert {:ok, ^dt} = BACnetDate.to_date(%{bdt | year: :unspecified})
  end

  test "to date unspecified month" do
    dt = Date.utc_today()
    bdt = BACnetDate.from_date(dt)

    assert {:ok, ^dt} = BACnetDate.to_date(%{bdt | month: :unspecified})
  end

  test "to date even month" do
    dt = Date.utc_today()
    bdt = BACnetDate.from_date(dt)

    dt2 = %{
      dt
      | month:
          if(rem(dt.month, 2) == 0,
            do: dt.month,
            else: if(dt.month == 1, do: 12, else: dt.month - 1)
          )
    }

    dt2 =
      if Date.compare(dt2, Date.end_of_month(dt2)) == :gt do
        Date.end_of_month(dt2)
      else
        dt2
      end

    assert {:ok, ^dt2} = BACnetDate.to_date(%{bdt | month: :even})
  end

  test "to date even month - fixed date" do
    dt = ~D[2023-03-31]
    bdt = BACnetDate.from_date(dt)

    assert {:ok, ~D[2023-02-28]} = BACnetDate.to_date(%{bdt | month: :even}, dt)
  end

  test "to date even month - fixed date leap day" do
    dt = ~D[2020-03-31]
    bdt = BACnetDate.from_date(dt)

    assert {:ok, ~D[2020-02-29]} = BACnetDate.to_date(%{bdt | month: :even}, dt)
  end

  test "to date odd month" do
    dt = Date.utc_today()
    bdt = BACnetDate.from_date(dt)

    dt2 = %{
      dt
      | month:
          if(rem(dt.month, 2) == 1,
            do: dt.month,
            else: if(dt.month == 1, do: 12, else: dt.month - 1)
          )
    }

    dt2 =
      if Date.compare(dt2, Date.end_of_month(dt2)) == :gt do
        Date.end_of_month(dt2)
      else
        dt2
      end

    assert {:ok, ^dt2} = BACnetDate.to_date(%{bdt | month: :odd})
  end

  test "to date odd month - fixed date" do
    dt = ~D[2023-03-31]
    bdt = BACnetDate.from_date(dt)

    assert {:ok, ~D[2023-03-31]} = BACnetDate.to_date(%{bdt | month: :odd}, dt)
  end

  test "to date odd month - fixed date leap day" do
    dt = ~D[2020-03-31]
    bdt = BACnetDate.from_date(dt)

    assert {:ok, ~D[2020-03-31]} = BACnetDate.to_date(%{bdt | month: :odd}, dt)
  end

  test "to date unspecified day" do
    dt = Date.utc_today()
    bdt = BACnetDate.from_date(dt)

    assert {:ok, ^dt} = BACnetDate.to_date(%{bdt | day: :unspecified})
  end

  test "to date even day" do
    dt = Date.utc_today()
    bdt = BACnetDate.from_date(dt)

    assert {:ok, if(rem(dt.day, 2) == 0, do: dt, else: Date.add(dt, -1))} ==
             BACnetDate.to_date(%{bdt | day: :even})
  end

  test "to date even day - fixed date" do
    dt = ~D[2023-03-31]
    bdt = BACnetDate.from_date(dt)

    assert {:ok, ~D[2023-03-30]} ==
             BACnetDate.to_date(%{bdt | day: :even}, dt)
  end

  test "to date odd day" do
    dt = Date.utc_today()
    bdt = BACnetDate.from_date(dt)

    assert {:ok, if(rem(dt.day, 2) == 1, do: dt, else: Date.add(dt, -1))} ==
             BACnetDate.to_date(%{bdt | day: :odd})
  end

  test "to date odd day - fixed date" do
    dt = ~D[2023-03-31]
    bdt = BACnetDate.from_date(dt)

    assert {:ok, ~D[2023-03-31]} ==
             BACnetDate.to_date(%{bdt | day: :odd}, dt)
  end

  test "to date last day" do
    dt = Date.utc_today()
    dtl = Date.end_of_month(dt)
    bdt = BACnetDate.from_date(dt)

    assert {:ok, ^dtl} = BACnetDate.to_date(%{bdt | day: :last})
  end

  test "to date last day - fixed date" do
    dt = ~D[2023-02-27]
    bdt = BACnetDate.from_date(dt)

    assert {:ok, Date.end_of_month(dt)} == BACnetDate.to_date(%{bdt | day: :last}, dt)
  end

  test "to date last day - fixed date leap day" do
    dt = ~D[2020-02-27]
    bdt = BACnetDate.from_date(dt)

    assert {:ok, Date.end_of_month(dt)} == BACnetDate.to_date(%{bdt | day: :last}, dt)
  end

  test "to date unspecified weekday" do
    dt = Date.utc_today()
    bdt = BACnetDate.from_date(dt)

    assert {:ok, ^dt} = BACnetDate.to_date(%{bdt | weekday: :unspecified})
  end

  test "to date!" do
    dt = Date.utc_today()
    bdt = BACnetDate.from_date(dt)

    assert ^dt = BACnetDate.to_date!(bdt)
  end

  test "to date! unspecified year" do
    dt = Date.utc_today()
    bdt = BACnetDate.from_date(dt)

    assert ^dt = BACnetDate.to_date!(%{bdt | year: :unspecified})
  end

  test "to date! unspecified month" do
    dt = Date.utc_today()
    bdt = BACnetDate.from_date(dt)

    assert ^dt = BACnetDate.to_date!(%{bdt | month: :unspecified})
  end

  test "to date! even month" do
    dt = Date.utc_today()
    bdt = BACnetDate.from_date(dt)

    dt2 = %{
      dt
      | month:
          if(rem(dt.month, 2) == 0,
            do: dt.month,
            else: if(dt.month == 1, do: 12, else: dt.month - 1)
          )
    }

    dt2 =
      if Date.compare(dt2, Date.end_of_month(dt2)) == :gt do
        Date.end_of_month(dt2)
      else
        dt2
      end

    assert ^dt2 = BACnetDate.to_date!(%{bdt | month: :even})
  end

  test "to date! even month - fixed date" do
    dt = ~D[2023-03-31]
    bdt = BACnetDate.from_date(dt)

    assert ~D[2023-02-28] = BACnetDate.to_date!(%{bdt | month: :even}, dt)
  end

  test "to date! even month - fixed date leap day" do
    dt = ~D[2020-03-31]
    bdt = BACnetDate.from_date(dt)

    assert ~D[2020-02-29] = BACnetDate.to_date!(%{bdt | month: :even}, dt)
  end

  test "to date! odd month" do
    dt = Date.utc_today()
    bdt = BACnetDate.from_date(dt)

    dt2 = %{
      dt
      | month:
          if(rem(dt.month, 2) == 1,
            do: dt.month,
            else: if(dt.month == 1, do: 12, else: dt.month - 1)
          )
    }

    dt2 =
      if Date.compare(dt2, Date.end_of_month(dt2)) == :gt do
        Date.end_of_month(dt2)
      else
        dt2
      end

    assert ^dt2 = BACnetDate.to_date!(%{bdt | month: :odd})
  end

  test "to date! odd month - fixed date" do
    dt = ~D[2023-03-31]
    bdt = BACnetDate.from_date(dt)

    assert ~D[2023-03-31] = BACnetDate.to_date!(%{bdt | month: :odd}, dt)
  end

  test "to date! odd month - fixed date leap day" do
    dt = ~D[2020-03-31]
    bdt = BACnetDate.from_date(dt)

    assert ~D[2020-03-31] = BACnetDate.to_date!(%{bdt | month: :odd}, dt)
  end

  test "to date! unspecified day" do
    dt = Date.utc_today()
    bdt = BACnetDate.from_date(dt)

    assert ^dt = BACnetDate.to_date!(%{bdt | day: :unspecified})
  end

  test "to date! even day" do
    dt = Date.utc_today()
    bdt = BACnetDate.from_date(dt)

    assert if(rem(dt.day, 2) == 0, do: dt, else: Date.add(dt, -1)) ==
             BACnetDate.to_date!(%{bdt | day: :even})
  end

  test "to date! even day - fixed date" do
    dt = ~D[2023-03-31]
    bdt = BACnetDate.from_date(dt)

    assert ~D[2023-03-30] ==
             BACnetDate.to_date!(%{bdt | day: :even}, dt)
  end

  test "to date! odd day" do
    dt = Date.utc_today()
    bdt = BACnetDate.from_date(dt)

    assert if(rem(dt.day, 2) == 1, do: dt, else: Date.add(dt, -1)) ==
             BACnetDate.to_date!(%{bdt | day: :odd})
  end

  test "to date! odd day - fixed date" do
    dt = ~D[2023-03-31]
    bdt = BACnetDate.from_date(dt)

    assert ~D[2023-03-31] ==
             BACnetDate.to_date!(%{bdt | day: :odd}, dt)
  end

  test "to date! last day" do
    dt = Date.utc_today()
    bdt = BACnetDate.from_date(dt)

    assert Date.end_of_month(dt) == BACnetDate.to_date!(%{bdt | day: :last})
  end

  test "to date! last day - fixed date" do
    dt = ~D[2023-02-27]
    bdt = BACnetDate.from_date(dt)

    assert Date.end_of_month(dt) == BACnetDate.to_date!(%{bdt | day: :last}, dt)
  end

  test "to date! last day - fixed date leap day" do
    dt = ~D[2020-02-27]
    bdt = BACnetDate.from_date(dt)

    assert Date.end_of_month(dt) == BACnetDate.to_date!(%{bdt | day: :last}, dt)
  end

  test "to date! unspecified weekday" do
    dt = Date.utc_today()
    bdt = BACnetDate.from_date(dt)

    assert ^dt = BACnetDate.to_date!(%{bdt | weekday: :unspecified})
  end

  test "specific date" do
    base_date = BACnetDate.utc_today()
    assert true == BACnetDate.specific?(base_date)
    assert true == BACnetDate.specific?(BACnetDate.from_date(Date.utc_today()))
    assert false == BACnetDate.specific?(%{base_date | year: :unspecified})
    assert false == BACnetDate.specific?(%{base_date | month: :unspecified})
    assert false == BACnetDate.specific?(%{base_date | month: :even})
    assert false == BACnetDate.specific?(%{base_date | month: :odd})
    assert false == BACnetDate.specific?(%{base_date | day: :unspecified})
    assert false == BACnetDate.specific?(%{base_date | day: :even})
    assert false == BACnetDate.specific?(%{base_date | day: :odd})
    assert true == BACnetDate.specific?(%{base_date | day: :last})
    assert false == BACnetDate.specific?(%{base_date | weekday: :unspecified})
  end

  test "utc today date" do
    dt = Date.utc_today()
    day = dt.day
    month = dt.month
    year = dt.year
    weekday = Date.day_of_week(dt)

    assert %BACnetDate{
             day: ^day,
             month: ^month,
             year: ^year,
             weekday: ^weekday
           } = BACnetDate.utc_today()
  end

  test "valid date" do
    base_date = BACnetDate.utc_today()
    assert true == BACnetDate.valid?(base_date)
    assert true == BACnetDate.valid?(%{base_date | year: :unspecified})
    assert true == BACnetDate.valid?(%{base_date | month: :unspecified})
    assert true == BACnetDate.valid?(%{base_date | month: :even})
    assert true == BACnetDate.valid?(%{base_date | month: :odd})
    assert true == BACnetDate.valid?(%{base_date | day: :unspecified})
    assert true == BACnetDate.valid?(%{base_date | day: :even})
    assert true == BACnetDate.valid?(%{base_date | day: :odd})
    assert true == BACnetDate.valid?(%{base_date | day: :last})
    assert true == BACnetDate.valid?(%{base_date | weekday: :unspecified})
    assert true == BACnetDate.valid?(BACnetDate.from_date(Date.utc_today()))
  end

  test "invalid date" do
    assert false ==
             BACnetDate.valid?(%BACnetDate{year: :hello, month: :odd, day: :odd, weekday: 1})

    assert false ==
             BACnetDate.valid?(%BACnetDate{year: 2000, month: :hello, day: :odd, weekday: 1})

    assert false ==
             BACnetDate.valid?(%BACnetDate{
               year: :unspecified,
               month: :odd,
               day: :hello,
               weekday: 1
             })

    assert false ==
             BACnetDate.valid?(%BACnetDate{
               year: :unspecified,
               month: :odd,
               day: :odd,
               weekday: :odd
             })
  end
end
