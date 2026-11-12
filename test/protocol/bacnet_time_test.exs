defmodule BACnet.Protocol.BACnetTimeTest do
  alias BACnet.Protocol.BACnetTime

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest BACnetTime

  defp patch_hundredth(time)

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
    assert BACnetTime.from_time(~T[23:59:59.123456]) == %BACnetTime{
             hour: 23,
             minute: 59,
             second: 59,
             hundredth: 12
           }
  end

  test "from time with explicit fractional precision" do
    for precision <- 1..6 do
      assert %BACnetTime{hour: 23, minute: 59, second: 59, hundredth: 50} =
               BACnetTime.from_time(Time.new!(23, 59, 59, {500_000, precision}))
    end

    assert %BACnetTime{hour: 23, minute: 59, second: 59, hundredth: 5} =
             BACnetTime.from_time(Time.new!(23, 59, 59, {50_000, 2}))
  end

  for {time, hundredth} <- [
        {~T[12:34:56], 0},
        {~T[12:34:56.5], 50},
        {~T[12:34:56.50], 50},
        {~T[12:34:56.500], 50},
        {~T[12:34:56.5000], 50},
        {~T[12:34:56.50000], 50},
        {~T[12:34:56.500000], 50},
        {~T[12:34:56.05], 5},
        {~T[12:34:56.334], 33},
        {~T[12:34:56.009999], 0},
        {~T[12:34:56.019999], 1},
        {~T[12:34:56.999999], 99}
      ] do
    test "from_time converts microseconds to hundredths for #{Time.to_iso8601(time)}" do
      time = unquote(Macro.escape(time))
      converted = BACnetTime.from_time(time)

      assert converted == %BACnetTime{
               hour: 12,
               minute: 34,
               second: 56,
               hundredth: unquote(hundredth)
             }

      assert BACnetTime.valid?(converted)
    end
  end

  test "unspecified hundredths use the reference time truncated to hundredth resolution" do
    pattern = %BACnetTime{hour: 12, minute: 34, second: 56, hundredth: :unspecified}

    for {reference, expected} <- [
          {~T[00:00:00.5], ~T[12:34:56.500000]},
          {~T[00:00:00.500], ~T[12:34:56.500000]},
          {~T[00:00:00.500000], ~T[12:34:56.500000]},
          {~T[00:00:00.123456], ~T[12:34:56.120000]},
          {~T[00:00:00.009999], ~T[12:34:56]}
        ] do
      assert {:ok, ^expected} = BACnetTime.to_time(pattern, reference)
      assert BACnetTime.to_time!(pattern, reference) == expected
    end
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
