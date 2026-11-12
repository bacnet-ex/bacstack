defmodule BACnet.Protocol.ObjectTypes.Schedule do
  @moduledoc """
  A Schedule selects a value from a weekly timetable or an exception and
  writes it to configured BACnet properties. Use one for occupancy
  setpoints, lighting scenes or holiday overrides. Several schedules can
  share a holiday list through a `BACnet.Protocol.ObjectTypes.Calendar`.

  A weekly schedule contains seven daily lists of time/value pairs, Monday through Sunday.
  Exception schedules override those lists on dates selected by inline calendar entries or local
  Calendar references. `present_value` is the currently selected primitive BACnet value.

  ### Object Description (ASHRAE 135)

  > The Schedule object type defines a standardized object used to describe a periodic schedule
  > that may recur during a range of dates, with optional exceptions at arbitrary times on
  > arbitrary dates. The Schedule object also serves as a binding between these scheduled times
  > and the writing of specified "values" to specific properties of specific objects at those times.

  ### Behaviour and Operation

  `execute/2` implements the calculation and target writes.
  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  is the integrating application or higher-level BACnet stack that owns this object and drives
  its lifecycle. The host needs to supply time, retain results, deliver triggers and arrange
  wakeups. It does not need to implement a separate Schedule evaluator.

  For each active day, the Schedule selects the latest time/value pair at or before the supplied
  local time. Entries may be supplied in any order, but each time must be specific and unique
  within its daily or special-event list. Values do not carry over from the preceding day.

  Matching exceptions are considered in order of `priority`, then exception array index.
  The first exception contributing a non-NULL value wins. A NULL contribution falls through to
  lower-priority exceptions, today's weekly value and finally `schedule_default`. Event priority
  chooses an exception - `priority_for_writing` independently chooses the target command priority.

  `effective_period` bounds automatic scheduling. On entry, calculation and target writes occur
  even when the selected value equals the stored value. Outside that period, the previous
  `present_value` is retained. Leaving the period or entering out-of-service does not automatically
  relinquish earlier target commands.

  ### Configuration and Value Datatypes

  The weekly property must contain seven `BACnet.Protocol.DailySchedule` elements when present.
  An empty seven-day weekly schedule is valid. If it is absent, `exception_schedule` must contain
  at least one `BACnet.Protocol.SpecialEvent`, whose time/value list may itself be empty.
  Creation supplies an empty weekly schedule by default. A host resizing an exception array needs
  to initialize new special events with empty time/value lists and valid period/priority fields.

  Values use primitive `BACnet.Protocol.ApplicationTags.Encoding` structs. All primitive
  application tags in `t:BACnet.Protocol.ApplicationTags.primitive_type/0` are supported, including
  NULL. Non-NULL weekly, exception and default values must share one BACnet datatype. An all-NULL
  configuration is valid. Tagged/constructed values and deferred
  `BACnet.Protocol.ApplicationTags.Encoding` encoder functions are
  rejected during execution preflight.

  Local target compatibility uses each resolved object's property type map and encoding annotations.
  REAL and Double remain distinct, as do ENUMERATED and Unsigned. For example, a binary output's
  ENUMERATED 0/1 becomes the Boolean representation expected by its property functions. An
  incompatible tag is not silently coerced to the target datatype. Primitive property codecs are
  used when declared, with the outgoing tag checked for consistency. Local validation uses
  `BACnet.Protocol.ObjectsUtility.cast_property_to_value/4` with the identifier
  obtained from the target module's object-identifier getter. NULL time/value
  entries select a fallback - a NULL `schedule_default` can itself be written and is included in
  target validation. A NULL command relinquishes the selected target priority.

  Each target write callback receives the original `BACnet.Protocol.ApplicationTags.Encoding`.
  A local host adapter needs to cast it through `BACnet.Protocol.ObjectsUtility.cast_property_to_value/4`
  with the target's object identifier before applying the property write or command. A NULL commandable `present_value` write
  relinquishes the selected priority through the target module's priority setter, using `nil`.
  Handle this before ordinary property casting. Use `allow_partial: true` when casting an array
  element. Index zero belongs to length validation and resizing in the write path.
  Remote adapters can pass the encoding directly to `BACnet.Stack.ClientHelper.write_property/6`,
  retaining the reference's property, array index and write priority. The host needs to resolve
  device identifiers to network destinations and bound transport waits. Schedule does not look up
  remote object models or infer remote datatype support - remote write responses report failures.

  Target references form an Elixir list, matching BACnetLIST semantics. Targets may be scalar
  properties or indexed array elements. An array index must exist; index zero is accepted only for
  a variable array's Unsigned length. The host write callback needs to implement that property's
  resize/default-initialization rules. A whole structured array is not a primitive scheduled value.

  ### Lifecycle Execution

  Use `BACnet.Protocol.ObjectExecution.Lifecycle` around the module-owned callbacks. Preparation
  validates configuration and capabilities without host I/O. Duplicate times return
  `{:error, {:duplicate_entry, property}}`. Other malformed schedules return
  `{:error, {:invalid_configuration, property}}`. Mixed non-NULL configuration datatypes are
  rejected by write preparation with `{:error, :inconsistent_datatypes}`. Property functions
  validate representation - an update alone does not run this lifecycle or command targets.

  The host needs to serialize each object's operations and supply:

  - `now` in the device's configured timezone, `timezone_database` supporting that zone, current
    monotonic milliseconds, the trigger and the last returned opaque runtime state.
  - `write_property` when the target list is nonempty. Writes receive the selected encoding,
    the complete target reference and `priority_for_writing`.
  - `lookup_object` when any target is local. Lookup must return the actual local object,
    including its type map and property annotations. Remote-only target lists need no lookup.
  - `read_property` when automatic scheduling uses Calendar references. Calendar reads must be
    fresh through the lifecycle and use the enclosing operation's supplied time. Running Calendar
    first on some previous tick does not establish freshness.
  - `device_identifier`, set to the containing Device's identifier to recognize explicit self-device
    references, or `nil` when not needed. Recognized self references are normalized to local
    references for host I/O. Other device-qualified references remain remote, with their device
    identifier preserved. Without a local identity, all device-qualified references are forwarded
    as remote references.

  No object-specific `context.options` are needed. Empty target lists need no lookup or write
  callback. Local Calendar references contain only an ObjectIdentifier and always resolve locally.

  #### Triggers, commits and target writes

  | Event | Required interaction |
  | --- | --- |
  | Start or restart | Execute with `:initialization` and fresh runtime state. Active initialization commands the selected value. |
  | Proposed property write | Build a candidate through property functions, then call `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3`. Commit the accepted candidate and execute with the same property-write context, including same-value writes. |
  | Computed read | Call `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2`, retain its result, finish continuations, then call `get_property/2`. |
  | Requested deadline | Check `BACnet.Protocol.ObjectExecution.Wakeup.due?/2` with fresh supplied time and execute with `:timer`. |
  | Clock or timezone change | Execute with `:clock_change`, including relevant timezone-offset/DST changes, and replace the previous wakeup. |
  | Calendar edit/value change | Deliver `{:object_changed, reference}` to affected Schedules. |

  Before target writes, execution resolves and checks all targets. It publishes the calculated
  `present_value` and a pending write plan in a result requesting `:immediate`. The host needs to
  commit that result, then execute with `:continuation` before processing another external
  operation. This makes the new Schedule value visible to target callbacks. The continuation
  attempts valid targets in list order and retains each failure while continuing through the rest.

  A selected-value change, active initialization, effective-period entry or return to service
  commands the targets. In-service edits of the target list or write priority also send the current
  value to the current targets. Removed targets are not automatically relinquished. Unchanged
  periodic calls and reads do not repeat writes. A successful revalidation after a configuration
  fault resynchronizes active targets; unchanged write failures are retained until a later command
  or explicit reinitialization, without automatic retries on every tick.

  #### Out-of-service and reliability

  In service, host access checks and write preparation reject client writes to `present_value`.
  While `out_of_service` is true, automatic calculation stops and `present_value` becomes writable.
  A manual change still commands all configured targets at `priority_for_writing`. A same-value
  manual write passes through execution but does not create another value change. Changing other
  configuration while out of service does not substitute an automatic value.

  Manual control also remains available when the automatic configuration has inconsistent
  datatypes. The manual value is checked against the targets independently, while reliability
  continues to report the automatic configuration fault.

  Target lookup, writability, type and index failures set `reliability` to `:configuration_error`.
  Invalid targets are skipped and valid targets are still attempted. Calendar-read failures and
  inconsistent configuration datatypes also produce a retained configuration fault, holding the
  previous value until calculation can recover. Property/type/access rejections from target writes
  also set `:configuration_error`. Other write-operation failures set
  `:communication_failure` unless a configuration failure also occurred. The returned opaque state
  retains reference/reason pairs. Property operations maintain the corresponding status flags.

  These operational faults return successful results containing the updated reliability and state.
  Pure preflight errors supply no replacement result. The host needs to preserve the previous
  result on rejection, or an already accepted property write if execution fails after commit.
  The host also needs to enforce target service permissions and reserved command-priority rules.

  `reliability_evaluation_inhibit` masks automatic reliability evaluation with
  `:no_fault_detected`, except for an alternate Reliability explicitly written while out of
  service. Explicit simulation writes can use either BACnet or application origin.
  Failure details remain in runtime state. With `intrinsic_reporting: true`,
  changes in Reliability can generate FAULT and NORMAL transitions. The host
  retrieves transitions with `BACnet.Protocol.ObjectExecution.EventReporting.transition/1`
  after retaining the result.
  Local and remote target writes are supported through host callbacks. Remote Schedule snapshots execute passively, preserving
  their object and supplied state with no next-execution request.

  #### Wakeups and state ownership

  Each automatic step requests the next potential time/value transition or local midnight as a
  wall-clock `BACnet.Protocol.ObjectExecution.Wakeup`. Exception lists can produce extra checks
  even when their dates do not match - unchanged checks do not repeat commands. Ambiguous local
  times include both occurrences and use the first future instant. A time in a gap resolves to
  the first instant after that gap. The host needs to report clock corrections and timezone-offset
  changes promptly so calculation reflects a repeated or skipped local hour.

  Out-of-service execution requests no timer. Each successful result replaces the previous
  request, including cancellation with `nil`. Runtime state belongs to this module and includes
  prior effective/service state, pending writes and retained failures. Pass it back unchanged for
  that same instance. After a VM restart use `nil` and initialization with current clocks.
  See `BACnet.Protocol.ObjectExecution.Lifecycle` for complete timer-arming and continuation code.

  ### Examples

  This complete example calculates a daily lighting schedule without targets. A host with targets
  must also supply the callbacks and drain immediate continuations described above.

      iex> alias BACnet.Protocol.ApplicationTags.Encoding
      iex> alias BACnet.Protocol.{BACnetArray, BACnetTime, DailySchedule, TimeValue}
      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> alias BACnet.Protocol.ObjectTypes.Schedule
      iex> on = Encoding.create!({:enumerated, 1})
      iex> off = Encoding.create!({:enumerated, 0})
      iex> day = %DailySchedule{schedule: [
      ...>   %TimeValue{time: BACnetTime.from_time(~T[08:00:00]), value: on},
      ...>   %TimeValue{time: BACnetTime.from_time(~T[18:00:00]), value: off}]}
      iex> {:ok, schedule} = Schedule.create(600, "Lighting", %{
      ...>   weekly_schedule: BACnetArray.from_list(List.duplicate(day, 7), true),
      ...>   schedule_default: off})
      iex> context = %Context{
      ...>   device_identifier: nil,
      ...>   now: ~U[2026-11-09 08:00:00Z],
      ...>   timezone_database: Calendar.UTCOnlyTimeZoneDatabase,
      ...>   monotonic_time: 0,
      ...>   trigger: :initialization,
      ...>   state: nil,
      ...>   lookup_object: nil,
      ...>   read_property_multiple: nil,
      ...>   read_property: nil,
      ...>   write_property: nil,
      ...>   options: []}
      iex> {:ok, stored} = Lifecycle.execute(schedule, context)
      iex> stored.object.present_value
      %Encoding{encoding: :primitive, type: :enumerated, value: 1, extras: []}
      iex> DateTime.to_iso8601(stored.next_execution.wall_time)
      "2026-11-09T18:00:00.000000Z"
      iex> context = %{context | now: ~U[2026-11-09 18:00:00Z],
      ...>   monotonic_time: 36_000_000, state: stored.state, trigger: :timer}
      iex> {:ok, stored} = Lifecycle.execute(stored.object, context)
      iex> Schedule.get_property(stored.object, :present_value)
      {:ok, %Encoding{encoding: :primitive, type: :enumerated, value: 0, extras: []}}

  For a runnable example with a Calendar, a commandable binary output, fresh reads, target writes,
  out-of-service manual control and deadline delivery, run
  `mix run examples/objects_lifecycle/schedule_lifecycle.exs` from the repository root. See the
  schedule lifecycle in the examples directory for the walkthrough and integration expectations.

  ### See Also

  - `BACnet.Protocol.ObjectTypes.Calendar`
  - `BACnet.Protocol.DailySchedule`
  - `BACnet.Protocol.SpecialEvent`
  - `BACnet.Protocol.CalendarEntry`
  - `BACnet.Protocol.ObjectExecution.Lifecycle`
  """

  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DailySchedule
  alias BACnet.Protocol.DateRange
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.EventAlgorithms
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.IntrinsicReporting
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.ScheduleEvaluator, as: Evaluator
  alias BACnet.Protocol.ObjectExecution.ScheduleTargets, as: Targets
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectsUtility.Internal, as: UtilityInternal
  alias BACnet.Protocol.SpecialEvent

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Schedule object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a Schedule object. All keys should be treated as read-only,
  all updates should go through `update_property/3`.
  """
  bac_object Constants.macro_assert_name(:object_type, :schedule) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:event_state, Constants.event_state(), intrinsic: true, default: :normal)
    field(:reliability, Constants.reliability(), required: true)
    field(:reliability_evaluation_inhibit, boolean())

    field(:out_of_service, boolean(), required: true)

    field(:present_value, Encoding.t(),
      required: true,
      default: %Encoding{
        encoding: :primitive,
        extras: [],
        type: :null,
        value: nil
      }
    )

    field(:effective_period, DateRange.t(),
      required: true,
      default: %DateRange{
        start_date: %BACnetDate{
          year: :unspecified,
          month: :unspecified,
          day: :unspecified,
          weekday: :unspecified
        },
        end_date: %BACnetDate{
          year: :unspecified,
          month: :unspecified,
          day: :unspecified,
          weekday: :unspecified
        }
      }
    )

    field(:weekly_schedule, BACnetArray.t(DailySchedule.t(), 7),
      init_fun: &UtilityInternal.init_fun_schedule_weekly_schedule/0
    )

    field(:exception_schedule, BACnetArray.t(SpecialEvent.t()))

    field(:schedule_default, Encoding.t(),
      required: true,
      default: %Encoding{
        encoding: :primitive,
        extras: [],
        type: :null,
        value: nil
      }
    )

    field(
      :list_of_object_property_references,
      [DeviceObjectPropertyRef.t()],
      required: true,
      default: []
    )

    field(:priority_for_writing, 1..16, required: true, default: 16)
  end

  @typedoc false
  @type execution_state :: %{
          value: Encoding.t(),
          active: boolean(),
          out_of_service: boolean(),
          pending: [Targets.plan()] | nil,
          next_execution: Wakeup.t() | nil,
          failure_kind: :configuration | :write | nil,
          manual_reliability: Constants.reliability() | nil,
          configuration_fault: term() | nil,
          failures: [
            {DeviceObjectPropertyRef.t() | BACnet.Protocol.ObjectIdentifier.t(), reason :: term()}
          ]
        }

  @impl BACnet.Protocol.ObjectsBehaviour
  @spec validate_execution(t(), Context.t()) :: :ok | {:error, term()}
  def validate_execution(object, context)

  def validate_execution(%__MODULE__{_metadata: %{remote_object: remote}}, %Context{})
      when not is_nil(remote), do: :ok

  def validate_execution(%__MODULE__{} = object, %Context{} = context) do
    with :ok <- Evaluator.validate(object),
         :ok <- Targets.validate_references(object.list_of_object_property_references, context),
         :ok <- Context.require_operations(context, required_operations(object, context)),
         {:ok, _wakeup} <- Evaluator.next_wakeup(object, context) do
      valid_state(context.state)
    end
  end

  @impl BACnet.Protocol.ObjectsBehaviour
  @spec prepare_write(t(), t(), Context.t()) :: {:ok, t()} | {:error, term()}
  def prepare_write(original, candidate, context)

  def prepare_write(%__MODULE__{_metadata: %{remote_object: remote}}, _candidate, %Context{})
      when not is_nil(remote), do: {:error, :operation_not_available_for_remote_objects}

  def prepare_write(%__MODULE__{}, %__MODULE__{out_of_service: false}, %Context{
        trigger: {:property_write, property, _index, _priority}
      })
      when property in [
             :present_value,
             Constants.macro_by_name(:property_identifier, :present_value)
           ],
      do: {:error, {:write_access_denied, :present_value}}

  def prepare_write(%__MODULE__{} = original, %__MODULE__{} = candidate, %Context{} = context) do
    with {:ok, candidate} <- super(original, candidate, context),
         :ok <- Evaluator.validate(candidate),
         :ok <- validate_write_datatype(candidate, context) do
      {:ok, candidate}
    end
  end

  @spec validate_write_datatype(t(), Context.t()) :: :ok | {:error, term()}
  defp validate_write_datatype(candidate, context) do
    {:property_write, property, _index, _priority} = normalize_trigger(context).trigger

    if candidate.out_of_service and
         property not in [:weekly_schedule, :exception_schedule, :schedule_default] do
      :ok
    else
      case Evaluator.datatype(candidate) do
        {:ok, _type} -> :ok
        {:error, _reason} = error -> error
      end
    end
  end

  @spec property_writable?(t(), atom()) :: boolean()
  def property_writable?(object, property)

  def property_writable?(%__MODULE__{} = object, :present_value), do: object.out_of_service
  def property_writable?(%__MODULE__{} = object, property), do: super(object, property)

  @impl BACnet.Protocol.ObjectsBehaviour
  @spec execute(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  def execute(object, context)

  def execute(%__MODULE__{_metadata: %{remote_object: remote}} = object, %Context{} = context)
      when not is_nil(remote), do: super(object, context)

  def execute(%__MODULE__{} = object, %Context{} = context) do
    with :ok <- validate_execution(object, context) do
      context = normalize_trigger(context)

      with {:ok, result} <- execute_schedule(object, context) do
        {:ok, IntrinsicReporting.evaluate(result, context, EventAlgorithms.None, [])}
      end
    end
  end

  @spec execute_schedule(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  defp execute_schedule(object, context) do
    case {context.trigger, context.state} do
      {:continuation, %{pending: pending} = state} when is_list(pending) ->
        write_targets(object, context, state)

      _other ->
        calculate(object, context)
    end
  end

  @spec normalize_trigger(Context.t()) :: Context.t()
  defp normalize_trigger(context) do
    case Context.write_trigger(context) do
      {:application_write, :reliability, index, priority} ->
        # Explicit Reliability simulation has the same semantics for either write origin.
        %{context | trigger: {:property_write, :reliability, index, priority}}

      nil ->
        context

      trigger ->
        %{context | trigger: trigger}
    end
  end

  @spec calculate(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  defp calculate(object, context) do
    previous = if context.trigger == :initialization, do: nil, else: context.state

    active =
      not object.out_of_service and Evaluator.active?(object, DateTime.to_date(context.now))

    {:ok, wakeup} = Evaluator.next_wakeup(object, context)

    state = %{
      value: object.present_value,
      active: active,
      out_of_service: object.out_of_service,
      pending: nil,
      next_execution: wakeup,
      failure_kind: if(previous, do: previous.failure_kind, else: nil),
      manual_reliability: manual_reliability(object, context.trigger, previous),
      configuration_fault:
        case Evaluator.datatype(object) do
          {:ok, _type} -> nil
          {:error, reason} -> reason
        end,
      failures: if(previous, do: previous.failures, else: [])
    }

    with {:ok, _type} <-
           if(object.out_of_service, do: {:ok, nil}, else: Evaluator.datatype(object)),
         {:ok, calendars} <- read_calendars(object, context, active) do
      value =
        if active,
          do: Evaluator.evaluate(object, context.now, calendars),
          else: object.present_value

      {:ok, updated} = update_property(object, :present_value, value)
      state = %{state | value: value}

      configured_values =
        if object.out_of_service,
          do: [value],
          else: Evaluator.target_values(object)

      plans =
        Targets.prepare(
          object.list_of_object_property_references,
          value,
          configured_values,
          object.priority_for_writing,
          context
        )

      configuration_failures =
        configuration_failures(object, state) ++
          for {reference, {:error, reason}} <- plans, do: {reference, reason}

      recovered =
        previous && previous.failure_kind == :configuration && configuration_failures == []

      if write_required?(updated, context.trigger, previous, state) or (active and recovered) do
        if plans == [] do
          reliability =
            if configuration_failures == [], do: :no_fault_detected, else: :configuration_error

          finish(updated, %{state | failures: configuration_failures}, reliability)
        else
          # Publish the computed value before any target writes. The host commits
          # this result and drains :continuation before its next external operation.
          state = %{state | pending: plans, failures: []}
          {:ok, %Result{object: updated, state: state, next_execution: :immediate}}
        end
      else
        finish_without_writes(updated, state, previous, configuration_failures)
      end
    else
      {:error, reason} ->
        failures = [{get_object_identifier(object), reason}]
        finish(object, %{state | failures: failures, active: false}, :configuration_error)
    end
  end

  @spec finish_without_writes(t(), execution_state(), execution_state() | nil, [
          {reference :: term(), reason :: term()}
        ]) ::
          {:ok, Result.t(t())}
  defp finish_without_writes(object, state, previous, configuration_failures) do
    cond do
      configuration_failures != [] ->
        finish(object, %{state | failures: configuration_failures}, :configuration_error)

      previous && previous.failure_kind == :write ->
        reliability =
          if Enum.any?(previous.failures, fn {_reference, reason} ->
               configuration_write_error?(reason)
             end), do: :configuration_error, else: :communication_failure

        {:ok, result} = finish(object, state, reliability)
        {:ok, %{result | state: %{result.state | failure_kind: :write}}}

      true ->
        finish(object, %{state | failures: []}, :no_fault_detected)
    end
  end

  @spec write_required?(t(), Context.trigger(), execution_state() | nil, execution_state()) ::
          boolean()
  defp write_required?(object, trigger, previous, state) do
    changed = is_nil(previous) or not Evaluator.same_value?(previous.value, state.value)

    if object.out_of_service do
      changed and match?({:property_write, :present_value, _index, _priority}, trigger)
    else
      routing_changed =
        case trigger do
          {:property_write, property, _index, _priority} ->
            property in [:list_of_object_property_references, :priority_for_writing]

          _other ->
            false
        end

      state.active and
        (changed or is_nil(previous) or not previous.active or
           previous.out_of_service or routing_changed)
    end
  end

  @spec write_targets(t(), Context.t(), execution_state()) :: {:ok, Result.t(t())}
  defp write_targets(object, context, state) do
    {failures, configuration_error} =
      Enum.reduce(
        state.pending,
        {configuration_failures(object, state), not is_nil(state.configuration_fault)},
        fn {reference, prepared}, {failures, configuration_error} ->
          case prepared do
            {:ok, value} ->
              case Context.write_property(context, reference, value, object.priority_for_writing) do
                :ok -> {failures, configuration_error}
                {:error, reason} -> {[{reference, reason} | failures], configuration_error}
              end

            {:error, reason} ->
              {[{reference, reason} | failures], true}
          end
        end
      )

    reliability =
      cond do
        configuration_error ->
          :configuration_error

        Enum.any?(failures, fn {_reference, reason} -> configuration_write_error?(reason) end) ->
          :configuration_error

        failures != [] ->
          :communication_failure

        true ->
          :no_fault_detected
      end

    {:ok, result} =
      finish(object, %{state | pending: nil, failures: Enum.reverse(failures)}, reliability)

    # Rejected writes do not become automatic retries when a metadata lookup
    # still succeeds. Only pre-write configuration faults can resynchronize.
    kind =
      cond do
        configuration_error -> :configuration
        failures != [] -> :write
        true -> nil
      end

    {:ok, %{result | state: %{result.state | failure_kind: kind}}}
  end

  @spec configuration_failures(t(), execution_state()) :: [
          {BACnet.Protocol.ObjectIdentifier.t(), reason :: term()}
        ]
  defp configuration_failures(object, state) do
    if is_nil(state.configuration_fault),
      do: [],
      else: [{get_object_identifier(object), state.configuration_fault}]
  end

  @spec configuration_write_error?(term()) :: boolean()
  defp configuration_write_error?(reason) do
    case reason do
      %BACnet.Protocol.APDU.Error{class: error_class} ->
        Constants.by_value(:error_class, error_class, error_class) in [:property, :object]

      atom
      when atom in [
             :write_access_denied,
             :unknown_object,
             :unknown_property,
             :invalid_array_index,
             :property_is_not_an_array,
             :datatype_not_supported,
             :invalid_property_value
           ] ->
        true

      {kind, _detail}
      when kind in [
             :write_access_denied,
             :unknown_property,
             :invalid_property_value,
             :invalid_property_type,
             :protected_property,
             :unsupported_capability
           ] ->
        true

      _other ->
        false
    end
  end

  @spec read_calendars(t(), Context.t(), boolean()) :: {:ok, map()} | {:error, term()}
  defp read_calendars(object, context, active)

  defp read_calendars(_object, _context, false), do: {:ok, %{}}

  defp read_calendars(object, context, true) do
    Enum.reduce_while(Evaluator.calendar_references(object), {:ok, %{}}, fn identifier,
                                                                            {:ok, values} ->
      reference = %DeviceObjectPropertyRef{
        object_identifier: identifier,
        device_identifier: nil,
        property_identifier: :present_value,
        property_array_index: nil
      }

      case Context.read_property(context, reference) do
        {:ok, value} when is_boolean(value) -> {:cont, {:ok, Map.put(values, identifier, value)}}
        {:ok, _value} -> {:halt, {:error, {:invalid_calendar_value, identifier}}}
        {:error, reason} -> {:halt, {:error, {:calendar_read_failed, identifier, reason}}}
      end
    end)
  end

  @spec finish(t(), execution_state(), Constants.reliability()) :: {:ok, Result.t(t())}
  defp finish(object, state, reliability) do
    state = %{
      state
      | failure_kind:
          case reliability do
            :configuration_error -> :configuration
            :communication_failure -> :write
            _other -> nil
          end
    }

    reliability =
      if object.reliability_evaluation_inhibit do
        if object.out_of_service and not is_nil(state.manual_reliability),
          do: state.manual_reliability,
          else: :no_fault_detected
      else
        reliability
      end

    {:ok, updated} = update_property(object, :reliability, reliability)
    {:ok, %Result{object: updated, state: state, next_execution: state.next_execution}}
  end

  @spec manual_reliability(t(), Context.trigger(), execution_state() | nil) ::
          Constants.reliability() | nil
  defp manual_reliability(object, trigger, previous) do
    cond do
      not object.out_of_service -> nil
      match?({:property_write, :reliability, _index, _priority}, trigger) -> object.reliability
      previous && previous.out_of_service -> previous.manual_reliability
      true -> nil
    end
  end

  @spec required_operations(t(), Context.t()) :: [atom()]
  defp required_operations(object, context) do
    targets = Targets.required_operations(object.list_of_object_property_references, context)

    calendars =
      if not object.out_of_service and Evaluator.calendar_references(object) != [],
        do: [:read_property],
        else: []

    targets ++ calendars
  end

  @spec valid_state(term()) :: :ok | {:error, term()}
  defp valid_state(state)

  defp valid_state(nil), do: :ok

  defp valid_state(%{
         value: %Encoding{},
         active: active,
         out_of_service: oos,
         pending: pending,
         next_execution: _wakeup,
         failure_kind: _kind,
         failures: failures
       })
       when is_boolean(active) and is_boolean(oos) and (is_nil(pending) or is_list(pending)) and
              is_list(failures),
       do: :ok

  defp valid_state(_state), do: {:error, :invalid_execution_state}

  # Override add_defaults/2, to assert weeky_schedule or exception_schedule is present
  @spec add_defaults(map(), map()) :: map() | {:error, term()}
  defp add_defaults(properties, metadata) do
    props = super(properties, metadata)

    if Map.has_key?(props, :weekly_schedule) or Map.has_key?(props, :exception_schedule) do
      props
    else
      {:error, {:missing_required_property, {:weekly_schedule, :or, :exception_schedule}}}
    end
  end
end
