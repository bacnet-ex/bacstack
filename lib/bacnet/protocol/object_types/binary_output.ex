defmodule BACnet.Protocol.ObjectTypes.BinaryOutput do
  @moduledoc """
  A Binary Output commands a two-state actuator such as a relay or solenoid
  valve. The priority array selects the effective command in `present_value`.
  The driver can use `get_output/2` to obtain the signal for the configured
  normal or reverse polarity.

  In addition to priority-based commandability and `relinquish_default`, the object
  provides optional `min_off_time` / `min_on_time` protection, logical transition
  history and elapsed active seconds. Actual feedback can be supplied separately through
  `feedback_value`. The existing `auto_write_feedback` option instead models feedback
  as following the logical command.

  ### Object Description (ASHRAE 135)

  > The Binary Output object type defines a standardized object whose properties represent
  > the externally visible characteristics of a binary output.
  > A "binary output" is a physical device or hardware output that can be in only one of two distinct states.
  >
  > Binary Output objects that support intrinsic reporting shall apply the COMMAND_FAILURE event algorithm.

  ### Behaviour and Operation

  Binary Output objects are commandable two-state outputs. `present_value` is the logical
  command selected by the highest-priority non-NULL slot, or by `relinquish_default` when
  all commands have been relinquished. Use `set_priority/3` to build command candidates -
  direct property updates of `present_value` are protected. Text properties describe the
  meaning of ACTIVE and INACTIVE. The related event state, reliability and out-of-service
  properties continue to supply the corresponding status flags.

  Logical commands and physical state are distinct. `polarity` translates the logical
  command at the hardware boundary: NORMAL preserves it and REVERSE inverts it. A polarity
  change can change the required physical signal without changing `present_value`.
  `get_output/2` calculates that signal, with a caller-selected fallback while out of service.
  It neither operates hardware nor reports a measured state.

  ### Lifecycle and host contract

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  is the integrating application or higher-level BACnet stack that retains objects and
  runtime state, serializes operations and delivers requested wakeups. Initialize through
  `BACnet.Protocol.ObjectExecution.Lifecycle.execute/2` with `:initialization` and supplied
  clocks in `BACnet.Protocol.ObjectExecution.Context`. This module reads no clock, starts
  no process and invokes no hardware or property I/O callbacks.

  For each command, build a candidate, call
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3`, commit the returned candidate
  and execute with the same clocks and previous runtime state before exposing another
  operation. Retain the resulting object, state and replacement wakeup together. Use
  `{:property_write, property, array_index, priority}` for BACnet writes and
  `{:application_write, property, array_index, priority}` for local application updates.
  Deliver same-value writes too. Numeric property identifiers are accepted in triggers.

  Preparation reconciles priority holds and zero-write reset timestamps without I/O or
  runtime-state changes. Execution publishes transition history and active seconds. The
  host needs to service the returned monotonic wakeups and refresh computed reads through
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` before using the property getter.
  Raw property operations alone do not execute this lifecycle.

  ### Minimum on/off times and command priorities

  Priority 6 is reserved for the minimum-time mechanism. External `set_priority/3` calls
  and lifecycle writes using priority 6 return `{:error, :write_access_denied}` even when
  minimum times are absent. An omitted command priority means 16. NULL (`nil`) relinquishes
  only its specified slot, and lower-priority commands are retained while masked.

  An effective logical transition starts `min_on_time` for ACTIVE or `min_off_time` for
  INACTIVE, in seconds. Priority 6 holds that new state until expiry. The expiry clears
  the hold and reevaluates commands. If that changes `present_value`, the new applicable
  hold starts. Priorities 1 through 5 can override a hold and restart timing for their new
  state. Same-value or masked writes do not restart timing. Duration edits reevaluate the
  hold from the last observed logical transition. Polarity does not affect this calculation.

  ### Logical transition history and active seconds

  `change_of_state_time`, `change_of_state_count` and `time_of_state_count_reset` form
  one optional group. Each effective `present_value` transition increments the count and
  stamps device-local wall time. Binary Output retains its existing non-negative integer
  count type without imposing a wrap limit. Physical feedback and polarity changes alone
  are not logical transitions.

  `elapsed_active_time` and `time_of_active_time_reset` form a second optional group.
  This implementation uses **Present_Value** as the active indicator, which is one of the
  alternatives permitted by ASHRAE 135-2016 12.7.17. It accumulates monotonic ACTIVE
  milliseconds into whole seconds and preserves the fractional remainder across inactive
  intervals. The unsigned 32-bit seconds total wraps modulo 2^32 without a reset stamp.

  A zero write to either total stamps its reset time, including same-value zero writes.
  Nonzero total writes are accepted and leave reset timestamps unchanged. Reset timestamps
  are writable. Writing an active-time total also clears its fractional remainder. Merely
  writing a reset timestamp does not clear a total. History and timing continue while out
  of service. Wall-clock corrections affect timestamps, not elapsed durations.

  ### Physical output, feedback and out of service

  The host needs to apply the retained logical command and polarity to its physical adapter
  while in service. It also needs to reapply the current command on return to service and
  when polarity changes. This module cannot confirm that the physical command succeeded.
  The host supplies actual feedback and physical reliability through property candidates and
  the same lifecycle write sequence.

  Out of service decouples physical drive and physical reliability. Logical application
  and BACnet commands, priority arbitration, minimum times and history continue. Physical
  adapter updates of `feedback_value` use an `:application_write` trigger and return
  `{:error, :out_of_service}` while decoupled. BACnet writes may simulate feedback.
  Explicit Reliability simulation is accepted from either origin, including same-value
  writes. The host needs to stop forwarding automatic hardware Reliability reports while
  out of service - origin alone does not identify the intent of a report. It also needs
  to isolate its hardware adapter and choose
  what the physical output does while decoupled. A `get_output/2` fallback is a calculation
  input, not a universal safe-state requirement.

  `feedback_value` is available independently of intrinsic reporting. Without
  `auto_write_feedback`, command changes do not overwrite it. Supply actual feedback in
  the object's logical domain, after any hardware-specific mapping. This differs from the
  physical signal returned by `get_output/2`, especially with reverse polarity.

  With `auto_write_feedback: true`, existing property mechanics copy the logical command
  into feedback. This is command-following modeled feedback, including during out-of-service
  simulation - it is not evidence that hardware reached that state. Explicit feedback writes
  are rejected during lifecycle preparation with `{:error, :feedback_managed_automatically}`
  in this mode. Choose independent feedback when the adapter reports an actual state.

  ### Initialization, errors and capability boundaries

  Initialization establishes a baseline without inventing a transition, and preserves totals
  and reset timestamps. A stored priority-6 hold restarts its full applicable duration with
  the new monotonic origin. Obsolete holds are reconciled, counting any actual transition.
  Enable history groups at the operation where accounting should start - earlier history
  is not reconstructed. Reinitialize with fresh state after a VM restart.

  Invalid/cross-instance state or backwards monotonic time returns
  `{:error, :invalid_execution_state}`. Rejected writes leave the previous object, runtime
  state and wakeup unchanged. They do not change Reliability. Physical faults need explicit
  host-supplied reliability updates, subject to the out-of-service isolation above.

  With `intrinsic_reporting: true`, COMMAND_FAILURE compares the effective command
  with Feedback_Value. The event delay applies while they disagree and the normal
  delay applies once they match. The host retrieves transitions with
  `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after retaining
  the result. Remote snapshots remain passive and request no wakeup.

  ### Commandability and Priority Arrays

  Binary Output always has `priority_array` and `relinquish_default`. Its effective logical
  command remains subject to prioritization while out of service. The priority array is
  read-only to BACnet clients - the host needs to enforce service access before preparing
  a write. The generated tables describe the remaining property relationships and encoding.

  ### Examples

  Creating a Binary Output with descriptive state texts:

      iex> {:ok, bo} = BACnet.Protocol.ObjectTypes.BinaryOutput.create(1, "Fan Cmd", %{active_text: "On", inactive_text: "Off"}); bo.active_text
      "On"

  Selecting command-following feedback and the intrinsic property representation:

      iex> {:ok, bo} = BACnet.Protocol.ObjectTypes.BinaryOutput.create(2, "Pump", %{}, auto_write_feedback: true, intrinsic_reporting: true)
      iex> {is_boolean(bo.feedback_value), bo.event_state}
      {true, :normal}

  A complete lifecycle command with supplied clocks:

      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> {:ok, object} = BACnet.Protocol.ObjectTypes.BinaryOutput.create(3, "Relay", %{min_on_time: 2, change_of_state_count: 0})
      iex> start = Context.new(:initialization, now: ~U[2026-11-08 10:00:00Z], monotonic_time: 0)
      iex> {:ok, stored} = Lifecycle.execute(object, start)
      iex> command = Context.new({:property_write, :present_value, nil, 8}, now: ~U[2026-11-08 10:00:01Z], monotonic_time: 1000, state: stored.state)
      iex> {:ok, candidate} = BACnet.Protocol.ObjectTypes.BinaryOutput.set_priority(stored.object, 8, true)
      iex> {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, command)
      iex> {:ok, stored} = Lifecycle.execute(prepared, command)
      iex> {stored.object.present_value, stored.object.change_of_state_count, stored.next_execution.monotonic_time}
      {true, 1, 3000}

  The runnable host-adapter walkthrough is
  `examples/objects_lifecycle/binary_output_lifecycle.exs`.

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.CommandFailure`
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EventAlgorithms
  alias BACnet.Protocol.ObjectExecution.BinaryState
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.IntrinsicReporting
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectOperations
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.PriorityArray

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Binary Output object.

  In addition to the common options, Binary Output supports:
  - `auto_write_feedback` - Selects modeled command-following feedback, automatically kept
    in sync with the logical command. This is not measured hardware feedback.
  - `intrinsic_reporting` - Selects COMMAND_FAILURE reporting and enables evaluation during execution.
  """
  @type object_opts ::
          {:auto_write_feedback, boolean()}
          | {:intrinsic_reporting, boolean()}
          | common_object_opts()

  @typedoc """
  Represents a Binary Output object. Treat struct fields as read-only. Use the object module's
  property functions to build updates.

  Create the object with `intrinsic_reporting: true` to select its intrinsic
  reporting properties. The fields for those properties are `nil` when omitted.

  Use `set_priority/3` to submit a command. Present_Value is the logical
  value selected by the priority array. Call `get_output/2` for the
  polarity-adjusted signal in service or the chosen fallback out of service.
  """
  bac_object Constants.macro_assert_name(:object_type, :binary_output) do
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

    field(:priority_array, PriorityArray.t(boolean()), required: true, readonly: true)

    field(:relinquish_default, boolean(),
      required: true,
      default: false,
      annotation: {:encode_as, :enumerated}
    )

    field(:polarity, Constants.polarity(), required: true, default: :normal)

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

    field(:change_of_state_count, non_neg_integer(),
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

    field(:feedback_value, boolean(),
      default: false,
      annotation: [encode_as: :enumerated, required_when: {:opts, :intrinsic_reporting}]
    )
  end

  @doc """
  Calculates the physical command from logical Present_Value and polarity.

  While out of service, returns `decoupled_output_state` unchanged, ignoring polarity.
  The default fallback is false. The host chooses its physical isolation policy - this
  helper neither drives hardware nor measures its state, and the fallback does not define
  a universal safe state. Check `out_of_service` before applying a command to the adapter.
  """
  @doc group: "Functions Operational"
  @spec get_output(t(), boolean()) :: boolean()
  def get_output(%__MODULE__{} = object, decoupled_output_state \\ false)
      when is_boolean(decoupled_output_state) do
    if object.out_of_service do
      decoupled_output_state
    else
      case object.polarity do
        Constants.macro_assert_name(:polarity, :normal) -> object.present_value
        Constants.macro_assert_name(:polarity, :reverse) -> !object.present_value
      end
    end
  end

  @spec add_defaults(map(), ObjectOperations.metadata()) :: map()
  defp add_defaults(properties, metadata) do
    properties = super(properties, metadata)

    if metadata.intrinsic_reporting or metadata.other[:auto_write_feedback] == true,
      do: Map.put_new(properties, :feedback_value, false),
      else: properties
  end

  @doc """
  Checks selected capabilities and retained state without host or hardware operations.

  Initialize local objects before other operations. Remote snapshots are accepted passively.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec validate_execution(t(), Context.t()) :: :ok | {:error, term()}
  def validate_execution(object, context)

  def validate_execution(%__MODULE__{_metadata: %{remote_object: remote}}, %Context{})
      when not is_nil(remote), do: :ok

  def validate_execution(%__MODULE__{} = object, %Context{} = context) do
    with :ok <- validate_configuration(object) do
      BinaryState.validate(object, context)
    end
  end

  @doc """
  Prepares a command or feedback/reliability candidate and related hold/reset changes.

  Application feedback updates are rejected while out of service. Explicit Reliability
  simulation and logical commands remain accepted from both origins. The host needs to
  stop forwarding automatic hardware Reliability reports while decoupled.
  No runtime state or hardware is changed during preparation.
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
         :ok <- ObjectOperations.check_priority_array_change(original, candidate) do
      BinaryState.prepare_write(candidate, context, object_contract(), operation_hooks())
    end
  end

  @doc """
  Maintains logical transition history, active seconds and priority-6 minimum times.

  Retain the complete result before driving an in-service physical adapter. No hardware
  or host callbacks are invoked. Out-of-service simulation retains logical processing.
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
       IntrinsicReporting.evaluate(result, context, EventAlgorithms.CommandFailure, [
         :present_value,
         :feedback_value
       ])}
    end
  end

  @spec validate_configuration(t()) :: :ok | {:error, term()}
  defp validate_configuration(object) do
    if object._metadata.other[:auto_write_feedback] == true and
         not has_property?(object, :feedback_value),
       do: {:error, {:invalid_configuration, :feedback_value}},
       else: :ok
  end

  @spec validate_write(t(), Context.t()) :: :ok | {:error, term()}
  defp validate_write(object, context) do
    property = BinaryState.written_property(context)

    case context.trigger do
      {:application_write, _property, _index, _priority}
      when object.out_of_service and property == :feedback_value ->
        {:error, :out_of_service}

      _other ->
        if property == :feedback_value and object._metadata.other[:auto_write_feedback] == true,
          do: {:error, :feedback_managed_automatically},
          else: ObjectOperations.check_priority_write(object, context.trigger)
    end
  end
end
