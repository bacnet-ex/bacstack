defmodule BACnet.Protocol.ObjectTypes.BitstringValue do
  @moduledoc """
  A Bitstring Value groups Boolean flags into one named BACnet value. For
  example, use it to publish a set of related alarm bits. In Elixir, the value
  is a tuple of booleans. Optional labels describe what each bit means.

  ### Object Description (ASHRAE 135)

  > The Bitstring Value object type defines a standardized object whose properties
  > represent the externally visible characteristics of a named data value
  > in a BACnet device.
  >
  > Bitstring Value objects that support intrinsic reporting shall apply
  > the CHANGE_OF_BITSTRING event algorithm.

  ### Values and commandability

  A BIT STRING is represented as a tuple of booleans. A direct write replaces the
  whole tuple through `update_property/3`. Selecting Priority_Array or
  Relinquish_Default selects its partner and makes Present_Value follow the
  highest-priority active command or the default.

  Use `set_priority/3` for commandable Present_Value writes. The lowest numbered
  non-nil priority wins. Lower-priority commands stay stored. Pass nil to
  relinquish a slot. Priority 6 is reserved for minimum on/off control. The host
  needs to use priority 16 when a BACnet command omits its priority.

  ### Bit labels

  Bit_Text is optional. When present, it contains one character string per bit
  of Present_Value. Bit zero is described at BACnet array index one. The labels
  also need to fit every stored command and the relinquish default, so that
  relinquishment always leaves a value with the correct number of labels.

  Local operations that would leave a length mismatch return
  `{:error, {:invalid_configuration, :bit_text}}`. Values and labels keep
  their supplied lengths. To change the width, remove Bit_Text, change the
  value and any commands and default, then add labels for the new width.

  ### Out of service and write origin

  Use `:application_write` for normal local software and `:property_write`
  for BACnet writes. Out_Of_Service isolates the value from local software.
  While it is true, application Present_Value writes and indirect application
  edits that would change the effective value are rejected. BACnet commands
  remain available for simulation and continue to arbitrate. An absent
  Out_Of_Service property is treated as in service.

  ### Lifecycle and host contract

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  needs to own instances, serialize operations and retain runtime state.
  Initialize with `BACnet.Protocol.ObjectExecution.Lifecycle.execute/2` and an
  `:initialization` context. Build a candidate with the property operations,
  call `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3`, and execute
  the prepared object with the same context and prior state. Retain the whole
  result on success. The host needs to enforce service permissions and array
  indices and deliver every accepted write, including repeated or masked commands.

  Use `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` before reading
  through `get_property/2`. The lifecycle requires no host I/O or wakeup. After a
  restart, initialize the restored properties with fresh runtime state. Remote
  snapshots remain passive and reject local write preparation.

  ### Reliability and reporting

  The application supplies Reliability. Reliability_Evaluation_Inhibit exposes
  NO_FAULT_DETECTED and retains the reported value for restoration. While out of
  service, either write origin can supply an explicit alternate Reliability, even
  while inhibited. Refresh any suppressed report held only in runtime state after
  restart.

  FAULT follows the exposed Reliability, IN_ALARM follows Event_State, and
  OUT_OF_SERVICE follows Out_Of_Service. OVERRIDDEN remains a local indication.
  With `intrinsic_reporting: true`, CHANGE_OF_BITSTRING compares the masked
  Present_Value with Alarm_Values. After retaining the result, the host retrieves
  transitions with `BACnet.Protocol.ObjectExecution.EventReporting.transition/1`.

  The runnable walkthrough is `examples/objects_lifecycle/bitstring_value_lifecycle.exs`.

  ### Examples

  Creating a Bitstring Value:

      iex> {:ok, bv} = BACnet.Protocol.ObjectTypes.BitstringValue.create(60, "Flags", %{present_value: {true, false}}); bv.object_name
      "Flags"

  With intrinsic reporting:

      iex> {:ok, bv} = BACnet.Protocol.ObjectTypes.BitstringValue.create(61, "Bits", %{present_value: {true, false}}, intrinsic_reporting: true); bv.object_name
      "Bits"

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.ChangeOfBitstring`
  """

  alias BACnet.BeamTypes
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EventAlgorithms
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.IntrinsicReporting
  alias BACnet.Protocol.ObjectExecution.Reliability
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectOperations
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Bitstring Value object.

  `intrinsic_reporting` selects CHANGE_OF_BITSTRING reporting properties.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents a BitString Value object. Treat fields as read-only. Build property
  candidates with `update_property/3` or `set_priority/3` before driving the lifecycle.
  """
  bac_object Constants.macro_assert_name(:object_type, :bitstring_value) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean())

    field(:present_value, tuple(), required: true)

    field(:priority_array, PriorityArray.t(tuple()), readonly: true)

    field(:relinquish_default, tuple())

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:bit_text, BACnetArray.t(String.t()), default: BACnetArray.new())

    # Intrinsic Reporting
    field(:alarm_values, [tuple()], intrinsic: true, default: [])

    field(:bit_mask, tuple(), intrinsic: true)
    field(:event_state, Constants.event_state(), intrinsic: true)
  end

  @spec inhibit_object_check(
          t(),
          t() | nil,
          ObjectOperations.property_operation(),
          ObjectOperations.property_operation_args()
        ) :: {:ok, t()} | property_update_error()
  defp inhibit_object_check(object, _original, _operation, _args) do
    with :ok <- validate_bit_text(object) do
      {:ok, object}
    end
  end

  @doc """
  Checks bit labels, reserved priority and retained runtime state without I/O.

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
         {:ok, updated, reliability_state} <- Reliability.reconcile_reported(object, context) do
      updated = ObjectOperations.propagate_properties(object_contract(), updated)
      out_of_service = updated.out_of_service == true

      updated = %{
        updated
        | status_flags: %{
            updated.status_flags
            | out_of_service: out_of_service,
              fault: has_property?(updated, :reliability) and updated.status_flags.fault
          }
      }

      state =
        Map.merge(reliability_state, %{
          identifier: get_object_identifier(updated),
          value: updated.present_value,
          out_of_service: out_of_service
        })

      result = %Result{object: updated, state: state, next_execution: nil}

      {:ok,
       IntrinsicReporting.evaluate(result, context, EventAlgorithms.ChangeOfBitstring, [
         :present_value
       ])}
    end
  end

  @spec validate_configuration(t()) :: :ok | {:error, {:invalid_configuration, atom()}}
  defp validate_configuration(object)

  defp validate_configuration(%__MODULE__{priority_array: %PriorityArray{priority_6: priority}})
       when not is_nil(priority), do: {:error, {:invalid_configuration, :priority_6}}

  defp validate_configuration(object), do: validate_bit_text(object)

  @spec validate_bit_text(t()) :: :ok | {:error, {:invalid_configuration, :bit_text}}
  defp validate_bit_text(object)

  defp validate_bit_text(%__MODULE__{_metadata: %{remote_object: remote}})
       when not is_nil(remote), do: :ok

  defp validate_bit_text(object) do
    case object.bit_text do
      %BACnetArray{} = labels ->
        count = BACnetArray.size(labels)

        valid =
          bit_count_matches?(object.present_value, count) and
            valid_bit_labels?(labels, count) and
            command_bit_counts_match?(object, count)

        if valid, do: :ok, else: {:error, {:invalid_configuration, :bit_text}}

      nil ->
        :ok
    end
  end

  @spec valid_bit_labels?(BACnetArray.t(String.t()), non_neg_integer()) :: boolean()
  defp valid_bit_labels?(labels, count) do
    Enum.all?(1..count//1, fn index ->
      case BACnetArray.get_item(labels, index) do
        {:ok, label} -> BeamTypes.check_type(:string, label)
        :error -> false
      end
    end)
  end

  @spec command_bit_counts_match?(t(), non_neg_integer()) :: boolean()
  defp command_bit_counts_match?(object, count)

  defp command_bit_counts_match?(%__MODULE__{priority_array: nil}, _count), do: true

  defp command_bit_counts_match?(%__MODULE__{priority_array: priorities} = object, count) do
    bit_count_matches?(object.relinquish_default, count) and
      Enum.all?(PriorityArray.to_list(priorities), fn value ->
        is_nil(value) or bit_count_matches?(value, count)
      end)
  end

  @spec bit_count_matches?(term(), non_neg_integer()) :: boolean()
  defp bit_count_matches?(value, count), do: is_tuple(value) and tuple_size(value) == count

  @spec validate_state(t(), Context.t()) :: :ok | {:error, :invalid_execution_state}
  defp validate_state(object, context)

  defp validate_state(_object, %Context{trigger: :initialization}), do: :ok

  defp validate_state(object, %Context{state: state}) do
    valid =
      case state do
        %{
          identifier: %ObjectIdentifier{type: :bitstring_value} = identifier,
          value: value,
          out_of_service: out_of_service,
          reported_reliability: reported,
          manual_reliability: manual
        } ->
          identifier == get_object_identifier(object) and
            BeamTypes.check_type(:bitstring, value) and is_boolean(out_of_service) and
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
end
