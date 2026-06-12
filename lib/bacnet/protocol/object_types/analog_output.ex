defmodule BACnet.Protocol.ObjectTypes.AnalogOutput do
  @moduledoc """
  The Analog Output object is used to command analog actuators (valve or
  damper positioners, variable-speed drives, heating elements, etc. -- which may be
  hardware output signals or anything similar) or to publish
  analog setpoints and calculated control signals. The `present_value` is fully
  commandable: writes go through a 16-level `priority_array` with a `relinquish_default`
  fallback; the effective value is the highest-priority non-null entry (or the default).

  In addition to commandability, the object supports COV reporting (tunable via
  `cov_increment`) and can be placed out of service. When `intrinsic_reporting: true`
  is supplied to `create/4`, OUT_OF_RANGE intrinsic event generation is enabled using
  `high_limit`, `low_limit` and `deadband`. Typical companion properties are `units`,
  `min_present_value`, `max_present_value`, `resolution`, and `device_type`.

  ### Object Description (ASHRAE 135)

  > The Analog Output object type defines a standardized object whose properties represent
  > the externally visible characteristics of an analog output.
  >
  > Analog Output objects that support intrinsic reporting shall apply the OUT_OF_RANGE
  > event algorithm.

  ### Behaviour and Operation

  Analog Output objects are *commandable output* objects. The effective `present_value`
  (the value that the local application should drive to the actuator) is derived from
  the `priority_array`: the highest-priority (lowest numeric slot) non-`nil` entry wins;
  if none is set, `relinquish_default` is used. The library automatically keeps
  `present_value` in sync whenever the priority array or relinquish default changes
  (except while `out_of_service` is `true`).

  Application code (the device server or control logic) must observe changes to
  `present_value` (via polling, subscriptions, or by hooking object updates) and apply
  the value to the target (hardware or anything similar). It must *not* write directly to
  `present_value` through `update_property/3` while `out_of_service` is `false`; use
  `set_priority/3` (or update the `priority_array` / `relinquish_default` properties)
  instead. When `out_of_service` is `true`, the output is disconnected and a
  test value may be forced directly into `present_value`.

  `reliability` and `status_flags` reflect problems detected by the output channel or
  feedback (if any). COV reporting on the present value is available and
  rate-limited by `cov_increment`.

  When created with `intrinsic_reporting: true` the OUT_OF_RANGE intrinsic alarming
  properties (`high_limit`, `low_limit`, `deadband`, ...) are present and the object
  will manage event state transitions accordingly.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: Effective commanded analog value.
    **Dev must**: Never write directly (library rejects unless `out_of_service`); use
    `set_priority/3` or update the `relinquish_default`. Your actuator driver
    reads the effective `present_value` (using `get_output/2`) and drives hardware.

  - `priority_array`: The command sources.

  - `status_flags`, `out_of_service`, `reliability` (with inhibit):
    **Dev must**: `out_of_service` lifts PV protection for testing. Reliability from
    actuator (`:no_output`, etc). The `in_alarm`, `fault` and `out_of_service` bits of
    `status_flags` are automatically maintained by the object. The `overridden` bit
    is a local matter (your feedback logic can set it, if appropriate).

  - `min_present_value`, `max_present_value`, `resolution`, `units`, `cov_increment`:
    **Dev must**: Enforce in your hardware driver (limit outputs further to hardware limit)

  - Intrinsic (high/low/deadband + event, and feedback_value for command_failure):
    **Dev must**: After PV changes or feedback, re-eval OUT_OF_RANGE or
    COMMAND_FAILURE; drive the event machine and notifications.

  See the detailed commandability model notes below, plus runtime, protection,
  feedback, reliability, COV, intrinsic.

  **Commandability model (the core contract)**: Because the object always declares
  both `priority_array` and `relinquish_default`, the generated code
  treats `:present_value` as a *derived* property. The only supported ways to
  change the commanded value are:
  - `set_priority(obj, 1..16, value_or_nil)`  - preferred high-level API
  - `update_property(obj, :priority_array, new_pa)` or
    `update_property(obj, :relinquish_default, val)`
  Any attempt to call `update_property(obj, :present_value, ...)` while
  `out_of_service == false` is rejected by the library with a clear error.
  This is the opposite of pure input objects, where the *server* must supply the
  protection.

  **How the library keeps present_value in sync**:
  - on `create` (if a PA is supplied)
  - on `add_property` when a PA/relinquish is added
  - on `update_property` when PA or relinquish changes (unless `out_of_service`)
  - on `set_priority`
  The recalc is simply: highest non-nil priority slot, else `relinquish_default`.
  When `out_of_service` is `true`, this auto-sync is suppressed, so you can force a
  synthetic command for testing while the real actuator is disconnected.

  **Your actuator driver responsibility**: After any successful update that changes
  the returned object's `present_value`, your driver (or a change subscriber /
  GenServer) must read the new value and drive the hardware (DAC, PWM, 4-20 mA
  loop, valve positioner …). You can poll the object, or better, have the object
  store call a callback / publish on a PubSub topic when a commandable object
  changes. The `device_type` field is a good place to store a human string that
  your HMI can show ("0-10V damper actuator on AO-03").

  **out_of_service for outputs**: `true` means "the physical channel is isolated from
  this object; the value you see/write is for simulation only". Your driver must
  stop driving the real hardware (or put it in a safe state) while `true`.
  The `present_value` is still subject to command priorization.

  **Intrinsic alarming (OUT_OF_RANGE on a commanded value)**: When enabled the
  object carries high/low/deadband etc. After you (or a `set_priority/3`) change
  the effective PV, run the OUT_OF_RANGE evaluation exactly as for an Analog Input.
  This is useful for "commanded value is outside the safe range the actuator
  should ever see".

  **Reliability for an output**: You (the driver) set it based on actuator health,
  wiring, power, etc. A typical pattern is to have a background task that reads
  the real feedback (if any) and, if it doesn't match the commanded value for
  longer than a timeout, sets reliability to `:process_error` or similar (the
  `fault` bit in `status_flags` will be automatically updated by the object).

  **Remote objects**: If `_metadata.remote_object` is set (populated by
  `BACnet.Protocol.ObjectsUtility` when reading from a remote device), all mutation
  operations (`update_property`, `add_property`, `set_priority`, etc.) will be rejected
  by the generated code. You can only read remote analog outputs.

  **Important invariant**: after any call that returns `{:ok, new_obj}`, the
  `new_obj.present_value` is the value your hardware *must* be driving if NOT
  `out_of_service` (subject to polarity, scaling, min/max clamps you implement on top).
  If you ever see a mismatch between the object and reality for longer than your tolerance,
  raise the reliability / event.

  See the generated moduledoc tables for which fields are
  readonly, required, have init_funs, validators, or implicit_relationships.

  ### Intrinsic Reporting

  When `intrinsic_reporting: true` is passed to `create/4`, the `deadband`,
  `high_limit` and `low_limit` properties become active and the object
  participates in intrinsic event reporting using the OUT_OF_RANGE algorithm.

  ### COV Reporting

  Change-of-value reporting is supported via the `cov_increment` property.

  ### Commandability and Priority Arrays

  As an output object this always has a `priority_array` together with `relinquish_default`.
  The present value is protected from direct modification and is normally only changed
  through the priority array (writing prioritized to `present_value`).

  ### Examples

  Creating a simple Analog Output (commandable object):

      iex> {:ok, ao} = BACnet.Protocol.ObjectTypes.AnalogOutput.create(1, "Valve Cmd", %{units: :percent}); ao.units
      :percent

  Enabling intrinsic reporting (additional properties become available):

      iex> {:ok, ao} = BACnet.Protocol.ObjectTypes.AnalogOutput.create(2, "Setpoint", %{
      ...>   units: :degrees_celsius
      ...> }, intrinsic_reporting: true); is_number(ao.high_limit)
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
  Options accepted when creating or configuring an Analog Output object.

  In addition to the common options, Analog Output supports:
  - `intrinsic_reporting` - Enables the OUT_OF_RANGE intrinsic reporting properties
    (deadband, high_limit, low_limit).
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents an Analog Output object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.

  For commandable objects (objects with a priority array), the present value property is protected.

  To get the physical state, call `get_output/2` and the function gets the present value in respect
  to the out of service state.
  """
  bac_object Constants.macro_assert_name(:object_type, :analog_output) do
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

    field(:priority_array, PriorityArray.t(float()), required: true, readonly: true)

    field(:relinquish_default, float(),
      required: true,
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
    field(:profile_name, String.t())

    # COV Reporting
    field(:cov_increment, float(), cov: true, default: 0.1)

    # Intrinsic Reporting
    field(:deadband, float(), intrinsic: true, default: 0.0)
    field(:high_limit, float(), intrinsic: true, default: 0.0)
    field(:low_limit, float(), intrinsic: true, default: 0.0)
  end

  @doc """
  Get the logical state of the object from the present value property.

  If the object is out of service, then the `decoupled_output_state` is returned.
  The specification specifies that when the object is out of service, then the physical output
  is decoupled from the BACnet present value. The actual physical output state can then either
  hold its last value, go to a safe state or behaves according to local logic (-> defined as local matter).
  The default value is `0.0` - the safe state of physical outputs in typical environments.
  """
  @spec get_output(t(), float()) :: boolean()
  def get_output(%__MODULE__{} = object, decoupled_output_state \\ 0.0)
      when is_float(decoupled_output_state) do
    if object.out_of_service do
      decoupled_output_state
    else
      object.present_value
    end
  end
end
