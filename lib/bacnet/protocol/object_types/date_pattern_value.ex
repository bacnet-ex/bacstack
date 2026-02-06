defmodule BACnet.Protocol.ObjectTypes.DatePatternValue do
  @moduledoc """
  The Date Pattern Value object type defines a standardized object whose properties
  represent the externally visible characteristics of a named data value in a BACnet device.
  A BACnet device can use a Date Pattern Value object to make any kind of date data
  value accessible to other BACnet devices. The mechanisms by which the value is derived
  are not visible to the BACnet client.

  Date Pattern objects can be used to represent multiple recurring dates based on rules
  defined by the pattern of individual fields of the date, some of which can be
  special values like "even months", or "don't care", which matches any value in that field.

  Examples of possibilities would be: "every Thursday in May of any year", or "every day in May 2009".

  (ASHRAE 135 - Clause 12.48)
  """

  # TODO: Docs

  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Available object options.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a Date Pattern Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected,
  unless out of service is active. For the duration of out of service, updates to the present value
  using `update_property/3` are allowed. Once out of service is disabled, the present value is once
  again protected from updates, as the present value is updated through the relinquish_default and
  priority_array properties.
  """
  bac_object Constants.macro_assert_name(:object_type, :date_pattern_value) do
    services(intrinsic: false)

    field(:description, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean())

    field(:present_value, BACnetDate.t(), required: true)
    field(:priority_array, PriorityArray.t(BACnetDate.t()), readonly: true)
    field(:relinquish_default, BACnetDate.t())

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:event_state, Constants.event_state())
    field(:profile_name, String.t())
  end
end
