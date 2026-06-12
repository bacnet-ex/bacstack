defmodule BACnet.Protocol.ObjectTypes.Loop do
  @moduledoc """
  The Loop object is the standard BACnet representation of a closed-loop controller
  (PID, PI, P, or any other feedback algorithm). It continuously computes a
  `present_value` (the controlled variable or the output, depending on the
  implementation) from a `controlled_variable_reference`, a `setpoint_reference`,
  and the three tuning parameters `proportional_constant`, `integral_constant`,
  and `derivative_constant` (plus bias and other parameters).

  When `intrinsic_reporting: true` the FLOATING_LIMIT event algorithm is
  available for alarming on deviation from setpoint.
  Many additional properties (`update_interval`, `deadband`, etc.) control
  the loop behaviour and event generation.

  ### Object Description (ASHRAE 135)

  > The Loop object type defines a standardized object whose properties represent
  > the externally visible characteristics of any form of feedback control loop.

  ### Behaviour and Operation

  Loop objects represent closed-loop controllers (PID or similar). The local
  control engine (not the BACnet stack) is responsible for periodically reading the
  `controlled_variable_reference` (and setpoint reference), running the control
  algorithm using the `proportional_constant`, `integral_constant`,
  `derivative_constant`, `bias`, `action`, etc., and writing the result into
  `present_value` (and the manipulated variable).

  The object merely stores the tuning parameters, references, and current state
  (`present_value`, `controlled_variable_value`, etc.). BACnet clients can read the
  state for monitoring and can write tuning parameters
  (subject to any application-level interlocks).

  When intrinsic reporting is enabled, the FLOATING_LIMIT algorithm can alarm on
  excessive deviation between the controlled variable and the setpoint.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `present_value`: The output of the control algorithm (manipulated
    variable or the loop's computed output).
    **Dev must**: Your control task (PID etc) reads the controlled var and setpoint
    (via the references), runs the math using the constants on the object, then
    writes the result to the manipulated_variable_reference (another object at
    priority) *and/or* to this present_value for monitoring. This is the live output.

  - `controlled_variable_reference`, `setpoint_reference`,
    `manipulated_variable_reference`: The I/O wiring for the loop.
    **Dev must**: If remote refs, your task does the Read/WriteProperty. Local ones
    you can access directly. The loop object just holds the config.

  - `proportional_constant`, etc. (with implicit *_units), `action`, `bias`,
    `output` limits, etc.: Tuning and behaviour params.
    **Dev must**: Your algorithm uses the values from the object.

  - `status_flags`, `out_of_service`, `reliability`:
    **Dev must**: `out_of_service`: Hold output.
    `in_alarm`/`fault`/`out_of_service` bits of `status_flags` are auto-updated
    by the object.

  - Intrinsic event properties:
    **Dev must**: Re-eval after relevant changes.

  See the "The control loop runs in your code" section below for the exact steps
  your task must perform on its schedule.

  A Loop object is a *data + parameter* container for a control algorithm. The
  actual PID (or similar) math lives in your control task, not in the BACnet
  object.

  **The control loop runs in your code**: On whatever schedule makes sense for the
  process you do:
  1. Read the current value of the `controlled_variable_reference` (may be
     remote - you do the ReadProperty).
  2. Read the `setpoint_reference` (or the local `setpoint` property).
  3. Read all the tuning constants, `bias`, `action` (direct/reverse), min/max
     output, etc. from the Loop object.
  4. Run your PID (or PI, P, fuzzy, …) algorithm.
  5. Write the result into the `manipulated_variable_reference` (the thing you
     are really controlling - usually an Analog Output or an Analog Value)
     *and* into the Loop's own `present_value`.

  After you write to the manipulated variable (and to the Loop's PV) you should
  also update `controlled_variable_value` (and `setpoint` if you are using the
  local one) on the Loop object, so that a remote operator sees a consistent
  snapshot of what the loop "thinks" is happening right now.

  **Priority interaction**: Because the manipulated variable is often a
  commandable Analog Output or Analog Value, the Loop should normally write at
  a well-known priority (the Loop object itself exposes a `priority_for_writing`).
  This way a schedule, an operator, or a fire interlock at a higher priority
  can override the loop without the loop fighting it.

  **Intrinsic FLOATING_LIMIT**: This algorithm is specifically designed for loops.
  It typically alarms when the controlled variable is "floating" too far from
  the setpoint for too long (using the `time_delay`, `high_limit`, `low_limit`,
  `deadband` etc. that live on the Loop). After you update the controlled
  variable or the setpoint on the object, run the FLOATING_LIMIT evaluation and
  drive the event state machine.

  **Writing tuning parameters**: A good HMI will let an operator tweak Kp, Ki, Kd,
  bias, etc. while the loop is running. Your control task simply picks up
  the new numbers on the next cycle.

  **Remote references**: Both the controlled variable and the setpoint (and the
  manipulated variable) can be on other devices. Your control task becomes a
  mini gateway - it does the reads and writes on the network schedule that the
  loop requires.

  **Reliability**: A loop can report `:no_fault_detected`, `:process_error` (the
  actuator is not responding), `:communication_failure` (can't read the sensor),
  `:configuration_error` (the references point at the wrong type of object), etc.
  Your control task is the place that can detect most of these conditions.

  The generated tables at the bottom of its moduledoc are the best place
  to see all the optional parameters
  (proportional_constant_units, integral_constant_units, …,
  maximum_output, minimum_output, update_interval, …) and which ones have
  implicit relationships (the constant + its unit field).

  In short: the Loop object is where an operator or a configuration tool goes
  to see and change *what* the loop is doing and how it is tuned. The actual
  closed-loop arithmetic, the scheduling of the arithmetic, the reading of
  remote sensors and the writing of remote actuators, the bumpless transfer
  logic, and the safety interlocks all live in *your* control engine.

  ### Intrinsic Reporting

  When `intrinsic_reporting: true` is passed to `create/4`, the FLOATING_LIMIT
  event algorithm and related properties become active.

  ### Examples

  Creating a Loop:

      iex> {:ok, l} = BACnet.Protocol.ObjectTypes.Loop.create(1200, "TempPID", %{}); l.object_name
      "TempPID"

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.FloatingLimit`
  """

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectPropertyRef
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.SetpointReference

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Loop object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a Loop object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.
  """
  bac_object Constants.macro_assert_name(:object_type, :loop) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:event_state, Constants.event_state(), required: true)
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean(), required: true)
    field(:present_value, float(), required: true, readonly: true, default: 0.0)
    field(:priority_for_writing, 1..16, required: true, default: 16)

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:action, Constants.action(), required: true, default: :direct)
    field(:bias, float())

    field(:max_output, float())
    field(:min_output, float())

    field(:manipulated_variable_reference, ObjectPropertyRef.t(),
      required: true,
      default: ObjectsMacro.get_default_object_ref()
    )

    field(:output_units, Constants.engineering_unit(), required: true, default: :no_units)

    field(:controlled_variable_reference, ObjectPropertyRef.t(),
      required: true,
      default: ObjectsMacro.get_default_object_ref()
    )

    field(:controlled_variable_value, float(), required: true, default: 0.0)

    field(:controlled_variable_units, Constants.engineering_unit(),
      required: true,
      default: :no_units
    )

    field(:setpoint_reference, SetpointReference.t(),
      required: true,
      default: %SetpointReference{ref: nil}
    )

    field(:setpoint, float(), required: true, default: 0.0)

    field(:update_interval, non_neg_integer())
    field(:profile_name, String.t())

    field(:proportional_constant, float(), implicit_relationship: :proportional_constant_units)
    field(:proportional_constant_units, Constants.engineering_unit())
    field(:integral_constant, float(), implicit_relationship: :integral_constant_units)
    field(:integral_constant_units, Constants.engineering_unit())
    field(:derivative_constant, float(), implicit_relationship: :derivative_constant_units)
    field(:derivative_constant_units, Constants.engineering_unit())

    # COV reporting
    field(:cov_increment, float(), default: 0.1)

    # Intrinsic Reporting
    field(:deadband, float(), intrinsic: true, default: 0.0)
    field(:error_limit, float(), intrinsic: true, default: 0.0)
  end
end
