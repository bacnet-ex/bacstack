defmodule BACnet.Protocol.ObjectTypes.Accumulator do
  @moduledoc """
  The Accumulator object provides a standardised representation for pulse-counting
  measurement devices such as utility meters (electricity, water, gas, etc.). Pulses
  are accumulated into the readonly `present_value` using the `prescale` (pulses per
  unit) and `scale` factors so the exposed value matches the meter's register as
  closely as possible, including proper rollover behaviour at `max_present_value`
  (defaults to 32-bit unsigned max). Additional properties expose the instantaneous
  `pulse_rate` over a configurable `limit_monitoring_interval`, allow presetting the
  counter via `value_set`, and record change timestamps.

  The object supports COV reporting on the present value. When `intrinsic_reporting:
  true` is passed to `create/4`, the UNSIGNED_RANGE event algorithm and associated
  high/low limit properties are activated for alarming on count thresholds.

  ### Object Description (ASHRAE 135)

  > The Accumulator object type defines a standardized object whose properties
  > represent the externally visible characteristics of a device that indicates
  > measurements made by counting pulses.
  >
  > Accumulator objects that support intrinsic reporting shall apply the UNSIGNED_RANGE event algorithm.

  ### Behaviour and Operation

  Accumulator objects are pulse totalizer / measurement objects. The `present_value`
  (a non-negative integer) is maintained by the local application or pulse counting
  hardware/driver. The application is responsible for incrementing the count (or
  writing the accumulated total) as pulses arrive, applying the `prescale` and `scale`
  factors so that the value matches the engineering units expected by the meter
  register as closely as possible. Rollover occurs at `max_present_value` (normally
  2^32-1; the default is set in the struct but can be overridden at creation to higher values).

  The object also exposes `pulse_rate` (when intrinsic or limit monitoring is active),
  `value_change_time` / `value_before_change` for detecting manual presets, and
  `value_set` which the local logic can use to preset the counter. The optional
  `logging_record` / `logging_object` pair supports atomic snapshot acquisition by
  a local logger (see Developer notes).

  `present_value` is declared readonly in the object definition; writes normally come
  only from the local pulse source. `out_of_service` allows the input pulses to be
  ignored while a test total is forced. No priority array is present.

  When `intrinsic_reporting: true`, UNSIGNED_RANGE high/low limit alarming on the
  accumulated count becomes available.

  ### Developer Implementation Notes (geared to device server / application authors)

  The object definition (via `ObjectsMacro`) provides the struct, `create`/`update_property`
  etc., type safety, defaults, implicit relationships, validators, and `readonly`/`protected`
  annotations (the latter are *hints*; your device server read/write handlers must enforce
  BACnet-side write protection for readonly properties and inputs).

  **Special / live properties and expected developer behaviour**

  These are the properties that are not just passive configuration or simple data. The
  object struct + macro provide storage, type checks, some implicit side effects, and
  advisory flags. You (device server / driver / app author) must implement the live
  semantics and keep them consistent with the real world / hardware. Always use
  `update_property/3` (or helpers) to change them; direct map updates bypass logic.

  - `present_value`: The current accumulated total, after applying prescale + scale
    and rollover at `max_present_value`. This is the primary "live" input property
    (analog to other input objects' present_value).
    **Dev must**: From your pulse counting hardware/driver/polling task, call
    `update_property(obj, :present_value, new_total)` on pulse arrival or periodic
    batch. Handle rollover yourself or let the update do it if within max. This drives
    COV, intrinsic events (UNSIGNED_RANGE), status, etc.

  - `out_of_service`: When `true`, pulses are ignored; PV can be forced for
    testing/commissioning.
    **Dev must**: Suspend normal pulse processing / driver updates while `true`. Allow
    (in your write handler) writes to `present_value` / `value_set` only when `true`.
    Resume on `false`.

  - `reliability` (with implicit `reliability_evaluation_inhibit`): Current fault status
    (no_fault_detected, over_range, etc.).
    **Dev must**: Update it based on your pulse source health (e.g. comms loss to
    remote counter, sensor error). When changed, re-eval events if intrinsic.

  - `value_set`: The "preset" input. Writing here is how you (or a client when allowed)
    set a new total (e.g. after meter replacement).
    **Dev must**: Your code around `update_property/3` should treat a write to `value_set`
    as a preset: snapshot the old present_value into `value_before_change`,
    set `value_change_time` to now, then apply the new value to `present_value` (or let subsequent logic).
    The change properties are side-effect outputs for observers to detect manual presets.
    Note: server write protection applies similar to `present_value` when `!out_of_service`.

  - `value_change_time` / `value_before_change` (readonly): Timestamp and prior value
    for the last preset.
    **Dev must**: Populate them (as described for `value_set`) so that clients and
    your own logic can detect when/how the accumulator was manually adjusted.

  - `logging_record` + `logging_object`: Support for atomic historical sampling by
    a co-resident logger (e.g. Trend Log in same device).
    **Dev must** (the key acquire-on-read contract): If `logging_object` is set,
    when that object (or any reader) reads `logging_record`, your read path  must:
    1. Capture a *stable, atomic* snapshot from the underlying pulse/accumulated
       state (per spec: not mid-increment of PV vs accumulated_value).
    2. Build `%AccumulatorRecord{timestamp: now, present_value: ..., accumulated_value: ..., ...}`.
    3. Append the new record to the `logging_record` property and `update_property/3`.
    4. Return the fresh value.
    Before first acquire (or if never), use wildcard timestamp + zeros + status `:starting`.
    See `BACnet.Protocol.AccumulatorRecord` for the struct. This is analogous to `present_value`
    maintenance but triggered by reads instead of pulses.

  - `pulse_rate` + `limit_monitoring_interval` (intrinsic related): pulse_rate is the
    count of pulses in the recent interval.
    **Dev must**: Depending on implementation, either maintain pulse_rate yourself
    (from hardware) or ensure the limit monitoring logic (your event engine) has
    what it needs. The object links it via implicit to the interval.

  - Intrinsic properties (`high_limit`, `low_limit`, ... + full event set when enabled):
    **Dev must**: After any `present_value` or `reliability` update, your event
    processing code must re-run the UNSIGNED_RANGE algorithm using the limits on
    this object, update `event_state`/timestamps etc., and emit notifications via the
    `notification_class` if transitions require it. The object stores state; you drive
    the machine.

  - `cov_increment`: Affects when COV notifications are sent for `present_value` changes.

  General: After any `update_property/3` that returns `:ok`, store the returned object (it
  may have had computed/side effects). Your write handlers must respect readonly
  (use `get_readonly_properties/0`) and `out_of_service` rules for conformance.

  **Creation and initialisation**: Use `create/4`. Required properties in the map
  include at minimum `:units`, `:scale`, `:prescale` (and `:max_present_value` if you
  want something other than the 32-bit max default).
  If `intrinsic_reporting: true` is passed in `opts`, the limit fields
  (`high_limit`, `low_limit`, `pulse_rate`, `limit_monitoring_interval`)
  plus the full intrinsic set (`event_enable`, etc.) become active and non-nil.

  **Maintaining present_value at runtime**: Your sensor/pulse driver or I/O polling task
  MUST keep the value up to date by calling `update_property(obj, :present_value, new_count)`
  (or the equivalent in your device server abstraction) whenever a pulse arrives or
  a batch is processed. Direct struct mutation (`%{obj | present_value: val}`) bypasses
  validators, implicit relationships, the type's inhibit_object_check,
  and any side-effect logic. After a successful update the
  returned object should be stored back in your object database / registry.

  **Write protection for inputs (critical for BACnet conformance)**: Unlike commandable
  output/value objects (where the library itself protects `:present_value` in
  `update_property/3` and `set_priority/3` unless `out_of_service`), input-style
  objects like Accumulator provide no automatic protection. The *device server* layer
  (your WriteProperty / WritePropertyMultiple handler, or the code that receives
  BACnet writes) is responsible for rejecting attempts to write `:present_value`
  (or `:value_set`) when `out_of_service == false`. Typical error is
  `{:error, :write_access_denied}` or a BACnet error constructed from it. Local
  application code (your driver) is allowed to "write" via the internal path. See
  the macro documentation in `BACnet.Protocol.ObjectsMacro` for the exact note on
  input objects.

  **out_of_service semantics**: Setting it `true` (via network write or local) signals
  that pulses should be ignored; you can then force a synthetic total by writing
  `:present_value` (now allowed) for testing, simulation, or commissioning. The
  pulse_rate / limit logic should typically be suspended. When you set it back to
  `false`, the physical source resumes.

  **Presets and change tracking**: To preset the accumulator (e.g. after a meter
  replacement), write the desired total to `:value_set`. Your driver should monitor
  the side-effect properties (`value_change_time`, `value_before_change`) that the
  object populates on such updates.

  **Logging_Record and Logging_Object (special acquire-on-read properties)**: These
  optional properties enable atomic historical sampling by a co-located logger
  (commonly a Trend Log in the same device) without the logger needing direct access
  to the pulse hardware or risking inconsistent reads of present_value vs. the
  internal accumulated total.

  `logging_object` (when present) identifies the logger object that will "acquire"
  records from this accumulator. Its presence changes the required behaviour of
  `logging_record`.

  `logging_record` holds the most recently acquired atomic sample.
  Each `BACnet.Protocol.AccumulatorRecord` carries a timestamp, the `present_value`
  and `accumulated_value` at sample time, plus an `accumulator_status`.

  Per ASHRAE 135: the values must be acquired and returned "atomically". If
  `logging_object` is set and no acquisition has occurred yet, the record must use a
  fully-wildcard timestamp, zero for the two value fields, and status `:starting`.
  Acquisition must occur when the underlying system is in a stable state (example
  from the spec: not between a PV pulse increment and the corresponding
  accumulated-value update).

  **What the developer must do (analogous to maintaining present_value)**: The
  library never auto-populates `logging_record`; it is entirely your responsibility
  (your pulse driver, meter interface, or a logging coordinator). Exactly as you
  drive present_value from the physical source via `update_property/3`, you must
  supply fresh records to logging_record via the same call when acquisition is
  triggered.

  - Network writes to `logging_record` (and usually `logging_object` only by
    privileged local logic) must be rejected by your device server's WriteProperty
    handler using the readonly annotation (`get_readonly_properties/0`) or explicit
    checks. Internal/driver code may write.
  - On every *read* of `logging_record` (BACnet ReadProperty or internal read by
    the logger that owns `logging_object`): your read path must trigger acquisition
    of a stable snapshot from the real counter, build the `AccumulatorRecord`,
    `update_property(obj, :logging_record, [record])`, then return the value. This
    is the key "special property" contract.
  - Because acquisition logic is instance- and hardware-specific, most
    implementors handle the special case for accumulator+logging_record centrally
    in their property read dispatcher rather than (or in addition to) wiring an
    annotation on the field definition.

  After acquisition the just-captured record stays visible to subsequent reads
  until the next acquisition. This lets a local Trend Log treat the accumulator's
  logging_record as a "sample source" that always yields a consistent point-in-time
  total when read.

  **Intrinsic / event processing**: When intrinsic is enabled the object carries the
  full event state machine fields. After you update `:present_value` (or
  `:reliability`), your event engine (or the code that calls into event detection)
  must re-evaluate the UNSIGNED_RANGE algorithm using the high/low/deadband params
  present on the object, update `:event_state`, manage `:event_timestamps` etc., and
  emit ConfirmedEventNotification / Unconfirmed... via the referenced
  `notification_class` when transitions occur. The object itself does not auto-emit;
  that is a server responsibility.

  **Remote objects**: If `_metadata.remote_object` is set (populated by
  `BACnet.Protocol.ObjectsUtility` when reading from a remote device), all mutation
  operations (`update_property`, `add_property`, `set_priority`, etc.) will be rejected
  by the generated code. You can only read remote accumulators.

  **Reliability and status**: Your driver must keep `:reliability` current (e.g.
  `:no_fault_detected`, `:over_range`, `:communication_failure` for a remote pulse
  source). The `status_flags.fault` (and `in_alarm`, `out_of_service`) bits are
  automatically kept in sync by the object based on `reliability`, `event_state` and
  `out_of_service`. The `overridden` bit is a local matter.

  See the generated moduledoc tables for which fields are
  readonly, required, have init_funs, validators, or implicit_relationships.

  ### Intrinsic Reporting

  When `intrinsic_reporting: true` is passed to `create/4`, the UNSIGNED_RANGE event
  algorithm and related properties become active.

  ### Examples

  Creating an Accumulator:

      iex> {:ok, acc} = BACnet.Protocol.ObjectTypes.Accumulator.create(200, "Energy", %{units: :kilowatt_hours, scale: 10, prescale: %BACnet.Protocol.Prescale{multiplier: 1, modulo_divide: 1}}); acc.object_name
      "Energy"

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.UnsignedRange`
  """

  alias BACnet.Protocol.AccumulatorRecord
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.Prescale

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring an Accumulator object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents an Accumulator object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  The `max_present_value` property defaults to `2^32-1` and can be manually
  set to a higher value, if desired and/or needed.
  """
  bac_object Constants.macro_assert_name(:object_type, :accumulator) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:device_type, String.t())
    field(:event_state, Constants.event_state(), required: true)
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean(), required: true)
    field(:present_value, non_neg_integer(), required: true, readonly: true, default: 0)

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:units, Constants.engineering_unit(), required: true, default: :no_units)

    field(:scale, float() | integer(),
      required: true,
      annotation: [
        decoder: fn %Encoding{extras: extras} = encoding ->
          case Keyword.fetch(extras, :tag_number) do
            {:ok, 0} ->
              with {:ok, {_tag, value}} <- ApplicationTags.unfold_to_type(:real, encoding.value) do
                {:ok, value}
              end

            {:ok, 1} ->
              with {:ok, {_tag, value}} <-
                     ApplicationTags.unfold_to_type(:signed_integer, encoding.value) do
                {:ok, value}
              end

            _other ->
              {:error, :invalid_value}
          end
        end,
        encoder: fn
          float when is_float(float) ->
            with {:ok, raw, _more} <- ApplicationTags.encode_value({:real, float}) do
              Encoding.create({:tagged, {0, raw, byte_size(raw)}})
            end

          int when is_integer(int) ->
            with {:ok, raw, _more} <- ApplicationTags.encode_value({:signed_integer, int}) do
              Encoding.create({:tagged, {1, raw, byte_size(raw)}})
            end

          _other ->
            {:error, :invalid_value}
        end
      ]
    )

    field(:prescale, Prescale.t(), required: true)
    field(:max_present_value, non_neg_integer(), required: true, default: 4_294_967_295)

    field(:value_change_time, BACnetDateTime.t(),
      readonly: true,
      init_fun: &ObjectsMacro.get_default_bacnet_datetime/0
    )

    field(:value_before_change, non_neg_integer(),
      readonly: true,
      default: 0,
      implicit_relationship: :value_change_time
    )

    field(:value_set, non_neg_integer())

    field(:logging_record, [AccumulatorRecord.t()], readonly: true)
    field(:logging_object, ObjectIdentifier.t())

    # Intrinsic Reporting
    field(:high_limit, non_neg_integer(), intrinsic: true, default: 0)
    field(:low_limit, non_neg_integer(), intrinsic: true, default: 0)

    field(:pulse_rate, non_neg_integer(),
      intrinsic: true,
      implicit_relationship: :limit_monitoring_interval
    )

    field(:limit_monitoring_interval, non_neg_integer(), intrinsic: true, default: 1)
  end
end
