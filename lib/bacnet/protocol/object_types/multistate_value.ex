defmodule BACnet.Protocol.ObjectTypes.MultistateValue do
  @moduledoc """
  The Multistate Value object is the in-memory (non-physical I/O) counterpart to
  Multistate Input and Multistate Output. It holds an integer state (1..N) that
  represents an operating mode, a stage, a position in a sequence, or any other
  enumerated control parameter that lives inside the device.

  The semantics of the states are a local matter and may be described with the
  optional `state_text` array. The object is frequently commandable via priority
  array so that schedules, operators and control logic can change the mode.
  Intrinsic reporting (CHANGE_OF_STATE + optional FAULT_STATE when
  `intrinsic_reporting: true`) are supported exactly as for the input/output variants.

  ### Object Description (ASHRAE 135)

  > The Multi-state Value object type defines a standardized object whose properties
  > represent the externally visible characteristics of a multi-state value.
  > A "multi-state value" is a control system parameter residing in the memory of the
  > BACnet Device.
  >
  > Multi-state Value objects that support intrinsic reporting shall apply the CHANGE_OF_STATE event algorithm.

  ### Behaviour and Operation

  Multistate Value objects are in-memory multi-state parameters (operating modes,
  stage selections, enumerated setpoints, etc.). When not commandable, the integer
  state can be written directly by the application or by BACnet clients.

  When a priority array is present, the object is commandable: `present_value` is
  derived from the priority mechanism and direct writes are not permitted.
  Use `set_priority/3` to command the mode.

  The meaning of states is local (`number_of_states` + optional `state_text`).
  Intrinsic CHANGE_OF_STATE + FAULT_STATE alarming is available when enabled at
  creation.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: The discrete value or mode.
    **Dev must**: Your application logic writes the current state (direct if not
    commandable; via set_priority/PA if commandable). Other logic reads it to act.

  - `priority_array`, `relinquish_default`:
    **Dev must**: Optional Priority commanding; library derives PV.

  - `number_of_states`, `state_text` (size must match `number_of_states`):
    Human names for states 1..N.
    **Dev must**: Define states; keep text array in sync.

  - `feedback_value`: Actual state from hardware.
    **Dev must**: Update from feedback sensor; used for command failure alarming.

  - `alarm_values`: List of state numbers that are alarm.
    **Dev must**: For intrinsic, your event engine runs CHANGE_OF_STATE algorithm,
    updates event state/notifications.

  - `fault_values`: States that indicate fault.
    **Dev must**: If PV in fault_values, set reliability appropriately.

  - `status_flags`, `out_of_service`, `reliability`:
    **Dev must**: `out_of_service` for test direct writes.
    Reliability from actuator health. `in_alarm`/`fault`/`out_of_service` bits
    of `status_flags` are auto-managed by the object (`overridden` is local matter).

  In-memory multistate "variable". Your code is the producer and consumer.

  ### Intrinsic Reporting

  When `intrinsic_reporting: true` is passed to `create/4`, the CHANGE_OF_STATE (and
  optionally FAULT_STATE) algorithms become active.

  ### Commandability and Priority Arrays

  Value objects can have a `priority_array` (making them commandable). When a priority array
  is present, the present value is protected and is only changed through the priority mechanism.

  ### Examples

  Creating a minimal Multistate Value:

      iex> {:ok, mv} = BACnet.Protocol.ObjectTypes.MultistateValue.create(5, "ModeSel", %{present_value: 1}); mv.present_value
      1

  With intrinsic reporting:

      iex> {:ok, mv} = BACnet.Protocol.ObjectTypes.MultistateValue.create(6, "Flag", %{present_value: 1}, intrinsic_reporting: true); mv.object_name
      "Flag"

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.ChangeOfState`
  - `BACnet.Protocol.FaultAlgorithms.FaultState` (optional)
  """

  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Multistate Value object.

  In addition to the common options, Multistate Value supports:
  - `intrinsic_reporting` - Enables CHANGE_OF_STATE (and FAULT_STATE) intrinsic reporting.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents an Multistate Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected.
  """
  bac_object Constants.macro_assert_name(:object_type, :multi_state_value) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:device_type, String.t())
    field(:event_state, Constants.event_state(), required: true)
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean(), required: true)

    field(:present_value, pos_integer(),
      required: true,
      default: 1,
      validator_fun: &(&1 <= (&2[:number_of_states] || -1)),
      annotation: {:readonly_when, {:out_of_service, false}}
    )

    field(:priority_array, PriorityArray.t(pos_integer()), readonly: true)

    field(:relinquish_default, pos_integer(),
      validator_fun: &(&1 <= (&2[:number_of_states] || -1)),
      default: 1
    )

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:fault_values, [non_neg_integer()],
      default: [],
      implicit_relationship: :reliability
    )

    field(:number_of_states, pos_integer(), required: true, readonly: true, default: 1)

    field(:state_text, BACnetArray.t(String.t(), pos_integer()),
      validator_fun: &(BACnetArray.size(&1) == (&2[:number_of_states] || -1))
    )

    # Intrinsic Reporting
    field(:alarm_values, [non_neg_integer()], intrinsic: true, default: [])
  end
end
