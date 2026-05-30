defmodule BACnet.Protocol.DailySchedule do
  @moduledoc """
  A Daily Schedule is a list of `BACnet.Protocol.TimeValue` pairs that define the
  desired behavior of a scheduled property for one 24-hour period. It is the
  fundamental building block of both the normal `weekly_schedule` (7 entries,
  one per `BACnet.Protocol.DaysOfWeek`) and the `exception_schedule` in Schedule objects.

  Each `TimeValue` specifies the time at which the scheduled property should
  take on the given value (and keep it until the next entry or the end of the day).

  ### BACnet Specification References
  - **ASN.1** (Clause 21): `BACnetDailySchedule ::= SEQUENCE { daySchedule SEQUENCE OF BACnetTimeValue }`
  - **Schedule object** (12.24): `weekly_schedule` is a `BACnetARRAY[7]` of
    `BACnet.Protocol.DailySchedule`; `exception_schedule` is a list of `BACnet.Protocol.SpecialEvent` each
    containing a `BACnet.Protocol.DailySchedule` (in the `list` field).
  - Time values may be unspecified patterns in some contexts, but for normal
    schedule operation concrete times are expected.

  ### Examples (Doc Test)

  ```elixir
  iex> schedule = %DailySchedule{
  ...>   schedule: [
  ...>     %TimeValue{time: %BACnetTime{hour: 8, minute: 0, second: 0, hundredth: 0}, value: {:real, 22.0}},
  ...>     %TimeValue{time: %BACnetTime{hour: 18, minute: 0, second: 0, hundredth: 0}, value: {:real, 18.0}}
  ...>   ]
  ...> }
  iex> length(schedule.schedule)
  2
  ```

  ### See Also
  - `BACnet.Protocol.CalendarEntry`
  - `BACnet.Protocol.DateRange`
  - `BACnet.Protocol.SpecialEvent`
  - `BACnet.Protocol.TimeValue`
  - `BACnet.Protocol.WeekNDay`
  """

  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.TimeValue

  @typedoc """
  One day's schedule: list of `BACnet.Protocol.TimeValue` (see `BACnet.Protocol.DailySchedule` module
  docs and Schedule object Clause 12.24).
  """
  @type t :: %__MODULE__{
          schedule: [TimeValue.t()]
        }

  @fields [
    :schedule
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encode a BACnet daily schedule into application tag-encoded.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = schedule, opts \\ []) do
    case Enum.reduce_while(schedule.schedule, {:ok, []}, fn
           tv, {:ok, acc} ->
             case TimeValue.encode(tv, opts) do
               {:ok, encoded} -> {:cont, {:ok, [encoded | acc]}}
               {:error, _err} = err -> {:halt, err}
             end
         end) do
      {:ok, schedules} ->
        day_schedule =
          schedules
          |> Enum.reverse()
          |> List.flatten()

        {:ok, [{:constructed, {0, day_schedule, 0}}]}

      {:error, _err} = err ->
        err
    end
  end

  @doc """
  Parse a BACnet daily schedule from application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    case tags do
      [{:constructed, {0, tags, _len}} | rest] ->
        case Enum.reduce_while(1..100_000//1, {:ok, {[], tags}}, fn
               _ind, {:ok, {acc, []}} ->
                 {:halt, {:ok, acc}}

               _ind, {:ok, {acc, tags}} ->
                 case TimeValue.parse(tags) do
                   {:ok, {tv, rest}} -> {:cont, {:ok, {[tv | acc], rest}}}
                   {:error, _err} = err -> {:halt, err}
                 end
             end) do
          {:ok, schedules} when is_list(schedules) ->
            schedule = %__MODULE__{
              schedule: Enum.reverse(schedules)
            }

            {:ok, {schedule, rest}}

          {:error, _err} = err ->
            err
        end

      _term ->
        {:error, :invalid_tags}
    end
  end

  @doc """
  Validates whether the given daily schedule is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{schedule: schedule} = _t) when is_list(schedule) do
    Enum.all?(schedule, fn
      %TimeValue{} = val -> TimeValue.valid?(val)
      _else -> false
    end)
  end

  def valid?(%__MODULE__{} = _t), do: false
end
