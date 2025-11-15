defmodule BACnet.Protocol.ObjectTypes.CharacterStringValue do
  @moduledoc """
  The CharacterString Value object type defines a standardized object whose properties
  represent the externally visible characteristics of a named data value in a BACnet device.
  A BACnet device can use a CharacterString Value object to make any kind of character
  string data value accessible to other BACnet devices. The mechanisms by which the
  value is derived are not visible to the BACnet client.

  If a set of strings is known and fixed, then a Multi-state Value object is an alternative
  that may provide some benefit to automated processes consuming the numeric Present_Value.
  CharacterString Value objects that support intrinsic reporting shall apply the
  CHANGE_OF_CHARACTERSTRING event algorithm.

  For reliability-evaluation, the FAULT_CHARACTERSTRING fault algorithm can be applied.

  (ASHRAE 135 - Clause 12.37)
  """

  # TODO: Docs

  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Available object options.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents a Character String Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected,
  unless out of service is active. For the duration of out of service, updates to the present value
  using `update_property/3` are allowed. Once out of service is disabled, the present value is once
  again protected from updates, as the present value is updated through the relinquish_default and
  priority_array properties.
  """
  bac_object Constants.macro_assert_name(:object_type, :character_string_value) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean())

    field(:present_value, String.t(), required: true)
    field(:priority_array, PriorityArray.t(String.t()), readonly: true)
    field(:relinquish_default, String.t())

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit,
      # If fault_values is present, reliability must be present too (but not the other way around)
      annotation: [required_when: {:property, :fault_values}]
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:fault_values, BACnetArray.t(String.t() | nil), default: BACnetArray.new())

    field(:profile_name, String.t())

    # Intrinsic Reporting
    field(:alarm_values, BACnetArray.t(String.t() | nil),
      default: BACnetArray.new(),
      intrinsic: true
    )

    field(:event_state, Constants.event_state(), intrinsic: true)
  end
end
