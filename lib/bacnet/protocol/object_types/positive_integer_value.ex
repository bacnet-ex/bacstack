defmodule BACnet.Protocol.ObjectTypes.PositiveIntegerValue do
  @moduledoc """
  A Positive Integer Value holds an unsigned integer such as a pulse total,
  error count or stage number. It accepts zero. Use
  `BACnet.Protocol.ObjectTypes.IntegerValue` when the value can be negative.

  ### Object Description (ASHRAE 135)

  > The Positive Integer Value object type defines a standardized object whose properties represent
  > the externally visible characteristics of a named data value in a BACnet device.
  > A BACnet device can use a Positive Integer Value object to make any kind of unsigned
  > integer data value accessible to other BACnet devices.
  >
  > Positive Integer Value objects that support intrinsic reporting shall apply
  > the UNSIGNED_OUT_OF_RANGE event algorithm.

  ### Values and commandability

  A non-commandable instance accepts direct unsigned values through
  `update_property/3`. This implementation allows direct BACnet writes in
  either service state, subject to the host's permissions. Selecting
  Priority_Array or Relinquish_Default adds its partner and makes Present_Value
  follow the effective command or default.

  For commandable instances, use `set_priority/3` for Present_Value writes.
  The lowest numbered non-nil priority wins. Lower-priority commands remain
  stored while masked. A nil command relinquishes its slot, exposing the next
  command or Relinquish_Default. The host needs to use priority 16 when a BACnet
  command omits its priority. Priority_Array is read-only to BACnet clients.
  Priority 6 is reserved for minimum on/off control and is unavailable.
  Lifecycle preflight rejects a stored non-nil command at that priority.

  ### Unsigned range and configuration

  Values and commands are non-negative integers, including zero. The configured range
  applies when both `min_present_value` and `max_present_value` are present. Property operations
  check Present_Value, commands and Relinquish_Default. Lifecycle preparation
  also checks the complete candidate, including masked slots. An edit that
  would invalidate a stored command, effective value or default fails with
  `{:error, {:value_failed_property_validation, property}}`. Reconcile those values before
  narrowing the range. Rejected writes do not infer Reliability.

  Resolution and Units describe the application value. The application
  determines its meaning and supplies it as an integer. The lifecycle applies
  no periodic formula, rounding or unit conversion.

  ### Out of service and write origin

  An `:application_write` trigger identifies normal local software writes.
  When Out_Of_Service is true, preparation rejects application Present_Value
  writes, including same-value and masked commands. It also rejects local
  configuration edits that would indirectly change the effective value.
  Configuration edits that preserve the effective value can proceed.
  Resume service before supplying a new local value in a separate operation.

  BACnet requests use `:property_write` and remain available for simulation.
  Command prioritization continues while out of service. The host needs to
  preserve that origin for requests handled by a local callback. Lifecycle
  checks accept named and numeric property identifiers. Returning to service
  preserves the effective value until another write.

  ### Lifecycle and host contract

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  needs to own instances, serialize operations and retain their runtime state.
  Initialize with `BACnet.Protocol.ObjectExecution.Lifecycle.execute/2` and an
  `:initialization` context. Build a candidate with the property operations
  and call `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3` before
  committing it. Execute with the same context and previous runtime state.
  Retain the complete result before exposing another operation. Deliver every
  accepted write, including repeated values and masked commands.

  The host needs to enforce service permissions, read-only annotations and
  array indices. Rejection supplies no replacement result. Missing, malformed
  or other-instance runtime state returns `{:error, :invalid_execution_state}`.
  Remote snapshots are passive and reject local write preparation.

  Use `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` before reading
  with `get_property/2`. An active reporting delay can request a monotonic wakeup. The host
  needs to cancel any superseded request when retaining the result. After
  restart, initialize restored properties with fresh runtime state.

  ### Reliability and reporting

  The application supplies Reliability from its diagnosis of the value source.
  Reliability_Evaluation_Inhibit masks a report with NO_FAULT_DETECTED and retains
  it for restoration. Either origin can supply an explicit alternate Reliability
  during simulation, including while inhibited. Returning to service while
  inhibited masks that value again. Refresh suppressed reports held only in
  runtime state after restart.

  FAULT follows the exposed Reliability, IN_ALARM follows the supplied Event_State
  and OUT_OF_SERVICE follows Out_Of_Service. OVERRIDDEN remains a local indication.
  With `intrinsic_reporting: true`, UNSIGNED_OUT_OF_RANGE evaluates Present_Value
  against the enabled limits. The host retrieves transitions with
  `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after retaining
  the result.

  The runnable walkthrough is `examples/objects_lifecycle/positive_integer_value_lifecycle.exs`.

  ### Examples

  Creating a Positive Integer Value:

      iex> {:ok, piv} = BACnet.Protocol.ObjectTypes.PositiveIntegerValue.create(20, "Count", %{present_value: 0}); piv.object_name
      "Count"

  Selecting intrinsic reporting properties:

      iex> {:ok, piv} = BACnet.Protocol.ObjectTypes.PositiveIntegerValue.create(21, "UCount", %{present_value: 0}, intrinsic_reporting: true); is_integer(piv.present_value)
      true

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.UnsignedOutOfRange`
  """

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EventAlgorithms
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.IntrinsicReporting
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectOperations
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Positive Integer Value object.

  `intrinsic_reporting` selects UNSIGNED_OUT_OF_RANGE reporting properties.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents a Positive Integer Value object. Treat fields as read-only. Build candidates
  with `update_property/3` or `set_priority/3` before driving the lifecycle.
  """
  bac_object Constants.macro_assert_name(:object_type, :positive_integer_value) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:device_type, String.t())
    field(:event_state, Constants.event_state(), required: true)
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean(), required: true)

    field(:present_value, non_neg_integer(),
      required: true,
      default: 0,
      validator_fun: fn
        value, %{min_present_value: min, max_present_value: max}
        when not is_nil(min) and not is_nil(max) ->
          min <= value and value <= max

        _value, _obj ->
          true
      end
    )

    field(:priority_array, PriorityArray.t(non_neg_integer()), readonly: true)

    field(:relinquish_default, non_neg_integer(),
      default: 0,
      validator_fun: fn
        value, %{min_present_value: min, max_present_value: max}
        when not is_nil(min) and not is_nil(max) ->
          min <= value and value <= max

        _value, _obj ->
          true
      end
    )

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())
    field(:resolution, non_neg_integer(), readonly: true)
    field(:units, Constants.engineering_unit(), required: true, default: :no_units)

    field(:max_present_value, non_neg_integer())
    field(:min_present_value, non_neg_integer())

    # COV Reporting
    field(:cov_increment, non_neg_integer(), cov: true, default: 0)

    # Intrinsic Reporting
    field(:deadband, non_neg_integer(), intrinsic: true, default: 0)
    field(:high_limit, non_neg_integer(), intrinsic: true, default: 0)
    field(:low_limit, non_neg_integer(), intrinsic: true, default: 0)
  end

  @typep reliability_value :: Constants.reliability() | non_neg_integer() | nil

  @doc """
  Checks the unsigned range, reserved priority and retained runtime state without I/O.

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
       IntrinsicReporting.evaluate(result, context, EventAlgorithms.UnsignedOutOfRange, [
         :present_value
       ])}
    end
  end

  @spec validate_configuration(t()) :: :ok | {:error, term()}
  defp validate_configuration(object)

  defp validate_configuration(%__MODULE__{priority_array: %PriorityArray{priority_6: value}})
       when not is_nil(value),
       do: {:error, {:invalid_configuration, :priority_6}}

  defp validate_configuration(object) do
    properties =
      if has_priority_array?(object),
        do: [:present_value, :relinquish_default, :priority_array],
        else: [:present_value]

    Enum.reduce_while(properties, :ok, fn property, :ok ->
      case ObjectOperations.check_property_value(
             object_contract(),
             object,
             property,
             Map.fetch!(object, property),
             false,
             false
           ) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  @spec validate_state(t(), Context.t()) :: :ok | {:error, :invalid_execution_state}
  defp validate_state(object, context)

  defp validate_state(_object, %Context{trigger: :initialization}), do: :ok

  defp validate_state(object, %Context{state: state}) do
    valid =
      case state do
        %{
          identifier: %ObjectIdentifier{type: :positive_integer_value} = identifier,
          value: value,
          out_of_service: out_of_service,
          reported_reliability: reported,
          manual_reliability: manual
        } ->
          identifier == get_object_identifier(object) and
            is_integer(value) and value >= 0 and is_boolean(out_of_service) and
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
      {:application_write, _property, _index, _priority}
      when object.out_of_service or context.state.out_of_service ->
        if Context.written_property(context) == :present_value or
             object.present_value != context.state.value,
           do: {:error, :out_of_service},
           else: ObjectOperations.check_priority_write(object, context.trigger)

      _other ->
        ObjectOperations.check_priority_write(object, context.trigger)
    end
  end

  @spec reconcile_reliability(t(), Context.t()) ::
          {:ok, object :: t(),
           reliability_state :: %{
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
