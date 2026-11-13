defmodule BACnet.Protocol.ObjectTypes.MultistateOutput do
  @moduledoc """
  A Multistate Output commands a device with a fixed set of states, such as
  a fan with several speeds. The effective command in `present_value`
  is a state number between 1 and Number_Of_States. Optional `state_text`
  entries give each state a label.

  ### Object Description (ASHRAE 135)

  > The Multi-state Output object type defines a standardized object whose properties
  > represent the desired state of one or more physical outputs or processes within
  > the BACnet Device in which the object resides.
  >
  > Multi-state Output objects that support intrinsic reporting shall apply the COMMAND_FAILURE event algorithm.

  ### Commands and physical output

  Present_Value reflects the highest-priority active command or Relinquish_Default.
  Use `set_priority/3` to write Present_Value. A nil value relinquishes the slot
  and exposes the next command or the default. The host needs to use priority 16
  when a BACnet command omits its priority. Priority 6 is reserved for minimum
  on/off control and is unavailable for this object. Lifecycle preflight rejects a
  stored command at priority 6. Priority_Array is read-only to BACnet clients.

  Commands from either origin continue to arbitrate during out-of-service simulation.
  The host needs to isolate the physical output while Out_Of_Service is true. In
  service, it can use `get_output/2` to obtain the command to apply. While out of
  service, the helper returns a caller-supplied fallback, defaulting to 1. The host
  chooses the isolation policy for its equipment. On resumption it can apply the
  effective command, including commands received during simulation.

  ### Feedback and physical observations

  Supply measured Feedback_Value independently through an application write.
  Feedback_Value is optional and selected automatically for intrinsic reporting.
  During simulation, lifecycle preparation rejects application Feedback_Value
  writes. BACnet writes can supply simulated feedback subject to host permissions.
  With `auto_write_feedback: true`, Feedback_Value models a command-following
  output, including during simulation. The lifecycle rejects direct writes to
  modeled feedback.

  Optional Interface_Value exposes the observed physical state independently of
  the command and Feedback_Value, including during simulation. Select it explicitly
  with a state in 1..Number_Of_States or `:undefined`. An unknown observation
  encodes as BACnet NULL. A known observation encodes as Unsigned. A local adapter
  can report it through `update_property/3` and the application-write lifecycle.
  BACnet writes are rejected.

  ### State count and labels

  Local changes to Number_Of_States resize a selected State_Text array. Growth
  preserves labels and appends empty strings. Shrinking truncates labels only if
  the command, every stored priority, the default and any known Interface_Value
  remain valid. Reconcile those values before reducing the count. A rejected
  reduction returns no partial object. A State_Text replacement must match the
  current count. The host needs to enforce Number_Of_States read-only access
  for BACnet requests.

  ### Lifecycle and reliability

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  owns instances, serializes operations and retains their runtime state. Initialize
  with `BACnet.Protocol.ObjectExecution.Lifecycle.execute/2` and an `:initialization`
  context. Build each write candidate with `set_priority/3` or `update_property/3`.
  Use `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3` before committing
  the candidate, then execute with the same context and previous runtime state.
  Retain the complete result before exposing the write or applying a command.
  Use an `:application_write` trigger for driver reports and a `:property_write`
  trigger for BACnet requests, including requests handled locally.

  The host needs to supply Reliability from its driver and suppress automatic
  Reliability reports while the output is isolated. Either write origin can supply
  explicit simulated Reliability. Reliability_Evaluation_Inhibit masks physical
  reports while retaining the latest one. Explicit out-of-service simulation can
  override the mask. Returning to service restores a known physical report,
  subject to inhibition. FAULT follows exposed Reliability, IN_ALARM follows
  Event_State and OUT_OF_SERVICE follows Out_Of_Service. OVERRIDDEN is local.

  Execute after restart using restored properties and fresh runtime state.
  Suppressed reports held only in old runtime state need to be reported again.
  Use `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` to refresh
  derived properties before reading. An active reporting delay can request a monotonic wakeup.
  The host needs to cancel any superseded request. Remote snapshots remain passive.

  With `intrinsic_reporting: true`, COMMAND_FAILURE compares the effective
  command and Feedback_Value. The host retrieves transitions with
  `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after retaining
  the result.
  The core lifecycle performs command arbitration and reliability handling without
  running event or fault algorithms, sending notifications or invoking hardware I/O.

  The runnable driver walkthrough is
  `examples/objects_lifecycle/multistate_output_lifecycle.exs`.

  ### Examples

  Creating a minimal Multistate Output:

      iex> {:ok, mo} = BACnet.Protocol.ObjectTypes.MultistateOutput.create(3, "Valve", %{priority_array: %BACnet.Protocol.PriorityArray{}, relinquish_default: 1}); mo.present_value
      1

  Using special options:

      iex> {:ok, mo} = BACnet.Protocol.ObjectTypes.MultistateOutput.create(4, "Mode", %{priority_array: %BACnet.Protocol.PriorityArray{}, relinquish_default: 1}, auto_write_feedback: true, intrinsic_reporting: true); mo.object_name
      "Mode"

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.CommandFailure`
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
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
  Options accepted when creating or configuring a Multistate Output object.

  In addition to the common options, Multistate Output supports:
  - `auto_write_feedback` - Selects feedback that models the effective command.
  - `intrinsic_reporting` - Selects COMMAND_FAILURE reporting properties.
  """
  @type object_opts ::
          {:auto_write_feedback, boolean()}
          | {:intrinsic_reporting, boolean()}
          | common_object_opts()

  @typedoc """
  Represents a Multistate Output object. Treat fields as read-only. Use
  `set_priority/3` for commands and `update_property/3` for property changes,
  then drive the lifecycle. Use `get_output/2` to obtain the command or fallback
  to pass to the physical adapter.
  """
  bac_object Constants.macro_assert_name(:object_type, :multi_state_output) do
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

    field(:interface_value, pos_integer() | :undefined,
      bac_type: {:type_list, [:unsigned_integer, {:literal, :undefined}]},
      readonly: true,
      validator_fun: &valid_interface_value?/2,
      annotation: [encoder: &encode_interface_value/1, decoder: &decode_interface_value/1],
      annotation: {:revision, 16}
    )

    field(:priority_array, PriorityArray.t(pos_integer()), required: true, readonly: true)

    field(:relinquish_default, pos_integer(),
      required: true,
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

    field(:feedback_value, pos_integer(),
      default: 1,
      annotation: [
        required_when: fn _properties, metadata ->
          metadata.intrinsic_reporting or metadata.other[:auto_write_feedback] == true
        end
      ]
    )

    # Intrinsic Reporting
    field(:alarm_values, [non_neg_integer()], intrinsic: true, default: [])
  end

  @doc """
  Get the logical state of the object from the present value property.

  If the object is out of service, then the `decoupled_output_state` is returned.
  The specification specifies that when the object is out of service, then the physical output
  is decoupled from the BACnet present value. The actual physical output state can then either
  hold its last value, go to a safe state or behaves according to local logic (-> defined as local matter).
  The default value is `1` - the safe state of physical outputs in typical environments.
  """
  @doc group: "Functions Operational"
  @spec get_output(t(), pos_integer()) :: pos_integer()
  def get_output(%__MODULE__{} = object, decoupled_output_state \\ 1)
      when is_integer(decoupled_output_state) and decoupled_output_state >= 1 do
    if object.out_of_service do
      decoupled_output_state
    else
      object.present_value
    end
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

  @spec valid_interface_value?(non_neg_integer() | :undefined, map()) :: boolean()
  defp valid_interface_value?(value, object) do
    value == :undefined or (value > 0 and value <= (object[:number_of_states] || -1))
  end

  @spec encode_interface_value(term()) ::
          {:ok, ApplicationTags.encoding()} | {:error, :invalid_value}
  defp encode_interface_value(value)

  defp encode_interface_value(:undefined), do: {:ok, {:null, nil}}

  defp encode_interface_value(value) when is_integer(value) and value > 0,
    do: {:ok, {:unsigned_integer, value}}

  defp encode_interface_value(_value), do: {:error, :invalid_value}

  @spec decode_interface_value(Encoding.t()) ::
          {:ok, pos_integer() | :undefined} | {:error, :invalid_value}
  defp decode_interface_value(encoding)

  defp decode_interface_value(%Encoding{encoding: :primitive, type: :null, value: nil}),
    do: {:ok, :undefined}

  defp decode_interface_value(%Encoding{
         encoding: :primitive,
         type: :unsigned_integer,
         value: value
       })
       when is_integer(value) and value > 0,
       do: {:ok, value}

  defp decode_interface_value(_encoding), do: {:error, :invalid_value}

  @typep reliability_value :: Constants.reliability() | non_neg_integer() | nil

  @doc """
  Checks state ranges, labels, the reserved priority and retained state without I/O.

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
  service. Application feedback writes require an in-service output. Direct writes
  to modeled feedback and BACnet writes to Interface_Value are rejected.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec prepare_write(t(), t(), Context.t()) :: {:ok, t()} | {:error, term()}
  def prepare_write(original, candidate, context)

  def prepare_write(%__MODULE__{_metadata: %{remote_object: remote}}, _candidate, %Context{})
      when not is_nil(remote), do: {:error, :operation_not_available_for_remote_objects}

  def prepare_write(%__MODULE__{} = original, %__MODULE__{} = candidate, %Context{} = context) do
    with :ok <- validate_execution(original, context),
         :ok <- validate_configuration(candidate),
         :ok <- validate_write(original, candidate, context) do
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
         :ok <- validate_write(object, object, context),
         {:ok, updated, reliability_state} <- reconcile_reliability(object, context) do
      updated = ObjectOperations.propagate_properties(object_contract(), updated)

      state =
        Map.merge(reliability_state, %{
          identifier: get_object_identifier(updated),
          out_of_service: updated.out_of_service
        })

      result = %Result{object: updated, state: state, next_execution: nil}

      {:ok,
       IntrinsicReporting.evaluate(result, context, EventAlgorithms.CommandFailure, [
         :present_value,
         :feedback_value
       ])}
    end
  end

  @spec validate_configuration(t()) :: :ok | {:error, term()}
  defp validate_configuration(object) do
    properties = [:number_of_states, :present_value, :priority_array, :relinquish_default]

    properties =
      if has_property?(object, :interface_value),
        do: [:interface_value | properties],
        else: properties

    with :ok <- validate_configuration_properties(object, properties),
         :ok <- validate_state_text(object) do
      if is_nil(object.priority_array.priority_6),
        do: :ok,
        else: {:error, {:invalid_configuration, :priority_6}}
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
          identifier: %ObjectIdentifier{type: :multi_state_output} = identifier,
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

  @spec validate_write(t(), t(), Context.t()) :: :ok | {:error, term()}
  defp validate_write(original, candidate, context) do
    property = Context.written_property(context)

    case context.trigger do
      {:property_write, _property, _index, _priority} when property == :interface_value ->
        {:error, :write_access_denied}

      {:application_write, _property, _index, _priority}
      when property == :feedback_value and (original.out_of_service or candidate.out_of_service) ->
        {:error, :out_of_service}

      _other ->
        if property == :feedback_value and candidate._metadata.other[:auto_write_feedback] == true,
          do: {:error, :feedback_managed_automatically},
          else: ObjectOperations.check_priority_write(candidate, context.trigger)
    end
  end

  @spec reconcile_reliability(t(), Context.t()) ::
          {:ok, object :: t(),
           reliability_state :: %{
             physical_reliability: reliability_value(),
             manual_reliability: reliability_value()
           }}
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
