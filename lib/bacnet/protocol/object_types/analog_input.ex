defmodule BACnet.Protocol.ObjectTypes.AnalogInput do
  @moduledoc """
  The Analog Input object is the primary BACnet object type for exposing continuous
  sensor measurements such as temperature, pressure, flow, humidity, current, voltage,
  or any other physical analog quantity. Its `present_value` (a float) reflects the
  current reading, scaled and in the units specified by the required `units` property.
  Supporting properties include `min_present_value`/`max_present_value` limits,
  `resolution`, `update_interval`, `device_type` (for the physical sensor), and
  reliability/out_of_service handling.

  Change-of-value (COV) reporting is supported and can be tuned with the `cov_increment`
  property (only notifications are sent when the value changes by at least that amount).
  When `intrinsic_reporting: true` is passed to `create/4`, the object activates
  OUT_OF_RANGE intrinsic alarming with `high_limit`, `low_limit`, and `deadband`
  properties plus the full event reporting machinery.

  ### Object Description (ASHRAE 135)

  > The Analog Input object type defines a standardized object whose properties represent
  > the externally visible characteristics of an analog input.
  >
  > Analog Input objects that support intrinsic reporting shall apply the OUT_OF_RANGE
  > event algorithm.

  ### Behaviour and Operation

  Analog Input objects are measurement objects. The `present_value` (a float in the
  units declared by the required `units` property) is normally maintained by the local
  application or I/O subsystem that reads the physical sensor and writes the current
  value (subject to any scaling, filtering or calibration the device performs).

  BACnet clients may freely read `present_value`, `status_flags`, `reliability`, etc.
  Direct writes to `present_value` from the network side are only permitted while
  `out_of_service` is `true` (this allows forcing a value for testing, simulation or
  commissioning). When `out_of_service` is `false`, the device server must reject
  writes to `present_value` coming over BACnet (the object struct itself does not
  enforce this for input objects because it cannot distinguish local vs. remote
  writers; see `BACnet.Protocol.ObjectsMacro` for guidance).

  Setting `out_of_service` to `true` also signals that the physical input is
  disconnected or ignored. The `reliability` property (together with `status_flags.fault`)
  is used to indicate sensor or input hardware problems. COV reporting is supported and
  can be tuned with `cov_increment` so that notifications are only generated for
  changes large enough to matter.

  When the object is created with `intrinsic_reporting: true`, the intrinsic event
  properties become available and the object will use the OUT_OF_RANGE algorithm to
  manage `event_state` transitions and generate notifications via the configured
  `notification_class`.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: The measured analog value in engineering units.
    **Dev must**: Your I/O / ADC / sensor driver or polling task computes the value
    (apply calibration, scaling, filtering) and calls `update_property(obj, :present_value, val)`
    on samples or significant changes. This is the core "live input" contract.

  - `status_flags`: The `in_alarm`, `fault` and `out_of_service` bits are automatically
    maintained by the object (based on `event_state`, `reliability` and
    the `out_of_service` property). The `overridden` bit is a local matter for the
    user to set when appropriate.

  - `out_of_service`: Suspends real input.
    **Dev must**: Your driver ignores hardware while `true`; your BACnet write handler
    allows forcing present_value only while `true`.

  - `reliability` (implicit to `reliability_evaluation_inhibit`): Sensor health.
    **Dev must**: Set based on hardware (e.g. `:no_sensor`, `:over_range`). The `fault` bit
    in `status_flags` is automatically set by the object. Re-evaluate intrinsic events on change.

  - `cov_increment`: Affects when COV notifications are sent for `present_value` changes.

  - Intrinsic only (`high_limit`, `low_limit`, `deadband`, + event_* set): Limits for
    alarming.
    **Dev must**: After PV/reliability update, your central event engine must run the
    OUT_OF_RANGE algorithm (using these params on the object), transition `event_state`,
    manage timestamps/acked, and send notifications if needed via notification_class.
    Object only stores; you execute.

  - `resolution`, `update_interval`, `min/max_present_value`, `device_type`: Mostly
    static metadata/config.
    **Dev must**: Set at creation or allow writes; publish accurate info from your
    transducer characteristics. `update_interval` can reflect your scan rate.

  See the rest of these notes and the generated tables (at end of moduledoc) for
  creation, runtime PV, write protection, COV, intrinsic, remote objects, etc.

  **Creation**: `create(instance, name, %{units: :degrees_celsius, ...}, intrinsic_reporting: true)`
  Optional fields like `min_present_value`, `max_present_value`, `resolution`, `update_interval`,
  `device_type`, `cov_increment` can be supplied.
  If `intrinsic_reporting: true` is passed in `opts`, the limit fields
  (`high_limit`, `low_limit`, `pulse_rate`, `limit_monitoring_interval`)
  plus the full intrinsic set (`event_enable`, etc.) become active and non-nil.

  **Runtime PV maintenance (the heart of an input object)**: Your I/O scanner, ADC
  driver or periodic task is 100% responsible for the engineering value. Compute it
  (apply any local calibration, filtering, unit conversion), then call
  `update_property(obj, :present_value, val)`. This will:
  - run the validator (float range check)
  - update `status_flags` (`in_alarm`/`fault`/`out_of_service`) automatically as needed
  - return a (possibly mutated) object that you must persist back into your
    object store / ETS / GenServer state.
  Never do `%{obj | present_value: val}` unless you are inside a controlled
  test path; you will bypass protection, validation, etc.

  **Network write protection for inputs (MANDATORY for conformance)**: The library
  explicitly documents that input objects do **not** protect `present_value` themselves
  because they cannot know whether the caller is "local app" or "BACnet wire".
  Therefore your WriteProperty / WritePropertyMultiple / ConfirmedWriteProperty
  service handler (or the generic property writer) **must** protect writes to `present_value`
  when the object is not out of service.
  Local driver code bypasses this check (it calls the function directly).
  When `out_of_service` becomes true the protection is lifted, so a technician or
  simulator can force a value for diagnostics. The `out_of_service` bit in
  `status_flags` is automatically kept in sync by the object.

  **out_of_service + reliability contract**: Setting `out_of_service = true` tells
  everybody "ignore the real sensor, the value you see may be synthetic".
  Your driver should stop (or ignore) hardware reads while it is true. You must
  keep `:reliability` accurate at all times (`:no_fault_detected`,
  `:over_range`, `:under_range`, `:communication_failure`, `:process_error`, ...). When
  reliability is not the no-fault value the `.fault` bit of `status_flags` is
  automatically set by the object (the `overridden` bit is a local matter).
  `reliability_evaluation_inhibit` can be used to temporarily suppress reliability evaluation.

  **Intrinsic reporting / event generation**: With `intrinsic_reporting: true` the
  object carries a complete OUT_OF_RANGE event machine (`high_limit`, `low_limit`,
  `deadband`, `time_delay`, `time_delay_normal`, `event_enable`, `acked_transitions`,
  `event_state`, `event_timestamps`, `notification_class`, ...). After a PV update
  (or a reliability change) your event-detection task must:
  1. Re-evaluate the OUT_OF_RANGE algorithm using the limit/deadband values on
     this object + the current PV.
  2. Possibly transition `event_state` (normal <-> high-limit <-> low-limit).
  3. Update timestamps, ack bits etc.
  4. If a transition that requires notification occurred, look up the
     NotificationClass object and send the appropriate notifications (using the
     priority and ack-required flags from the class).
  The object struct only *stores* the state; the evaluation and notification
  emission is server code (often centralised in an EventManager or similar).
  The same applies to the optional fault algorithm if you support one.

  **Other properties your driver may need to touch**:
  - `update_interval` - you can publish how often you intend to refresh the value.
  - `device_type` - static string describing the transducer ("10k thermistor",
    "4-20mA pressure transducer" …).
  - `resolution` - the smallest change the hardware can reliably report.
  - `min_present_value` / `max_present_value` - Engineering limits of the sensor.
  All of these are normally written once at creation/configuration time.

  **Remote objects**: If `_metadata.remote_object` is set (populated by
  `BACnet.Protocol.ObjectsUtility` when reading from a remote device), all mutation
  operations (`update_property`, `add_property`, `set_priority`, etc.) will be rejected
  by the generated code. You can only read remote analog inputs.

  **Threading / concurrency note**: Your object store must handle concurrent reads
  (many COV subscribers, ReadPropertyMultiple) while you are doing an update.
  The returned object from `update_property` is the new canonical version; atomically
  replace it.

  **Testing / simulation**: The canonical way to force a value for a test is:
    1. Write `out_of_service = true` (allowed even on inputs).
    2. Write the desired `present_value`.
    3. Later set `out_of_service = false` to return to real hardware.

  The generated moduledoc lists every field with its revision,
  required/readonly/protected/ intrinsic flags, default, init_fun,
  validator and annotations - use it as the authoritative reference when writing your driver.

  See also the `ObjectsMacro` moduledoc for the generic rules that apply to all
  objects (protected properties, common defaults, remote-object behaviour, etc.).

  ### Intrinsic Reporting

  When `intrinsic_reporting: true` is passed to `create/4` (or the object is
  configured that way), the following additional properties become active:
  `deadband`, `high_limit`, `low_limit`, plus the standard event reporting set
  (`event_enable`, `event_state`, etc.). The object will use the OUT_OF_RANGE event
  algorithm.

  ### COV Reporting

  Change-of-value reporting is supported via the `cov_increment` property.

  ### Examples

  Creating a simple Analog Input (minimal properties):

      iex> {:ok, ai} = BACnet.Protocol.ObjectTypes.AnalogInput.create(1, "Room Temp", %{units: :degrees_celsius}); ai.units
      :degrees_celsius

  Enabling intrinsic reporting (additional properties become available):

      iex> {:ok, ai} = BACnet.Protocol.ObjectTypes.AnalogInput.create(2, "Pressure", %{
      ...>   units: :pascals
      ...> }, intrinsic_reporting: true); ai.high_limit != nil
      true

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.OutOfRange`
  """

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectsUtility

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring an Analog Input object.

  In addition to the common object options, supports enabling intrinsic
  reporting via `intrinsic_reporting`.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents an Analog Input object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.
  """
  bac_object Constants.macro_assert_name(:object_type, :analog_input) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:device_type, String.t())
    field(:event_state, Constants.event_state(), required: true)
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean(), required: true)

    field(:present_value, float(),
      required: true,
      default: 0.0,
      validator_fun: &ObjectsUtility.validate_float_range/2,
      annotation: {:readonly_when, {:out_of_service, false}}
    )

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())
    field(:resolution, float(), readonly: true, default: 0.1)
    field(:units, Constants.engineering_unit(), required: true, default: :no_units)

    field(:max_present_value, float())
    field(:min_present_value, float())
    field(:update_interval, non_neg_integer())
    field(:profile_name, String.t())

    # COV Reporting
    field(:cov_increment, float(), cov: true, default: 0.1)

    # Intrinsic Reporting
    field(:deadband, float(), intrinsic: true, default: 0.0)
    field(:high_limit, float(), intrinsic: true, default: 0.0)
    field(:low_limit, float(), intrinsic: true, default: 0.0)
  end
end
