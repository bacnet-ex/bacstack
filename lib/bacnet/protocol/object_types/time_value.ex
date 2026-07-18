defmodule BACnet.Protocol.ObjectTypes.TimeValue do
  @moduledoc """
  The Time Value object stores a single concrete time-of-day (hour, minute, second,
  hundredths) as a named BACnet value. It is the non-recurring counterpart to
  `BACnet.Protocol.ObjectTypes.TimePatternValue` and is used for absolute times
  such as "occupied start", "night setback time", "report generation time",
  or any other clock time that must be configurable over the network.

  The time value can be made commandable via a priority array. Like other Value
  objects, the meaning of the stored time is a local matter.
  It has no side effects by itself.

  ### Object Description (ASHRAE 135)

  > The Time Value object type defines a standardized object whose properties represent
  > the externally visible characteristics of a named data value in a BACnet device.
  >
  > A Time Value object is used to represent a single moment in time.

  ### Behaviour and Operation

  Time Value objects hold a single concrete time-of-day. They are used for
  occupancy start times, report times, etc. The time can be written directly
  unless the object is commandable (priority array present). In the commandable
  case the effective time comes from the priority mechanism.

  Consumers read the value and act on it.
  The object itself performs no time-based actions.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: The time value.
    **Dev must**: App logic or clients set it (direct or via PA if commandable).

  - `priority_array`, `relinquish_default` (if commandable):
    **Dev must**: Priority commanding for multiple sources.

  - `status_flags`, `out_of_service`, `reliability`:
    **Dev must**: `out_of_service` lifts protection.
    Reliability for source of the time value.
    `in_alarm`/`fault`/`out_of_service` bits of `status_flags` are
    auto-managed by the object.

  ### Commandability and Priority Arrays

  Value objects can have a priority array (making them commandable).

  ### Examples

  Creating a Time Value:

      iex> {:ok, tv} = BACnet.Protocol.ObjectTypes.TimeValue.create(80, "Now", %{present_value: %BACnet.Protocol.BACnetTime{hour: :unspecified, minute: :unspecified, second: :unspecified, hundredth: :unspecified}}); tv.object_name
      "Now"

  ### See Also
  - `BACnet.Protocol.ObjectTypes.TimePatternValue`
  """

  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Time Value object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a Time Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected.
  """
  bac_object Constants.macro_assert_name(:object_type, :time_value) do
    services(intrinsic: false)

    field(:description, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean())

    field(:present_value, BACnetTime.t(),
      required: true,
      annotation: {:readonly_when, {:out_of_service, false}}
    )

    field(:priority_array, PriorityArray.t(BACnetTime.t()), readonly: true)
    field(:relinquish_default, BACnetTime.t())

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:event_state, Constants.event_state())
  end
end
