defmodule BACnet.Protocol.ObjectTypes.PulseConverter do
  @moduledoc """
  A Pulse Converter turns a pulse count into a quantity such as energy or
  water usage. It can accept batches of pulses or read a counter on another
  object. Present_Value is Count multiplied by Scale_Factor.

  ### Object Description (ASHRAE 135)

  > The Pulse Converter object type defines a standardized object that represents
  > a process whereby ongoing measurements made of some quantity, such as
  > electric power or water or natural gas usage, and represented by pulses or counts,
  > might be monitored over some time interval.
  >
  > Pulse Converter objects that support intrinsic reporting shall apply
  > the OUT_OF_RANGE event algorithm.

  ### Direct and referenced acquisition

  Initialize with `BACnet.Protocol.ObjectExecution.Lifecycle.execute/2` and an
  `:initialization` context. With no Input_Reference, deliver raw batches via
  `record_pulses/3`. Each pulse adds one to Count. An increase in Count due to
  acquisition stamps Update_Time with the supplied device-local time.

  Input_Reference identifies a local object and an INTEGER or Unsigned property.
  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  supplies that property through the `BACnet.Protocol.ObjectExecution.Context`
  read callback. The lifecycle samples on initialization, a changed reference,
  a matching `:object_changed` notification or a `:periodic` trigger. An ordinary
  property read serves the retained result. The host needs to deliver source
  changes or choose a polling cadence. Execution requests no wakeup.

  The first valid sample establishes a source baseline and preserves the
  supplied Count. Later increases advance Count by the observed difference.
  A decrease establishes a fresh baseline. The callback needs to supply a
  monotonically increasing source if exact counting across resets or rollovers
  is required. A read failure preserves the last valid sample for the same
  reference. For a value that would otherwise be ambiguous, return its BACnet
  encoding so the converter can distinguish integer tags from other datatypes.

  ### Adjust the count

  An Adjust_Value write subtracts the quotient of the adjustment divided by
  Scale_Factor, truncated toward zero, from Count. The operation stores the
  written adjustment, copies the previous Count into Count_Before_Change,
  stamps Count_Change_Time and updates the coupled Present_Value. Repeating
  the same write applies another adjustment. Update_Time records acquisition
  and keeps its prior value when adjusting.

  Scale_Factor must be a finite, nonzero BACnet REAL. Count must be nonnegative
  and its product with Scale_Factor must fit in a finite REAL. An adjustment
  outside that domain returns `{:error, {:property_out_of_range, :adjust_value}}`
  before changing any property.

  Construct a candidate with `update_property/3`, prepare it with
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3` and execute it
  with the same context and prior state. The host needs to serialize those
  operations and retain the complete successful result before exposing it.

  ### Out of service and Reliability

  Out_Of_Service allows explicit Present_Value and Reliability simulation.
  Direct pulse batches are ignored while isolated. Referenced acquisition
  can continue to update Count and Update_Time while leaving Present_Value
  and exposed Reliability isolated. The converter's Out_Of_Service property
  describes its own state. It remains independent of the referenced object's
  state. Adjust_Value still updates Count and its history during simulation.
  Returning to service recomputes Present_Value from Count.

  A referenced source selects Reliability. An unsupported source or datatype
  reports CONFIGURATION_ERROR. A failed read reports COMMUNICATION_FAILURE,
  and an increase that exceeds the count domain reports OVER_RANGE. Successful
  samples clear those reports. With a direct input, the application supplies
  Reliability. Reliability_Evaluation_Inhibit masks the report with
  NO_FAULT_DETECTED while retaining it. Explicit out-of-service Reliability
  writes from either origin can supply a simulated report while inhibited.

  With `intrinsic_reporting: true`, OUT_OF_RANGE evaluates the scaled
  Present_Value. After retaining the result, the host retrieves transitions with
  `BACnet.Protocol.ObjectExecution.EventReporting.transition/1`.

  Remote snapshots are passive. After a restart, initialize with
  restored properties and fresh state. The first successful reference read
  starts a new baseline.

  The runnable walkthrough is `examples/objects_lifecycle/pulse_converter_lifecycle.exs`.

  ### Examples

  Creating a Pulse Converter:

      iex> {:ok, pc} = BACnet.Protocol.ObjectTypes.PulseConverter.create(400, "Usage total", %{}); pc.object_name
      "Usage total"

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.OutOfRange`
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.DeviceObjectRef
  alias BACnet.Protocol.EventAlgorithms
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.IntrinsicReporting
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectOperations
  alias BACnet.Protocol.ObjectPropertyRef
  alias BACnet.Protocol.ObjectsMacro

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Pulse Converter object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a Pulse Converter object. Treat fields as read-only. Use
  `record_pulses/3` for direct input and the lifecycle for property operations.
  """
  bac_object Constants.macro_assert_name(:object_type, :pulse_converter) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:device_type, String.t())
    field(:event_state, Constants.event_state(), required: true)
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean(), required: true)
    field(:present_value, float(), required: true, default: 0.0)

    field(:input_reference, ObjectPropertyRef.t())

    field(:reliability, Constants.reliability(),
      default: :no_fault_detected,
      annotation: [required_when: {:property, :input_reference}],
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean(),
      default: false,
      annotation: [required_when: {:property, :input_reference}]
    )

    field(:units, Constants.engineering_unit(), required: true, default: :no_units)

    field(:scale_factor, float(), required: true, readonly: true, default: 1.0)
    field(:adjust_value, float(), required: true, default: 0.0)
    field(:count, non_neg_integer(), required: true, readonly: true, default: 0)

    field(:update_time, BACnetDateTime.t(),
      required: true,
      readonly: true,
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    field(:count_change_time, BACnetDateTime.t(),
      required: true,
      readonly: true,
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    field(:count_before_change, non_neg_integer(), required: true, readonly: true, default: 0)

    # COV Reporting
    field(:cov_increment, float(), cov: true, default: 0.1)

    field(:cov_period, non_neg_integer(),
      cov: true,
      default: 0,
      implicit_relationship: :cov_increment
    )

    # Intrinsic Reporting
    field(:high_limit, float(), intrinsic: true, default: 0.0)
    field(:low_limit, float(), intrinsic: true, default: 0.0)
    field(:deadband, float(), intrinsic: true, default: 0.0)
  end

  @max_real 3.402_823_466_385_288_6e38
  @min_nonzero_real 1.401_298_464_324_817e-45

  @typep reliability_value :: Constants.reliability() | non_neg_integer() | nil

  @typep source_state :: %{
           reference: ObjectPropertyRef.t(),
           value: integer() | nil,
           reliability: Constants.reliability()
         }

  @typep execution_state :: %{
           identifier: ObjectIdentifier.t(),
           count: non_neg_integer(),
           out_of_service: boolean(),
           source: source_state() | nil,
           physical_reliability: reliability_value(),
           manual_reliability: reliability_value()
         }

  @doc """
  Records raw pulses when this object represents the physical input directly.

  Initialize first and supply the previous result's runtime state. The host needs to
  retain the whole result before delivering the next pulse batch. Out-of-service
  direct inputs ignore pulses. A configured Input_Reference selects reference
  acquisition instead.
  """
  @spec record_pulses(t(), non_neg_integer(), Context.t()) ::
          {:ok, Result.t(t())} | {:error, term()}
  def record_pulses(object, pulses, context)

  def record_pulses(%__MODULE__{_metadata: %{remote_object: remote}}, _pulses, %Context{})
      when not is_nil(remote), do: {:error, :operation_not_available_for_remote_objects}

  def record_pulses(%__MODULE__{input_reference: %ObjectPropertyRef{}}, _pulses, %Context{}),
    do: {:error, :input_reference_configured}

  def record_pulses(%__MODULE__{} = object, pulses, %Context{} = context)
      when is_integer(pulses) and pulses >= 0 do
    step(object, %{context | trigger: :periodic}, pulses)
  end

  def record_pulses(%__MODULE__{}, _pulses, %Context{}), do: {:error, :invalid_pulse_count}

  @doc """
  Reports Present_Value as writable to BACnet clients while out of service.
  """
  @spec property_writable?(t(), Constants.property_identifier()) :: boolean()
  def property_writable?(object, property)

  def property_writable?(%__MODULE__{} = object, :present_value),
    do: object.out_of_service == true and has_property?(object, :present_value)

  def property_writable?(%__MODULE__{} = object, property), do: super(object, property)

  @doc """
  Checks local scale, count and retained runtime state before execution.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec validate_execution(t(), Context.t()) :: :ok | {:error, term()}
  def validate_execution(object, context)

  def validate_execution(%__MODULE__{_metadata: %{remote_object: remote}}, %Context{})
      when not is_nil(remote), do: :ok

  def validate_execution(%__MODULE__{} = object, %Context{} = context) do
    with :ok <- validate_scale(object.scale_factor),
         {:ok, _value} <- scaled_value(object.count, object.scale_factor, :count) do
      validate_state(object, context)
    end
  end

  @doc """
  Checks write access and prepares Adjust_Value's atomic count and history updates.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec prepare_write(t(), t(), Context.t()) :: {:ok, t()} | {:error, term()}
  def prepare_write(original, candidate, context)

  def prepare_write(%__MODULE__{_metadata: %{remote_object: remote}}, _candidate, %Context{})
      when not is_nil(remote), do: {:error, :operation_not_available_for_remote_objects}

  def prepare_write(%__MODULE__{} = original, %__MODULE__{} = candidate, %Context{} = context) do
    with :ok <- validate_execution(original, context),
         :ok <- validate_execution(candidate, context),
         :ok <- validate_write(original, candidate, context) do
      prepare_adjustment(candidate, context)
    end
  end

  @doc """
  Advances acquisition, scaled value and Reliability using the host's context.

  The host drives referenced reads with initialization, periodic or source-change
  triggers. Retain the full result before exposing another operation.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec execute(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  def execute(object, context)

  def execute(%__MODULE__{_metadata: %{remote_object: remote}} = object, %Context{} = context)
      when not is_nil(remote),
      do: {:ok, %Result{object: object, state: context.state, next_execution: nil}}

  def execute(%__MODULE__{} = object, %Context{} = context), do: step(object, context, 0)

  @spec step(t(), Context.t(), non_neg_integer()) :: {:ok, Result.t(t())} | {:error, term()}
  defp step(object, context, pulses) do
    previous = Context.previous_state(context)

    with :ok <- validate_execution(object, context),
         :ok <- validate_write(object, object, context),
         {:ok, adjusted} <- prepare_adjustment(object, context),
         {:ok, acquired, source} <- acquire(adjusted, previous, context, pulses),
         {:ok, measured} <- update_present_value(acquired),
         {:ok, updated, reliability_state} <-
           reconcile_reliability(measured, previous, source, context) do
      state =
        Map.merge(reliability_state, %{
          identifier: get_object_identifier(updated),
          count: updated.count,
          out_of_service: updated.out_of_service,
          source: source
        })

      result = %Result{object: updated, state: state, next_execution: nil}

      {:ok,
       IntrinsicReporting.evaluate(result, context, EventAlgorithms.OutOfRange, [:present_value])}
    end
  end

  @spec validate_scale(term()) :: :ok | {:error, {:invalid_configuration, :scale_factor}}
  defp validate_scale(scale) do
    if is_float(scale) and abs(scale) >= @min_nonzero_real and abs(scale) <= @max_real,
      do: :ok,
      else: {:error, {:invalid_configuration, :scale_factor}}
  end

  @spec scaled_value(integer(), float(), Constants.property_identifier()) ::
          {:ok, float()} | {:error, {:property_out_of_range, Constants.property_identifier()}}
  defp scaled_value(count, scale, property) do
    if count >= 0 do
      value = count * scale

      if abs(value) <= @max_real,
        do: {:ok, value},
        else: {:error, {:property_out_of_range, property}}
    else
      {:error, {:property_out_of_range, property}}
    end
  rescue
    ArithmeticError -> {:error, {:property_out_of_range, property}}
  end

  @spec validate_state(t(), Context.t()) :: :ok | {:error, :invalid_execution_state}
  defp validate_state(object, context)

  defp validate_state(_object, %Context{trigger: :initialization}), do: :ok

  defp validate_state(object, %Context{state: state}) do
    valid =
      case state do
        %{
          identifier: %ObjectIdentifier{} = identifier,
          count: count,
          out_of_service: out_of_service,
          source: source,
          physical_reliability: physical,
          manual_reliability: manual
        }
        when is_integer(count) and count >= 0 and is_boolean(out_of_service) ->
          identifier == get_object_identifier(object) and valid_source?(source) and
            ObjectOperations.valid_reliability?(object_contract(), object, physical) and
            ObjectOperations.valid_reliability?(object_contract(), object, manual)

        _invalid ->
          false
      end

    if valid, do: :ok, else: {:error, :invalid_execution_state}
  end

  @spec valid_source?(term()) :: boolean()
  defp valid_source?(source)

  defp valid_source?(nil), do: true

  defp valid_source?(%{reference: %ObjectPropertyRef{} = ref, value: value, reliability: report})
       when (is_nil(value) or is_integer(value)) and is_atom(report) do
    ObjectPropertyRef.valid?(ref) and Constants.has_by_name(:reliability, report)
  end

  defp valid_source?(_source), do: false

  @spec validate_write(t(), t(), Context.t()) :: :ok | {:error, term()}
  defp validate_write(original, candidate, context) do
    case Context.written_property(context) do
      property
      when property in [:count, :count_before_change, :count_change_time, :update_time] ->
        {:error, :write_access_denied}

      :present_value when not original.out_of_service or not candidate.out_of_service ->
        {:error, :write_access_denied}

      _property ->
        :ok
    end
  end

  @spec prepare_adjustment(t(), Context.t()) :: {:ok, t()} | {:error, term()}
  defp prepare_adjustment(object, context) do
    if Context.written_property(context) == :adjust_value do
      previous_count = context.state.count

      with {:ok, count} <-
             adjusted_count(previous_count, object.adjust_value, object.scale_factor),
           {:ok, timestamp} <- timestamp(context) do
        update_present_value(%{
          object
          | count: count,
            count_before_change: previous_count,
            count_change_time: timestamp
        })
      end
    else
      {:ok, object}
    end
  end

  @spec adjusted_count(non_neg_integer(), ApplicationTags.ieee_float(), float()) ::
          {:ok, non_neg_integer()} | {:error, {:property_out_of_range, :adjust_value}}
  defp adjusted_count(previous, adjustment, scale)

  defp adjusted_count(previous, adjustment, scale)
       when is_float(adjustment) and abs(adjustment) <= @max_real do
    count = previous - trunc(adjustment / scale)

    with {:ok, _value} <- scaled_value(count, scale, :adjust_value) do
      {:ok, count}
    end
  end

  defp adjusted_count(_previous, _adjustment, _scale),
    do: {:error, {:property_out_of_range, :adjust_value}}

  @spec acquire(t(), execution_state() | nil, Context.t(), non_neg_integer()) ::
          {:ok, object :: t(), source :: source_state() | nil} | {:error, term()}
  defp acquire(object, previous, context, pulses)

  defp acquire(%__MODULE__{input_reference: nil} = object, _previous, context, pulses) do
    increments = if object.out_of_service, do: 0, else: pulses

    with {:ok, updated} <- add_pulses(object, increments, context) do
      {:ok, updated, nil}
    end
  end

  defp acquire(
         %__MODULE__{input_reference: %ObjectPropertyRef{} = ref} = object,
         previous,
         context,
         0
       ) do
    source = if previous, do: previous.source

    if should_read_source?(ref, source, context) do
      baseline =
        case source do
          %{reference: ^ref, value: count} -> count
          _other -> nil
        end

      sample_reference(object, ref, baseline, context)
    else
      {:ok, object, source}
    end
  end

  @spec should_read_source?(ObjectPropertyRef.t(), source_state() | nil, Context.t()) :: boolean()
  defp should_read_source?(ref, source, context) do
    is_nil(source) or source.reference != ref or context.trigger in [:initialization, :periodic] or
      source_changed?(ref, context)
  end

  @spec source_changed?(ObjectPropertyRef.t(), Context.t()) :: boolean()
  defp source_changed?(ref, context)

  defp source_changed?(ref, %Context{
         device_identifier: local_device,
         trigger:
           {:object_changed,
            %DeviceObjectRef{object_identifier: identifier, device_identifier: device}}
       }) do
    identifier == ref.object_identifier and (is_nil(device) or device == local_device)
  end

  defp source_changed?(_ref, _context), do: false

  @spec sample_reference(t(), ObjectPropertyRef.t(), integer() | nil, Context.t()) ::
          {:ok, object :: t(), source :: source_state()} | {:error, term()}
  defp sample_reference(object, ref, previous, context) do
    reading =
      if ref.object_identifier == get_object_identifier(object) do
        {:error, :configuration_error}
      else
        read_reference(ref, context)
      end

    case reading do
      {:ok, count} ->
        increments = if is_nil(previous), do: 0, else: max(count - previous, 0)

        case add_pulses(object, increments, context) do
          {:ok, updated} ->
            {:ok, updated, %{reference: ref, value: count, reliability: :no_fault_detected}}

          {:error, {:property_out_of_range, :count}} ->
            {:ok, object, %{reference: ref, value: previous, reliability: :over_range}}

          {:error, _reason} = error ->
            error
        end

      {:error, reliability} ->
        {:ok, object, %{reference: ref, value: previous, reliability: reliability}}
    end
  end

  @spec read_reference(ObjectPropertyRef.t(), Context.t()) ::
          {:ok, integer()} | {:error, :configuration_error | :communication_failure}
  defp read_reference(ref, context) do
    reference = %DeviceObjectPropertyRef{
      device_identifier: nil,
      object_identifier: ref.object_identifier,
      property_identifier: ref.property_identifier,
      property_array_index: ref.property_array_index
    }

    case Context.read_property(context, reference) do
      {:ok, value} ->
        input_count(value)

      {:error, reason}
      when reason in [
             :unknown_object,
             :unknown_property,
             :cyclic_execution,
             :unsupported_reference
           ] ->
        {:error, :configuration_error}

      {:error, {reason, _details}}
      when reason in [:unknown_object, :unknown_property, :unsupported_operation] ->
        {:error, :configuration_error}

      {:error, _reason} ->
        {:error, :communication_failure}
    end
  end

  @spec input_count(term()) :: {:ok, integer()} | {:error, :configuration_error}
  defp input_count(value)

  defp input_count(value) when is_integer(value), do: {:ok, value}

  defp input_count(%Encoding{encoding: :primitive, type: :signed_integer, value: value})
       when is_integer(value), do: {:ok, value}

  defp input_count(%Encoding{encoding: :primitive, type: :unsigned_integer, value: value})
       when is_integer(value) and value >= 0, do: {:ok, value}

  defp input_count(_invalid), do: {:error, :configuration_error}

  @spec add_pulses(t(), non_neg_integer(), Context.t()) :: {:ok, t()} | {:error, term()}
  defp add_pulses(object, pulses, context)

  defp add_pulses(object, 0, _context), do: {:ok, object}

  defp add_pulses(object, pulses, context) do
    count = object.count + pulses

    with {:ok, _value} <- scaled_value(count, object.scale_factor, :count),
         {:ok, timestamp} <- timestamp(context) do
      {:ok, %{object | count: count, update_time: timestamp}}
    end
  end

  @spec update_present_value(t()) :: {:ok, t()} | {:error, term()}
  defp update_present_value(object)

  defp update_present_value(%__MODULE__{out_of_service: true} = object), do: {:ok, object}

  defp update_present_value(object) do
    with {:ok, value} <- scaled_value(object.count, object.scale_factor, :count) do
      {:ok, %{object | present_value: value}}
    end
  end

  @spec reconcile_reliability(t(), execution_state() | nil, source_state() | nil, Context.t()) ::
          {:ok, object :: t(),
           reliability_state :: %{
             physical_reliability: reliability_value(),
             manual_reliability: reliability_value()
           }}
          | {:error, term()}
  defp reconcile_reliability(object, previous, source, context) do
    with {:ok, object} <- ensure_reference_reliability(object, source) do
      if has_property?(object, :reliability) do
        physical = physical_reliability(object, previous, source, context)
        manual = manual_reliability(object, previous, context)

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

  @spec ensure_reference_reliability(t(), source_state() | nil) :: {:ok, t()} | {:error, term()}
  defp ensure_reference_reliability(object, source) do
    if source && not has_property?(object, :reliability),
      do: add_property(object, :reliability, :no_fault_detected),
      else: {:ok, object}
  end

  @spec physical_reliability(t(), execution_state() | nil, source_state() | nil, Context.t()) ::
          reliability_value()
  defp physical_reliability(object, previous, source, context)

  defp physical_reliability(_object, _previous, %{reliability: reliability}, _context),
    do: reliability

  defp physical_reliability(object, previous, nil, context) do
    if not object.out_of_service and
         (is_nil(previous) or Context.written_property(context) == :reliability) do
      object.reliability
    else
      case previous do
        %{source: %{}} -> :no_fault_detected
        %{physical_reliability: reliability} -> reliability
        nil -> nil
      end
    end
  end

  @spec manual_reliability(t(), execution_state() | nil, Context.t()) :: reliability_value()
  defp manual_reliability(object, previous, context) do
    cond do
      not object.out_of_service -> nil
      is_nil(previous) or Context.written_property(context) == :reliability -> object.reliability
      previous.out_of_service -> previous.manual_reliability
      true -> nil
    end
  end

  @spec timestamp(Context.t()) :: {:ok, BACnetDateTime.t()} | {:error, :invalid_wall_time}
  defp timestamp(context) do
    if context.now.year in 1900..2154,
      do: {:ok, BACnetDateTime.from_datetime(context.now)},
      else: {:error, :invalid_wall_time}
  end
end
