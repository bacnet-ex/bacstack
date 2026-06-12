defmodule BACnet.Protocol.ObjectTypes.MultistateOutput do
  @moduledoc """
  The Multistate Output object commands a multi-state actuator
  (e.g. multi-speed fan, chiller mode selector,
  damper with several positions, etc. -- which may be
  hardware output signals or anything similar). The `present_value`
  is an integer in the range 1..N; the meaning of each state number
  is defined locally and can be documented with `state_text`.

  The object is fully commandable via a priority array. When
  `intrinsic_reporting: true` is used, the COMMAND_FAILURE event algorithm plus
  associated properties become active so that failure to reach the commanded state
  can be alarmed.

  ### Object Description (ASHRAE 135)

  > The Multi-state Output object type defines a standardized object whose properties
  > represent the desired state of one or more physical outputs or processes within
  > the BACnet Device in which the object resides.
  >
  > Multi-state Output objects that support intrinsic reporting shall apply the COMMAND_FAILURE event algorithm.

  ### Behaviour and Operation

  Multistate Output objects command multi-position outputs.
  The local logic must observe `present_value` (1..N) and apply it to the
  target, taking `state_text` into account for documentation only.

  The object is fully commandable: `present_value` is derived from the priority
  array + relinquish default. Application code must use `set_priority/3`
  to command it; direct writes to `present_value` are blocked.

  When intrinsic reporting is enabled the COMMAND_FAILURE algorithm uses the
  feedback `feedback_value` to detect failures to reach the commanded state.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: Effective commanded discrete state.
    **Dev must**: Command only via `set_priority/3`.
    Your driver reads effective state and maps to hardware.

  - `priority_array`, `relinquish_default`:
    **Dev must**: Priority commanding; library derives PV.

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

  See the **Your driver** notes below.

  **Your driver**: Read the effective 1..N and map it through whatever hardware
  abstraction you have (write a register on a VFD, set a stepper position,
  select a mode in a chiller controller, …).

  **state_text**: Purely documentary. Your HMI or alarm messages can use it, but
  the wire protocol and your driver only ever deal with the integer.

  **Number of states**: `number_of_states` tells you the valid range.
  Writes of 0 or >N are rejected by `update_property/3`.

  Multistate outputs are commonly used for "mode" or "stage" commands where
  the meaning of each integer is defined by the equipment manufacturer.

  ### Intrinsic Reporting

  When `intrinsic_reporting: true` is passed to `create/4`, the object uses the
  COMMAND_FAILURE event algorithm.

  ### Commandability and Priority Arrays

  As an output object this always has a `priority_array` together with `relinquish_default`.
  The present value is protected from direct modification and is normally only changed
  through the priority array.

  ### Examples

  Creating a minimal Multistate Output:

      iex> {:ok, mo} = BACnet.Protocol.ObjectTypes.MultistateOutput.create(3, "Valve", %{priority_array: %BACnet.Protocol.PriorityArray{}, relinquish_default: 1}); mo.present_value
      1

  Using special options:

      iex> {:ok, mo} = BACnet.Protocol.ObjectTypes.MultistateOutput.create(4, "Mode", %{priority_array: %BACnet.Protocol.PriorityArray{}, relinquish_default: 1}, auto_write_feedback: true, intrinsic_reporting: true); mo.object_name
      "Mode"

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.CommandFailure`
  """

  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Multistate Output object.

  In addition to the common options, Multistate Output supports:
  - `auto_write_feedback` - When enabled, the `feedback_value` is automatically kept in sync
    with `present_value` changes.
  - `intrinsic_reporting` - Enables COMMAND_FAILURE intrinsic reporting.
  """
  @type object_opts ::
          {:auto_write_feedback, boolean()}
          | {:intrinsic_reporting, boolean()}
          | common_object_opts()

  @typedoc """
  Represents an Multistate Output object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected.

  To get the physical state, call `get_output/2` and the function gets the present value in respect
  to the out of service state.
  """
  bac_object Constants.macro_assert_name(:object_type, :multi_state_output) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:device_type, String.t())
    field(:event_state, Constants.event_state(), required: true)
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean(), required: true)

    field(:present_value, pos_integer(),
      required: true,
      default: 1,
      validator_fun: &(&1 <= (&2[:number_of_states] || -1))
    )

    field(:priority_array, PriorityArray.t(pos_integer()), required: true, readonly: true)

    field(:relinquish_default, pos_integer(),
      required: true,
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

    field(:profile_name, String.t())

    # Intrinsic Reporting
    field(:alarm_values, [non_neg_integer()], intrinsic: true, default: [])
    field(:feedback_value, pos_integer(), intrinsic: true, default: 1)
  end

  @doc """
  Get the logical state of the object from the present value property.

  If the object is out of service, then the `decoupled_output_state` is returned.
  The specification specifies that when the object is out of service, then the physical output
  is decoupled from the BACnet present value. The actual physical output state can then either
  hold its last value, go to a safe state or behaves according to local logic (-> defined as local matter).
  The default value is `1` - the safe state of physical outputs in typical environments.
  """
  @spec get_output(t(), pos_integer()) :: boolean()
  def get_output(%__MODULE__{} = object, decoupled_output_state \\ 1)
      when is_integer(decoupled_output_state) and decoupled_output_state >= 1 do
    if object.out_of_service do
      decoupled_output_state
    else
      object.present_value
    end
  end
end
