defmodule BACnet.Protocol.BACnetTime do
  @moduledoc """
  A BACnet Time is used to represent timepoints of the day, but also can represent
  unspecific timepoints, such as a single component being unspecified
  (i.e. can match anything in that component).

  This module provides some helpers to convert `Time` into a `BACnetTime` and back.
  """

  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags

  @typedoc """
  Represents a BACnet Time, which can have unspecified values (= any).

  One hundredth corresponds to 0.01 of a second.
  """
  @type t :: %__MODULE__{
          hour: 0..23 | :unspecified,
          minute: 0..59 | :unspecified,
          second: 0..59 | :unspecified,
          hundredth: 0..99 | :unspecified
        }

  @fields [
    :hour,
    :minute,
    :second,
    :hundredth
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Compares two BACnet Time.

  Returns `:gt` if first time is later than the second,
  and `:lt` for vice versa.
  If the two times are equal, `:eq` is returned.

  Note that this is achieved by converting to `Time` and then
  comparing them.
  """
  @spec compare(t(), t()) :: :gt | :eq | :lt
  def compare(%__MODULE__{} = time1, %__MODULE__{} = time2) do
    Time.compare(to_time!(time1), to_time!(time2))
  end

  @doc """
  Encodes the given BACnet Time into an application tag.
  """
  @spec encode(t(), Keyword.t()) :: {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = time, _opts \\ []) do
    {:ok, [{:time, time}]}
  end

  @doc """
  Converts a `Time` into a BACnet Time.
  """
  @spec from_time(Time.t()) :: t()
  def from_time(%Time{} = time) do
    %__MODULE__{
      hour: time.hour,
      minute: time.minute,
      second: time.second,
      hundredth: patch_microsecond(time.microsecond)
    }
  end

  @doc """
  Parses a BACnet Time from BACnet application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}} | {:error, term}
  def parse(tags) when is_list(tags) do
    with [{:time, %__MODULE__{} = time} | rest] <- tags do
      {:ok, {time, rest}}
    else
      _else -> {:error, :invalid_tags}
    end
  end

  @doc """
  Checks whether the given BACnet Time is a specific time value
  (every component is a numeric value).
  """
  @spec specific?(t()) :: boolean()
  def specific?(%__MODULE__{} = time) do
    case time do
      %{hour: :unspecified} -> false
      %{minute: :unspecified} -> false
      %{second: :unspecified} -> false
      %{hundredth: :unspecified} -> false
      _else -> true
    end
  end

  @doc """
  Converts a BACnet Time into a `Time`.

  If any of the fields are unspecified, the reference time (current UTC value) is used.
  """
  @spec to_time(t(), Time.t()) :: {:ok, Time.t()} | {:error, term()}
  def to_time(%__MODULE__{} = time, ref_time \\ Time.utc_now()) do
    hundredth = get_component(:hundredth, time, ref_time)

    Time.new(
      get_component(:hour, time, ref_time),
      get_component(:minute, time, ref_time),
      get_component(:second, time, ref_time),
      {hundredth, if(hundredth > 0, do: 6, else: 0)}
    )
  end

  @doc """
  Bang-version of `to_time/1`.
  """
  @spec to_time!(t(), Time.t()) :: Time.t() | no_return()
  def to_time!(%__MODULE__{} = time, ref_time \\ Time.utc_now()) do
    hundredth = get_component(:hundredth, time, ref_time)

    Time.new!(
      get_component(:hour, time, ref_time),
      get_component(:minute, time, ref_time),
      get_component(:second, time, ref_time),
      {hundredth, if(hundredth > 0, do: 6, else: 0)}
    )
  end

  @doc """
  Creates a new BACnet Time with the current UTC time.
  """
  @spec utc_now() :: t()
  def utc_now() do
    from_time(Time.utc_now())
  end

  @doc """
  Validates whether the given BACnet time is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(
        %__MODULE__{
          hour: hour,
          minute: minute,
          second: second,
          hundredth: hundredth
        } = _t
      )
      when (hour in 0..23 or hour == :unspecified) and (minute in 0..59 or minute == :unspecified) and
             (second in 0..59 or second == :unspecified) and
             (hundredth in 0..99 or hundredth == :unspecified),
      do: true

  def valid?(%__MODULE__{} = _t), do: false

  defp get_component(:hundredth, %__MODULE__{hundredth: :unspecified} = _time, %Time{} = utc_now) do
    patch_microsecond(utc_now.microsecond)
  end

  defp get_component(:hundredth, %__MODULE__{hundredth: hundredth} = _time, _utc_now),
    do: hundredth * 10_000

  defp get_component(component, %__MODULE__{} = time, utc_now)
       when :erlang.map_get(component, time) == :unspecified,
       do: Map.fetch!(utc_now, component)

  defp get_component(component, %__MODULE__{} = time, _utc_now), do: Map.fetch!(time, component)

  @spec patch_microsecond(Calendar.microsecond()) :: non_neg_integer()
  defp patch_microsecond(microsecond_prec) do
    case microsecond_prec do
      {_value, 0} -> 0
      {value, 1} -> value * 10
      {value, 2} -> value
      {value, 3} -> Integer.floor_div(value, 10)
      {value, 4} -> Integer.floor_div(value, 100)
      {value, 5} -> Integer.floor_div(value, 1000)
      {value, 6} -> Integer.floor_div(value, 10_000)
    end
  end
end
