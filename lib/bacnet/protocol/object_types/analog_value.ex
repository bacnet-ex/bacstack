defmodule BACnet.Protocol.ObjectTypes.AnalogValue do
  @moduledoc """
  The Analog Value object represents an analog (floating-point) data value or parameter
  that exists only inside the BACnet device (setpoint, calculated intermediate result,
  tuned constant, etc.) rather than being directly wired to hardware I/O. Because it is
  not a physical input or output, its `present_value` can be written by the local
  application or by BACnet clients.

  The object is frequently made commandable via a priority array so that multiple
  sources (operators, schedules, control loops, etc.) can compete for control of the
  value with well-defined priority arbitration and a relinquish default. It supports
  COV reporting (via `cov_increment`) and, when `intrinsic_reporting: true` is passed
  at creation, OUT_OF_RANGE alarming. Typical properties include `units` and
  optional min/max present value limits.

  ### Object Description (ASHRAE 135)

  > The Analog Value object type defines a standardized object whose properties represent
  > the externally visible characteristics of an analog value.
  > An "analog value" is a control system parameter residing in the memory of the BACnet Device.
  >
  > Analog Value objects that support intrinsic reporting shall apply the OUT_OF_RANGE
  > event algorithm.

  ### Behaviour and Operation

  Analog Value objects represent in-memory analog parameters or setpoints. The
  `present_value` may be written directly by the local application or by BACnet
  clients (it is a normal writable property unless a priority array has been added).

  If a `priority_array` together with `relinquish_default` is present (the object
  was created as commandable or the priority array was added later), the object
  becomes a commandable value: `present_value` is then derived from the priority
  array (highest priority non-nil entry, falling back to `relinquish default`) and
  direct writes to `present_value` are rejected. Use `set_priority/3` to command it.

  While `out_of_service` is `true`, the physical or logical "consumer" of the value
  should ignore the object and a test value may be forced. `reliability` is used
  to signal problems with the value (e.g. the source calculation is invalid).

  COV and intrinsic OUT_OF_RANGE alarming work the same way as for Analog Output
  when the corresponding features are enabled.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: The current analog value (setpoint, calc result, etc.).
    **Dev must**: If no priority_array, local app or clients write it directly via
    `update_property/3`. If commandable (PA + `relinquish_default` present), only command
    via `set_priority/3` or updating the PA/relinquish.
    Your "consumer" (loop, logic, HMI) reads the effective value after updates.
    The library syncs PV from PA on relevant updates.

  - `priority_array`, `relinquish_default`: Optional for making it commandable
    (unlike outputs, not required at creation).
    **Dev must**: Add later via `add_property/3` if desired. Once added, protection and
    derivation logic activates. Your commanding sources use the priority APIs.

  - `status_flags`, `out_of_service`, `reliability` (implicit inhibit):
    **Dev must**: Reliability usually reflects source health
    (bad calc, missing input to formula, etc.). The `in_alarm`, `fault` and `out_of_service`
    bits are automatically kept in sync by the object; `overridden` is a local matter.

  - `min_present_value`, `max_present_value`, `resolution`, `units`: Config/limits.
    **Dev must**: Set accurately for your use case.

  - Intrinsic (`high/low_limit`, `deadband` + full event set when enabled): For
    OUT_OF_RANGE.
    **Dev must**: After PV (or reliability) change, your event engine must re-evaluate
    OUT_OF_RANGE using these on the object, update `event_state` etc., and emit
    notifications as needed.

  See the "Optional commandability", "Your 'consumer' code", "out_of_service",
  "Intrinsic & COV", "Adding commandability later", "Reliability" sections below for
  more details.

  Analog Value is the "in-memory" analogue of Analog Output. It is the typical
  object type for setpoints, calculated intermediates, tuning constants, etc.
  that live only inside the device.

  **Optional commandability**: Unlike Analog Output (where PA + `relinquish_default`
  are required fields), here `priority_array` is *not* required.
  If the caller never supplies one (neither at create nor later via `add_property/3`),
  then `present_value` behaves like a normal writable property:
  Both local app and network clients can write to the present value at any time.
  As soon as a PA (plus a relinquish_default) appears, the object becomes commandable
  from that moment on and the protection logic kicks in.

  *When a value object is commandable* the exact same rules as Analog Output
  apply: use `set_priority/3` or write the PA/relinquish fields.

  **out_of_service**: Same meaning - the logical consumer should treat the value
  as "don't care / for test only". Direct writes to the PV, if not commandable,
  from the application code must be suspended.

  **Intrinsic & COV**: Identical to the output case. After you (or the network)
  change the effective value, run OUT_OF_RANGE evaluation if intrinsic is on.

  **Adding commandability later**: A client or your own config code can do
  `add_property(obj, :priority_array, empty_pa)` followed by writing the
  `relinquish_default`. From that point on the object is commandable; any
  previous direct value is replaced by the PA-derived one.

  **Reliability**: Usually reflects whether the *source* that is supposed to
  compute or supply this value is healthy (the calculation overflowed, a
  required sensor for the formula is offline, etc.).

  **Remote Analog Values**: Observable only.

  The macro-generated property tables at the bottom of the moduledoc are the
  best place to see exactly which fields become present only when a PA is
  supplied, which have implicit relationships (PA <-> `relinquish_default`), and
  which annotations (cov, readonly, intrinsic …) are attached.

  ### Intrinsic Reporting

  When `intrinsic_reporting: true` is passed to `create/4`, the `deadband`,
  `high_limit` and `low_limit` properties become active for OUT_OF_RANGE event detection.

  ### COV Reporting

  Change-of-value reporting is supported via the `cov_increment` property.

  ### Commandability and Priority Arrays

  Value objects can have a `priority_array` (making them commandable). When a priority array
  is present, the present value is protected and is only changed through the priority mechanism.

  ### Examples

  Creating a simple Analog Value:

      iex> {:ok, av} = BACnet.Protocol.ObjectTypes.AnalogValue.create(10, "Setpoint", %{units: :percent}); av.units
      :percent

  Enabling intrinsic reporting:

      iex> {:ok, av} = BACnet.Protocol.ObjectTypes.AnalogValue.create(11, "CalcResult", %{}, intrinsic_reporting: true); is_number(av.high_limit)
      true

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.OutOfRange`
  """

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring an Analog Value object.

  In addition to the common options, Analog Value supports:
  - `intrinsic_reporting` - Enables the OUT_OF_RANGE intrinsic reporting properties
    (deadband, high_limit, low_limit).
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents an Analog Value object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected.
  """
  bac_object Constants.macro_assert_name(:object_type, :analog_value) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:device_type, String.t())
    field(:event_state, Constants.event_state(), required: true)
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean(), required: true)

    field(:present_value, float(),
      required: true,
      default: 0.0,
      validator_fun: &ObjectsUtility.validate_float_range/2
    )

    field(:priority_array, PriorityArray.t(float()), readonly: true)

    field(:relinquish_default, float(),
      default: 0.0,
      validator_fun: &ObjectsUtility.validate_float_range/2
    )

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())
    field(:resolution, float(), readonly: true)
    field(:units, Constants.engineering_unit(), required: true, default: :no_units)

    field(:max_present_value, float())
    field(:min_present_value, float())

    # COV Reporting
    field(:cov_increment, float(), cov: true, default: 0.1)

    # Intrinsic Reporting
    field(:deadband, float(), intrinsic: true, default: 0.0)
    field(:high_limit, float(), intrinsic: true, default: 0.0)
    field(:low_limit, float(), intrinsic: true, default: 0.0)
  end
end
