defmodule BACnet.Protocol.ObjectTypes.Program do
  @moduledoc """
  A Program exposes the state of an application program, script or state machine
  to BACnet clients. Clients read `program_state` and use `program_change` to
  request actions such as loading, running or halting it. Optional properties
  describe why it halted and identify the loaded program.

  The object deliberately leaves the actual program logic and any additional
  parameters as vendor-specific. It is the standard way to monitor and control
  embedded control logic, custom sequences, or downloadable applications from a
  BACnet workstation.

  ### Object Description (ASHRAE 135)

  > The Program object type defines a standardized object whose properties represent
  > the externally visible characteristics of an application program.
  >
  > Program objects that support intrinsic reporting shall apply the NONE event algorithm.

  ### Behaviour and Operation

  `program_state` reflects the runtime's current state. A write to
  `program_change` requests a transition. The object accepts another request
  when Program_Change is `:ready`. Requests that keep the program in its
  current state complete immediately.

  Starting from idle loads the program and then initializes it at its entry
  point. Load or Restart on an initialized running program reenters that
  entry point. Run resumes a halted, initialized program. If a halt interrupted
  loading, Restart loads the incomplete program again. Out_Of_Service indicates
  whether the program is properly loaded and initialized. A waiting or halted
  program can remain in service. When selected, Reason_For_Halt and
  Description_Of_Halt expose why execution stopped.

  ### Lifecycle

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  retains the object and execution state returned by each step. Use
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3` to prepare a
  Program_Change write, then execute the committed candidate. A busy request
  returns `{:error, :busy}` before any runtime operation. A local override
  indicated by Status_Flags also prevents BACnet writes to program settings.

  Supply a `t:runtime/0` callback as the `:program_runtime` option to
  `create/4` for a local Program that runs runtime actions. The object retains
  the binding in its metadata. When recreating a persisted object at startup,
  supply the callback from local application configuration.

  Commit the result, then run its immediate continuation to invoke the runtime.
  The callback can finish during that call or return `:pending`. For a pending
  action, deliver its token and outcome through the `:program_event` option in
  `BACnet.Protocol.ObjectExecution.Context` on a `:periodic` step. Report a
  failure through the same option if the action times out.

  Use the same event option to report runtime waits, resumes, halts and
  location changes. See `t:runtime_event/0` for the supported inputs. A runtime
  halt can terminate an incomplete load, and a completion for a superseded
  operation leaves the current operation intact.

  On startup, supply properties that reflect the runtime's current state.
  Initialization clears any saved request without replaying it. The runtime
  runs the program and manages its I/O and resources. Remote snapshots retain
  their stored values.

  With `intrinsic_reporting: true`, changes in Reliability can generate FAULT
  and NORMAL transitions. After committing the result, call
  `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` to retrieve them.

  ### Examples

  Creating a Program object:

      iex> {:ok, p} = BACnet.Protocol.ObjectTypes.Program.create(1400, "MyApp", %{program_state: :idle}); p.object_name
      "MyApp"

  Loading and starting a program with an asynchronous load:

      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> alias BACnet.Protocol.ObjectTypes.Program
      iex> runtime = fn
      ...>   :load, token, _object ->
      ...>     send(self(), {:loading, token})
      ...>     :pending
      ...>   :restart, _token, _object -> :ok
      ...> end
      iex> {:ok, object} = Program.create(1400, "MyApp", %{program_state: :idle}, program_runtime: runtime)
      iex> context = Context.new(:initialization)
      iex> {:ok, stored} = Lifecycle.execute(object, context)
      iex> write = %{context | state: stored.state, trigger: {:property_write, :program_change, nil, nil}}
      iex> {:ok, candidate} = Program.update_property(stored.object, :program_change, :run)
      iex> {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, write)
      iex> {:ok, staged} = Lifecycle.execute(prepared, write)
      iex> {staged.object.program_state, staged.object.program_change, staged.next_execution}
      {:loading, :run, :immediate}
      iex> {:ok, waiting} = Lifecycle.execute(staged.object, %{context | trigger: :continuation, state: staged.state})
      iex> token = receive do {:loading, token} -> token end
      iex> completion = Context.new(:periodic, state: waiting.state,
      ...>   options: [program_event: {:completed, token, :ok}])
      iex> {:ok, loaded} = Lifecycle.execute(waiting.object, completion)
      iex> {:ok, running} = Lifecycle.execute(loaded.object, %{context | trigger: :continuation, state: loaded.state})
      iex> {running.object.program_state, running.object.program_change, running.object.out_of_service}
      {:running, :ready, false}

  #### WriteProperty without a runtime binding

  This example shows the host handling a request to write RUN to Program_Change
  on an idle Program. The host resolves the request to the stored local object
  and checks property access before preparing the candidate. For this example,
  the host maps a missing runtime binding to `PROPERTY/WRITE_ACCESS_DENIED`
  in a `BACnet.Protocol.APDU.Error` response.

      iex> alias BACnet.Protocol.{Constants, ObjectsUtility}
      iex> alias BACnet.Protocol.ApplicationTags.Encoding
      iex> alias BACnet.Protocol.APDU.Error
      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> alias BACnet.Protocol.ObjectTypes.Program
      iex> alias BACnet.Protocol.Services.WriteProperty
      iex> {:ok, object} = Program.create(1400, "MyApp", %{program_state: :idle})
      iex> {:ok, stored} = Lifecycle.execute(object, Context.new(:initialization))
      iex> request = %WriteProperty{
      ...>   object_identifier: Program.get_object_identifier(stored.object),
      ...>   property_identifier: :program_change,
      ...>   property_array_index: nil,
      ...>   property_value: Encoding.create!({:enumerated, Constants.by_name!(:program_request, :run)}),
      ...>   priority: nil
      ...> }
      iex> {:ok, apdu} = WriteProperty.to_apdu(request, invoke_id: 7)
      iex> {:ok, write} = WriteProperty.from_apdu(apdu)
      iex> true = write.object_identifier == Program.get_object_identifier(stored.object)
      iex> true = Program.property_writable?(stored.object, write.property_identifier)
      iex> {:ok, :run = value} = ObjectsUtility.cast_property_to_value(
      ...>   write.object_identifier, write.property_identifier, write.property_value
      ...> )
      iex> {:ok, candidate} = Program.update_property(stored.object, write.property_identifier, value)
      iex> trigger = {:property_write, write.property_identifier, write.property_array_index, write.priority}
      iex> context = Context.new(trigger, state: stored.state)
      iex> {:error, {:unsupported_operation, :program_runtime}} = Lifecycle.prepare_write(stored.object, candidate, context)
      iex> response = %Error{invoke_id: apdu.invoke_id, service: apdu.service, class: :property, code: :write_access_denied, payload: []}
      iex> Error.encode(response)
      {:ok, <<0x50, 7, 0x0F, 0x91, 2, 0x91, 0x28>>}
      iex> {stored.object.program_state, stored.object.program_change}
      {:idle, :ready}

  The preparation error leaves the stored result intact. A request that keeps
  the program in its current state, such as HALT while idle, can complete
  without a runtime binding. The host can acknowledge that write with
  `BACnet.Protocol.APDU.SimpleACK` after executing it.

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.None`
  """

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EventAlgorithms
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.IntrinsicReporting
  alias BACnet.Protocol.ObjectExecution.Result

  require Constants
  use BACnet.Protocol.ObjectsMacro

  # Requests omitted from a state's entry are the self-loops in Figure 12-3.
  @actions %{
    idle: %{load: :load, run: :load, restart: :load},
    loading: %{unload: :unload},
    running: %{load: :restart, restart: :restart, halt: :halt, unload: :unload},
    waiting: %{halt: :halt, unload: :unload},
    halted: %{load: :restart, restart: :restart, run: :run, unload: :unload},
    unloading: %{}
  }

  @runtime_properties [
    :program_state,
    :out_of_service,
    :reason_for_halt,
    :description_of_halt,
    :program_location,
    :status_flags
  ]
  @halt_reasons [:normal, :load_failed, :internal, :program, :other]

  @typedoc """
  An operation performed by the application runtime. Restart initializes the
  program at its entry point, including after a successful load.
  """
  @type operation :: :load | :run | :halt | :restart | :unload

  @typedoc """
  The runtime's completion of an operation. A load failure returns the program
  to idle. If initial setup fails after loading, the program is halted with
  its complete image still available. Other failures retain the prior state.
  A runtime that actually halted can report that outcome separately.
  """
  @type outcome :: :ok | {:error, description :: String.t()}

  @typedoc """
  Executes an operation for the supplied Program object. Return `:pending`
  when the host will report the outcome later using the supplied token.
  """
  @type runtime :: (operation(), token :: reference(), object :: t() -> outcome() | :pending)

  @typedoc """
  The image available after a halt. An incomplete image requires loading.
  A loaded image still requires initialization. An initialized image remains
  in service and can resume.
  """
  @type image_status :: :incomplete | :loaded | :initialized

  @typedoc """
  A host observation delivered through the `:program_event` context option
  on a `:periodic` step. Completion tokens identify individual operations.
  `:waiting` and `:running` report entering and leaving a wait. A runtime that
  was already loading or unloading at initialization can report `:running`
  after setup or `:idle` after unload. A halt reports its reason, description
  and image status. A location event updates a selected Program_Location.
  """
  @type runtime_event ::
          {:completed, token :: reference(), outcome()}
          | :waiting
          | :running
          | :idle
          | {:halted, reason :: Constants.program_error(), description :: String.t(),
             image_status()}
          | {:location, location :: String.t()}

  @typep pending :: %{
           operation: operation(),
           token: reference(),
           phase: :dispatch | :waiting,
           previous_state: Constants.program_state()
         }
  @typep execution_state :: %{
           instance: non_neg_integer(),
           loaded: boolean(),
           pending: pending() | nil
         }

  @typedoc """
  Options accepted when creating or configuring a Program object.

  `:program_runtime` binds the local object to its runtime callback.
  """
  @type object_opts :: common_object_opts() | {:program_runtime, runtime()}

  @typedoc """
  Represents a Program object. Treat struct fields as read-only. Use the object module's
  property functions to build updates.
  """
  bac_object Constants.macro_assert_name(:object_type, :program) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:program_state, Constants.program_state(), required: true, readonly: true)
    field(:program_change, Constants.program_request(), required: true, default: :ready)

    field(:reason_for_halt, Constants.program_error(),
      readonly: true,
      implicit_relationship: :description_of_halt
    )

    field(:description_of_halt, String.t(), readonly: true)

    field(:program_location, String.t(), readonly: true)
    field(:instance_of, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:event_state, Constants.event_state(), intrinsic: true, default: :normal)
    field(:out_of_service, boolean(), required: true, readonly: true)

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())
  end

  @spec property_writable?(t(), Constants.property_identifier()) :: boolean()
  def property_writable?(object, property)

  def property_writable?(%__MODULE__{} = object, :program_change) do
    object.program_change == :ready and not match?(%{overridden: true}, object.status_flags) and
      super(object, :program_change)
  end

  def property_writable?(%__MODULE__{} = object, :instance_of) do
    not match?(%{overridden: true}, object.status_flags) and super(object, :instance_of)
  end

  def property_writable?(%__MODULE__{} = object, property), do: super(object, property)

  @doc """
  Checks retained program state and runtime availability for the requested step.

  A pending program operation requires a configured runtime callback.
  Remote snapshots pass preflight.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec validate_execution(t(), Context.t()) :: :ok | {:error, term()}
  def validate_execution(object, context)

  def validate_execution(%__MODULE__{_metadata: %{remote_object: remote}}, %Context{})
      when not is_nil(remote), do: :ok

  def validate_execution(%__MODULE__{} = object, %Context{} = context) do
    with {:ok, state} <- execution_state(object, context.state) do
      validate_step(object, state, Context.normalize_write(context))
    end
  end

  @doc """
  Checks a Program write before commit.

  Runtime-owned properties are protected. Program_Change can be rejected
  while busy or when the requested operation is invalid for the current
  state. BACnet writes to Program_Change and Instance_Of also honor the
  OVERRIDDEN flag.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec prepare_write(t(), t(), Context.t()) :: {:ok, t()} | {:error, term()}
  def prepare_write(original, candidate, context)

  def prepare_write(%__MODULE__{_metadata: %{remote_object: remote}}, _candidate, %Context{})
      when not is_nil(remote), do: {:error, :operation_not_available_for_remote_objects}

  def prepare_write(
        %__MODULE__{} = original,
        %__MODULE__{} = candidate,
        %Context{trigger: {source, _property, _index, _priority}} = context
      )
      when source in [:property_write, :application_write] do
    property = Context.written_property(context)

    cond do
      property in @runtime_properties ->
        {:error, {:write_access_denied, property}}

      source == :property_write and property in [:program_change, :instance_of] and
          original.status_flags.overridden ->
        {:error, {:write_access_denied, property}}

      property == :program_change and original.program_change != :ready ->
        {:error, :busy}

      property == :program_change ->
        with {:ok, state} <- execution_state(original, context.state),
             {:ok, _action} <- requested_operation(original, state, candidate.program_change) do
          {:ok, candidate}
        end

      true ->
        {:ok, candidate}
    end
  end

  @doc """
  Advances the Program lifecycle and evaluates reliability reporting.

  An accepted Program_Change can publish an intermediate state and request
  an immediate continuation. The continuation invokes the configured runtime
  callback. Retain each result before following its continuation.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec execute(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  def execute(object, context)

  def execute(%__MODULE__{_metadata: %{remote_object: remote}} = object, %Context{} = context)
      when not is_nil(remote), do: super(object, context)

  def execute(%__MODULE__{} = object, %Context{} = context) do
    context = Context.normalize_write(context)

    with {:ok, state} <- execution_state(object, context.state),
         :ok <- validate_step(object, state, context),
         {:ok, result} <- step(object, state, context) do
      {:ok,
       IntrinsicReporting.evaluate(result, context, EventAlgorithms.None, [
         :program_state,
         :reason_for_halt,
         :description_of_halt
       ])}
    end
  end

  @spec execution_state(t(), term()) :: {:ok, execution_state()} | {:error, term()}
  defp execution_state(object, state)

  defp execution_state(%__MODULE__{program_state: state}, _retained)
       when not is_map_key(@actions, state),
       do: {:error, :invalid_program_state}

  defp execution_state(object, nil) do
    loaded = not object.out_of_service and object.reason_for_halt != :load_failed
    {:ok, %{instance: object.object_instance, loaded: loaded, pending: nil}}
  end

  defp execution_state(
         %__MODULE__{object_instance: instance},
         %{instance: instance, loaded: loaded, pending: pending} = state
       )
       when is_boolean(loaded) and (is_nil(pending) or is_map(pending)),
       do: {:ok, state}

  defp execution_state(_object, _state), do: {:error, :invalid_execution_state}

  @spec requested_operation(t(), execution_state(), Constants.program_request()) ::
          {:ok, operation() | nil} | {:error, term()}
  defp requested_operation(object, state, request) do
    case @actions[object.program_state][request] do
      :run when object.out_of_service or not state.loaded ->
        {:error, {:invalid_program_request, :run}}

      :restart when not state.loaded ->
        {:ok, :load}

      operation ->
        {:ok, operation}
    end
  end

  @spec validate_step(t(), execution_state(), Context.t()) :: :ok | {:error, term()}
  defp validate_step(object, state, context)

  defp validate_step(
         object,
         %{pending: %{phase: :dispatch}},
         %Context{trigger: :continuation}
       ) do
    with {:ok, _runtime} <- runtime(object), do: :ok
  end

  defp validate_step(
         object,
         state,
         %Context{trigger: {source, :program_change, _index, _priority}}
       )
       when source in [:property_write, :application_write] do
    if state.pending do
      {:error, :busy}
    else
      case requested_operation(object, state, object.program_change) do
        {:ok, nil} -> :ok
        {:ok, _operation} -> with {:ok, _runtime} <- runtime(object), do: :ok
        {:error, _reason} = error -> error
      end
    end
  end

  defp validate_step(_object, _state, _context), do: :ok

  @spec runtime(t()) :: {:ok, runtime()} | {:error, term()}
  defp runtime(%__MODULE__{_metadata: %{other: options}}) do
    case Map.get(options, :program_runtime) do
      callback when is_function(callback, 3) -> {:ok, callback}
      nil -> {:error, {:unsupported_operation, :program_runtime}}
      _other -> {:error, {:invalid_configuration, :program_runtime}}
    end
  end

  @spec step(t(), execution_state(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  defp step(object, state, context)

  defp step(object, state, %Context{trigger: :initialization, state: nil}) do
    object = set_out_of_service(object, not state.loaded)
    result(%{object | program_change: :ready}, state)
  end

  defp step(object, state, %Context{trigger: {source, :program_change, _index, _priority}})
       when source in [:property_write, :application_write] do
    case requested_operation(object, state, object.program_change) do
      {:ok, nil} -> result(%{object | program_change: :ready}, state)
      {:ok, operation} -> queue_operation(object, state, operation)
    end
  end

  defp step(
         object,
         %{pending: %{phase: :dispatch} = pending} = state,
         %Context{trigger: :continuation}
       ) do
    {:ok, callback} = runtime(object)

    case callback.(pending.operation, pending.token, object) do
      :pending ->
        result(object, put_in(state.pending.phase, :waiting))

      outcome ->
        if valid_outcome?(outcome) do
          complete(object, state, outcome)
        else
          raise ArgumentError, "invalid Program runtime outcome: #{inspect(outcome)}"
        end
    end
  end

  defp step(object, state, %Context{trigger: :periodic, options: options}) do
    apply_event(object, state, Keyword.get(options, :program_event))
  end

  defp step(object, state, _context), do: result(object, state)

  @spec queue_operation(t(), execution_state(), operation()) :: {:ok, Result.t(t())}
  defp queue_operation(object, state, operation) do
    pending = %{
      operation: operation,
      token: make_ref(),
      phase: :dispatch,
      previous_state: object.program_state
    }

    case operation do
      :load ->
        loading = set_status(object, :loading, true, :normal, "")
        result(loading, %{state | loaded: false, pending: pending})

      :unload ->
        result(%{object | program_state: :unloading}, %{state | pending: pending})

      _other ->
        result(object, %{state | pending: pending})
    end
  end

  @spec apply_event(t(), execution_state(), runtime_event() | nil) ::
          {:ok, Result.t(t())} | {:error, term()}
  defp apply_event(object, state, event)

  defp apply_event(object, state, nil), do: result(object, state)

  defp apply_event(object, state, {:completed, token, outcome}) when is_reference(token) do
    if valid_outcome?(outcome) do
      case state.pending do
        %{token: ^token, phase: :waiting} -> complete(object, state, outcome)
        _other -> result(object, state)
      end
    else
      {:error, :invalid_program_event}
    end
  end

  defp apply_event(
         %__MODULE__{program_state: :running} = object,
         %{pending: nil} = state,
         :waiting
       ) do
    result(%{object | program_state: :waiting}, state)
  end

  defp apply_event(
         %__MODULE__{program_state: :waiting} = object,
         %{pending: nil} = state,
         :running
       ) do
    result(%{object | program_state: :running}, state)
  end

  defp apply_event(
         %__MODULE__{program_state: :loading} = object,
         %{pending: nil} = state,
         :running
       ) do
    result(set_status(object, :running, false, :normal, ""), %{state | loaded: true})
  end

  defp apply_event(
         %__MODULE__{program_state: :unloading} = object,
         %{pending: nil} = state,
         :idle
       ) do
    result(set_status(object, :idle, true, :normal, ""), %{state | loaded: false})
  end

  defp apply_event(object, state, {:halted, reason, description, image_status})
       when object.program_state in [:loading, :running, :waiting, :halted, :unloading] and
              reason in @halt_reasons and is_binary(description) and
              image_status in [:incomplete, :loaded, :initialized] do
    loaded = image_status != :incomplete
    halted = set_status(object, :halted, image_status != :initialized, reason, description)
    result(%{halted | program_change: :ready}, %{state | loaded: loaded, pending: nil})
  end

  defp apply_event(object, state, {:location, location}) when is_binary(location) do
    updated =
      if has_property?(object, :program_location),
        do: %{object | program_location: location},
        else: object

    result(updated, state)
  end

  defp apply_event(_object, _state, _event), do: {:error, :invalid_program_event}

  @spec valid_outcome?(term()) :: boolean()
  defp valid_outcome?(outcome)

  defp valid_outcome?(:ok), do: true
  defp valid_outcome?({:error, description}), do: is_binary(description)
  defp valid_outcome?(_other), do: false

  @spec complete(t(), execution_state(), outcome()) :: {:ok, Result.t(t())}
  defp complete(object, state, outcome)

  defp complete(object, %{pending: %{operation: :load}} = state, :ok) do
    queue_operation(object, %{state | loaded: true}, :restart)
  end

  defp complete(object, %{pending: %{operation: operation}} = state, :ok) do
    {updated, loaded} =
      case operation do
        :unload ->
          {set_status(object, :idle, true, :normal, ""), false}

        :halt ->
          {set_status(
             object,
             :halted,
             object.out_of_service,
             :program,
             "Halted by Program_Change"
           ), state.loaded}

        _start ->
          {set_status(object, :running, false, :normal, ""), true}
      end

    result(%{updated | program_change: :ready}, %{state | loaded: loaded, pending: nil})
  end

  defp complete(object, %{pending: pending} = state, {:error, description}) do
    updated =
      case pending do
        %{operation: :load} ->
          set_status(object, :idle, true, :load_failed, description)

        %{operation: :restart, previous_state: :loading} ->
          set_status(object, :halted, true, :internal, description)

        %{previous_state: previous_state} ->
          %{object | program_state: previous_state}
      end

    result(%{updated | program_change: :ready}, %{state | pending: nil})
  end

  @spec set_status(
          t(),
          Constants.program_state(),
          boolean(),
          Constants.program_error(),
          String.t()
        ) :: t()
  defp set_status(object, program_state, out_of_service, reason, description) do
    updated = set_out_of_service(%{object | program_state: program_state}, out_of_service)

    if has_property?(updated, :reason_for_halt) do
      %{updated | reason_for_halt: reason, description_of_halt: description}
    else
      updated
    end
  end

  @spec result(t(), execution_state()) :: {:ok, Result.t(t())}
  defp result(object, state) do
    next_execution = if match?(%{phase: :dispatch}, state.pending), do: :immediate
    {:ok, %Result{object: object, state: state, next_execution: next_execution}}
  end

  @spec set_out_of_service(t(), boolean()) :: t()
  defp set_out_of_service(object, out_of_service) do
    %{
      object
      | out_of_service: out_of_service,
        status_flags: %{object.status_flags | out_of_service: out_of_service}
    }
  end

  @spec inhibit_object_check(
          t(),
          t() | nil,
          ObjectOperations.property_operation(),
          ObjectOperations.property_operation_args()
        ) :: {:ok, t()}
  defp inhibit_object_check(object, original, operation, args)

  defp inhibit_object_check(%{program_state: state} = object, _original, _operation, _args)
       when state in [:idle, :loading],
       do: {:ok, set_out_of_service(object, true)}

  defp inhibit_object_check(%{program_state: state} = object, _original, _operation, _args)
       when state in [:running, :waiting],
       do: {:ok, set_out_of_service(object, false)}

  defp inhibit_object_check(object, _original, _operation, _args), do: {:ok, object}
end
