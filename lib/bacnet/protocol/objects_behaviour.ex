defmodule BACnet.Protocol.ObjectsBehaviour do
  @moduledoc """
  Execution and lifecycle callbacks for BACnet object types.
  The callbacks an object module uses to define its BACnet behaviour.

  ## Using an object

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  is the integrating application or higher-level BACnet stack that owns object instances and drives
  their lifecycle. Use `BACnet.Protocol.ObjectExecution.Lifecycle` to initialize an instance,
  run its behaviour after a change, prepare writes and refresh values on read. Its
  [first execution example](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-first-execution)
  shows how to create an object, supply a context and retain the result.

  Every object defined with `BACnet.Protocol.ObjectsMacro` has the same lifecycle interface.
  The default execution returns the object and runtime state as supplied, with no wakeup.
  The object module documents which triggers, options and I/O callbacks its behaviour needs.
  For example, `BACnet.Protocol.ObjectTypes.Calendar` needs the local date and a midnight wakeup,
  while `BACnet.Protocol.ObjectTypes.Schedule` can also write to referenced properties through
  a host callback.

  Use `BACnet.Protocol.ObjectsProtocol` when you need to dispatch an individual callback
  for an object whose module is only known at runtime. For example, a direct protocol execution
  invokes the object's callback without lifecycle preflight or passive remote-snapshot handling.

  ## Implementing an object type

  `BACnet.Protocol.ObjectsMacro` generates overridable implementations of these callbacks.
  The object module defines the behaviour. Host callbacks in
  `BACnet.Protocol.ObjectExecution.Context` supply object lookup and property I/O.

  | Callback | Responsibility |
  | --- | --- |
  | `c:validate_execution/2` | Check the instance's configuration, selected capabilities and required host operations before execution. The default returns `:ok`. |
  | `c:prepare_write/3` | Compare a proposed candidate with the original object. Return the candidate, optionally with validated related changes, or reject it. The default returns the candidate. |
  | `c:execute/2` | Run one step using the trigger, clock samples and prior state. Return the updated object, runtime state and any request for another execution. |

  Keep validation and write preparation free of I/O and other side effects. Use
  `BACnet.Protocol.ObjectExecution.Context.require_operations/2` to check for callbacks.
  Use `{:error, {:unsupported_capability, capability}}` for a selected capability the
  implementation cannot run, and document any configuration errors the object returns.

  During execution, use the object's property functions so validation and related updates apply.
  Document the object's triggers, `context.options`, out-of-service rules and any initialization
  or recovery behaviour the host needs to know. If an operational failure changes Reliability,
  status or runtime state, include those changes in `{:ok, result}`. Use `{:error, reason}`
  when there is no replacement result to retain. See
  [execution and failure](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-execution-and-failure)
  for the handling of committed writes and completed I/O.

  An object can also use `BACnet.Protocol.ObjectExecution.IntrinsicReporting` to evaluate
  events or faults as part of execution. Document the reporting selected by
  `intrinsic_reporting: true` for that object.

  For example, an object module can track executions since initialization in runtime state.
  Place this override after its `BACnet.Protocol.ObjectsMacro.bac_object/2` block.

  ```elixir
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Result

  @impl BACnet.Protocol.ObjectsBehaviour
  @spec execute(t(), Context.t()) :: {:ok, Result.t(t())}
  def execute(object, %Context{} = context) do
    count = (Context.previous_state(context) || 0) + 1
    {:ok, %Result{object: object, state: count, next_execution: nil}}
  end
  ```

  Behaviour implementations may also call `BACnet.Protocol.ObjectExecution.Context.lookup_object/2`,
  `BACnet.Protocol.ObjectExecution.Context.read_property/2`, and
  `BACnet.Protocol.ObjectExecution.Context.write_property/4` to access other objects. Their host
  callbacks perform the requested I/O during execution.
  """

  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Result

  @doc """
  Runs one execution step and returns the object and runtime state, or an error.

  The default returns the supplied object and `context.state` in `{:ok, result}`.
  """
  @callback execute(struct(), Context.t()) :: {:ok, Result.t()} | {:error, term()}

  @doc """
  Checks configuration and required capabilities without I/O or state changes.

  Check the instance's selected properties and configuration. Return missing-operation errors
  here, before execution begins. Handle subsequent I/O failures according to the object's
  execution and continuation rules.
  """
  @callback validate_execution(struct(), Context.t()) :: :ok | {:error, term()}

  @doc """
  Validates a write candidate against the original object before atomic commit.

  The context carries the write trigger and previous runtime state. The candidate already
  contains the property change and any related updates applied by the object's property
  operations. Return it, optionally with further validated related changes, or reject it.
  Use the original object to check rules such as rejecting writes while busy. Apply these
  checks to same-value writes too. This callback performs no host I/O. Lifecycle preflight
  checks the final candidate before the host commits it.
  """
  @callback prepare_write(struct(), struct(), Context.t()) :: {:ok, struct()} | {:error, term()}
end
