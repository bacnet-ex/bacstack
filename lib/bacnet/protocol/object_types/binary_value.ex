defmodule BACnet.Protocol.ObjectTypes.BinaryValue do
  @moduledoc """
  The Binary Value object holds a two-state (Boolean) parameter that lives entirely in
  the device's memory rather than being bound to physical I/O. It is the binary
  counterpart to Analog Value and Multistate Value and is commonly used for operating
  mode flags, enable/disable commands, alarm latches, or any calculated Boolean result
  that needs to be visible and writable over the network.

  The value is optionally fully commandable via a priority array (with relinquish default)
  so that schedules, operators, and control logic can arbitrate control.
  COV reporting for state changes is supported. When `intrinsic_reporting: true` is passed
  to `create/4`, the CHANGE_OF_STATE intrinsic algorithm (and optional FAULT_STATE) are
  activated.

  ### Object Description (ASHRAE 135)

  > The Binary Value object type defines a standardized object whose properties represent
  > the externally visible characteristics of a binary value.
  > A "binary value" is a control system parameter residing in the memory of the BACnet Device.
  >
  > Binary Value objects that support intrinsic reporting shall apply the CHANGE_OF_STATE event algorithm.

  ### Behaviour and Operation

  Binary Value objects are in-memory two-state parameters (mode flags, enable bits,
  calculated booleans, etc.). When no priority array is present, `present_value` may
  be written directly by the local application or over BACnet.

  If the object was created with (or later given) a `priority_array` and
  `relinquish_default`, it becomes commandable: `present_value` is then computed from
  the priority array and direct writes are blocked. Use `set_priority/3` to change it.

  `out_of_service` allows forcing a test value while the logical consumer of the flag
  should treat the object as disconnected. The object supports CHANGE_OF_STATE
  intrinsic alarming (when enabled at creation) and COV on state changes.
  Local writes should be blocked and only BACnet writes should be allowed.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: The current value. If priority_array present, it is
    derived/protected.
    **Dev must**: For non-commandable: your app logic writes the value. For
    commandable: use `set_priority/3` or PA writes; library derives PV. Your "user" of
    the value reads it to act on it.

  - `priority_array`, `relinquish_default`: Optional properties.
    **Dev must**: Manage via APIs; when present PV is protected.

  - `status_flags`: The `in_alarm`/`fault`/`out_of_service` bits of `status_flags`
    are auto-managed; `overridden` is local matter.

  - `active_text` / `inactive_text`: Human strings.
    **Dev must**: Set at init; changes are just data.

  - `change_of_state_count` etc. (with implicits), `elapsed_active_time` etc.: History.
    **Dev must**: On PV (state) changes, maintain the counters and times (bump,
    set times, accumulate). Similar to BinaryInput.

  - Intrinsic (`alarm_values` + event set for CHANGE_OF_STATE, optional fault):
    **Dev must**: On PV change, re-eval the algorithms using the properties on the object;
    drive `event_state` and notifications.

  Value objects are the "in memory" variables; your application logic is the driver
  that reads/writes them (or lets priority sources command them).

  ### Intrinsic Reporting

  When `intrinsic_reporting: true` is passed to `create/4`, the CHANGE_OF_STATE event
  algorithm and related properties are activated.

  ### Commandability and Priority Arrays

  Value objects can have a `priority_array` (making them commandable). When a priority array
  is present, the present value is protected and is only changed through the priority mechanism.

  ### Examples

  Creating a Binary Value with state texts:

      iex> {:ok, bv} = BACnet.Protocol.ObjectTypes.BinaryValue.create(20, "Mode", %{active_text: "Auto", inactive_text: "Manual"}); bv.active_text
      "Auto"

  With intrinsic reporting enabled:

      iex> {:ok, bv} = BACnet.Protocol.ObjectTypes.BinaryValue.create(21, "Flag", %{}, intrinsic_reporting: true); bv.object_name
      "Flag"

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.ChangeOfState`
  - `BACnet.Protocol.FaultAlgorithms.FaultState` (optional)
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.PriorityArray

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Binary Value object.

  In addition to the common options, Binary Value supports:
  - `intrinsic_reporting` - Enables CHANGE_OF_STATE intrinsic reporting.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents a Binary Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  The physical output decouples the present value and the polarity from the physical state.
  The present value reflects the logical state of the object.

  For commandable objects (objects with a priority array), the present value property is protected.
  """
  bac_object Constants.macro_assert_name(:object_type, :binary_value) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:device_type, String.t())
    field(:event_state, Constants.event_state(), required: true)
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean(), required: true)

    field(:present_value, boolean(),
      required: true,
      default: false,
      annotation: {:encode_as, :enumerated}
    )

    field(:priority_array, PriorityArray.t(boolean()), readonly: true)
    field(:relinquish_default, boolean(), default: false, annotation: {:encode_as, :enumerated})

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:active_text, String.t(), default: "Active", implicit_relationship: :inactive_text)
    field(:inactive_text, String.t(), default: "Inactive")

    field(:change_of_state_time, BACnetDateTime.t(),
      implicit_relationship: :change_of_state_count,
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    field(:change_of_state_count, ApplicationTags.unsigned32(), default: 0)

    field(:time_of_state_count_reset, BACnetDateTime.t(),
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    field(:elapsed_active_time, ApplicationTags.unsigned32(),
      implicit_relationship: :time_of_active_time_reset,
      default: 0
    )

    field(:time_of_active_time_reset, BACnetDateTime.t(),
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    field(:min_off_time, ApplicationTags.unsigned32())
    field(:min_on_time, ApplicationTags.unsigned32())

    # Intrinsic Reporting
    field(:alarm_value, boolean(),
      intrinsic: true,
      default: true,
      annotation: {:encode_as, :enumerated}
    )
  end
end
