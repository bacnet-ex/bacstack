<!--t: Driving a Schedule -->

# Driving a Schedule

`BACnet.Protocol.ObjectTypes.Schedule` evaluates weekly and exception schedules,
selects a primitive value and commands configured target properties. The
[object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
is the integrating application that owns the objects and drives these steps.

Run the example from the repository root.

```sh
mix run examples/objects_lifecycle/schedule_lifecycle.exs
```

The example keeps each result in an Agent and advances a simulated UTC clock.
It follows a day's schedule through these steps.

- Initializing before occupancy and explicitly delivering the requested 08:00 deadline.
- Converting ENUMERATED 0/1 to the Boolean property representation of a binary output.
- Fresh Calendar reads and dependency notification after a same-day holiday edit.
- Publishing each new Schedule value before a continuation writes the target.
- Manual out-of-service control and recalculation when returning to service.
- A remote NULL write at priority 8, encoded by a simulated callback without a remote object lookup.
  This segment constructs a WriteProperty request but sends no network traffic.

The walkthrough advances supplied time directly. An integrating host needs to
arm and deliver timers using the
[wakeup contract](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-wakeups-continuations-and-restarts).
The example's local write adapter handles scalar properties of its three
configured objects.

## Calls and retained results

Use `BACnet.Protocol.ObjectExecution.Lifecycle.execute/2` for initialization,
timers, clock changes and dependency changes. A result requesting `:immediate`
must be retained before another step with `:continuation`. The host needs to drain
those continuations before another external operation on that instance.

Use `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` before a computed
read, retain its result and finish continuations, then obtain the value with
`BACnet.Protocol.ObjectTypes.Schedule.get_property/2`. A Calendar read performed
inside Schedule evaluation must follow the same freshness rule and use the
enclosing operation's supplied time.

For a property write, enforce access and build the candidate with property
functions, then call `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3`.
Commit the returned candidate before executing the property-write trigger.
Preparation failures leave the original result unchanged. A later execution
failure retains the accepted candidate and previous runtime state/request.

## Local identity and datatypes

Set `device_identifier:` in `BACnet.Protocol.ObjectExecution.Context.new/2` to
the containing Device's `BACnet.Protocol.ObjectIdentifier` when Schedule needs
to recognize references that explicitly name the local device. Schedule treats a
reference as local if it omits the device identifier or matches the one in the
context. For a match, Schedule clears the device identifier and preserves the
property array index and write priority. Other device-qualified references reach
the callback unchanged. With the default `device_identifier: nil`, this includes
every device-qualified reference.

Values use `BACnet.Protocol.ApplicationTags.Encoding`, with one consistent non-NULL
datatype across weekly, exception and default values. All primitive application
tags are supported. Target type maps, encoding annotations and primitive codecs
validate local compatibility. Write callbacks receive the original encoding. The
local adapter uses `BACnet.Protocol.ObjectsUtility.cast_property_to_value/4` with the
identifier from the target module's object-identifier getter before applying the
write. It uses `allow_partial: true` for array elements. To relinquish a commandable
Present_Value at the selected priority, handle a NULL write by calling the target's
priority setter with `nil`. Apply array-length writes using the target's resizing
rules. In the Schedule's own time/value entries, NULL means to use the next
applicable value or the schedule default.

## Remote write adapter

Remote-only target lists require a write callback and no object lookup. A network
adapter can forward the encoding directly to `BACnet.Stack.ClientHelper.write_property/6`.
The following factory creates a callback for an already running BACnet client and
a map from Device ObjectIdentifiers to transport destinations. The integrating
application needs to supply those destinations and configure bounded client timeouts.

```elixir
defmodule ExampleRemoteScheduleWriter do
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Stack.ClientHelper

  @spec new(GenServer.server(), %{ObjectIdentifier.t() => term()}) :: Context.write_property()
  def new(client, destinations) do
    fn reference, encoding, priority ->
      case Map.fetch(destinations, reference.device_identifier) do
        {:ok, destination} ->
          ClientHelper.write_property(client, destination, reference.object_identifier,
            reference.property_identifier, encoding,
            array_index: reference.property_array_index, priority: priority)

        :error ->
          {:error, :unknown_device}
      end
    end
  end
end
```

Supply the returned callback as the `write_property:` keyword field to
`BACnet.Protocol.ObjectExecution.Context.new/2`. For mixed local/remote target lists,
the callback needs to route references with a `nil` device identifier through the
local write path, and other references through the remote adapter. A remote object
model is not required. Remote service errors are retained with the complete
reference - property/object Error APDUs set `:configuration_error`, and transport
failures set `:communication_failure` when no configuration fault is present.

## Faults and capabilities

Invalid target configurations and property/type/access rejections set
`:configuration_error`. Other target write failures set `:communication_failure`
when no configuration failure also exists.
Failure details remain in the opaque runtime state. One failed target does not
prevent later valid targets from being attempted. Unchanged reads and ticks do
not blindly retry commands.

When reliability evaluation is inhibited, an explicitly written out-of-service Reliability
can simulate an alternate condition. Both BACnet and local application writes support
this exception. Named and numeric property identifiers are accepted. This standalone
example configures no targets, so no host I/O callbacks are needed:

```elixir
alias BACnet.Protocol.ApplicationTags.Encoding
alias BACnet.Protocol.BACnetArray
alias BACnet.Protocol.DailySchedule
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.Schedule

{:ok, simulation_object} = Schedule.create(52, "Reliability simulation", %{
  out_of_service: true,
  reliability_evaluation_inhibit: true,
  schedule_default: Encoding.create!({:boolean, false}),
  weekly_schedule: BACnetArray.from_list(List.duplicate(%DailySchedule{schedule: []}, 7), true)
})
initial = Context.new(:initialization,
  now: ~U[2026-11-08 10:00:00Z], monotonic_time: 0)
{:ok, simulation_result} = Lifecycle.execute(simulation_object, initial)
write = Context.new({:application_write, :reliability, nil, nil},
  now: initial.now, monotonic_time: 0, state: simulation_result.state)
{:ok, candidate} = Schedule.update_property(simulation_result.object, :reliability, :configuration_error)
{:ok, prepared} = Lifecycle.prepare_write(simulation_result.object, candidate, write)
simulation_result = %{simulation_result | object: prepared}
{:ok, simulation_result} = Lifecycle.execute(simulation_result.object, write)
:configuration_error = simulation_result.object.reliability
true = simulation_result.object.status_flags.fault
```

In service, `present_value` is computed. Out of service, manual changes to that
property still command targets. Neither leaving the effective period nor entering
out-of-service automatically relinquishes previously written commands.

Remote Schedule snapshots remain passive. Remote target writes use the host callback.
See `BACnet.Protocol.ObjectTypes.Schedule` for the full contract, validation
errors and wakeup rules.

## Intrinsic reporting

Create the local object with `intrinsic_reporting: true` to enable reporting.
Changes in Reliability can generate FAULT and NORMAL transitions. A
target configuration error or a transport failure can produce a FAULT.
Target writes can change Reliability during an immediate continuation. Check
the continuation result for a fault or return-to-normal transition after
committing it.

Call `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after
committing each result. The
[intrinsic reporting example](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-intrinsic-transitions)
shows when to send a notification and how to handle acknowledgment.
