defmodule BACnet.Protocol.ObjectTypes.AnalogValue do
  @moduledoc """
  An Analog Value is used for an application value such as a setpoint, tuning
  constant or intermediate calculation. Both the local application and BACnet
  clients can write `present_value`, subject to the object's commandability
  and write rules.

  The object is frequently made commandable via a priority array so that multiple
  sources (operators, schedules, control loops, etc.) can compete for control of the
  value with well-defined priority arbitration and a relinquish default. The object
  carries a COV threshold (`cov_increment`) and can expose OUT_OF_RANGE reporting
  properties with `intrinsic_reporting: true`. Lifecycle execution maintains core value
  behaviour - event detection and notification delivery are separate. Typical properties
  include `units` and optional min/max present value limits.

  ### Object Description (ASHRAE 135)

  > The Analog Value object type defines a standardized object whose properties represent
  > the externally visible characteristics of an analog value.
  > An "analog value" is a control system parameter residing in the memory of the BACnet Device.
  >
  > Analog Value objects that support intrinsic reporting shall apply the OUT_OF_RANGE
  > event algorithm.

  ### Behaviour and Operation

  Analog Value objects represent in-memory analog parameters or setpoints. A
  non-commandable instance stores `present_value` directly. The local application
  supplies calculated values through `update_property/3`, and BACnet clients may
  write it through the host's service handler. There is no standardized periodic
  calculation, sensor acquisition or hardware output algorithm for this object.

  ### Optional commandability and priority arrays

  Supplying `priority_array` or `relinquish_default` selects commandability. The existing
  implicit relationship adds its partner, including when selected with `add_property/3`.
  Adding commandability replaces the previous direct value with the array's effective
  value. Removing the pair returns the instance to direct property updates.

  For a commandable instance, use `set_priority/3` to implement writes to Present_Value
  from both BACnet clients and local applications. The lowest numbered non-nil slot wins.
  A nil command relinquishes only that slot, revealing the next command or
  `relinquish_default` when all slots are nil. Lower-priority commands are retained even
  while masked. A write without an explicit BACnet priority uses priority 16 - the host
  needs to pass that default to `set_priority/3`.

  Priority 6 is reserved for minimum on/off control and cannot be commanded or relinquished
  through `set_priority/3`. Analog Value has no minimum on/off timing. Lifecycle preflight
  rejects a stored non-nil slot 6 with `{:error, {:invalid_configuration, :priority_6}}`.
  The array is read-only to BACnet clients. Direct Present_Value updates bypass the
  command mechanism and must not be used for a commandable instance, including while
  out of service. The existing property operations keep the effective value synchronized
  when priorities or the relinquish default change.

  ### Out of service and write origin

  `out_of_service: true` prevents normal local software from modifying Present_Value.
  `BACnet.Protocol.ObjectExecution.Context` distinguishes these updates with
  `{:application_write, property, array_index, priority}`. Lifecycle preparation rejects
  local Present_Value writes while out of service, including same-value and masked
  commands. It also rejects indirect local changes to the effective value, such as a
  relinquish-default edit that changes Present_Value. A masked configuration edit that
  leaves the effective value unchanged is allowed.

  BACnet writes use `{:property_write, property, array_index, priority}` and remain
  available for simulation while out of service. Commandable instances still arbitrate
  these writes. A local adapter handling a BACnet request needs to preserve that BACnet
  origin. Local value production can resume after returning to service.

  ### Lifecycle and host contract

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  is the integrating application or higher-level BACnet stack that retains the object
  and its runtime state, serializes operations and supplies their context. This module
  starts no process and invokes no host I/O callbacks.

  Initialize with `BACnet.Protocol.ObjectExecution.Lifecycle.execute/2` and the
  `:initialization` trigger. Retain the full returned result. For each write, construct
  a candidate through this module's property operations, call
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3`, commit the prepared object
  and execute it with the same context and previous runtime state before exposing the
  operation. Deliver every accepted write, including same-value writes. Raw property
  operations do not enforce lifecycle origin checks or execute the lifecycle themselves.

  The host still needs to enforce service permissions, read-only annotations, array
  indices and BACnet priority rules. Preparation is pure and rejected writes leave the
  original object and state unchanged. Execute returns no replacement result on error.
  Initialization is required for local operations - missing, malformed or other-instance
  runtime state returns `{:error, :invalid_execution_state}`.

  Every successful execution returns `next_execution: nil`. No timer or periodic polling
  is required for this core behaviour. The host needs to cancel any superseded request
  when retaining that result. Reads can use
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` and then `get_property/2`.
  Wall and monotonic clocks do not drive arithmetic here. After a restart, initialize
  from restored object properties with fresh context and state. Runtime-only suppressed
  reliability reports cannot be recovered from a property that currently exposes
  NO_FAULT_DETECTED - the application needs to supply a fresh report if necessary.

  ### Reliability and status flags

  The application supplies `reliability` from the health of its value source - for
  example, a failed calculation or missing dependency. No source fault is inferred
  from a rejected write, a min/max validation error or an invalid runtime state.
  The existing property mechanics propagate Reliability into the FAULT status flag,
  Event_State into IN_ALARM and Out_Of_Service into OUT_OF_SERVICE. OVERRIDDEN remains
  a local indication that the host needs to supply when applicable.

  When selected, `reliability_evaluation_inhibit` exposes NO_FAULT_DETECTED while true,
  except for an explicitly supplied or written Reliability while out of service.
  The lifecycle retains the latest supplied reliability report and restores it when
  inhibition ends. Entering out of service alone does not turn a previously suppressed
  report into a simulation value. Returning to service while inhibited masks that
  alternate value again. Reliability reports may still be supplied while out of service -
  the software-value isolation rule applies to Present_Value.

  ### Configuration, intrinsic reporting and COV

  `units`, `resolution`, `min_present_value` and `max_present_value` describe the
  engineering value and its usable range. When both min/max properties are present,
  the existing range validator applies to values, priority commands and relinquish
  defaults. The lifecycle does not add a control formula, unit conversion or rounding.

  With `intrinsic_reporting: true`, execution evaluates OUT_OF_RANGE using the
  effective value and enabled limits. Reliability faults take precedence.
  Event and recovery delays use monotonic time. The host retrieves transitions with
  `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after retaining the result.
  `cov_increment` represents the COV threshold for the host's subscriptions and delivery.

  ### Remote Analog Values

  Remote snapshots are passive. Lifecycle execution preserves the supplied object and
  context state, requests no wakeup and invokes no host callbacks. Preparing local writes
  to a remote snapshot returns `{:error, :operation_not_available_for_remote_objects}`.

  ### Complete write example

  This example supplies a local application value and retains the resulting state.
  For a commandable instance, construct the candidate with `set_priority/3` instead.

      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> {:ok, object} = BACnet.Protocol.ObjectTypes.AnalogValue.create(10, "Room setpoint", %{present_value: 21.0, units: :degrees_celsius})
      iex> start = Context.new(:initialization, now: ~U[2026-11-08 10:00:00Z], monotonic_time: 0)
      iex> {:ok, stored} = Lifecycle.execute(object, start)
      iex> write = Context.new({:application_write, :present_value, nil, nil}, now: ~U[2026-11-08 10:00:01Z], monotonic_time: 1000, state: stored.state)
      iex> {:ok, candidate} = BACnet.Protocol.ObjectTypes.AnalogValue.update_property(stored.object, :present_value, 22.0)
      iex> {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, write)
      iex> stored = %{stored | object: prepared}
      iex> {:ok, stored} = Lifecycle.execute(stored.object, write)
      iex> {stored.object.present_value, stored.next_execution}
      {22.0, nil}

  A runnable walkthrough is `examples/objects_lifecycle/analog_value_lifecycle.exs`.

  ### Examples

  Creating a simple Analog Value:

      iex> {:ok, av} = BACnet.Protocol.ObjectTypes.AnalogValue.create(10, "Setpoint", %{units: :percent}); av.units
      :percent

  Selecting intrinsic reporting properties:

      iex> {:ok, av} = BACnet.Protocol.ObjectTypes.AnalogValue.create(11, "CalcResult", %{}, intrinsic_reporting: true); is_number(av.high_limit)
      true

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.OutOfRange`
  """

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
  Options accepted when creating or configuring an Analog Value object.

  In addition to the common options, Analog Value supports:
  - `intrinsic_reporting` - Selects the OUT_OF_RANGE properties (deadband, high_limit,
    low_limit) and enables evaluation during execution.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents an Analog Value object. Treat struct fields as read-only. Use the object module's
  property functions to build updates.

  Create the object with `intrinsic_reporting: true` to select its intrinsic
  reporting properties. The fields for those properties are `nil` when omitted.

  For a commandable instance, use `set_priority/3` to change the effective
  Present_Value.
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

  Application Present_Value writes are rejected while out of service, including same-value
  and masked commands. Indirect local changes to the effective value are also rejected.
  BACnet commands remain subject to prioritization while out of service. No state is changed.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec prepare_write(t(), t(), Context.t()) :: {:ok, t()} | {:error, term()}
  def prepare_write(original, candidate, context)

  def prepare_write(%__MODULE__{_metadata: %{remote_object: remote}}, _candidate, %Context{})
      when not is_nil(remote), do: {:error, :operation_not_available_for_remote_objects}

  def prepare_write(%__MODULE__{} = original, %__MODULE__{} = candidate, %Context{} = context) do
    with :ok <- validate_execution(original, context),
         :ok <- validate_configuration(candidate),
         :ok <- validate_write(original, context),
         :ok <- validate_write(candidate, context) do
      {:ok, candidate}
    end
  end

  @doc """
  Maintains effective command values, supplied reliability and reliability inhibition.

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
         :ok <- validate_write(object, context),
         {:ok, updated, reliability_state} <- reconcile_reliability(object, context) do
      updated = ObjectOperations.propagate_properties(object_contract(), updated)

      state =
        Map.merge(reliability_state, %{
          identifier: get_object_identifier(updated),
          value: updated.present_value,
          out_of_service: updated.out_of_service
        })

      result = %Result{object: updated, state: state, next_execution: nil}

      {:ok,
       IntrinsicReporting.evaluate(result, context, EventAlgorithms.OutOfRange, [:present_value])}
    end
  end

  @spec validate_configuration(t()) :: :ok | {:error, {:invalid_configuration, :priority_6}}
  defp validate_configuration(object) do
    if has_priority_array?(object) and not is_nil(object.priority_array.priority_6),
      do: {:error, {:invalid_configuration, :priority_6}},
      else: :ok
  end

  @spec validate_state(t(), Context.t()) :: :ok | {:error, :invalid_execution_state}
  defp validate_state(object, context)

  defp validate_state(_object, %Context{trigger: :initialization}), do: :ok

  defp validate_state(object, %Context{state: state}) do
    valid =
      case state do
        %{
          identifier: %ObjectIdentifier{type: :analog_value} = identifier,
          value: value,
          out_of_service: out_of_service,
          reported_reliability: reported,
          manual_reliability: manual
        } ->
          identifier == get_object_identifier(object) and
            (is_float(value) or value in [:NaN, :inf, :infn]) and is_boolean(out_of_service) and
            ObjectOperations.valid_reliability?(object_contract(), object, reported) and
            ObjectOperations.valid_reliability?(object_contract(), object, manual)

        _other ->
          false
      end

    if valid, do: :ok, else: {:error, :invalid_execution_state}
  end

  @spec validate_write(t(), Context.t()) :: :ok | {:error, term()}
  defp validate_write(object, context) do
    case context.trigger do
      {:application_write, _property, _index, _priority} when object.out_of_service ->
        if Context.written_property(context) == :present_value or
             object.present_value != context.state.value,
           do: {:error, :out_of_service},
           else: ObjectOperations.check_priority_write(object, context.trigger)

      _other ->
        ObjectOperations.check_priority_write(object, context.trigger)
    end
  end

  @spec reconcile_reliability(t(), Context.t()) ::
          {:ok, t(),
           %{
             reported_reliability: reliability_value(),
             manual_reliability: reliability_value()
           }}
          | {:error, term()}
  defp reconcile_reliability(object, context) do
    previous = Context.previous_state(context)

    if has_property?(object, :reliability) do
      reported =
        if is_nil(previous) or Context.written_property(context) == :reliability or
             is_nil(previous.reported_reliability),
           do: object.reliability,
           else: previous.reported_reliability

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

      value =
        if object.reliability_evaluation_inhibit,
          do: manual || :no_fault_detected,
          else: reported

      with {:ok, updated} <- update_property(object, :reliability, value) do
        {:ok, updated, %{reported_reliability: reported, manual_reliability: manual}}
      end
    else
      with {:ok, updated} <-
             update_property(object, :status_flags, %{object.status_flags | fault: false}) do
        {:ok, updated, %{reported_reliability: nil, manual_reliability: nil}}
      end
    end
  end
end
