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

{:ok, stored} = write.(stored, :out_of_service, true, 1300)
nil = stored.next_execution
{:ok, stored} = write.(stored, :present_value, 3, 1300)

{:ok, stored} =
  Accumulator.record_pulses(stored.object, 50, context.(stored, :periodic, 1400, []))

3 = stored.object.present_value

{:ok, stored} = write.(stored, :out_of_service, false, 1500)
8 = stored.object.present_value
0 = stored.object.pulse_rate
2500 = stored.next_execution.monotonic_time
