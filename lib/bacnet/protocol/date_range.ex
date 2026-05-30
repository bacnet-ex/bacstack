defmodule BACnet.Protocol.DateRange do
  @moduledoc """
  A Date Range defines an inclusive period bounded by a start `BACnet.Protocol.BACnetDate` and
  an end `BACnet.Protocol.BACnetDate`. It is one of the three CHOICE alternatives inside
  `BACnet.Protocol.CalendarEntry` (alongside a specific `BACnet.Protocol.BACnetDate` and
  a `BACnet.Protocol.WeekNDay` pattern).

  Date ranges are the natural way to express holiday blocks, maintenance windows,
  or temporary schedule overrides that span multiple consecutive days.

  ### BACnet Specification References
  - **ASN.1** (Clause 21): `BACnetDateRange ::= SEQUENCE { startDate Date, endDate Date }`
  - **Usage** (Clause 12):
    - `date_list` property of Calendar objects (as `BACnet.Protocol.CalendarEntry` CHOICE)
    - `exception_schedule` of Schedule objects (as `BACnet.Protocol.SpecialEvent.period`)
    - `ReadRange` "by time" requests (start/stop as date+time)
  - Both endpoints are inclusive.

  This module also provides a small helper to convert a fully-specified range
  into an Elixir `Date.Range` for easier processing.

  ### Examples

  ```elixir
  iex> range = %DateRange{
  ...>   start_date: %BACnetDate{year: 2025, month: 6, day: 1, weekday: 7},
  ...>   end_date: %BACnetDate{year: 2025, month: 6, day: 30, weekday: 1}
  ...> }
  iex> {:ok, elixir_range} = DateRange.get_date_range(range)
  iex> elixir_range.first
  ~D[2025-06-01]
  ```

  ### See Also
  - `BACnet.Protocol.CalendarEntry`
  - `BACnet.Protocol.DaysOfWeek`
  - `BACnet.Protocol.ReadRange`
  - `BACnet.Protocol.SpecialEvent`
  - `BACnet.Protocol.WeekNDay`
  """

  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDate

  @typedoc """
  Inclusive start/end date pair used inside `BACnet.Protocol.CalendarEntry` and `BACnet.Protocol.SpecialEvent`
  (and for ReadRange by time). Dates may contain wildcards.
  """
  @type t :: %__MODULE__{
          start_date: BACnetDate.t(),
          end_date: BACnetDate.t()
        }

  @fields [
    :start_date,
    :end_date
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Get a `Date.Range` struct for this date range. Only specific dates are allowed.
  """
  @spec get_date_range(t()) :: {:ok, Date.Range.t()} | {:error, term()}
  def get_date_range(%__MODULE__{} = date_range) do
    if date_specific_enough_for_date_range?(date_range.start_date) and
         date_specific_enough_for_date_range?(date_range.end_date) do
      with {:ok, start_date} <- BACnetDate.to_date(date_range.start_date),
           {:ok, end_date} <- BACnetDate.to_date(date_range.end_date) do
        {:ok, Date.range(start_date, end_date)}
      end
    else
      {:error, :invalid_date_range}
    end
  end

  @doc """
  Encodes a BACnet date range into BACnet application tags encoding.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = date_range, _opts \\ []) do
    params = [
      {:date, date_range.start_date},
      {:date, date_range.end_date}
    ]

    {:ok, params}
  end

  @doc """
  Parses a BACnet date range from BACnet application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [
        {:date, start_date},
        {:date, end_date}
        | rest
      ] ->
        range = %__MODULE__{
          start_date: start_date,
          end_date: end_date
        }

        {:ok, {range, rest}}

      _else ->
        {:error, :invalid_tags}
    end
  end

  @doc """
  Validates whether the given BACnet date range is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          start_date: %BACnetDate{} = start_date,
          end_date: %BACnetDate{} = end_date
        } = _t
      ) do
    BACnetDate.valid?(start_date) and BACnetDate.valid?(end_date) and
      valid_date_range?(start_date, end_date)
  end

  def valid?(%__MODULE__{} = _t), do: false

  @spec valid_date_range?(BACnetDate.t(), BACnetDate.t()) :: boolean()
  defp valid_date_range?(%BACnetDate{} = start_date, %BACnetDate{} = end_date) do
    {any1, all1} = date_any_unspecified?(start_date)
    {any2, all2} = date_any_unspecified?(end_date)

    # ASHRAE 135-2012: A date may be unspecific or a specific date only
    (not any1 and not any2 and BACnetDate.compare(start_date, end_date) != :gt) or
      (all1 and all2) or
      (all1 and not any2) or
      (all2 and not any1)
  end

  @date_keys Map.keys(Map.from_struct(BACnetDate.__struct__()))

  defp date_any_unspecified?(%BACnetDate{
         unquote_splicing(Enum.map(@date_keys, &{&1, :unspecified}))
       }),
       do: {true, true}

  for key <- @date_keys do
    defp date_any_unspecified?(%BACnetDate{unquote(key) => :unspecified}), do: {true, false}
  end

  defp date_any_unspecified?(%BACnetDate{month: :odd}), do: {true, false}
  defp date_any_unspecified?(%BACnetDate{month: :even}), do: {true, false}
  defp date_any_unspecified?(%BACnetDate{day: :odd}), do: {true, false}
  defp date_any_unspecified?(%BACnetDate{day: :even}), do: {true, false}
  defp date_any_unspecified?(%BACnetDate{} = _date), do: {false, false}

  defp date_specific_enough_for_date_range?(%BACnetDate{
         year: year,
         month: mon,
         day: day,
         weekday: _any
       })
       when is_integer(year) and is_integer(mon) and (is_integer(day) or day == :last),
       do: true

  defp date_specific_enough_for_date_range?(%BACnetDate{} = _date), do: false
end
