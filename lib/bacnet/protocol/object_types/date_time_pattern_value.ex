defmodule BACnet.Protocol.ObjectTypes.DateTimePatternValue do
  @moduledoc """
  The Date Time Pattern Value object stores a combined date+time pattern that supports
  the full set of BACnet wildcards on both the date and time portions. It is the most
  powerful of the pattern value objects and is used when you need to express rules such
  as "every weekday at 07:30 during even months" or "last Friday of the quarter at
  17:00".

  he object itself can be made commandable (priority array), so the pattern can be overridden.
  Like other Value objects its `present_value` is the pattern data; evaluation happens
  in the objects or devices that consume it.

  ### Object Description (ASHRAE 135)

  > The DateTime Pattern Value object type defines a standardized object whose properties
  > represent the externally visible characteristics of a named data value in a BACnet device.
  >
  > DateTime Pattern objects can be used to represent multiple recurring dates and times based
  > on rules defined by the pattern of individual fields of the date and time.

  ### Behaviour and Operation

  Date Time Pattern Value objects store the most expressive recurring date+time
  pattern supported by BACnet. Like other pattern values they are primarily
  referenced by custom application code that needs to know
  "does this complex recurring moment match now?".

  The pattern value can be commanded via priority array if present; otherwise it is
  a normal writable data value. `out_of_service` permits forcing a test pattern while
  the using logic should ignore the object, if not commandable.
  The object itself performs no evaluation; it is a pure configuration / data container.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: The recurring date+time pattern.
    **Dev must**: Set by writers (direct or priority). Consumers evaluate the pattern
    against current time using wildcard rules. Object holds definition only.

  - `priority_array`, `relinquish_default`: Commandability.
    **Dev must**: Priority APIs for commanding the pattern value.

  - `status_flags`, `out_of_service`, `reliability`:
    **Dev must**: The `in_alarm`/`fault`/`out_of_service` bits of `status_flags` are
    automatically updated by the object; `overridden` is a local matter.

  ### Commandability and Priority Arrays

  Value objects can have a `priority_array` (making them commandable).

  ### Examples

  Creating a DateTime Pattern Value:

      iex> {:ok, dtpv} = BACnet.Protocol.ObjectTypes.DateTimePatternValue.create(120, "RecurDT", %{present_value: %BACnet.Protocol.BACnetDateTime{date: %BACnet.Protocol.BACnetDate{year: :unspecified, month: :unspecified, day: :unspecified, weekday: :unspecified}, time: %BACnet.Protocol.BACnetTime{hour: :unspecified, minute: :unspecified, second: :unspecified, hundredth: :unspecified}}}); dtpv.object_name
      "RecurDT"

  ### See Also
  - `BACnet.Protocol.BACnetDateTime`
  - `BACnet.Protocol.ObjectTypes.DateTimeValue`
  """

  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a DateTime Pattern Value object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a DateTime Pattern Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected.
  """
  bac_object Constants.macro_assert_name(:object_type, :datetime_pattern_value) do
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
