defprotocol BACnet.Protocol.ObjectsProtocol do
  @moduledoc """
  Common execution interface for BACnet objects.

  Every object defined with `BACnet.Protocol.ObjectsMacro` implements this protocol
  by delegating to its object module's `execute/2`. Objects without execution logic
  return an ok-result preserving the object and runtime state, so callers can
  execute a mixture of object types without checking which ones implement behaviour.

  The caller supplies a `BACnet.Protocol.ObjectExecution.Context`, decides when
  to execute, and retains the returned object and runtime state.
  See `BACnet.Protocol.ObjectsBehaviour` for the execution contract.
  Providing this interface does not implement the operational
  behaviour of an object type by itself.
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
end
