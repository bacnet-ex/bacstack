defmodule BACnet.Protocol.ObjectTypes.EventEnrollment do
  @moduledoc """
  The Event Enrollment object type defines a standardized object that represents
  and contains the information required for algorithmic reporting of events.
  For the general event concepts and algorithmic event reporting, see Clause 13.2.

  For the Event Enrollment object, detecting events is accomplished by performing
  particular event and fault algorithms on monitored values of a referenced object.
  The parameters for the algorithms are provided by the Event Enrollment object.
  The standard event algorithms are defined in Clause 13.3.
  The standard fault algorithms are defined in Clause 13.4.
  Event Enrollment objects do not modify or otherwise influence the state or
  operation of the referenced object. For the reliability indication by the
  Reliability property of the Event Enrollment object, internal unreliable operation
  such as configuration error or communication failure takes precedence over
  reliability indication for the monitored object (i.e., MONITORED_OBJECT_FAULT).
  Fault indications determined by the fault algorithm, if any, have least precedence.
  Clause 13.2 describes the interaction between Event Enrollment objects,
  the Notification Class objects, and the Alarm and Event application services.

  (ASHRAE 135 - Clause 12.12)
  """

  # TODO: Docs

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
  Available object options.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents an Event Enrollment object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.
  """
  bac_object Constants.macro_assert_name(:object_type, :event_enrollment) do
    services(intrinsic: false)

    field(:description, String.t())

    field(:event_type, Constants.event_type(), required: true, default: :none)
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
    field(:fault_parameters, FaultParameters.fault_parameter())

    field(:profile_name, String.t())
  end
end
