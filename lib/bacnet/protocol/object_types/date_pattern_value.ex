defmodule BACnet.Protocol.ObjectTypes.DatePatternValue do
  @moduledoc """
  The Date Pattern Value object holds a single recurring date pattern expressed with
  the rich BACnet date wildcards. It is the pattern version of the simple
  `BACnet.Protocol.ObjectTypes.DateValue` object.

  The object can be made commandable via a priority array so that the effective
  pattern itself can be overridden by operators or other logic. It is a pure data
  holder; its `present_value` is the pattern definition and has no direct effect until
  referenced by another object or used by logic.

  ### Object Description (ASHRAE 135)

  > The Date Pattern Value object type defines a standardized object whose properties
  > represent the externally visible characteristics of a named data value in a BACnet device.
  >
  > Date Pattern objects can be used to represent multiple recurring dates based on rules
  > defined by the pattern of individual fields of the date, some of which can be
  > special values like "even months", or "don't care".

  ### Behaviour and Operation

  Date Pattern Value objects hold a single recurring date pattern (using the full
  BACnet wildcard rules). They are passive data holders. A BACnet device can use a
  Date Pattern Value object to make any kind of date data value accessible to other
  BACnet devices.

  The pattern itself (`present_value`) can be written directly unless the object has
  been made commandable with a priority array. In the commandable case, the effective
  pattern is taken from the priority array / relinquish default and direct writes to
  `present_value` are not permitted.

  Evaluation of the pattern against the current date is performed by consumers of
  the object (i.e. the device clock and schedule engine), not by the value object itself.
  The object simply stores and exposes the pattern definition.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: The recurring date pattern.
    **Dev must**: Writers (app or clients) set the pattern (directly or via priority
    if commandable). Consumers (your custom logic) read it and evaluate it using
    the standard wildcard rules. The object does not evaluate; it just holds the definition.

  - `priority_array`, `relinquish_default`: Optional commandability.
    **Dev must**: Same rules as other commandable values: use `set_priority/3` etc.
    for sources

  - `status_flags`, `out_of_service`, `reliability`:
    **Dev must**: `out_of_service` allows forcing a pattern for test, if not commandable.
    Reliability for bad source of the pattern value.
    `in_alarm`/`fault`/`out_of_service` bits of `status_flags` auto-managed.

  ### Commandability and Priority Arrays

  Value objects can have a `priority_array` (making them commandable).

  ### Examples

  Creating a Date Pattern Value:

      iex> {:ok, dpv} = BACnet.Protocol.ObjectTypes.DatePatternValue.create(100, "Recurring", %{present_value: %BACnet.Protocol.BACnetDate{year: :unspecified, month: :unspecified, day: :unspecified, weekday: :unspecified}}); dpv.object_name
      "Recurring"

  ### See Also
  - `BACnet.Protocol.BACnetDate`
  - `BACnet.Protocol.ObjectTypes.DateValue`
  """

  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Date Pattern Value object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a Date Pattern Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected.
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
