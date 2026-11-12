defmodule BACnet.Protocol.ObjectExecution.BinaryState do
  @moduledoc """
  Shared logical history for binary objects and minimum times for commandable/value objects.
  Tracks logical transitions, elapsed active time and minimum on/off holds for binary objects.

  `BACnet.Protocol.ObjectTypes.BinaryInput`, `BACnet.Protocol.ObjectTypes.BinaryValue` and
  `BACnet.Protocol.ObjectTypes.BinaryOutput` call these helpers after applying their own
  write and capability checks. Use `BACnet.Protocol.ObjectExecution.Lifecycle` to drive
  those objects from an application.

  ## Preparation and execution

  `prepare_write/3` is pure. It reconciles the candidate's priority-6 hold and stamps
  reset times on explicit zero writes. It changes neither retained runtime state nor
  host storage. `execute/3` advances history and returns a replacement result. The object
  module supplies its own property contract, and property updates use the actual object's
  API. Callers must retain that result before another operation observes the object.

  Minimum durations and active seconds use supplied monotonic milliseconds. Transition
  and reset timestamps use device-local wall time. Active-time accounting uses logical
  Present_Value for all three object types, with fractional milliseconds retained across
  inactive periods. Binary Value's state-change count wraps modulo 2^32. Binary Input and Binary Output
  use a non-negative count with no fixed wrap limit. Elapsed seconds wrap modulo
  2^32 for all three types. Counter wrap is not an explicit reset.

  Initialization establishes a baseline, retaining historical totals. A stored priority-6
  hold restarts its full applicable duration at the new monotonic origin. Obsolete holds
  are reconciled, and actual changes of Present_Value are recorded. Non-commandable
  Binary Value rejects conflicting writes until its hold expires instead of creating an
  array. Binary Output is always commandable. Binary Input has neither priorities nor
  minimum durations.

  Hardware state, feedback, polarity and physical reliability are outside these calculations.
  Those responsibilities are documented by `BACnet.Protocol.ObjectTypes.BinaryOutput`.
  The shared runtime state remains opaque to the host and is isolated by object type and
  identifier. It cannot be reused across VM restarts.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectOperations
  alias BACnet.Protocol.ObjectsContract
  alias BACnet.Protocol.PriorityArray

  @typedoc """
  Object types supported by the shared logical calculations.
  """
  @type binary_object ::
          BACnet.Protocol.ObjectTypes.BinaryInput.t()
          | BACnet.Protocol.ObjectTypes.BinaryValue.t()
          | BACnet.Protocol.ObjectTypes.BinaryOutput.t()

  @typedoc """
  Runtime state for one binary object instance. Pass it back on the next execution.

  `value` is the last effective logical state. `observed_at` and `transitioned_at` use
  VM-monotonic milliseconds. Totals mirror the selected property groups, or are nil when
  absent. `active_remainder` retains the unpublished fraction of an active second.
  """
  @type state :: %{
          kind: :binary_input | :binary_value | :binary_output,
          identifier: ObjectIdentifier.t(),
          value: boolean(),
          observed_at: integer(),
          transitioned_at: integer() | nil,
          count: non_neg_integer() | nil,
          active_seconds: ApplicationTags.unsigned32() | nil,
          active_remainder: 0..999
        }

  @doc """
  Prepares priority holds and explicit reset timestamps on a validated write candidate.

  The object module must first validate configuration, runtime state and write origin.
  Supply that module's contract and property hooks. No I/O or runtime-state update occurs here.
  """
  @spec prepare_write(
          binary_object(),
          Context.t(),
          ObjectsContract.t(),
          ObjectOperations.operation_hooks()
        ) ::
          {:ok, binary_object()} | {:error, term()}
  def prepare_write(candidate, context, contract, hooks) do
    with {:ok, prepared} <-
           reconcile_value(candidate, context.state, context.monotonic_time, contract, hooks) do
      updates =
        reset_timestamp(
          prepared,
          [],
          written_property(context),
          BACnetDateTime.from_datetime(context.now)
        )

      update_properties(prepared, updates)
    end
  end

  @doc """
  Updates logical history and accounts for elapsed time after the object module checks the operation.

  Supply the object's contract, property hooks, fresh clocks and its previous state. The result's
  wakeup replaces the previous request. This function performs no hardware or host I/O.
  """
  @spec execute(
          binary_object(),
          Context.t(),
          ObjectsContract.t(),
          ObjectOperations.operation_hooks()
        ) ::
          {:ok, Result.t(binary_object())} | {:error, term()}
  def execute(object, context, contract, hooks) do
    with :ok <- validate(object, context),
         {:ok, updated, state} <- advance(object, context, contract, hooks) do
      {:ok, %Result{object: updated, state: state, next_execution: next_wakeup(updated, state)}}
    end
  end

  @doc """
  Checks state identity, totals and monotonic ordering, or accepts fresh initialization.

  Does not check object capabilities or invoke property or host operations.
  """
  @spec validate(binary_object(), Context.t()) :: :ok | {:error, :invalid_execution_state}
  def validate(object, context)

  def validate(_object, %Context{trigger: :initialization}), do: :ok

  def validate(object, %Context{state: state, monotonic_time: now}) do
    valid =
      case state do
        %{
          kind: kind,
          identifier: %ObjectIdentifier{type: kind} = identifier,
          value: value,
          observed_at: observed,
          transitioned_at: transition,
          count: count,
          active_seconds: seconds,
          active_remainder: remainder
        } ->
          identifier == object.__struct__.get_object_identifier(object) and is_boolean(value) and
            is_integer(observed) and now >= observed and
            (is_nil(transition) or (is_integer(transition) and transition <= observed)) and
            valid_count?(count, kind) and valid_total?(seconds) and remainder in 0..999

        _other ->
          false
      end

    if valid, do: :ok, else: {:error, :invalid_execution_state}
  end

  @spec valid_total?(term()) :: boolean()
  defp valid_total?(value), do: is_nil(value) or (is_integer(value) and value in 0..0xFFFFFFFF)

  @doc """
  Returns the written property from BACnet/application triggers, normalizing numeric identifiers.

  Other triggers return nil. An unknown numeric property identifier is retained unchanged.
  """
  @spec written_property(Context.t()) :: atom() | non_neg_integer() | nil
  defdelegate written_property(context), to: Context

  @spec commandable?(binary_object()) :: boolean()
  defp commandable?(object), do: is_struct(Map.get(object, :priority_array), PriorityArray)

  @spec valid_count?(term(), :binary_input | :binary_value | :binary_output) :: boolean()
  defp valid_count?(value, kind) do
    if kind == :binary_value,
      do: valid_total?(value),
      else: is_nil(value) or (is_integer(value) and value >= 0)
  end

  @spec advance(
          binary_object(),
          Context.t(),
          ObjectsContract.t(),
          ObjectOperations.operation_hooks()
        ) ::
          {:ok, binary_object(), state()} | {:error, term()}
  defp advance(object, context, contract, hooks)

  defp advance(object, %Context{trigger: :initialization} = context, contract, hooks) do
    restoring_hold = commandable?(object) and not is_nil(object.priority_array.priority_6)

    state = %{
      kind: object.__struct__.get_object_identifier(object).type,
      identifier: object.__struct__.get_object_identifier(object),
      value: object.present_value,
      observed_at: context.monotonic_time,
      transitioned_at: if(restoring_hold, do: context.monotonic_time),
      count: Map.get(object, :change_of_state_count),
      active_seconds: Map.get(object, :elapsed_active_time),
      active_remainder: 0
    }

    advance(object, %{context | trigger: :periodic, state: state}, contract, hooks)
  end

  defp advance(object, %Context{state: state} = context, contract, hooks) do
    with {:ok, object} <- reconcile_value(object, state, context.monotonic_time, contract, hooks) do
      changed = object.present_value != state.value
      timestamp = BACnetDateTime.from_datetime(context.now)
      property = written_property(context)
      {seconds, remainder} = active_total(object, state, context, property)
      count = transition_count(object, state, property, changed)

      updates =
        if object.__struct__.has_property?(object, :change_of_state_count) do
          [change_of_state_count: count] ++
            if(changed, do: [change_of_state_time: timestamp], else: [])
        else
          []
        end

      updates = if is_nil(seconds), do: updates, else: [{:elapsed_active_time, seconds} | updates]
      updates = reset_timestamp(object, updates, property, timestamp)

      with {:ok, updated} <- update_properties(object, updates) do
        {:ok, updated,
         %{
           state
           | value: updated.present_value,
             observed_at: context.monotonic_time,
             transitioned_at:
               if(changed, do: context.monotonic_time, else: state.transitioned_at),
             count: count,
             active_seconds: seconds,
             active_remainder: remainder
         }}
      end
    end
  end

  @spec reconcile_value(
          binary_object(),
          state(),
          integer(),
          ObjectsContract.t(),
          ObjectOperations.operation_hooks()
        ) ::
          {:ok, binary_object()} | {:error, term()}
  defp reconcile_value(object, state, now, contract, hooks) do
    if commandable?(object) do
      hold = if hold_active?(object, state, now), do: state.value, else: nil

      present_value =
        case PriorityArray.get_value(%{object.priority_array | priority_6: hold}) do
          {_priority, value} -> value
          nil -> object.relinquish_default
        end

      new_hold =
        cond do
          present_value == state.value -> hold
          minimum_time(object, present_value) > 0 -> present_value
          true -> nil
        end

      ObjectOperations.set_minimum_time_hold(contract, object, new_hold, hooks)
    else
      if object.present_value != state.value and hold_active?(object, state, now),
        do: {:error, {:minimum_time_active, hold_deadline(object, state)}},
        else: {:ok, object}
    end
  end

  @spec minimum_time(binary_object(), boolean()) :: non_neg_integer()
  defp minimum_time(object, value),
    do: (Map.get(object, if(value, do: :min_on_time, else: :min_off_time)) || 0) * 1000

  @spec hold_deadline(binary_object(), state()) :: integer() | nil
  defp hold_deadline(object, state) do
    if is_integer(state.transitioned_at) and minimum_time(object, state.value) > 0,
      do: state.transitioned_at + minimum_time(object, state.value),
      else: nil
  end

  @spec hold_active?(binary_object(), state(), integer()) :: boolean()
  defp hold_active?(object, state, now) do
    deadline = hold_deadline(object, state)
    is_integer(deadline) and deadline > now
  end

  @spec transition_count(binary_object(), state(), atom() | non_neg_integer() | nil, boolean()) ::
          non_neg_integer() | nil
  defp transition_count(object, state, property, changed) do
    if object.__struct__.has_property?(object, :change_of_state_count) do
      base =
        if property == :change_of_state_count or is_nil(state.count),
          do: object.change_of_state_count,
          else: state.count

      total = base + if(changed, do: 1, else: 0)
      if state.kind == :binary_value, do: rem(total, 0x100000000), else: total
    end
  end

  @spec active_total(binary_object(), state(), Context.t(), atom() | non_neg_integer() | nil) ::
          {seconds :: ApplicationTags.unsigned32() | nil, remainder_ms :: 0..999}
  defp active_total(object, state, context, property) do
    cond do
      not object.__struct__.has_property?(object, :elapsed_active_time) ->
        {nil, 0}

      property == :elapsed_active_time or is_nil(state.active_seconds) ->
        {object.elapsed_active_time, 0}

      true ->
        elapsed = if state.value, do: context.monotonic_time - state.observed_at, else: 0
        milliseconds = state.active_remainder + elapsed

        {rem(state.active_seconds + div(milliseconds, 1000), 0x100000000),
         rem(milliseconds, 1000)}
    end
  end

  @spec reset_timestamp(
          binary_object(),
          keyword(),
          atom() | non_neg_integer() | nil,
          BACnetDateTime.t()
        ) ::
          keyword()
  defp reset_timestamp(object, updates, property, timestamp) do
    case property do
      :change_of_state_count when object.change_of_state_count == 0 ->
        [{:time_of_state_count_reset, timestamp} | updates]

      :elapsed_active_time when object.elapsed_active_time == 0 ->
        [{:time_of_active_time_reset, timestamp} | updates]

      _other ->
        updates
    end
  end

  @spec update_properties(binary_object(), keyword()) :: {:ok, binary_object()} | {:error, term()}
  defp update_properties(object, properties) do
    Enum.reduce_while(properties, {:ok, object}, fn {property, value}, {:ok, current} ->
      case current.__struct__.update_property(current, property, value) do
        {:ok, updated} -> {:cont, {:ok, updated}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  @spec next_wakeup(binary_object(), state()) :: Wakeup.t() | nil
  defp next_wakeup(object, state) do
    active_deadline =
      if state.value and not is_nil(state.active_seconds),
        do: state.observed_at + 1000 - state.active_remainder

    deadlines =
      Enum.filter(
        [hold_deadline(object, state), active_deadline],
        &(is_integer(&1) and &1 > state.observed_at)
      )

    case deadlines do
      [] -> nil
      values -> %Wakeup{wall_time: nil, monotonic_time: Enum.min(values)}
    end
  end
end
