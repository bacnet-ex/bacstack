defmodule BACnet.Protocol.ObjectTypes.BinaryValue do
  @moduledoc """
  The Binary Value object type defines a standardized object whose properties represent
  the externally visible characteristics of a binary value.
  A "binary value" is a control system parameter residing in the memory of the BACnet Device.
  This parameter may assume only one of two distinct states.
  In this description, those states are referred to as ACTIVE and INACTIVE.

  Binary Value objects that support intrinsic reporting shall apply the CHANGE_OF_STATE event algorithm.

  (ASHRAE 135 - Clause 12.8)
  """

  # TODO: Docs

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.PriorityArray
  alias BACnet.Protocol.ObjectsMacro

  require Constants
  use ObjectsMacro

  @typedoc """
  Available object options.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents a Binary Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  The physical output decouples the present value and the polarity from the physical state.
  The present value reflects the logical state of the object.
  To get the physical state, call `get_output/1` and the function gets the present value in respect to the polarity.

  For commandable objects (objects with a priority array), the present value property is protected,
  unless out of service is active. For the duration of out of service, updates to the present value
  using `update_property/3` are allowed. Once out of service is disabled, the present value is once
  again protected from updates, as the present value is updated through the relinquish_default and
  priority_array properties.
  """
  bac_object Constants.macro_assert_name(:object_type, :binary_value) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:device_type, String.t())
    field(:event_state, Constants.event_state(), required: true)
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean(), required: true)

    field(:present_value, boolean(),
      required: true,
      default: false,
      annotation: {:encode_as, :enumerated}
    )

    field(:priority_array, PriorityArray.t(boolean()), readonly: true)
    field(:relinquish_default, boolean(), default: false, annotation: {:encode_as, :enumerated})
    field(:polarity, Constants.polarity(), required: true, default: :normal)

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())
    field(:profile_name, String.t())

    field(:active_text, String.t(), default: "Active", implicit_relationship: :inactive_text)
    field(:inactive_text, String.t(), default: "Inactive")

    field(:change_of_state_time, BACnet.Protocol.BACnetDateTime.t(),
      implicit_relationship: :change_of_state_count,
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    field(:change_of_state_count, ApplicationTags.unsigned32(), default: 0)

    field(:time_of_state_count_reset, BACnet.Protocol.BACnetDateTime.t(),
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    field(:elapsed_active_time, ApplicationTags.unsigned32(),
      implicit_relationship: :time_of_active_time_reset,
      default: 0
    )

    field(:time_of_active_time_reset, BACnet.Protocol.BACnetDateTime.t(),
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    field(:min_off_time, ApplicationTags.unsigned32())
    field(:min_on_time, ApplicationTags.unsigned32())

    # Intrinsic Reporting
    field(:alarm_value, boolean(),
      intrinsic: true,
      default: true,
      annotation: {:encode_as, :enumerated}
    )
  end

  @doc """
  Get the logical state of the object from the present value property in respect to the polarity.
  """
  @spec get_output(t()) :: boolean()
  def get_output(%__MODULE__{} = object) do
    case object.polarity do
      Constants.macro_assert_name(:polarity, :normal) -> object.present_value
      Constants.macro_assert_name(:polarity, :reverse) -> !object.present_value
    end
  end
end
