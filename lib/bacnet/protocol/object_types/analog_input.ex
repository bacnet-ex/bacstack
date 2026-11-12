defmodule BACnet.Protocol.ObjectTypes.AnalogInput do
  @moduledoc """
  The Analog Input object is the primary BACnet object type for exposing continuous
  sensor measurements such as temperature, pressure, flow, humidity, current, voltage,
  or any other physical analog quantity. Supply the reading in the engineering units
  given by `units`. The object exposes it through `present_value` and can report
  the sensor's range, resolution, update interval and reliability.

  Use `min_present_value` and `max_present_value` to set the range,
  `resolution` for the smallest recognizable change and `update_interval`
  for the advertised acquisition interval.

  The object carries a COV threshold (`cov_increment`) and can expose OUT_OF_RANGE
  reporting properties with `intrinsic_reporting: true`, including `high_limit`,
  `low_limit` and `deadband`. Core lifecycle execution handles supplied readings and
  reliability - event detection, subscriptions and notification delivery remain separate.

  ### Object Description (ASHRAE 135)

  > The Analog Input object type defines a standardized object whose properties represent
  > the externally visible characteristics of an analog input.
  >
  > Analog Input objects that support intrinsic reporting shall apply the OUT_OF_RANGE
  > event algorithm.

  ### Behaviour and Operation

  Analog Input exposes a measurement in the engineering units declared by `units`.
  The host's driver acquires the sensor value, applies any scaling, calibration or
  filtering, and supplies the resulting REAL through `set_input/2` and the
  application-write lifecycle. BACnet does not prescribe that acquisition or conversion
  algorithm. This module does not read hardware or convert units.

  Analog Input is not commandable. Present_Value has no priority array and an explicit
  write priority is ignored. The host can expose the reading and status to BACnet clients.
  `property_writable?/2` reports Present_Value writable only while out of service - other
  properties retain their generated access hints. Raw property setters remain available
  to the local application and do not distinguish BACnet requests from sensor updates.

  ### Physical observations and Interface_Value

  The optional, read-only `interface_value` exposes the physical input in engineering
  units independently of Present_Value simulation. Select it explicitly at creation with
  `interface_value: :undefined` or a known REAL, or with `add_property/3`. A nil creation
  value omits the property. `:undefined` is a selected unknown value and encodes as BACnet
  NULL - known readings encode as REAL through this module's property annotations.

  `set_input/2` constructs a physical-observation candidate. In service, a known value
  updates Present_Value and a selected Interface_Value. Out of service, it updates only
  a selected Interface_Value, preserving the simulated Present_Value. `:undefined`
  marks the physical value unknown without inventing a new Present_Value or Reliability.
  The helper never selects the optional property implicitly. Without that property,
  out-of-service observations are not retained in the object.

  Prepare and execute the candidate using an application-write Present_Value context.
  The helper performs no lifecycle execution or I/O itself. Existing Present_Value range
  validation applies in service - an error returns no partial object. Interface_Value
  reports the supplied physical REAL independently of Present_Value's min/max validator
  during out-of-service simulation. Initialization preserves supplied property values
  without inferring a physical observation from Present_Value.

  Ordinary Present_Value writes do not update Interface_Value. Use `update_property/3`
  for explicit simulation and `set_input/2` for physical readings. Local adapters may
  report Interface_Value alone through an application-write context for that property.
  BACnet writes to Interface_Value are rejected in either service state, including
  numeric property identifiers.

  ### Lifecycle and host contract

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  is the integrating application or higher-level BACnet stack that owns object instances,
  retains their runtime state and serializes operations. It supplies engineering readings,
  hardware Reliability reports and the context for each operation. This module starts no
  process and invokes no host I/O callbacks.

  Initialize with `BACnet.Protocol.ObjectExecution.Lifecycle.execute/2` and an
  `:initialization` context. Initialization preserves the supplied Present_Value and
  establishes Reliability state from the object's properties. It does not acquire a
  fresh measurement. Retain the complete result for that instance.

  For every accepted write, build a candidate through this module's property operations,
  call `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3`, commit the prepared
  object while retaining the previous runtime state, then execute with the same context
  before exposing the operation. Retain the returned object, state and replacement wakeup.
  Deliver every accepted write, including same-value writes. Raw setters do not perform
  lifecycle preparation or execution.

  The host still needs to enforce service permissions, read-only annotations and array
  indices. Preparation is pure. Rejected writes leave the original object, runtime state
  and wakeup unchanged. Missing, malformed or other-instance runtime state returns
  `{:error, :invalid_execution_state}` - initialize local instances before other operations.
  An error supplies no replacement result and does not diagnose a sensor failure.

  ### In-service readings and write origin

  Use `{:application_write, property, array_index, priority}` for local readings and
  `{:property_write, property, array_index, priority}` for BACnet requests. A local
  callback handling a BACnet request needs to retain the BACnet origin. Lifecycle
  preparation and execution reject in-service BACnet Present_Value writes with
  `{:error, :write_access_denied}`, including same-value writes. Preparation checks both
  the original and final candidate's Out_Of_Service state. Named and numeric identifiers
  are supported for these checks.

  In-service application readings are accepted. The existing range validator applies
  when both `min_present_value` and `max_present_value` are present. A nil or otherwise
  invalid reading is rejected through the property API. The lifecycle does not infer
  `:no_sensor`, `:over_range` or another hardware diagnosis from that rejection - the
  adapter needs to supply Reliability from its own diagnosis. Existing REAL special
  values remain supported. No rounding or automatic clamping is introduced.

  ### Out-of-service simulation and resumption

  When `out_of_service` is true, Present_Value and Reliability are decoupled from the
  physical input. The host needs to stop forwarding automatic hardware updates to those
  properties. Explicit simulation writes from either BACnet or application origin are
  accepted, including same-value writes. Origin alone does not identify whether a local
  write is an automatic report or deliberate simulation.

  Returning to service preserves Present_Value until the host supplies a fresh reading.
  The lifecycle neither invents a measurement nor restores an older reading. The host
  needs to deliver current sensor data before presenting a value as a fresh live sample.
  A selected Interface_Value can continue to expose physical observations during
  simulation. A fresh `set_input/2` call updates both values after resumption. No raw
  sensor metadata, polarity mapping or hardware acquisition state is introduced.

  ### Reliability and status flags

  Supply `reliability` from the sensor/driver's diagnosis while in service. The lifecycle
  retains these reports separately from explicitly simulated out-of-service Reliability.
  Returning to service restores a retained physical report when known. If initialization
  began out of service and no physical report is known, the supplied Reliability remains
  until a fresh report, subject to inhibition. The host needs to refresh hardware status
  when retained observations are insufficient for its application.

  `reliability_evaluation_inhibit` exposes NO_FAULT_DETECTED while true, except for an
  explicitly supplied or written out-of-service Reliability. In-service reports received
  while inhibited are retained and become effective when inhibition ends. Entering out
  of service alone does not expose an earlier suppressed report. Explicit simulation is
  accepted from either origin while inhibited. Returning to service masks simulation
  again when inhibition remains enabled.

  Property propagation maintains FAULT from Reliability, IN_ALARM from the supplied
  Event_State and OUT_OF_SERVICE from Out_Of_Service. Removing Reliability clears FAULT
  during execution. OVERRIDDEN remains a local indication for the host to supply when
  applicable. These property updates do not execute event or fault algorithms.

  ### Acquisition timing and Update_Interval

  When present, `update_interval` describes the maximum period between Present_Value
  updates in hundredths of a second while in service and not overridden. For example,
  100 means one second. It describes the acquisition behaviour that the host needs to
  provide - it is not an instruction to this lifecycle to poll the sensor. A driver may
  use polling or pushed observations and needs to meet its advertised maximum interval.
  This module creates no acquisition timer and infers no stale-sensor fault from elapsed
  time. The `resolution` and `device_type` properties can describe the sensor's precision
  and hardware without implementing calibration or acquisition themselves.

  Before a read, use `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2`, retain
  its result, then use `get_property/2`. This refreshes lifecycle-derived status but does
  not acquire a new measurement. An active reporting delay can request a
  monotonic wakeup. The host replaces its previous request when retaining each result.

  ### Restart, reporting and representation boundaries

  After a restart, initialize from restored object properties with fresh context and
  runtime state. Present_Value is preserved. Supplied in-service Reliability seeds the
  physical report, while supplied out-of-service Reliability seeds simulation. A
  suppressed report held only in old runtime state cannot be recovered from a property
  exposing NO_FAULT_DETECTED - supply a fresh driver report when needed.

  With `intrinsic_reporting: true`, execution evaluates OUT_OF_RANGE using the
  engineering value and enabled limits. Reliability faults take precedence.
  Event and recovery delays use monotonic time. The host retrieves transitions with
  `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after retaining the result.
  `cov_increment` represents the COV threshold for the host's subscriptions and delivery.

  ### Complete reading example

  This example supplies an engineering reading and retains its result. The read returns
  the supplied value without performing hardware acquisition.

      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> {:ok, object} = BACnet.Protocol.ObjectTypes.AnalogInput.create(50, "Room temperature", %{present_value: 21.5, interface_value: :undefined, units: :degrees_celsius, update_interval: 100})
      iex> start = Context.new(:initialization, now: ~U[2026-11-08 10:00:00Z], monotonic_time: 0)
      iex> {:ok, stored} = Lifecycle.execute(object, start)
      iex> reading = Context.new({:application_write, :present_value, nil, nil}, now: ~U[2026-11-08 10:00:01Z], monotonic_time: 1000, state: stored.state)
      iex> {:ok, candidate} = BACnet.Protocol.ObjectTypes.AnalogInput.set_input(stored.object, 22.0)
      iex> {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, reading)
      iex> stored = %{stored | object: prepared}
      iex> {:ok, stored} = Lifecycle.execute(stored.object, reading)
      iex> {BACnet.Protocol.ObjectTypes.AnalogInput.get_property(stored.object, :present_value), stored.object.interface_value, stored.next_execution}
      {{:ok, 22.0}, 22.0, nil}

  A runnable driver/simulation walkthrough is
  `examples/objects_lifecycle/analog_input_lifecycle.exs`.

  ### Examples

  Creating a simple Analog Input (minimal properties):

      iex> {:ok, ai} = BACnet.Protocol.ObjectTypes.AnalogInput.create(1, "Room Temp", %{units: :degrees_celsius}); ai.units
      :degrees_celsius

  Selecting intrinsic reporting properties:

      iex> {:ok, ai} = BACnet.Protocol.ObjectTypes.AnalogInput.create(2, "Pressure", %{
      ...>   units: :pascals
      ...> }, intrinsic_reporting: true); ai.high_limit != nil
      true

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.OutOfRange`
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EventAlgorithms
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.IntrinsicReporting
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectOperations
  alias BACnet.Protocol.ObjectsUtility

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring an Analog Input object.

  In addition to the common options, `intrinsic_reporting` selects the OUT_OF_RANGE
  reporting properties and enables evaluation during execution.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents an Analog Input object. Treat fields as read-only. Construct updates through
  this module's property operations or `set_input/2`, then drive the lifecycle.

  Create the object with `intrinsic_reporting: true` to select its intrinsic
  reporting properties. The fields for those properties are `nil` when omitted.
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
      validator_fun: &ObjectsUtility.validate_float_range/2
    )

    field(:interface_value, float() | :undefined,
      bac_type: {:type_list, [:real, {:literal, :undefined}]},
      readonly: true,
      annotation: [encoder: &encode_interface_value/1, decoder: &decode_interface_value/1],
      annotation: {:revision, 16}
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

    # COV Reporting
    field(:cov_increment, float(), cov: true, default: 0.1)

    # Intrinsic Reporting
    field(:deadband, float(), intrinsic: true, default: 0.0)
    field(:high_limit, float(), intrinsic: true, default: 0.0)
    field(:low_limit, float(), intrinsic: true, default: 0.0)
  end

  @typep reliability_value :: Constants.reliability() | non_neg_integer() | nil

  @doc """
  Builds a physical engineering-reading candidate without running its lifecycle.

  A known reading updates Present_Value while in service and a selected Interface_Value
  in either service state. Out of service, the simulated Present_Value is preserved.
  `:undefined` marks the physical value unknown without changing Present_Value or inferring
  Reliability. The optional Interface_Value is never selected implicitly.

  Prepare and execute the candidate with an application-write Present_Value context before
  exposing it. On error, no partial object is returned. Remote snapshots cannot receive input.
  """
  @spec set_input(t(), ApplicationTags.ieee_float() | :undefined) :: {:ok, t()} | {:error, term()}
  def set_input(object, value)

  def set_input(%__MODULE__{_metadata: %{remote_object: remote}}, _value)
      when not is_nil(remote), do: {:error, :operation_not_available_for_remote_objects}

  def set_input(%__MODULE__{} = object, value) do
    with :ok <-
           ObjectOperations.check_property_value(
             object_contract(),
             object,
             :interface_value,
             value,
             false,
             false
           ),
         {:ok, observed} <- update_interface_value(object, value) do
      if object.out_of_service or value == :undefined,
        do: {:ok, observed},
        else: update_property(observed, :present_value, value)
    end
  end

  @doc """
  Reports BACnet property writability, requiring out of service for Present_Value.

  This service-access hint does not prevent the local application from constructing
  an in-service reading through `update_property/3` and the application-write lifecycle.
  """
  @spec property_writable?(t(), Constants.property_identifier()) :: boolean()
  def property_writable?(object, property)

  def property_writable?(%__MODULE__{} = object, :present_value), do: object.out_of_service

  def property_writable?(%__MODULE__{} = object, property), do: super(object, property)

  @doc """
  Checks retained per-instance runtime state without acquiring a physical input.

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
    validate_state(object, context)
  end

  @doc """
  Checks BACnet or application write candidates before commit.

  BACnet Present_Value writes require out of service. Application readings are accepted
  in service. Explicit out-of-service Present_Value and Reliability simulation accepts
  either origin. The host needs to keep automatic Present_Value/Reliability updates
  decoupled - `set_input/2` can still update a selected Interface_Value. BACnet writes
  to Interface_Value are rejected in either service state. No state or I/O is changed
  during preparation.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec prepare_write(t(), t(), Context.t()) :: {:ok, t()} | {:error, term()}
  def prepare_write(original, candidate, context)

  def prepare_write(%__MODULE__{_metadata: %{remote_object: remote}}, _candidate, %Context{})
      when not is_nil(remote), do: {:error, :operation_not_available_for_remote_objects}

  def prepare_write(%__MODULE__{} = original, %__MODULE__{} = candidate, %Context{} = context) do
    with :ok <- validate_execution(original, context),
         :ok <- validate_write(original, context),
         :ok <- validate_write(candidate, context) do
      {:ok, candidate}
    end
  end

  @doc """
  Maintains supplied engineering values, physical reliability and reliability inhibition.

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
          out_of_service: updated.out_of_service
        })

      result = %Result{object: updated, state: state, next_execution: nil}

      {:ok,
       IntrinsicReporting.evaluate(result, context, EventAlgorithms.OutOfRange, [:present_value])}
    end
  end

  @spec validate_state(t(), Context.t()) :: :ok | {:error, :invalid_execution_state}
  defp validate_state(object, context)

  defp validate_state(_object, %Context{trigger: :initialization}), do: :ok

  defp validate_state(object, %Context{state: state}) do
    valid =
      case state do
        %{
          identifier: %ObjectIdentifier{type: :analog_input} = identifier,
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

  @spec validate_write(t(), Context.t()) :: :ok | {:error, :write_access_denied}
  defp validate_write(object, context) do
    case {context.trigger, Context.written_property(context)} do
      {{:property_write, _property, _index, _priority}, :interface_value} ->
        {:error, :write_access_denied}

      {{:property_write, _property, _index, _priority}, :present_value}
      when not object.out_of_service ->
        {:error, :write_access_denied}

      _other ->
        :ok
    end
  end

  @spec update_interface_value(t(), ApplicationTags.ieee_float() | :undefined) ::
          {:ok, t()} | {:error, term()}
  defp update_interface_value(object, value) do
    if has_property?(object, :interface_value),
      do: update_property(object, :interface_value, value),
      else: {:ok, object}
  end

  @spec encode_interface_value(term()) ::
          {:ok, ApplicationTags.encoding()} | {:error, :invalid_value}
  defp encode_interface_value(value)

  defp encode_interface_value(:undefined), do: {:ok, {:null, nil}}

  defp encode_interface_value(value) when is_float(value) or value in [:NaN, :inf, :infn],
    do: {:ok, {:real, value}}

  defp encode_interface_value(_value), do: {:error, :invalid_value}

  @spec decode_interface_value(Encoding.t()) ::
          {:ok, ApplicationTags.ieee_float() | :undefined} | {:error, :invalid_value}
  defp decode_interface_value(encoding)

  defp decode_interface_value(%Encoding{encoding: :primitive, type: :null, value: nil}),
    do: {:ok, :undefined}

  defp decode_interface_value(%Encoding{encoding: :primitive, type: :real, value: value})
       when is_float(value) or value in [:NaN, :inf, :infn],
       do: {:ok, value}

  defp decode_interface_value(_encoding), do: {:error, :invalid_value}

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
