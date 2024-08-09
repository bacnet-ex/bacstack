defmodule BACnet.Protocol.DateRange do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDate

  @typedoc """
  Represents a BACnet Date Range.
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
    if is_date_specific_enough_for_date_range(date_range.start_date) and
         is_date_specific_enough_for_date_range(date_range.end_date) do
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
      is_valid_date_range(start_date, end_date)
  end

  def valid?(%__MODULE__{} = _t), do: false

  @spec is_valid_date_range(BACnetDate.t(), BACnetDate.t()) :: boolean()
  defp is_valid_date_range(%BACnetDate{} = start_date, %BACnetDate{} = end_date) do
    {any1, all1} = is_date_any_unspecified(start_date)
    {any2, all2} = is_date_any_unspecified(end_date)

    # ASHRAE 135-2012: A date may be unspecific or a specific date only
    (not any1 and not any2 and BACnetDate.compare(start_date, end_date) != :gt) or
      (all1 and all2) or
      (all1 and not any2) or
      (all2 and not any1)
  end

  @date_keys Map.keys(Map.from_struct(BACnetDate.__struct__()))

  defp is_date_any_unspecified(%BACnetDate{
         unquote_splicing(Enum.map(@date_keys, &{&1, :unspecified}))
       }),
       do: {true, true}

  for key <- @date_keys do
    defp is_date_any_unspecified(%BACnetDate{unquote(key) => :unspecified}), do: {true, false}
  end

  defp is_date_any_unspecified(%BACnetDate{month: :odd}), do: {true, false}
  defp is_date_any_unspecified(%BACnetDate{month: :even}), do: {true, false}
  defp is_date_any_unspecified(%BACnetDate{day: :odd}), do: {true, false}
  defp is_date_any_unspecified(%BACnetDate{day: :even}), do: {true, false}
  defp is_date_any_unspecified(%BACnetDate{} = _date), do: {false, false}

  defp is_date_specific_enough_for_date_range(%BACnetDate{
         year: year,
         month: mon,
         day: day,
         weekday: _any
       })
       when is_integer(year) and is_integer(mon) and (is_integer(day) or day == :last),
       do: true

  defp is_date_specific_enough_for_date_range(%BACnetDate{} = _date), do: false
end
