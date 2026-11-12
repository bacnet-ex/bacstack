defmodule BACnet.Protocol.ObjectExecution.ScheduleEvaluator do
  @moduledoc """
  Internal validation, value selection and deadline calculations for Schedule objects.

  `BACnet.Protocol.ObjectTypes.Schedule` uses these helpers to implement its object behaviour.
  Use `BACnet.Protocol.ObjectExecution.Lifecycle` to run a Schedule in an application.
  The functions here validate the timetable and calculate its selected value and next deadline.

  ## Inputs and responsibilities

  Inputs are normally `BACnet.Protocol.ObjectTypes.Schedule` structs. Each function also accepts
  a map containing the fields it reads, as described in its documentation. The configuration
  fields used across this module are:

  | Field | Representation |
  | --- | --- |
  | `weekly_schedule` | Seven-element `BACnet.Protocol.BACnetArray` of `BACnet.Protocol.DailySchedule`, or `nil`. |
  | `exception_schedule` | `BACnet.Protocol.BACnetArray` of `BACnet.Protocol.SpecialEvent`, or `nil`. |
  | `effective_period` | `BACnet.Protocol.DateRange`. |
  | `schedule_default`, `present_value` | Primitive `BACnet.Protocol.ApplicationTags.Encoding` values. |
  | `out_of_service` | Boolean used by `next_wakeup/2`. |

  `validate/1` checks configuration contents. Its required map keys must already be present.
  Validate the input before using the individual calculations. Call `datatype/1` to check
  that the non-NULL values share a BACnet application datatype.
  The Schedule implementation decides how validation failures affect its Reliability property.

  `calendar_references/1` identifies the local Calendar values needed by `evaluate/3`. The caller
  needs to obtain fresh Boolean values for all those identifiers and supply them in the calendar
  map. For lifecycle execution, nested Calendar reads need to share the enclosing operation's
  supplied time, as described by `BACnet.Protocol.ObjectExecution.Lifecycle`.

  `next_wakeup/2` calculates local deadlines from the time and timezone database in
  `BACnet.Protocol.ObjectExecution.Context`. Supply Calendar values and other inputs
  before calling these functions. Schedule handles Reliability updates, and the host
  delivers timers.

  ## NULL selection and target values

  A NULL weekly or exception time/value entry causes selection to fall through to another
  applicable value. The Schedule default is the final fallback and can itself be NULL.
  `values/1` retains all configured NULLs for configuration inspection. `target_values/1` omits
  NULL time/value entries but retains the default, including a NULL default, because that value
  can be written to a target. The current selected value, including an out-of-service manual
  value, is supplied separately to `BACnet.Protocol.ObjectExecution.ScheduleTargets.prepare/5`
  by the Schedule implementation.

  ## Example

  This example evaluates a validated daily schedule and calculates its next requested deadline.
  It uses supplied UTC time and no Calendar references.

      iex> alias BACnet.Protocol.ApplicationTags.Encoding
      iex> alias BACnet.Protocol.{BACnetArray, BACnetTime, DailySchedule, TimeValue}
      iex> alias BACnet.Protocol.ObjectExecution.{Context, ScheduleEvaluator}
      iex> alias BACnet.Protocol.ObjectTypes.Schedule
      iex> null = Encoding.create!({:null, nil})
      iex> on = Encoding.create!({:enumerated, 1})
      iex> day = %DailySchedule{schedule: [
      ...>   %TimeValue{time: BACnetTime.from_time(~T[08:00:00]), value: on},
      ...>   %TimeValue{time: BACnetTime.from_time(~T[18:00:00]), value: null}]}
      iex> {:ok, object} = Schedule.create(600, "Lighting", %{
      ...>   weekly_schedule: BACnetArray.from_list(List.duplicate(day, 7), true),
      ...>   schedule_default: null})
      iex> ScheduleEvaluator.validate(object)
      :ok
      iex> ScheduleEvaluator.datatype(object)
      {:ok, :enumerated}
      iex> ScheduleEvaluator.calendar_references(object)
      []
      iex> ScheduleEvaluator.evaluate(object, ~U[2026-11-09 08:00:00Z], %{}) == on
      true
      iex> ScheduleEvaluator.evaluate(object, ~U[2026-11-09 18:00:00Z], %{}) == null
      true
      iex> Enum.count(ScheduleEvaluator.values(object), &(&1.type == :null))
      8
      iex> Enum.count(ScheduleEvaluator.target_values(object), &(&1.type == :null))
      1
      iex> context = Context.new(:initialization, now: ~U[2026-11-09 08:00:00Z],
      ...>   monotonic_time: 0, timezone_database: Calendar.UTCOnlyTimeZoneDatabase)
      iex> {:ok, wakeup} = ScheduleEvaluator.next_wakeup(object, context)
      iex> DateTime.to_iso8601(wakeup.wall_time)
      "2026-11-09T18:00:00.000000Z"
  """

  alias BACnet.BeamTypes
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.CalendarEntry
  alias BACnet.Protocol.DailySchedule
  alias BACnet.Protocol.DateRange
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.SpecialEvent
  alias BACnet.Protocol.TimeValue

  @primitive_types [
    :null,
    :boolean,
    :unsigned_integer,
    :signed_integer,
    :real,
    :double,
    :octet_string,
    :character_string,
    :bitstring,
    :enumerated,
    :date,
    :time,
    :object_identifier
  ]

  @doc """
  Validates the structural and semantic contents of a Schedule configuration.

  Reads `weekly_schedule`, `exception_schedule`, `effective_period`, `schedule_default` and
  `present_value`. A present weekly array must contain seven daily schedules. If the weekly
  array is absent, the exception array must contain at least one event. Time/value lists need
  specific, unique times and valid primitive values. Event periods, priorities and the effective
  date range must also be valid.

  Returns `:ok`, `{:error, {:duplicate_entry, property}}` for repeated times, or
  `{:error, {:invalid_configuration, property}}` for other invalid contents. The property detail
  can also be `:missing_schedule` or `:schedule_value`. Missing map keys are programming errors.

  Datatype consistency is checked separately by `datatype/1`. This function does not check target
  compatibility, host operations, service capabilities or runtime state.

  ## Example

      iex> alias BACnet.Protocol.ObjectExecution.ScheduleEvaluator
      iex> alias BACnet.Protocol.ObjectTypes.Schedule
      iex> {:ok, object} = Schedule.create(600, "Empty week")
      iex> ScheduleEvaluator.validate(object)
      :ok
      iex> ScheduleEvaluator.validate(%{object | weekly_schedule: nil, exception_schedule: nil})
      {:error, {:invalid_configuration, :missing_schedule}}
  """
  @spec validate(map()) :: :ok | {:error, term()}
  def validate(object) do
    with :ok <- validate_week(object.weekly_schedule),
         :ok <- validate_events(object.exception_schedule),
         :ok <- required_schedule(object),
         :ok <- validate_range(object.effective_period),
         true <- valid_value?(object.schedule_default),
         true <- valid_value?(object.present_value) do
      :ok
    else
      false -> {:error, {:invalid_configuration, :schedule_value}}
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Checks whether a term is a supported primitive Schedule value.

  Accepts `BACnet.Protocol.ApplicationTags.Encoding` structs with `encoding: :primitive`, a
  supported application tag and a payload valid for that tag. NULL requires a `nil` payload.
  The `extras` field must be a keyword list without an `:encoder` entry. Tagged/constructed
  encodings, deferred encoders and non-encoding terms return `false`.

  This checks one value independently of configuration datatype consistency and target types.

  ## Example

      iex> alias BACnet.Protocol.ApplicationTags.Encoding
      iex> alias BACnet.Protocol.ObjectExecution.ScheduleEvaluator
      iex> ScheduleEvaluator.valid_value?(Encoding.create!({:null, nil}))
      true
      iex> ScheduleEvaluator.valid_value?(%Encoding{
      ...>   encoding: :primitive, type: :unsigned_integer, value: true, extras: []})
      false
      iex> ScheduleEvaluator.valid_value?(nil)
      false
  """
  @spec valid_value?(term()) :: boolean()
  def valid_value?(value)

  def valid_value?(%Encoding{encoding: :primitive, type: type, value: value, extras: extras})
      when type in @primitive_types and is_list(extras) do
    Keyword.keyword?(extras) and not Keyword.has_key?(extras, :encoder) and
      valid_primitive?(type, value)
  end

  def valid_value?(_value), do: false

  @doc """
  Compares application tags and payloads using strict payload equality.

  The inputs are expected to be validated primitive encodings. Encoding metadata and `extras`
  do not participate in the comparison. REAL and Double remain distinct even when their payloads
  are equal. The Schedule implementation uses this comparison to detect value changes.

  ## Example

      iex> alias BACnet.Protocol.ApplicationTags.Encoding
      iex> alias BACnet.Protocol.ObjectExecution.ScheduleEvaluator
      iex> value = Encoding.create!({:real, 1.0})
      iex> ScheduleEvaluator.same_value?(value, value)
      true
      iex> ScheduleEvaluator.same_value?(value, Encoding.create!({:double, 1.0}))
      false
  """
  @spec same_value?(Encoding.t(), Encoding.t()) :: boolean()
  def same_value?(left, right), do: left.type == right.type and left.value === right.value

  @doc """
  Collects the default and all configured weekly and exception values.

  Reads `schedule_default`, `weekly_schedule` and `exception_schedule`. Returns the default first,
  followed by weekly values in day/list order and exception values in array/list order. Duplicates
  and NULL entries are retained. `present_value` is not included. This function does not select
  values for a particular date or time.

  See `target_values/1` for the values used in advance target checks and `datatype/1` for the
  non-NULL configuration datatype check.

  ## Example

      iex> alias BACnet.Protocol.ApplicationTags.Encoding
      iex> alias BACnet.Protocol.ObjectExecution.ScheduleEvaluator
      iex> null = Encoding.create!({:null, nil})
      iex> ScheduleEvaluator.values(%{
      ...>   schedule_default: null, weekly_schedule: nil, exception_schedule: nil}) == [null]
      true
  """
  @spec values(map()) :: [Encoding.t()]
  def values(object), do: [object.schedule_default | scheduled_values(object)]

  @doc """
  Collects possible automatic output values for advance target validation.

  Reads `schedule_default`, `weekly_schedule` and `exception_schedule`. Returns the default,
  including NULL, followed by the non-NULL weekly and exception values in the same order as
  `values/1`. Duplicates are retained. NULL time/value entries are omitted because they select a
  fallback - they are not themselves the resulting command. A NULL default can be the result
  and must remain in this list.

  `BACnet.Protocol.ObjectExecution.ScheduleTargets.prepare/5` also checks the current selected
  value. Out-of-service manual control supplies only that selected value rather than this list.
  The module example demonstrates the difference from `values/1` with NULL time entries.

  ## Example

      iex> alias BACnet.Protocol.ApplicationTags.Encoding
      iex> alias BACnet.Protocol.ObjectExecution.ScheduleEvaluator
      iex> null = Encoding.create!({:null, nil})
      iex> ScheduleEvaluator.target_values(%{
      ...>   schedule_default: null, weekly_schedule: nil, exception_schedule: nil}) == [null]
      true
  """
  @spec target_values(map()) :: [Encoding.t()]
  def target_values(object) do
    # NULL time/value entries select a fallback. A NULL default can itself be written.
    [object.schedule_default | Enum.reject(scheduled_values(object), &(&1.type == :null))]
  end

  @spec scheduled_values(map()) :: [Encoding.t()]
  defp scheduled_values(object) do
    weekly = Enum.flat_map(array_items(object.weekly_schedule), & &1.schedule)
    exceptions = Enum.flat_map(array_items(object.exception_schedule), & &1.list)
    Enum.map(weekly ++ exceptions, & &1.value)
  end

  @doc """
  Finds the common application tag of the non-NULL configured values.

  Uses the same fields and values as `values/1`, ignoring NULLs. Returns `{:ok, tag}` for one
  common tag, `{:ok, nil}` for an all-NULL configuration, or `{:error, :inconsistent_datatypes}`
  when multiple non-NULL tags occur. It does not include `present_value` or check target
  compatibility. Values are expected to have passed `validate/1` or `valid_value?/1`.

  ## Example

      iex> alias BACnet.Protocol.ApplicationTags.Encoding
      iex> alias BACnet.Protocol.ObjectExecution.ScheduleEvaluator
      iex> ScheduleEvaluator.datatype(%{schedule_default: Encoding.create!({:real, 1.0}),
      ...>   weekly_schedule: nil, exception_schedule: nil})
      {:ok, :real}
      iex> ScheduleEvaluator.datatype(%{schedule_default: Encoding.create!({:null, nil}),
      ...>   weekly_schedule: nil, exception_schedule: nil})
      {:ok, nil}
  """
  @spec datatype(map()) :: {:ok, atom() | nil} | {:error, :inconsistent_datatypes}
  def datatype(object) do
    case object
         |> values()
         |> Enum.reject(&(&1.type == :null))
         |> Enum.map(& &1.type)
         |> Enum.uniq() do
      [] -> {:ok, nil}
      [type] -> {:ok, type}
      _types -> {:error, :inconsistent_datatypes}
    end
  end

  @doc """
  Lists the distinct Calendar identifiers used by exception events.

  Reads `exception_schedule`. Returns `BACnet.Protocol.ObjectIdentifier` values in order of first
  occurrence. Inline `BACnet.Protocol.CalendarEntry` periods are not included. On validated input,
  these identifiers refer to local Calendar objects. The function does not look up or read them.

  The caller needs to supply their fresh Boolean values to `evaluate/3`.

  ## Example

      iex> BACnet.Protocol.ObjectExecution.ScheduleEvaluator.calendar_references(%{exception_schedule: nil})
      []
  """
  @spec calendar_references(map()) :: [ObjectIdentifier.t()]
  def calendar_references(object) do
    object.exception_schedule
    |> array_items()
    |> Enum.map(& &1.period)
    |> Enum.filter(&is_struct(&1, ObjectIdentifier))
    |> Enum.uniq()
  end

  @doc """
  Checks whether a date matches the Schedule's effective period.

  Reads only `effective_period` and delegates date-pattern matching to
  `BACnet.Protocol.CalendarEntry.matches_date?/2`. The range must be valid for matching.
  This predicate does not consider `out_of_service`, time/value entries or exception priorities.
  The Schedule implementation separately decides whether automatic evaluation should run.

  ## Example

      iex> alias BACnet.Protocol.BACnetDate
      iex> alias BACnet.Protocol.DateRange
      iex> alias BACnet.Protocol.ObjectExecution.ScheduleEvaluator
      iex> object = %{effective_period: %DateRange{
      ...>   start_date: BACnetDate.from_date(~D[2026-11-01]),
      ...>   end_date: BACnetDate.from_date(~D[2026-11-30])}}
      iex> ScheduleEvaluator.active?(object, ~D[2026-11-09])
      true
      iex> ScheduleEvaluator.active?(object, ~D[2026-12-01])
      false
  """
  @spec active?(map(), Date.t()) :: boolean()
  def active?(object, date),
    do: CalendarEntry.matches_date?(range_entry(object.effective_period), date)

  @doc """
  Selects the automatic value at the supplied device-local wall time.

  Reads `weekly_schedule`, `exception_schedule` and `schedule_default`. Inputs must have passed
  structural validation. The calendar map must contain fresh Boolean values keyed by every
  identifier returned by `calendar_references/1` - a missing key raises `KeyError`.

  Matching exceptions are considered by ascending numeric priority, with array order breaking
  ties. Each list contributes its latest time/value entry at or before the supplied time. NULL
  contributions fall through to another exception, then the weekday schedule, then the default.
  Weekly indices run from Monday (`1`) through Sunday (`7`). The default may itself be NULL.

  Returns the selected encoding unchanged. The caller needs to check effective-period and
  out-of-service rules before choosing to use this calculation. This function does not update
  `present_value`, Reliability or any targets.

  ## Example

      iex> alias BACnet.Protocol.ApplicationTags.Encoding
      iex> alias BACnet.Protocol.ObjectExecution.ScheduleEvaluator
      iex> alias BACnet.Protocol.ObjectTypes.Schedule
      iex> fallback = Encoding.create!({:enumerated, 0})
      iex> {:ok, object} = Schedule.create(600, "Fallback", %{schedule_default: fallback})
      iex> ScheduleEvaluator.evaluate(object, ~U[2026-11-09 08:00:00Z], %{}) == fallback
      true
  """
  @spec evaluate(map(), DateTime.t(), %{ObjectIdentifier.t() => boolean()}) :: Encoding.t()
  def evaluate(object, now, calendars) do
    today = DateTime.to_date(now)
    time = DateTime.to_time(now)

    exception =
      object.exception_schedule
      |> array_items()
      |> Enum.with_index()
      |> Enum.filter(fn {event, _index} -> matches?(event.period, today, calendars) end)
      |> Enum.sort_by(fn {event, index} -> {event.priority, index} end)
      |> Enum.find_value(fn {event, _index} -> current_value(event.list, time) end)

    weekly =
      case object.weekly_schedule do
        %BACnetArray{} = week ->
          {:ok, day} = BACnetArray.get_item(week, Date.day_of_week(today))
          current_value(day.schedule, time)

        nil ->
          nil
      end

    exception || weekly || object.schedule_default
  end

  @doc """
  Calculates the next potential automatic transition or local midnight.

  Reads `out_of_service`, and for an in-service object also `effective_period`, `weekly_schedule`
  and `exception_schedule`. The context supplies `now` and `timezone_database` - its trigger,
  monotonic time, state and host operations are not used by this calculation.

  Returns `{:ok, nil}` out of service. Otherwise returns a
  `BACnet.Protocol.ObjectExecution.Wakeup` with the earliest future wall deadline and
  `monotonic_time: nil`. Outside the effective period, only the next local midnight is considered.
  Inside it, all of today's weekly and exception transition times are also considered. This can
  request an extra check for an exception whose period does not match today.

  Both occurrences of an ambiguous local time are considered. A time in a timezone gap resolves
  to the first instant after that gap. Database errors return `{:error, {:timezone_error, reason}}`.
  Inputs must already be structurally valid. No timer is armed - the integrating host needs to
  service the returned deadline through `BACnet.Protocol.ObjectExecution.Lifecycle`.

  ## Example

      iex> alias BACnet.Protocol.ObjectExecution.{Context, ScheduleEvaluator}
      iex> context = Context.new(:periodic, now: ~U[2026-11-09 08:00:00Z], monotonic_time: 0)
      iex> ScheduleEvaluator.next_wakeup(%{out_of_service: true}, context)
      {:ok, nil}
  """
  @spec next_wakeup(map(), Context.t()) :: {:ok, Wakeup.t() | nil} | {:error, term()}
  def next_wakeup(object, context)

  def next_wakeup(%{out_of_service: true}, %Context{}), do: {:ok, nil}

  def next_wakeup(object, %Context{} = context) do
    today = DateTime.to_date(context.now)
    tomorrow = Date.add(today, 1)
    # All potentially relevant transitions are considered. This includes a second
    # occurrence in an overlapping local hour, even if its wall time is earlier.
    times =
      if active?(object, today) do
        weekly =
          case object.weekly_schedule do
            nil ->
              []

            week ->
              {:ok, day} = BACnetArray.get_item(week, Date.day_of_week(today))
              day.schedule
          end

        (weekly ++ Enum.flat_map(array_items(object.exception_schedule), & &1.list))
        |> Enum.map(&to_time(&1.time))
        |> Enum.uniq()
      else
        []
      end

    [{tomorrow, ~T[00:00:00]} | Enum.map(times, &{today, &1})]
    |> Enum.reduce_while({:ok, []}, fn {date, time}, {:ok, acc} ->
      case local_instants(date, time, context) do
        {:ok, instants} -> {:cont, {:ok, instants ++ acc}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, instants} ->
        deadline =
          instants
          |> Enum.filter(&(DateTime.compare(&1, context.now) == :gt))
          |> Enum.min_by(&DateTime.to_unix(&1, :microsecond))

        {:ok, %Wakeup{wall_time: deadline, monotonic_time: nil}}

      {:error, _reason} = error ->
        error
    end
  end

  @spec validate_week(term()) :: :ok | {:error, term()}
  defp validate_week(week)

  defp validate_week(nil), do: :ok

  defp validate_week(%BACnetArray{size: 7} = week) do
    Enum.reduce_while(1..7, :ok, fn index, :ok ->
      case BACnetArray.get_item(week, index) do
        {:ok, %DailySchedule{schedule: list}} ->
          validation_step(validate_times(list, :weekly_schedule))

        _other ->
          {:halt, {:error, {:invalid_configuration, :weekly_schedule}}}
      end
    end)
  end

  defp validate_week(_week), do: {:error, {:invalid_configuration, :weekly_schedule}}

  @spec validate_events(term()) :: :ok | {:error, term()}
  defp validate_events(events)

  defp validate_events(nil), do: :ok

  defp validate_events(%BACnetArray{} = events) do
    Enum.reduce_while(1..events.size//1, :ok, fn index, :ok ->
      case BACnetArray.get_item(events, index) do
        {:ok, %SpecialEvent{period: period, list: list, priority: priority}}
        when priority in 1..16 ->
          if valid_period?(period),
            do: validation_step(validate_times(list, :exception_schedule)),
            else: {:halt, {:error, {:invalid_configuration, :exception_schedule}}}

        _other ->
          {:halt, {:error, {:invalid_configuration, :exception_schedule}}}
      end
    end)
  end

  defp validate_events(_events), do: {:error, {:invalid_configuration, :exception_schedule}}

  @spec validate_times(term(), atom()) :: :ok | {:error, term()}
  defp validate_times(list, property)

  defp validate_times(list, property) when is_list(list) do
    result =
      Enum.reduce_while(list, MapSet.new(), fn
        %TimeValue{time: %BACnetTime{} = time, value: value}, seen ->
          cond do
            not BACnetTime.valid?(time) or not BACnetTime.specific?(time) or
                not valid_value?(value) ->
              {:halt, {:error, {:invalid_configuration, property}}}

            MapSet.member?(seen, time) ->
              {:halt, {:error, {:duplicate_entry, property}}}

            true ->
              {:cont, MapSet.put(seen, time)}
          end

        _item, _seen ->
          {:halt, {:error, {:invalid_configuration, property}}}
      end)

    if is_struct(result, MapSet), do: :ok, else: result
  end

  defp validate_times(_list, property), do: {:error, {:invalid_configuration, property}}

  @spec required_schedule(map()) :: :ok | {:error, term()}
  defp required_schedule(object) do
    if not is_nil(object.weekly_schedule) or
         (is_struct(object.exception_schedule, BACnetArray) and object.exception_schedule.size > 0),
       do: :ok,
       else: {:error, {:invalid_configuration, :missing_schedule}}
  end

  @spec validate_range(term()) :: :ok | {:error, term()}
  defp validate_range(range) do
    if is_struct(range, DateRange) and CalendarEntry.valid_for_matching?(range_entry(range)),
      do: :ok,
      else: {:error, {:invalid_configuration, :effective_period}}
  end

  @spec range_entry(DateRange.t()) :: CalendarEntry.t()
  defp range_entry(range),
    do: %CalendarEntry{type: :date_range, date_range: range, date: nil, week_n_day: nil}

  @spec valid_period?(term()) :: boolean()
  defp valid_period?(period)

  defp valid_period?(%CalendarEntry{} = entry), do: CalendarEntry.valid_for_matching?(entry)

  defp valid_period?(%ObjectIdentifier{type: :calendar} = identifier),
    do: ObjectIdentifier.valid?(identifier)

  defp valid_period?(_period), do: false

  @spec matches?(CalendarEntry.t() | ObjectIdentifier.t(), Date.t(), map()) :: boolean()
  defp matches?(period, date, calendars)

  defp matches?(%CalendarEntry{} = entry, date, _calendars),
    do: CalendarEntry.matches_date?(entry, date)

  defp matches?(%ObjectIdentifier{} = identifier, _date, calendars),
    do: Map.fetch!(calendars, identifier)

  @spec current_value([TimeValue.t()], Time.t()) :: Encoding.t() | nil
  defp current_value(list, now) do
    list
    |> Enum.filter(&(Time.compare(to_time(&1.time), now) != :gt))
    |> Enum.max_by(&to_time(&1.time), Time, fn -> nil end)
    |> case do
      nil -> nil
      %TimeValue{value: %Encoding{type: :null}} -> nil
      %TimeValue{value: value} -> value
    end
  end

  @spec to_time(BACnetTime.t()) :: Time.t()
  defp to_time(time),
    do: Time.new!(time.hour, time.minute, time.second, {time.hundredth * 10_000, 6})

  @spec array_items(BACnetArray.t() | nil) :: list()
  defp array_items(array)

  defp array_items(nil), do: []

  defp array_items(array) do
    Enum.map(1..array.size//1, fn index ->
      {:ok, item} = BACnetArray.get_item(array, index)
      item
    end)
  end

  @spec local_instants(Date.t(), Time.t(), Context.t()) ::
          {:ok, [DateTime.t()]} | {:error, term()}
  defp local_instants(date, time, context) do
    case DateTime.new(date, time, context.now.time_zone, context.timezone_database) do
      {:ok, instant} -> {:ok, [instant]}
      {:ambiguous, first, second} -> {:ok, [first, second]}
      {:gap, _before, first_after} -> {:ok, [first_after]}
      {:error, reason} -> {:error, {:timezone_error, reason}}
    end
  end

  @spec validation_step(:ok | {:error, term()}) :: {:cont, :ok} | {:halt, {:error, term()}}
  defp validation_step(result)

  defp validation_step(:ok), do: {:cont, :ok}
  defp validation_step({:error, _reason} = error), do: {:halt, error}

  @spec valid_primitive?(atom(), term()) :: boolean()
  defp valid_primitive?(type, value)

  defp valid_primitive?(:null, value), do: is_nil(value)
  defp valid_primitive?(:enumerated, value), do: BeamTypes.check_type(:unsigned_integer, value)
  defp valid_primitive?(:character_string, value), do: BeamTypes.check_type(:string, value)
  defp valid_primitive?(:date, value), do: BeamTypes.check_type({:struct, BACnetDate}, value)
  defp valid_primitive?(:time, value), do: BeamTypes.check_type({:struct, BACnetTime}, value)

  defp valid_primitive?(:object_identifier, value),
    do: BeamTypes.check_type({:struct, ObjectIdentifier}, value)

  defp valid_primitive?(type, value), do: BeamTypes.check_type(type, value)
end
