defmodule BACnet.Protocol.ObjectTypes.BinaryValue do
  @moduledoc """
  A Binary Value holds an application flag such as an enable command, an
  alarm latch or a calculated Boolean result. BACnet clients can read and, where
  permitted, write its logical state. The object can also track transitions,
  active time and minimum on/off durations.

  The value is optionally fully commandable via a priority array (with relinquish default)
  so that schedules, operators, and control logic can arbitrate control.
  Its core lifecycle maintains optional transition history, elapsed active time and
  minimum on/off protection and intrinsic CHANGE_OF_STATE evaluation.

  ### Object Description (ASHRAE 135)

  > The Binary Value object type defines a standardized object whose properties represent
  > the externally visible characteristics of a binary value.
  > A "binary value" is a control system parameter residing in the memory of the BACnet Device.
  >
  > Binary Value objects that support intrinsic reporting shall apply the CHANGE_OF_STATE event algorithm.

  ### Behaviour and Operation

  Binary Value objects are in-memory two-state parameters (mode flags, enable bits,
  calculated booleans, etc.). A non-commandable instance accepts `present_value` updates
  through `update_property/3`. When `priority_array` and `relinquish_default` are present,
  use `set_priority/3` - the existing priority mechanism computes `present_value`.
  Text properties describe the intended meaning of the two states. Status flags continue
  to follow the related event state, reliability and out-of-service properties.

  ### Lifecycle and host contract

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  is the integrating application or higher-level stack that retains objects and runtime
  state, serializes operations and delivers triggers and requested wakeups. This object
  starts no process, reads no clock and performs no host I/O.

  Initialize with `BACnet.Protocol.ObjectExecution.Lifecycle.execute/2`, supplying
  `:initialization` and fresh clocks in `BACnet.Protocol.ObjectExecution.Context`.
  Keep the returned object, state and wakeup together. Initialization establishes a baseline
  without inventing a transition or changing reset timestamps. A previously stored priority-6
  hold starts its full applicable minimum duration again - elapsed time from another VM
  cannot be reconstructed. With no stored hold, initialization starts no minimum duration.
  Existing totals are retained, and any actual value change while reconciling an obsolete
  hold is recorded as a transition.

  For every write, build a candidate through the property API, call
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3`, commit the returned candidate
  and execute with the same context and previous runtime state before serving another operation.
  Use `{:property_write, property, array_index, priority}` for BACnet writes and
  `{:application_write, property, array_index, priority}` for local application writes.
  A local application `present_value` write is rejected with `{:error, :out_of_service}`
  while the object is out of service. BACnet writes, arbitration, timers and history
  accounting continue. Raw property setters have no source or clock information and do not
  perform this orchestration. Supply atomic write triggers even when the value is unchanged.

  Preparation computes priority holds and reset timestamps without changing runtime state
  or invoking I/O. Execution publishes transition history and active seconds and advances
  the retained runtime state before another operation may observe the object.
  Application writes use the same preparation and commit order as BACnet writes.
  Numeric property identifiers are accepted in triggers. Priority 6 is reserved for the
  module's minimum-time mechanism - `set_priority/3` and lifecycle preparation reject commands
  using it. Direct client writes to the read-only priority array remain a host access check.

  ### Transition history and active time

  The optional `change_of_state_time`, `change_of_state_count` and
  `time_of_state_count_reset` form one property group. Every actual effective
  `present_value` transition increments the count and stamps device-local wall time.
  Same-value writes and commands masked by a higher priority do not count as transitions.
  A count of 4,294,967,295 wraps to zero on the next transition without stamping a reset.

  `elapsed_active_time` and `time_of_active_time_reset` form another optional group.
  Execution accumulates monotonic milliseconds spent ACTIVE, publishes whole seconds and
  retains the fractional remainder across inactive periods. Both groups operate while out
  of service. Zero writes to either total stamp its reset time, including repeated zero
  writes. Nonzero writes are accepted and leave the reset time unchanged. Reset timestamps
  are writable. Writing an active-time total replaces the total and clears its fractional
  remainder. The seconds total wraps modulo 2^32 without treating wraparound as a reset.

  Service the returned monotonic wakeups, and refresh computed properties through
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` before reading them. Wall-clock
  corrections affect timestamps, not elapsed durations. A backwards monotonic sample or
  runtime state belonging to another instance returns `{:error, :invalid_execution_state}`.
  Initialize again after a VM restart. Enabling a history group starts accounting at that
  operation's supplied time - it does not reconstruct history from before the group existed.

  ### Minimum on/off times

  `min_on_time` and `min_off_time` select optional minimum durations in seconds.
  For commandable instances, an effective transition places the new state in priority 6
  for the applicable duration. Lower-priority commands are still stored. On expiry the
  hold is cleared, priorities are reevaluated and a new hold starts if the value changes.
  Priorities 1 through 5 may override a hold, and such transitions start a new hold too.
  Changing a minimum duration reevaluates the hold from the last observed transition.

  For non-commandable instances, the local mechanism rejects a conflicting value write
  with `{:error, {:minimum_time_active, deadline}}` until the monotonic deadline.
  It does not queue that rejected write or create a priority array. The caller may submit
  a new write when the duration expires. Same-value writes succeed without restarting a hold.

  ### Complete write example

  This example uses supplied clocks and retains each result in the caller. A running host
  additionally needs to service returned wakeups as described in
  `BACnet.Protocol.ObjectExecution.Lifecycle`. The runnable walkthrough
  `examples/objects_lifecycle/binary_value_lifecycle.exs` also covers command holds and resets.

      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> {:ok, object} = BACnet.Protocol.ObjectTypes.BinaryValue.create(22, "Enable", %{change_of_state_count: 0})
      iex> start = Context.new(:initialization, now: ~U[2026-11-08 10:00:00Z], monotonic_time: 0)
      iex> {:ok, stored} = Lifecycle.execute(object, start)
      iex> write = Context.new({:application_write, :present_value, nil, nil}, now: ~U[2026-11-08 10:00:01Z], monotonic_time: 1000, state: stored.state)
      iex> {:ok, candidate} = BACnet.Protocol.ObjectTypes.BinaryValue.update_property(stored.object, :present_value, true)
      iex> {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, write)
      iex> {:ok, stored} = Lifecycle.execute(prepared, write)
      iex> {stored.object.present_value, stored.object.change_of_state_count, stored.next_execution}
      {true, 1, nil}

  ### Capability boundaries

  With `intrinsic_reporting: true`, CHANGE_OF_STATE evaluates the effective value
  against Alarm_Value. The host retrieves transitions with
  `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after retaining
  the result. Rejected writes leave Reliability unchanged. Remote snapshots remain
  passive and request no wakeup.

  ### Commandability and Priority Arrays

  Value objects can have a `priority_array` (making them commandable). When a priority array
  is present, the present value is protected and is only changed through the priority mechanism.

  ### Examples

  Creating a Binary Value with state texts:

      iex> {:ok, bv} = BACnet.Protocol.ObjectTypes.BinaryValue.create(20, "Mode", %{active_text: "Auto", inactive_text: "Manual"}); bv.active_text
      "Auto"

  With the intrinsic reporting property group selected:

      iex> {:ok, bv} = BACnet.Protocol.ObjectTypes.BinaryValue.create(21, "Flag", %{}, intrinsic_reporting: true); bv.object_name
      "Flag"

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.ChangeOfState`
  - `BACnet.Protocol.FaultAlgorithms.FaultState` (optional)
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EventAlgorithms
  alias BACnet.Protocol.ObjectExecution.BinaryState
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.IntrinsicReporting
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.PriorityArray

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Binary Value object.

  In addition to the common options, Binary Value supports:
  - `intrinsic_reporting` - Selects CHANGE_OF_STATE reporting and enables evaluation during execution.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()} | common_object_opts()

  @typedoc """
  Represents a Binary Value object. Treat struct fields as read-only. Use the object module's
  property functions to build updates.

  Create the object with `intrinsic_reporting: true` to select its intrinsic
  reporting properties. The fields for those properties are `nil` when omitted.

  The present value reflects an in-memory logical state. No physical polarity is involved.

  For a commandable instance, use `set_priority/3` to change the effective
  Present_Value.
  """
  bac_object Constants.macro_assert_name(:object_type, :binary_value) do
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

    field(:priority_array, PriorityArray.t(boolean()), readonly: true)
    field(:relinquish_default, boolean(), default: false, annotation: {:encode_as, :enumerated})

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

    field(:change_of_state_count, ApplicationTags.unsigned32(),
      default: 0,
      implicit_relationship: :time_of_state_count_reset
    )

    field(:time_of_state_count_reset, BACnetDateTime.t(),
      implicit_relationship: :change_of_state_time,
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    field(:elapsed_active_time, ApplicationTags.unsigned32(),
      implicit_relationship: :time_of_active_time_reset,
      default: 0
    )

    field(:time_of_active_time_reset, BACnetDateTime.t(),
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    field(:min_off_time, ApplicationTags.unsigned32())
    field(:min_on_time, ApplicationTags.unsigned32())

    # Intrinsic Reporting
    field(:alarm_value, boolean(),
      intrinsic: true,
      default: true,
      annotation: {:encode_as, :enumerated}
    )
  end

  @spec check_implicit_relationships(t(), :add | :remove) :: {:ok, t()} | {:error, term()}
  defp check_implicit_relationships(object, operation) do
    # Close the three-property history group regardless of which member was supplied.
    with {:ok, first} <- super(object, operation),
         {:ok, second} <- super(first, operation) do
      super(second, operation)
    end
  end

  @doc """
  Checks retained runtime state without I/O.

  Local execution requires initialization first. Remote snapshots are accepted passively.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec validate_execution(t(), Context.t()) :: :ok | {:error, term()}
  def validate_execution(object, context)

  def validate_execution(%__MODULE__{_metadata: %{remote_object: remote}}, %Context{})
      when not is_nil(remote), do: :ok

  def validate_execution(%__MODULE__{} = object, %Context{} = context) do
    BinaryState.validate(object, context)
  end

  @doc """
  Prepares a BACnet or application write and its related history and timing updates.

  The returned candidate and subsequent execution use the same clocks and previous runtime
  state. Rejected writes leave that state and the previous object unchanged.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec prepare_write(t(), t(), Context.t()) :: {:ok, t()} | {:error, term()}
  def prepare_write(original, candidate, context)

  def prepare_write(%__MODULE__{_metadata: %{remote_object: remote}}, _candidate, %Context{})
      when not is_nil(remote), do: {:error, :operation_not_available_for_remote_objects}

  def prepare_write(%__MODULE__{} = original, %__MODULE__{} = candidate, %Context{} = context) do
    with :ok <- validate_execution(original, context),
         :ok <- validate_write(original, context),
         :ok <- ObjectOperations.check_priority_array_change(original, candidate),
         {:ok, prepared} <-
           BinaryState.prepare_write(candidate, context, object_contract(), operation_hooks()),
         :ok <- validate_write(prepared, context) do
      {:ok, prepared}
    end
  end

  @doc """
  Maintains logical value history, active seconds and minimum-time protection.

  Retain every successful result and honor its replacement monotonic wakeup.
  Initialization establishes the history baseline and evaluates any configured alarm.
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
         {:ok, result} <-
           BinaryState.execute(object, context, object_contract(), operation_hooks()) do
      {:ok,
       IntrinsicReporting.evaluate(result, context, EventAlgorithms.ChangeOfState, [
         :present_value
       ])}
    end
  end

  @spec validate_write(t(), Context.t()) :: :ok | {:error, term()}
  defp validate_write(object, context) do
    case {context.trigger, BinaryState.written_property(context)} do
      {{:application_write, _property, _index, _priority}, property}
      when object.out_of_service ->
        if property == :present_value or object.present_value != context.state.value,
          do: {:error, :out_of_service},
          else: ObjectOperations.check_priority_write(object, context.trigger)

      _other ->
        ObjectOperations.check_priority_write(object, context.trigger)
    end
  end
end
