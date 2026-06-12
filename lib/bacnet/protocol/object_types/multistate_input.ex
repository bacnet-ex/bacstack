defmodule BACnet.Protocol.ObjectTypes.MultistateInput do
  @moduledoc """
  The Multistate Input object reports the current state of a multi-position physical
  or logical sensor as a positive integer (1..N). The meaning of each state number
  is a local matter and is documented for humans via the optional `state_text`
  array (index 1 corresponds to state 1). Typical examples: fan speed selector
  feedback, valve position (closed / mid / open), operating mode reported by a
  chiller, etc.

  The number of valid states is declared by the required `number_of_states` property.
  When `intrinsic_reporting: true` is supplied at `create/4`, then the CHANGE_OF_STATE
  algorithm is activated for alarming.

  ### Object Description (ASHRAE 135)

  > The Multi-state Input object type defines a standardized object whose Present_Value
  > represents the result of an algorithmic process within the BACnet Device in which
  > the object resides.
  >
  > Multi-state Input objects that support intrinsic reporting shall apply the CHANGE_OF_STATE event algorithm.

  ### Behaviour and Operation

  Multistate Input objects report the current state of a physical or logical
  multi-position sensor / process as an integer 1..N. The local I/O or algorithm
  layer is responsible for determining the current state and writing it to
  `present_value`. The meaning of each state number is documented via the optional
  `state_text` array.

  Network writes to present_value are only allowed while `out_of_service` is true.
  The device server must enforce input write protection. `out_of_service` also
  means the underlying process or hardware is ignored.

  Intrinsic CHANGE_OF_STATE (and optional FAULT_STATE) alarming is supported when
  enabled at creation.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: The current discrete state.
    **Dev must**: Your process/hardware reader determines the state (1-based) and
    calls `update_property/3` on changes.

  - `number_of_states`: How many states are defined.
    **Dev must**: Set at creation.

  - `state_text` (size must match `number_of_states`): Human names for states 1..N.
    **Dev must**: Define states; keep text array in sync.

  - `alarm_values`: List of state numbers that are alarm.
    **Dev must**: For intrinsic, your event engine runs CHANGE_OF_STATE algorithm,
    updates event state/notifications.

  - `fault_values`: States that indicate fault.
    **Dev must**: If PV in fault_values, set reliability appropriately.

  - `status_flags`, `out_of_service`, `reliability`:
    **Dev must**: Standard input protection: server rejects PV writes
    unless `out_of_service`.
    Your driver ignores hardware on `out_of_service`, allows test value.
    Reliability from process (e.g. invalid state).
    `in_alarm`/`fault`/`out_of_service` bits of `status_flags` are auto-updated by the object.

  ### Intrinsic Reporting

  When `intrinsic_reporting: true` is passed to `create/4`, the CHANGE_OF_STATE (and
  optionally FAULT_STATE) event algorithms and related properties become active.

  ### Examples

  Creating a minimal Multi-state Input:

      iex> {:ok, mi} = BACnet.Protocol.ObjectTypes.MultistateInput.create(1, "Mode", %{}); mi.present_value
      1

  Enabling intrinsic reporting:

      iex> {:ok, mi} = BACnet.Protocol.ObjectTypes.MultistateInput.create(2, "Status", %{}, intrinsic_reporting: true); mi.object_name
      "Status"

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.ChangeOfState`
  - `BACnet.Protocol.FaultAlgorithms.FaultState` (optional)
  """

  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.Constants
  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Multistate Input object.

  In addition to the common options, Multistate Input supports:
  - `intrinsic_reporting` - Enables CHANGE_OF_STATE (and FAULT_STATE) intrinsic reporting.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents an Multistate Input object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.
  """
  bac_object Constants.macro_assert_name(:object_type, :multi_state_input) do
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

    field(:profile_name, String.t())

    # Intrinsic Reporting
    field(:alarm_values, [non_neg_integer()], intrinsic: true, default: [])
  end
end
