<!--t: Driving a Binary Value -->

# Driving a Binary Value

`BACnet.Protocol.ObjectTypes.BinaryValue` represents an in-memory Boolean parameter,
with optional command priorities, transition history, active seconds and minimum on/off
times. The object module owns these calculations. The integrating application - the
[object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host) -
needs to retain results, serialize operations, supply clocks and deliver requested wakeups.
No lookup, read or write callback is needed for this object.

Run the example from the repository root.

```sh
mix run examples/objects_lifecycle/binary_value_lifecycle.exs
```

The source is `examples/objects_lifecycle/binary_value_lifecycle.exs`. It supplies explicit
clocks and retains each returned result in a variable. It performs no network operations
and starts no timers. A running host needs to arm and replace timers using the examples in
`BACnet.Protocol.ObjectExecution.Lifecycle`.

## Initialize and retain

```elixir
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.BinaryValue

{:ok, object} = BinaryValue.create(20, "Enable", %{
  relinquish_default: false,
  min_on_time: 3,
  min_off_time: 2,
  change_of_state_count: 0,
  elapsed_active_time: 0
})

context = Context.new(:initialization,
  now: ~U[2026-11-08 10:00:00Z], monotonic_time: 0)
{:ok, stored} = Lifecycle.execute(object, context)
```

Selecting `relinquish_default` also selects the related priority array. Selecting any
transition-history property adds its other two partners. Active seconds have their own
related reset timestamp. These are instance capabilities selected through the existing
property API, not execution options.

Retain all three fields of `BACnet.Protocol.ObjectExecution.Result`. On subsequent calls,
pass that object's `state` back with fresh clocks. Initialization establishes a baseline
without inventing a transition. A stored priority-6 hold restarts its full applicable
minimum duration using the new monotonic origin. It receives no credit for elapsed time
from another VM. Any actual transition during reconciliation updates history normally.

## Prepare, commit and execute each write

```elixir
write = Context.new({:property_write, :present_value, nil, 8},
  now: ~U[2026-11-08 10:00:00.100Z], monotonic_time: 100, state: stored.state)
{:ok, candidate} = BinaryValue.set_priority(stored.object, 8, true)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, write)
{:ok, stored} = Lifecycle.execute(prepared, write)
```

`BACnet.Protocol.ObjectTypes.BinaryValue.set_priority/3` builds a candidate and performs
ordinary priority arbitration. `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3`
checks the proposed operation and prepares the related priority hold and reset timestamps.
The host needs to commit this candidate while retaining the previous runtime state, then
execute with the same context before allowing another operation to observe the object.
Execution publishes the transition history and elapsed seconds in the retained result.
The example's variables perform these steps synchronously.

If preparation fails, keep the original object, state and wakeup. A rejected write has no
queued effect. The property setters alone have no clocks or origin information and do
not run lifecycle behaviour. Deliver every accepted write, including same-value writes.

For a non-commandable object, build the candidate with
`BACnet.Protocol.ObjectTypes.BinaryValue.update_property/3` instead. Omitted command
priority means 16. A `nil` command value relinquishes only that priority slot. Priority 6
is reserved for minimum on/off protection and is rejected for external commands.

## Deliver timers and refresh computed reads

After the preceding ACTIVE transition, priority 6 holds ACTIVE for three seconds. An
INACTIVE command at priority 8 is still stored, but it cannot become effective until the
hold expires. Priorities 1 through 5 may override the hold and restart timing for their
new effective state. Same-value and masked writes do not restart a hold or increment the
transition count.

```elixir
fresh = Context.new(:timer,
  now: ~U[2026-11-08 10:00:01.100Z], monotonic_time: 1100, state: stored.state)
true = BACnet.Protocol.ObjectExecution.Wakeup.due?(stored.next_execution, fresh)
{:ok, stored} = Lifecycle.execute(stored.object, fresh)
1 = stored.object.elapsed_active_time
```

Each result replaces the previous wakeup request. ACTIVE objects with elapsed-time
accounting request the next whole accumulated second. A hold can request an earlier
deadline. Service the earliest request and retain the replacement. Late delivery accrues
all elapsed whole seconds, but the host still needs timely timer delivery to honor minimum
time expiry and observe transitions in order.

Before a computed read, refresh and retain the result:

```elixir
read = Context.new({:property_read, :elapsed_active_time, nil},
  now: ~U[2026-11-08 10:00:01.600Z], monotonic_time: 1600, state: stored.state)
{:ok, stored} = Lifecycle.prepare_read(stored.object, read)
{:ok, seconds} = BinaryValue.get_property(stored.object, :elapsed_active_time)
```

Monotonic time controls elapsed seconds and holds. Device-local wall time supplies
transition and reset timestamps. Wall-clock corrections cannot shorten a hold or add
active seconds. Fractional active milliseconds survive inactive periods. A backwards
monotonic sample or invalid/cross-instance runtime state returns
`{:error, :invalid_execution_state}` without a replacement result.

## Reset totals

```elixir
reset = Context.new({:property_write, :change_of_state_count, nil, nil},
  now: ~U[2026-11-08 10:00:01.700Z], monotonic_time: 1700, state: stored.state)
{:ok, candidate} = BinaryValue.update_property(stored.object, :change_of_state_count, 0)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, reset)
{:ok, stored} = Lifecycle.execute(prepared, reset)
```

Zero writes stamp the corresponding reset time even when the total already equals zero.
Nonzero writes are allowed and retain the reset time. Reset timestamps are writable.
The same lifecycle sequence applies to `elapsed_active_time`. Writing that total also
discards its fractional remainder. Counts and active seconds wrap modulo 2^32 without
stamping a reset. A coincident effective transition after a count reset counts once.

## Application writes and out of service

Local application writes need the same candidate and commit sequence, using an explicit
application origin:

```elixir
local = Context.new({:application_write, :present_value, nil, 8},
  now: ~U[2026-11-08 10:00:01.800Z], monotonic_time: 1800, state: stored.state)
{:ok, candidate} = BinaryValue.set_priority(stored.object, 8, false)
{:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, local)
{:ok, stored} = Lifecycle.execute(prepared, local)
```

While out of service, application value writes return `{:error, :out_of_service}`.
BACnet writes remain allowed. Arbitration, hold expiry and history accounting continue.
The host needs to retain the actual origin - a local adapter processing a BACnet command
still represents a BACnet write. This object has no hardware polarity or physical output.

For non-commandable values with minimum times, a conflicting write is rejected with
`{:error, {:minimum_time_active, deadline}}`. The deadline is a monotonic millisecond
value. The caller may retry after that time. No priority array or pending command is
created for the rejected write. The runnable example covers both timing mechanisms.

## Capability and recovery boundaries

Initialization retains existing totals and reset timestamps. Enabling a history group
starts accounting at that operation, without reconstructing earlier history. After a VM
restart, initialize again with fresh runtime state and clocks. Do not reuse old monotonic
state. Remote snapshots remain passive and request no wakeups.
Rejected writes and invalid runtime state leave Reliability unchanged.

## Intrinsic reporting

Create the local object with `intrinsic_reporting: true` to enable reporting.
CHANGE_OF_STATE compares the effective Present_Value with Alarm_Value.
When a minimum-time hold masks a command, reporting continues to evaluate
the held value. The next wakeup uses the earliest of any reporting,
minimum-time or active-history deadlines.

Call `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after
committing each result. The
[intrinsic reporting example](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-intrinsic-transitions)
shows when to send a notification and how to handle acknowledgment.
