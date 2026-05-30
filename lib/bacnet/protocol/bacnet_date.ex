defmodule BACnet.Protocol.BACnetDate do
  @moduledoc """
  A BACnet Date is a structured value that can represent either a specific calendar
  date or a *date pattern* containing wildcards and special values. It is one of the
  fundamental data types in BACnet (application tag 10) and is used pervasively for
  schedules, calendars, trend-log time ranges, and event timestamps.

  Each of the four components (year, month, day, weekday) may be a concrete value or
  one of the special atoms `:unspecified`, `:even`, or `:odd` (plus `:last` for day).
  When any component is a special value the date acts as a pattern that can match
  many actual dates. A completely unspecified date (all fields `:unspecified`) is
  interpreted as "don't care / match anything".

  ### BACnet Specification References

  - **Encoding**: ASHRAE 135-2012 Clause 20.2.12. Four contents octets:
    year-1900, month (January=1), day-of-month, weekday (Monday=1). Any octet may be
    0xFF to indicate "unspecified".
  - **Special pattern values** (Clause 20.2.12): month 13=odd months, 14=even months;
    day 32=last day of month, 33=odd days, 34=even days. These **shall not** be used
    when conveying an actual date (e.g. the Device object's `Local_Date` or a
    TimeSynchronization-Request).
  - **ASN.1 production** (Clause 21): `Date ::= [APPLICATION 10] OCTET STRING (SIZE(4))`
    (with comments describing the special values above).
  - **Primary usage contexts**: `date_list` property of Calendar objects (12.9),
    `exception_schedule` of Schedule objects (12.24), `start_time`/`stop_time` in
    ReadRange requests, Event Timestamps, and many "last changed" properties.

  This module supplies ergonomic conversion helpers to and from Elixir `Date` while
  correctly handling the pattern semantics via a reference date.

  ### Examples

  #### Specific date

  ```elixir
  iex> date = %BACnetDate{year: 2024, month: 12, day: 25, weekday: 3}
  iex> BACnetDate.specific?(date)
  true
  iex> BACnetDate.to_date!(date)
  ~D[2024-12-25]
  ```

  #### Wildcard / pattern date (e.g. "every Christmas")

  ```elixir
  iex> christmas = %BACnetDate{year: :unspecified, month: 12, day: 25, weekday: :unspecified}
  iex> BACnetDate.specific?(christmas)
  false
  iex> BACnetDate.to_date!(christmas, ~D[2025-06-01])
  ~D[2025-12-25]
  ```

  #### Even/odd patterns

  ```elixir
  iex> even_months = %BACnetDate{year: 2025, month: :even, day: 1, weekday: :unspecified}
  iex> BACnetDate.to_date!(even_months, ~D[2025-03-15])
  ~D[2025-02-01]
  ```

  #### Edge cases

  Day overflow falls back to the end of the month:

  ```elixir
  iex> feb30 = %BACnetDate{year: 2025, month: 2, day: 30, weekday: :unspecified}
  iex> BACnetDate.to_date!(feb30, ~D[2025-01-01])
  ~D[2025-02-28]
  ```

  `day: :last` counts as specific (as long as the other components are concrete values):

  ```elixir
  iex> last_day = %BACnetDate{year: 2025, month: 2, day: :last, weekday: 5}
  iex> BACnetDate.specific?(last_day)
  true
  iex> BACnetDate.to_date!(last_day, ~D[2025-01-01])
  ~D[2025-02-28]
  ```

  > #### Warning {: .warning}
  >
  > Per the BACnet specification, pattern dates (any special values) **shall not**
  > be used when conveying actual dates, such as the Device object's `Local_Date`
  > or in TimeSynchronization requests.

  ### See Also
  - `BACnet.Protocol.BACnetDateTime`
  - `BACnet.Protocol.BACnetTime`
  - `BACnet.Protocol.BACnetTimestamp`
  - `BACnet.Protocol.DateRange`
  - `BACnet.Protocol.WeekNDay`
  """

  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags

  @typedoc """
  Represents a BACnet Date (application tag 10).

  - `year`    - 1900-2154 or `:unspecified` (0xFF in encoding)
  - `month`   - 1-12, `:even`, `:odd`, or `:unspecified`
  - `day`     - 1-31, `:even`, `:odd`, `:last`, or `:unspecified`
  - `weekday` - 1 (Monday) … 7 (Sunday) or `:unspecified`

  The special atoms create *date patterns*. A pattern matches any concrete date
  whose corresponding component satisfies the rule (e.g. `month: :odd` matches
  January, March, …). See `specific?/1` and the conversion functions for how
  patterns are resolved against a reference date.
  """
  @type t :: %__MODULE__{
          year: 1900..2154 | :unspecified,
          month: 1..12 | :even | :odd | :unspecified,
          day: 1..31 | :even | :odd | :last | :unspecified,
          weekday: 1..7 | :unspecified
        }

  @fields [
    :year,
    :month,
    :day,
    :weekday
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Compares two BACnet Date.

  Returns `:gt` if first date is later than the second,
  and `:lt` for vice versa.
  If the two dates are equal, `:eq` is returned.

  Note that this is achieved by converting to `Date` and then
  comparing them.
  """
  @spec compare(t(), t()) :: :gt | :eq | :lt
  def compare(%__MODULE__{} = date1, %__MODULE__{} = date2) do
    Date.compare(to_date!(date1), to_date!(date2))
  end

  @doc """
  Encodes the given BACnet Date into an application tag.
  """
  @spec encode(t(), Keyword.t()) :: {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = date, _opts \\ []) do
    {:ok, [{:date, date}]}
  end

  @doc """
  Converts a `Date` to a BACnet Date.
  """
  @spec from_date(Date.t()) :: t()
  def from_date(%Date{} = date) when date.year >= 1900 and date.year <= 2154 do
    %__MODULE__{
      year: date.year,
      month: date.month,
      day: date.day,
      weekday: Date.day_of_week(date, :monday)
    }
  end

  @doc """
  Parses a BACnet Date from BACnet application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}} | {:error, term}
  def parse(tags) when is_list(tags) do
    case tags do
      [{:date, %__MODULE__{} = date} | rest] ->
        {:ok, {date, rest}}

      _else ->
        {:error, :invalid_tags}
    end
  end

  @doc """
  Checks whether the given BACnet Date is a specific date value
  (every component is a numeric value; `day: :last` counts as specific).
  """
  @spec specific?(t()) :: boolean()
  def specific?(%__MODULE__{} = time) do
    case time do
      %{year: :unspecified} -> false
      %{month: :unspecified} -> false
      %{month: :even} -> false
      %{month: :odd} -> false
      %{day: :unspecified} -> false
      %{day: :even} -> false
      %{day: :odd} -> false
      %{weekday: :unspecified} -> false
      _else -> true
    end
  end

  @doc """
  Converts the BACnet Date to a `Date`.

  If any of the fields are unspecified, the reference date (current UTC value) is used.
  In case of even or odd, either the current or the previous value of the reference date is used.
  """
  @spec to_date(t(), Date.t()) :: {:ok, Date.t()} | {:error, term()}
  def to_date(%__MODULE__{} = date, ref_date \\ Date.utc_today()) do
    month = get_month(date, ref_date)
    day = get_day(date, ref_date, month)
    year = get_year(date, ref_date)

    edate =
      with {:error, :invalid_date} <- Date.new(year, month, day) do
        # Invalid date, probably due to calendar month "day overflow" - use end of month
        {:ok, Date.end_of_month(Date.new!(year, month, 1))}
      end

    with {:ok, edate} <- edate do
      # Handle now even and odd days
      {:ok, date_handle_even_odd(date, edate)}
    end
  end

  @doc """
  Bang-version of `to_date/1`.
  """
  @spec to_date!(t(), Date.t()) :: Date.t() | no_return()
  def to_date!(%__MODULE__{} = date, ref_date \\ Date.utc_today()) do
    month = get_month(date, ref_date)
    day = get_day(date, ref_date, month)
    year = get_year(date, ref_date)

    edate =
      case Date.new(year, month, day) do
        {:ok, date} -> date
        # Invalid date, probably due to calendar month "day overflow" - use end of month
        {:error, :invalid_date} -> Date.end_of_month(Date.new!(year, month, 1))
      end

    # Handle now even and odd days
    date_handle_even_odd(date, edate)
  end

  @doc """
  Creates a new BACnet Date with the current UTC date.
  """
  @spec utc_today() :: t()
  def utc_today() do
    from_date(Date.utc_today())
  end

  @doc """
  Validates whether the given BACnet date is in form valid.

  It only validates the struct is valid as per type specification,
  it does not validate that the day matches the weekday.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          year: year,
          month: month,
          day: day,
          weekday: weekday
        } = _t
      )
      when (year in 1900..2154 or year == :unspecified) and
             (month in 1..12 or month in [:unspecified, :even, :odd]) and
             (day in 1..31 or day in [:unspecified, :even, :odd, :last]) and
             (weekday in 1..7 or weekday == :unspecified),
      do: true

  def valid?(%__MODULE__{} = _t), do: false

  defp get_year(%__MODULE__{year: :unspecified}, %Date{} = utc_now), do: utc_now.year
  defp get_year(%__MODULE__{year: year}, _utc_now), do: year

  defp get_month(%__MODULE__{month: :unspecified}, %Date{} = utc_now), do: utc_now.month

  defp get_month(%__MODULE__{month: :even}, %Date{} = utc_now),
    do:
      if(rem(utc_now.month, 2) == 0,
        do: utc_now.month,
        else: if(utc_now.month == 1, do: 12, else: utc_now.month - 1)
      )

  defp get_month(%__MODULE__{month: :odd}, %Date{} = utc_now),
    do: if(rem(utc_now.month, 2) != 0, do: utc_now.month, else: utc_now.month - 1)

  defp get_month(%__MODULE__{month: month}, _utc_now), do: month

  defp get_day(%__MODULE__{day: :unspecified}, %Date{} = utc_now, _month), do: utc_now.day

  defp get_day(%__MODULE__{day: :even}, %Date{} = utc_now, _month),
    do: utc_now.day

  defp get_day(%__MODULE__{day: :odd}, %Date{} = utc_now, _month),
    do: utc_now.day

  defp get_day(%__MODULE__{day: :last}, %Date{} = utc_now, month),
    do: Date.end_of_month(Date.new!(utc_now.year, month, 1)).day

  defp get_day(%__MODULE__{day: day}, _utc_now, _month), do: day

  defp date_handle_even_odd(%__MODULE__{} = date, %Date{} = edate) do
    if (date.day == :even and rem(edate.day, 2) != 0) or
         (date.day == :odd and rem(edate.day, 2) == 0) do
      Date.add(edate, -1)
    else
      edate
    end
  end
end
