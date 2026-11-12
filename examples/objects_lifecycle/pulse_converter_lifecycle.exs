alias BACnet.Protocol.DeviceObjectPropertyRef
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectIdentifier
alias BACnet.Protocol.ObjectPropertyRef
alias BACnet.Protocol.ObjectTypes.PulseConverter

start_time = ~U[2026-11-09 12:00:00Z]

context = fn stored, trigger, elapsed, options ->
  Context.new(
    trigger,
    Keyword.merge(
      [
        now: DateTime.add(start_time, elapsed, :millisecond),
        monotonic_time: elapsed,
        state: if(stored, do: stored.state)
      ],
      options
    )
  )
end

{:ok, object} = PulseConverter.create(1, "Water total", %{count: 5, scale_factor: 2.5})
{:ok, stored} = Lifecycle.execute(object, context.(nil, :initialization, 0, []))

{:ok, stored} =
  PulseConverter.record_pulses(stored.object, 3, context.(stored, :periodic, 100, []))

8 = stored.object.count
20.0 = stored.object.present_value

write = fn stored, property, value, elapsed ->
  ctx = context.(stored, {:property_write, property, nil, nil}, elapsed, [])

  with {:ok, candidate} <- PulseConverter.update_property(stored.object, property, value),
       {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
    Lifecycle.execute(prepared, ctx)
  end
end

{:ok, stored} = write.(stored, :adjust_value, 6.0, 200)
8 = stored.object.count_before_change
6 = stored.object.count
15.0 = stored.object.present_value
{:error, {:property_out_of_range, :adjust_value}} = write.(stored, :adjust_value, 20.0, 300)

source = %ObjectIdentifier{type: :accumulator, instance: 3}

input = %ObjectPropertyRef{
  object_identifier: source,
  property_identifier: :present_value,
  property_array_index: nil
}

read_ref = %DeviceObjectPropertyRef{
  device_identifier: nil,
  object_identifier: source,
  property_identifier: :present_value,
  property_array_index: nil
}

read_count = fn count -> fn ^read_ref -> {:ok, count} end end

{:ok, object} =
  PulseConverter.create(2, "Referenced total", %{
    count: 12,
    scale_factor: 2.0,
    input_reference: input
  })

{:ok, referenced} =
  Lifecycle.execute(
    object,
    context.(nil, :initialization, 0, read_property: read_count.(100))
  )

12 = referenced.object.count

{:ok, referenced} =
  Lifecycle.execute(
    referenced.object,
    context.(referenced, :periodic, 100, read_property: read_count.(104))
  )

16 = referenced.object.count
32.0 = referenced.object.present_value
nil = referenced.next_execution

{:ok, referenced} = write.(referenced, :out_of_service, true, 200)
{:ok, referenced} = write.(referenced, :present_value, 99.0, 200)

{:ok, referenced} =
  Lifecycle.execute(
    referenced.object,
    context.(referenced, :periodic, 300, read_property: read_count.(105))
  )

17 = referenced.object.count
99.0 = referenced.object.present_value

{:ok, referenced} = write.(referenced, :out_of_service, false, 400)
34.0 = referenced.object.present_value
