defprotocol BACnet.Protocol.ObjectsProtocol do
  @moduledoc """
  Common callback interface for BACnet objects.
  Dispatches an individual lifecycle callback to the object's module.

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  is the integrating application or higher-level BACnet stack that owns object instances and drives
  their lifecycle. It needs to retain results and arrange execution according to that contract.

  Every object defined with `BACnet.Protocol.ObjectsMacro` implements this protocol
  by delegating to its object module's callbacks. Objects without execution logic
  return a successful result preserving the object and runtime state.
  Call the same function for any object type.

  For ordinary application integration, use `BACnet.Protocol.ObjectExecution.Lifecycle`.
  It applies preflight and the common write, read and remote-snapshot rules. Use this
  protocol when you need to invoke an individual callback without those lifecycle steps.
  `BACnet.Protocol.ObjectsBehaviour` documents what each callback receives and returns.
  """

  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Result

  @doc """
  Runs one execution step using the object's implementation.

  Returns `{:ok, BACnet.Protocol.ObjectExecution.Result.t()}` or `{:error, reason}`.
  Object-specific context options and runtime state are documented by the object
  module. Dispatch always uses the implementation defined by that module.
  """
  @spec execute(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  def execute(object, context)

  @doc """
  Checks the object's configuration and capabilities without I/O or state changes.
  """
  @spec validate_execution(t(), Context.t()) :: :ok | {:error, term()}
  def validate_execution(object, context)

  @doc """
  Validates and prepares a write candidate before the host commits it.

  Use `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3` for identity,
  remote-snapshot and final execution preflight checks as well.
  """
  @spec prepare_write(t(), t(), Context.t()) :: {:ok, t()} | {:error, term()}
  def prepare_write(object, candidate, context)
end
