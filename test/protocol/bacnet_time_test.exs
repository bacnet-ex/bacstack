defmodule BACnet.Protocol.BACnetTimeTest do
  alias BACnet.Protocol.BACnetTime

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest BACnetTime

  defp patch_hundredth(%Time{microsecond: {_us, 0}} = dt), do: dt

  defp patch_hundredth(%Time{} = dt) do
    %{dt | microsecond: {div(elem(dt.microsecond, 0), 10_000) * 10_000, 6}}
  end

  test "compare time eq" do
    time1 = BACnetTime.utc_now()
    assert :eq = BACnetTime.compare(time1, time1)
  end

  test "compare time lt" do
    time1 = BACnetTime.utc_now()
    time2 = BACnetTime.from_time(Time.add(BACnetTime.to_time!(time1), 60))
    assert :lt = BACnetTime.compare(time1, time2)
  end

  test "compare time gt" do
    time1 = BACnetTime.utc_now()
    time2 = BACnetTime.from_time(Time.add(BACnetTime.to_time!(time1), -60))
    assert :gt = BACnetTime.compare(time1, time2)
  end

  test "encode time" do
    time = BACnetTime.utc_now()

    assert {:ok, [time: ^time]} = BACnetTime.encode(time)
  end

  test "parse time" do
    time = BACnetTime.utc_now()

    assert {:ok, {^time, []}} = BACnetTime.parse(time: time)
  end

  test "parse invalid time" do
    assert {:error, :invalid_tags} = BACnetTime.parse([])
  end

  test "from time" do
    dt = Time.utc_now()

    hundredth =
      case dt.microsecond do
        {_value, 0} -> 0
        {value, 1} -> value * 10
        {value, 2} -> value
        {value, 3} -> Integer.floor_div(value, 10)
        {value, 4} -> Integer.floor_div(value, 100)
        {value, 5} -> Integer.floor_div(value, 1000)
        {value, 6} -> Integer.floor_div(value, 10_000)
      end

    assert %BACnetTime{
             second: dt.second,
             minute: dt.minute,
             hour: dt.hour,
             hundredth: hundredth
           } == BACnetTime.from_time(dt)
  end

  test "from time various ms precision" do
    assert %BACnetTime{
             hour: 23,
             minute: 59,
             second: 59,
             hundredth: 50
           } = BACnetTime.from_time(Time.new!(23, 59, 59, {50_000, 5}))

    assert %BACnetTime{
             hour: 23,
             minute: 59,
             second: 59,
             hundredth: 50
           } = BACnetTime.from_time(Time.new!(23, 59, 59, {5000, 4}))

    assert %BACnetTime{
             hour: 23,
             minute: 59,
             second: 59,
             hundredth: 50
           } = BACnetTime.from_time(Time.new!(23, 59, 59, {500, 3}))

    assert %BACnetTime{
             hour: 23,
             minute: 59,
             second: 59,
             hundredth: 50
           } = BACnetTime.from_time(Time.new!(23, 59, 59, {50, 2}))

    assert %BACnetTime{
             hour: 23,
             minute: 59,
             second: 59,
             hundredth: 50
           } = BACnetTime.from_time(Time.new!(23, 59, 59, {5, 1}))

    assert %BACnetTime{
             hour: 23,
             minute: 59,
             second: 59,
             hundredth: 5
           } = BACnetTime.from_time(Time.new!(23, 59, 59, {5, 2}))
  end

  test "to time" do
    dt = Time.utc_now()
    bdt = BACnetTime.from_time(dt)

    assert {:ok, patch_hundredth(dt)} == BACnetTime.to_time(bdt)
  end

  test "to time unspecified hour" do
    dt = Time.utc_now()
    bdt = BACnetTime.from_time(dt)

    assert {:ok, patch_hundredth(dt)} == BACnetTime.to_time(%{bdt | hour: :unspecified})
  end

  test "to time unspecified minute" do
    dt = Time.utc_now()
    bdt = BACnetTime.from_time(dt)

    assert {:ok, patch_hundredth(dt)} == BACnetTime.to_time(%{bdt | minute: :unspecified})
  end

  test "to time unspecified second" do
    dt = Time.utc_now()
    bdt = BACnetTime.from_time(dt)

    assert {:ok, patch_hundredth(dt)} == BACnetTime.to_time(%{bdt | second: :unspecified})
  end

  test "to time unspecified hundredth" do
    dt = Time.utc_now()
    dtp = Time.truncate(dt, :second)
    bdt = BACnetTime.from_time(dt)

    assert {:ok, ^dtp} = BACnetTime.to_time(%{bdt | hundredth: :unspecified}, dtp)
  end

  test "to time!" do
    dt = Time.utc_now()
    bdt = BACnetTime.from_time(dt)

    assert patch_hundredth(dt) == BACnetTime.to_time!(bdt)
  end

  test "to time! unspecified hour" do
    dt = Time.utc_now()
    bdt = BACnetTime.from_time(dt)

    assert patch_hundredth(dt) == BACnetTime.to_time!(%{bdt | hour: :unspecified})
  end

  test "to time! unspecified minute" do
    dt = Time.utc_now()
    bdt = BACnetTime.from_time(dt)

    assert patch_hundredth(dt) == BACnetTime.to_time!(%{bdt | minute: :unspecified})
  end

  test "to time! unspecified second" do
    dt = Time.utc_now()
    bdt = BACnetTime.from_time(dt)

    assert patch_hundredth(dt) == BACnetTime.to_time!(%{bdt | second: :unspecified})
  end

  test "to time! unspecified hundredth" do
    dt = Time.utc_now()
    dtp = Time.truncate(dt, :second)
    bdt = BACnetTime.from_time(dt)

    assert ^dtp = BACnetTime.to_time!(%{bdt | hundredth: :unspecified}, dtp)
  end

  test "specific time" do
    base_time = BACnetTime.utc_now()
    assert true == BACnetTime.specific?(base_time)
    assert true == BACnetTime.specific?(BACnetTime.from_time(Time.utc_now()))
    assert false == BACnetTime.specific?(%{base_time | hour: :unspecified})
    assert false == BACnetTime.specific?(%{base_time | minute: :unspecified})
    assert false == BACnetTime.specific?(%{base_time | second: :unspecified})
    assert false == BACnetTime.specific?(%{base_time | hundredth: :unspecified})
  end

  test "utc now time" do
    dt = Time.utc_now()
    hour = dt.hour
    minute = dt.minute
    second = dt.second

    assert %BACnetTime{
             hour: ^hour,
             minute: ^minute,
             second: ^second
           } = BACnetTime.utc_now()
  end

  test "valid time" do
    base_time = BACnetTime.utc_now()
    assert true == BACnetTime.valid?(base_time)
    assert true == BACnetTime.valid?(%{base_time | hour: :unspecified})
    assert true == BACnetTime.valid?(%{base_time | minute: :unspecified})
    assert true == BACnetTime.valid?(%{base_time | second: :unspecified})
    assert true == BACnetTime.valid?(%{base_time | hundredth: :unspecified})
    assert true == BACnetTime.valid?(BACnetTime.from_time(Time.utc_now()))
  end

  test "invalid time" do
    assert false ==
             BACnetTime.valid?(%BACnetTime{hour: -1, minute: 0, second: 0, hundredth: 1})

    assert false ==
             BACnetTime.valid?(%BACnetTime{hour: 24, minute: 0, second: 0, hundredth: 1})

    assert false ==
             BACnetTime.valid?(%BACnetTime{hour: 0, minute: -1, second: 0, hundredth: 1})

    assert false ==
             BACnetTime.valid?(%BACnetTime{hour: 0, minute: 60, second: 0, hundredth: 1})

    assert false ==
             BACnetTime.valid?(%BACnetTime{hour: 0, minute: 0, second: -1, hundredth: 1})

    assert false ==
             BACnetTime.valid?(%BACnetTime{hour: 0, minute: 0, second: 60, hundredth: 1})

    assert false ==
             BACnetTime.valid?(%BACnetTime{hour: 0, minute: 0, second: 0, hundredth: -1})

    assert false ==
             BACnetTime.valid?(%BACnetTime{hour: 0, minute: 0, second: 0, hundredth: 100})

    assert false ==
             BACnetTime.valid?(%BACnetTime{hour: :hello, minute: 0, second: 0, hundredth: 1})

    assert false ==
             BACnetTime.valid?(%BACnetTime{hour: 0, minute: :hello, second: 0, hundredth: 1})

    assert false ==
             BACnetTime.valid?(%BACnetTime{
               hour: 0,
               minute: 0,
               second: :hello,
               hundredth: 1
             })

    assert false ==
             BACnetTime.valid?(%BACnetTime{
               hour: 0,
               minute: 0,
               second: 0,
               hundredth: :hello
             })
  end
end
