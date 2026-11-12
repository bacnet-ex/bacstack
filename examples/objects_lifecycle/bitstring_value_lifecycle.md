<!--t: Driving a Bitstring Value -->

# Driving a Bitstring Value

`BACnet.Protocol.ObjectTypes.BitstringValue` represents a BACnet BIT STRING as a
tuple of booleans. This example uses a commandable two-bit value with one label
per bit. Run `mix run examples/objects_lifecycle/bitstring_value_lifecycle.exs`
or paste the Elixir blocks into IEx in order.

## Initialize and command the value

```elixir
alias BACnet.Protocol.BACnetArray
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.BitstringValue

{:ok, object} =
  BitstringValue.create(60, "Flags", %{
    present_value: {false, false},
    relinquish_default: {false, false},
    bit_text: BACnetArray.from_list(["Occupied", "Ventilating"]),
    reliability: :no_fault_detected
  })

{:ok, stored} = Lifecycle.execute(object, Context.new(:initialization))

commit = fn stored, candidate, trigger ->
  context = Context.new(trigger, state: stored.state)

  with {:ok, candidate} <- candidate,
       {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, context) do
    Lifecycle.execute(prepared, context)
  end
end

command = fn stored, value, origin, priority ->
  candidate = BitstringValue.set_priority(stored.object, priority || 16, value)
  commit.(stored, candidate, {origin, :present_value, nil, priority})
end

write = fn stored, property, value, origin ->
  candidate = BitstringValue.update_property(stored.object, property, value)
  commit.(stored, candidate, {origin, property, nil, nil})
end

{:ok, stored} = command.(stored, {true, false}, :application_write, nil)
{:ok, stored} = command.(stored, {false, true}, :property_write, 8)
{false, true} = stored.object.present_value
{true, false} = stored.object.priority_array.priority_16
{:ok, "Occupied"} = BACnetArray.get_item(stored.object.bit_text, 1)
```

Selecting Relinquish_Default also selects Priority_Array. Supply each command
as a complete bit string to `BACnet.Protocol.ObjectTypes.BitstringValue.set_priority/3`.
Use priority 16 when a BACnet command omits its priority. Priority 6 is reserved.
For a non-commandable instance, write Present_Value directly with
`BACnet.Protocol.ObjectTypes.BitstringValue.update_property/3`.

The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
needs to enforce write permissions and retain the complete
`BACnet.Protocol.ObjectExecution.Result` after each successful operation.
A failed operation leaves the prior result in storage.

## Validate labels and relinquish commands

```elixir
{:error, {:invalid_configuration, :bit_text}} =
  command.(stored, {true}, :property_write, 16)

{:error, {:invalid_configuration, :bit_text}} =
  write.(stored, :bit_text, BACnetArray.from_list(["Occupied"]), :application_write)

{:ok, stored} = command.(stored, nil, :property_write, 8)
{true, false} = stored.object.present_value
{:ok, stored} = command.(stored, nil, :property_write, 16)
{false, false} = stored.object.present_value
```

Bit 0 is described by label 1, and bit 1 by label 2. With two labels selected,
every stored command and the default must have two bits. The one-bit command
at priority 16 is rejected because it would have only one bit when it later
takes effect. Likewise, replacing the labels with a one-element array fails.

A BACnet NULL command clears a slot. Clearing priority 8 exposes priority 16.
Clearing priority 16 leaves the array empty, so Present_Value follows
Relinquish_Default. To change the bit count, remove Bit_Text, update the
values and commands, then add a matching label array.

## Simulate while out of service

```elixir
{:ok, stored} = write.(stored, :out_of_service, true, :property_write)
{:error, :out_of_service} = command.(stored, {true, true}, :application_write, nil)
{:ok, stored} = command.(stored, {true, true}, :property_write, 8)

{:ok, stored} = write.(stored, :reliability_evaluation_inhibit, true, :property_write)
{:ok, stored} = write.(stored, :reliability, :process_error, :application_write)
:process_error = stored.object.reliability
true = stored.object.status_flags.fault

{:ok, stored} = write.(stored, :out_of_service, false, :application_write)
:no_fault_detected = stored.object.reliability
false = stored.object.status_flags.fault

read = Context.new({:property_read, :present_value, nil}, state: stored.state)
{:ok, stored} = Lifecycle.prepare_read(stored.object, read)
{:ok, {true, true}} = BitstringValue.get_property(stored.object, :present_value)
nil = stored.next_execution
```

While out of service, BACnet commands continue to arbitrate and local application
value writes are blocked. Either origin can supply a simulated Reliability report.
Returning to service keeps the effective command and masks Reliability while
inhibition remains enabled.

Retain the result of `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2`
before reading. An active reporting delay can request a monotonic wakeup. After a
restart, initialize the restored properties with fresh runtime state and refresh any Reliability report
held only in the previous state.

## Intrinsic reporting

Create the local object with `intrinsic_reporting: true` to enable reporting.
CHANGE_OF_BITSTRING applies Bit_Mask to Present_Value, then compares the
masked value with Alarm_Values. Choose which bits participate in detection
through the mask. An alarm match needs to persist for Time_Delay, and
Time_Delay_Normal governs recovery after the match clears.

Call `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after
committing each result. The
[intrinsic reporting example](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-intrinsic-transitions)
shows when to send a notification and how to handle acknowledgment.
