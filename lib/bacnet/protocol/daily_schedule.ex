defmodule BACnet.Protocol.DailySchedule do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.TimeValue

  @typedoc """
  Represents a BACnet Daily Schedule.
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
    with {:ok, schedules} <-
           Enum.reduce_while(schedule.schedule, {:ok, []}, fn
             tv, {:ok, acc} ->
               case TimeValue.encode(tv, opts) do
                 {:ok, encoded} -> {:cont, {:ok, [encoded | acc]}}
                 {:error, _err} = err -> {:halt, err}
               end
           end) do
      day_schedule =
        schedules
        |> Enum.reverse()
        |> List.flatten()

      {:ok, [{:constructed, {0, day_schedule, 0}}]}
    else
      {:error, _err} = err -> err
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
        with {:ok, schedules} when is_list(schedules) <-
               Enum.reduce_while(1..100_000//1, {:ok, {[], tags}}, fn
                 _ind, {:ok, {acc, []}} ->
                   {:halt, {:ok, acc}}

                 _ind, {:ok, {acc, tags}} ->
                   case TimeValue.parse(tags) do
                     {:ok, {tv, rest}} -> {:cont, {:ok, {[tv | acc], rest}}}
                     {:error, _err} = err -> {:halt, err}
                   end
               end) do
          schedule = %__MODULE__{
            schedule: Enum.reverse(schedules)
          }

          {:ok, {schedule, rest}}
        else
          {:error, _err} = err -> err
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
