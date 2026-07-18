defmodule BACnet.Protocol.ObjectTypes.TimePatternValue do
  @moduledoc """
  The Time Pattern Value object holds a recurring time-of-day pattern that may contain
  "don't care" wildcards in any of the hour/minute/second/hundredths fields. It is the
  time-only sibling of `BACnet.Protocol.ObjectTypes.DateTimePatternValue` Value and
  is the pattern form of the simple `BACnet.Protocol.ObjectTypes.TimeValue` object.

  Typical uses are "every day at 06:00", "at :30 and :00 of every hour", or "any time
  between 08:00 and 17:00" (expressed with appropriate don't-care combinations). The
  object can be commandable via priority array, so the pattern itself can be overridden.

  ### Object Description (ASHRAE 135)

  > The Time Pattern Value object type defines a standardized object whose properties
  > represent the externally visible characteristics of a named data value in a BACnet device.
  >
  > Time Pattern objects can be used to represent multiple recurring times based on rules defined
  > by the pattern of individual fields of the time.

  ### Behaviour and Operation

  Time Pattern Value objects hold a recurring time-of-day pattern (with "don't care"
  wildcards).

  The pattern is a normal data value, unless commandable via priority array. The
  object performs no clock evaluation itself; consumers compare the current time
  against the pattern. `out_of_service` allows a test pattern to be forced.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: The recurring time pattern.
    **Dev must**: Set by config/writers. Custom application logic evaluate the pattern
    vs current time (wildcards).

  - `priority_array`, `relinquish_default` (if commandable):
    **Dev must**: Use priority APIs to command the pattern.

  - `status_flags`, `out_of_service`:
    **Dev must**: The `in_alarm`/`fault`/`out_of_service` bits of `status_flags` are
    automatically updated by the object; `overridden` is a local matter.

  ### Commandability and Priority Arrays

  Value objects can have a priority array (making them commandable).

  ### Examples

  Creating a Time Pattern Value:

      iex> {:ok, tpv} = BACnet.Protocol.ObjectTypes.TimePatternValue.create(110, "Daily", %{present_value: %BACnet.Protocol.BACnetTime{hour: :unspecified, minute: :unspecified, second: :unspecified, hundredth: :unspecified}}); tpv.object_name
      "Daily"

  ### See Also
  - `BACnet.Protocol.ObjectTypes.TimeValue`
  """

  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Time Pattern Value object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a Time Pattern Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected.
  """
  bac_object Constants.macro_assert_name(:object_type, :time_pattern_value) do
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
