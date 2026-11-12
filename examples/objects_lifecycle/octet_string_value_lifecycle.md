<!--t: Driving an Octet String Value -->

# Driving an Octet String Value

`BACnet.Protocol.ObjectTypes.OctetStringValue` exposes an Elixir binary as
a BACnet OCTET STRING. This example uses priorities to choose a device payload
containing arbitrary bytes. Run `mix run examples/objects_lifecycle/octet_string_value_lifecycle.exs`
or paste the Elixir blocks into IEx in order.

## Initialize and command the payload

```elixir
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.OctetStringValue

{:ok, object} =
  OctetStringValue.create(40, "Device payload", %{
    present_value: <<1, 0>>,
    relinquish_default: <<1, 0>>,
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
  candidate = OctetStringValue.set_priority(stored.object, priority || 16, value)
  commit.(stored, candidate, {origin, :present_value, nil, priority})
end

write = fn stored, property, value, origin ->
  candidate = OctetStringValue.update_property(stored.object, property, value)
  commit.(stored, candidate, {origin, property, nil, nil})
end

{:ok, stored} = command.(stored, <<0, 255, 128>>, :application_write, nil)
{:ok, stored} = command.(stored, <<>>, :property_write, 8)
<<>> = stored.object.present_value
<<0, 255, 128>> = stored.object.priority_array.priority_16
```

Selecting Relinquish_Default also selects Priority_Array. Use
`BACnet.Protocol.ObjectTypes.OctetStringValue.set_priority/3` for commands.
Use priority 16 when a BACnet command omits its priority. Priority 6 is reserved.
A non-commandable instance accepts direct Present_Value writes through
`BACnet.Protocol.ObjectTypes.OctetStringValue.update_property/3`.

The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
needs to serialize operations, enforce write permissions and retain the complete
`BACnet.Protocol.ObjectExecution.Result` after each successful operation.
A failed operation leaves the prior result in storage.

## Relinquish a command

```elixir
{:ok, stored} = command.(stored, nil, :property_write, 8)
<<0, 255, 128>> = stored.object.present_value
{:ok, stored} = command.(stored, nil, :property_write, 16)
<<1, 0>> = stored.object.present_value
```

The empty binary at priority 8 is an active command. The host passes nil for a
BACnet NULL command to clear a slot. Clearing priority 8 exposes the three bytes
at priority 16 exactly as supplied, including the leading zero. Clearing priority
16 leaves no active slots, so Present_Value falls back to Relinquish_Default.

## Simulate while out of service

```elixir
{:ok, stored} = write.(stored, :out_of_service, true, :property_write)
{:error, :out_of_service} = command.(stored, <<2, 0>>, :application_write, nil)
{:ok, stored} = command.(stored, <<0, 128, 255>>, :property_write, 8)

{:ok, stored} = write.(stored, :reliability_evaluation_inhibit, true, :property_write)
{:ok, stored} = write.(stored, :reliability, :process_error, :application_write)
:process_error = stored.object.reliability
true = stored.object.status_flags.fault

{:ok, stored} = write.(stored, :out_of_service, false, :application_write)
:no_fault_detected = stored.object.reliability
false = stored.object.status_flags.fault

read = Context.new({:property_read, :present_value, nil}, state: stored.state)
{:ok, stored} = Lifecycle.prepare_read(stored.object, read)
{:ok, <<0, 128, 255>>} = OctetStringValue.get_property(stored.object, :present_value)
nil = stored.next_execution
```

Out of service, local application writes to Present_Value are blocked. BACnet
commands still arbitrate. Either write origin can supply a simulated Reliability
report. Returning to service keeps the current payload and masks Reliability
while inhibition remains enabled.

Retain the result of `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2`
before reading. Execution requests no wakeup. After a restart, initialize the
restored properties with fresh runtime state and refresh any Reliability report
held only in the previous state.

