defmodule BACnet.Protocol.ObjectTypes.BinaryInput do
  @moduledoc """
  A Binary Input represents a two-state sensor or contact, such as a door switch
  or a pump run signal. Its Boolean `present_value` is the logical reading after
  applying `polarity`. Use `device_type` to describe the connected hardware.

  The object supports out-of-service simulation and reliability indication.
  Its core lifecycle applies polarity, maintains optional logical history and
  accumulates active seconds. It also evaluates intrinsic alarms when selected at creation.

  ### Object Description (ASHRAE 135)

  > The Binary Input object type defines a standardized object whose properties represent
  > the externally visible characteristics of a binary input.
  > A "binary input" is a physical device or hardware input that can be in only one of two distinct states.
  >
  > Binary Input objects that support intrinsic reporting shall apply the CHANGE_OF_STATE event algorithm.

  ### Behaviour and Operation

  Binary Input is the standard representation of a dry contact, run indication or limit
  switch. The host's sensor adapter reads the hardware. `set_input/2` builds a candidate
  from its raw Boolean sample: NORMAL preserves the sample and REVERSE inverts it.
  `active_text` and `inactive_text` describe those logical states for human consumption.
  The wire representation remains enumerated INACTIVE/ACTIVE.

  ### Lifecycle and host contract

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  is the integrating application or higher-level stack that retains objects and runtime
  state, serializes operations and supplies clocks, sensor samples and requested wakeups.
  This module starts no process, reads no clock and invokes no hardware or property callbacks.

  Initialize with `BACnet.Protocol.ObjectExecution.Lifecycle.execute/2`, `:initialization`
  and a fresh `BACnet.Protocol.ObjectExecution.Context`. Retain the full returned result.
  For a physical sample, call `set_input/2`, then
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3` with
  `{:application_write, :present_value, nil, nil}`. Commit the prepared candidate and execute
  with the same clocks and previous runtime state before exposing another operation.
  Deliver each accepted sample, including same-value samples, and retain every result's
  object, state and replacement wakeup. Property setters alone do not run history accounting.

  `set_input/2` retains the raw sample in `_metadata.physical_input`, not in a BACnet property.
  The existing `physical_input` creation option supplies an initial raw Boolean sample;
  nil means unknown. A nil sample through `set_input/2` marks the physical input unknown
  without inventing a new logical value. The host needs to supply physical reliability
  separately - absence of a sample does not infer a particular hardware fault here.

  ### Polarity and Interface_Value

  While in service, a polarity edit recomputes `present_value` from the retained sample.
  With no known sample, it inverts the previous logical value when polarity changes,
  without asserting knowledge of the physical input. While out of service, polarity
  does not alter the simulated `present_value`. Returning to service uses the latest
  retained sample when one is known. The host needs to supply a fresh sample/status if
  retained observations are insufficient for its application.

  The optional `interface_value` reports the physical input mapped through current
  polarity, even during out-of-service simulation. It is `:undefined` when the raw input is
  unknown, which encodes as BACnet NULL. A nil property value means the optional property
  is absent.
  It is read-only to BACnet clients and is maintained as a related property of input,
  polarity and out-of-service updates. `set_input/2` does not create the optional property -
  select it explicitly with `interface_value: :undefined` at creation, or pass `:undefined`
  to `add_property/3`.

  ### Out of service, simulation and reliability

  BACnet `present_value` writes use `{:property_write, property, index, priority}` and
  are rejected with `{:error, :write_access_denied}` while in service. Out of service,
  BACnet writes can simulate logical values. Write priority is ignored for this
  non-commandable object. The host still needs to enforce service permissions and indices.

  Physical samples may continue while out of service: `set_input/2` retains them and
  updates a selected Interface_Value, but preserves the simulated Present_Value. A local
  application candidate that changes the simulated value returns `{:error, :out_of_service}`.
  Explicit Reliability writes from either application or BACnet origin can simulate
  conditions while out of service, including same-value writes. The host needs to stop
  forwarding automatic hardware Reliability reports while decoupled. Origin alone does
  not distinguish an automatic report from intentional simulation.
  Logical history and active-time accounting continue to follow simulated Present_Value.

  `reliability_evaluation_inhibit` masks automatic reliability with `:no_fault_detected`,
  except for an explicitly supplied out-of-service simulation. The retained physical
  reliability becomes effective when inhibition ends or when returning to service, if known
  and evaluation is not inhibited.
  Physical reports received while inhibited are retained for that later evaluation.
  With no retained physical reliability, the current supplied value remains until a fresh
  report. Initialization treats a supplied out-of-service reliability value as initial
  simulation. Existing property mechanics keep the corresponding fault and OOS status flags
  synchronized. The host owns any local overridden indication and its hardware diagnosis.

  ### Logical history and active seconds

  The optional `change_of_state_time`, `change_of_state_count` and
  `time_of_state_count_reset` form one group. Every actual effective Present_Value
  transition increments the existing non-negative integer count and stamps device-local
  wall time. The count has no imposed wrap limit. Repeated identical samples do not count,
  but an in-service polarity change that changes Present_Value does.

  `elapsed_active_time` and `time_of_active_time_reset` form another optional group.
  Monotonic ACTIVE milliseconds accumulate into whole seconds, retaining fractions across
  inactive periods. The unsigned 32-bit seconds total wraps modulo 2^32 without a reset
  stamp. Zero writes to either total stamp its reset time, including repeated zero writes.
  Nonzero writes leave reset timestamps unchanged. Reset timestamps are writable and do
  not themselves clear totals. Replacing the active-time total clears its fractional part.

  Service the returned monotonic second-boundary wakeups while ACTIVE. Before computed
  reads, use `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2`, retain its result
  and call the getter. Wall-clock corrections affect timestamps, not elapsed durations.
  The host needs to deliver input transitions promptly - polling cannot recover transitions
  that were never supplied to the object.

  A complete physical-sample operation with supplied clocks:

      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> {:ok, object} = BACnet.Protocol.ObjectTypes.BinaryInput.create(7, "Contact", %{change_of_state_count: 0, interface_value: :undefined})
      iex> start = Context.new(:initialization, now: ~U[2026-11-08 10:00:00Z], monotonic_time: 0)
      iex> {:ok, stored} = Lifecycle.execute(object, start)
      iex> sample = Context.new({:application_write, :present_value, nil, nil}, now: ~U[2026-11-08 10:00:01Z], monotonic_time: 1000, state: stored.state)
      iex> {:ok, candidate} = BACnet.Protocol.ObjectTypes.BinaryInput.set_input(stored.object, true)
      iex> {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, sample)
      iex> {:ok, stored} = Lifecycle.execute(prepared, sample)
      iex> {stored.object.present_value, stored.object.interface_value, stored.object.change_of_state_count}
      {true, true, 1}

  The runnable walkthrough is `examples/objects_lifecycle/binary_input_lifecycle.exs`.


  ### Initialization and capability boundaries

  Initialization establishes a baseline from the current sample/value without fabricating
  a historical transition. Existing totals and reset timestamps are retained. Newly added
  history groups start accounting at that operation. After a VM restart, initialize with
  fresh clocks and runtime state. Invalid/cross-instance state or backwards monotonic time
  returns `{:error, :invalid_execution_state}` without a replacement result. Rejected writes
  leave the original object, state and wakeup unchanged and do not set a hardware fault.

  ### Intrinsic reporting

  Create a local Binary Input with `intrinsic_reporting: true` to evaluate
  CHANGE_OF_STATE against the logical `present_value` and `alarm_value`. Simulated
  values participate while out of service. Alarm and normal delays use monotonic
  time. The next wakeup covers the earliest reporting or history deadline.
  A condition that clears before its delay expires starts a fresh delay when it recurs.

  Reliability faults take precedence over the alarm condition. Fault recovery
  records a return to normal and requests an immediate reevaluation if the alarm
  condition still applies. `event_algorithm_inhibit` clears offnormal alarms and
  leaves fault detection active. A linked inhibit property is read through the host
  and keeps its last value if the read fails. The host needs to reevaluate when
  the linked property changes. Disabling `event_detection_enable` resets the
  reporting properties and cancels pending event delays.

  The host needs to call `transition/1` for each committed result, including
  intermediate results before immediate continuations. For an enabled transition
  with a routing plan, use the plan's recipients and priority to deliver
  `BACnet.Protocol.Services.ConfirmedEventNotification` or
  `BACnet.Protocol.Services.UnconfirmedEventNotification`. If the class lookup
  fails, the object still records the transition and timestamp. For an alarm
  acknowledgment, use `acknowledge/3` to match the timestamp and update the
  acknowledgment bit. The host handles the acknowledgment service and delivery.
  Remote snapshots remain passive and request no wakeup.

  ### Examples

  Creating a Binary Input with state texts:

      iex> {:ok, bi} = BACnet.Protocol.ObjectTypes.BinaryInput.create(5, "Door Contact", %{active_text: "Open", inactive_text: "Closed"}); bi.active_text
      "Open"

  Selecting an initial physical sample and the intrinsic property representation:

      iex> {:ok, bi} = BACnet.Protocol.ObjectTypes.BinaryInput.create(6, "RunStat", %{}, intrinsic_reporting: true, physical_input: true); is_boolean(bi.present_value)
      true

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.ChangeOfState`
  - `BACnet.Protocol.FaultAlgorithms.FaultState` (optional)
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetTimestamp
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EventAlgorithms
  alias BACnet.Protocol.ObjectExecution.BinaryState
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.IntrinsicReporting
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectsMacro

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Binary Input object.

  In addition to the common options, Binary Input supports:
  - `intrinsic_reporting` - Enables the CHANGE_OF_STATE reporting lifecycle.
  - `physical_input` - Initial raw Boolean sample retained in metadata, or nil when unknown.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()}
          | {:physical_input, boolean() | nil}
          | common_object_opts()

  @typedoc """
  Represents a Binary Input object. Treat struct fields as read-only. Use the object module's
  property functions to build updates.

  Create the object with `intrinsic_reporting: true` to select its intrinsic
  reporting properties. The fields for those properties are `nil` when omitted.

  Use `set_input/2` to supply a raw sample. In service, the object applies
  polarity and stores the logical reading in Present_Value. The raw sample is
  local application data. When selected, Interface_Value holds the
  polarity-adjusted sample, or `:undefined` (BACnet NULL) if it is unknown.
  """
  bac_object Constants.macro_assert_name(:object_type, :binary_input) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:device_type, String.t())
    field(:event_state, Constants.event_state(), required: true)
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean(), required: true)

    field(:present_value, boolean(),
      required: true,
      default: false,
      annotation: {:encode_as, :enumerated}
    )

    field(:polarity, Constants.polarity(), required: true, default: :normal)

    field(:interface_value, boolean() | :undefined,
      bac_type: {:type_list, [:boolean, {:literal, :undefined}]},
      readonly: true,
      annotation: [encoder: &encode_interface_value/1, decoder: &decode_interface_value/1],
      annotation: {:revision, 16}
    )

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:active_text, String.t(), default: "Active", implicit_relationship: :inactive_text)
    field(:inactive_text, String.t(), default: "Inactive")

    field(:change_of_state_time, BACnetDateTime.t(),
      implicit_relationship: :change_of_state_count,
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    field(:change_of_state_count, non_neg_integer(), default: 0)

    field(:time_of_state_count_reset, BACnetDateTime.t(),
      implicit_relationship: :change_of_state_count,
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    field(:elapsed_active_time, ApplicationTags.unsigned32(),
      implicit_relationship: :time_of_active_time_reset,
      default: 0
    )

    field(:time_of_active_time_reset, BACnetDateTime.t(),
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    # Intrinsic Reporting
    field(:alarm_value, boolean(),
      intrinsic: true,
      default: true,
      required: true,
      default: false,
      annotation: {:encode_as, :enumerated}
    )
  end

  @typep execution_state :: %{
           optional(:reporting) => IntrinsicReporting.state(),
           history: BinaryState.state(),
           polarity: Constants.polarity(),
           out_of_service: boolean(),
           physical_reliability: Constants.reliability() | nil,
           manual_reliability: Constants.reliability() | nil
         }

  @doc """
  Sets the physical input and writes to the present value property in respect to the polarity.

  If the object is out of service, the present value won't be updated.
  A nil sample marks the input unknown, preserves the present value and sets a selected
  `interface_value` to `:undefined` (BACnet NULL).
  """
  @spec set_input(t(), boolean() | nil) :: {:ok, t()} | {:error, term()}
  def set_input(object, value)

  def set_input(%__MODULE__{_metadata: %{remote_object: remote}}, _value)
      when not is_nil(remote), do: {:error, :operation_not_available_for_remote_objects}

  def set_input(%__MODULE__{} = object, value) when is_boolean(value) or is_nil(value) do
    candidate = %{object | _metadata: %{object._metadata | physical_input: value}}
    reconcile_input(candidate, nil)
  end

  @doc """
  Reports BACnet property writability. Present_Value requires out-of-service simulation.
  """
  @spec property_writable?(t(), Constants.property_identifier()) :: boolean()
  def property_writable?(object, property)

  def property_writable?(%__MODULE__{} = object, :present_value), do: object.out_of_service

  def property_writable?(%__MODULE__{} = object, property), do: super(object, property)

  @spec check_implicit_relationships(t(), :add | :remove) :: {:ok, t()} | {:error, term()}
  defp check_implicit_relationships(object, operation) do
    with {:ok, first} <- super(object, operation),
         {:ok, second} <- super(first, operation) do
      super(second, operation)
    end
  end

  @doc """
  Checks selected capabilities and retained input/history state without I/O.

  Local instances need initialization before other operations. Remote snapshots are passive.
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
  Prepares physical samples, simulation writes and related polarity/interface/reset updates.

  Physical samples use application-write triggers. BACnet Present_Value writes require
  out-of-service simulation. No runtime state, I/O or host storage is changed here.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec prepare_write(t(), t(), Context.t()) :: {:ok, t()} | {:error, term()}
  def prepare_write(original, candidate, context)

  def prepare_write(%__MODULE__{_metadata: %{remote_object: remote}}, _candidate, %Context{})
      when not is_nil(remote), do: {:error, :operation_not_available_for_remote_objects}

  def prepare_write(%__MODULE__{} = original, %__MODULE__{} = candidate, %Context{} = context) do
    with :ok <- validate_execution(original, context),
         :ok <- validate_configuration(candidate),
         :ok <- validate_write(original, candidate, context),
         {:ok, reconciled} <- reconcile_input(candidate, context.state) do
      BinaryState.prepare_write(
        reconciled,
        history_context(context),
        object_contract(),
        operation_hooks()
      )
    end
  end

  @doc """
  Reconciles input/polarity, maintains logical history and evaluates reliability inhibition.

  Retain the entire result before serving another operation and deliver its replacement
  monotonic wakeup. Physical input and reliability reports come from the host's adapter.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec execute(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  def execute(object, context)

  def execute(%__MODULE__{_metadata: %{remote_object: remote}} = object, %Context{} = context)
      when not is_nil(remote),
      do: {:ok, %Result{object: object, state: context.state, next_execution: nil}}

  def execute(%__MODULE__{} = object, %Context{} = context) do
    with :ok <- validate_execution(object, context),
         :ok <- validate_write(object, object, context),
         {:ok, reconciled} <- reconcile_input(object, Context.previous_state(context)),
         {:ok, reliable, reliability_state} <- reconcile_reliability(reconciled, context),
         {:ok, result} <-
           BinaryState.execute(
             reliable,
             history_context(context),
             object_contract(),
             operation_hooks()
           ) do
      state =
        Map.merge(reliability_state, %{
          history: result.state,
          polarity: reliable.polarity,
          out_of_service: reliable.out_of_service
        })

      {:ok,
       IntrinsicReporting.evaluate(
         %{result | state: state},
         context,
         EventAlgorithms.ChangeOfState,
         [
           :present_value
         ]
       )}
    end
  end

  @doc """
  Returns the transition from this execution result for host delivery after commit.
  """
  @spec transition(Result.t(t())) :: EventReporting.transition() | nil
  def transition(%Result{object: %__MODULE__{}} = result), do: EventReporting.transition(result)

  @doc """
  Acknowledges the current transition of the given kind after matching its timestamp.

  The host validates the acknowledged event state and delivers the acknowledgment
  notification as part of its BACnet service handling.
  """
  @spec acknowledge(t(), Constants.event_transition_bit(), BACnetTimestamp.t()) ::
          {:ok, t()} | {:error, term()}
  def acknowledge(object, transition, timestamp)

  def acknowledge(%__MODULE__{_metadata: %{remote_object: remote}}, _transition, _timestamp)
      when not is_nil(remote), do: {:error, :operation_not_available_for_remote_objects}

  def acknowledge(%__MODULE__{} = object, transition, %BACnetTimestamp{} = timestamp),
    do: EventReporting.acknowledge(object, transition, timestamp)

  @spec validate_configuration(t()) :: :ok | {:error, term()}
  defp validate_configuration(object) do
    if is_boolean(object._metadata.physical_input) or is_nil(object._metadata.physical_input),
      do: :ok,
      else: {:error, {:invalid_configuration, :physical_input}}
  end

  @spec validate_state(t(), Context.t()) :: :ok | {:error, :invalid_execution_state}
  defp validate_state(object, context)

  defp validate_state(_object, %Context{trigger: :initialization}), do: :ok

  defp validate_state(object, %Context{state: state} = context) do
    case state do
      %{
        history: history,
        polarity: polarity,
        out_of_service: out_of_service,
        physical_reliability: physical,
        manual_reliability: manual
      }
      when polarity in [:normal, :reverse] and is_boolean(out_of_service) ->
        if valid_reliability?(physical) and valid_reliability?(manual) and
             IntrinsicReporting.valid_state?(Map.get(state, :reporting)),
           do: BinaryState.validate(object, %{context | state: history}),
           else: {:error, :invalid_execution_state}

      _other ->
        {:error, :invalid_execution_state}
    end
  end

  @spec valid_reliability?(term()) :: boolean()
  defp valid_reliability?(value)

  defp valid_reliability?(nil), do: true

  defp valid_reliability?(value) when is_atom(value),
    do: match?({:ok, _value}, Constants.by_name(:reliability, value))

  defp valid_reliability?(_value), do: false

  @spec validate_write(t(), t(), Context.t()) :: :ok | {:error, term()}
  defp validate_write(original, candidate, context) do
    property = BinaryState.written_property(context)

    case context.trigger do
      {origin, _property, _index, _priority}
      when origin in [:property_write, :application_write] and
             property in [:event_state, :event_algorithm_inhibit] ->
        if property_writable?(original, property), do: :ok, else: {:error, :write_access_denied}

      {:property_write, _property, _index, _priority}
      when property == :present_value and not original.out_of_service ->
        {:error, :write_access_denied}

      {:application_write, _property, _index, _priority}
      when original.out_of_service and property == :present_value ->
        if candidate.present_value == context.state.history.value,
          do: :ok,
          else: {:error, :out_of_service}

      _other ->
        if property == :interface_value, do: {:error, :write_access_denied}, else: :ok
    end
  end

  @spec encode_interface_value(term()) ::
          {:ok, ApplicationTags.encoding()} | {:error, :invalid_value}
  defp encode_interface_value(value)

  defp encode_interface_value(:undefined), do: {:ok, {:null, nil}}

  defp encode_interface_value(value) when is_boolean(value),
    do: {:ok, {:enumerated, if(value, do: 1, else: 0)}}

  defp encode_interface_value(_value), do: {:error, :invalid_value}

  @spec decode_interface_value(Encoding.t()) ::
          {:ok, boolean() | :undefined} | {:error, :invalid_value}
  defp decode_interface_value(encoding)

  defp decode_interface_value(%Encoding{encoding: :primitive, type: :null, value: nil}),
    do: {:ok, :undefined}

  defp decode_interface_value(%Encoding{encoding: :primitive, type: :enumerated, value: value})
       when value in [0, 1],
       do: {:ok, value == 1}

  defp decode_interface_value(_encoding), do: {:error, :invalid_value}

  @spec history_context(Context.t()) :: Context.t()
  defp history_context(context) do
    previous = Context.previous_state(context)
    %{context | state: if(previous, do: previous.history)}
  end

  @spec reconcile_input(t(), execution_state() | nil) :: {:ok, t()} | {:error, term()}
  defp reconcile_input(object, previous) do
    sample = mapped_sample(object)

    value =
      cond do
        object.out_of_service -> object.present_value
        is_boolean(sample) -> sample
        previous && previous.polarity != object.polarity -> not previous.history.value
        true -> object.present_value
      end

    with {:ok, updated} <- update_property(object, :present_value, value) do
      if has_property?(updated, :interface_value),
        do: update_property(updated, :interface_value, sample),
        else: {:ok, updated}
    end
  end

  @spec mapped_sample(t()) :: boolean() | :undefined
  defp mapped_sample(object) do
    case object._metadata.physical_input do
      nil -> :undefined
      value -> if object.polarity == :reverse, do: not value, else: value
    end
  end

  @spec reconcile_reliability(t(), Context.t()) ::
          {:ok, t(),
           %{
             physical_reliability: Constants.reliability() | nil,
             manual_reliability: Constants.reliability() | nil
           }}
          | {:error, term()}
  defp reconcile_reliability(object, context) do
    if has_property?(object, :reliability) do
      previous = Context.previous_state(context)
      property = BinaryState.written_property(context)

      physical =
        cond do
          not object.out_of_service and (property == :reliability or is_nil(previous)) ->
            object.reliability

          previous ->
            previous.physical_reliability

          true ->
            nil
        end

      manual =
        cond do
          not object.out_of_service -> nil
          property == :reliability or is_nil(previous) -> object.reliability
          previous.out_of_service -> previous.manual_reliability
          true -> nil
        end

      base =
        if not object.out_of_service and not is_nil(physical),
          do: physical,
          else: object.reliability

      value =
        if Map.get(object, :reliability_evaluation_inhibit) do
          if object.out_of_service and not is_nil(manual), do: manual, else: :no_fault_detected
        else
          base
        end

      with {:ok, updated} <- update_property(object, :reliability, value) do
        {:ok, updated, %{physical_reliability: physical, manual_reliability: manual}}
      end
    else
      {:ok, object, %{physical_reliability: nil, manual_reliability: nil}}
    end
  end
end
