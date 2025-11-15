defmodule BACnet.Protocol.SpecialEvent do
  # TODO: Docs
  # TODO: Throw argument error in encode if not valid

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.CalendarEntry
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.TimeValue

  import BACnet.Protocol.Utility, only: [pattern_extract_tags: 4]
  require Constants

  @typedoc """
  Represents a BACnet Special Event.
  """
  @type t :: %__MODULE__{
          period: CalendarEntry.t() | ObjectIdentifier.t(),
          list: [TimeValue.t()],
          priority: 1..16
        }

  @fields [
    :period,
    :list,
    :priority
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Encode a BACnet special event into application tag-encoded.
  """
  @spec encode(t(), Keyword.t()) ::
          {:ok, ApplicationTags.encoding_list()} | {:error, term()}
  def encode(%__MODULE__{} = event, opts \\ []) do
    with {:ok, period} <-
           (case event.period do
              %CalendarEntry{} ->
                with {:ok, [entry]} <- CalendarEntry.encode(event.period) do
                  {:ok, {:constructed, {0, entry, 0}}}
                end

              %ObjectIdentifier{} ->
                ApplicationTags.create_tag_encoding(1, :object_identifier, event.period)

              _else ->
                {:error, :invalid_period}
            end),
         {:ok, schedules} <-
           Enum.reduce_while(event.list, {:ok, []}, fn
             %TimeValue{} = tv, {:ok, acc} ->
               case TimeValue.encode(tv, opts) do
                 {:ok, encoded} -> {:cont, {:ok, [encoded | acc]}}
                 {:error, _err} = err -> {:halt, err}
               end

             _else, _acc ->
               {:halt, {:error, :invalid_time_value}}
           end),
         {:ok, priority} <-
           ApplicationTags.create_tag_encoding(3, :unsigned_integer, event.priority) do
      event_list =
        schedules
        |> Enum.reverse()
        |> List.flatten()

      params = [
        period,
        {:constructed, {2, event_list, 0}},
        priority
      ]

      {:ok, params}
    else
      {:error, _err} = err -> err
    end
  end

  @doc """
  Parse a BACnet special event from application tags encoding.
  """
  @spec parse(ApplicationTags.encoding_list()) ::
          {:ok, {t(), rest :: ApplicationTags.encoding_list()}}
          | {:error, term()}
  def parse(tags) when is_list(tags) do
    with {:ok, period, rest} <- parse_period(tags),
         {:ok, {:constructed, {2, schedule_raw, 0}}, rest} <-
           pattern_extract_tags(rest, {:constructed, {2, _v, _l}}, nil, false),
         {:ok, schedules} when is_list(schedules) <-
           Enum.reduce_while(1..100_000//1, {:ok, {[], schedule_raw}}, fn
             _ind, {:ok, {acc, []}} ->
               {:halt, {:ok, acc}}

             _ind, {:ok, {acc, tags}} ->
               case TimeValue.parse(tags) do
                 {:ok, {tv, rest}} -> {:cont, {:ok, {[tv | acc], rest}}}
                 {:error, _err} = err -> {:halt, err}
               end
           end),
         {:ok, priority, rest} <-
           pattern_extract_tags(rest, {:tagged, {3, _c, _l}}, :unsigned_integer, false) do
      schedule = %__MODULE__{
        period: period,
        list: Enum.reverse(schedules),
        priority: priority
      }

      {:ok, {schedule, rest}}
    else
      {:error, :missing_pattern} -> {:error, :invalid_tags}
      {:error, _err} = err -> err
    end
  end

  @doc """
  Validates whether the given special event is in form valid.

  It only validates the struct is valid as per type specification.
  """
  @spec valid?(t()) :: boolean()
  def valid?(t)

  def valid?(
        %__MODULE__{
          period: %CalendarEntry{} = period,
          list: list,
          priority: priority
        } = _t
      )
      when is_list(list) and priority in 1..16 do
    CalendarEntry.valid?(period) and validate_list(list)
  end

  def valid?(
        %__MODULE__{
          period:
            %ObjectIdentifier{
              type: Constants.macro_assert_name(:object_type, :calendar)
            } = period,
          list: list,
          priority: priority
        } = _t
      )
      when is_list(list) and priority in 1..16 do
    ObjectIdentifier.valid?(period) and validate_list(list)
  end

  def valid?(%__MODULE__{} = _t), do: false

  @spec parse_period(ApplicationTags.encoding_list()) ::
          {:ok, CalendarEntry.t() | ObjectIdentifier.t(), ApplicationTags.encoding_list()}
          | {:error, term()}
  defp parse_period(tags)

  defp parse_period([{:constructed, {0, raw, 0}} | rest]) do
    with {:ok, {cal, _rest}} <- CalendarEntry.parse(List.wrap(raw)) do
      {:ok, cal, rest}
    end
  end

  defp parse_period([{:tagged, {1, _raw, _len}} = tag | rest]) do
    with {:ok, {:object_identifier, obj}} <-
           ApplicationTags.unfold_to_type(:object_identifier, tag) do
      {:ok, obj, rest}
    end
  end

  defp parse_period(_else), do: {:error, :invalid_tags}

  defp validate_list(list) when is_list(list) do
    Enum.all?(list, fn
      %TimeValue{} = val -> TimeValue.valid?(val)
      _else -> false
    end)
  end
end
