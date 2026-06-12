defmodule BACnet.Protocol.ObjectTypes.Schedule do
  @moduledoc """
  The Schedule object is the heart of time-based automation in BACnet. It contains a
  weekly schedule (seven day schedules, each a list of time/value pairs) plus a list
  of exception schedules (holidays, special events) that can reference
  `BACnet.Protocol.ObjectTypes.Calendar` objects or contain inline date patterns.
  At the scheduled times the object automatically writes the configured values
  into the target properties listed in `list_of_object_property_references`.

  The `present_value` of the schedule reflects the currently effective value (or
  `schedule_default` outside any defined period).
  Schedules are the standard way to implement occupancy-based setpoints,
  lighting scenes, etc.

  ### Object Description (ASHRAE 135)

  > The Schedule object type defines a standardized object used to describe a periodic schedule
  > that may recur during a range of dates, with optional exceptions at arbitrary times on
  > arbitrary dates. The Schedule object also serves as a binding between these scheduled times
  > and the writing of specified "values" to specific properties of specific objects at those times.
  >
  > Schedule objects that support intrinsic reporting shall apply the NONE event algorithm.

  ### Behaviour and Operation

  Schedule objects are active time-based actuators. The device must run a scheduler
  engine (typically a periodic task driven by the real-time clock) that:
  1. Evaluates the `weekly_schedule` and any `exception_schedule` entries
     (which may reference calendars).
  2. Determines the currently effective value (or falls back to `schedule_default`).
  3. Writes that value to every property listed in `list_of_object_property_references`,
     using the priority slot given by `priority_for_writing`.

  The readonly `present_value` of the Schedule itself reflects what it is currently
  writing (or would write). The local application does not write to the targets
  directly for scheduled control; the Schedule object performs the writes.

  `out_of_service` can disable scheduled writes while still allowing the schedule
  state to be inspected. When intrinsic reporting is enabled the Schedule can
  participate in (minimal) event reporting for reliability issues.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: The currently effective scheduled value for the referenced objects.
    **Dev must**: Your scheduler task must evaluate the weekly/exception schedules
    against current time (respect effective_period, special events, calendars),
    determine the value (or schedule_default), write it to `present_value`,
    *and* perform the actual writes to all entries in
    `list_of_object_property_references` at the `priority_for_writing`.

  - `weekly_schedule`, `exception_schedule`, `schedule_default`, `effective_period`,
    `list_of_object_property_references`, `priority_for_writing`, etc.:
    The schedule data and targets.
    **Dev must**: Populate at creation/config time (at minimum weekly or
    exception schedule present enforced).

  - `status_flags`, `reliability`, `out_of_service`:
    **Dev must**: `out_of_service` means "ignore schedule, do not write targets". Reliability for
    problems like missing calendar ref. The `in_alarm`/`fault`/`out_of_service` bits
    of `status_flags` are auto-managed by the object (`overridden` local).

  Schedule is one of the few objects that is expected to have *side effects on
  other objects* on a time base. The object itself is mostly passive data; the
  "active" part lives in your scheduler engine.

  **You own the scheduler engine**: You must periodically:
  1. Read the current wall time (respect DST, the device's `utc_offset`, etc.).
  2. Evaluate `effective_period`, then the `weekly_schedule[ weekday ]` plus any
     matching `exception_schedule` entries (a `SpecialEvent` can be a calendar
     reference or an inline date/time pattern + a list of `TimeValue`).
  3. Compute the effective value (or `schedule_default`).
  4. For every entry in `list_of_object_property_references`, perform a
     WriteProperty (or internal `update_property/3`/`set_priority/3` if local)
     to the target property at the priority given by `priority_for_writing`.
  5. Update the Schedule's own `present_value`,
     so that observers see what the schedule is currently "commanding".

  Because the writes are performed at a specific priority, downstream objects
  (setpoints, binary outputs, etc.) will see the schedule's command only when
  no higher-priority source has a value in their priority array.

  **Functional schedule**: At creation time either `weekly_schedule` or
  `exception_schedule` (or both) must be supplied; otherwise you get an error.
  This is a developer convenience, so you don't create a completely inert schedule.

  **out_of_service for a scheduler**: When `true`, the engine should stop the
  internal calculation and will stop performing the writes to the target properties
  (they will keep whatever value they had at the moment it was disabled,
  subject to their own priority arrays and relinquish defaults).
  You can still change the schedule data (weekly list, targets, …)
  while it is out of service.

  **Changing targets or exceptions at runtime**:
  Because `list_of_object_property_references`, `exception_schedule`,
  `weekly_schedule`, etc. are normal writable properties,
  a config tool or another schedule can rewrite them. Your engine simply sees the
  new data on the next evaluation cycle. There is no "reload" signal; the object
  is the source of truth.

  **Intrinsic NONE + reliability**: The only intrinsic algorithm a Schedule uses is
  NONE (see the See Also). It is intended for the Schedule object itself to be
  able to report reliability problems (bad calendar reference, malformed
  SpecialEvent, etc.) via the normal event machinery. Your engine should set
  the Schedule's `:reliability` when it detects problems during evaluation.

  **Remote targets**: A `DeviceObjectPropertyRef` in the list can point at another
  device. Your engine must then issue a real WriteProperty service request
  at the schedule's priority. Failures should probably be reflected
  in the Schedule's reliability.

  The object also has an `effective_period` (`DateRange`) that can be used to
  make a whole schedule active only between two dates (e.g. "this schedule is
  only valid during the 2025-2026 heating season").

  ### Intrinsic Reporting

  When `intrinsic_reporting: true` is passed to `create/4`, the Schedule participates
  in intrinsic event reporting using the NONE algorithm
  (primarily for reliability/fault conditions).

  ### Examples

  Creating a basic Schedule:

      iex> {:ok, sch} = BACnet.Protocol.ObjectTypes.Schedule.create(600, "Lighting", %{}); sch.object_name
      "Lighting"

  ### See Also
  - `BACnet.Protocol.DailySchedule`
  - `BACnet.Protocol.DateRange`
  - `BACnet.Protocol.EventAlgorithms.None`
  - `BACnet.Protocol.ObjectTypes.Calendar`
  - `BACnet.Protocol.SpecialEvent`
  - `BACnet.Protocol.TimeValue`
  """

  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DailySchedule
  alias BACnet.Protocol.DateRange
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ObjectsUtility.Internal, as: UtilityInternal
  alias BACnet.Protocol.SpecialEvent

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Schedule object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a Schedule object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.
  """
  bac_object Constants.macro_assert_name(:object_type, :schedule) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:reliability, Constants.reliability(), required: true)
    field(:reliability_evaluation_inhibit, boolean())

    field(:out_of_service, boolean(), required: true)

    field(:present_value, Encoding.t(),
      required: true,
      default: %Encoding{
        encoding: :primitive,
        extras: [],
        type: :null,
        value: nil
      }
    )

    field(:effective_period, DateRange.t(),
      required: true,
      default: %DateRange{
        start_date: %BACnetDate{
          year: :unspecified,
          month: :unspecified,
          day: :unspecified,
          weekday: :unspecified
        },
        end_date: %BACnetDate{
          year: :unspecified,
          month: :unspecified,
          day: :unspecified,
          weekday: :unspecified
        }
      }
    )

    field(:weekly_schedule, BACnetArray.t(DailySchedule.t(), 7),
      init_fun: &UtilityInternal.init_fun_schedule_weekly_schedule/0
    )

    field(:exception_schedule, BACnetArray.t(SpecialEvent.t()))

    field(:schedule_default, Encoding.t(),
      required: true,
      default: %Encoding{
        encoding: :primitive,
        extras: [],
        type: :null,
        value: nil
      }
    )

    field(:list_of_object_property_references, BACnetArray.t(DeviceObjectPropertyRef.t()),
      required: true,
      default: BACnetArray.new()
    )

    field(:priority_for_writing, 1..16, required: true, default: 16)
    field(:profile_name, String.t())
  end

  # Override add_defaults/2, to assert weeky_schedule or exception_schedule is present
  defp add_defaults(properties, metadata) do
    props = super(properties, metadata)

    if Map.has_key?(props, :weekly_schedule) or Map.has_key?(props, :exception_schedule) do
      props
    else
      {:error, {:missing_required_property, {:weekly_schedule, :or, :exception_schedule}}}
    end
  end
end
