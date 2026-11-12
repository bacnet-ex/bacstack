defmodule BACnet.Protocol.ObjectExecution.Wakeup do
  @moduledoc """
  Absolute deadlines requested by an object's execution result.

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  is the integrating application or higher-level BACnet stack that owns object instances and drives
  their lifecycle. The host uses these deadlines to schedule the next execution.

  `wall_time` is an absolute `DateTime` for work tied to the device's wall clock,
  such as a Calendar's next midnight. `monotonic_time` is an absolute VM-monotonic
  deadline in milliseconds, for work tied to elapsed time. If both are supplied, the
  request is due when either deadline is reached. Initialize both fields explicitly,
  using `nil` for an unused clock. Two `nil` fields request no execution.

  The host needs to commit the result before arming timers, invoke execution with `:timer` when due,
  and replace the request with the next successful result. It must also deliver `:clock_change`
  after wall-clock/timezone changes and reconcile wall timers then. Monotonic deadlines must not
  shift with wall time. Use `:initialization` with fresh runtime state after a VM restart - persisted
  monotonic deadlines cannot be reused across VMs.

  Pass the current clock samples to `due?/2` on timer delivery. See the
  [wakeup examples](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-wakeups-continuations-and-restarts)
  for arming timers, replacing requests and checking deliveries.
  """

  alias BACnet.Protocol.ObjectExecution.Context

  @typedoc """
  Wall-clock and/or monotonic deadlines - the first one reached is due.
  """
  @type t :: %__MODULE__{
          wall_time: DateTime.t() | nil,
          monotonic_time: integer() | nil
        }

  @fields [:wall_time, :monotonic_time]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Checks whether either deadline has been reached using only supplied time.
  """
  @spec due?(t(), Context.t()) :: boolean()
  def due?(%__MODULE__{} = wakeup, %Context{} = context) do
    wall_due?(wakeup.wall_time, context.now) or
      monotonic_due?(wakeup.monotonic_time, context.monotonic_time)
  end

  @spec wall_due?(DateTime.t() | nil, DateTime.t()) :: boolean()
  defp wall_due?(deadline, now)

  defp wall_due?(nil, _now), do: false

  defp wall_due?(%DateTime{} = deadline, %DateTime{} = now),
    do: DateTime.compare(now, deadline) != :lt

  @spec monotonic_due?(integer() | nil, integer()) :: boolean()
  defp monotonic_due?(deadline, now)

  defp monotonic_due?(nil, _now), do: false

  defp monotonic_due?(deadline, now) when is_integer(deadline) and is_integer(now),
    do: now >= deadline
end
