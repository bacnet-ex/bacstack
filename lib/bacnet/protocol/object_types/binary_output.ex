defmodule BACnet.Protocol.ObjectTypes.BinaryOutput do
  @moduledoc """
  The Binary Output object is used to command two-state actuators (relays,
  contactors, motor starters, solenoid valves, fans, pumps, etc. -- which may be
  hardware output signals or anything similar). Its `present_value`
  (ACTIVE/INACTIVE) is fully commandable through a priority array; the resulting
  command is translated to the output according to the `polarity` property
  (normal or reverse).

  In addition to priority-based commandability and `relinquish_default`, the object
  provides a `minimum_off_time` / `minimum_on_time` interlock mechanism and can
  optionally perform an automatic feedback write to the `feedback_value` property.
  When `intrinsic_reporting: true` is used at creation the COMMAND_FAILURE algorithm
  plus associated event properties become active.

  ### Object Description (ASHRAE 135)

  > The Binary Output object type defines a standardized object whose properties represent
  > the externally visible characteristics of a binary output.
  > A "binary output" is a physical device or hardware output that can be in only one of two distinct states.
  >
  > Binary Output objects that support intrinsic reporting shall apply the COMMAND_FAILURE event algorithm.

  ### Behaviour and Operation

  Binary Output objects are commandable two-state output objects (relays, motor
  starters, etc.). The effective `present_value` (the logical command the local
  logic should act upon) is always derived from the `priority_array` +
  `relinquish_default`. The library keeps `present_value` synchronised automatically.
  Application code must react to changes in `present_value` (and `polarity`) and
  apply it to the target (hardware or anything similar) accordingly. It must use `set_priority/3` (or write the
  priority array / relinquish default) rather than writing `present_value` directly.

  While `out_of_service` is true, the output is disconnected from the object
  and a test command may be forced into `present_value`. Many binary outputs also
  support an optional `feedback_value` (useful for verifying that the
  commanded state was actually achieved).

  Minimum on/off time interlocks (`min_on_time`, `min_off_time`) are maintained by
  the application layer. When intrinsic reporting is enabled the COMMAND_FAILURE
  algorithm can detect when the output fails to reach the commanded
  state (using feedback).

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: The effective commanded state (after priority arbitration or relinquish).
    **Dev must**: Use `set_priority/3` or update relinquish.
    Your actuator driver typically calls the provided `get_output/2` helper
    to read the effective value and drive hardware. On polarity change or relinquish,
    re-apply to hardware.

  - `priority_array`, `relinquish_default`: Command sources.
    **Dev must**: Write via the high level APIs; the macro syncs PV from highest
    priority or default.

  - `status_flags`: The `in_alarm`/`fault`/`out_of_service` bits of `status_flags`
    are auto-managed; `overridden` is local matter.
    Maintain feedback if used (and set `overridden` if appropriate).

  - `change_of_state_count`, `change_of_state_time`, `elapsed_active_time`,
    `time_of_state_count_reset`, `time_of_active_time_reset`:
    History counters for state transitions and active time.
    **Dev must**: On every actual logical state flip (after polarity), bump count,
      set time, accumulate elapsed if active.
      On reset writes to the reset times, snapshot current and clear counters.
      These are side-effect "live" history properties you maintain from state changes
      (analog to `value_*` in Accumulator).

  - `active_text` / `inactive_text`: Human strings.
    **Dev must**: Set at init; changes are just data.

  - `feedback_value` (if present/intrinsic): For command_failure alarming.
    **Dev must**: If supporting, your hardware feedback must update this.

  - Intrinsic event properties: For command failure or other.
    **Dev must**: Drive event evaluation after PV or feedback changes.

  **Commandability & protection**: Same rules as any commandable: only
  `set_priority/3` or writes to the PA/relinquish fields change the effective
  command. Direct PV writes are rejected by the library.

  **out_of_service for outputs**: `true` means "the physical channel is isolated from
  this object; the value you see/write is for simulation only". Your driver must
  stop driving the real hardware (or put it in a safe state) while `true`.
  The `present_value` is still subject to command priorization.
  See also `get_output/2`.

  **Polarity and the physical world**: The logical PV (what the priority array
  and relinquish_default produce) is translated by the `polarity` property
  before it becomes the "command the hardware should see". Your driver must
  apply the polarity when it drives the relay / contactor / etc.
  You can use `get_output/2` to get the effective state your driver should apply.

  **Minimum on/off times**: The `min_on_time` and `min_off_time` fields (in
  seconds) are stored on the object. It is your driver's job to remember when
  the output last changed state and to refuse (or delay) a command that would
  violate the interlock.
  The object uses a process-less architecture, so it can not enforce them.
  The driver should write to the priority 6 with the current command state
  and automatically lift priority 6 once time has passed.

  **Feedback and COMMAND_FAILURE**: This is the classic "commanded vs. actual"
  pattern for binary outputs. If you set the `auto_write_feedback` opt
  flag, the library will copy the effective (logical) PV into `feedback_value`
  on every change. If the underlying hardware can report back the actual state,
  you should instead update the property yourself.

  **elapsed_active_time etc.**: Same maintenance responsibility as on the
  corresponding Binary Input - every time the *physical* state changes you
  update the counters and timestamps on the output object (or the driver can
  maintain them and only write when they change).

  **Intrinsic on a binary output**: COMMAND_FAILURE is the interesting one; it
  uses the feedback mechanism described above. OUT_OF_RANGE doesn't make much
  sense on a boolean; the enrollment would be on a different object that
  watches the consequence of this output.

  **Reliability for an output**: You (the driver) set it based on actuator health,
  wiring, power, etc. A typical pattern is to have a background task that reads
  the real feedback (if any) and, if it doesn't match the commanded value for
  longer than a timeout, sets reliability to `:process_error` or similar (the
  `fault` bit in `status_flags` will be automatically updated by the object).

  **Remote objects**: If `_metadata.remote_object` is set (populated by
  `BACnet.Protocol.ObjectsUtility` when reading from a remote device), all mutation
  operations (`update_property`, `add_property`, `set_priority`, etc.) will be rejected
  by the generated code. You can only read remote binary outputs.

  **Important invariant**: after any call that returns `{:ok, new_obj}`, the
  `new_obj.present_value` is the value your hardware *must* be driving if NOT
  `out_of_service` (subject to polarity, scaling, min/max clamps you implement on top).
  If you ever see a mismatch between the object and reality for longer than your tolerance,
  raise the reliability / event.

  The generated tables are the place to see which fields have
  implicit relationships and which annotations affect encoding.

  ### Intrinsic Reporting

  When `intrinsic_reporting: true` is passed to `create/4`, the object uses the COMMAND_FAILURE
  event algorithm and the related event reporting properties become active.

  ### Commandability and Priority Arrays

  As an output object this always has a `priority_array` together with `relinquish_default`.
  The present value is protected from direct modification and is normally only changed
  through the priority array.

  ### Examples

  Creating a Binary Output with descriptive state texts:

      iex> {:ok, bo} = BACnet.Protocol.ObjectTypes.BinaryOutput.create(1, "Fan Cmd", %{active_text: "On", inactive_text: "Off"}); bo.active_text
      "On"

  Using the special options (auto feedback + intrinsic reporting):

      iex> {:ok, bo} = BACnet.Protocol.ObjectTypes.BinaryOutput.create(2, "Pump", %{}, auto_write_feedback: true, intrinsic_reporting: true)
      iex> {is_boolean(bo.feedback_value), bo.event_state}
      {true, :normal}

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.CommandFailure`
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.PriorityArray

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Binary Output object.

  In addition to the common options, Binary Output supports:
  - `auto_write_feedback` - When enabled, the `feedback_value` is automatically kept in sync
    with `present_value` changes.
  - `intrinsic_reporting` - Enables COMMAND_FAILURE intrinsic reporting properties.
  """
  @type object_opts ::
          {:auto_write_feedback, boolean()}
          | {:intrinsic_reporting, boolean()}
          | common_object_opts()

  @typedoc """
  Represents a Binary Output object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  The physical output decouples the present value and the polarity from the physical state.
  The present value reflects the logical state of the object.
  To get the physical state, call `get_output/2` and the function gets the present value in respect to the polarity
  and respecting out of service state.

  For commandable objects (objects with a priority array), the present value property is protected.
  """
  bac_object Constants.macro_assert_name(:object_type, :binary_output) do
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

    field(:priority_array, PriorityArray.t(boolean()), required: true, readonly: true)

    field(:relinquish_default, boolean(),
      required: true,
      default: false,
      annotation: {:encode_as, :enumerated}
    )

    field(:polarity, Constants.polarity(), required: true, default: :normal)

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())
    field(:profile_name, String.t())

    field(:active_text, String.t(), default: "Active", implicit_relationship: :inactive_text)
    field(:inactive_text, String.t(), default: "Inactive")

    field(:change_of_state_time, BACnetDateTime.t(),
      implicit_relationship: :change_of_state_count,
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    field(:change_of_state_count, non_neg_integer(), default: 0)

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
    field(:feedback_value, boolean(),
      intrinsic: true,
      default: false,
      annotation: {:encode_as, :enumerated}
    )
  end

  @doc """
  Get the logical state of the object from the present value property in respect to the polarity.

  If the object is out of service, then the `decoupled_output_state` is returned.
  The actual polarity is ignored for `decoupled_output_state`.
  The specification specifies that when the object is out of service, then the physical output
  is decoupled from the BACnet present value. The actual physical output state can then either
  hold its last value, go to a safe state or behaves according to local logic (-> defined as local matter).
  The default value is `false` - the safe state of physical outputs in typical environments.
  """
  @spec get_output(t(), boolean()) :: boolean()
  def get_output(%__MODULE__{} = object, decoupled_output_state \\ false)
      when is_boolean(decoupled_output_state) do
    if object.out_of_service do
      decoupled_output_state
    else
      case object.polarity do
        Constants.macro_assert_name(:polarity, :normal) -> object.present_value
        Constants.macro_assert_name(:polarity, :reverse) -> !object.present_value
      end
    end
  end
end
