defmodule BACnet.Protocol.ObjectTypes.BinaryInput do
  @moduledoc """
  The Binary Input object type defines a standardized object whose properties represent
  the externally visible characteristics of a binary input.
  A "binary input" is a physical device or hardware input that can be in only one of two distinct states.
  In this description, those states are referred to as ACTIVE (`true`) and INACTIVE (`false`).
  A typical use of a binary input is to indicate whether a particular piece of mechanical equipment,
  such as a fan or pump, is running or idle.

  The state ACTIVE corresponds to the situation when the equipment is on or running,
  and INACTIVE corresponds to the situation when the equipment is off or idle.

  In some applications, electronic circuits may reverse the relationship between the application-level
  logical states ACTIVE and INACTIVE and the physical state of the underlying hardware.
  For example, a normally open relay contact may result in an ACTIVE state when the relay is energized,
  while a normally closed relay contact may result in an INACTIVE state when the relay is energized.
  The Binary Input object provides for this possibility by including a Polarity property.

  Binary Input objects that support intrinsic reporting shall apply the CHANGE_OF_STATE event algorithm.

  (ASHRAE 135 - Clause 12.6)
  """

  # TODO: Docs

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectsMacro

  require Constants
  use ObjectsMacro

  @typedoc """
  Available object options.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()}
          | {:physical_input, boolean()}
          | common_object_opts()

  @typedoc """
  Represents a Binary Input object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  The physical input decouples the present value and the polarity from the physical state.
  The present value reflects the logical state of the object.
  To set the logical state, call `set_input/2` and the function writes to the present value in respect to the polarity.
  The physical input is NOT a real BACnet property.
  """
  bac_object Constants.macro_assert_name(:object_type, :binary_input) do
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

    field(:change_of_state_count, non_neg_integer(), default: 0)

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

    # Intrinsic Reporting
    field(:alarm_value, boolean(),
      intrinsic: true,
      default: true,
      required: true,
      default: false,
      annotation: {:encode_as, :enumerated}
    )
  end

  @doc """
  Sets the physical input and writes to the present value property in respect to the polarity.

  If the object is out of service, the present value won't be updated.
  """
  @spec set_input(t(), boolean()) :: {:ok, t()} | property_update_error()
  def set_input(%__MODULE__{} = object, value) when is_boolean(value) do
    new_value =
      case object.polarity do
        Constants.macro_assert_name(:polarity, :normal) -> value
        Constants.macro_assert_name(:polarity, :reverse) -> !value
      end

    new_object = %{
      object
      | _metadata: %{object._metadata | physical_input: value},
        # Only write to the present_value if out_of_service is not active
        present_value: if(object.out_of_service, do: object.present_value, else: new_value)
    }

    {:ok, new_object}
  end
end
