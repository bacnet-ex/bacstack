defmodule BACnet.Protocol.ObjectsBehaviour do
  @moduledoc """
  Execution callback for BACnet object types.

  `BACnet.Protocol.ObjectsMacro` implements this behaviour for every object type
  and generates an overridable `execute/2` that preserves the object and runtime state.
  Object modules can override it to implement one execution step of their
  object-specific behaviour, such as evaluating a schedule. The implementation
  is defined by the object module and cannot be selected through the context.

  Every object receives the same `BACnet.Protocol.ObjectExecution.Context` and
  returns `{:ok, %BACnet.Protocol.ObjectExecution.Result{}}` or `{:error, reason}`.
  The context supplies wall and monotonic time, an execution trigger, prior
  runtime state and host callbacks for object lookup and property reads/writes. Implementations should
  document their state and any object-specific `context.options`, and use the
  object's property functions so validation and related updates apply.

  The caller owns execution timing and must retain both the result's object
  and runtime state. Execution does not start a process or arrange subsequent
  calls. Invoke it when time or relevant properties change, as required by the
  object type; periodic calls alone may not cover every trigger.

  Recoverable operation failures may require updating reliability, status or
  runtime state. Return an ok-result containing those updates. An error-result
  means no replacement object or runtime state is supplied: the caller retains
  its previous versions. Host writes already performed are not rolled back,
  even on error; callers must not assume retrying execution is safe.

  Implementations are responsible for respecting object-specific rules, including
  remote objects and `out_of_service`. These rules differ between object types
  and are not imposed by the default implementation.

  Use `BACnet.Protocol.ObjectsProtocol.execute/2` to dispatch on an object's struct
  without knowing its module.

  For example, an object module can track the number of executions in runtime
  state. Place the override after its `bac_object/2` block:

  ```elixir
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Result

  @impl BACnet.Protocol.ObjectsBehaviour
  def execute(object, %Context{} = context) do
    count = (context.state || 0) + 1
    {:ok, %Result{object: object, state: count}}
  end
  ```

  Behaviour implementations may also call `Context.lookup_object/2`,
  `Context.read_property/2`, and `Context.write_property/4` to access other objects.
  Their host callbacks provide I/O only; they cannot replace the execution callback.
  """

  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Result

  @doc """
  Runs one execution step and returns the object and runtime state, or an error.

  Objects without execution logic return an ok-result preserving the object and
  `context.state`, without invoking host callbacks.
  """
  @callback execute(struct(), Context.t()) :: {:ok, Result.t()} | {:error, term()}
end
