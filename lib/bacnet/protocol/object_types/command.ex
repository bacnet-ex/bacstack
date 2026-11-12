defmodule BACnet.Protocol.ObjectTypes.Command do
  @moduledoc """
  A Command runs a predefined sequence of property writes from a single request.
  Writing an action code to `present_value` selects the sequence to run.
  For example, an occupied-mode action could set the lighting level and
  temperature setpoint for a zone.

  `action` is a `BACnet.Protocol.BACnetArray` of `BACnet.Protocol.ActionList` values.
  Each list contains ordered `BACnet.Protocol.ActionCommand` entries, specifying a
  target device/object/property, encoded value, optional array index and priority,
  optional post-delay, failure policy and result flag. `action_text` optionally gives
  human-readable names such as "Night setback" or "Occupied" for those action codes.

  ### Object Description (ASHRAE 135)

  > The Command object type defines a standardized object whose properties represent
  > the externally visible characteristics of a multi-action command procedure.

  ## Behaviour and operation

  Every accepted write to `present_value` starts execution, including a write of the
  existing value. Codes run from zero through the current Action array size. Code zero
  and an empty selected list perform no writes and complete successfully. Initialization,
  reads and periodic execution do not replay a previously selected action code.

  Execution first publishes `in_process: true` and `all_writes_successful: false`, then
  requests an immediate continuation. Only after the host retains that result does the
  continuation perform a write. Each attempted entry's `write_successful` flag is updated
  from the actual result. A failure with `quit_on_failure: true` stops the remaining entries,
  whose flags are false. Other failures permit following writes. Earlier successful writes
  are retained - Command execution provides no multi-object transaction or rollback.

  `post_delay` is in **seconds**, after either a successful or failed write. A positive
  delay also applies before final completion and after a failure that terminates the list.
  A continuation after the callback returns samples the host-supplied monotonic time and
  requests an absolute `BACnet.Protocol.ObjectExecution.Wakeup`. No process is blocked
  for the delay. At completion, `in_process` becomes false and `all_writes_successful`
  becomes true only if every attempted entry succeeded and none were skipped by failure.

  ## Lifecycle integration

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  owns storage, serialization, callback routing and timer delivery. Use
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3` before committing a proposed write,
  followed by `BACnet.Protocol.ObjectExecution.Lifecycle.execute/2` with the same write trigger.
  The host needs to do this even for same-value writes, retain each successful result and
  drain `:immediate` continuations before another external operation on that instance.

  - `present_value` writes while busy return `{:error, :busy}` without acceptance. The host
    needs to map this to BACnet OBJECT/BUSY. Low-level `update_property/3` also rejects busy
    present-value writes. This is the interlock for direct and indirect self-commanding.
  - Action and Action_Text configuration writes are rejected while busy by write preparation.
    Idle updates through `update_property/3` synchronize their sizes. New action slots are empty
    action lists and new text slots contain empty strings. Resizing does not execute a sequence.
  - `in_process` and `all_writes_successful` are computed, read-only properties. The module
    maintains them and the selected list's write-success flags through property operations.
  - The `BACnet.Protocol.ObjectExecution.Context` needs a write callback when a sequence still
    has writes to attempt. Values are passed unchanged as encodings or encoding lists, with
    each entry's array index and priority. No object lookup callback is required by Command.
    The local adapter needs to cast through `BACnet.Protocol.ObjectsUtility.cast_property_to_value/4`
    using the identifier from the target module. It also needs to enforce conditional array-index
    and priority requirements, NULL command relinquishment, service access and reserved priorities.
  - Recognized explicit self-device references normalize to local references. Other qualified
    references remain remote. Without a local context device identifier, all qualified references
    are forwarded as remote. A remote adapter can pass encodings directly to
    `BACnet.Stack.ClientHelper.write_property/6` after resolving the destination.
  - Supply fresh monotonic milliseconds for each continuation, especially the continuation after
    a write callback returns. That sample establishes the post-delay deadline. Early timer calls
    retain the deadline, and wall-clock corrections do not shorten or extend it. Delays are not
    replayed to catch up after late delivery - the next write occurs when execution resumes.

  Keep the returned opaque state for the same instance. Operational write failures return
  `{:ok, result}` so the host can retain flags, progress and failure details. Exceptions and
  malformed callback results remain programming errors. A rejected preflight/write preparation
  returns no replacement result. Host writes already performed have no rollback.

  After a VM restart, initialize with fresh state. Initialization clears an interrupted busy flag
  and marks the interrupted sequence unsuccessful, preserving its recorded per-entry results.
  It does not replay or automatically resume writes, whose external effects may already exist.
  Remote Command snapshots remain passive. Command creation does not support intrinsic
  reporting properties. Lifecycle execution does not execute intrinsic reporting. The core object has
  no Reliability property - sequence outcomes use the success properties and runtime details.

  A complete finite lifecycle walkthrough is available at
  `examples/objects_lifecycle/command_lifecycle.exs` in the repository.

  ## Developer notes

  The generated property API handles storage, representation checks and related updates. A property
  update alone does not execute the Command. The host needs to enforce lifecycle ordering and
  bounded callback waits. For local self-targets, a callback needs to check the published busy
  object and return BUSY before attempting to call an owner already executing that same object.
  The Command library does not supply a production object server.

  Command objects can cascade into other Commands. Preserve the busy interlock and make callback
  routing and failure logging explicit so operators can understand coordinated changes. Configure
  sequences with the actual priorities and failure policy required by their targets.

  A zero-code write still passes through the busy/publication stage and needs no host callbacks:

      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> alias BACnet.Protocol.ObjectTypes.Command
      iex> {:ok, command} = Command.create(1301, "No action")
      iex> context = Context.new({:property_write, :present_value, nil, nil},
      ...>   now: ~U[2026-11-09 08:00:00Z], monotonic_time: 0)
      iex> {:ok, candidate} = Command.update_property(command, :present_value, 0)
      iex> {:ok, prepared} = Lifecycle.prepare_write(command, candidate, context)
      iex> {:ok, busy} = Lifecycle.execute(prepared, context)
      iex> {busy.object.in_process, busy.object.all_writes_successful, busy.next_execution}
      {true, false, :immediate}
      iex> {:ok, completed} = Lifecycle.execute(busy.object,
      ...>   %{context | trigger: :continuation, state: busy.state})
      iex> {completed.object.in_process, completed.object.all_writes_successful, completed.next_execution}
      {false, true, nil}

  ## Examples

  Creating a Command object:

      iex> {:ok, command} = BACnet.Protocol.ObjectTypes.Command.create(1300, "ZoneControl")
      iex> command.object_name
      "ZoneControl"

  ### See Also

  - `BACnet.Protocol.ActionCommand`
  - `BACnet.Protocol.ActionList`
  - `BACnet.Protocol.ObjectExecution.Lifecycle`
  """

  alias BACnet.Protocol.ActionCommand
  alias BACnet.Protocol.ActionList
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectsMacro

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Command object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a Command object. Treat struct fields as read-only. Use the object module's
  property functions to build updates.
  """
  bac_object Constants.macro_assert_name(:object_type, :command) do
    services(intrinsic: false)

    field(:description, String.t())
    field(:present_value, non_neg_integer(), required: true, default: 0)

    field(:in_process, boolean(), required: true, readonly: true, default: false)
    field(:all_writes_successful, boolean(), required: true, readonly: true, default: false)

    field(:action, BACnetArray.t(ActionList.t()),
      required: true,
      default: BACnetArray.new(nil, %ActionList{actions: []})
    )

    field(:action_text, BACnetArray.t(String.t()))
  end

  @typep execution_state :: %{
           phase: :ready | :delay_pending | :waiting | :idle,
           action_code: non_neg_integer(),
           entries: [ActionCommand.t()],
           position: non_neg_integer(),
           all_success: boolean(),
           halt: boolean(),
           delay: non_neg_integer(),
           deadline: integer() | nil,
           failures: [{DeviceObjectPropertyRef.t(), reason :: term()}]
         }

  @doc """
  Updates a property without executing the selected sequence.

  Busy present-value writes return `{:error, :busy}`. Out-of-range action codes return
  `{:error, :value_out_of_range}`. Action and Action_Text updates synchronize the other array's
  size when it is present. Lifecycle write preparation is still required before committing a
  client write, including its busy check for configuration changes.
  """
  @spec update_property(t(), atom(), term()) :: {:ok, t()} | {:error, term()}
  def update_property(object, property, value)

  def update_property(%__MODULE__{_metadata: %{remote_object: remote}} = object, property, value)
      when not is_nil(remote), do: super(object, property, value)

  def update_property(%__MODULE__{in_process: true}, :present_value, _value), do: {:error, :busy}

  def update_property(%__MODULE__{} = object, :present_value, value)
      when is_integer(value) and value >= 0 do
    if value <= object.action.size,
      do: super(object, :present_value, value),
      else: {:error, :value_out_of_range}
  end

  def update_property(%__MODULE__{} = object, property, value)
      when property in [:action, :action_text] do
    with {:ok, updated} <- super(object, property, value) do
      synchronize_arrays(updated, property)
    end
  end

  def update_property(%__MODULE__{} = object, property, value), do: super(object, property, value)

  @doc """
  Adds an optional property, synchronizing Action size when adding Action_Text.

  As with `update_property/3`, client writes still need lifecycle preparation before commit.
  """
  @spec add_property(t(), Constants.property_identifier() | non_neg_integer(), term()) ::
          {:ok, t()} | {:error, term()}
  def add_property(object, property, value)

  def add_property(%__MODULE__{} = object, :action_text, value) do
    with {:ok, updated} <- super(object, :action_text, value) do
      synchronize_arrays(updated, :action_text)
    end
  end

  def add_property(%__MODULE__{} = object, property, value), do: super(object, property, value)

  @doc """
  Checks configuration, requested action code, runtime state and required write callbacks.

  This preflight invokes no host callbacks. Busy present-value requests return `{:error, :busy}`,
  invalid codes return `{:error, :value_out_of_range}`, malformed action arrays return an
  `:invalid_configuration` error, and incompatible runtime state returns
  `{:error, :invalid_execution_state}`. Lifecycle execution does not execute intrinsic reporting.
  Passive initialization, idle reads and empty sequences need no write callback.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec validate_execution(t(), Context.t()) :: :ok | {:error, term()}
  def validate_execution(object, context)

  def validate_execution(%__MODULE__{_metadata: %{remote_object: remote}}, %Context{})
      when not is_nil(remote), do: :ok

  def validate_execution(%__MODULE__{} = object, %Context{} = context) do
    with :ok <- validate_configuration(object),
         :ok <- validate_request(object, context),
         :ok <- validate_state(object, context),
         {:ok, entries} <- pending_entries(object, context) do
      operations = if entries == [], do: [], else: [:write_property]
      Context.require_operations(context, operations)
    end
  end

  @doc """
  Rejects client writes to computed flags and busy sequence/configuration writes before commit.

  The host needs to build the candidate through property operations and use
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3` for complete preparation. Array-size
  synchronization is handled by `update_property/3` or `add_property/3`. This callback preserves
  the original object on rejection and performs no host I/O or execution.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec prepare_write(t(), t(), Context.t()) :: {:ok, t()} | {:error, term()}
  def prepare_write(original, candidate, context)

  def prepare_write(%__MODULE__{_metadata: %{remote_object: remote}}, _candidate, %Context{})
      when not is_nil(remote), do: {:error, :operation_not_available_for_remote_objects}

  def prepare_write(%__MODULE__{} = original, %__MODULE__{} = candidate, %Context{} = context) do
    property = Context.written_property(context, :property_write)

    cond do
      property in [:in_process, :all_writes_successful] ->
        {:error, {:write_access_denied, property}}

      original.in_process and property in [:present_value, :action, :action_text] ->
        {:error, :busy}

      true ->
        super(original, candidate, context)
    end
  end

  @doc """
  Performs one Command lifecycle step using caller-supplied clocks and runtime state.

  An accepted present-value write publishes busy state and requests `:immediate`. Continuations
  perform ordered writes, publish entry flags and arm post-delays from a fresh monotonic sample.
  Each successful result needs to be retained before another step. The module documentation
  describes initialization, restart handling, host obligations and failure semantics.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec execute(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  def execute(object, context)

  def execute(%__MODULE__{_metadata: %{remote_object: remote}} = object, %Context{} = context)
      when not is_nil(remote), do: super(object, context)

  def execute(%__MODULE__{} = object, %Context{} = context) do
    with :ok <- validate_execution(object, context) do
      cond do
        context.trigger == :initialization ->
          initialize(object)

        Context.written_property(context, :property_write) == :present_value ->
          start_sequence(object)

        object.in_process ->
          resume_sequence(object, context, context.state)

        true ->
          result(object, context.state, nil)
      end
    end
  end

  @spec initialize(t()) :: {:ok, Result.t(t())}
  defp initialize(object)

  defp initialize(%__MODULE__{in_process: true} = object) do
    {:ok, object} = update_property(object, :in_process, false)
    {:ok, object} = update_property(object, :all_writes_successful, false)
    result(object, nil, nil)
  end

  defp initialize(%__MODULE__{} = object), do: result(object, nil, nil)

  @spec start_sequence(t()) :: {:ok, Result.t(t())}
  defp start_sequence(object) do
    {:ok, entries} = selected_entries(object)
    entries = Enum.map(entries, &%{&1 | write_successful: false})
    {:ok, object} = put_entries(object, object.present_value, entries)
    {:ok, object} = update_property(object, :in_process, true)
    {:ok, object} = update_property(object, :all_writes_successful, false)

    state = %{
      phase: :ready,
      action_code: object.present_value,
      entries: entries,
      position: 0,
      all_success: true,
      halt: false,
      delay: 0,
      deadline: nil,
      failures: []
    }

    result(object, state, :immediate)
  end

  @spec resume_sequence(t(), Context.t(), execution_state()) :: {:ok, Result.t(t())}
  defp resume_sequence(object, context, state)

  defp resume_sequence(object, context, %{phase: :delay_pending} = state) do
    deadline = context.monotonic_time + state.delay * 1000
    result(object, %{state | phase: :waiting, deadline: deadline}, wakeup(deadline))
  end

  defp resume_sequence(object, context, %{phase: :waiting} = state) do
    if context.monotonic_time < state.deadline,
      do: result(object, state, wakeup(state.deadline)),
      else: resume_sequence(object, context, %{state | phase: :ready, deadline: nil, delay: 0})
  end

  defp resume_sequence(object, context, %{phase: :ready} = state) do
    if state.halt or state.position >= length(state.entries),
      do: complete(object, state),
      else: attempt_write(object, context, state)
  end

  @spec attempt_write(t(), Context.t(), execution_state()) :: {:ok, Result.t(t())}
  defp attempt_write(object, context, state) do
    entry = Enum.at(state.entries, state.position)
    reference = reference(entry, context)
    response = Context.write_property(context, reference, entry.property_value, entry.priority)

    {successful, failures} =
      case response do
        :ok -> {true, state.failures}
        {:error, reason} -> {false, [{reference, reason} | state.failures]}
      end

    entries =
      List.replace_at(state.entries, state.position, %{entry | write_successful: successful})

    state = %{
      state
      | entries: entries,
        position: state.position + 1,
        all_success: state.all_success and successful,
        halt: not successful and entry.quit_on_failure,
        failures: failures,
        delay: entry.post_delay || 0
    }

    {:ok, object} = put_entries(object, state.action_code, entries)

    cond do
      state.delay > 0 -> result(object, %{state | phase: :delay_pending}, :immediate)
      state.halt or state.position >= length(entries) -> complete(object, state)
      true -> result(object, state, :immediate)
    end
  end

  @spec complete(t(), execution_state()) :: {:ok, Result.t(t())}
  defp complete(object, state) do
    {:ok, object} = update_property(object, :all_writes_successful, state.all_success)
    {:ok, object} = update_property(object, :in_process, false)

    result(
      object,
      %{
        state
        | phase: :idle,
          entries: [],
          position: 0,
          delay: 0,
          deadline: nil,
          failures: Enum.reverse(state.failures)
      },
      nil
    )
  end

  @spec result(t(), term(), nil | :immediate | Wakeup.t()) :: {:ok, Result.t(t())}
  defp result(object, state, request),
    do: {:ok, %Result{object: object, state: state, next_execution: request}}

  @spec wakeup(integer()) :: Wakeup.t()
  defp wakeup(deadline), do: %Wakeup{wall_time: nil, monotonic_time: deadline}

  @spec reference(ActionCommand.t(), Context.t()) :: DeviceObjectPropertyRef.t()
  defp reference(entry, context) do
    device =
      if entry.device_identifier == context.device_identifier,
        do: nil,
        else: entry.device_identifier

    %DeviceObjectPropertyRef{
      device_identifier: device,
      object_identifier: entry.object_identifier,
      property_identifier: entry.property_identifier,
      property_array_index: entry.property_array_index
    }
  end

  @spec put_entries(t(), non_neg_integer(), [ActionCommand.t()]) :: {:ok, t()} | {:error, term()}
  defp put_entries(object, code, entries)

  defp put_entries(object, 0, _entries), do: {:ok, object}

  defp put_entries(object, code, entries) do
    with {:ok, action} <- BACnetArray.set_item(object.action, code, %ActionList{actions: entries}) do
      update_property(object, :action, action)
    end
  end

  @spec validate_configuration(t()) :: :ok | {:error, term()}
  defp validate_configuration(object) do
    cond do
      not is_struct(object.action, BACnetArray) ->
        {:error, {:invalid_configuration, :action}}

      not Enum.all?(array_values(object.action), &valid_list?/1) ->
        {:error, {:invalid_configuration, :action}}

      not is_nil(object.action_text) and
          (not is_struct(object.action_text, BACnetArray) or
             object.action_text.size != object.action.size or
             not Enum.all?(array_values(object.action_text), &is_binary/1)) ->
        {:error, {:invalid_configuration, :action_text}}

      true ->
        :ok
    end
  end

  @spec valid_list?(term()) :: boolean()
  defp valid_list?(value), do: is_struct(value, ActionList) and ActionList.valid?(value)

  @spec validate_request(t(), Context.t()) :: :ok | {:error, term()}
  defp validate_request(object, context) do
    if Context.written_property(context, :property_write) == :present_value do
      if object.in_process, do: {:error, :busy}, else: action_code(object)
    else
      :ok
    end
  end

  @spec action_code(t()) :: :ok | {:error, :value_out_of_range}
  defp action_code(object) do
    if object.present_value in 0..object.action.size, do: :ok, else: {:error, :value_out_of_range}
  end

  @spec selected_entries(t()) :: {:ok, [ActionCommand.t()]} | {:error, term()}
  defp selected_entries(object)

  defp selected_entries(%__MODULE__{present_value: 0}), do: {:ok, []}

  defp selected_entries(object) do
    with :ok <- action_code(object),
         {:ok, %ActionList{} = list} <- BACnetArray.get_item(object.action, object.present_value) do
      {:ok, list.actions}
    else
      :error -> {:error, {:invalid_configuration, :action}}
      {:error, _reason} = error -> error
    end
  end

  @spec pending_entries(t(), Context.t()) :: {:ok, [ActionCommand.t()]} | {:error, term()}
  defp pending_entries(object, context) do
    cond do
      context.trigger == :initialization ->
        {:ok, []}

      Context.written_property(context, :property_write) == :present_value ->
        selected_entries(object)

      object.in_process and not context.state.halt ->
        {:ok, Enum.drop(context.state.entries, context.state.position)}

      true ->
        {:ok, []}
    end
  end

  @spec validate_state(t(), Context.t()) :: :ok | {:error, :invalid_execution_state}
  defp validate_state(object, context)

  defp validate_state(_object, %Context{trigger: :initialization}), do: :ok
  defp validate_state(%__MODULE__{in_process: false}, %Context{state: nil}), do: :ok

  defp validate_state(object, %Context{
         state: %{
           phase: phase,
           action_code: code,
           entries: entries,
           position: position,
           all_success: success,
           halt: halt,
           delay: delay,
           deadline: deadline,
           failures: failures
         }
       })
       when phase in [:ready, :delay_pending, :waiting, :idle] and is_integer(code) and code >= 0 and
              is_list(entries) and is_integer(position) and position >= 0 and
              is_boolean(success) and is_boolean(halt) and is_integer(delay) and delay >= 0 and
              is_list(failures) do
    valid =
      position <= length(entries) and
        ((phase == :idle and not object.in_process and is_nil(deadline)) or
           (phase != :idle and object.in_process and code == object.present_value and
              valid_active_state?(object, phase, entries, delay, deadline)))

    if valid, do: :ok, else: {:error, :invalid_execution_state}
  end

  defp validate_state(_object, _context), do: {:error, :invalid_execution_state}

  @spec valid_active_state?(t(), atom(), [ActionCommand.t()], non_neg_integer(), term()) ::
          boolean()
  defp valid_active_state?(object, phase, entries, delay, deadline) do
    case selected_entries(object) do
      {:ok, selected} ->
        selected == entries and Enum.all?(entries, &ActionCommand.valid?/1) and
          case phase do
            :waiting -> is_integer(deadline) and delay > 0
            :delay_pending -> is_nil(deadline) and delay > 0
            :ready -> is_nil(deadline)
          end

      {:error, _reason} ->
        false
    end
  end

  @spec synchronize_arrays(t(), :action | :action_text) :: {:ok, t()} | {:error, term()}
  defp synchronize_arrays(object, property)

  defp synchronize_arrays(%__MODULE__{action_text: nil} = object, :action), do: {:ok, object}

  defp synchronize_arrays(object, :action) do
    if object.action_text.size == object.action.size,
      do: {:ok, object},
      else:
        update_property(
          object,
          :action_text,
          resize_array(object.action_text, object.action.size, "")
        )
  end

  defp synchronize_arrays(object, :action_text) do
    if object.action.size == object.action_text.size,
      do: {:ok, object},
      else:
        update_property(
          object,
          :action,
          resize_array(object.action, object.action_text.size, %ActionList{actions: []})
        )
  end

  @spec resize_array(BACnetArray.t(), non_neg_integer(), term()) :: BACnetArray.t()
  defp resize_array(array, size, default) do
    values =
      Enum.map(1..size//1, fn index ->
        case BACnetArray.get_item(array, index) do
          {:ok, value} -> value
          :error -> default
        end
      end)

    BACnetArray.from_list(values, not is_nil(array.fixed_size), default)
  end

  @spec array_values(BACnetArray.t()) :: [term()]
  defp array_values(array),
    do:
      Enum.map(1..array.size//1, fn index ->
        case BACnetArray.get_item(array, index) do
          {:ok, value} -> value
          :error -> :undefined
        end
      end)

  @spec add_defaults(map(), map()) :: map() | {:error, term()}
  defp add_defaults(properties, metadata) do
    props = super(properties, metadata)

    if is_nil(metadata.remote_object) do
      result =
        if is_struct(props[:action_text], BACnetArray) and
             props.action_text.size != props.action.size do
          if Map.has_key?(properties, :action),
            do: {:error, {:invalid_configuration, :action_text}},
            else:
              Map.put(
                props,
                :action,
                resize_array(props.action, props.action_text.size, %ActionList{actions: []})
              )
        else
          props
        end

      case result do
        props when is_map(props) ->
          if props.present_value <= props.action.size,
            do: props,
            else: {:error, :value_out_of_range}

        {:error, _reason} = error ->
          error
      end
    else
      props
    end
  end
end
