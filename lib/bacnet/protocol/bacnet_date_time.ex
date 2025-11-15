defmodule BACnet.Protocol.BACnetDateTime do
  @moduledoc """
  A BACnet DateTime is used to represent date with timepoints.
  It wraps both `BACnetDate` and `BACnetTime`.

  This module provides some helpers to convert `DateTime` and `NaiveDateTime`
  into a `BACnetDateTime` and back.
  """

  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetTime

  @typedoc """
  Represents a BACnet DateTime. It wraps both BACnet Date and Time.
  """
  @type t :: %__MODULE__{
          date: BACnetDate.t(),
          time: BACnetTime.t()
        }

  @fields [
    :date,
    :time
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Compares two BACnet DateTime.

  Returns `:gt` if first datetime is later than the second,
  and `:lt` for vice versa.
  If the two datetimes are equal, `:eq` is returned.

  Note that this is achieved by converting to `DateTime` and then
  comparing them.
  """
  @spec compare(t(), t()) :: :gt | :eq | :lt
  def compare(%__MODULE__{} = dt1, %__MODULE__{} = dt2) do
    DateTime.compare(to_datetime!(dt1), to_datetime!(dt2))
  end

  @doc """
  Encodes the given BACnet DateTime into an application tag.

  For tagged encoding, you'll have to strip this down further
  using manual efforts.
  """
  @spec encode(t(), Keyword.t()) :: {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = dt, _opts \\ []) do
    {:ok, [{:date, dt.date}, {:time, dt.time}]}
  end

  @doc """
  Converts a `DateTime` to a BACnet DateTime.
  """
  @spec from_datetime(DateTime.t()) :: t()
  def from_datetime(%DateTime{} = dt) do
    %__MODULE__{
      date: BACnetDate.from_date(DateTime.to_date(dt)),
      time: BACnetTime.from_time(DateTime.to_time(dt))
    }
  end

  @doc """
  Converts a `NaiveDateTime` to a BACnet DateTime.
  """
  @spec from_naive_datetime(NaiveDateTime.t()) :: t()
  def from_naive_datetime(%NaiveDateTime{} = dt) do
    %__MODULE__{
      date: BACnetDate.from_date(NaiveDateTime.to_date(dt)),
      time: BACnetTime.from_time(NaiveDateTime.to_time(dt))
    }
  end

  @doc """
  Parses a BACnet DateTime from BACnet application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}} | {:error, term}
  def parse(tags) when is_list(tags) do
    with [{:date, %BACnetDate{} = date}, {:time, %BACnetTime{} = time} | rest] <- tags do
      dt = %__MODULE__{
        date: date,
        time: time
      }

      {:ok, {dt, rest}}
    else
      _else -> {:error, :invalid_tags}
    end
  end

  @doc """
  Checks whether the given BACnet DateTime is a specific date-time value
  (every component is a numeric value).
  """
  @spec specific?(t()) :: boolean()
  def specific?(%__MODULE__{} = dt) do
    BACnetDate.specific?(dt.date) and BACnetTime.specific?(dt.time)
  end

  @doc """
  Converts the BACnet DateTime to a `DateTime`.
  """
  @spec to_datetime(t(), Calendar.time_zone(), Calendar.time_zone_database()) ::
          {:ok, DateTime.t()} | {:error, term()}
  def to_datetime(
        %__MODULE__{} = dt,
        timezone \\ Application.get_env(:bacstack, :default_timezone, "Etc/UTC"),
        time_zone_database \\ Calendar.get_time_zone_database()
      ) do
    with {:ok, date} <- BACnetDate.to_date(dt.date),
         {:ok, time} <- BACnetTime.to_time(dt.time),
         do: DateTime.new(date, time, timezone, time_zone_database)
  end

  @doc """
  Bang-version of `to_datetime/1`.
  """
  @spec to_datetime!(t(), Calendar.time_zone(), Calendar.time_zone_database()) ::
          DateTime.t() | no_return()
  def to_datetime!(
        %__MODULE__{} = dt,
        timezone \\ Application.get_env(:bacstack, :default_timezone, "Etc/UTC"),
        time_zone_database \\ Calendar.get_time_zone_database()
      ) do
    date = BACnetDate.to_date!(dt.date)
    time = BACnetTime.to_time!(dt.time)
    DateTime.new!(date, time, timezone, time_zone_database)
  end

  @doc """
  Converts the BACnet DateTime to a `NaiveDateTime`.
  """
  @spec to_naive_datetime(t()) :: {:ok, NaiveDateTime.t()} | {:error, term()}
  def to_naive_datetime(%__MODULE__{} = dt) do
    with {:ok, date} <- BACnetDate.to_date(dt.date),
         {:ok, time} <- BACnetTime.to_time(dt.time),
         do: NaiveDateTime.new(date, time)
  end

  @doc """
  Bang-version of `to_naive_datetime/1`.
  """
  @spec to_naive_datetime!(t()) :: NaiveDateTime.t() | no_return()
  def to_naive_datetime!(%__MODULE__{} = dt) do
    date = BACnetDate.to_date!(dt.date)
    time = BACnetTime.to_time!(dt.time)
    NaiveDateTime.new!(date, time)
  end

  @doc """
  Creates a new BACnet DateTime for the current UTC datetime.
  """
  @spec utc_now() :: t()
  def utc_now() do
    %__MODULE__{
      date: BACnetDate.from_date(Date.utc_today()),
      time: BACnetTime.from_time(Time.utc_now())
    }
  end

  @doc """
  Validates whether the given BACnet datetime is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          date: %BACnetDate{} = date,
          time: %BACnetTime{} = time
        } = _t
      ) do
    BACnetDate.valid?(date) and BACnetTime.valid?(time)
  end

  def valid?(%__MODULE__{} = _t), do: false
end
