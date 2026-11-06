defmodule BACnet.Protocol.ObjectExecution.Result do
  @moduledoc """
  Object and runtime state produced by one execution step.

  The caller must retain `object` and pass `state` in the next
  `BACnet.Protocol.ObjectExecution.Context` for that same object instance.
  State is opaque to the caller and belongs to the object module; `nil` denotes
  initial state. Changing an object's properties does not implicitly clear its
  runtime state. The implementation must reconcile state with changed properties.

  This result describes the executing object. Writes to other objects are
  performed through the context's host callback and retained by the host.
  """

  @typedoc """
  An execution result for a particular object type.
  """
  @type t(object) :: %__MODULE__{
          object: object,
          state: term()
        }

  @typedoc """
  An execution result for any BACnet object.
  """
  @type t :: t(struct())

  @fields [:object, :state]
  @enforce_keys @fields
  defstruct @fields
end
