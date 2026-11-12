defmodule BACnet.Protocol.ObjectExecution.IntrinsicReporting do
  @moduledoc """
  Evaluates an object's intrinsic event and fault conditions during lifecycle execution.
  Runs an object's intrinsic event and fault algorithms and records any transition.

  ## Using intrinsic reporting

  Create a supported local object with `intrinsic_reporting: true` and set its
  reporting properties. The
  [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  runs the object through `BACnet.Protocol.ObjectExecution.Lifecycle` as usual.
  The object module selects the event algorithm and any fault algorithm.

  If you are implementing an object type, update its monitored values and
  any object-specific Reliability first. Then call `evaluate/5` with that
  result, the current context, the event algorithm, the ordered property list
  for CHANGE_OF_RELIABILITY and any fault algorithm. For example,
  `BACnet.Protocol.ObjectTypes.BinaryInput` uses
  `BACnet.Protocol.EventAlgorithms.ChangeOfState` and `[:present_value]`.
  The evaluator returns the supplied result unchanged for a remote snapshot
  or when intrinsic reporting is off.

  `BACnet.Protocol.ObjectTypes.EventEnrollment` evaluates its configured
  algorithms through its own lifecycle. It shares transition bookkeeping and
  the result accessor in `BACnet.Protocol.ObjectExecution.EventReporting`.

  ## Detection, delays and retained state

  A Reliability fault takes precedence over an alarm. When the fault clears
  and the alarm condition still holds, the return to normal can request an
  immediate continuation to evaluate that alarm.

  Event_Algorithm_Inhibit suppresses alarm detection and clears an active
  offnormal state. Reliability reporting continues. With a configured inhibit
  reference, the evaluator reads it through
  `BACnet.Protocol.ObjectExecution.Context.read_property/2` and keeps the last
  inhibit value if the read fails.

  Disabling Event_Detection_Enable resets the reporting properties and clears
  pending event delays. A configured fault algorithm still runs while
  Reliability_Evaluation_Inhibit is false. Event Enrollment uses its own
  detection policy and clears both algorithm states when detection is disabled.

  An alarm or recovery condition needs to hold for its configured delay. Delay
  deadlines use the context's monotonic milliseconds. The event timestamp uses
  the context's wall time when the transition is recorded. A reporting deadline
  can add a monotonic wakeup or bring an existing monotonic wakeup forward.
  Wall-clock deadlines and immediate continuations are preserved when adding a
  reporting deadline.

  Retain the complete `BACnet.Protocol.ObjectExecution.Result` for each object
  and pass its state to the next execution. This carries both the object's core
  state and the reporting state. After a VM restart, run `:initialization` with
  fresh runtime state and clocks. See
  `BACnet.Protocol.ObjectExecution.Lifecycle` for timer arming and delivery.

  ## Recording and delivering transitions

  When the evaluator detects a transition,
  `BACnet.Protocol.ObjectExecution.EventReporting.record/5` updates the object's
  Event_State, alarm flag, timestamps, message text and acknowledgment bits.
  It uses the context's `lookup_object` callback to resolve the local
  `BACnet.Protocol.ObjectTypes.NotificationClass` and obtain the routing plan.
  Event_Enable controls the transition's `enabled` flag. A disabled transition
  or a missing routing plan still permits the object update.

  After committing each result, call
  `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` to get the
  transition, if any. If the transition is enabled and has a routing plan,
  the host needs to build and send the BACnet notification. Check the result
  before running an immediate continuation so transitions are handled in order.
  When handling AcknowledgeAlarm, commit the object returned by
  `BACnet.Protocol.ObjectExecution.EventReporting.acknowledge/3`. See the
  [lifecycle delivery example](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-intrinsic-transitions).

  ## Buffer Ready

  For Event Log, Trend Log and Trend Log Multiple, the logger tracks the
  buffer and threshold. The log callbacks use `evaluate_log/3` to check
  reporting against the current object, including a linked inhibit value,
  and request threshold evaluation from
  `BACnet.Stack.TrendLogger.evaluate_buffer_ready/2`.

  On a logger message with `event: :intrinsic_reporting`, the host finds
  the current object and retained state using the log identifier and
  executes with the `:periodic` trigger and the `:trend_logger` context option. The logger
  checks the current count during execution. A recorded TO_NORMAL transition
  advances Last_Notify_Record and resets Records_Since_Notification.
  Disabled detection, inhibition and an active reliability fault leave the
  threshold pending while collection continues. Event_Enable controls
  delivery of the recorded transition.

  ## Examples

  ### Alarm with a time delay

  Initialize an alarmed Binary Value with a two-second delay. The lookup resolves
  the Notification Class. Its default recipient list is empty in this example.

      iex> alias BACnet.Protocol.{DeviceObjectRef, EventTransitionBits, ObjectIdentifier}
      iex> alias BACnet.Protocol.ObjectExecution.{Context, EventReporting, Lifecycle}
      iex> alias BACnet.Protocol.ObjectTypes.{BinaryValue, NotificationClass}
      iex> enabled = EventTransitionBits.from_bitstring({true, false, false})
      iex> {:ok, class} = NotificationClass.create(7, "Alarms", %{notification_class: 7, ack_required: enabled})
      iex> {:ok, object} = BinaryValue.create(1, "Fan alarm", %{
      ...>   present_value: true, alarm_value: true, time_delay: 2,
      ...>   event_enable: enabled, notification_class: 7
      ...> }, intrinsic_reporting: true)
      iex> lookup = fn %DeviceObjectRef{object_identifier: %ObjectIdentifier{type: :notification_class, instance: 7}} ->
      ...>   {:ok, class}
      ...> end
      iex> initial = Context.new(:initialization, now: ~U[2026-11-11 10:00:00Z], monotonic_time: 100, lookup_object: lookup)
      iex> {:ok, pending} = Lifecycle.execute(object, initial)
      iex> {pending.next_execution.monotonic_time, EventReporting.transition(pending)}
      {2100, nil}
      iex> timer = Context.new(:timer, now: ~U[2026-11-11 10:00:02Z], monotonic_time: 2100, state: pending.state, lookup_object: lookup)
      iex> {:ok, alarm} = Lifecycle.execute(pending.object, timer)
      iex> transition = EventReporting.transition(alarm)
      iex> {alarm.object.event_state, transition.enabled, transition.routing.ack_required}
      {:offnormal, true, true}
      iex> alarm.object.event_timestamps.to_offnormal == transition.timestamp
      true

  ### Fault detection with FAULT_STATE

  Configure a `BACnet.Protocol.ObjectTypes.MultistateInput` with three states.
  State 1 is normal, state 2 is an alarm, and state 3 belongs to both the alarm
  and fault lists. The object applies
  `BACnet.Protocol.FaultAlgorithms.FaultState` to the sampled value. A sample
  of 3 sets Reliability to `:multi_state_fault` and records a
  CHANGE_OF_RELIABILITY transition to FAULT.

  When the input moves to state 2, reliability recovers and the object records
  a return to NORMAL. Since state 2 still qualifies for an alarm, the result
  requests an immediate continuation. The host commits and handles the
  recovery transition before running that continuation.

      iex> alias BACnet.Protocol.ObjectExecution.{Context, EventReporting, Lifecycle}
      iex> alias BACnet.Protocol.ObjectTypes.MultistateInput
      iex> {:ok, object} = MultistateInput.create(2, "Fan status", %{
      ...>   number_of_states: 3, present_value: 1, reliability: :no_fault_detected,
      ...>   alarm_values: [2, 3], fault_values: [3]
      ...> }, intrinsic_reporting: true)
      iex> now = ~U[2026-11-11 10:00:00Z]
      iex> initial = Context.new(:initialization, now: now, monotonic_time: 0)
      iex> {:ok, normal} = Lifecycle.execute(object, initial)
      iex> sample = fn stored, value, elapsed ->
      ...>   context = Context.new({:application_write, :present_value, nil, nil},
      ...>     now: DateTime.add(now, elapsed, :millisecond),
      ...>     monotonic_time: elapsed, state: stored.state)
      ...>   with {:ok, candidate} <- MultistateInput.set_input(stored.object, value),
      ...>        {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, context) do
      ...>     Lifecycle.execute(prepared, context)
      ...>   end
      ...> end
      iex> {:ok, fault} = sample.(normal, 3, 100)
      iex> transition = EventReporting.transition(fault)
      iex> {fault.object.reliability, fault.object.status_flags.fault, transition.event_type, transition.to_state}
      {:multi_state_fault, true, :change_of_reliability, :fault}
      iex> {:ok, recovered} = sample.(fault, 2, 200)
      iex> transition = EventReporting.transition(recovered)
      iex> {recovered.object.reliability, transition.event_type, transition.to_state, recovered.next_execution}
      {:no_fault_detected, :change_of_reliability, :normal, :immediate}
      iex> continuation = Context.new(:continuation,
      ...>   now: DateTime.add(now, 200, :millisecond),
      ...>   monotonic_time: 200, state: recovered.state)
      iex> {:ok, alarm} = Lifecycle.execute(recovered.object, continuation)
      iex> transition = EventReporting.transition(alarm)
      iex> {transition.event_type, transition.to_state}
      {:change_of_state, :offnormal}
  """

  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.EventAlgorithms
  alias BACnet.Protocol.EventParameters
  alias BACnet.Protocol.FaultAlgorithms
  alias BACnet.Protocol.FaultParameters
  alias BACnet.Protocol.LimitEnable
  alias BACnet.Protocol.NotificationParameters
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectPropertyRef
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.PropertyState
  alias BACnet.Protocol.PropertyValue
  alias BACnet.Protocol.StatusFlags
  alias BACnet.Stack.TrendLogger

  @typedoc """
  The event algorithm module selected by the object type.
  """
  @type algorithm ::
          EventAlgorithms.BufferReady
          | EventAlgorithms.ChangeOfBitstring
          | EventAlgorithms.ChangeOfCharacterString
          | EventAlgorithms.ChangeOfState
          | EventAlgorithms.CommandFailure
          | EventAlgorithms.DoubleOutOfRange
          | EventAlgorithms.FloatingLimit
          | EventAlgorithms.None
          | EventAlgorithms.OutOfRange
          | EventAlgorithms.SignedOutOfRange
          | EventAlgorithms.UnsignedOutOfRange
          | EventAlgorithms.UnsignedRange

  @typedoc """
  An optional fault algorithm selected by the object module.

  A built-in module reads its inputs from the reconciled object:

  - `BACnet.Protocol.FaultAlgorithms.FaultState` and
    `BACnet.Protocol.FaultAlgorithms.FaultCharacterString` use Present_Value
    and Fault_Values.
  - `BACnet.Protocol.FaultAlgorithms.FaultLifeSafety` also uses Mode.
  - `BACnet.Protocol.FaultAlgorithms.FaultStatusFlags` uses Member_Status_Flags.

  For custom algorithms or other input sources, pass
  `{module, constructor_args, updates}`. The module's `new/N` returns its
  state struct, and `execute/1` returns `{:event, state, reliability}` or
  `{:no_event, state}`. The state carries `current_reliability`. Nonempty
  keyword updates are passed to `update/2` on subsequent executions. Use an
  empty list for fixed inputs.

  The two-element form `{module, constructor_args}` infers updates for
  `[value, parameters]` and `[value, mode, parameters]`. Other argument
  counts retain the state with fixed inputs. Vendor-specific
  `BACnet.Protocol.FaultAlgorithms.FaultExtended` requires a vendor implementation.
  """
  @type fault_algorithm ::
          nil
          | FaultAlgorithms.FaultCharacterString
          | FaultAlgorithms.FaultLifeSafety
          | FaultAlgorithms.FaultState
          | FaultAlgorithms.FaultStatusFlags
          | {module(), constructor_args :: [term()]}
          | {module(), constructor_args :: [term()], updates :: Keyword.t()}

  @typep inputs ::
           {Constants.event_type(), constructor_args :: [term()], updates :: Keyword.t()}

  @typep pending :: {condition :: term(), delay :: non_neg_integer(), due :: integer()}

  @typedoc """
  Reporting state retained between executions of the same object.
  """
  @type state :: %{
          algorithm: struct() | nil,
          fault_state: struct() | nil,
          pending: pending() | nil,
          reliability: Constants.reliability(),
          transition: EventReporting.transition() | nil
        }

  @range_algorithms %{
    EventAlgorithms.OutOfRange => {:out_of_range, EventParameters.OutOfRange},
    EventAlgorithms.DoubleOutOfRange => {:double_out_of_range, EventParameters.DoubleOutOfRange},
    EventAlgorithms.SignedOutOfRange => {:signed_out_of_range, EventParameters.SignedOutOfRange},
    EventAlgorithms.UnsignedOutOfRange =>
      {:unsigned_out_of_range, EventParameters.UnsignedOutOfRange}
  }

  require Constants

  @uninitialized Constants.macro_by_name(:asn1, :max_instance_and_property_id)

  @doc """
  Evaluates reporting after the object reconciles its properties and reliability.

  Supply the algorithm module selected by the object type. The evaluator
  converts the object's properties to the inputs required by that algorithm.
  Binary and multistate objects can share an algorithm module while supplying
  different BACnet value types. Use `BACnet.Protocol.EventAlgorithms.None` for
  reliability-only reporting.

  `fault_properties` lists properties in their required notification order.
  Unselected properties are omitted. Pass `fault_algorithm` to evaluate an
  additional fault condition. While reliability evaluation is enabled, the
  configured algorithm supplies Reliability and the FAULT flag on every
  execution, including recovery to `:no_fault_detected`. The evaluator
  retains the algorithm state between calls. When reliability evaluation is
  inhibited, the object supplies Reliability and the evaluator discards the
  fault algorithm state. Evaluation resumes with a fresh state built from the
  current inputs.

  Existing lifecycle wakeups are retained alongside reporting deadlines.
  """
  @spec evaluate(
          Result.t(object),
          Context.t(),
          algorithm(),
          [Constants.property_identifier()],
          fault_algorithm()
        ) :: Result.t(object)
        when object: struct()
  def evaluate(result, context, algorithm, fault_properties, fault_algorithm \\ nil)

  def evaluate(
        %Result{object: %{_metadata: %{intrinsic_reporting: true, remote_object: nil}}} = result,
        %Context{} = context,
        algorithm,
        fault_properties,
        fault_algorithm
      ) do
    previous = previous_reporting(context)

    {object, fault_state, fault_transition?} =
      evaluate_configured_fault(
        result.object,
        fault_algorithm,
        Map.get(previous, :fault_state)
      )

    result = %{result | object: object}
    reliability = Map.get(object, :reliability) || :no_fault_detected

    reporting = %{
      algorithm: nil,
      fault_state: fault_state,
      pending: nil,
      reliability: reliability,
      transition: nil
    }

    state =
      case {algorithm, result.state} do
        {EventAlgorithms.BufferReady, state} -> %{execution_state: state}
        {_algorithm, state} when is_map(state) -> state
        {_algorithm, nil} -> %{}
        {_algorithm, state} -> %{execution_state: state}
      end

    result = %{result | state: Map.put(state, :reporting, reporting)}

    if object.event_detection_enable == false do
      %{result | object: EventReporting.reset(object)}
    else
      object =
        if algorithm == EventAlgorithms.None, do: object, else: read_inhibit(object, context)

      result = %{result | object: object}

      if reliability != :no_fault_detected or object.event_state == :fault do
        evaluate_reliability(
          result,
          context,
          algorithm,
          previous,
          fault_properties,
          fault_transition?
        )
      else
        evaluate_event(result, context, algorithm, previous)
      end
    end
  end

  def evaluate(%Result{} = result, %Context{}, _algorithm, _fault_properties, _fault_algorithm),
    do: result

  @doc """
  Evaluates reporting for a local log and projects its current logger counters.

  The logger evaluates the threshold against the reconciled reporting state
  and returns the resulting counters together with any BUFFER_READY payload.
  Fault and recovery transitions are recorded before a separate BUFFER_READY
  transition can be evaluated.
  """
  @spec evaluate_log(Result.t(object), Context.t(), TrendLogger.server()) ::
          {:ok, Result.t(object)} | {:error, term()}
        when object: TrendLogger.object()
  def evaluate_log(%Result{} = result, %Context{} = context, logger) do
    evaluated = evaluate(result, context, EventAlgorithms.BufferReady, [])

    case EventReporting.transition(evaluated) do
      nil ->
        with {:ok, snapshot, notification} <-
               TrendLogger.evaluate_buffer_ready(logger, evaluated.object) do
          result = project_log_snapshot(evaluated, snapshot)

          if notification do
            {:ok, record(result, context, :normal, :buffer_ready, notification)}
          else
            {:ok, result}
          end
        end

      _transition ->
        with {:ok, snapshot} <- TrendLogger.get_snapshot(logger, evaluated.object) do
          {:ok, project_log_snapshot(evaluated, snapshot)}
        end
    end
  end

  @spec project_log_snapshot(Result.t(object), TrendLogger.snapshot()) :: Result.t(object)
        when object: TrendLogger.object()
  defp project_log_snapshot(%Result{object: object} = result, snapshot) do
    object = %{
      object
      | enable: snapshot.enable,
        log_buffer: [],
        record_count: snapshot.record_count,
        total_record_count: snapshot.total_record_count,
        records_since_notification: snapshot.records_since_notification,
        last_notify_record: snapshot.last_notify_record
    }

    %{result | object: object}
  end

  @doc """
  Checks the retained reporting state. A nil state is valid before evaluation.
  """
  @spec valid_state?(term()) :: boolean()
  def valid_state?(state)

  def valid_state?(nil), do: true

  def valid_state?(%{
        algorithm: algorithm,
        pending: pending,
        reliability: reliability,
        transition: _transition
      })
      when (is_nil(algorithm) or is_struct(algorithm)) and is_atom(reliability) do
    valid_pending?(pending) and
      match?({:ok, _value}, Constants.by_name(:reliability, reliability))
  end

  def valid_state?(_state), do: false

  @spec valid_pending?(term()) :: boolean()
  defp valid_pending?(pending)
  defp valid_pending?(nil), do: true

  defp valid_pending?({_condition, delay, due}),
    do: is_integer(delay) and delay > 0 and is_integer(due)

  defp valid_pending?(_pending), do: false

  @doc """
  Extracts a log's continuation state from an intrinsic-reporting result state.
  """
  @spec log_execution_state(term()) :: term()
  def log_execution_state(state)
  def log_execution_state(%{reporting: %{}, execution_state: state}), do: state
  def log_execution_state(state), do: state

  @spec evaluate_configured_fault(struct(), fault_algorithm(), struct() | nil) ::
          {object :: struct(), fault_state :: struct() | nil, fault_transition? :: boolean()}
  defp evaluate_configured_fault(object, selection, previous)

  defp evaluate_configured_fault(
         %{reliability_evaluation_inhibit: true} = object,
         _selection,
         _previous
       ),
       do: {object, nil, false}

  defp evaluate_configured_fault(object, selection, previous) do
    case fault_inputs(object, selection) do
      {module, arguments, updates} ->
        {reliability, fault, transition} =
          EventReporting.run_fault_algorithm(module, arguments, updates, previous)

        flags = %{object.status_flags | fault: reliability != :no_fault_detected}

        {%{object | reliability: reliability, status_flags: flags}, fault,
         transition == :retained}

      nil ->
        {object, nil, false}
    end
  end

  @spec fault_inputs(struct(), fault_algorithm()) :: {module(), [term()], Keyword.t()} | nil
  defp fault_inputs(object, selection)

  defp fault_inputs(
         %{present_value: present_value, fault_values: faults},
         FaultAlgorithms.FaultState
       )
       when is_list(faults) do
    value = %PropertyState{type: :unsigned_value, value: present_value}
    params = %FaultParameters.FaultState{fault_values: Enum.map(faults, &%{value | value: &1})}
    fault_selection(FaultAlgorithms.FaultState, [value, params])
  end

  defp fault_inputs(
         %{present_value: value, fault_values: %BACnetArray{} = faults},
         FaultAlgorithms.FaultCharacterString
       ) do
    params = %FaultParameters.FaultCharacterString{fault_values: BACnetArray.to_list(faults)}
    fault_selection(FaultAlgorithms.FaultCharacterString, [value, params])
  end

  defp fault_inputs(
         %{present_value: value, mode: mode, fault_values: faults} = object,
         FaultAlgorithms.FaultLifeSafety
       )
       when is_list(faults) do
    params = %FaultParameters.FaultLifeSafety{
      mode: fault_property_reference(object, :mode),
      fault_values: faults
    }

    fault_selection(FaultAlgorithms.FaultLifeSafety, [value, mode, params])
  end

  defp fault_inputs(
         %{member_status_flags: %StatusFlags{} = flags} = object,
         FaultAlgorithms.FaultStatusFlags
       ) do
    params = %FaultParameters.FaultStatusFlags{
      status_flags: fault_property_reference(object, :member_status_flags)
    }

    fault_selection(FaultAlgorithms.FaultStatusFlags, [flags, params])
  end

  defp fault_inputs(_object, {module, arguments}), do: fault_selection(module, arguments)
  defp fault_inputs(_object, {_module, _arguments, _updates} = selection), do: selection
  defp fault_inputs(_object, _selection), do: nil

  @spec fault_selection(module(), [term()]) :: {module(), [term()], Keyword.t()}
  defp fault_selection(module, arguments)

  defp fault_selection(module, [value, parameters] = arguments),
    do: {module, arguments, [monitored_value: value, parameters: parameters]}

  defp fault_selection(module, [value, mode, parameters] = arguments),
    do: {module, arguments, [monitored_value: value, mode: mode, parameters: parameters]}

  defp fault_selection(module, arguments), do: {module, arguments, []}

  @spec fault_property_reference(struct(), Constants.property_identifier()) ::
          DeviceObjectPropertyRef.t()
  defp fault_property_reference(%module{} = object, property) do
    %DeviceObjectPropertyRef{
      device_identifier: nil,
      object_identifier: module.get_object_identifier(object),
      property_identifier: property,
      property_array_index: nil
    }
  end

  @spec previous_reporting(Context.t()) :: state() | map()
  defp previous_reporting(context)

  defp previous_reporting(%Context{trigger: trigger, state: %{reporting: reporting}})
       when trigger != :initialization and is_map(reporting), do: reporting

  defp previous_reporting(_context), do: %{}

  @spec evaluate_reliability(Result.t(), Context.t(), algorithm(), map(), [atom()], boolean()) ::
          Result.t()
  defp evaluate_reliability(result, context, algorithm, previous, properties, fault_transition?) do
    object = result.object
    reliability = result.state.reporting.reliability
    target = if reliability == :no_fault_detected, do: :normal, else: :fault
    previous_reliability = Map.get(previous, :reliability, reliability)

    if object.event_state != target or reliability != previous_reliability or fault_transition? do
      values = %NotificationParameters.ChangeOfReliability{
        reliability: reliability,
        status_flags: %{object.status_flags | in_alarm: target != :normal},
        property_values: fault_values(object, properties)
      }

      result = record(result, context, target, :change_of_reliability, values)

      if target == :normal and not object.event_algorithm_inhibit and
           (algorithm == EventAlgorithms.BufferReady or
              event_condition_present?(algorithm, result.object, context.now)) do
        %{result | next_execution: :immediate}
      else
        result
      end
    else
      result
    end
  end

  @spec fault_values(struct(), [atom()]) :: [PropertyValue.t()]
  defp fault_values(%module{} = object, properties) do
    identifier = module.get_object_identifier(object)

    for property <- properties,
        value = Map.get(object, property),
        not is_nil(value),
        {:ok, encoded} <- [ObjectsUtility.cast_value_to_property(identifier, property, value)] do
      %PropertyValue{
        property_identifier: property,
        property_array_index: nil,
        property_value: encoded,
        priority: nil
      }
    end
  end

  @spec evaluate_event(Result.t(), Context.t(), algorithm(), map()) :: Result.t()
  defp evaluate_event(result, context, module, previous)

  defp evaluate_event(result, context, module, previous) do
    object = result.object

    case event_inputs(module, object) do
      {type, args, updates} ->
        algorithm =
          restore_algorithm(module, args, updates, object, Map.get(previous, :algorithm))

        if object.event_algorithm_inhibit do
          if object.event_state == :normal do
            result
          else
            record(result, context, :normal, type, EventReporting.normal_notification(algorithm))
          end
        else
          case module.execute(algorithm, context.now) do
            {:event, candidate, values} ->
              delay_event(result, context, type, algorithm, candidate, values, previous)

            {:no_event, algorithm} ->
              put_in(result.state.reporting.algorithm, algorithm)
          end
        end

      nil ->
        result
    end
  end

  @spec restore_algorithm(module(), [term()], Keyword.t(), struct(), struct() | nil) :: struct()
  defp restore_algorithm(module, args, updates, object, previous) do
    updates = Keyword.put(updates, :status_flags, object.status_flags)

    case previous do
      %{__struct__: ^module, current_state: state} when state == object.event_state ->
        module.update(previous, updates)

      _other ->
        module
        |> new_algorithm(args)
        |> module.update(updates)
        |> restore_event_state(object.event_state)
    end
  end

  @spec new_algorithm(module(), [term()]) :: struct()
  defp new_algorithm(module, args)
  defp new_algorithm(module, [value, params]), do: module.new(value, params)
  defp new_algorithm(module, [value, limit, params]), do: module.new(value, limit, params)

  @spec restore_event_state(struct(), Constants.event_state()) :: struct()
  defp restore_event_state(%module{} = algorithm, state) do
    # A restored offnormal object has already reported its current alarm value.
    algorithm =
      if state == :offnormal do
        case module.execute(algorithm, ~U[2000-01-01 00:00:00Z]) do
          {:event, candidate, _values} ->
            candidate

          {:no_event, %{last_alarm_value: nil} = candidate} ->
            %{candidate | last_alarm_value: ""}

          {:no_event, candidate} ->
            candidate
        end
      else
        algorithm
      end

    %{algorithm | current_state: state}
  end

  @spec event_condition_present?(algorithm(), struct(), DateTime.t()) :: boolean()
  defp event_condition_present?(module, object, now) do
    case event_inputs(module, object) do
      {_type, args, updates} ->
        algorithm = module.update(new_algorithm(module, args), updates)
        match?({:event, _candidate, _values}, module.execute(algorithm, now))

      nil ->
        false
    end
  end

  @spec delay_event(
          Result.t(),
          Context.t(),
          Constants.event_type(),
          struct(),
          struct(),
          struct(),
          map()
        ) :: Result.t()
  defp delay_event(result, context, type, algorithm, candidate, values, previous) do
    object = result.object
    target = candidate.current_state
    delay = delay_seconds(object, target)
    condition = event_condition(type, candidate)
    now = context.monotonic_time

    due =
      case Map.get(previous, :pending) do
        {^condition, ^delay, due} -> due
        _other -> now + delay * 1000
      end

    if due <= now do
      result = put_in(result.state.reporting.algorithm, candidate)
      record(result, context, target, type, values)
    else
      result = put_in(result.state.reporting.algorithm, algorithm)
      result = put_in(result.state.reporting.pending, {condition, delay, due})
      %{result | next_execution: merge_deadline(result.next_execution, due)}
    end
  end

  @spec delay_seconds(struct(), Constants.event_state()) :: non_neg_integer()
  defp delay_seconds(object, target)

  defp delay_seconds(
         %{event_state: :high_limit, limit_enable: %LimitEnable{high_limit_enable: false}},
         :normal
       ),
       do: 0

  defp delay_seconds(
         %{event_state: :low_limit, limit_enable: %LimitEnable{low_limit_enable: false}},
         :normal
       ),
       do: 0

  defp delay_seconds(object, :normal), do: object.time_delay_normal || object.time_delay || 0
  defp delay_seconds(object, _target), do: object.time_delay || 0

  @spec event_condition(Constants.event_type(), struct()) :: term()
  defp event_condition(type, candidate)

  defp event_condition(:change_of_characterstring, candidate),
    do: {candidate.current_state, candidate.last_alarm_value}

  defp event_condition(type, candidate) when type in [:change_of_state, :change_of_bitstring],
    do: {candidate.current_state, candidate.last_value}

  defp event_condition(_type, candidate), do: candidate.current_state

  @spec merge_deadline(Wakeup.t() | :immediate | nil, integer()) :: Wakeup.t() | :immediate
  defp merge_deadline(wakeup, due)
  defp merge_deadline(:immediate, _due), do: :immediate
  defp merge_deadline(nil, due), do: %Wakeup{wall_time: nil, monotonic_time: due}

  defp merge_deadline(%Wakeup{monotonic_time: previous} = wakeup, due),
    do: %{wakeup | monotonic_time: min(previous || due, due)}

  @spec record(
          Result.t(),
          Context.t(),
          Constants.event_state(),
          Constants.event_type(),
          struct() | nil
        ) ::
          Result.t()
  defp record(result, context, target, event_type, values) do
    {object, transition} =
      EventReporting.record(result.object, target, event_type, values, context)

    result = put_in(result.state.reporting.transition, transition)
    %{result | object: object}
  end

  @spec read_inhibit(struct(), Context.t()) :: struct()
  defp read_inhibit(object, context) do
    case object.event_algorithm_inhibit_ref do
      %ObjectPropertyRef{object_identifier: %ObjectIdentifier{instance: instance} = id} = ref
      when instance != @uninitialized ->
        reference = %DeviceObjectPropertyRef{
          device_identifier: nil,
          object_identifier: id,
          property_identifier: ref.property_identifier,
          property_array_index: ref.property_array_index
        }

        case Context.read_property(context, reference) do
          {:ok, value} when value in [true, :active] ->
            %{object | event_algorithm_inhibit: true}

          {:ok, value} when value in [false, :inactive] ->
            %{object | event_algorithm_inhibit: false}

          _other ->
            object
        end

      _other ->
        object
    end
  end

  @spec event_inputs(algorithm(), struct()) :: inputs() | nil
  defp event_inputs(module, object)

  defp event_inputs(EventAlgorithms.ChangeOfState, %{present_value: value, alarm_value: alarm})
       when is_boolean(value) do
    change_of_state(:binary_value, value, [alarm])
  end

  defp event_inputs(EventAlgorithms.ChangeOfState, %{present_value: value, alarm_values: alarms}) do
    change_of_state(:unsigned_value, value, alarms || [])
  end

  defp event_inputs(EventAlgorithms.CommandFailure, %{
         present_value: value,
         feedback_value: feedback
       })
       when is_boolean(value) do
    command_failure(:enumerated, binary_number(value), binary_number(feedback))
  end

  defp event_inputs(EventAlgorithms.CommandFailure, %{
         present_value: value,
         feedback_value: feedback
       }) do
    command_failure(:unsigned_integer, value, feedback)
  end

  defp event_inputs(
         module,
         %{present_value: value, high_limit: high, low_limit: low, deadband: deadband} = object
       )
       when is_map_key(@range_algorithms, module) and is_number(value) and is_number(high) and
              is_number(low) and is_number(deadband) do
    {type, parameters} = Map.fetch!(@range_algorithms, module)
    limit = object.limit_enable || %LimitEnable{high_limit_enable: false, low_limit_enable: false}

    params =
      struct!(parameters,
        high_limit: high,
        low_limit: low,
        deadband: deadband,
        time_delay: 0,
        time_delay_normal: 0
      )

    {type, [value, limit, params],
     [monitored_value: value, limit_enable: limit, parameters: params]}
  end

  defp event_inputs(EventAlgorithms.UnsignedRange, object) do
    params = %EventParameters.UnsignedRange{
      high_limit: object.high_limit,
      low_limit: object.low_limit,
      time_delay: 0,
      time_delay_normal: 0
    }

    value = object.pulse_rate

    {:unsigned_range, [value, params], [monitored_value: value, parameters: params]}
  end

  defp event_inputs(EventAlgorithms.ChangeOfBitstring, %{bit_mask: mask} = object)
       when is_tuple(mask) do
    params = %EventParameters.ChangeOfBitstring{
      alarm_values: object.alarm_values,
      bitmask: mask,
      time_delay: 0,
      time_delay_normal: 0
    }

    value = object.present_value

    {:change_of_bitstring, [value, params], [monitored_value: value, parameters: params]}
  end

  defp event_inputs(EventAlgorithms.ChangeOfCharacterString, object) do
    params = %EventParameters.ChangeOfCharacterString{
      alarm_values:
        if(object.alarm_values, do: BACnetArray.to_list(object.alarm_values), else: []),
      time_delay: 0,
      time_delay_normal: 0
    }

    value = object.present_value

    {:change_of_characterstring, [value, params], [monitored_value: value, parameters: params]}
  end

  defp event_inputs(EventAlgorithms.FloatingLimit, object) do
    params = %EventParameters.FloatingLimit{
      setpoint: object.setpoint_reference,
      high_diff_limit: object.error_limit,
      low_diff_limit: object.error_limit,
      deadband: object.deadband,
      time_delay: 0,
      time_delay_normal: 0
    }

    value = object.controlled_variable_value

    {:floating_limit, [value, params],
     [monitored_value: value, setpoint: object.setpoint, parameters: params]}
  end

  defp event_inputs(_module, _object), do: nil

  @spec change_of_state(atom(), term(), [term()]) :: inputs()
  defp change_of_state(type, value, alarms) do
    value = %PropertyState{type: type, value: value}

    params = %EventParameters.ChangeOfState{
      alarm_values: Enum.map(alarms, &%{value | value: &1}),
      time_delay: 0,
      time_delay_normal: 0
    }

    {:change_of_state, [value, params], [monitored_value: value, parameters: params]}
  end

  @spec command_failure(atom(), non_neg_integer() | nil, non_neg_integer() | nil) ::
          inputs() | nil
  defp command_failure(type, value, feedback)

  defp command_failure(type, value, feedback) when is_integer(value) and is_integer(feedback) do
    value = Encoding.create!({type, value})
    feedback = Encoding.create!({type, feedback})

    params = %EventParameters.CommandFailure{
      feedback_value: feedback,
      time_delay: 0,
      time_delay_normal: 0
    }

    {:command_failure, [value, params], [monitored_value: value, parameters: params]}
  end

  defp command_failure(_type, _value, _feedback), do: nil

  @spec binary_number(boolean() | nil) :: 0 | 1 | nil
  defp binary_number(value)
  defp binary_number(true), do: 1
  defp binary_number(false), do: 0
  defp binary_number(nil), do: nil
end
