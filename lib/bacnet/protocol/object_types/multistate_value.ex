defmodule BACnet.Protocol.ObjectTypes.MultistateValue do
  @moduledoc """
  A Multistate Value represents an application mode, stage or sequence position.
  Its value is a state number between 1 and Number_Of_States. The application
  defines what each number means and can expose labels through `state_text`.

  Unlike an Input or Output object, this object has no prescribed hardware acquisition
  or output operation. Its value producer and consumer belong to the application.
  Optional commandability allows schedules, operators and control logic to compete for
  control through a priority array and relinquish default.

  ### Object Description (ASHRAE 135)

  > The Multi-state Value object type defines a standardized object whose properties
  > represent the externally visible characteristics of a multi-state value.
  > A "multi-state value" is a control system parameter residing in the memory of the
  > BACnet Device.
  >
  > Multi-state Value objects that support intrinsic reporting shall apply the CHANGE_OF_STATE event algorithm.

  ### Values and optional commandability

  `number_of_states` and `present_value` must be positive, and Present_Value cannot
  exceed Number_Of_States. A non-commandable instance accepts direct values through
  `update_property/3`. This implementation permits BACnet writes while in service as
  well as out of service. The host still needs to enforce its service permissions.

  Selecting `priority_array` or `relinquish_default` adds the other through their
  implicit relationship. The effective array value replaces any previous direct value.
  Removing the pair returns the object to direct value updates.

  For commandable instances, construct Present_Value writes with `set_priority/3`
  from either BACnet or application origin. The lowest numbered non-nil slot wins.
  `nil` relinquishes only that slot, revealing another command or Relinquish_Default.
  Masked commands remain stored. The host needs to pass priority 16 for a BACnet
  command without an explicit priority. Direct Present_Value updates are protected,
  including while out of service. Priority_Array is read-only to BACnet clients.

  Priority 6 is reserved for minimum on/off control. Multistate Value has no minimum
  on/off timer, and `set_priority/3` rejects commands and relinquishment at priority 6.
  Lifecycle preflight rejects a stored non-nil slot 6 with
  `{:error, {:invalid_configuration, :priority_6}}`. Other slots and Relinquish_Default
  must all remain within 1..Number_Of_States, even while masked.

  ### Out of service and write origin

  `out_of_service: true` isolates Present_Value from normal local software updates.
  Use `{:application_write, property, array_index, priority}` for that origin. Lifecycle
  preparation rejects local Present_Value writes while isolated, including same-value
  and masked commands. Indirect local changes to the effective value are also rejected.
  A masked configuration edit that leaves the effective value unchanged is allowed.
  Preparation checks both the original and candidate states - resume service before
  supplying the next local value in a separate operation.

  BACnet requests use `{:property_write, property, array_index, priority}` and remain
  available for simulation. Command arbitration continues while isolated. A local
  callback handling a BACnet request needs to preserve that BACnet origin. Named and
  numeric property identifiers are supported by lifecycle origin and priority checks.
  Returning to service preserves the effective value until another accepted write.

  ### State count and label changes

  For local objects, `update_property/3` synchronizes Number_Of_States and a selected
  State_Text array. Increasing the count retains existing labels and appends empty
  strings. Decreasing it truncates labels only if Present_Value, every stored priority
  command and Relinquish_Default still fit. State_Text updates must match the existing
  count and never change Number_Of_States. No labels are selected implicitly when the
  optional property is absent. The array retains its fixed/variable representation.

  The specification leaves value reconciliation after a count change to the implementation.
  This implementation rejects an invalidating reduction instead of clamping values or
  clearing commands. Reconcile values, priorities and the default first, then reduce the
  count. Rejection returns no partial object. Lifecycle preflight also rejects inconsistent
  count/value/label candidates with `{:error, {:invalid_configuration, property}}`.
  State_Text needs a string at every position - sparse unknown labels are rejected.

  Number_Of_States remains read-only to BACnet clients. The host needs to enforce that
  service access and turn supported indexed State_Text edits into a complete array
  before calling the property operation. An array element replacement can use
  `BACnet.Protocol.BACnetArray.set_item/3`. Updating a property does not execute its
  lifecycle or determine write origin.

  ### Lifecycle and host contract

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  is the integrating application or higher-level BACnet stack that retains object and
  runtime state, serializes operations and supplies their context. This module starts
  no process and invokes no host I/O callbacks.

  Initialize local objects with `BACnet.Protocol.ObjectExecution.Lifecycle.execute/2`
  and an `:initialization` context. Initialization preserves supplied direct values or
  effective commands and establishes the Reliability baseline. Retain the full result.
  For each write, construct a candidate through this module's property operations, call
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3`, commit the prepared object
  while retaining the previous runtime state, and execute with the same context before
  exposing the operation. Retain the complete result before the next operation.
  Deliver every accepted write, including same-value and masked commands.

  The host still needs to enforce service permissions, read-only annotations, array
  indices and BACnet priority rules. Preparation is pure. On error, retain the original
  object, runtime state and wakeup - no replacement result is supplied. Missing, malformed
  or other-instance state returns `{:error, :invalid_execution_state}`. Raw property
  operations do not perform lifecycle preparation or execution.

  Reads can use `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2`, retain its
  result, then call `get_property/2`. Every successful execution returns
  `next_execution: nil`. The host needs to cancel a superseded wakeup when retaining
  that result. This core behaviour has no periodic calculation or timing requirement.
  Wall-clock changes and monotonic time do not drive arithmetic here.

  ### Reliability and reporting

  The application supplies Reliability from the health of its value source, such as a
  failed calculation or missing dependency. A rejected write or configuration does not
  diagnose a source fault. Property propagation maintains FAULT from Reliability,
  IN_ALARM from the supplied Event_State and OUT_OF_SERVICE from Out_Of_Service.
  OVERRIDDEN remains a local indication for the host to supply when applicable.

  Reliability_Evaluation_Inhibit exposes NO_FAULT_DETECTED while true, except for an
  explicitly supplied or written out-of-service Reliability. The lifecycle retains the
  latest report for restoration when inhibition ends. Entering out of service alone
  does not expose an earlier suppressed report. Explicit Reliability simulation is
  accepted from both origins, including while inhibited. Returning to service while
  inhibited masks that simulation again. The host needs to isolate automatic source
  Reliability reports while simulating - application origin alone does not express intent.

  With `intrinsic_reporting: true`, CHANGE_OF_STATE compares Present_Value with
  Alarm_Values. FAULT_STATE uses Fault_Values when reliability evaluation is
  enabled. A reliability fault takes precedence over an alarm match. After
  retaining the result, the host retrieves transitions with
  `BACnet.Protocol.ObjectExecution.EventReporting.transition/1`.

  With Fault_Values configured, the algorithm supplies Reliability while
  evaluation is enabled. To retain an explicit out-of-service Reliability
  write, set Reliability_Evaluation_Inhibit to true before the write.

  ### Restart and remote snapshots

  After restart, initialize from restored properties with fresh context and runtime state.
  Supplied out-of-service Reliability is retained for simulation. A suppressed report
  held only in old runtime state cannot be recovered from a property exposing
  NO_FAULT_DETECTED - the application needs to supply a fresh report when necessary.

  Remote snapshots remain passive. Lifecycle execution preserves their object and
  context state without callbacks or wakeups. Local write preparation returns
  `{:error, :operation_not_available_for_remote_objects}`. Property synchronization
  described above applies to local objects.

  ### Complete write example

      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> {:ok, object} = BACnet.Protocol.ObjectTypes.MultistateValue.create(5, "Operating mode", %{number_of_states: 3, relinquish_default: 1})
      iex> start = Context.new(:initialization, now: ~U[2026-11-08 10:00:00Z], monotonic_time: 0)
      iex> {:ok, stored} = Lifecycle.execute(object, start)
      iex> command = Context.new({:application_write, :present_value, nil, 16}, now: start.now, monotonic_time: 0, state: stored.state)
      iex> {:ok, candidate} = BACnet.Protocol.ObjectTypes.MultistateValue.set_priority(stored.object, 16, 2)
      iex> {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, command)
      iex> stored = %{stored | object: prepared}
      iex> {:ok, stored} = Lifecycle.execute(stored.object, command)
      iex> {stored.object.present_value, stored.next_execution}
      {2, nil}

  A runnable walkthrough is `examples/objects_lifecycle/multistate_value_lifecycle.exs`.

  ### Examples

  Creating a minimal Multistate Value:

      iex> {:ok, mv} = BACnet.Protocol.ObjectTypes.MultistateValue.create(5, "ModeSel", %{present_value: 1}); mv.present_value
      1

  Selecting intrinsic reporting properties:

      iex> {:ok, mv} = BACnet.Protocol.ObjectTypes.MultistateValue.create(6, "Flag", %{present_value: 1}, intrinsic_reporting: true); mv.object_name
      "Flag"

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.ChangeOfState`
  - `BACnet.Protocol.FaultAlgorithms.FaultState`
  """

  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EventAlgorithms
  alias BACnet.Protocol.FaultAlgorithms
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.IntrinsicReporting
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectOperations
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Multistate Value object.

  In addition to the common options, Multistate Value supports:
  - `intrinsic_reporting` - Selects CHANGE_OF_STATE reporting and enables evaluation during execution.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents a Multistate Value object. Treat fields as read-only. Construct changes
  through this module's property operations, then drive the lifecycle.

  Create the object with `intrinsic_reporting: true` to select its intrinsic
  reporting properties. The fields for those properties are `nil` when omitted.

  For a commandable instance, use `set_priority/3` to change the effective
  Present_Value.
  """
  bac_object Constants.macro_assert_name(:object_type, :multi_state_value) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:device_type, String.t())
    field(:event_state, Constants.event_state(), required: true)
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean(), required: true)

    field(:present_value, pos_integer(),
      required: true,
      default: 1,
      validator_fun: &(&1 <= (&2[:number_of_states] || -1))
    )

    field(:priority_array, PriorityArray.t(pos_integer()), readonly: true)

    field(:relinquish_default, pos_integer(),
      validator_fun: &(&1 <= (&2[:number_of_states] || -1)),
      default: 1
    )

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:fault_values, [non_neg_integer()],
      default: [],
      implicit_relationship: :reliability
    )

    field(:number_of_states, pos_integer(), required: true, readonly: true, default: 1)

    field(:state_text, BACnetArray.t(String.t(), pos_integer()),
      validator_fun: &(BACnetArray.size(&1) == (&2[:number_of_states] || -1))
    )

    # Intrinsic Reporting
    field(:alarm_values, [non_neg_integer()], intrinsic: true, default: [])
  end

  @doc """
  Updates a property, synchronizing the state count and selected state-text array.

  Growing Number_Of_States preserves existing labels and appends empty strings. Shrinking
  truncates labels only when Present_Value, every priority slot and Relinquish_Default
  remain valid. State_Text updates must match the existing Number_Of_States and never
  change it. Rejections return no partial object. Number_Of_States remains read-only
  to BACnet clients - the host needs to enforce service permissions.

  This property operation does not run lifecycle preparation or enforce write origin.
  """
  @spec update_property(t(), atom(), term()) :: {:ok, t()} | {:error, term()}
  def update_property(object, property, value)

  def update_property(
        %__MODULE__{_metadata: %{remote_object: nil}} = object,
        :number_of_states,
        value
      ) do
    with {:ok, updated} <- super(object, :number_of_states, value),
         :ok <- validate_state_text(object),
         updated = resize_state_text(updated),
         :ok <- validate_configuration(updated) do
      {:ok, updated}
    end
  end

  def update_property(%__MODULE__{} = object, property, value), do: super(object, property, value)

  @typep reliability_value :: Constants.reliability() | non_neg_integer() | nil

  @doc """
  Checks state ranges, selected labels, the reserved priority and runtime state without I/O.

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
       IntrinsicReporting.evaluate(
         result,
         context,
         EventAlgorithms.ChangeOfState,
         [:present_value],
         FaultAlgorithms.FaultState
       )}
    end
  end

  @spec validate_configuration(t()) :: :ok | {:error, term()}
  defp validate_configuration(object) do
    properties =
      [:number_of_states, :present_value] ++
        Enum.filter([:priority_array, :relinquish_default], &has_property?(object, &1))

    with :ok <- validate_configuration_properties(object, properties),
         :ok <- validate_state_text(object) do
      if has_priority_array?(object) and not is_nil(object.priority_array.priority_6),
        do: {:error, {:invalid_configuration, :priority_6}},
        else: :ok
    end
  end

  @spec validate_configuration_properties(t(), [atom()]) :: :ok | {:error, term()}
  defp validate_configuration_properties(object, properties) do
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
        {:error, _reason} -> {:halt, {:error, {:invalid_configuration, property}}}
      end
    end)
  end

  @spec validate_state_text(t()) :: :ok | {:error, {:invalid_configuration, :state_text}}
  defp validate_state_text(object) do
    case object.state_text do
      %BACnetArray{} = text ->
        valid =
          BACnetArray.size(text) == object.number_of_states and
            Enum.all?(1..BACnetArray.size(text)//1, fn index ->
              case BACnetArray.get_item(text, index) do
                {:ok, label} -> is_binary(label)
                :error -> false
              end
            end)

        if valid, do: :ok, else: {:error, {:invalid_configuration, :state_text}}

      _other ->
        :ok
    end
  end

  @spec resize_state_text(t()) :: t()
  defp resize_state_text(object) do
    case object.state_text do
      %BACnetArray{} = text ->
        labels =
          Enum.map(1..object.number_of_states//1, fn index ->
            case BACnetArray.get_item(text, index) do
              {:ok, label} -> label
              :error -> ""
            end
          end)

        %{
          object
          | state_text: BACnetArray.from_list(labels, BACnetArray.fixed_size?(text))
        }

      _other ->
        object
    end
  end

  @spec validate_state(t(), Context.t()) :: :ok | {:error, :invalid_execution_state}
  defp validate_state(object, context)

  defp validate_state(_object, %Context{trigger: :initialization}), do: :ok

  defp validate_state(object, %Context{state: state}) do
    valid =
      case state do
        %{
          identifier: %ObjectIdentifier{type: :multi_state_value} = identifier,
          value: value,
          out_of_service: out_of_service,
          reported_reliability: reported,
          manual_reliability: manual
        } ->
          identifier == get_object_identifier(object) and
            (is_integer(value) and value > 0) and is_boolean(out_of_service) and
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
