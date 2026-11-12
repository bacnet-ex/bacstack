defmodule BACnet.Protocol.ObjectTypes.LargeAnalogValue do
  @moduledoc """
  A Large Analog Value holds a double-precision floating-point number. Use it
  for quantities such as accumulated energy totals that need more precision
  than a single-precision Analog Value offers.

  ### Object Description (ASHRAE 135)

  > The Large Analog Value object type defines a standardized object whose properties represent
  > the externally visible characteristics of a named data value in a BACnet device.
  > A BACnet device can use a Large Analog Value object to make any kind of
  > double-precision data value accessible to other BACnet devices.
  >
  > Large Analog Value objects that support intrinsic reporting shall apply
  > the DOUBLE_OUT_OF_RANGE event algorithm.

  ### Values and commandability

  A non-commandable instance accepts direct Double values through
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

  ### Double precision and range

  The property and priority-array encoders use BACnet Double. The lifecycle retains
  the supplied Elixir float or IEEE special value.

  The configured range applies when both `min_present_value` and
  `max_present_value` are present. The existing direct property operations
  check Present_Value, commands and Relinquish_Default. Lifecycle preparation
  also checks the complete candidate, including masked slots. An edit that
  would invalidate a stored command, effective value or default fails with
  `{:error, {:property_out_of_range, property}}`. Reconcile those values before
  narrowing the range. The IEEE-aware range check accepts infinite bounds and
  permits NaN as a value. A NaN bound leaves the range unconstrained.
  Rejected writes do not infer Reliability.

  Resolution and Units describe the value supplied by the application.
  The lifecycle preserves the supplied value without periodic calculation,
  rounding or unit conversion.

  ### Out of service and write origin

  An `:application_write` trigger identifies normal local software writes.
  An absent Out_Of_Service property is treated as in service. When the property
  is true, preparation rejects application Present_Value
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
  With `intrinsic_reporting: true`, DOUBLE_OUT_OF_RANGE evaluates Present_Value
  against the enabled limits. The host retrieves transitions with
  `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after retaining
  the result.

  The runnable walkthrough is `examples/objects_lifecycle/large_analog_value_lifecycle.exs`.

  ### Examples

  Creating a Large Analog Value:

      iex> {:ok, lav} = BACnet.Protocol.ObjectTypes.LargeAnalogValue.create(30, "Precise", %{present_value: 3.14159}); lav.object_name
      "Precise"

  Selecting intrinsic reporting properties:

      iex> {:ok, lav} = BACnet.Protocol.ObjectTypes.LargeAnalogValue.create(31, "HighRes", %{present_value: 3.14159}, intrinsic_reporting: true); is_float(lav.present_value)
      true

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.DoubleOutOfRange`
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
  Options accepted when creating or configuring a Large Analog Value object.

  `intrinsic_reporting` selects DOUBLE_OUT_OF_RANGE reporting properties.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents a Large Analog Value object. Treat fields as read-only. Build property
  candidates with `update_property/3` or `set_priority/3` before driving the lifecycle.
  """
  bac_object Constants.macro_assert_name(:object_type, :large_analog_value) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean())

    field(:present_value, float(),
      required: true,
      default: 0.0,
      bac_type: :double
    )

    field(:priority_array, PriorityArray.t(float()), readonly: true)
    field(:relinquish_default, float(), default: 0.0, bac_type: :double)

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())
    field(:resolution, float(), readonly: true, bac_type: :double)
    field(:units, Constants.engineering_unit(), required: true, default: :no_units)

    field(:max_present_value, float(), bac_type: :double)
    field(:min_present_value, float(), bac_type: :double)

    # COV Reporting
    field(:cov_increment, float(), cov: true, default: 0.1, bac_type: :double)

    # Intrinsic Reporting
    field(:event_state, Constants.event_state(), intrinsic: true)
    field(:deadband, float(), intrinsic: true, default: 0.0, bac_type: :double)
    field(:high_limit, float(), intrinsic: true, default: 0.0, bac_type: :double)
    field(:low_limit, float(), intrinsic: true, default: 0.0, bac_type: :double)
  end

  @doc """
  Commands or relinquishes a priority slot within the configured Double range.

  A nil value relinquishes the slot. Priority 6 is reserved for minimum on/off control.
  Prepare and execute the candidate with the actual write origin before exposing it.
  """
  @spec set_priority(t(), 1..16, ApplicationTags.ieee_float() | nil) ::
          {:ok, t()} | {:error, term()}
  def set_priority(object, priority, value)

  def set_priority(%__MODULE__{priority_array: nil} = _object, _priority, _value) do
    {:error, {:unknown_property, :priority_array}}
  end

  def set_priority(
        %__MODULE__{priority_array: %PriorityArray{} = _pa} = object,
        priority,
        value
      )
      when priority in 1..16 do
    with :ok <- ObjectOperations.check_priority_command(object, priority),
         :ok <-
           if(value == nil,
             do: :ok,
             else: check_min_max_present_value(object, :priority_array, value)
           ),
         do: super(object, priority, value)
  end

  @doc """
  Updates a property, checking the Double range for direct values and relinquish defaults.

  Commandable Present_Value writes use the priority mechanism. This property operation
  builds a candidate for lifecycle preparation.
  """
  @spec update_property(t(), Constants.property_identifier(), term()) ::
          {:ok, t()} | property_update_error()
  def update_property(object, property, value)

  def update_property(%__MODULE__{} = object, :present_value, value) do
    with :ok <- check_min_max_present_value(object, :present_value, value),
         do: super(object, :present_value, value)
  end

  def update_property(%__MODULE__{} = object, :relinquish_default, value) do
    with :ok <- check_min_max_present_value(object, :relinquish_default, value),
         do: super(object, :relinquish_default, value)
  end

  def update_property(%__MODULE__{} = object, property, value) when is_atom(property) do
    super(object, property, value)
  end

  @spec check_min_max_present_value(t(), Constants.property_identifier(), term()) ::
          :ok | property_update_error()
  defp check_min_max_present_value(object, property, value)

  defp check_min_max_present_value(
         %{min_present_value: min, max_present_value: max},
         property,
         value
       )
       when is_float(value) or value in [:NaN, :inf, :infn] do
    if ObjectsUtility.validate_float_range(value, %{
         min_present_value: min,
         max_present_value: max
       }),
       do: :ok,
       else: {:error, {:property_out_of_range, property}}
  end

  defp check_min_max_present_value(_object, _property, _value), do: :ok

  @typep reliability_value :: Constants.reliability() | non_neg_integer() | nil

  @doc """
  Checks the Double range, reserved priority and retained runtime state without I/O.

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
      out_of_service = updated.out_of_service == true

      updated = %{
        updated
        | status_flags: %{updated.status_flags | out_of_service: out_of_service}
      }

      state =
        Map.merge(reliability_state, %{
          identifier: get_object_identifier(updated),
          value: updated.present_value,
          out_of_service: out_of_service
        })

      result = %Result{object: updated, state: state, next_execution: nil}

      {:ok,
       IntrinsicReporting.evaluate(result, context, EventAlgorithms.DoubleOutOfRange, [
         :present_value
       ])}
    end
  end

  @spec validate_configuration(t()) :: :ok | {:error, term()}
  defp validate_configuration(object) do
    with :ok <- check_min_max_present_value(object, :present_value, object.present_value) do
      validate_command_range(object)
    end
  end

  @spec validate_command_range(t()) :: :ok | {:error, term()}
  defp validate_command_range(object) do
    case object.priority_array do
      nil ->
        :ok

      %PriorityArray{priority_6: priority} when not is_nil(priority) ->
        {:error, {:invalid_configuration, :priority_6}}

      %PriorityArray{} = priorities ->
        with :ok <-
               check_min_max_present_value(object, :relinquish_default, object.relinquish_default) do
          priorities
          |> PriorityArray.to_list()
          |> Enum.reduce_while(:ok, fn
            nil, :ok ->
              {:cont, :ok}

            value, :ok ->
              case check_min_max_present_value(object, :priority_array, value) do
                :ok -> {:cont, :ok}
                {:error, _reason} = error -> {:halt, error}
              end
          end)
        end
    end
  end

  @spec validate_state(t(), Context.t()) :: :ok | {:error, :invalid_execution_state}
  defp validate_state(object, context)

  defp validate_state(_object, %Context{trigger: :initialization}), do: :ok

  defp validate_state(object, %Context{state: state}) do
    valid =
      case state do
        %{
          identifier: %ObjectIdentifier{type: :large_analog_value} = identifier,
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
      {:application_write, _property, _index, _priority}
      when object.out_of_service == true or context.state.out_of_service ->
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
    out_of_service = object.out_of_service == true

    if has_property?(object, :reliability) do
      reported =
        if is_nil(previous) or Context.written_property(context) == :reliability or
             is_nil(previous.reported_reliability),
           do: object.reliability,
           else: previous.reported_reliability

      manual =
        cond do
          not out_of_service ->
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
