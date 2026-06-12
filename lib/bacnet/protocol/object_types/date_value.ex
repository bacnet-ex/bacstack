defmodule BACnet.Protocol.ObjectTypes.DateValue do
  @moduledoc """
  The Date Value object stores a single concrete calendar date (year, month, day,
  weekday) as a network-visible named value. It is the non-pattern counterpart to
  `BACnet.Protocol.ObjectTypes.DatePatternValue` and is used for absolute dates
  such as "project start", "warranty expiration", "last filter change",
  or any other date that needs to be read or written by BACnet clients.

  The date can be made commandable through a priority array. It has no intrinsic
  semantics by itself; consuming objects (event enrollment, etc.) decide
  how to interpret the date. The value is treated as a local matter by the device.

  ### Object Description (ASHRAE 135)

  > The Date Value object type defines a standardized object whose properties represent
  > the externally visible characteristics of a named data value in a BACnet device.
  >
  > A Date Value object is used to represent a single day.

  ### Behaviour and Operation

  Date Value objects hold a single concrete calendar date. Typical uses are
  effective dates, expiration dates, last service dates, etc. The date is a normal
  data value that can be written directly unless the object carries a priority array
  (commandable case).

  Consumers (custom logic, the device itself) read the date and decide
  what to do with it. The object performs no automatic actions on its own.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: The current date value (may have wildcards).
    **Dev must**: Your app logic or time source updates it (via `update_property/3`).
    If commandable (PA present), only through priority (via `set_priority/3`).

  - `priority_array`, `relinquish_default`: Commanding a date.
    **Dev must**: Use priority APIs for sources to "set" the date value at
    different priorities.

  - `status_flags`, `out_of_service`, `reliability`:
    **Dev must**: `out_of_service` allows direct writes for test if not commandable.
    Reliability if the date source is bad.
    `in_alarm`/`fault`/`out_of_service` bits auto-managed by object.

  ### Commandability and Priority Arrays

  Value objects can have a `priority_array` (making them commandable).

  ### Examples

  Creating a Date Value:

      iex> {:ok, dv} = BACnet.Protocol.ObjectTypes.DateValue.create(70, "Today", %{present_value: %BACnet.Protocol.BACnetDate{year: :unspecified, month: :unspecified, day: :unspecified, weekday: :unspecified}}); dv.object_name
      "Today"

  ### See Also
  - `BACnet.Protocol.BACnetDate`
  - `BACnet.Protocol.ObjectTypes.DatePatternValue`
  """

  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Date Value object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a Date Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected.
  """
  bac_object Constants.macro_assert_name(:object_type, :date_value) do
    services(intrinsic: false)

    field(:description, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean())

    field(:present_value, BACnetDate.t(),
      required: true,
      annotation: {:readonly_when, {:out_of_service, false}}
    )

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
