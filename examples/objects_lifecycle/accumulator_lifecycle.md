<!--t: Driving an Accumulator -->

# Driving an Accumulator

`BACnet.Protocol.ObjectTypes.Accumulator` counts pulses and rolls over at its
configured limit. The example supplies the pulses and clock samples. Run it with
`mix run examples/objects_lifecycle/accumulator_lifecycle.exs` or run the Elixir
blocks in order in IEx.

## Choose who samples the meter

An Accumulator exposes the live count through Present_Value. Logging_Record
captures the count and the amount accumulated between two samples. A qualified
read takes a sample and starts the next interval. Use Logging_Object when a
single local logger should determine the sampling times and other readers need
to see the last sample.

For example, a logger samples a meter on the hour and a dashboard reads the
same property between samples.

| Time | Reader | Live count | Logging_Record returned |
| --- | --- | ---: | --- |
| 09:00 | Configured logger | 1,200 | New baseline at 09:00, count 1,200, delta 0 |
| 09:30 | Dashboard | 1,235 | Retained 09:00 record, count 1,200, delta 0 |
| 10:00 | Configured logger | 1,280 | New sample at 10:00, count 1,280, delta 80 |

The dashboard read leaves the interval anchored at 09:00. If Logging_Object
were omitted, the dashboard read would take a new sample at 09:30 and the
10:00 sample would report a delta of 45.

## Initialize and acquire the first sample

```elixir
alias BACnet.Protocol.AccumulatorRecord
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectExecution.Wakeup
alias BACnet.Protocol.ObjectIdentifier
alias BACnet.Protocol.ObjectTypes.Accumulator
alias BACnet.Protocol.Prescale

logger = %ObjectIdentifier{type: :trend_log, instance: 2}
start_time = ~U[2026-11-09 12:00:00Z]

context = fn stored, trigger, elapsed, options ->
  Context.new(trigger,
    now: DateTime.add(start_time, elapsed, :millisecond),
    monotonic_time: elapsed,
    state: if(stored, do: stored.state),
    options: options
  )
end

{:ok, object} =
  Accumulator.create(1, "Meter", %{
    present_value: 8,
    prescale: %Prescale{multiplier: 2, modulo_divide: 3},
    scale: 1.0,
    max_present_value: 9,
    value_set: 0,
    limit_monitoring_interval: 1,
    logging_object: logger
  })

{:ok, stored} = Lifecycle.execute(object, context.(nil, :initialization, 0, []))

read_log = fn stored, elapsed, options ->
  read = context.(stored, {:property_read, :logging_record, nil}, elapsed, options)
  Lifecycle.prepare_read(stored.object, read)
end

{:ok, stored} = read_log.(stored, 0, [])
[%AccumulatorRecord{status: :starting, present_value: 0, accumulated_value: 0}] =
  stored.object.logging_record

{:ok, stored} = read_log.(stored, 0, reader_identifier: logger)
[%AccumulatorRecord{status: :starting, present_value: 8, accumulated_value: 0}] =
  stored.object.logging_record
```

The first read above has no reader identifier. It receives the initial STARTING
record, which has zero counts and an unspecified timestamp. The second read
identifies the configured logger. It captures the live count of eight and
starts the first interval. The host supplies the actual local reader's
identifier through `:reader_identifier` and leaves the option unset for network
clients. Retain the successful result of
`BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` before serving
Logging_Record with `BACnet.Protocol.ObjectTypes.Accumulator.get_property/2`.

## Submit raw pulses and complete a rate window

```elixir
{:ok, stored} = Accumulator.record_pulses(stored.object, 3, context.(stored, :periodic, 100, []))
0 = stored.object.present_value

timer = context.(stored, :timer, 1000, [])
true = Wakeup.due?(stored.next_execution, timer)
{:ok, stored} = Lifecycle.execute(stored.object, timer)
3 = stored.object.pulse_rate
2000 = stored.next_execution.monotonic_time

{:ok, stored} = read_log.(stored, 1050, [])
[%AccumulatorRecord{status: :starting, present_value: 8, accumulated_value: 0}] =
  stored.object.logging_record
```

Three raw pulses contribute two units with the configured Prescale. The count
moves from eight to zero because it wraps modulo ten. The rate measures the
three raw pulses over the completed one-second window. The final read in this
block still sees the original logging sample at count eight. The
[object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
needs to retain each successful result and schedule its returned deadline
against the same monotonic clock used for
`BACnet.Protocol.ObjectTypes.Accumulator.record_pulses/3`. When
`BACnet.Protocol.ObjectExecution.Wakeup.due?/2` indicates the deadline is due,
deliver a `:timer` context with fresh clocks.

## Preset and acquire the accumulated delta

```elixir
write = fn stored, property, value, elapsed ->
  ctx = context.(stored, {:property_write, property, nil, nil}, elapsed, [])

  with {:ok, candidate} <- Accumulator.update_property(stored.object, property, value),
       {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
    Lifecycle.execute(prepared, ctx)
  end
end

{:ok, stored} = write.(stored, :value_set, 6, 1100)
0 = stored.object.value_before_change
6 = stored.object.present_value
{:ok, stored} = Accumulator.record_pulses(stored.object, 3, context.(stored, :periodic, 1200, []))

{:ok, stored} = read_log.(stored, 1250, reader_identifier: logger)
[%AccumulatorRecord{status: :recovered, present_value: 8, accumulated_value: 4}] =
  stored.object.logging_record
```

The preset snapshots the previous count and its change time. The two pulse
batches contribute two units each. The preset is excluded from the accumulated
delta and the next qualified record has status RECOVERED. Rejected writes leave
the earlier result in storage.

## Simulate while out of service

```elixir
{:ok, stored} = write.(stored, :out_of_service, true, 1300)
nil = stored.next_execution
{:ok, stored} = write.(stored, :present_value, 3, 1300)
{:ok, stored} = Accumulator.record_pulses(stored.object, 50, context.(stored, :periodic, 1400, []))
3 = stored.object.present_value

{:ok, stored} = write.(stored, :out_of_service, false, 1500)
8 = stored.object.present_value
0 = stored.object.pulse_rate
2500 = stored.next_execution.monotonic_time
```

The host needs to cancel the previous timer when the result has no wakeup.
Pulses submitted while out of service leave the simulated value alone.
Returning to service restores the retained count and starts a new rate window.
After a restart, initialize restored properties with fresh runtime state.

## Intrinsic reporting

Create the local object with `intrinsic_reporting: true` to enable reporting.
UNSIGNED_RANGE evaluates Pulse_Rate against Low_Limit and High_Limit.
Each completed Limit_Monitoring_Interval supplies the rate for this check.
The accumulation and rollover of Present_Value continue independently.
Execution and `BACnet.Protocol.ObjectTypes.Accumulator.record_pulses/3`
return the earlier of any rate-window and reporting deadlines. Replace the
previous timer with the wakeup from the retained result.

Call `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after
committing each result. The
[intrinsic reporting example](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-intrinsic-transitions)
shows when to send a notification and how to handle acknowledgment.
