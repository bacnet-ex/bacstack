defmodule BACnet.Protocol.WeekNDay do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags

  @typedoc """
  Represents a BACnet Week And Day, which can have unspecified (= any) or even/odd values.

  Week of month specifies which week of the month:
  - `1` - Days numbered 1-7
  - `2` - Days numbered 8-14
  - `3` - Days numbered 15-21
  - `4` - Days numbered 22-28
  - `5` - Days numbered 29-31
  - `6` - Last 7 days of this month

  Weekday specifies the day of the week, starting with monday to sunday (1-7).
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
