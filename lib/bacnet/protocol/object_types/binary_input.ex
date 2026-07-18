defmodule BACnet.Protocol.ObjectTypes.BinaryInput do
  @moduledoc """
  The Binary Input object exposes the state of a physical two-state sensor or contact
  (door switch, pump run status, high-level float, limit switch, etc.). The `present_value`
  is a Boolean (ACTIVE/INACTIVE or similar) that can be inverted from the physical
  polarity via the `polarity` property. A `device_type` string can document the
  underlying hardware.

  The object can be marked as a physical input via metadata and supports out-of-service
  and reliability indication. When `intrinsic_reporting: true` is passed to `create/4`,
  CHANGE_OF_STATE intrinsic alarming is enabled (with optional time delay and event
  parameters). COV reporting is also supported for state changes.

  ### Object Description (ASHRAE 135)

  > The Binary Input object type defines a standardized object whose properties represent
  > the externally visible characteristics of a binary input.
  > A "binary input" is a physical device or hardware input that can be in only one of two distinct states.
  >
  > Binary Input objects that support intrinsic reporting shall apply the CHANGE_OF_STATE event algorithm.

  ### Behaviour and Operation

  Binary Input objects are physical or logical two-state sensor objects. The local
  application or I/O layer is responsible for reading the hardware contact / switch
  (respecting the `polarity` setting - using `set_input/2`) and updating `present_value`.
  The `active_text` / `inactive_text` properties provide human-readable labels
  for the two states.

  Writes to `present_value` over BACnet are only allowed while `out_of_service` is
  true (for testing or simulation). The device server must enforce this protection
  for input objects. `out_of_service` also means the physical input is ignored.

  Additional properties such as `change_of_state_time`, `change_of_state_count` and
  `elapsed_active_time` are maintained by the local logic as side effects of state
  changes. Reliability and status flags indicate contact or wiring problems.

  When `intrinsic_reporting: true` the CHANGE_OF_STATE (and optional FAULT_STATE)
  alarming machinery is present.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: Logical state after polarity.
    **Dev must**: Use the set_input/2 helper to correctly set the present value
    based on the logical state of the physical input.

  - `status_flags`: The `in_alarm`, `fault` and `out_of_service` bits are
    automatically maintained by the object. The `overridden` bit is a local matter.
    **Dev must**: See general input rules (for overridden if used).

  - `out_of_service`:
    **Dev must**: Ignore physical contact and do not set present value.

  - `reliability`:
    **Dev must**: Update from hardware health.

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

  - Intrinsic (`alarm_values` + event set): For `change_of_state` alarming.
    **Dev must**: Re-eval CHANGE_OF_STATE algorithm on PV changes; manage event state/notifications.

  See the rest of the dev notes for polarity, write protection, side-effect counters,
  out_of_service, reliability, COV, intrinsic.

  BinaryInput is the classic "dry contact / run status / limit switch" object.

  **Polarity handling**: The object stores the logical state after polarity has been
  applied. Your contact reader must do:
      raw = read_gpio_or_fieldbus()
      logical = if polarity == :reverse, do: not raw, else: raw
      update_property(obj, :present_value, logical)
  You can also use `set_input/2` to update the present value.
  The `active_text` / `inactive_text` are purely for human consumption (HMI,
  alarm messages); the wire protocol always uses the enumerated 0/1.

  **Write protection (same rule as every input)**: The server-side WriteProperty
  handler must reject writes to `:present_value` (and the counter/time fields if
  you treat them as read-only from the wire) whenever `out_of_service == false`.
  Local driver code is the only thing allowed to advance `change_of_state_count`,
  `elapsed_active_time`, `change_of_state_time` etc.

  **Side-effect counters you must maintain**: Every time the logical state
  actually flips you should:
  - bump `change_of_state_count`
  - set `change_of_state_time` to now
  - if the new state is ACTIVE, start / accumulate `elapsed_active_time`
  - keep `time_of_state_count_reset` / `time_of_active_time_reset` when a
    client (or you) resets the counters.
  These are ordinary properties; you update them with the normal
  `update_property/3` calls.

  **out_of_service**: While `true`, the contact is ignored for alarming and for the
  counters (or you freeze them). A test tool can force ACTIVE/INACTIVE for
  verification of downstream logic (schedules, interlocks, etc.).

  **Intrinsic CHANGE_OF_STATE + optional FAULT_STATE**: After you update PV or
  reliability, your event engine re-evaluates the algorithm that lives in the
  object's event fields. The object stores the current `event_state`,
  `event_timestamps`, `acked_transitions` etc.; you drive the transitions and
  the notification emission.

  **Reliability examples for a binary input**:
  - `:no_fault_detected`
  - `:communication_failure` (if the contact is on a remote I/O block)
  - `:process_error` (welded contact detected by cross-check with a second sensor)

  Use the generated property tables (bottom of the moduledoc) to see exactly
  which fields become active only with `intrinsic_reporting: true`.

  ### Intrinsic Reporting

  When `intrinsic_reporting: true` is passed to `create/4`, the object applies the
  CHANGE_OF_STATE algorithm and the associated alarm/event properties become active.

  ### Examples

  Creating a Binary Input with state texts:

      iex> {:ok, bi} = BACnet.Protocol.ObjectTypes.BinaryInput.create(5, "Door Contact", %{active_text: "Open", inactive_text: "Closed"}); bi.active_text
      "Open"

  Using physical_input + intrinsic_reporting options:

      iex> {:ok, bi} = BACnet.Protocol.ObjectTypes.BinaryInput.create(6, "RunStat", %{}, intrinsic_reporting: true, physical_input: true); is_boolean(bi.present_value)
      true

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.ChangeOfState`
  - `BACnet.Protocol.FaultAlgorithms.FaultState` (optional)
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectsMacro

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Binary Input object.

  In addition to the common options, Binary Input supports:
  - `intrinsic_reporting` - Enables CHANGE_OF_STATE intrinsic reporting.
  - `physical_input` - Marks the object as directly representing a physical sensor input
    (affects present value / polarity handling via helper functions).
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()}
          | {:physical_input, boolean()}
          | common_object_opts()

  @typedoc """
  Represents a Binary Input object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  The physical input decouples the present value and the polarity from the physical state.
  The present value reflects the logical state of the object.
  To set the logical state, call `set_input/2` and the function writes to the present value in respect to the polarity.
  The physical input is NOT a real BACnet property.
  """
  bac_object Constants.macro_assert_name(:object_type, :binary_input) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:device_type, String.t())
    field(:event_state, Constants.event_state(), required: true)
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean(), required: true)

    field(:present_value, boolean(),
      required: true,
      default: false,
      annotation: {:encode_as, :enumerated},
      annotation: {:readonly_when, {:out_of_service, false}}
    )

    field(:polarity, Constants.polarity(), required: true, default: :normal)

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

    # Intrinsic Reporting
    field(:alarm_value, boolean(),
      intrinsic: true,
      default: true,
      required: true,
      default: false,
      annotation: {:encode_as, :enumerated}
    )
  end

  @doc """
  Sets the physical input and writes to the present value property in respect to the polarity.

  If the object is out of service, the present value won't be updated.
  """
  @spec set_input(t(), boolean()) :: {:ok, t()} | property_update_error()
  def set_input(%__MODULE__{} = object, value) when is_boolean(value) do
    new_value =
      case object.polarity do
        Constants.macro_assert_name(:polarity, :normal) -> value
        Constants.macro_assert_name(:polarity, :reverse) -> !value
      end

    new_object = %{
      object
      | _metadata: %{object._metadata | physical_input: value},
        # Only write to the present_value if out_of_service is not active
        present_value: if(object.out_of_service, do: object.present_value, else: new_value)
    }

    {:ok, new_object}
  end
end
