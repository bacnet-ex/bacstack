<!--t: Driving a Calendar -->

# Driving a Calendar

A `BACnet.Protocol.ObjectTypes.Calendar` answers whether the device's current local date matches its
`date_list`. For example, a shared holiday Calendar can select the exception
schedule used by several Schedules. Calendar implements date matching and
calculates its next local midnight. The application needs to supply time, retain
the execution result, and call the lifecycle at the appropriate moments.

This integrating application is the
[object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host).
This walkthrough shows how to retain one Calendar's result, serve its computed
value and arrange execution at midnight.

## Run the walkthrough

From the repository root:

```sh
mix run examples/objects_lifecycle/calendar_lifecycle.exs
```

The example advances its clock from December 24 to 26. Watch how Present_Value
and the pending wakeup change as it runs.

- Initialization with `Present_Value=false` before Christmas.
- At midnight, a process timer runs Calendar and sets Present_Value to `true`.
- A fresh read after advancing the clock to the following day.
- A `Date_List` write that changes the value immediately, and a same-value write.
- Rejected writes retaining the previous object, runtime state and wakeup.
- An explicit backward clock-change notification recalculating the value and
  replacing the wakeup.

The walkthrough finishes within seconds. The example host uses a supplied clock
and a real process timer. Its snapshot operation reads the retained result, so
the change visible at midnight comes from the timer.

`examples/objects_lifecycle/calendar_lifecycle_host.exs` contains the single-Calendar GenServer
used by the walkthrough. It exposes operations to read Present_Value, write
properties, report clock changes and inspect snapshots. Load this example
module from the repository before trying its API in IEx.

## Try it with the current clock

Start `iex -S mix` from the repository root, then paste:

```elixir
Code.require_file("examples/objects_lifecycle/calendar_lifecycle_host.exs")

alias BACnet.Examples.CalendarLifecycleHost, as: Host
alias BACnet.Protocol.BACnetDate
alias BACnet.Protocol.CalendarEntry
alias BACnet.Protocol.ObjectTypes.Calendar, as: CalendarObject

{:ok, calendar} = CalendarObject.create(500, "Holidays")
{:ok, host} = Host.start_link(calendar)

today = %CalendarEntry{
  type: :date,
  date: BACnetDate.from_date(Date.utc_today()),
  date_range: nil,
  week_n_day: nil
}

:ok = Host.write_property(host, :date_list, [today])
Host.present_value(host)
Host.snapshot(host)

# Call this when the application's clock-change detector reports a correction.
:ok = Host.clock_changed(host)

GenServer.stop(host)
```

The example host uses UTC by default - Calendar requests execution at the next UTC midnight.
The fresh read returns `{:ok, true}` while the current date matches `today`.
The example's snapshot operation exposes the retained
`BACnet.Protocol.ObjectExecution.Result`, including the next wakeup.

For a regional timezone, configure an Elixir timezone database supporting that
zone and pass it explicitly:

```elixir
{:ok, host} = Host.start_link(calendar,
  timezone: "Europe/Zurich",
  timezone_database: Calendar.get_time_zone_database()
)
```

Elixir's default `Calendar.UTCOnlyTimeZoneDatabase` supports UTC only. Calendar
uses the supplied database to resolve its next local midnight, including gaps
and ambiguous local times. A custom `:clock` function can supply
`{device_local_datetime, monotonic_milliseconds}`, as the walkthrough does.

## The lifecycle calls behind the host

The example builds a `BACnet.Protocol.ObjectExecution.Context` for each operation using a fresh
device-local `now`, the timezone database, current monotonic milliseconds, an
operation trigger, and the last result's opaque runtime `state`. Initially,
`state` is `nil`. Calendar needs no object-lookup or property-I/O callbacks, so
these context fields are `nil` - `options` is `[]`.

The example host serializes operations for its Calendar. Follow this order when
implementing the same operations in your application.

| Event | Calls and retained changes |
| --- | --- |
| Initialization | `BACnet.Protocol.ObjectExecution.Lifecycle.execute/2` with `:initialization` - retain the successful result before accepting requests. |
| Computed read | `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` with `{:property_read, :present_value, nil}` - retain its result, then call `BACnet.Protocol.ObjectTypes.Calendar.get_property/2`. |
| Property write | Check access, build a candidate with `BACnet.Protocol.ObjectTypes.Calendar.update_property/3`, then call `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3`. Commit the accepted candidate, execute with the same write context, and retain the result. |
| Midnight | Check `BACnet.Protocol.ObjectExecution.Wakeup.due?/2` using fresh time, then call `BACnet.Protocol.ObjectExecution.Lifecycle.execute/2` with `:timer`. |
| Clock change | Call `BACnet.Protocol.ObjectExecution.Lifecycle.execute/2` with `:clock_change`, then replace the stored result and timer. |

Retain the object, opaque state and replacement wakeup together after each
successful execution. Pass that instance's retained state in the next context.
Calendar preserves the state and computes its value from the supplied date and
current `date_list`.

After a Date_List write, execute the accepted candidate to refresh Present_Value
for the current date. Use the same sequence for a same-value write. This excerpt
uses the helpers defined in `examples/objects_lifecycle/calendar_lifecycle_host.exs`.

```elixir
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.Calendar, as: CalendarObject

context = context(state, {:property_write, property, nil, nil})

with :ok <- check_writable(object, property),
     {:ok, candidate} <- CalendarObject.update_property(object, property, value),
     {:ok, prepared} <- Lifecycle.prepare_write(object, candidate, context) do
  committed = %{state | execution: %{state.execution | object: prepared}}

  case Lifecycle.execute(prepared, context) do
    {:ok, result} -> {:reply, :ok, retain_result(committed, result)}
    {:error, reason} ->
      {:reply, {:error, {:execution_failed_after_commit, reason}}, committed}
  end
else
  {:error, reason} -> {:reply, {:error, reason}, state}
end
```

The example's access checks reject writes to the read-only `present_value`.
Its preparation failure path preserves the previous result. If execution fails after a
write has been accepted, the example host keeps the committed properties and previous
runtime state and wakeup, and returns the distinct
`{:execution_failed_after_commit, reason}` error. Read and clock-change errors
also retain the previous result. A timer execution failure stops this example
host - an integrating application chooses its recovery policy.

## Wakeups and integration

Calendar requests its next local midnight as a wall-clock
`BACnet.Protocol.ObjectExecution.Wakeup`. The example host cancels the old timer
after retaining a result, samples time again and rounds the remaining duration
up to milliseconds. Each timer carries a unique token to identify stale
deliveries. When the current token arrives, the example checks the deadline
again. It rearms an early timer or executes Calendar when the request is due.
A result with `next_execution: nil` cancels the preceding timer.

An integrating host needs to honor the same replacement requests. See the
[wakeup examples](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-wakeups-continuations-and-restarts)
for wall-clock and monotonic deadlines, cancellation and immediate continuations.

Report wall-clock corrections promptly through the example host's clock-change
operation so it can reschedule its monotonic process timer. After a restart,
initialize again using current time. Monotonic timestamps are local to the
running VM.

The example handles Calendar's wall-clock wakeups. Other object types may also
request monotonic deadlines or immediate continuations - their host must implement
the full `BACnet.Protocol.ObjectExecution.Result` contract.

When integrating multiple objects, the stack needs to track dependencies and
notify affected Schedules after Calendar edits. A Schedule's Calendar read must
refresh the computed value through the lifecycle with the same supplied time as
the enclosing operation. The single-Calendar example leaves those interactions
to that integrating stack. See `BACnet.Protocol.ObjectExecution.Lifecycle` for
read, write and dependency ordering.
