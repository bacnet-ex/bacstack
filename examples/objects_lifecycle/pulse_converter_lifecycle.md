<!--t: Driving a Pulse Converter -->

# Driving a Pulse Converter

`BACnet.Protocol.ObjectTypes.PulseConverter` turns an input pulse count
into a measured quantity such as energy or water usage. Run the walkthrough
with `mix run examples/objects_lifecycle/pulse_converter_lifecycle.exs`, or
run the Elixir blocks in order in IEx.

## Count pulses directly

```elixir
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

{:ok, stored} = PulseConverter.record_pulses(stored.object, 3, context.(stored, :periodic, 100, []))
8 = stored.object.count
20.0 = stored.object.present_value
```

With no Input_Reference, supply each batch of raw pulses to
`BACnet.Protocol.ObjectTypes.PulseConverter.record_pulses/3`. Three pulses
take Count from five to eight. At 2.5 units per pulse, Present_Value becomes
20.0. Update_Time is stamped with the context's device-local time. The
[object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
needs to retain the full result before the next operation.

## Correct the count

```elixir
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
```

The adjustment of 6.0 divides by 2.5 to give 2.4. Truncating the quotient
toward zero gives two counts to subtract. Count_Change_Time records the
adjustment and Update_Time still refers to the pulse batch. The second
write would subtract eight from six, so it fails before changing the stored
result. Repeating an accepted adjustment applies it again.

## Follow a local count reference

```elixir
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
```

The first source reading establishes a baseline of 100 and preserves the
restored Count of 12. The increase to 104 adds four to the converter's Count.
A source decrease establishes a fresh baseline. The host supplies a local
read callback and either delivers a matching source-change trigger or
drives periodic sampling. With reporting selected, also service any wakeup returned
by the converter.

## Simulate the value

```elixir
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
```

While isolated, referenced reads can advance Count without replacing the
simulated Present_Value. Direct pulse batches are ignored while isolated.
Returning to service exposes the value derived from the retained Count.
After a restart, initialize restored properties and establish a fresh
reference baseline.

## Intrinsic reporting

Create the local object with `intrinsic_reporting: true` to enable reporting.
OUT_OF_RANGE evaluates the scaled Present_Value against enabled Low_Limit
and High_Limit checks, with Deadband governing recovery. The monitored
value comes from the same lifecycle that handles pulse batches, referenced
counts, and out-of-service simulation. A reference or acquisition fault
takes precedence over a limit alarm. A reporting delay can add a monotonic
wakeup alongside the host's own source sampling schedule.

Call `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after
committing each result. The
[intrinsic reporting example](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-intrinsic-transitions)
shows when to send a notification and how to handle acknowledgment.
