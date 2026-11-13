defmodule BACnet.Protocol.ObjectExecution.EventReporting do
  @moduledoc """
  Records event transitions and resolves their notification routing.
  Updates object properties for an event transition and prepares its delivery information.

  `BACnet.Protocol.ObjectExecution.IntrinsicReporting` and
  `BACnet.Protocol.ObjectTypes.EventEnrollment` call `record/5` after evaluating
  event and fault conditions. The host uses `transition/1` on a committed
  execution result and delivers enabled transitions using their routing plans.
  If lookup cannot resolve the Notification Class, the transition's routing plan is `nil`. See
  `BACnet.Protocol.ObjectExecution.Lifecycle` for the delivery flow.
  """

  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetTimestamp
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectRef
  alias BACnet.Protocol.EventAlgorithms
  alias BACnet.Protocol.EventMessageTexts
  alias BACnet.Protocol.EventTimestamps
  alias BACnet.Protocol.NotificationParameters
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.ObjectTypes.EventEnrollment
  alias BACnet.Protocol.ObjectTypes.NotificationClass
  alias BACnet.Protocol.StatusFlags

  @typedoc """
  A transition recorded during the current execution, with its delivery settings.
  """
  @type transition :: %{
          transition: Constants.event_transition_bit(),
          from_state: Constants.event_state(),
          to_state: Constants.event_state(),
          event_type: Constants.event_type(),
          timestamp: BACnetTimestamp.t(),
          event_values: NotificationParameters.notification_parameter() | nil,
          message_text: String.t(),
          notification_class: non_neg_integer(),
          notify_type: Constants.notify_type(),
          enabled: boolean(),
          routing: NotificationClass.routing_plan() | nil
        }

  @doc """
  Executes a fault algorithm with fresh inputs or its retained state.

  The helper constructs state on the first call for an algorithm module. Later
  calls pass any supplied updates to the module's `update/2`. The return value
  identifies whether the transition came from fresh or retained algorithm state.
  """
  @spec run_fault_algorithm(module(), [term()], Keyword.t(), struct() | nil) ::
          {reliability :: Constants.reliability(), state :: struct(),
           transition :: :initial | :retained | nil}
  def run_fault_algorithm(module, args, updates, previous) do
    {algorithm, origin} =
      case previous do
        %{__struct__: ^module} = retained ->
          {if(updates == [], do: retained, else: module.update(retained, updates)), :retained}

        _other ->
          {apply(module, :new, args), :initial}
      end

    case module.execute(algorithm) do
      {:event, state, reliability} -> {reliability, state, origin}
      {:no_event, state} -> {state.current_reliability, state, nil}
    end
  end

  @doc """
  Updates the event state, timestamp, message and acknowledgment bit for a transition.
  """
  @spec record(
          object,
          Constants.event_state(),
          Constants.event_type(),
          NotificationParameters.notification_parameter() | nil,
          Context.t()
        ) ::
          {updated :: object, transition()}
        when object: struct()
  def record(object, to_state, event_type, values, %Context{} = context) do
    key = transition_key(to_state)
    routing = routing_plan(object.notification_class, key, context)
    ack_required = routing != nil and routing.ack_required

    timestamp = %BACnetTimestamp{
      type: :datetime,
      datetime: BACnetDateTime.from_datetime(context.now),
      time: nil,
      sequence_number: nil
    }

    message = Map.get(object.event_message_texts_config || %{}, key, "")

    transition = %{
      transition: key,
      from_state: object.event_state,
      to_state: to_state,
      event_type: event_type,
      timestamp: timestamp,
      event_values: values,
      message_text: message,
      notification_class: object.notification_class,
      notify_type: object.notify_type,
      enabled: Map.fetch!(object.event_enable, key),
      routing: routing
    }

    messages = if object.event_message_texts, do: %{object.event_message_texts | key => message}

    updated = %{
      object
      | event_state: to_state,
        status_flags: %{object.status_flags | in_alarm: to_state != :normal},
        event_timestamps: %{object.event_timestamps | key => timestamp},
        event_message_texts: messages,
        acked_transitions: %{object.acked_transitions | key => not ack_required}
    }

    {updated, transition}
  end

  @doc """
  Restores the initial reporting properties when event detection is disabled.
  """
  @spec reset(object) :: object when object: struct()
  def reset(object) do
    stamp = ObjectsMacro.get_default_bacnet_timestamp()
    stamps = %EventTimestamps{to_offnormal: stamp, to_fault: stamp, to_normal: stamp}

    %{
      object
      | event_state: :normal,
        status_flags: %{object.status_flags | in_alarm: false},
        event_timestamps: stamps,
        acked_transitions: ObjectsMacro.get_default_event_transbits(true),
        event_message_texts:
          if(object.event_message_texts,
            do: %EventMessageTexts{to_offnormal: "", to_fault: "", to_normal: ""}
          )
    }
  end

  @doc """
  Acknowledges the most recent transition of the given kind after matching its timestamp.
  """
  @spec acknowledge(object, Constants.event_transition_bit(), BACnetTimestamp.t()) ::
          {:ok, object} | {:error, {:services, :invalid_timestamp}}
        when object: struct()
  def acknowledge(object, transition, %BACnetTimestamp{} = timestamp)
      when transition in [:to_offnormal, :to_fault, :to_normal] do
    if is_map(object.event_timestamps) and
         timestamp != ObjectsMacro.get_default_bacnet_timestamp() and
         Map.get(object.event_timestamps, transition) == timestamp do
      {:ok, %{object | acked_transitions: %{object.acked_transitions | transition => true}}}
    else
      {:error, {:services, :invalid_timestamp}}
    end
  end

  @doc """
  Returns the transition produced by this execution, if any.

  The host can use this after committing the result. An event recorded with
  `enabled: false` still updates the object but does not request delivery.
  """
  @spec transition(Result.t()) :: transition() | nil
  def transition(result)

  def transition(%Result{
        object: %{_metadata: %{remote_object: nil, intrinsic_reporting: true}},
        state: %{reporting: %{transition: transition}}
      }),
      do: transition

  def transition(%Result{
        object: %{__struct__: EventEnrollment, _metadata: %{remote_object: nil}},
        state: %{transition: transition}
      }),
      do: transition

  def transition(%Result{}), do: nil

  @range_notifications %{
    EventAlgorithms.OutOfRange => NotificationParameters.OutOfRange,
    EventAlgorithms.DoubleOutOfRange => NotificationParameters.DoubleOutOfRange,
    EventAlgorithms.SignedOutOfRange => NotificationParameters.SignedOutOfRange,
    EventAlgorithms.UnsignedOutOfRange => NotificationParameters.UnsignedOutOfRange
  }

  # Inhibition forces a return to normal even if the monitored condition remains
  # offnormal. Build that transition from the current algorithm inputs.
  @doc """
  Builds the return-to-normal parameters when inhibition stops an active algorithm.
  """
  @spec normal_notification(struct()) ::
          NotificationParameters.notification_parameter() | nil
  def normal_notification(algorithm)

  def normal_notification(%EventAlgorithms.ChangeOfBitstring{} = algorithm) do
    %NotificationParameters.ChangeOfBitstring{
      referenced_bitstring: algorithm.monitored_value,
      status_flags: normal_flags(algorithm)
    }
  end

  def normal_notification(%EventAlgorithms.ChangeOfCharacterString{} = algorithm) do
    %NotificationParameters.ChangeOfCharacterString{
      changed_value: algorithm.monitored_value,
      alarm_value: algorithm.last_alarm_value || "",
      status_flags: normal_flags(algorithm)
    }
  end

  def normal_notification(%EventAlgorithms.ChangeOfState{} = algorithm) do
    %NotificationParameters.ChangeOfState{
      new_state: algorithm.monitored_value,
      status_flags: normal_flags(algorithm)
    }
  end

  def normal_notification(%EventAlgorithms.ChangeOfStatusFlags{} = algorithm) do
    %NotificationParameters.ChangeOfStatusFlags{
      present_value: algorithm.present_value,
      referenced_flags: algorithm.monitored_value
    }
  end

  def normal_notification(%EventAlgorithms.ChangeOfLifeSafety{} = algorithm) do
    %NotificationParameters.ChangeOfLifeSafety{
      new_state: algorithm.monitored_value,
      new_mode: algorithm.mode,
      operation_expected: algorithm.operation_expected,
      status_flags: normal_flags(algorithm)
    }
  end

  def normal_notification(%EventAlgorithms.CommandFailure{} = algorithm) do
    %NotificationParameters.CommandFailure{
      command_value: algorithm.monitored_value,
      feedback_value: algorithm.parameters.feedback_value,
      status_flags: normal_flags(algorithm)
    }
  end

  def normal_notification(%EventAlgorithms.FloatingLimit{} = algorithm) do
    params = algorithm.parameters

    limit =
      if algorithm.current_state == :low_limit,
        do: params.low_diff_limit,
        else: params.high_diff_limit

    %NotificationParameters.FloatingLimit{
      reference_value: algorithm.monitored_value,
      setpoint_value: algorithm.setpoint,
      error_limit: limit,
      status_flags: normal_flags(algorithm)
    }
  end

  def normal_notification(%EventAlgorithms.UnsignedRange{} = algorithm) do
    %NotificationParameters.UnsignedRange{
      exceeding_value: algorithm.monitored_value,
      exceeded_limit: exceeded_limit(algorithm),
      status_flags: normal_flags(algorithm)
    }
  end

  def normal_notification(%module{} = algorithm) when is_map_key(@range_notifications, module) do
    struct!(Map.fetch!(@range_notifications, module),
      exceeding_value: algorithm.monitored_value,
      exceeded_limit: exceeded_limit(algorithm),
      deadband: algorithm.parameters.deadband,
      status_flags: normal_flags(algorithm)
    )
  end

  def normal_notification(_algorithm), do: nil

  @spec normal_flags(struct()) :: StatusFlags.t()
  defp normal_flags(algorithm), do: %{algorithm.status_flags | in_alarm: false}

  @spec exceeded_limit(struct()) :: number()
  defp exceeded_limit(algorithm) do
    if algorithm.current_state == :low_limit,
      do: algorithm.parameters.low_limit,
      else: algorithm.parameters.high_limit
  end

  @spec transition_key(Constants.event_state()) :: Constants.event_transition_bit()
  defp transition_key(state)
  defp transition_key(:normal), do: :to_normal
  defp transition_key(:fault), do: :to_fault
  defp transition_key(_offnormal), do: :to_offnormal

  @spec routing_plan(non_neg_integer(), Constants.event_transition_bit(), Context.t()) ::
          NotificationClass.routing_plan() | nil
  defp routing_plan(class, key, context) do
    reference = %DeviceObjectRef{
      device_identifier: nil,
      object_identifier: %ObjectIdentifier{type: :notification_class, instance: class}
    }

    case Context.lookup_object(context, reference) do
      {:ok, %NotificationClass{} = object} ->
        NotificationClass.routing_plan(object, key, context.now)

      _other ->
        nil
    end
  end
end
