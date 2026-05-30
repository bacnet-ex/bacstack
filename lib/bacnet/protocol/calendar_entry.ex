defmodule BACnet.Protocol.CalendarEntry do
  @moduledoc """
  A Calendar Entry is the CHOICE type used by both Calendar objects and Schedule
  objects to describe "special" days (holidays, maintenance periods, after-hours
  operation, etc.).

  The three alternatives (defined in Clause 21) are:
  - `:date`       - a single specific (or partially unspecified) `BACnet.Protocol.BACnetDate`
  - `:date_range` - an inclusive `BACnet.Protocol.DateRange`
  - `:week_n_day` - a recurring `BACnet.Protocol.WeekNDay` pattern

  This single type is deliberately reused in multiple places so that matching
  logic ("does today match any exception?") can be written once.

  ### BACnet Specification References
  - **ASN.1** (Clause 21):
    ```
    BACnetCalendarEntry ::= CHOICE {
        date       Date,
        dateRange  BACnetDateRange,
        weekNDay   BACnetWeekNDay
    }
    ```
  - **Calendar object** (12.9): `date_list` property is `BACnetARRAY` of `BACnet.Protocol.CalendarEntry`.
  - **Schedule object** (12.24): `exception_schedule` contains `BACnet.Protocol.SpecialEvent`
    whose `period` can be a `BACnet.Protocol.CalendarEntry` or an object identifier referencing
    a Calendar object.

  ### Examples

  #### Specific date entry

  ```elixir
  iex> entry = %CalendarEntry{type: :date, date: %BACnetDate{year: 2025, month: 12, day: 25, weekday: 4}, date_range: nil, week_n_day: nil}
  iex> entry.type
  :date
  ```

  #### Date range entry

  ```elixir
  iex> entry = %CalendarEntry{type: :date_range, date_range: %DateRange{start_date: %BACnetDate{year: 2025, month: 7, day: 1, weekday: 2}, end_date: %BACnetDate{year: 2025, month: 7, day: 31, weekday: 4}}, date: nil, week_n_day: nil}
  iex> entry.type
  :date_range
  ```

  #### Recurring WeekNDay entry

  ```elixir
  iex> entry = %CalendarEntry{type: :week_n_day, week_n_day: %WeekNDay{month: :unspecified, week_of_month: 3, weekday: 2}, date: nil, date_range: nil}
  iex> entry.type
  :week_n_day
  ```

  ### See Also
  - `BACnet.Protocol.DailySchedule`
  - `BACnet.Protocol.DateRange`
  - `BACnet.Protocol.DaysOfWeek`
  - `BACnet.Protocol.SpecialEvent`
  - `BACnet.Protocol.WeekNDay`
  """

  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.DateRange
  alias BACnet.Protocol.WeekNDay

  @typedoc """
  CHOICE of a single date, date range, or `BACnet.Protocol.WeekNDay` pattern
  (see `BACnet.Protocol.CalendarEntry` module docs + ASN.1 in Clause 21).
  Used in Calendar `date_list` and Schedule exception schedules.
  """
  @type t :: %__MODULE__{
          type: :date | :date_range | :week_n_day,
          date: BACnetDate.t() | nil,
          date_range: DateRange.t() | nil,
          week_n_day: WeekNDay.t() | nil
        }

  @fields [:type, :date, :date_range, :week_n_day]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encode a calendar entry into application tag-encoded.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(entry, opts \\ [])

  def encode(%__MODULE__{type: :date, date: %BACnetDate{} = date} = _entry, opts) do
    with {:ok, date, _header} <- ApplicationTags.encode_value({:date, date}, opts) do
      {:ok, [{:tagged, {0, date, byte_size(date)}}]}
    end
  end

  def encode(
        %__MODULE__{
          type: :date_range,
          date_range: %DateRange{
            start_date: %BACnetDate{} = start_date,
            end_date: %BACnetDate{} = end_date
          }
        } = _entry,
        _opts
      ) do
    {:ok,
     [
       {:constructed,
        {1,
         [
           date: start_date,
           date: end_date
         ], 0}}
     ]}
  end

  def encode(%__MODULE__{type: :week_n_day, week_n_day: %WeekNDay{} = week_n_day} = _entry, _opts) do
    with {:ok, [{:octet_string, str}]} <- WeekNDay.encode(week_n_day) do
      {:ok, [{:tagged, {2, str, 3}}]}
    end
  end

  @doc """
  Parse application tag-encoded calendar entry into a struct.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [{:tagged, {0, tags, _len}} | rest] ->
        with {:ok, {:date, date}} <- ApplicationTags.unfold_to_type(:date, tags) do
          cal = %__MODULE__{
            type: :date,
            date: date,
            date_range: nil,
            week_n_day: nil
          }

          {:ok, {cal, rest}}
        end

      [
        {:constructed,
         {1,
          [
            {:date, start_date},
            {:date, end_date}
          ], _len}}
        | rest
      ] ->
        cal = %__MODULE__{
          type: :date_range,
          date: nil,
          date_range: %DateRange{
            start_date: start_date,
            end_date: end_date
          },
          week_n_day: nil
        }

        {:ok, {cal, rest}}

      [{:tagged, {2, str, _len}} | rest] ->
        with {:ok, {week, _rest}} <- WeekNDay.parse([{:octet_string, str}]) do
          cal = %__MODULE__{
            type: :week_n_day,
            date: nil,
            date_range: nil,
            week_n_day: week
          }

          {:ok, {cal, rest}}
        end

      _term ->
        {:error, :invalid_tags}
    end
  end

  @doc """
  Validates whether the given BACnet calendar entry is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(t)

  def valid?(
        %__MODULE__{
          type: :date,
          date: %BACnetDate{} = date
        } = _t
      ) do
    BACnetDate.valid?(date)
  end

  def valid?(
        %__MODULE__{
          type: :date_range,
          date_range: %DateRange{} = range
        } = _t
      ) do
    DateRange.valid?(range)
  end

  def valid?(
        %__MODULE__{
          type: :week_n_day,
          week_n_day: %WeekNDay{} = week
        } = _t
      ) do
    WeekNDay.valid?(week)
  end

  def valid?(%__MODULE__{} = _t), do: false
end
