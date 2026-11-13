defmodule BACnet.Protocol.ObjectTypes.EventEnrollment do
  @moduledoc """
  An Event Enrollment monitors a property on a local or remote object. Use
  one to report events for a source that lacks its own intrinsic reporting.
  The enrollment holds the algorithm configuration and event state and refers
  to a Notification Class for delivery.

  ### Object Description (ASHRAE 135)

  > The Event Enrollment object type defines a standardized object that represents
  > and contains the information required for algorithmic reporting of events.
  > For the general event concepts and algorithmic event reporting, see Clause 13.2.

  ### Behaviour and Operation

  `object_property_reference` selects the value to monitor. `event_parameters`
  selects the event algorithm and its inputs. An optional `fault_parameters`
  selects the fault algorithm. The object derives `event_type` and `fault_type`
  from those parameters. The enrollment only reads the monitored object.

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  supplies the `:read_property` callback in `BACnet.Protocol.ObjectExecution.Context`.
  The enrollment passes local and device-qualified references to that callback,
  including any array index. For remote monitoring, the host can use
  `BACnet.Stack.ClientHelper.read_property/5` and return the property's native
  value. For an optional property that is absent, return an unknown-property
  error. The enrollment also reads inputs selected by the algorithm, such as
  the monitored object's status flags, a feedback or setpoint reference, or a
  life safety mode.

  Execute when the enrollment starts, an input changes, a configuration write
  commits or a timer comes due. For a remote source, the host can also poll with
  `:periodic`. Retain each result and schedule any requested monotonic deadline.
  The algorithm uses monotonic time to measure delays and local wall time for
  event timestamps and Notification Class delivery windows. A property read
  returns the last evaluated state and preserves any pending deadline.

  #### Reliability and inhibition

  Acquisition and configuration failures take precedence over a fault reported by
  the monitored object, which takes precedence over the optional fault algorithm.
  Fault transitions take precedence over offnormal events. An initialized
  `event_algorithm_inhibit_ref` controls the inhibit flag from a local Boolean or
  BinaryPV property. Inhibition returns an offnormal event to NORMAL and starts a
  fresh delay when released. Fault detection can continue while the event algorithm
  is inhibited. `reliability_evaluation_inhibit` suppresses reliability evaluation.
  Disabling `event_detection_enable` resets event state, timestamps, messages and
  acknowledgment bits and clears the retained event and fault algorithm states.

  #### Transitions and delivery

  Each transition updates its event timestamp, message and acknowledgment bit.
  The enrollment uses `BACnet.Protocol.ObjectExecution.Context.lookup_object/2`
  to find the Notification Class, which provides the eligible recipients and
  acknowledgment requirement. If lookup fails, the enrollment records the
  transition with a `nil` routing plan and no acknowledgment requirement.

  After committing the result, call `transition/1` to get the recorded transition.
  For an enabled transition with a routing plan, the host builds either a
  `BACnet.Protocol.Services.ConfirmedEventNotification` or
  an `BACnet.Protocol.Services.UnconfirmedEventNotification` for each recipient.
  To process an alarm acknowledgment, the host validates the acknowledged event
  state and uses `acknowledge/3` to match the last timestamp and update the bit. It
  handles delivery of the resulting acknowledgment notification.

  The lifecycle supports NONE and the implemented standard event and fault
  algorithms. An enabled enrollment with a vendor-specific Extended algorithm
  returns an unsupported-algorithm error.

  ### Example

  Monitor an unsigned Present_Value and hold the high-limit condition for five
  seconds before emitting a transition.

      iex> alias BACnet.Protocol.{DeviceObjectPropertyRef, EventParameters, ObjectIdentifier, StatusFlags}
      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> alias BACnet.Protocol.ObjectTypes.{EventEnrollment, NotificationClass}
      iex> reference = %DeviceObjectPropertyRef{
      ...>   device_identifier: nil,
      ...>   object_identifier: %ObjectIdentifier{type: :positive_integer_value, instance: 2},
      ...>   property_identifier: :present_value,
      ...>   property_array_index: nil
      ...> }
      iex> {:ok, enrollment} = EventEnrollment.create(1100, "High value", %{
      ...>   notification_class: 1,
      ...>   object_property_reference: reference,
      ...>   event_parameters: %EventParameters.UnsignedRange{
      ...>     low_limit: 1, high_limit: 10, time_delay: 5, time_delay_normal: nil
      ...>   }
      ...> })
      iex> {:ok, class} = NotificationClass.create(1, "Alarms", %{notification_class: 1})
      iex> read = fn
      ...>   %{property_identifier: :present_value} -> {:ok, 12}
      ...>   %{property_identifier: :reliability} -> {:ok, :no_fault_detected}
      ...>   %{property_identifier: :status_flags} -> {:ok, StatusFlags.from_bitstring({false, false, false, false})}
      ...> end
      iex> now = ~U[2026-06-01 12:00:00Z]
      iex> context = Context.new(:initialization,
      ...>   now: now, monotonic_time: 0, read_property: read,
      ...>   lookup_object: fn _reference -> {:ok, class} end
      ...> )
      iex> {:ok, pending} = Lifecycle.execute(enrollment, context)
      iex> pending.next_execution.monotonic_time
      5000
      iex> timer = %{context | trigger: :timer, now: DateTime.add(now, 5, :second),
      ...>   monotonic_time: 5000, state: pending.state}
      iex> {:ok, evaluated} = Lifecycle.execute(pending.object, timer)
      iex> evaluated.object.event_state
      :high_limit
      iex> EventEnrollment.transition(evaluated).transition
      :to_offnormal

  ### See Also
  - `BACnet.Protocol.EventAlgorithms`
  - `BACnet.Protocol.FaultAlgorithms`
  - Related: `BACnet.Protocol.ObjectTypes.NotificationClass`
  """

  alias BACnet.Protocol.APDU
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.BACnetTimestamp
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.EventAlgorithms
  alias BACnet.Protocol.EventMessageTexts
  alias BACnet.Protocol.EventParameters
  alias BACnet.Protocol.EventTimestamps
  alias BACnet.Protocol.EventTransitionBits
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
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.PropertyState
  alias BACnet.Protocol.PropertyValue
  alias BACnet.Protocol.StatusFlags

  import BACnet.Internal, only: [unless_env: 2]
  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring an Event Enrollment object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents an Event Enrollment object. Treat struct fields as read-only. Use the object module's
  property functions to build updates.
  """
  bac_object Constants.macro_assert_name(:object_type, :event_enrollment) do
    services(intrinsic: false)

    field(:description, String.t())

    field(:event_type, Constants.event_type(), required: true, readonly: true, default: :none)
    field(:notify_type, Constants.notify_type(), required: true, default: :alarm)

    field(:event_parameters, EventParameters.event_parameter(),
      required: true,
      default: %EventParameters.None{}
    )

    field(:object_property_reference, DeviceObjectPropertyRef.t(),
      required: true,
      default: ObjectsMacro.get_default_dev_object_ref()
    )

    field(:event_state, Constants.event_state(), required: true, readonly: true, default: :normal)

    field(:event_enable, EventTransitionBits.t(),
      required: true,
      default: ObjectsMacro.get_default_event_transbits(true)
    )

    field(:acked_transitions, EventTransitionBits.t(),
      required: true,
      readonly: true,
      default: ObjectsMacro.get_default_event_transbits(true)
    )

    field(:notification_class, non_neg_integer(), required: true)

    field(:event_timestamps, EventTimestamps.t(),
      required: true,
      readonly: true,
      default: fn ->
        stamp = ObjectsMacro.get_default_bacnet_timestamp()
        %EventTimestamps{to_offnormal: stamp, to_fault: stamp, to_normal: stamp}
      end
    )

    field(:event_message_texts, EventMessageTexts.t(),
      readonly: true,
      default: %EventMessageTexts{to_offnormal: "", to_fault: "", to_normal: ""}
    )

    field(:event_message_texts_config, EventMessageTexts.t())
    field(:event_detection_enable, boolean(), required: true, default: true)

    field(:event_algorithm_inhibit, boolean(), default: false)

    field(:event_algorithm_inhibit_ref, ObjectPropertyRef.t(),
      implicit_relationship: :event_algorithm_inhibit
    )

    field(:time_delay_normal, non_neg_integer())
    field(:status_flags, StatusFlags.t(), required: true, readonly: true)

    field(:reliability, Constants.reliability(),
      required: true,
      readonly: true,
      default: :no_fault_detected
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:fault_type, Constants.fault_type(), readonly: true, default: :none)

    field(:fault_parameters, FaultParameters.fault_parameter(),
      default: %FaultParameters.None{},
      implicit_relationship: :fault_type
    )
  end

  @event_algorithms %{
    change_of_bitstring: EventAlgorithms.ChangeOfBitstring,
    change_of_state: EventAlgorithms.ChangeOfState,
    change_of_value: EventAlgorithms.ChangeOfValue,
    command_failure: EventAlgorithms.CommandFailure,
    floating_limit: EventAlgorithms.FloatingLimit,
    out_of_range: EventAlgorithms.OutOfRange,
    change_of_life_safety: EventAlgorithms.ChangeOfLifeSafety,
    buffer_ready: EventAlgorithms.BufferReady,
    unsigned_range: EventAlgorithms.UnsignedRange,
    double_out_of_range: EventAlgorithms.DoubleOutOfRange,
    signed_out_of_range: EventAlgorithms.SignedOutOfRange,
    unsigned_out_of_range: EventAlgorithms.UnsignedOutOfRange,
    change_of_characterstring: EventAlgorithms.ChangeOfCharacterString,
    change_of_status_flags: EventAlgorithms.ChangeOfStatusFlags
  }

  @fault_algorithms %{
    fault_characterstring: FaultAlgorithms.FaultCharacterString,
    fault_life_safety: FaultAlgorithms.FaultLifeSafety,
    fault_state: FaultAlgorithms.FaultState,
    fault_status_flags: FaultAlgorithms.FaultStatusFlags
  }

  @range_events [
    :out_of_range,
    :double_out_of_range,
    :signed_out_of_range,
    :unsigned_out_of_range
  ]
  @uninitialized Constants.macro_by_name(:asn1, :max_instance_and_property_id)

  @typedoc """
  A transition produced by the current execution step. The host uses its routing
  plan to deliver the event if the transition is enabled. A nil routing plan
  indicates that the Notification Class could not be resolved.
  """
  @type transition :: EventReporting.transition()

  @typep execution_state :: %{
           configuration: map(),
           clock: {base_time :: DateTime.t(), monotonic_time :: integer()},
           event: struct() | nil,
           fault: struct() | nil,
           next_execution: Wakeup.t() | :immediate | nil,
           transition: transition() | nil
         }

  @typep sample :: %{value: term(), reliability: Constants.reliability() | nil}
  @typep acquisition_error :: {:error, Constants.reliability()}

  @doc """
  Checks selected algorithms, parameters and property references.

  An enabled local enrollment rejects unsupported algorithms and invalid
  configuration before acquiring a monitored value. Remote snapshots and
  enrollments with detection disabled pass preflight.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec validate_execution(t(), Context.t()) :: :ok | {:error, term()}
  def validate_execution(object, context)

  def validate_execution(%__MODULE__{_metadata: %{remote_object: remote}}, %Context{})
      when not is_nil(remote),
      do: :ok

  def validate_execution(%__MODULE__{event_detection_enable: false}, %Context{}), do: :ok

  def validate_execution(%__MODULE__{} = object, %Context{}) do
    cond do
      object.event_type != :none and not is_map_key(@event_algorithms, object.event_type) ->
        {:error, {:unsupported_event_algorithm, object.event_type}}

      object[:fault_type] not in [nil, :none] and
          not is_map_key(@fault_algorithms, object[:fault_type]) ->
        {:error, {:unsupported_fault_algorithm, object[:fault_type]}}

      not DeviceObjectPropertyRef.valid?(object.object_property_reference) ->
        {:error, {:invalid_configuration, :object_property_reference}}

      object[:event_algorithm_inhibit_ref] != nil and
          not ObjectPropertyRef.valid?(object.event_algorithm_inhibit_ref) ->
        {:error, {:invalid_configuration, :event_algorithm_inhibit_ref}}

      not EventParameters.valid?(object.event_parameters) ->
        {:error, {:invalid_configuration, :event_parameters}}

      object[:fault_parameters] != nil and not FaultParameters.valid?(object.fault_parameters) ->
        {:error, {:invalid_configuration, :fault_parameters}}

      true ->
        :ok
    end
  end

  @doc """
  Checks write access before committing an Event Enrollment candidate.

  An initialized inhibit reference controls Event_Algorithm_Inhibit.
  Remote snapshots return an operation-not-available error.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec prepare_write(t(), t(), Context.t()) :: {:ok, t()} | {:error, term()}
  def prepare_write(original, candidate, context)

  def prepare_write(%__MODULE__{_metadata: %{remote_object: remote}}, _candidate, %Context{})
      when not is_nil(remote),
      do: {:error, :operation_not_available_for_remote_objects}

  def prepare_write(
        %__MODULE__{} = original,
        %__MODULE__{} = candidate,
        %Context{
          trigger: {source, _property, _index, _priority}
        } = context
      )
      when source in [:property_write, :application_write] do
    property = Context.written_property(context)

    if property_writable?(original, property),
      do: {:ok, candidate},
      else: {:error, {:write_access_denied, property}}
  end

  @spec property_writable?(t(), Constants.property_identifier()) :: boolean()
  def property_writable?(object, property)

  def property_writable?(%__MODULE__{} = object, :event_algorithm_inhibit) do
    object.event_detection_enable and
      not initialized_reference?(object[:event_algorithm_inhibit_ref]) and
      super(object, :event_algorithm_inhibit)
  end

  def property_writable?(%__MODULE__{} = object, property), do: super(object, property)

  @doc """
  Evaluates a monitored sample or returns the last evaluated read snapshot.

  Evaluation acquires the required properties through the host, evaluates
  the configured algorithms, and returns any transition and next deadline.
  Read steps preserve the pending deadline and clear the previous
  transition from the returned result.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec execute(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  def execute(object, context)

  def execute(%__MODULE__{_metadata: %{remote_object: remote}} = object, %Context{} = context)
      when not is_nil(remote),
      do: super(object, context)

  def execute(
        %__MODULE__{} = object,
        %Context{trigger: {:property_read, _property, _index}} = context
      ) do
    case context.state do
      %{next_execution: deadline, transition: _previous} = state ->
        {:ok,
         %Result{object: object, state: %{state | transition: nil}, next_execution: deadline}}

      _state ->
        super(object, context)
    end
  end

  def execute(%__MODULE__{} = object, %Context{} = context) do
    with :ok <- validate_execution(object, context) do
      state = execution_state(object, context)

      if object.event_detection_enable do
        evaluate(object, state, context)
      else
        reset_detection(object, state)
      end
    end
  end

  @doc """
  Returns the transition produced by this execution, if any. A subsequent read or
  evaluation clears the transition from its own result.
  """
  @doc group: "Functions Operational"
  @spec transition(Result.t(t())) :: transition() | nil
  def transition(result)

  def transition(%Result{
        object: %__MODULE__{_metadata: %{remote_object: nil}},
        state: %{transition: transition}
      }),
      do: transition

  def transition(%Result{object: %__MODULE__{}}), do: nil

  @doc """
  Acknowledges the most recent event of the given transition type after matching
  its timestamp. The host handles service authentication, validation of the
  acknowledged event state, and distribution of the acknowledgment notification.
  """
  @doc group: "Functions Operational"
  @spec acknowledge(t(), Constants.event_transition_bit(), BACnetTimestamp.t()) ::
          {:ok, t()} | {:error, term()}
  def acknowledge(object, transition, timestamp)

  def acknowledge(%__MODULE__{_metadata: %{remote_object: remote}}, _transition, _timestamp)
      when not is_nil(remote),
      do: {:error, :operation_not_available_for_remote_objects}

  def acknowledge(%__MODULE__{} = object, transition, %BACnetTimestamp{} = timestamp)
      when transition in [:to_offnormal, :to_fault, :to_normal] do
    EventReporting.acknowledge(object, transition, timestamp)
  end

  @spec execution_state(t(), Context.t()) :: execution_state()
  defp execution_state(object, context) do
    configuration =
      Map.take(object, [
        :object_property_reference,
        :event_parameters,
        :fault_parameters,
        :event_algorithm_inhibit_ref,
        :time_delay_normal
      ])

    case context.state do
      %{configuration: ^configuration, clock: {_base_time, _base_monotonic}} = state
      when context.trigger != :initialization ->
        %{state | transition: nil}

      _state ->
        %{
          configuration: configuration,
          clock: {DateTime.shift_zone!(context.now, "Etc/UTC"), context.monotonic_time},
          event: nil,
          fault: nil,
          next_execution: nil,
          transition: nil
        }
    end
  end

  @spec reset_detection(t(), execution_state()) :: {:ok, Result.t(t())}
  defp reset_detection(object, state) do
    object = EventReporting.reset(object)

    object =
      if object[:reliability_evaluation_inhibit] == true,
        do: %{object | reliability: :no_fault_detected},
        else: object

    finish(object, %{state | event: nil, fault: nil, next_execution: nil})
  end

  @spec evaluate(t(), execution_state(), Context.t()) :: {:ok, Result.t(t())}
  defp evaluate(object, state, context) do
    with {:ok, inhibit} <- inhibit_value(object, context),
         {:ok, sample} <- acquire(object, context) do
      object =
        if has_property?(object, :event_algorithm_inhibit),
          do: %{object | event_algorithm_inhibit: inhibit},
          else: object

      evaluate_sample(object, state, context, sample, inhibit)
    else
      {:error, reliability} -> acquisition_failed(object, state, context, reliability)
    end
  end

  @spec evaluate_sample(t(), execution_state(), Context.t(), sample(), boolean()) ::
          {:ok, Result.t(t())}
  defp evaluate_sample(object, state, context, sample, inhibit) do
    case evaluate_reliability(object, state.fault, sample, context) do
      {:ok, reliability, fault, changed} ->
        reconcile_event(
          object,
          %{state | fault: fault},
          context,
          sample,
          reliability,
          changed,
          inhibit
        )

      {:error, reliability} ->
        acquisition_failed(object, state, context, reliability, sample)
    end
  end

  @spec reconcile_event(
          t(),
          execution_state(),
          Context.t(),
          sample(),
          Constants.reliability(),
          boolean(),
          boolean()
        ) ::
          {:ok, Result.t(t())}
  defp reconcile_event(object, state, context, sample, reliability, fault_event, inhibit) do
    cond do
      reliability != :no_fault_detected or object.event_state == :fault ->
        reconcile_fault(object, state, context, sample, reliability, fault_event)

      object.event_type == :none ->
        finish(%{object | event_state: :normal, reliability: reliability}, %{
          state
          | event: nil,
            next_execution: nil
        })

      inhibit ->
        inhibit_event(%{object | reliability: reliability}, state, context, sample)

      true ->
        evaluate_event(%{object | reliability: reliability}, state, context, sample)
    end
  end

  @spec inhibit_event(t(), execution_state(), Context.t(), sample()) :: {:ok, Result.t(t())}
  defp inhibit_event(object, state, context, sample) do
    cleared = %{state | event: nil, next_execution: nil}

    if object.event_state == :normal do
      finish(object, cleared)
    else
      case prepare_event_algorithm(object, state.event, sample.value, context) do
        {:ok, algorithm} ->
          report_transition(
            object,
            cleared,
            context,
            :normal,
            object.event_type,
            EventReporting.normal_notification(algorithm)
          )

        {:error, reliability} ->
          acquisition_failed(object, state, context, reliability, sample)
      end
    end
  end

  @spec acquisition_failed(t(), execution_state(), Context.t(), Constants.reliability(), sample()) ::
          {:ok, Result.t(t())}
  defp acquisition_failed(
         object,
         state,
         context,
         reliability,
         sample \\ %{value: nil, reliability: nil}
       ) do
    state = %{state | fault: nil}

    cond do
      object[:reliability_evaluation_inhibit] != true ->
        reconcile_fault(object, state, context, sample, reliability, false)

      object.event_state == :fault ->
        reconcile_fault(object, state, context, sample, :no_fault_detected, false)

      true ->
        finish(%{object | reliability: :no_fault_detected}, %{
          state
          | event: nil,
            next_execution: nil
        })
    end
  end

  @spec reconcile_fault(
          t(),
          execution_state(),
          Context.t(),
          sample(),
          Constants.reliability(),
          boolean()
        ) ::
          {:ok, Result.t(t())}
  defp reconcile_fault(object, state, context, sample, reliability, fault_event) do
    from_state = object.event_state
    to_state = if reliability == :no_fault_detected, do: :normal, else: :fault
    changed = from_state != to_state or object.reliability != reliability or fault_event
    object = %{object | reliability: reliability}

    next_execution =
      if from_state == :fault and to_state == :normal and sample.value != nil and
           object.event_type != :none and object[:event_algorithm_inhibit] != true,
         do: :immediate

    state = %{state | event: nil, next_execution: next_execution}

    if changed do
      flags = status_flags(object, to_state)
      values = fault_notification_values(object, sample, context)

      notify = %NotificationParameters.ChangeOfReliability{
        reliability: reliability,
        status_flags: flags,
        property_values: values
      }

      report_transition(object, state, context, to_state, :change_of_reliability, notify)
    else
      finish(object, state)
    end
  end

  @spec evaluate_event(t(), execution_state(), Context.t(), sample()) :: {:ok, Result.t(t())}
  defp evaluate_event(object, state, context, sample) do
    {base_time, base_monotonic} = state.clock
    now = DateTime.add(base_time, context.monotonic_time - base_monotonic, :millisecond)

    result =
      with {:ok, algorithm} <- prepare_event_algorithm(object, state.event, sample.value, context) do
        run_event_algorithm(object.event_type, algorithm, now)
      end

    case result do
      {:event, algorithm, notify} ->
        object = persist_event_parameters(object, algorithm)
        state = %{state | event: algorithm, next_execution: nil}

        report_transition(
          object,
          state,
          context,
          algorithm.current_state,
          object.event_type,
          notify
        )

      {result, algorithm} when result in [:delayed_event, :no_event] ->
        wakeup = event_wakeup(result, algorithm, context.monotonic_time, now)
        finish(object, %{state | event: algorithm, next_execution: wakeup})

      {:error, reliability} ->
        acquisition_failed(object, state, context, reliability, sample)
    end
  end

  @spec persist_event_parameters(t(), struct()) :: t()
  defp persist_event_parameters(object, algorithm)

  defp persist_event_parameters(object, %EventAlgorithms.BufferReady{parameters: parameters}),
    do: %{object | event_parameters: parameters}

  defp persist_event_parameters(object, _algorithm), do: object

  @spec event_wakeup(:delayed_event | :no_event, struct(), integer(), DateTime.t()) ::
          Wakeup.t() | nil
  defp event_wakeup(result, algorithm, monotonic_time, now)

  defp event_wakeup(:no_event, _algorithm, _monotonic_time, _now), do: nil

  defp event_wakeup(:delayed_event, algorithm, monotonic_time, now) do
    delays =
      algorithm
      |> Map.take([:dt_normal, :dt_offnormal, :dt_life_alarm])
      |> Map.values()
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&DateTime.diff(&1, now, :microsecond))
      |> Enum.filter(&(&1 > 0))

    case Enum.min(delays, fn -> nil end) do
      nil ->
        nil

      delay ->
        %Wakeup{monotonic_time: monotonic_time + max(0, div(delay + 999, 1000)), wall_time: nil}
    end
  end

  @spec report_transition(
          t(),
          execution_state(),
          Context.t(),
          Constants.event_state(),
          Constants.event_type(),
          NotificationParameters.notification_parameter() | nil
        ) ::
          {:ok, Result.t(t())}
  defp report_transition(object, state, context, to_state, event_type, notify) do
    {updated, transition} = EventReporting.record(object, to_state, event_type, notify, context)
    state = put_in(state.configuration.event_parameters, updated.event_parameters)
    finish(updated, %{state | transition: transition})
  end

  @spec finish(t(), execution_state()) :: {:ok, Result.t(t())}
  defp finish(object, state) do
    object = %{object | status_flags: status_flags(object, object.event_state)}
    {:ok, %Result{object: object, state: state, next_execution: state.next_execution}}
  end

  @spec status_flags(t(), Constants.event_state()) :: StatusFlags.t()
  defp status_flags(object, event_state) do
    %StatusFlags{
      in_alarm: event_state != :normal,
      fault: object.reliability != :no_fault_detected,
      overridden: false,
      out_of_service: false
    }
  end

  @spec initialized_reference?(DeviceObjectPropertyRef.t() | ObjectPropertyRef.t() | nil) ::
          boolean()
  defp initialized_reference?(reference)

  defp initialized_reference?(%{object_identifier: %ObjectIdentifier{instance: instance}}),
    do: instance != @uninitialized

  defp initialized_reference?(nil), do: false

  @spec inhibit_value(t(), Context.t()) :: {:ok, boolean()} | acquisition_error()
  defp inhibit_value(object, context) do
    ref = object[:event_algorithm_inhibit_ref]

    if initialized_reference?(ref) do
      device_ref =
        struct!(DeviceObjectPropertyRef, Map.put(Map.from_struct(ref), :device_identifier, nil))

      case optional_property(context, device_ref, :optional_object) do
        {:ok, value} when value in [true, :active] -> {:ok, true}
        {:ok, value} when value in [nil, false, :inactive] -> {:ok, false}
        {:ok, _other} -> {:error, :configuration_error}
        {:error, _reason} = error -> error
      end
    else
      {:ok, object[:event_algorithm_inhibit] == true}
    end
  end

  @spec acquire(t(), Context.t()) :: {:ok, sample()} | acquisition_error()
  defp acquire(object, context) do
    reference = object.object_property_reference

    cond do
      initialized_reference?(reference) ->
        with {:ok, value} <- read_input(context, reference),
             {:ok, reliability} <- monitored_reliability(object, context, reference),
             :ok <- validate_reliability(reliability) do
          {:ok, %{value: value, reliability: reliability}}
        end

      object.event_type == :none and object[:fault_type] in [nil, :none] ->
        {:ok, %{value: nil, reliability: nil}}

      true ->
        {:error, :configuration_error}
    end
  end

  @spec monitored_reliability(t(), Context.t(), DeviceObjectPropertyRef.t()) ::
          {:ok, term()} | acquisition_error()
  defp monitored_reliability(object, context, reference) do
    if object[:reliability_evaluation_inhibit] == true,
      do: {:ok, nil},
      else: optional_property(context, sibling(reference, :reliability))
  end

  @spec validate_reliability(Constants.reliability() | nil) :: :ok | acquisition_error()
  defp validate_reliability(reliability) do
    if reliability == nil or Constants.has_by_name(:reliability, reliability),
      do: :ok,
      else: {:error, :configuration_error}
  end

  @spec sibling(DeviceObjectPropertyRef.t(), Constants.property_identifier()) ::
          DeviceObjectPropertyRef.t()
  defp sibling(reference, property) do
    %{reference | property_identifier: property, property_array_index: nil}
  end

  @spec read_input(Context.t(), DeviceObjectPropertyRef.t()) ::
          {:ok, term()} | acquisition_error()
  defp read_input(context, reference) do
    if DeviceObjectPropertyRef.valid?(reference) and initialized_reference?(reference) do
      case Context.read_property(context, reference) do
        {:ok, value} -> {:ok, value}
        {:error, error} -> {:error, read_failure(reference, normalize_read_error(error))}
      end
    else
      {:error, :configuration_error}
    end
  end

  @spec optional_property(
          Context.t(),
          DeviceObjectPropertyRef.t(),
          :optional_object | :existing_object
        ) ::
          {:ok, term()} | acquisition_error()
  defp optional_property(context, reference, scope \\ :existing_object) do
    case Context.read_property(context, reference) do
      {:ok, value} ->
        {:ok, value}

      {:error, reason} ->
        case normalize_read_error(reason) do
          {:property, :unknown_property} -> {:ok, nil}
          {:object, :unknown_object} when scope == :optional_object -> {:ok, nil}
          error -> {:error, read_failure(reference, error)}
        end
    end
  end

  @spec normalize_read_error(term()) :: term()
  defp normalize_read_error(error)

  defp normalize_read_error(%module{class: class, code: code})
       when module in [APDU.Error, BACnetError],
       do: {class, code}

  defp normalize_read_error({name, _reference})
       when name in [:unknown_object, :unknown_property, :unknown_property_identifier],
       do: normalize_read_error(name)

  defp normalize_read_error(name) when name in [:unknown_property, :unknown_property_identifier],
    do: {:property, :unknown_property}

  defp normalize_read_error(:unknown_object), do: {:object, :unknown_object}
  defp normalize_read_error(error), do: error

  @spec read_failure(DeviceObjectPropertyRef.t(), term()) :: Constants.reliability()
  defp read_failure(reference, error)

  defp read_failure(_reference, {:unsupported_operation, :read_property}),
    do: :configuration_error

  defp read_failure(_reference, {class, _code}) when class in [:object, :property],
    do: :configuration_error

  defp read_failure(%DeviceObjectPropertyRef{device_identifier: nil}, _error),
    do: :configuration_error

  defp read_failure(_reference, _error), do: :communication_failure

  @spec evaluate_reliability(t(), struct() | nil, sample(), Context.t()) ::
          {:ok, Constants.reliability(), struct() | nil, boolean()}
          | acquisition_error()
  defp evaluate_reliability(object, previous, sample, context)

  defp evaluate_reliability(
         %__MODULE__{reliability_evaluation_inhibit: true},
         _previous,
         _sample,
         _context
       ),
       do: {:ok, :no_fault_detected, nil, false}

  defp evaluate_reliability(_object, _previous, %{reliability: reliability}, _context)
       when reliability not in [nil, :no_fault_detected],
       do: {:ok, :monitored_object_fault, nil, false}

  defp evaluate_reliability(object, previous, sample, context) do
    case Map.fetch(@fault_algorithms, object[:fault_type]) do
      {:ok, module} ->
        with {:ok, {args, updates}} <-
               fault_inputs(object.fault_parameters, sample.value, context) do
          run_fault_algorithm(module, previous, args, updates)
        end

      :error ->
        {:ok, :no_fault_detected, nil, false}
    end
  end

  @spec fault_inputs(FaultParameters.fault_parameter(), term(), Context.t()) ::
          {:ok, {constructor_arguments :: [term()], updates :: Keyword.t()}} | acquisition_error()
  defp fault_inputs(parameters, value, context)

  defp fault_inputs(%FaultParameters.FaultLifeSafety{mode: reference} = params, value, context) do
    with {:ok, mode} <- read_input(context, reference) do
      {:ok, {[value, mode, params], [monitored_value: value, mode: mode]}}
    end
  end

  defp fault_inputs(
         %FaultParameters.FaultStatusFlags{status_flags: reference} = params,
         _value,
         context
       ) do
    with {:ok, flags} <- read_input(context, reference) do
      {:ok, {[flags, params], [monitored_value: flags]}}
    end
  end

  defp fault_inputs(%FaultParameters.FaultState{fault_values: values} = params, value, _context) do
    with {:ok, state} <- property_state(value, values) do
      {:ok, {[state, params], [monitored_value: state]}}
    end
  end

  defp fault_inputs(%FaultParameters.FaultCharacterString{} = params, value, _context) do
    {:ok, {[value, params], [monitored_value: value]}}
  end

  @spec run_fault_algorithm(
          module(),
          struct() | nil,
          [term()],
          Keyword.t()
        ) ::
          {:ok, Constants.reliability(), struct(), boolean()}
          | acquisition_error()
  defp run_fault_algorithm(module, previous, args, updates) do
    {reliability, updated, transition} =
      EventReporting.run_fault_algorithm(module, args, updates, previous)

    {:ok, reliability, updated, transition != nil}
  rescue
    _error in [ArgumentError, FunctionClauseError] -> {:error, :configuration_error}
  end

  @spec prepare_event_algorithm(t(), struct() | nil, term(), Context.t()) ::
          {:ok, struct()} | acquisition_error()
  defp prepare_event_algorithm(object, previous, value, context) do
    module = Map.fetch!(@event_algorithms, object.event_type)
    params = object.event_parameters

    params =
      if object[:time_delay_normal] != nil and Map.has_key?(params, :time_delay_normal),
        do: %{params | time_delay_normal: object.time_delay_normal},
        else: params

    with {:ok, {args, updates}} <-
           event_inputs(
             object.event_type,
             params,
             object.object_property_reference,
             value,
             context
           ) do
      build_event_algorithm(module, previous, args, updates, object.event_state)
    end
  end

  @spec event_inputs(
          Constants.event_type(),
          EventParameters.event_parameter(),
          DeviceObjectPropertyRef.t(),
          term(),
          Context.t()
        ) ::
          {:ok, {constructor_arguments :: [term()], updates :: Keyword.t()}}
          | acquisition_error()
  defp event_inputs(type, parameters, reference, value, context)

  defp event_inputs(:buffer_ready, params, reference, value, _context) do
    {:ok, {[value, sibling(reference, :log_buffer), params], [monitored_value: value]}}
  end

  defp event_inputs(:change_of_status_flags, params, reference, value, context) do
    present_value = sibling(reference, :present_value)

    with {:ok, present} <- optional_property(context, present_value),
         {:ok, encoding} <- optional_encoding(present_value, present) do
      {:ok, {[value, encoding, params], [monitored_value: value, present_value: encoding]}}
    end
  end

  defp event_inputs(:command_failure, params, reference, value, context) do
    with {:ok, flags} <- monitored_flags(context, reference),
         {:ok, feedback} <- read_input(context, params.feedback_value),
         {:ok, command} <- property_encoding(reference, value),
         {:ok, feedback_value} <- property_encoding(params.feedback_value, feedback) do
      resolved = %{params | feedback_value: feedback_value}
      {:ok, {[command, resolved], [monitored_value: command, status_flags: flags]}}
    end
  end

  defp event_inputs(:floating_limit, params, reference, value, context) do
    with {:ok, flags} <- monitored_flags(context, reference),
         {:ok, setpoint} <- read_input(context, params.setpoint) do
      {:ok, {[value, params], [monitored_value: value, status_flags: flags, setpoint: setpoint]}}
    end
  end

  defp event_inputs(:change_of_life_safety, params, reference, value, context) do
    with {:ok, flags} <- monitored_flags(context, reference),
         {:ok, mode} <- read_input(context, params.mode),
         {:ok, operation} <- read_input(context, sibling(reference, :operation_expected)) do
      {:ok,
       {[value, mode, operation, params],
        [monitored_value: value, status_flags: flags, mode: mode, operation_expected: operation]}}
    end
  end

  defp event_inputs(:change_of_state, params, reference, value, context) do
    with {:ok, flags} <- monitored_flags(context, reference),
         {:ok, state} <- property_state(value, params.alarm_values) do
      {:ok, {[state, params], [monitored_value: state, status_flags: flags]}}
    end
  end

  defp event_inputs(type, params, reference, value, context) do
    with {:ok, flags} <- monitored_flags(context, reference) do
      args =
        if type in @range_events,
          do: [value, %LimitEnable{low_limit_enable: true, high_limit_enable: true}, params],
          else: [value, params]

      {:ok, {args, [monitored_value: value, status_flags: flags]}}
    end
  end

  @spec monitored_flags(Context.t(), DeviceObjectPropertyRef.t()) ::
          {:ok, StatusFlags.t()} | acquisition_error()
  defp monitored_flags(context, reference) do
    case read_input(context, sibling(reference, :status_flags)) do
      {:ok, %StatusFlags{} = flags} -> {:ok, flags}
      {:ok, _value} -> {:error, :configuration_error}
      {:error, _reason} = error -> error
    end
  end

  @spec build_event_algorithm(
          module(),
          struct() | nil,
          [term()],
          Keyword.t(),
          Constants.event_state()
        ) ::
          {:ok, struct()} | acquisition_error()
  defp build_event_algorithm(module, previous, args, updates, event_state) do
    algorithm =
      case previous do
        nil -> %{apply(module, :new, args) | current_state: event_state}
        retained -> %{retained | parameters: List.last(args)}
      end

    {:ok, module.update(algorithm, updates)}
  rescue
    _error in [ArgumentError, FunctionClauseError, KeyError] -> {:error, :configuration_error}
  end

  @spec run_event_algorithm(Constants.event_type(), struct(), DateTime.t()) ::
          {:event, struct(), NotificationParameters.notification_parameter()}
          | {:delayed_event | :no_event, struct()}
          | acquisition_error()
  defp run_event_algorithm(_type, %module{} = algorithm, now) do
    module.execute(algorithm, now)
  rescue
    _error in [ArgumentError, FunctionClauseError] -> {:error, :configuration_error}
  end

  @spec property_state(term(), [PropertyState.t()]) ::
          {:ok, PropertyState.t()} | acquisition_error()
  defp property_state(value, configured)

  defp property_state(%PropertyState{} = state, _configured), do: check_property_state(state)

  defp property_state(value, [%PropertyState{type: type} | _rest]),
    do: check_property_state(%PropertyState{type: type, value: value})

  defp property_state(value, []) when is_boolean(value),
    do: {:ok, %PropertyState{type: :boolean_value, value: value}}

  defp property_state(value, []) when is_integer(value) and value >= 0,
    do: {:ok, %PropertyState{type: :unsigned_value, value: value}}

  defp property_state(value, []) when is_integer(value),
    do: {:ok, %PropertyState{type: :integer_value, value: value}}

  defp property_state(_value, _configured), do: {:error, :configuration_error}

  @spec check_property_state(PropertyState.t()) :: {:ok, PropertyState.t()} | acquisition_error()
  defp check_property_state(state) do
    if PropertyState.valid?(state), do: {:ok, state}, else: {:error, :configuration_error}
  end

  @spec optional_encoding(DeviceObjectPropertyRef.t(), term()) ::
          {:ok, Encoding.t() | nil} | acquisition_error()
  defp optional_encoding(reference, value)

  defp optional_encoding(_reference, nil), do: {:ok, nil}
  defp optional_encoding(reference, value), do: property_encoding(reference, value)

  @spec property_encoding(DeviceObjectPropertyRef.t(), term()) ::
          {:ok, Encoding.t()} | acquisition_error()
  defp property_encoding(reference, value)

  defp property_encoding(_reference, %Encoding{} = encoding), do: {:ok, encoding}

  defp property_encoding(reference, value) do
    case encode_property(reference, value) do
      {:ok, %Encoding{} = encoding} -> {:ok, encoding}
      _other -> {:error, :configuration_error}
    end
  end

  @spec encode_property(DeviceObjectPropertyRef.t(), term()) ::
          {:ok, Encoding.t() | [Encoding.t()]} | {:error, term()}
  defp encode_property(reference, value)

  defp encode_property(_reference, %Encoding{} = encoding), do: {:ok, encoding}

  defp encode_property(reference, value) do
    property =
      case reference.property_identifier do
        name when is_atom(name) -> name
        value -> Constants.by_value(:property_identifier, value, nil)
      end

    if property do
      ObjectsUtility.cast_value_to_property(reference.object_identifier, property, value,
        allow_partial: reference.property_array_index != nil
      )
    else
      {:error, :unknown_property}
    end
  end

  @spec fault_notification_values(t(), sample(), Context.t()) :: [PropertyValue.t()]
  defp fault_notification_values(object, sample, context) do
    reference = object.object_property_reference
    {:ok, tags} = DeviceObjectPropertyRef.encode(reference)

    source = %PropertyValue{
      property_identifier: :object_property_reference,
      property_array_index: nil,
      property_value: Enum.map(tags, &Encoding.create!/1),
      priority: nil
    }

    values =
      if initialized_reference?(reference) and sample.value != nil do
        flags =
          case optional_property(context, sibling(reference, :status_flags)) do
            {:ok, %StatusFlags{} = flags} -> flags
            _other -> nil
          end

        [
          {reference, sample.value},
          {sibling(reference, :reliability), sample.reliability},
          {sibling(reference, :status_flags), flags}
        ]
        |> Enum.uniq_by(&elem(&1, 0))
        |> Enum.flat_map(fn {ref, value} -> fault_property_value(ref, value) end)
      else
        []
      end

    [source | values]
  end

  @spec fault_property_value(DeviceObjectPropertyRef.t(), term()) :: [PropertyValue.t()]
  defp fault_property_value(reference, value)

  defp fault_property_value(_reference, nil), do: []

  defp fault_property_value(reference, value) do
    case encode_property(reference, value) do
      {:ok, encoding} ->
        [
          %PropertyValue{
            property_identifier: reference.property_identifier,
            property_array_index: reference.property_array_index,
            property_value: encoding,
            priority: nil
          }
        ]

      {:error, _reason} ->
        []
    end
  end

  @spec inhibit_object_check(
          t(),
          t() | nil,
          ObjectOperations.property_operation(),
          ObjectOperations.property_operation_args()
        ) :: {:ok, t()} | {:error, term()}
  defp inhibit_object_check(%__MODULE__{} = obj, _original, _operation, _args) do
    with {:ok, obj} <- update_event_type(obj) do
      update_fault_type(obj)
    end
  end

  @spec update_event_type(t()) :: {:ok, t()} | {:error, term()}
  defp update_event_type(%{event_parameters: %type{}} = obj) do
    unless_env(:prod, do: Code.ensure_loaded(type))

    if function_exported?(type, :get_tag_number, 0) do
      with {:ok, val} <- Constants.by_value(:event_type, type.get_tag_number()) do
        {:ok, %{obj | event_type: val}}
      end
    else
      {:error, {:invalid_or_unknown_type, :event_parameters}}
    end
  end

  @spec update_fault_type(t()) :: {:ok, t()} | {:error, term()}
  defp update_fault_type(object)

  defp update_fault_type(%{fault_parameters: %type{}} = obj) do
    unless_env(:prod, do: Code.ensure_loaded(type))

    if function_exported?(type, :get_tag_number, 0) do
      with {:ok, val} <- Constants.by_value(:fault_type, type.get_tag_number()) do
        {:ok, %{obj | fault_type: val}}
      end
    else
      {:error, {:invalid_or_unknown_type, :fault_parameters}}
    end
  end

  defp update_fault_type(obj), do: {:ok, obj}
end
