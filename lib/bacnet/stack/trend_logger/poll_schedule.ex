defmodule BACnet.Stack.TrendLogger.PollSchedule do
  @moduledoc false

  # All four standard boundaries divide a day. For intervals that divide one of
  # them, counting from local midnight gives the same phase as the smallest
  # applicable boundary (second, minute, hour, or day).
  @day_hundredths 8_640_000

  @spec interval(non_neg_integer()) :: pos_integer()
  def interval(0), do: 1000
  def interval(hundredths), do: hundredths * 10

  # A nil phase means ordinary, relative polling. The standard does not specify
  # an alignment boundary for intervals that do not divide any of the four units.
  @spec alignment(map()) :: non_neg_integer() | nil
  def alignment(object)

  def alignment(%{align_intervals: true, log_interval: interval, interval_offset: offset})
      when is_integer(interval) and interval > 0 and rem(@day_hundredths, interval) == 0 do
    rem(offset || 0, interval)
  end

  def alignment(_object), do: nil

  @spec delay(map(), DateTime.t()) :: pos_integer()
  def delay(%{log_interval: interval} = object, %DateTime{} = now) do
    case alignment(object) do
      nil ->
        interval(interval)

      offset ->
        period_us = interval * 10_000

        elapsed_us =
          (now.hour * 3600 + now.minute * 60 + now.second) * 1_000_000 +
            elem(now.microsecond, 0)

        # Choose a strictly future boundary, and round up to milliseconds so
        # timer quantization cannot start acquisition before that boundary.
        delay_us = period_us - Integer.mod(elapsed_us - offset * 10_000, period_us)
        div(delay_us + 999, 1000)
    end
  end
end
