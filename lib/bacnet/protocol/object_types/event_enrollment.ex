defmodule BACnet.Protocol.ObjectTypes.EventEnrollment do
  @moduledoc """
  The Event Enrollment object is the primary mechanism for defining intrinsic or
  algorithmic event/alarm generation in BACnet. It references a single property
  (local or on a remote device via `object_property_reference`), applies a chosen
  event algorithm (CHANGE_OF_STATE, OUT_OF_RANGE, BUFFER_READY, etc.) together with
  optional fault algorithms, and, when the state changes, sends notifications to the
  recipients listed in the associated Notification Class.

  The enrollment object itself never modifies the monitored property; it is a pure
  observer. It carries the full set of event configuration (`event_enable`,
  `acked_transitions`, `event_priorities`, `event_message_texts`, etc.) and
  can be enabled/disabled independently. This design allows any object
  (even those that do not support intrinsic reporting themselves) to participate
  in alarming by creating a separate Event Enrollment that watches it.

  ### Object Description (ASHRAE 135)

  > The Event Enrollment object type defines a standardized object that represents
  > and contains the information required for algorithmic reporting of events.
  > For the general event concepts and algorithmic event reporting, see Clause 13.2.

  ### Behaviour and Operation

  Event Enrollment objects are the "watcher + algorithm engine". The device (local
  application or a background task) must periodically (or on change) evaluate the
  referenced property using the chosen event and fault algorithms (the parameters
  for which live in this object). When a transition occurs the enrollment generates
  `BACnet.Protocol.Services.ConfirmedEventNotification` or
  `BACnet.Protocol.Services.UnconfirmedEventNotification` messages to the
  recipients defined by the linked Notification Class.

  The enrollment never modifies the monitored property. It only observes it (the
  reference may point to a remote object via the network). `event_detection_enable`,
  `event_algorithm_inhibit`, time delays, limit parameters, etc. all live here and
  control exactly when and how notifications are produced. The object is not
  commandable.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, via `update_property/3` (never direct mutation).
  Read notes below + generated tables for details.

  **Special / live properties and expected developer behaviour**

  - `object_property_reference`: What to monitor (any object/prop, local or remote).
    **Dev must**: Your detection task periodically or on change reads the current
    value (and status_flags for some algos) of the referenced prop (do remote
    reads if needed) and feeds it + other params into the event algorithm (the
    params live on this enrollment).

  - `event_parameters`: The config for the configured algorithm.
    **Dev must**: Run the configured event algorithm.

  - `event_state`, `acked_transitions`, `event_timestamps`, `event_message_texts`, etc.:
    The event machine state.
    **Dev must**: After feeding a value and running the algorithm, update the
    state, timestamps, etc. on this object.

  - `status_flags`, `reliability`:
    **Dev must**: Update based on ability to read the reference or internal faults.
    `in_alarm`/`fault`/`out_of_service` bits are auto-managed (`overridden` is a local matter).

  - `event_algorithm_inhibit*`, `reliability_evaluation_inhibit`: Control.
    **Dev must**: Respect when inhibiting detection or reliability.

  - `fault_type`, `fault_parameters`: Optional fault detection on the reference.
    **Dev must**: Run the fault algorithm too if configured.

  Your "event engine" (timer or change driven) owns the evaluation loop; the
  enrollment is the attachment point + parameters + state holder. See the "You
  run the detection engine" section below.

  `EventEnrollment` is the most flexible way to attach alarming to *any* property,
  even on a completely different device, without modifying the source object.

  **You run the detection engine**: Nothing in the enrollment object automatically
  wakes up and evaluates the algorithm. On a schedule appropriate for the
  algorithm (on every change for a CHANGE_OF_STATE, every time a new record
  is appended for BUFFER_READY, …) you must:
  1. Read the current value of the property described by
     `object_property_reference` (local object or full remote ref - you do the
     network read if necessary).
  2. Feed that value (plus any other required inputs such as `status_flags` for
     some algorithms) into the event algorithm whose parameters live on this
     event enrollment.
  3. Also run the optional fault algorithm if one is configured
     (`fault_parameters`).
  4. From the results decide whether `event_state` or `reliability` should
     change.
  5. If a transition that requires a notification occurred (and the
     corresponding bit in `event_enable` is set, the `event_algorithm_inhibit`
     is not active, etc.), look up the Notification Class referenced by this
     enrollment and emit the notification (using the priority and ack-required
     information from the class, the message texts from the enrollment, etc.).
  6. Update the enrollment's own `event_state`, `event_timestamps`,
     `acked_transitions`, `reliability` etc. via the normal update path.

  The enrollment object is purely the *configuration and current state* of one
  particular alarm/fault detector.

  **The monitored property can be anywhere**: Because the reference is a full
  `BACnet.Protocol.DeviceObjectPropertyRef` you can watch a sensor that lives
  on a different controller.
  Your detection task becomes a little distributed alarm engine.

  *FAULT_* algorithms run in parallel with the event algorithm. A fault
  transition (e.g. FAULT_STATUS_FLAGS) can move the object into a fault
  reliability even if the event state stays normal. Both can generate
  notifications.

  **event_algorithm_inhibit / event_algorithm_inhibit_ref**: These let a different
  object (or a schedule, or a manual switch) temporarily suppress the alarming
  logic without clearing all the configuration. Your engine must check the
  inhibit flag (and follow the reference if present) on every evaluation.

  **Writing the enrollment from the wire**: Almost everything on an
  `EventEnrollment` is writable (the reference, the algorithm parameters, the
  enable bits, the notification class, the message texts, the delays …). A
  configuration tool can completely repurpose an enrollment at runtime. Your
  detection engine simply uses whatever parameters are currently stored on the
  object.

  ### Examples

  Creating an Event Enrollment:

      iex> {:ok, ee} = BACnet.Protocol.ObjectTypes.EventEnrollment.create(1100, "HighTempAlarm", %{notification_class: 1}); ee.object_name
      "HighTempAlarm"

  ### See Also
  - `BACnet.Protocol.EventAlgorithms`
  - `BACnet.Protocol.FaultAlgorithms`
  - Related: `BACnet.Protocol.ObjectTypes.NotificationClass`
  """

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.EventMessageTexts
  alias BACnet.Protocol.EventParameters
  alias BACnet.Protocol.EventTimestamps
  alias BACnet.Protocol.EventTransitionBits
  alias BACnet.Protocol.FaultParameters
  alias BACnet.Protocol.ObjectPropertyRef
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.StatusFlags

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring an Event Enrollment object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents an Event Enrollment object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.
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

    field(:event_state, Constants.event_state(), required: true, default: :normal)

    field(:event_enable, EventTransitionBits.t(),
      required: true,
      default: ObjectsMacro.get_default_event_transbits(true)
    )

    field(:acked_transitions, EventTransitionBits.t(), readonly: true)
    field(:notification_class, non_neg_integer(), required: true)

    field(:event_timestamps, EventTimestamps.t(), readonly: true)
    field(:event_message_texts, EventMessageTexts.t(), readonly: true)
    field(:event_message_texts_config, EventMessageTexts.t())
    field(:event_detection_enable, boolean(), required: true, default: true)

    field(:event_algorithm_inhibit, boolean(),
      implicit_relationship: :event_algorithm_inhibit_ref
    )

    field(:event_algorithm_inhibit_ref, ObjectPropertyRef.t())
    field(:time_delay_normal, non_neg_integer())
    field(:status_flags, StatusFlags.t(), required: true)

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:fault_type, Constants.fault_type(), readonly: true)

    field(:fault_parameters, FaultParameters.fault_parameter(),
      implicit_relationship: :fault_type
    )
  end

  @spec inhibit_object_check(t()) :: {:ok, t()} | {:error, term()}
  defp inhibit_object_check(%__MODULE__{} = obj) do
    with {:ok, obj} <- update_event_type(obj) do
      update_fault_type(obj)
    end
  end

  defp update_event_type(%{event_parameters: %type{}} = obj) do
    if function_exported?(type, :get_tag_number, 0) do
      with {:ok, val} <- Constants.by_value(:event_type, type.get_tag_number()) do
        {:ok, %{obj | event_type: val}}
      end
    else
      {:error, {:invalid_or_unknown_type, :event_parameters}}
    end
  end

  defp update_fault_type(%{fault_parameters: %type{}} = obj) do
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
