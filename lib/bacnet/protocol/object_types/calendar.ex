defmodule BACnet.Protocol.ObjectTypes.Calendar do
  @moduledoc """
  The Calendar object maintains a list of calendar dates and/or date patterns
  that represent holidays, special events, or other date-based exceptions.
  Other objects (primarily Schedule objects) reference a Calendar by its
  Object Identifier to determine whether the current day is "in calendar" or not.

  The  `present_value` is a Boolean that is true precisely when today's date
  matches at least one entry in the `date_list`. The list can contain both concrete
  dates and recurring patterns, giving a very flexible way to define "every third
  Wednesday in November", date ranges, etc.

  ### Object Description (ASHRAE 135)

  > The Calendar object type defines a standardized object used to describe
  > a list of calendar dates, which might be thought of as "holidays", "special events",
  > or simply as a list of dates.

  ### Behaviour and Operation

  Calendar objects are passive date-list containers. The `date_list` property
  (containing concrete dates, DateRanges, WeekNDay patterns, etc.) is normally
  configured at creation time or by a configuration tool / operator and then left
  alone. The local timekeeping subsystem evaluates the list against the current date
  to decide whether the calendar is "active".

  The `present_value` is `true` when the current local date matches any entry.
  The device must keep the system clock (and thus the evaluation) accurate.
  The calendar is not a control point but a reference used by Schedules and other objects.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: "Is today a special day per this calendar?"
    (yes/no for use by Schedules etc.).
    **Dev must**: This is *computed live*. Your time task (or the Schedules that
    reference calendars) must, on every date change (midnight or DST etc.) or slow
    poll, re-evaluate every `BACnet.Protocol.CalendarEntry` in `date_list` against
    the current wall date (handling wildcards, ranges, WeekNDay).
    Update `present_value` via `update_property/3` when it changes.

  - `date_list`: The definition of special days.
    **Dev must**: Populate at creation/config (by workstation, client, or your setup).
    Clients can rewrite it at runtime (you may restrict in Write handler or require
    special mode). When it changes, immediately re-eval `present_value` for "today".

  A Calendar is a *shared date predicate*. Any number of Schedules (and
  potentially your own custom logic) can ask "is today one of the special days
  defined by this calendar?" by simply reading its `present_value`.

  **Wildcards and patterns**: The power of a calendar comes from the rich
  wildcard rules (month 13 = odd, 14 = even, day-of-month 32 = last day,
  weekday 7 = "any", year = unspecified, etc.). Your evaluation code must
  implement the full BACnet date matching rules when comparing a
  `BACnet.Protocol.CalendarEntry` against the current date.

  **Remote calendars**: A Schedule can reference a Calendar on another device
  (via the object identifier in an exception). In that case the Schedule's
  evaluation engine must read the remote calendar's `present_value`.

  **Writing the date_list**: Because it is a normal property (an array of
  CalendarEntry), a client can completely rewrite the holidays at runtime.

  Calendars are the classic example of a "pure reference object" whose only
  job is to answer a yes/no question that many other objects need.

  ### Examples

  Creating a Calendar:

      iex> {:ok, cal} = BACnet.Protocol.ObjectTypes.Calendar.create(500, "Holidays", %{}); cal.object_name
      "Holidays"

  ### See Also
  - Related: `BACnet.Protocol.ObjectTypes.Schedule`
  """

  alias BACnet.Protocol.CalendarEntry
  alias BACnet.Protocol.Constants

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Calendar object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a Calendar object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.
  """
  bac_object Constants.macro_assert_name(:object_type, :calendar) do
    services(intrinsic: false)

    field(:description, String.t())
    field(:date_list, [CalendarEntry.t()], required: true, default: [])
    field(:present_value, boolean(), required: true, default: false)
    field(:profile_name, String.t())
  end
end
