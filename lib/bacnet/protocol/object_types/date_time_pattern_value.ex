defmodule BACnet.Protocol.ObjectTypes.DateTimePatternValue do
  @moduledoc """
  A DateTime Pattern Value stores a combined date and time pattern, such as
  17:00 on the last day of even months. Use `BACnet.Protocol.ObjectTypes.DateTimeValue`
  for a single date and time.

  ### Object Description (ASHRAE 135)

  > The DateTime Pattern Value object type defines a standardized object whose properties
  > represent the externally visible characteristics of a named data value in a BACnet device.
  >
  > DateTime Pattern objects can be used to represent multiple recurring dates and times based
  > on rules defined by the pattern of individual fields of the date and time.

  ### Values and commandability

  Write a `BACnet.Protocol.BACnetDateTime` with `update_property/3` on a non-commandable
  instance. To make an instance commandable, select Priority_Array or
  Relinquish_Default. The object adds the corresponding partner property.
  Use `set_priority/3` to write a command. The lowest numbered active slot
  supplies Present_Value, and Relinquish_Default supplies it when all slots
  are empty.

  The date and time fields can be specified independently. Direct writes,
  priority commands and Relinquish_Default preserve unspecified fields and
  special month and day codes such as `:even` and `:last`. A fully unspecified
  value can occupy a priority slot. Pass nil to relinquish a slot in response
  to BACnet NULL. The host needs to use priority 16 when a BACnet command omits
  its priority. Priority 6 is reserved for minimum on/off control.

  Consumers can interpret the stored pattern for their own purposes. This
  object keeps the pattern as supplied and does not evaluate it against the
  device clock or request a wakeup when the clock matches.

  ### UTC and local time

  Is_UTC indicates how to interpret Present_Value. When true, the value represents
  a UTC date and time. When false or absent, it represents device-local time.
  Supply commands and the relinquish default on the same basis. Writing Is_UTC
  changes the interpretation of stored fields. The lifecycle preserves those
  fields and performs no timezone conversion.

  ### Out of service and write origin

  Use `:application_write` for normal local software and `:property_write`
  for BACnet writes. While Out_Of_Service is true, lifecycle preparation
  rejects application Present_Value writes, including repeated values and
  masked commands. It also rejects indirect application edits that would
  change the effective value. BACnet writes remain available for simulation
  and command prioritization continues. An absent Out_Of_Service property is
  treated as in service.

  ### Lifecycle and host contract

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  needs to own instances, serialize operations and retain runtime state.
  Initialize with `BACnet.Protocol.ObjectExecution.Lifecycle.execute/2` and an
  `:initialization` context. Build a candidate through the property operations,
  call `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3`, and execute
  the prepared object with the same context and prior state. Retain the whole
  result on success. The host needs to enforce service permissions and array
  indices, preserve the write origin, and deliver every accepted write.

  Use `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` before reading
  through `get_property/2`. Execution requires no host I/O or wakeup. After a
  restart, initialize the restored properties with fresh runtime state. Remote
  snapshots remain passive and reject local write preparation.

  ### Reliability and reporting

  The application supplies Reliability. Reliability_Evaluation_Inhibit exposes
  NO_FAULT_DETECTED and retains the reported value for restoration. While out
  of service, either write origin can supply an explicit alternate Reliability,
  including while inhibited. Refresh any suppressed report held only in runtime
  state after restart.

  FAULT follows the exposed Reliability, and OUT_OF_SERVICE follows
  Out_Of_Service. IN_ALARM reflects the supplied Event_State when present.
  OVERRIDDEN remains a local indication. This module provides the core value
  lifecycle. Event_State, when present on an object without event reporting,
  is NORMAL.

  The runnable walkthrough is `examples/objects_lifecycle/date_time_pattern_value_lifecycle.exs`.

  ### Examples

  Creating a DateTime Pattern Value:

      iex> {:ok, dtpv} = BACnet.Protocol.ObjectTypes.DateTimePatternValue.create(120, "RecurDT", %{present_value: %BACnet.Protocol.BACnetDateTime{date: %BACnet.Protocol.BACnetDate{year: :unspecified, month: :unspecified, day: :unspecified, weekday: :unspecified}, time: %BACnet.Protocol.BACnetTime{hour: :unspecified, minute: :unspecified, second: :unspecified, hundredth: :unspecified}}}); dtpv.object_name
      "RecurDT"

  ### See Also
  - `BACnet.Protocol.BACnetDateTime`
  - `BACnet.Protocol.ObjectTypes.DateTimeValue`
  """

  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Reliability
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectOperations
  alias BACnet.Protocol.PriorityArray

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a DateTime Pattern Value object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a DateTime Pattern Value object. Treat fields as read-only. Build
  property candidates with `update_property/3` or `set_priority/3` before driving
  the lifecycle.
  """
  bac_object Constants.macro_assert_name(:object_type, :datetime_pattern_value) do
    services(intrinsic: false)

    field(:description, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:out_of_service, boolean())

    field(:present_value, BACnetDateTime.t(), required: true)

    field(:priority_array, PriorityArray.t(BACnetDateTime.t()), readonly: true)
    field(:relinquish_default, BACnetDateTime.t())

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:is_utc, boolean())

    field(:event_state, Constants.event_state())
  end

  @doc """
  Checks date-time patterns, reserved priority and retained runtime state without I/O.

  Initialize local objects before other lifecycle operations. Remote snapshots are passive.
  No host callback is required.
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
  establishes the baseline from supplied properties. Execution requires no host I/O
  and requests no wakeup.
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
              fault: has_property?(updated, :reliability) and updated.status_flags.fault,
              in_alarm: not is_nil(updated.event_state) and updated.status_flags.in_alarm
          }
      }

      state =
        Map.merge(reliability_state, %{
          identifier: get_object_identifier(updated),
          value: updated.present_value,
          out_of_service: out_of_service
        })

      {:ok, %Result{object: updated, state: state, next_execution: nil}}
    end
  end

  @spec validate_configuration(t()) :: :ok | {:error, term()}
  defp validate_configuration(object)

  defp validate_configuration(%__MODULE__{priority_array: %PriorityArray{priority_6: priority}})
       when not is_nil(priority), do: {:error, {:invalid_configuration, :priority_6}}

  defp validate_configuration(object) do
    properties =
      [:present_value] ++
        Enum.filter([:priority_array, :relinquish_default], &has_property?(object, &1))

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
          identifier: %ObjectIdentifier{type: :datetime_pattern_value} = identifier,
          value: value,
          out_of_service: out_of_service,
          reported_reliability: reported,
          manual_reliability: manual
        } ->
          identifier == get_object_identifier(object) and
            is_struct(value, BACnetDateTime) and BACnetDateTime.valid?(value) and
            is_boolean(out_of_service) and
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
