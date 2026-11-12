defmodule BACnet.Protocol.ObjectTypes.Loop do
  @moduledoc """
  A Loop represents a feedback controller. For example, it can compare a room
  temperature with its setpoint and command a heating valve. The object exposes
  the measured value, setpoint, tuning and limits. Its `present_value` is the
  control output in `output_units`.

  ### Object Description (ASHRAE 135)

  > The Loop object type defines a standardized object whose properties represent
  > the externally visible characteristics of any form of feedback control loop.

  ### Behaviour and Operation

  Local objects use `HvacPid.Controller` by default. The implementation belongs to
  this module. The integrating application is the
  [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  and needs to retain each result, deliver triggers and service replacement wakeups.
  `BACnet.Protocol.ObjectExecution.Lifecycle` documents that ordering and timer ownership.

  Initialize with `BACnet.Protocol.ObjectExecution.Context` containing fresh clocks,
  `state: nil`, and callbacks for the configured references. Initialization acquires
  one sample immediately when the controlled-variable reference is initialized.
  Each successful sample reads `controlled_variable_reference` and an optional
  `setpoint_reference`, publishes their values and computes `present_value`.
  Both inputs need to use `controlled_variable_units`. Reads accept native numbers or a primitive
  numeric `BACnet.Protocol.ApplicationTags.Encoding`, including a singleton encoding list.
  Values need to fit a finite BACnet REAL. Booleans and non-finite values are rejected.

  A computed result with a configured target requests `:immediate`. The host needs
  to retain the object and PID state before delivering a `:continuation` trigger.
  That continuation writes
  the captured output to `manipulated_variable_reference` at `priority_for_writing`.
  References are local `BACnet.Protocol.ObjectPropertyRef` values. The callbacks
  receive `BACnet.Protocol.DeviceObjectPropertyRef` values with a nil device and
  the configured array index. The host needs to validate and retain target writes.
  Callback exceptions and malformed responses remain programming errors.

  An object instance of 4194303 marks an uninitialized reference. An uninitialized
  controlled-variable reference lets the application supply readings directly.
  Without a referenced or application-supplied reading, the loop holds its output
  and requests no wakeup. Restoring the reference resumes control without
  integrating across the pause. An uninitialized manipulated-variable reference
  lets PID compute a local output without writing to another object. An uninitialized
  setpoint reference selects the fixed setpoint, as does
  `%BACnet.Protocol.SetpointReference{ref: nil}`.

  ### PID terms and units

  - `proportional_constant` is the shared gain in output units per controlled-variable
    unit. Its units property must be `:no_units` for this interpretation.
  - `integral_constant` is the reset time. Supported time units are `:milliseconds`,
    `:hundredths_seconds`, `:seconds`, `:minutes` and `:hours`. Reset rates in
    `:per_second` or `:per_minute` are converted to reset time.
  - `derivative_constant` is the derivative time in any of those time units.
  - An absent or zero constant disables its own term. With P disabled, the shared
    gain is 1.0 so I and D can still operate. Both signs of zero disable a term.
    Enabled constants must be positive. Other unit interpretations require an
    external controller.
  - `action: :direct` uses setpoint minus measurement, suitable for heating.
    `:reverse` uses measurement minus setpoint, suitable for cooling.
  - `bias` defaults to zero.
  - `min_output` and `max_output` bound the automatic output in `output_units`.
    Supply them in the properties map passed to `create/4`. On an existing Loop,
    use `update_property/3` to change a bound that is present or `add_property/3`
    to add an omitted bound. Each omitted bound independently uses the
    corresponding finite BACnet REAL limit, approximately -3.402823466e38 or
    +3.402823466e38. These are local control defaults. They do not describe the
    actuator's physical range.

  The controller's derivative source defaults to measurement. Set the creation
  option `pid_derivative_on: :error` to include setpoint changes. The first sample
  skips I and D. Configuration changes are applied at the next due sample with
  the bumpless transfer defined by `HvacPid.Controller.configure/2`. The controller
  also provides saturation anti-windup.

  Set the local `pid_deadzone:` creation option or call `set_pid_deadzone/2` to
  configure a hold radius in `controlled_variable_units`. A positive radius holds
  the previous output and freezes the integral when the absolute error is at or
  below that radius. Zero is the default and disables the hold. Loop's BACnet
  `deadband` serves intrinsic event reporting (ASHRAE 135-2016, 12.17.33).

  ### Timing, overrides and restart

  `update_interval` sets the output cadence in milliseconds. An absent property
  selects a local default of 1000 ms. Built-in control requires a positive interval.
  With a referenced input, each due call takes one current sample and requests the
  next deadline one interval after the supplied monotonic time. Late calls do not
  replay missed samples.
  Early calls, including computed reads, preserve the current values and deadline.
  Changing the interval reschedules from the last attempt. Elapsed time between
  successful samples is converted to fractional seconds, so 1 ms is 0.001 seconds.
  Wall-clock changes do not move the monotonic schedule.

  The host can report an effective actuator output through
  `context.options[:loop_effective_output]` on a due execution. This reanchors the
  next output, for example after a higher-priority override or a pause. Supply it
  when a new transfer is needed. Supplying it on every sample reanchors every
  sample and prevents ordinary I and D progression. After a VM restart initialize
  again with fresh state and clocks. PID history and monotonic timestamps are
  runtime state, separate from the BACnet properties.

  ### Out of service and failures

  Setting `out_of_service` places an enabled controller in manual mode and stops
  sampling. The controller's manual command follows the finite `present_value`,
  including values outside the automatic output limits. With an initialized
  manipulated reference, a committed Present_Value write requests an immediate
  actuator continuation, including same-value writes. The host needs to deliver
  each committed write before the next operation. An uninitialized manipulated
  reference leaves the simulated write local.

  BACnet simulation can also publish and forward non-finite REAL values. The
  controller holds a finite manual command during that simulation. Returning to
  service restores the automatic limits and reanchors to a finite simulated
  output on a fresh sample. After a non-finite simulated output, automatic control
  starts with fresh PID history.

  Preflight rejects invalid control configuration or missing callbacks before I/O.
  Operational failures return a successful result with `state.last_error` retained
  for diagnostics. Failed acquisition leaves the published sample and output intact.
  A failed write retains the computed output and advanced PID state. It is attempted
  once for that continuation. The next scheduled sample can attempt a new command.
  Recovery reanchors from the retained output without integrating across the gap.

  When selected and evaluation is enabled, `reliability` becomes `:configuration_error`
  for invalid samples and reference/access failures, `:communication_failure` for
  other read/write failures, or `:process_error` for numeric controller failures.
  A successful automatic output write or local PID calculation clears that algorithm fault.
  Simulation and `reliability_evaluation_inhibit` preserve the selected Reliability value.

  ### Application-supplied readings

  Leave `controlled_variable_reference` uninitialized to supply the measurement from
  an application or device driver. Use `update_property/3` to build a candidate with
  a finite `controlled_variable_value` in `controlled_variable_units`. Pass it through
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3` with the trigger
  `{:application_write, :controlled_variable_value, nil, nil}`, then commit and execute
  the prepared candidate. The property is read-only over BACnet. Built-in control
  accepts these readings while in service.

  The application supplies each fresh reading, including repeated values. An early
  reading updates the published measurement and preserves the previous output.
  The first reading and subsequent readings at or after `update_interval` run PID.
  This mode requests no sampling wakeup. A referenced setpoint still requires the
  read callback. With a configured manipulated target, retain and deliver any
  immediate write continuation in the usual way.

      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> alias BACnet.Protocol.ObjectTypes.Loop
      iex> {:ok, object} = Loop.create(1202, "Local sensor", %{setpoint: 21.0, proportional_constant: 2.0, proportional_constant_units: :no_units})
      iex> context = Context.new(:initialization, now: ~U[2026-11-10 08:00:00Z], monotonic_time: 0)
      iex> {:ok, stored} = Lifecycle.execute(object, context)
      iex> sample = %{context | trigger: {:application_write, :controlled_variable_value, nil, nil}, state: stored.state}
      iex> {:ok, candidate} = Loop.update_property(stored.object, :controlled_variable_value, 19.0)
      iex> {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, sample)
      iex> {:ok, stored} = Lifecycle.execute(prepared, sample)
      iex> {stored.object.controlled_variable_value, stored.object.present_value, stored.next_execution}
      {19.0, 4.0, nil}

  ### External controller

  Set `pid_enabled: false` in `create/4` to use the object as the BACnet representation
  of an application-owned controller. The option is retained in metadata. Execution
  preserves the object and supplied state and requests no wakeup or I/O. The application
  needs to own sampling, control, actuator writes and simulation propagation, and publish
  values through local updates. BACnet Present_Value writes still require out of service.

      iex> alias BACnet.Protocol.ObjectTypes.Loop
      iex> {:ok, object} = Loop.create(1200, "External PID", %{}, pid_enabled: false)
      iex> {:ok, object} = Loop.update_property(object, :controlled_variable_value, 20.0)
      iex> {:ok, object} = Loop.update_property(object, :setpoint, 21.0)
      iex> {:ok, object} = Loop.update_property(object, :present_value, 35.0)
      iex> object.present_value
      35.0

  ### Switching built-in control at runtime

  Use `set_pid_enabled/3` to enable or disable built-in control on a local Loop.
  The option lives in object metadata, independently of `out_of_service`. Pass the
  retained runtime state and fresh clocks. Retain the returned result and apply its
  wakeup or continuation using the normal lifecycle ordering.

  Disabling publishes the stop command and stops sampling. With an initialized
  manipulated reference, provide a write callback and deliver the immediate
  continuation for the stop command. After the stop, the application can publish
  externally controlled values as described above. Enabling in service starts
  automatic control with fresh history. A Loop with an application-supplied input
  waits for its next reading. Enabling out of service selects manual mode using
  the simulated output.

  Set `pid_start_value` and `pid_stop_value` at creation, or use
  `set_pid_start_value/2` and `set_pid_stop_value/2` to update them for the next
  startup or stop. Values are in `output_units` and are clamped to the automatic
  limits. Without a start value the first valid sample uses bias plus the
  proportional term. Without a stop value the command uses `min_output`, or zero
  within the limits when `min_output` is absent.

      iex> alias BACnet.Protocol.ObjectExecution.Context
      iex> alias BACnet.Protocol.ObjectTypes.Loop
      iex> {:ok, object} = Loop.create(1203, "Runtime PID", %{present_value: 35.0})
      iex> {:ok, object} = Loop.set_pid_stop_value(object, 10.0)
      iex> context = Context.new(:periodic, now: ~U[2026-11-10 08:00:00Z], monotonic_time: 0)
      iex> {:ok, disabled} = Loop.set_pid_enabled(object, false, context)
      iex> {Loop.pid_enabled?(disabled.object), disabled.object.present_value, disabled.next_execution}
      {false, 10.0, nil}
      iex> {:ok, enabled} = Loop.set_pid_enabled(disabled.object, true, %{context | state: disabled.state})
      iex> {Loop.pid_enabled?(enabled.object), enabled.object.out_of_service}
      {true, false}

  ### Driving built-in control

  This finite example retains the result between the calculation and actuator write.
  Its write callback accepts the command. An application's callback needs to apply it
  and retain the target update.

      iex> alias BACnet.Protocol.{ObjectIdentifier, ObjectPropertyRef}
      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> alias BACnet.Protocol.ObjectTypes.Loop
      iex> input = %ObjectPropertyRef{object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1}, property_identifier: :present_value, property_array_index: nil}
      iex> output = %{input | object_identifier: %ObjectIdentifier{type: :analog_output, instance: 2}}
      iex> {:ok, object} = Loop.create(1201, "Heating", %{controlled_variable_reference: input, manipulated_variable_reference: output, setpoint: 21.0, proportional_constant: 2.0, proportional_constant_units: :no_units, min_output: 0.0, max_output: 100.0})
      iex> context = Context.new(:initialization, now: ~U[2026-11-10 08:00:00Z], monotonic_time: 0, read_property: fn _reference -> {:ok, 19.0} end, write_property: fn _reference, _value, _priority -> :ok end)
      iex> {:ok, stored} = Lifecycle.execute(object, context)
      iex> {stored.object.present_value, stored.next_execution}
      {4.0, :immediate}
      iex> {:ok, stored} = Lifecycle.execute(stored.object, %{context | trigger: :continuation, state: stored.state})
      iex> {stored.next_execution.wall_time, stored.next_execution.monotonic_time}
      {nil, 1000}

  ### Intrinsic Reporting

  With `intrinsic_reporting: true`, execution evaluates FLOATING_LIMIT
  using Controlled_Variable_Value, Setpoint, Error_Limit and Deadband.
  Reporting also works when the host supplies the values and disables the
  built-in PID. After retaining the result, the host retrieves transitions with
  `BACnet.Protocol.ObjectExecution.EventReporting.transition/1`.

  ### See Also

  - `BACnet.Protocol.EventAlgorithms.FloatingLimit`
  - `BACnet.Protocol.ObjectExecution.Lifecycle`
  - `HvacPid.Controller`
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.EventAlgorithms
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.IntrinsicReporting
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectPropertyRef
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.SetpointReference
  alias HvacPid.Controller

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Loop object.
  """
  @type object_opts ::
          common_object_opts()
          | {:pid_enabled, boolean()}
          | {:pid_derivative_on, :measurement | :error}
          | {:pid_start_value | :pid_stop_value, number() | nil}
          | {:pid_deadzone, number()}

  @typedoc """
  Represents a Loop object. Treat struct fields as read-only. Use the object module's
  property functions to build updates.
  """
  bac_object Constants.macro_assert_name(:object_type, :loop) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:event_state, Constants.event_state(), required: true)
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean(), required: true)

    field(:present_value, ApplicationTags.ieee_float(),
      required: true,
      readonly: true,
      default: 0.0
    )

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

    field(:controlled_variable_value, float(), required: true, readonly: true, default: 0.0)

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

  @max_real 3.402_823_466_385_288_6e38
  @uninitialized_instance Constants.macro_by_name(:asn1, :max_instance_and_property_id)
  @time_units %{
    milliseconds: 0.001,
    hundredths_seconds: 0.01,
    seconds: 1.0,
    minutes: 60.0,
    hours: 3600.0
  }
  @numeric_properties [
    :setpoint,
    :bias,
    :proportional_constant,
    :integral_constant,
    :derivative_constant
  ]
  @typep pending_write :: %{
           reference: DeviceObjectPropertyRef.t(),
           value: ApplicationTags.ieee_float(),
           priority: 1..16
         }
  @typep execution_state :: %{
           optional(:stopping_pid) => true,
           identifier: ObjectIdentifier.t(),
           controller: Controller.t() | nil,
           last_sample: integer() | nil,
           last_attempt: integer() | nil,
           next_sample: integer() | nil,
           interval: pos_integer(),
           out_of_service: boolean(),
           references: {controlled :: ObjectPropertyRef.t(), setpoint :: SetpointReference.t()},
           pending_write: pending_write() | nil,
           last_error: term()
         }

  @doc """
  Reports BACnet write access. Present_Value is writable while out of service.

  Local application updates use `update_property/3` and lifecycle preparation.
  External-controller mode permits local publication of computed values in service.
  """
  @spec property_writable?(t(), property_name()) :: boolean()
  def property_writable?(object, property)
  def property_writable?(%__MODULE__{} = object, :present_value), do: object.out_of_service
  def property_writable?(%__MODULE__{} = object, property), do: super(object, property)

  @doc """
  Validates PID settings, retained state and required host operations without I/O.

  Remote snapshots and local objects with `pid_enabled: false` are passive after
  any pending stop command completes.
  Built-in control requires callbacks for initialized references that it uses.
  Out-of-service simulation requires a write callback when propagating a Present_Value write
  to an initialized target.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec validate_execution(t(), Context.t()) :: :ok | {:error, term()}
  def validate_execution(object, context)

  def validate_execution(%__MODULE__{_metadata: %{remote_object: remote}}, %Context{})
      when not is_nil(remote), do: :ok

  def validate_execution(%__MODULE__{} = object, %Context{} = context) do
    with :ok <- validate_options(object) do
      cond do
        pid_enabled?(object) ->
          with :ok <- validate_state(object, context),
               :ok <- validate_configuration(object),
               :ok <- validate_application_sample(object, context) do
            Context.require_operations(context, required_operations(object, context))
          end

        stopping_pid?(context) ->
          with :ok <- validate_state(object, context) do
            operations = if context.trigger == :continuation, do: [:write_property], else: []
            Context.require_operations(context, operations)
          end

        true ->
          :ok
      end
    end
  end

  @doc """
  Checks a proposed BACnet or local write before commit, without executing control.

  BACnet writes to Present_Value require out of service. In built-in mode,
  an in-service application can supply Controlled_Variable_Value when its reference
  is uninitialized. In external mode, application writes can publish the external
  controller's values while in service.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec prepare_write(t(), t(), Context.t()) :: {:ok, t()} | {:error, term()}
  def prepare_write(original, candidate, context)

  def prepare_write(%__MODULE__{_metadata: %{remote_object: remote}}, _candidate, %Context{})
      when not is_nil(remote), do: {:error, :operation_not_available_for_remote_objects}

  def prepare_write(%__MODULE__{} = original, %__MODULE__{} = candidate, %Context{} = context) do
    with :ok <- validate_write(original, context),
         :ok <- validate_execution(candidate, context) do
      {:ok, candidate}
    end
  end

  @doc """
  Acquires one due sample and publishes the PID output, or performs its continuation.

  Retain an immediate result before executing its continuation, which writes the
  captured value to the manipulated property. Operational failures retain progress
  and error details and update a selected Reliability property unless inhibited.
  External-controller objects use their supplied values for intrinsic reporting.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec execute(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  def execute(object, context)

  def execute(%__MODULE__{_metadata: %{remote_object: remote}} = object, %Context{} = context)
      when not is_nil(remote), do: super(object, context)

  def execute(%__MODULE__{} = object, %Context{} = context) do
    with :ok <- validate_execution(object, context),
         {:ok, result} <-
           if(pid_enabled?(object) or stopping_pid?(context),
             do: execute_state(object, context, previous_state(object, context)),
             else: super(object, context)
           ) do
      {:ok, evaluate_reporting(result, context)}
    end
  end

  @spec evaluate_reporting(Result.t(t()), Context.t()) :: Result.t(t())
  defp evaluate_reporting(%Result{object: object} = result, context) do
    result =
      if object._metadata.intrinsic_reporting and is_nil(result.state),
        do: %{result | state: previous_state(object, context)},
        else: result

    IntrinsicReporting.evaluate(result, context, EventAlgorithms.FloatingLimit, [
      :present_value,
      :controlled_variable_value,
      :setpoint
    ])
  end

  @doc """
  Returns whether the Loop selects built-in PID control.

  Control runs in service when Loop reads a configured reference or receives an
  application reading.
  """
  @spec pid_enabled?(t()) :: boolean()
  def pid_enabled?(%__MODULE__{} = object),
    do: Map.get(object._metadata.other, :pid_enabled, true) == true

  @doc """
  Sets the PID command for the first valid automatic sample after startup.

  The value is in `output_units` and the controller clamps it to the automatic
  output limits. Pass `nil` to start with the calculated proportional term and
  bias. This updates local configuration for the next startup.
  """
  @spec set_pid_start_value(t(), number() | nil) :: {:ok, t()} | {:error, term()}
  def set_pid_start_value(%__MODULE__{} = object, value),
    do: set_pid_value(object, :pid_start_value, value)

  @doc """
  Sets the PID command for the next transition to disabled control.

  The value is in `output_units` and the controller clamps it to the automatic
  output limits. Pass `nil` to use `min_output` when configured, or zero within
  the output limits otherwise. This updates local configuration for the next stop.
  """
  @spec set_pid_stop_value(t(), number() | nil) :: {:ok, t()} | {:error, term()}
  def set_pid_stop_value(%__MODULE__{} = object, value),
    do: set_pid_value(object, :pid_stop_value, value)

  @doc """
  Sets the built-in PID's hold radius in `controlled_variable_units`.

  Supply a finite, nonnegative value. Zero disables the hold. The returned object
  applies the setting on the next automatic sample with its retained PID history.
  Startup and transfers establish the output before the hold takes effect.
  """
  @spec set_pid_deadzone(t(), number()) :: {:ok, t()} | {:error, term()}
  def set_pid_deadzone(%__MODULE__{} = object, value),
    do: set_pid_value(object, :pid_deadzone, value)

  @spec set_pid_value(t(), atom(), term()) :: {:ok, t()} | {:error, term()}
  defp set_pid_value(object, property, value)

  defp set_pid_value(%__MODULE__{_metadata: %{remote_object: remote}}, _property, _value)
       when not is_nil(remote), do: {:error, :operation_not_available_for_remote_objects}

  defp set_pid_value(object, property, value) do
    if valid_pid_value?(property, value),
      do: {:ok, put_in(object._metadata.other[property], value)},
      else: {:error, {:invalid_configuration, property}}
  end

  @spec valid_pid_value?(atom(), term()) :: boolean()
  defp valid_pid_value?(property, value)

  defp valid_pid_value?(:pid_deadzone, value), do: real?(value) and value >= 0
  defp valid_pid_value?(_property, value), do: is_nil(value) or real?(value)

  @doc """
  Switches built-in PID control for a local Loop and returns its lifecycle result.

  Supply the retained runtime state, fresh clocks and host callbacks in the context.
  Retain the returned result before delivering a continuation or scheduling a wakeup.
  A mode change with an immediate actuator write pending returns `{:error, :busy}`.

  Disabling publishes the controller's stop command, cancels sampling and queues
  an actuator write when a target is configured. Enabling in service starts the
  controller in automatic mode with fresh history. Enabling out of service
  selects manual mode with the simulated output. Reapplying the same setting
  preserves the current execution request.
  """
  @spec set_pid_enabled(t(), boolean(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  def set_pid_enabled(object, enabled, context)

  def set_pid_enabled(%__MODULE__{_metadata: %{remote_object: remote}}, _enabled, %Context{})
      when not is_nil(remote), do: {:error, :operation_not_available_for_remote_objects}

  def set_pid_enabled(%__MODULE__{} = object, enabled, %Context{} = context)
      when is_boolean(enabled) do
    context = %{context | trigger: :periodic}

    with :ok <- validate_options(object) do
      if not pid_enabled?(object) and not enabled do
        execute(object, context)
      else
        with {:ok, result} <- change_pid_mode(object, context, pid_enabled?(object), enabled) do
          {:ok, evaluate_reporting(result, context)}
        end
      end
    end
  end

  @spec change_pid_mode(t(), Context.t(), boolean(), boolean()) ::
          {:ok, Result.t(t())} | {:error, term()}
  defp change_pid_mode(object, context, current, enabled)

  defp change_pid_mode(object, context, true, true) do
    with :ok <- validate_state(object, context) do
      result(object, previous_state(object, context))
    end
  end

  defp change_pid_mode(object, context, true, false), do: disable_pid(object, context)
  defp change_pid_mode(object, context, false, true), do: enable_pid(object, context)

  @spec enable_pid(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  defp enable_pid(object, context) do
    if stopping_pid?(context) do
      {:error, :busy}
    else
      object = put_in(object._metadata.other[:pid_enabled], true)
      context = %{context | state: nil}
      state = previous_state(object, context)

      with :ok <- validate_execution(object, context) do
        if object.out_of_service do
          execute_state(object, context, state)
        else
          with {:ok, controller} <- prepare_controller(object, context, state) do
            execute_state(object, context, %{state | controller: controller})
          end
        end
      end
    end
  end

  @spec disable_pid(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  defp disable_pid(object, context) do
    with :ok <- validate_state(object, context) do
      case previous_state(object, context) do
        %{pending_write: nil} = state ->
          stop_controller(object, context, state)

        _pending ->
          {:error, :busy}
      end
    end
  end

  @spec stop_controller(t(), Context.t(), execution_state()) ::
          {:ok, Result.t(t())} | {:error, term()}
  defp stop_controller(object, context, state) do
    target = object.manipulated_variable_reference
    operations = if uninitialized_reference?(target), do: [], else: [:write_property]

    with :ok <- validate_reference(target, :manipulated_variable_reference),
         :ok <- Context.require_operations(context, operations),
         {:ok, options} <- output_options(object),
         {:ok, controller} <- configure_controller(state.controller, options),
         {:ok, controller} <- Controller.set_mode(controller, :disabled),
         {:ok, object} <- update_property(object, :present_value, Controller.output(controller)) do
      object = put_in(object._metadata.other[:pid_enabled], false)

      state = %{
        state
        | controller: controller,
          last_sample: nil,
          last_attempt: nil,
          next_sample: nil,
          last_error: nil
      }

      if uninitialized_reference?(target),
        do: result(object, state),
        else: plan_write(object, Map.put(state, :stopping_pid, true))
    end
  end

  @spec stopping_pid?(Context.t()) :: boolean()
  defp stopping_pid?(context)

  defp stopping_pid?(%Context{trigger: trigger, state: %{stopping_pid: true, pending_write: %{}}})
       when trigger != :initialization, do: true

  defp stopping_pid?(%Context{}), do: false

  @spec validate_options(t()) :: :ok | {:error, term()}
  defp validate_options(object) do
    if is_boolean(Map.get(object._metadata.other, :pid_enabled, true)),
      do: :ok,
      else: {:error, {:invalid_configuration, :pid_enabled}}
  end

  @spec validate_configuration(t()) :: :ok | {:error, term()}
  defp validate_configuration(object) do
    if object.out_of_service do
      validate_reference(object.manipulated_variable_reference, :manipulated_variable_reference)
    else
      with :ok <-
             validate_reference(
               object.controlled_variable_reference,
               :controlled_variable_reference
             ),
           :ok <-
             validate_reference(
               object.manipulated_variable_reference,
               :manipulated_variable_reference
             ),
           :ok <- validate_sampling(object),
           {:ok, options} <- controller_options(object),
           {:ok, _controller} <- Controller.new(options) do
        :ok
      else
        {:error, :invalid_output_limits} ->
          {:error, {:invalid_configuration, :output_limits}}

        {:error, {:invalid_option, :derivative_on}} ->
          {:error, {:invalid_configuration, :pid_derivative_on}}

        {:error, _reason} = error ->
          error
      end
    end
  end

  @spec validate_sampling(t()) :: :ok | {:error, term()}
  defp validate_sampling(object) do
    cond do
      not SetpointReference.valid?(object.setpoint_reference) ->
        {:error, {:invalid_configuration, :setpoint_reference}}

      interval(object) == 0 ->
        {:error, {:invalid_configuration, :update_interval}}

      true ->
        :ok
    end
  end

  @spec validate_reference(term(), atom()) :: :ok | {:error, term()}
  defp validate_reference(reference, property) do
    if is_struct(reference, ObjectPropertyRef) and ObjectPropertyRef.valid?(reference),
      do: :ok,
      else: {:error, {:invalid_configuration, property}}
  end

  @spec uninitialized_reference?(ObjectPropertyRef.t() | DeviceObjectPropertyRef.t() | nil) ::
          boolean()
  defp uninitialized_reference?(reference)

  defp uninitialized_reference?(%{
         object_identifier: %ObjectIdentifier{instance: @uninitialized_instance}
       }),
       do: true

  defp uninitialized_reference?(_reference), do: false

  @spec controller_options(t()) :: {:ok, keyword()} | {:error, term()}
  defp controller_options(object) do
    deadzone = Map.get(object._metadata.other, :pid_deadzone, 0.0)

    invalid =
      Enum.find(@numeric_properties, fn property ->
        value = Map.fetch!(object, property)

        not is_nil(value) and
          (not real?(value) or
             (property in [:proportional_constant, :integral_constant, :derivative_constant] and
                value < 0))
      end)

    with nil <- invalid,
         true <- valid_pid_value?(:pid_deadzone, deadzone),
         {:ok, outputs} <- output_options(object),
         :ok <- proportional_units(object),
         {:ok, tn} <-
           time_constant(
             :integral_constant,
             object.integral_constant,
             object.integral_constant_units
           ),
         {:ok, td} <-
           time_constant(
             :derivative_constant,
             object.derivative_constant,
             object.derivative_constant_units
           ) do
      enabled = not is_nil(object.proportional_constant) and object.proportional_constant != 0.0

      {:ok,
       outputs ++
         [
           bias: object.bias || 0.0,
           deadzone: deadzone,
           kp: if(enabled, do: object.proportional_constant, else: 1.0),
           p_enabled: enabled,
           tn: tn,
           td: td,
           direction: object.action,
           derivative_on: Map.get(object._metadata.other, :pid_derivative_on, :measurement)
         ]}
    else
      false -> {:error, {:invalid_configuration, :pid_deadzone}}
      property when is_atom(property) -> {:error, {:invalid_configuration, property}}
      {:error, _reason} = error -> error
    end
  rescue
    ArithmeticError -> {:error, {:invalid_configuration, :pid_constants}}
  end

  @spec output_options(t()) :: {:ok, keyword()} | {:error, term()}
  defp output_options(object) do
    start = Map.get(object._metadata.other, :pid_start_value)
    stop = Map.get(object._metadata.other, :pid_stop_value)

    values = [
      min_output: object.min_output,
      max_output: object.max_output,
      pid_start_value: start,
      pid_stop_value: stop
    ]

    case Enum.find(values, fn {_property, value} -> not is_nil(value) and not real?(value) end) do
      {property, _value} ->
        {:error, {:invalid_configuration, property}}

      nil ->
        minimum = object.min_output || -@max_real
        maximum = object.max_output || @max_real

        if minimum <= maximum do
          {:ok,
           [
             out_min: minimum,
             out_max: maximum,
             start_value: start,
             stop_value: stop || object.min_output || 0.0
           ]}
        else
          {:error, {:invalid_configuration, :output_limits}}
        end
    end
  end

  @spec configure_controller(Controller.t() | nil, keyword()) ::
          {:ok, Controller.t()} | {:error, Controller.error()}
  defp configure_controller(controller, options)
  defp configure_controller(nil, options), do: Controller.new(options)
  defp configure_controller(controller, options), do: Controller.configure(controller, options)

  @spec proportional_units(t()) :: :ok | {:error, term()}
  defp proportional_units(object) do
    if is_nil(object.proportional_constant) or object.proportional_constant == 0.0 or
         object.proportional_constant_units == :no_units,
       do: :ok,
       else: {:error, {:unsupported_capability, {:pid_units, :proportional_constant_units}}}
  end

  @spec time_constant(atom(), float() | nil, atom() | nil) ::
          {:ok, float() | nil} | {:error, term()}
  defp time_constant(property, value, units)
  defp time_constant(_property, nil, _units), do: {:ok, nil}
  defp time_constant(_property, value, _units) when value == 0.0, do: {:ok, nil}
  defp time_constant(:integral_constant, value, :per_second), do: {:ok, 1.0 / value}
  defp time_constant(:integral_constant, value, :per_minute), do: {:ok, 60.0 / value}

  defp time_constant(property, value, units) do
    case Map.fetch(@time_units, units) do
      {:ok, scale} -> {:ok, value * scale}
      :error -> {:error, {:unsupported_capability, {:pid_units, property}}}
    end
  end

  @spec real?(term()) :: boolean()
  defp real?(value), do: is_number(value) and abs(value) <= @max_real

  @spec interval(t()) :: non_neg_integer()
  defp interval(object), do: object.update_interval || 1000

  @spec required_operations(t(), Context.t()) :: [atom()]
  defp required_operations(object, context)

  defp required_operations(_object, %Context{
         trigger: :continuation,
         state: %{pending_write: write}
       })
       when not is_nil(write), do: [:write_property]

  defp required_operations(object, context) do
    write =
      if uninitialized_reference?(object.manipulated_variable_reference),
        do: [],
        else: [:write_property]

    cond do
      object.out_of_service ->
        if simulation_write?(object, context), do: [:write_property], else: []

      application_sample?(context) ->
        if is_nil(configured_setpoint_reference(object)),
          do: write,
          else: [:read_property | write]

      uninitialized_reference?(object.controlled_variable_reference) ->
        []

      true ->
        [:read_property | write]
    end
  end

  @spec application_sample?(Context.t()) :: boolean()
  defp application_sample?(context) do
    match?({:application_write, _property, _index, _priority}, context.trigger) and
      Context.written_property(context) == :controlled_variable_value
  end

  @spec validate_application_sample(t(), Context.t()) :: :ok | {:error, term()}
  defp validate_application_sample(object, context) do
    cond do
      not application_sample?(context) ->
        :ok

      object.out_of_service or not uninitialized_reference?(object.controlled_variable_reference) ->
        {:error, :write_access_denied}

      not real?(object.controlled_variable_value) ->
        {:error, {:property_out_of_range, :controlled_variable_value}}

      true ->
        :ok
    end
  end

  @spec simulation_write?(t(), Context.t()) :: boolean()
  defp simulation_write?(object, context) do
    Context.written_property(context) == :present_value and
      not uninitialized_reference?(object.manipulated_variable_reference)
  end

  @spec validate_state(t(), Context.t()) :: :ok | {:error, :invalid_execution_state}
  defp validate_state(object, context)
  defp validate_state(_object, %Context{trigger: :initialization}), do: :ok
  defp validate_state(_object, %Context{state: nil}), do: :ok

  defp validate_state(object, %Context{state: state, monotonic_time: now}) do
    valid =
      case state do
        %{
          identifier: identifier,
          controller: controller,
          last_sample: sampled,
          last_attempt: attempted,
          next_sample: next,
          interval: period,
          out_of_service: oos,
          references: {%ObjectPropertyRef{}, %SetpointReference{}},
          pending_write: pending,
          last_error: _error
        } ->
          identifier == get_object_identifier(object) and
            (is_nil(controller) or is_struct(controller, Controller)) and
            (is_nil(sampled) or (is_integer(sampled) and sampled <= now)) and
            (is_nil(attempted) or (is_integer(attempted) and attempted <= now)) and
            (is_nil(next) or is_integer(next)) and is_integer(period) and period > 0 and
            is_boolean(oos) and valid_pending_write?(pending)

        _other ->
          false
      end

    if valid, do: :ok, else: {:error, :invalid_execution_state}
  end

  @spec valid_pending_write?(term()) :: boolean()
  defp valid_pending_write?(pending)
  defp valid_pending_write?(nil), do: true

  defp valid_pending_write?(%{
         reference: %DeviceObjectPropertyRef{} = reference,
         value: value,
         priority: priority
       }),
       do:
         DeviceObjectPropertyRef.valid?(reference) and not uninitialized_reference?(reference) and
           priority in 1..16 and (is_float(value) or value in [:inf, :infn, :NaN])

  defp valid_pending_write?(_pending), do: false

  @spec validate_write(t(), Context.t()) :: :ok | {:error, :write_access_denied}
  defp validate_write(object, context) do
    property = Context.written_property(context)
    application = match?({:application_write, _property, _index, _priority}, context.trigger)

    cond do
      application and not pid_enabled?(object) -> :ok
      application_sample?(context) -> :ok
      property == :present_value and not object.out_of_service -> {:error, :write_access_denied}
      property in [:status_flags, :controlled_variable_value] -> {:error, :write_access_denied}
      true -> :ok
    end
  end

  @spec previous_state(t(), Context.t()) :: execution_state()
  defp previous_state(object, context)

  defp previous_state(object, %Context{trigger: trigger, state: state})
       when trigger == :initialization or is_nil(state) do
    %{
      identifier: get_object_identifier(object),
      controller: nil,
      last_sample: nil,
      last_attempt: nil,
      next_sample: nil,
      interval: max(1, interval(object)),
      out_of_service: object.out_of_service,
      references: {object.controlled_variable_reference, object.setpoint_reference},
      pending_write: nil,
      last_error: nil
    }
  end

  defp previous_state(_object, %Context{state: state}), do: state

  @spec execute_state(t(), Context.t(), execution_state()) ::
          {:ok, Result.t(t())} | {:error, term()}
  defp execute_state(object, context, state)

  defp execute_state(
         object,
         %Context{trigger: :continuation} = context,
         %{pending_write: pending} = state
       )
       when not is_nil(pending) do
    outcome = Context.write_property(context, pending.reference, pending.value, pending.priority)
    stopping = stopping_pid?(context)
    state = %{Map.delete(state, :stopping_pid) | pending_write: nil}

    case outcome do
      :ok when stopping -> result(object, state)
      :ok -> finish(object, %{state | last_error: nil}, :no_fault_detected)
      {:error, reason} -> fail(object, state, {:write, pending.reference, reason})
    end
  end

  defp execute_state(object, _context, %{pending_write: pending} = state)
       when not is_nil(pending),
       do: result(object, state)

  defp execute_state(object, %Context{trigger: :continuation}, state), do: result(object, state)

  defp execute_state(%__MODULE__{out_of_service: true} = object, context, state) do
    with {:ok, controller} <- manual_controller(object, state) do
      state = %{state | controller: controller, out_of_service: true, next_sample: nil}

      if simulation_write?(object, context),
        do: plan_write(object, state),
        else: result(object, state)
    end
  end

  defp execute_state(object, context, %{out_of_service: true} = state) do
    with {:ok, controller} <- prepare_controller(object, context, state) do
      state = %{state | controller: controller, out_of_service: false, last_sample: nil}
      execute_state(object, context, state)
    end
  end

  defp execute_state(
         %__MODULE__{
           controlled_variable_reference: %ObjectPropertyRef{
             object_identifier: %ObjectIdentifier{instance: @uninitialized_instance}
           }
         } = object,
         context,
         state
       ) do
    {previous_source, previous_setpoint} = state.references

    state =
      if uninitialized_reference?(previous_source) do
        state
      else
        %{
          state
          | next_sample: nil,
            references: {object.controlled_variable_reference, previous_setpoint}
        }
      end

    if application_sample?(context),
      do: sample_if_due(object, context, state),
      else: result(object, state)
  end

  defp execute_state(object, context, state), do: sample_if_due(object, context, state)

  @spec sample_if_due(t(), Context.t(), execution_state()) ::
          {:ok, Result.t(t())} | {:error, term()}
  defp sample_if_due(object, context, state) do
    deadline =
      if is_integer(state.next_sample) and state.interval != interval(object) and
           is_integer(state.last_attempt),
         do: state.last_attempt + interval(object),
         else: state.next_sample

    if is_nil(deadline) or context.monotonic_time >= deadline do
      sample(object, context, state)
    else
      result(object, %{state | interval: interval(object), next_sample: deadline})
    end
  end

  @spec sample(t(), Context.t(), execution_state()) :: {:ok, Result.t(t())} | {:error, term()}
  defp sample(object, context, state) do
    attempt = %{
      state
      | last_attempt: context.monotonic_time,
        next_sample: context.monotonic_time + interval(object),
        interval: interval(object)
    }

    with {:ok, measurement} <- read_measurement(object, context),
         {:ok, setpoint} <- read_setpoint(object, context),
         {:ok, controller} <- prepare_controller(object, context, state),
         {:ok, output, controller} <-
           Controller.step(controller, setpoint, measurement, elapsed(attempt, context)),
         {:ok, updated} <- update_property(object, :controlled_variable_value, measurement),
         {:ok, updated} <- update_property(updated, :setpoint, setpoint),
         {:ok, updated} <- update_property(updated, :present_value, output) do
      state = %{
        attempt
        | controller: controller,
          last_sample: context.monotonic_time,
          references: {object.controlled_variable_reference, object.setpoint_reference},
          out_of_service: false
      }

      if uninitialized_reference?(object.manipulated_variable_reference) do
        finish(updated, %{state | last_error: nil}, :no_fault_detected)
      else
        plan_write(updated, state)
      end
    else
      {:error, reason} -> fail(object, attempt, reason)
    end
  end

  @spec elapsed(execution_state(), Context.t()) :: float()
  defp elapsed(state, context) do
    if is_nil(state.last_sample),
      do: state.interval / 1000,
      else: max(1, context.monotonic_time - state.last_sample) / 1000
  end

  @spec prepare_controller(t(), Context.t(), execution_state()) ::
          {:ok, Controller.t()} | {:error, term()}
  defp prepare_controller(object, context, state) do
    anchor_available = is_float(object.present_value)

    previous = if state.out_of_service and not anchor_available, do: nil, else: state.controller

    with {:ok, options} <- controller_options(object),
         {:ok, controller} <- configure_controller(previous, options),
         {:ok, controller} <- Controller.set_mode(controller, :automatic) do
      output = Keyword.get(context.options, :loop_effective_output)

      reanchor =
        state.out_of_service or
          (not is_nil(state.last_sample) and
             (not is_nil(state.last_error) or is_nil(state.next_sample) or
                state.references !=
                  {object.controlled_variable_reference, object.setpoint_reference}))

      cond do
        not is_nil(output) -> Controller.track_output(controller, output)
        reanchor and anchor_available -> Controller.track_output(controller, object.present_value)
        true -> {:ok, controller}
      end
    end
  end

  @spec manual_controller(t(), execution_state()) :: {:ok, Controller.t()} | {:error, term()}
  defp manual_controller(object, state) do
    output =
      cond do
        is_float(object.present_value) -> object.present_value
        is_nil(state.controller) -> 0.0
        true -> Controller.output(state.controller)
      end

    # Simulation can publish a finite value outside the automatic output limits.
    with {:ok, controller} <-
           configure_controller(state.controller, out_min: output, out_max: output) do
      Controller.set_mode(controller, {:manual, output})
    end
  end

  @spec read_setpoint(t(), Context.t()) :: {:ok, float()} | {:error, term()}
  defp read_setpoint(object, context) do
    case configured_setpoint_reference(object) do
      nil -> {:ok, object.setpoint}
      reference -> read_value(reference, context)
    end
  end

  @spec configured_setpoint_reference(t()) :: ObjectPropertyRef.t() | nil
  defp configured_setpoint_reference(object) do
    reference = object.setpoint_reference.ref
    if uninitialized_reference?(reference), do: nil, else: reference
  end

  @spec read_measurement(t(), Context.t()) :: {:ok, float()} | {:error, term()}
  defp read_measurement(object, context) do
    if application_sample?(context),
      do: {:ok, object.controlled_variable_value},
      else: read_value(object.controlled_variable_reference, context)
  end

  @spec read_value(ObjectPropertyRef.t(), Context.t()) :: {:ok, float()} | {:error, term()}
  defp read_value(reference, context) do
    with {:ok, value} <- Context.read_property(context, device_reference(reference)),
         {:ok, number} <- numeric_value(value) do
      {:ok, number}
    else
      {:error, reason} -> {:error, {:read, reference, reason}}
    end
  end

  @spec numeric_value(term()) :: {:ok, float()} | {:error, :invalid_numeric_value}
  defp numeric_value(value)
  defp numeric_value([%Encoding{} = value]), do: numeric_value(value)

  defp numeric_value(%Encoding{encoding: :primitive, type: type, value: value})
       when type in [:real, :double, :unsigned_integer, :signed_integer, :enumerated],
       do: numeric_value(value)

  defp numeric_value(value) do
    if real?(value), do: {:ok, value / 1}, else: {:error, :invalid_numeric_value}
  end

  @spec device_reference(ObjectPropertyRef.t()) :: DeviceObjectPropertyRef.t()
  defp device_reference(reference) do
    %DeviceObjectPropertyRef{
      device_identifier: nil,
      object_identifier: reference.object_identifier,
      property_identifier: reference.property_identifier,
      property_array_index: reference.property_array_index
    }
  end

  @spec plan_write(t(), execution_state()) :: {:ok, Result.t(t())}
  defp plan_write(object, state) do
    pending = %{
      reference: device_reference(object.manipulated_variable_reference),
      value: object.present_value,
      priority: object.priority_for_writing
    }

    result(object, %{state | pending_write: pending})
  end

  @spec fail(t(), execution_state(), term()) :: {:ok, Result.t(t())} | {:error, term()}
  defp fail(object, state, reason),
    do: finish(object, %{state | last_error: reason}, failure_reliability(reason))

  @spec failure_reliability(term()) :: Constants.reliability()
  defp failure_reliability(reason)

  defp failure_reliability({operation, _reference, reason}) when operation in [:read, :write] do
    error =
      case reason do
        {error, _details} -> error
        error -> error
      end

    if error in [
         :unknown_object,
         :unknown_property,
         :unsupported_reference,
         :cyclic_execution,
         :invalid_array_index,
         :invalid_numeric_value,
         :write_access_denied
       ], do: :configuration_error, else: :communication_failure
  end

  defp failure_reliability(_reason), do: :process_error

  @spec finish(t(), execution_state(), Constants.reliability()) ::
          {:ok, Result.t(t())} | {:error, term()}
  defp finish(object, state, reliability) do
    if has_property?(object, :reliability) and not object.out_of_service and
         object.reliability_evaluation_inhibit != true do
      with {:ok, updated} <- update_property(object, :reliability, reliability),
           do: result(updated, state)
    else
      result(object, state)
    end
  end

  @spec result(t(), execution_state()) :: {:ok, Result.t(t())}
  defp result(object, state) do
    next =
      cond do
        not is_nil(state.pending_write) ->
          :immediate

        is_integer(state.next_sample) and
            not uninitialized_reference?(object.controlled_variable_reference) ->
          %Wakeup{wall_time: nil, monotonic_time: state.next_sample}

        true ->
          nil
      end

    {:ok, %Result{object: object, state: state, next_execution: next}}
  end
end
