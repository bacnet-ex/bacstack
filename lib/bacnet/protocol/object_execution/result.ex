defmodule BACnet.Protocol.ObjectExecution.Result do
  @moduledoc """
  Object, runtime state and next execution request produced by one lifecycle step.

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  is the integrating application or higher-level BACnet stack that owns object instances and drives
  their lifecycle. It needs to retain and act on this result as described below.

  Retain all three fields together for each instance. Use `object` for the next operation
  and pass `state` in its `BACnet.Protocol.ObjectExecution.Context`. The object module
  defines the shape of this state and reconciles it with changed properties. Supply
  `state: nil` on initialization.

  For a write to another object, retain the target's update in the host callback that performs
  the write. This result belongs to the object that requested it.

  `next_execution` replaces the previous request on every successful result. A
  `BACnet.Protocol.ObjectExecution.Wakeup` requests a deadline. A `nil` request cancels
  the preceding request. Keep the previous request on error. See the
  [wakeup examples](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-wakeups-continuations-and-restarts)
  for arming and replacing timers.

  For `:immediate`, the host needs to commit this result before calling execution again with the
  `:continuation` trigger. This lets an object publish intermediate state, such as Command's busy
  flag, before performing I/O in a subsequent step. The host needs to drain these continuations
  before processing the next external operation on that object. Implementations must make progress
  and eventually finish or request a future wakeup.

  When constructing a result, supply all fields explicitly. Use `next_execution: nil`
  when the step requests no further execution.
  """

  @typedoc """
  An execution result for a particular object type.
  """
  @type t(object) :: %__MODULE__{
          object: object,
          state: term(),
          next_execution: nil | :immediate | BACnet.Protocol.ObjectExecution.Wakeup.t()
        }

  @typedoc """
  An execution result for any BACnet object.
  """
  @type t :: t(struct())

  @fields [:object, :state, :next_execution]
  @enforce_keys @fields
  defstruct @fields
end
