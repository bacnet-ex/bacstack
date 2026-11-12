defmodule BACnet.Protocol.ObjectTypes.MultistateInput do
  @moduledoc """
  A Multistate Input reports one of several states, such as a valve's closed,
  midway or open position. State numbers start at 1. Use the optional
  `state_text` array to label them, with the first entry describing state 1.

  The number of valid states is declared by the required `number_of_states` property.

  ### Object Description (ASHRAE 135)

  > The Multi-state Input object type defines a standardized object whose Present_Value
  > represents the result of an algorithmic process within the BACnet Device in which
  > the object resides.
  >
  > Multi-state Input objects that support intrinsic reporting shall apply the CHANGE_OF_STATE event algorithm.

  ### Samples and simulation

  The host's driver or local algorithm determines the input state in 1..Number_Of_States.
  Use `set_input/2` to build an observation candidate. In service, a known sample updates
  Present_Value. While out of service, it preserves the simulated Present_Value. A selected
  Interface_Value follows the observation in either service state. `:undefined` marks the
  observation unknown and preserves Present_Value and Reliability. Sample validation applies
  even when Interface_Value is absent.

  BACnet Present_Value writes require Out_Of_Service, including same-value writes.
  `property_writable?/2` reports that access policy. Explicit simulation from either origin
  can use `update_property/3`. Those writes leave Interface_Value alone. Returning to service
  preserves Present_Value until the driver supplies a fresh sample.

  ### Physical observations and Interface_Value

  The optional Interface_Value property describes the actual logical input state. Select it
  explicitly with a known state or `:undefined` at creation, or through `add_property/3`.
  A nil creation value omits it. An unknown observation encodes as BACnet NULL and a known
  one encodes as Unsigned.

  BACnet writes to Interface_Value are rejected. A local driver can report Interface_Value
  alone through the application-write lifecycle. Initialization preserves supplied property
  values. Observations do not select Interface_Value implicitly.

  ### State count and labels

  A local Number_Of_States edit resizes a selected State_Text array. Growth preserves
  existing labels and appends empty strings. A reduction truncates labels if Present_Value
  and any known Interface_Value still fit. If either would become invalid, the edit fails
  without changing the count or labels. Update the values first, then reduce the count.
  State_Text replacements must match the current count. The host needs to enforce the
  read-only service access for Number_Of_States.

  ### Lifecycle and host contract

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  needs to acquire samples, serialize operations and retain results per instance. Initialize
  with `BACnet.Protocol.ObjectExecution.Lifecycle.execute/2` and an `:initialization` context.
  For a sample, construct a candidate with `set_input/2` and an
  `{:application_write, :present_value, nil, nil}` context. Use
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3` before committing the
  candidate, then execute with the same context and previous runtime state. Retain the
  complete result before exposing the write. Use `:property_write` for BACnet requests,
  including requests handled locally. The host needs to deliver each accepted write and
  enforce service permissions and array indices.

  Preparation checks the original and candidate service states for BACnet Present_Value
  writes. A rejected operation supplies no replacement result. Initialize before local
  operations. Missing, malformed or other-instance runtime state returns
  `{:error, :invalid_execution_state}`.

  Use `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` before reading with
  `get_property/2`. An active reporting delay can request a monotonic wakeup. The host needs to cancel
  any superseded request when retaining the result. The lifecycle consumes supplied
  observations and uses no polling timer, hardware callback or clock arithmetic.

  ### Reliability, restart and reporting

  The driver supplies Reliability from its diagnosis. A rejected sample or unknown input
  does not infer a fault. The host needs to suppress automatic Reliability reports while
  simulating. Either origin can supply explicit simulated Reliability. Inhibition masks
  physical reports with NO_FAULT_DETECTED and retains the latest report. An explicitly
  supplied or written out-of-service value can override the mask. Returning to service
  restores a known physical report, subject to inhibition. FAULT follows exposed Reliability,
  IN_ALARM follows supplied Event_State and OUT_OF_SERVICE follows Out_Of_Service.
  OVERRIDDEN is a local indication.

  After restart, initialize from restored properties with fresh runtime state. Refresh any
  suppressed physical Reliability report retained only in the old runtime state. Remote
  snapshots are passive and reject local write preparation and `set_input/2`.

  With `intrinsic_reporting: true`, CHANGE_OF_STATE compares Present_Value with
  Alarm_Values. FAULT_STATE uses Fault_Values when reliability evaluation is
  enabled. A reliability fault takes precedence over an alarm match. After
  retaining the result, the host retrieves transitions with
  `BACnet.Protocol.ObjectExecution.EventReporting.transition/1`.

  With Fault_Values configured, the algorithm supplies Reliability while
  evaluation is enabled. To retain an explicit out-of-service Reliability
  write, set Reliability_Evaluation_Inhibit to true before the write.

  The runnable walkthrough is `examples/objects_lifecycle/multistate_input_lifecycle.exs`.

  ### Examples

  Creating a minimal Multi-state Input:

      iex> {:ok, mi} = BACnet.Protocol.ObjectTypes.MultistateInput.create(1, "Mode", %{}); mi.present_value
      1

  Selecting intrinsic reporting properties:

      iex> {:ok, mi} = BACnet.Protocol.ObjectTypes.MultistateInput.create(2, "Status", %{}, intrinsic_reporting: true); mi.object_name
      "Status"

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.ChangeOfState`
  - `BACnet.Protocol.FaultAlgorithms.FaultState` (optional)
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EventAlgorithms
  alias BACnet.Protocol.FaultAlgorithms
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.IntrinsicReporting
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectOperations

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Multistate Input object.

  `intrinsic_reporting` selects CHANGE_OF_STATE reporting properties for the object.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents a Multistate Input object. Treat fields as read-only and build candidates
  with `set_input/2` or the property operations before driving the lifecycle.
  """
  bac_object Constants.macro_assert_name(:object_type, :multi_state_input) do
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
  truncates labels only when Present_Value and any known Interface_Value remain valid.
  State_Text updates must match the existing Number_Of_States. A rejected update returns
  no partial object. The host needs to enforce read-only access to Number_Of_States for
  BACnet clients.

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
  Builds a input observation candidate without running its lifecycle.

  A known state updates Present_Value while in service and a selected Interface_Value
  in either service state. Out of service, the simulated Present_Value is preserved.
  `:undefined` marks the physical value unknown without changing Present_Value or inferring
  Reliability. The optional Interface_Value is never selected implicitly.

  Prepare and execute the candidate with an application-write Present_Value context before
  exposing it. On error, no partial object is returned. Remote snapshots cannot receive input.
  """
  @spec set_input(t(), pos_integer() | :undefined) :: {:ok, t()} | {:error, term()}
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
  an in-service reading through `set_input/2` and the application-write lifecycle.
  """
  @spec property_writable?(t(), Constants.property_identifier()) :: boolean()
  def property_writable?(object, property)

  def property_writable?(%__MODULE__{} = object, :present_value), do: object.out_of_service

  def property_writable?(%__MODULE__{} = object, property), do: super(object, property)

  @doc """
  Checks state ranges, labels and retained runtime state without acquiring a sample.

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
         :ok <- validate_configuration(candidate),
         :ok <- validate_write(original, context),
         :ok <- validate_write(candidate, context) do
      {:ok, candidate}
    end
  end

  @doc """
  Maintains supplied input values, physical reliability and reliability inhibition.

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
    properties = [:number_of_states, :present_value]

    properties =
      if has_property?(object, :interface_value),
        do: [:interface_value | properties],
        else: properties

    with :ok <- validate_configuration_properties(object, properties) do
      validate_state_text(object)
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
          identifier: %ObjectIdentifier{type: :multi_state_input} = identifier,
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

  @spec update_interface_value(t(), pos_integer() | :undefined) ::
          {:ok, t()} | {:error, term()}
  defp update_interface_value(object, value) do
    if has_property?(object, :interface_value),
      do: update_property(object, :interface_value, value),
      else: {:ok, object}
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
