defmodule BACnet.Protocol.CalendarEntry do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.DateRange
  alias BACnet.Protocol.WeekNDay

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
