defmodule BACnet.Protocol.WeekNDay do
  @moduledoc """
  A WeekNDay (Week And Day) is a compact 3-component pattern used inside
  `BACnet.Protocol.CalendarEntry` and `BACnet.Protocol.SpecialEvent` to describe
  recurring days without listing every date.
  Classic examples: "the third Tuesday of every month", "every even week on Friday",
  or "the last Sunday in odd months".

  It is one of BACnet's most powerful yet bandwidth-efficient calendar primitives.

  ### BACnet Specification References
  - **ASN.1** (Clause 21):
    ```
    BACnetWeekNDay ::= SEQUENCE {
        month       (1..12 | 13 | 14 | 255),  -- 13=odd, 14=even, 255=unspecified
        weekOfMonth (1..6 | 255),             -- 6 = last 7 days, 255=unspecified
        dayOfWeek   (1..7 | 255)
    }
    ```
  - **Primary usage** (Clause 12.9 Calendar, 12.24 Schedule):
    - Inside `BACnet.Protocol.CalendarEntry` (as one of the three CHOICE alternatives)
    - Inside `BACnet.Protocol.SpecialEvent` for exception schedules
    - Combined with `BACnet.Protocol.DaysOfWeek` in destinations and notification rules

  The week-of-month numbering (1 = days 1-7, 6 = last 7 days of month) is defined
  in the production comments and is independent of the actual calendar month length.

  ### Examples

  #### "Third Tuesday of every month"

  ```elixir
  iex> pattern = %WeekNDay{month: :unspecified, week_of_month: 3, weekday: 2}
  iex> pattern.week_of_month
  3
  ```

  #### "Last Sunday in December"

  ```elixir
  iex> last_sunday_dec = %WeekNDay{month: 12, week_of_month: 6, weekday: 7}
  iex> last_sunday_dec.week_of_month
  6
  ```

  #### Edge cases

  Week 6 always means the *last* 7 days of the month, regardless of length:

  ```elixir
  iex> feb_last = %WeekNDay{month: 2, week_of_month: 6, weekday: 1}  # last Monday in Feb
  iex> feb_last.week_of_month
  6
  ```

  When used inside a CalendarEntry or SpecialEvent, it can match the last few days even in short months (Feb 23-28 can be "week 6").

  ### See Also
  - `BACnet.Protocol.CalendarEntry`
  - `BACnet.Protocol.DailySchedule`
  - `BACnet.Protocol.DateRange`
  - `BACnet.Protocol.DaysOfWeek`
  - `BACnet.Protocol.SpecialEvent`
  """

  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags

  @typedoc """
  Compact recurring-day pattern (see `BACnet.Protocol.WeekNDay` module docs for full semantics
  and ASN.1 production). Month and week support the same even/odd/unspecified
  wildcards as `BACnet.Protocol.BACnetDate`.
  """
  @type t :: %__MODULE__{
          month: 1..12 | :even | :odd | :unspecified,
          week_of_month: 1..6 | :unspecified,
          weekday: 1..7 | :unspecified
        }

  @fields [
    :month,
    :week_of_month,
    :weekday
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encodes a BACnet week and day into application tags encoding.
  """
  @spec encode(t(), Keyword.t()) :: {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = week, _opts \\ []) do
    month =
      case week.month do
        :unspecified -> 255
        :even -> 14
        :odd -> 13
        _else -> week.month
      end

    str = <<month, item_to_int(week.week_of_month), item_to_int(week.weekday)>>
    {:ok, [{:octet_string, str}]}
  end

  @doc """
  Parses a BACnet week and day from application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}} | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [
        {:octet_string, <<month, week_of_month, weekday>>}
        | rest
      ]
      when (month in 1..14 or month == 255) and (week_of_month in 1..6 or week_of_month == 255) and
             (weekday in 1..7 or weekday == 255) ->
        week = %__MODULE__{
          month:
            case month do
              255 -> :unspecified
              14 -> :even
              13 -> :odd
              _else -> month
            end,
          week_of_month:
            case week_of_month do
              255 -> :unspecified
              _else -> week_of_month
            end,
          weekday:
            case weekday do
              255 -> :unspecified
              _else -> weekday
            end
        }

        {:ok, {week, rest}}

      _else ->
        {:error, :invalid_tags}
    end
  end

  @doc """
  Validates whether the given BACnet week and day is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          month: month,
          week_of_month: week,
          weekday: weekday
        } = _t
      )
      when (month in 1..12 or month in [:even, :odd, :unspecified]) and
             (week in 1..6 or week == :unspecified) and
             (weekday in 1..7 or weekday == :unspecified),
      do: true

  def valid?(%__MODULE__{} = _t), do: false

  defp item_to_int(:unspecified), do: 255
  defp item_to_int(term), do: term
end
