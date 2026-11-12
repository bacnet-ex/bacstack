defmodule BACnet.Protocol.ObjectTypes.AnalogOutput do
  @moduledoc """
  An Analog Output holds the command for an actuator such as a valve, damper or
  variable-speed drive. Its `present_value` is the highest-priority active
  command. When all 16 slots in the `priority_array` are empty, it uses
  `relinquish_default`.

  The object carries a COV threshold (`cov_increment`) and can be placed out of service.
  `intrinsic_reporting: true` selects OUT_OF_RANGE reporting properties, including
  `high_limit`, `low_limit` and `deadband`. Core lifecycle execution maintains the command
  and supplied reliability - event detection and notification delivery remain separate.
  Typical companion properties are `units`, `min_present_value`, `max_present_value`,
  `resolution` and `device_type`.

  ### Object Description (ASHRAE 135)

  > The Analog Output object type defines a standardized object whose properties represent
  > the externally visible characteristics of an analog output.
  >
  > Analog Output objects that support intrinsic reporting shall apply the OUT_OF_RANGE
  > event algorithm.

  ### Behaviour and Operation

  Analog Output is always commandable. Its required `priority_array` and
  `relinquish_default` determine the effective `present_value` in engineering units.
  The lowest numbered non-nil priority slot wins. Lower-priority commands remain stored
  while masked. A nil command relinquishes only its slot, revealing the next command or
  the relinquish default when all slots are nil. Both BACnet commands and local software
  commands follow this mechanism, including while out of service.

  Use `set_priority/3` to construct a Present_Value write candidate. A BACnet write
  without an explicit priority means 16 - the host needs to supply that default to the
  setter. The array is read-only to BACnet clients. Internal configuration can use the
  property operations to update the array or relinquish default. Direct Present_Value
  updates must not bypass arbitration, including during simulation. Existing property
  operations keep Present_Value synchronized after priority/default changes.

  Priority 6 is reserved for minimum on/off control and is unavailable for commands or
  relinquishment through `set_priority/3`. Analog Output has no minimum on/off timing.
  Lifecycle preflight rejects a stored non-nil slot 6 with
  `{:error, {:invalid_configuration, :priority_6}}`.

  ### Lifecycle and host contract

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  is the integrating application or higher-level BACnet stack that retains objects and
  runtime state, serializes operations and supplies their context. The host's physical
  adapter applies commands to the output channel and reports hardware reliability.
  This module starts no process and invokes no hardware or host I/O callback.

  Initialize with `BACnet.Protocol.ObjectExecution.Lifecycle.execute/2` and an
  `:initialization` context. Retain the full returned result. For every write, construct
  a candidate through this module's property operations, call
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3`, commit the prepared object
  and execute with the same context and previous runtime state before exposing another
  operation. Only then may the host pass the retained command to an in-service adapter.
  Raw property setters do not run lifecycle origin checks or execution. Deliver every
  accepted write, including same-value writes.

  The host still needs to enforce service permissions, read-only annotations, array
  indices and BACnet priority rules. Preparation is pure. A rejected write leaves the
  original object, runtime state and wakeup unchanged. Missing, malformed or other-instance
  state returns `{:error, :invalid_execution_state}`. Initialize local instances before
  other operations. Initialization seeds state from supplied properties - it performs
  no hardware write or status acquisition.

  ### Physical output and out-of-service simulation

  While in service, the host needs to apply the retained effective command through its
  driver. `get_output/2` selects that command without performing I/O or measuring the
  actuator. Scaling, calibration, hardware limits and the driver implementation are
  local matters. The `device_type` property can describe the attached channel or actuator.
  Commanded output does not establish that the physical output reached that value.

  While `out_of_service` is true, Present_Value changes are decoupled from the physical
  output. The host needs to implement that isolation. Its physical policy may hold the
  last output, select a configured fallback or follow other local logic.
  `get_output/2` returns its caller-supplied fallback while out of service - the default
  is `0.0`. That fallback is an API default, not a measured output or a prescribed
  physical policy. Returning to service requires the host to apply the current retained
  command, including commands accepted during simulation.

  Logical commands from both origins continue to arbitrate while out of service.
  Use `{:property_write, property, array_index, priority}` for BACnet requests and
  `{:application_write, property, array_index, priority}` for local application updates.
  A local adapter handling a BACnet request needs to preserve the BACnet origin.
  In-service hardware Reliability reports can use application-write triggers with
  `:reliability`. Explicit Reliability writes from either origin can simulate conditions
  while out of service, including same-value writes. The host needs to stop forwarding
  automatic hardware Reliability reports while decoupled - write origin alone does not
  distinguish an automatic report from intentional simulation.

  ### Reliability, inhibition and status flags

  The host supplies physical `reliability`, such as `:no_output` or
  `:communication_failure`, from its adapter's diagnosis. The lifecycle does not infer
  hardware failure from a rejected write, a range error or an invalid runtime state.
  No feedback value is copied from a command. Physical observations belong to the host -
  later Interface_Value, Current_Command_Priority and value-source properties remain
  outside this module's current declared property set.

  In-service Reliability reports are retained separately from out-of-service simulation.
  When returning to service, a retained physical report replaces simulated Reliability.
  If initialization began out of service and no physical report is known, the supplied
  property remains until a fresh report arrives. The host needs to supply fresh status
  when retained observations are insufficient for its application.

  When selected, `reliability_evaluation_inhibit` presents NO_FAULT_DETECTED while true,
  except for an explicitly supplied or written Reliability while out of service.
  Entering out of service alone does not expose a previously suppressed hardware report.
  Returning to service while inhibited masks simulation again. The latest retained
  physical report becomes effective when inhibition ends. Hardware reports received
  while inhibited and in service are retained for that later evaluation.

  Existing property propagation maintains FAULT from Reliability, IN_ALARM from the
  supplied Event_State and OUT_OF_SERVICE from Out_Of_Service. Removing Reliability
  clears FAULT during execution. OVERRIDDEN remains a local indication for the host to
  supply when applicable.

  ### Reads, timing and restart

  Before a read, use `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2`, retain
  its result and obtain the property through `get_property/2`. An active reporting
  delay can request a monotonic wakeup. The host replaces its previous request when
  retaining each result.

  After a restart, initialize from restored object properties with fresh context and
  runtime state. In-service supplied Reliability seeds the physical report. An initially
  out-of-service supplied Reliability seeds simulation instead. A suppressed physical
  report held only in old runtime state cannot be recovered from NO_FAULT_DETECTED -
  supply a fresh adapter report when needed. Remote snapshots remain passive, preserving
  their object and context state without callbacks or wakeups. Local write preparation
  for a remote snapshot returns `{:error, :operation_not_available_for_remote_objects}`.

  ### Configuration, intrinsic reporting and COV

  `units`, `min_present_value`, `max_present_value` and `resolution` describe the
  engineering value and usable range. When both min/max properties are present, the
  existing range validator applies to priority commands and relinquish defaults.
  The lifecycle introduces no rounding, unit conversion or automatic clamping.

  With `intrinsic_reporting: true`, execution evaluates OUT_OF_RANGE using the
  effective command and enabled limits. Reliability faults take precedence.
  Event and recovery delays use monotonic time. The host retrieves transitions with
  `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after retaining the result.
  `cov_increment` represents the COV threshold for the host's subscriptions and delivery.

  ### Complete command example

  This example supplies a command and retains the result before selecting the value
  for a physical adapter. The final getter performs no hardware operation.

      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> {:ok, object} = BACnet.Protocol.ObjectTypes.AnalogOutput.create(40, "Valve command", %{units: :percent, relinquish_default: 20.0})
      iex> start = Context.new(:initialization, now: ~U[2026-11-08 10:00:00Z], monotonic_time: 0)
      iex> {:ok, stored} = Lifecycle.execute(object, start)
      iex> write = Context.new({:property_write, :present_value, nil, 8}, now: ~U[2026-11-08 10:00:01Z], monotonic_time: 1000, state: stored.state)
      iex> {:ok, candidate} = BACnet.Protocol.ObjectTypes.AnalogOutput.set_priority(stored.object, 8, 45.0)
      iex> {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, write)
      iex> stored = %{stored | object: prepared}
      iex> {:ok, stored} = Lifecycle.execute(stored.object, write)
      iex> {BACnet.Protocol.ObjectTypes.AnalogOutput.get_output(stored.object), stored.next_execution}
      {45.0, nil}

  A runnable simulated-adapter walkthrough is
  `examples/objects_lifecycle/analog_output_lifecycle.exs`.

  ### Examples

  Creating a simple Analog Output (commandable object):

      iex> {:ok, ao} = BACnet.Protocol.ObjectTypes.AnalogOutput.create(1, "Valve Cmd", %{units: :percent}); ao.units
      :percent

  Selecting intrinsic reporting properties:

      iex> {:ok, ao} = BACnet.Protocol.ObjectTypes.AnalogOutput.create(2, "Setpoint", %{
      ...>   units: :degrees_celsius
      ...> }, intrinsic_reporting: true); is_number(ao.high_limit)
      true

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.OutOfRange`
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EventAlgorithms
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.IntrinsicReporting
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectOperations
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring an Analog Output object.

  In addition to the common options, Analog Output supports:
  - `intrinsic_reporting` - Selects the OUT_OF_RANGE properties (deadband, high_limit,
    low_limit) and enables evaluation during execution.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents an Analog Output object. Treat struct fields as read-only. Use the object module's
  property functions to build updates.

  Create the object with `intrinsic_reporting: true` to select its intrinsic
  reporting properties. The fields for those properties are `nil` when omitted.

  For a commandable instance, use `set_priority/3` to change the effective
  Present_Value.

  `get_output/2` selects the command or a caller-supplied out-of-service fallback. It does
  not acquire physical state or perform hardware I/O.
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

    # COV Reporting
    field(:cov_increment, float(), cov: true, default: 0.1)

    # Intrinsic Reporting
    field(:deadband, float(), intrinsic: true, default: 0.0)
    field(:high_limit, float(), intrinsic: true, default: 0.0)
    field(:low_limit, float(), intrinsic: true, default: 0.0)
  end

  @doc """
  Returns the commanded engineering value, or a supplied fallback while out of service.

  `decoupled_output_state` defaults to `0.0`. The host needs to choose and implement its
  physical out-of-service policy - this function performs no I/O and measures no output.
  An in-service Present_Value can use the existing BACnet REAL special values as well as floats.
  """
  @spec get_output(t(), float()) :: ApplicationTags.ieee_float()
  def get_output(%__MODULE__{} = object, decoupled_output_state \\ 0.0)
      when is_float(decoupled_output_state) do
    if object.out_of_service do
      decoupled_output_state
    else
      object.present_value
    end
  end

  @typep reliability_value :: Constants.reliability() | non_neg_integer() | nil

  @doc """
  Checks the reserved priority and retained runtime state without I/O.

  Initialize local objects before other lifecycle operations. Remote snapshots are passive.
  Reporting can use host callbacks to read a configured inhibit reference or
  resolve the Notification Class.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec validate_execution(t(), Context.t()) :: :ok | {:error, term()}
  def validate_execution(object, context)

  def validate_execution(%__MODULE__{_metadata: %{remote_object: remote}}, %Context{})
      when not is_nil(remote), do: :ok

  def validate_execution(%__MODULE__{} = object, %Context{} = context) do
    with :ok <- validate_configuration(object) do
      validate_state(object, context)
    end
  end

  @doc """
  Checks BACnet or application write candidates before commit.

  Logical commands from BACnet and local applications remain prioritized while out of
  service. Explicit Reliability simulation is accepted from both origins while out of
  service. The host needs to stop forwarding automatic hardware reports while decoupled.
  No state is changed.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec prepare_write(t(), t(), Context.t()) :: {:ok, t()} | {:error, term()}
  def prepare_write(original, candidate, context)

  def prepare_write(%__MODULE__{_metadata: %{remote_object: remote}}, _candidate, %Context{})
      when not is_nil(remote), do: {:error, :operation_not_available_for_remote_objects}

  def prepare_write(%__MODULE__{} = original, %__MODULE__{} = candidate, %Context{} = context) do
    with :ok <- validate_execution(original, context),
         :ok <- validate_configuration(candidate),
         :ok <- ObjectOperations.check_priority_write(candidate, context.trigger) do
      {:ok, candidate}
    end
  end

  @doc """
  Maintains the effective command, physical reliability and reliability inhibition.

  Retain the result before exposing the operation or accepting another write. Initialization
  establishes the baseline from supplied properties. Intrinsic reporting can
  record a transition or request a monotonic wakeup.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec execute(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  def execute(object, context)

  def execute(%__MODULE__{_metadata: %{remote_object: remote}} = object, %Context{} = context)
      when not is_nil(remote),
      do: {:ok, %Result{object: object, state: context.state, next_execution: nil}}

  def execute(%__MODULE__{} = object, %Context{} = context) do
    with :ok <- validate_execution(object, context),
         :ok <- ObjectOperations.check_priority_write(object, context.trigger),
         {:ok, updated, reliability_state} <- reconcile_reliability(object, context) do
      updated = ObjectOperations.propagate_properties(object_contract(), updated)

      state =
        Map.merge(reliability_state, %{
          identifier: get_object_identifier(updated),
          out_of_service: updated.out_of_service
        })

      result = %Result{object: updated, state: state, next_execution: nil}

      {:ok,
       IntrinsicReporting.evaluate(result, context, EventAlgorithms.OutOfRange, [:present_value])}
    end
  end

  @spec validate_configuration(t()) :: :ok | {:error, {:invalid_configuration, :priority_6}}
  defp validate_configuration(object) do
    if is_nil(object.priority_array.priority_6),
      do: :ok,
      else: {:error, {:invalid_configuration, :priority_6}}
  end

  @spec validate_state(t(), Context.t()) :: :ok | {:error, :invalid_execution_state}
  defp validate_state(object, context)

  defp validate_state(_object, %Context{trigger: :initialization}), do: :ok

  defp validate_state(object, %Context{state: state}) do
    valid =
      case state do
        %{
          identifier: %ObjectIdentifier{type: :analog_output} = identifier,
          out_of_service: out_of_service,
          physical_reliability: physical,
          manual_reliability: manual
        } ->
          identifier == get_object_identifier(object) and
            is_boolean(out_of_service) and
            ObjectOperations.valid_reliability?(object_contract(), object, physical) and
            ObjectOperations.valid_reliability?(object_contract(), object, manual)

        _other ->
          false
      end

    if valid, do: :ok, else: {:error, :invalid_execution_state}
  end

  @spec reconcile_reliability(t(), Context.t()) ::
          {:ok, t(),
           %{physical_reliability: reliability_value(), manual_reliability: reliability_value()}}
          | {:error, term()}
  defp reconcile_reliability(object, context) do
    previous = Context.previous_state(context)

    if has_property?(object, :reliability) do
      physical =
        cond do
          not object.out_of_service and
              (Context.written_property(context) == :reliability or is_nil(previous)) ->
            object.reliability

          previous ->
            previous.physical_reliability

          true ->
            nil
        end

      manual =
        cond do
          not object.out_of_service ->
            nil

          is_nil(previous) or Context.written_property(context) == :reliability ->
            object.reliability

          previous.out_of_service ->
            previous.manual_reliability

          true ->
            nil
        end

      base =
        if not object.out_of_service and not is_nil(physical),
          do: physical,
          else: object.reliability

      value =
        if object.reliability_evaluation_inhibit,
          do: manual || :no_fault_detected,
          else: base

      with {:ok, updated} <- update_property(object, :reliability, value) do
        {:ok, updated, %{physical_reliability: physical, manual_reliability: manual}}
      end
    else
      with {:ok, updated} <-
             update_property(object, :status_flags, %{object.status_flags | fault: false}) do
        {:ok, updated, %{physical_reliability: nil, manual_reliability: nil}}
      end
    end
  end
end
