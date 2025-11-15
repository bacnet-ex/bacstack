defmodule BACnet.Protocol.ObjectTypes.TimeValue do
  @moduledoc """
  The Time Value object type defines a standardized object whose properties represent
  the externally visible characteristics of a named data value in a BACnet device.
  A BACnet device can use a Time Value object to make any kind of time data value
  accessible to other BACnet devices. The mechanisms by which the value is derived
  are not visible to the BACnet client.
  A Time Value object is used to represent a single moment in time. In contrast,
  the Time Pattern Value object can be used to represent multiple recurring times.

  (ASHRAE 135 - Clause 12.42)
  """

  # TODO: Docs

  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Available object options.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a Time Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected,
  unless out of service is active. For the duration of out of service, updates to the present value
  using `update_property/3` are allowed. Once out of service is disabled, the present value is once
  again protected from updates, as the present value is updated through the relinquish_default and
  priority_array properties.
  """
  bac_object Constants.macro_assert_name(:object_type, :time_value) do
    services(intrinsic: false)

    field(:description, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean())

    field(:present_value, BACnetTime.t(), required: true)
    field(:priority_array, PriorityArray.t(BACnetTime.t()), readonly: true)
    field(:relinquish_default, BACnetTime.t())

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:event_state, Constants.event_state())
    field(:profile_name, String.t())
  end
end
