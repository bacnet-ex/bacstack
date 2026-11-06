defmodule BACnet.Stack.TrendLogger.PollScheduleTest do
  alias BACnet.Stack.TrendLogger.PollSchedule

  use ExUnit.Case, async: true

  @moduletag :stack
  @moduletag :trend_logger

  test "intervals use hundredths of a second, with a one-second zero default" do
    assert PollSchedule.interval(1) == 10
    assert PollSchedule.interval(100) == 1000
    assert PollSchedule.interval(90_000) == 900_000
    assert PollSchedule.interval(0) == 1000
  end

  test "second, minute, hour and day factors use their local clock boundaries" do
    now = ~U[2026-11-06 12:34:56.123456Z]

    assert delay(25, 0, now) == 127
    assert delay(150, 0, now) == 877
    assert delay(90_000, 0, now) == 603_877
    assert delay(4_320_000, 0, now) == 41_103_877
    assert delay(8_640_000, 0, now) == 41_103_877
  end

  test "quarter-hour samples use the offset modulo the interval" do
    now = ~U[2026-11-06 12:14:50Z]

    assert delay(90_000, 0, now) == 10_000
    assert delay(90_000, 3_000, now) == 40_000
    assert delay(90_000, 93_000, now) == 40_000
    assert delay(30, 31, ~U[2026-11-06 12:00:00Z]) == 10
    assert delay(90_000, 3_000, ~U[2026-11-06 00:00:10Z]) == 20_000
  end

  test "exact boundaries advance and fractional milliseconds never acquire early" do
    assert delay(90_000, 3_000, ~U[2026-11-06 12:15:30Z]) == 900_000
    assert delay(90_000, 3_000, ~U[2026-11-06 12:15:29.999999Z]) == 1
    assert delay(90_000, 3_000, ~U[2026-11-06 12:15:30.000001Z]) == 900_000
    assert delay(1, 0, ~U[2026-11-06 23:59:59.999999Z]) == 1
  end

  test "midnight rollover and delayed acquisition keep the clock phase" do
    assert delay(90_000, 0, ~U[2026-11-06 23:59:50Z]) == 10_000
    assert delay(90_000, 3_000, ~U[2026-11-06 23:59:50Z]) == 40_000
    assert delay(90_000, 0, ~U[2026-11-07 00:17:00Z]) == 780_000
  end

  test "alignment follows local time even with a fractional-hour UTC offset" do
    # Same instant as 12:00 UTC, expressed in a zone with a +05:45 offset.
    now = %{
      ~U[2026-11-06 12:00:00Z]
      | hour: 17,
        minute: 45,
        utc_offset: 20_700,
        time_zone: "Test/Local",
        zone_abbr: "LOCAL"
    }

    assert delay(360_000, 0, now) == 900_000
    assert delay(8_640_000, 0, now) == 22_500_000
  end

  test "absent or disabled alignment and unsupported intervals use relative polling" do
    now = ~U[2026-11-06 12:14:50Z]

    assert PollSchedule.delay(%{log_interval: 100}, now) == 1000

    assert PollSchedule.delay(
             %{log_interval: 90_000, align_intervals: false, interval_offset: 3_000},
             now
           ) == 900_000

    assert delay(7, 1, now) == 70
    assert delay(8_640_001, 1, now) == 86_400_010
    assert delay(0, 31, now) == 1000
  end

  defp delay(interval, offset, now) do
    PollSchedule.delay(
      %{log_interval: interval, align_intervals: true, interval_offset: offset},
      now
    )
  end
end
