defmodule BACnet.Protocol.ObjectTypes.DateTimeValue do
  @moduledoc """
  The Date Time Value object holds a single concrete date-and-time value.
  It is the non-recurring counterpart to `BACnet.Protocol.ObjectTypes.DateTimePatternValue`
  and is typically used for absolute timestamps such as "last maintenance performed",
  "contract expires", "next scheduled run", or any other point-in-time configuration
  or status datum that must be visible on the network.

  The value can be commandable via priority array, allowing operators or automated
  procedures to set or override the timestamp. It is a simple data container; the
  meaning of the timestamp is a local matter or defined by the objects that read it.

  ### Object Description (ASHRAE 135)

  > The DateTime Value object type defines a standardized object whose properties represent
  > the externally visible characteristics of a named data value in a BACnet device.
  >
  > A DateTime Value object is used to represent a single moment in time.

  ### Behaviour and Operation

  Date Time Value objects hold a single concrete timestamp. They are used for
  deadlines, last-run times, configuration points, etc. The timestamp can be read
  and (if not commandable) written directly by clients or the local application.

  When made commandable via a priority array the effective timestamp is taken from
  the priority mechanism.
  The object performs no automatic time-based action; any behaviour (e.g. "if now >
  this value then ...") is implemented in the objects or logic that read it.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: The timestamp value.
    **Dev must**: Your app/config/time logic writes it (directly if not commandable;
    via `set_priority/3` if commandable). Consumers read it for deadlines etc.
    The object does no auto-updating or time keeping.

  - `priority_array`, `relinquish_default`: For commandable timestamp override.
    **Dev must**: Use priority mechanism for multiple sources to "set" the time
    value.

  - `status_flags`, `out_of_service`, `reliability`:
    **Dev must**: `out_of_service` allows forcing a test timestamp if not commandable.
    Reliability if the source of this timestamp value is unhealthy.
    `in_alarm`/`fault`/`out_of_service` bits are auto-updated by the object
    (`overridden` local matter).

  - `is_utc`: Whether the time is UTC.
    **Dev must**: Set/maintain correctly when writing the value.

  ### Commandability and Priority Arrays

  Value objects can have a `priority_array` (making them commandable).

  ### Examples

  Creating a DateTime Value:

      iex> {:ok, dtv} = BACnet.Protocol.ObjectTypes.DateTimeValue.create(90, "Event", %{present_value: %BACnet.Protocol.BACnetDateTime{date: %BACnet.Protocol.BACnetDate{year: :unspecified, month: :unspecified, day: :unspecified, weekday: :unspecified}, time: %BACnet.Protocol.BACnetTime{hour: :unspecified, minute: :unspecified, second: :unspecified, hundredth: :unspecified}}}); dtv.object_name
      "Event"

  ### See Also
  - `BACnet.Protocol.BACnetDateTime`
  - `BACnet.Protocol.ObjectTypes.DateTimePatternValue`
  """

  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a DateTime Value object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a DateTime Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected.
  """
  bac_object Constants.macro_assert_name(:object_type, :datetime_value) do
    services(intrinsic: false)

    field(:description, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean())

    field(:present_value, BACnetDateTime.t(),
      required: true,
      annotation: {:readonly_when, {:out_of_service, false}}
    )

    field(:priority_array, PriorityArray.t(BACnetDateTime.t()), readonly: true)
    field(:relinquish_default, BACnetDateTime.t())

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:is_utc, boolean())

    field(:event_state, Constants.event_state())
  end
end
