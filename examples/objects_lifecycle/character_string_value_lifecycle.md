<!--t: Driving a Character String Value -->

# Driving a Character String Value

`BACnet.Protocol.ObjectTypes.CharacterStringValue` exposes an Elixir UTF-8 string as
a BACnet CHARACTER STRING. This example uses priorities to choose the message shown
to an operator. Run `mix run examples/objects_lifecycle/character_string_value_lifecycle.exs`
or paste the Elixir blocks into IEx in order.

## Initialize and command the message

```elixir
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.CharacterStringValue

{:ok, object} =
  CharacterStringValue.create(40, "Operator message", %{
    present_value: "Idle",
    relinquish_default: "Idle",
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
  candidate = CharacterStringValue.set_priority(stored.object, priority || 16, value)
  commit.(stored, candidate, {origin, :present_value, nil, priority})
end

write = fn stored, property, value, origin ->
  candidate = CharacterStringValue.update_property(stored.object, property, value)
  commit.(stored, candidate, {origin, property, nil, nil})
end

{:ok, stored} = command.(stored, "Lüftung bereit", :application_write, nil)
{:ok, stored} = command.(stored, "", :property_write, 8)
"" = stored.object.present_value
"Lüftung bereit" = stored.object.priority_array.priority_16
```

Selecting Relinquish_Default also selects Priority_Array. Use
`BACnet.Protocol.ObjectTypes.CharacterStringValue.set_priority/3` for commands.
Use priority 16 when a BACnet command omits its priority. Priority 6 is reserved.
A non-commandable instance accepts direct Present_Value writes through
`BACnet.Protocol.ObjectTypes.CharacterStringValue.update_property/3`.

The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
needs to serialize operations, enforce write permissions and retain the complete
`BACnet.Protocol.ObjectExecution.Result` after each successful operation.
A failed operation leaves the prior result in storage.

## Relinquish a command

```elixir
{:ok, stored} = command.(stored, nil, :property_write, 8)
"Lüftung bereit" = stored.object.present_value
{:ok, stored} = command.(stored, nil, :property_write, 16)
"Idle" = stored.object.present_value
```

The empty string at priority 8 is an active command, so the message stays blank
until that slot is cleared. The host passes nil for a BACnet NULL command.
Clearing priority 8 exposes the message at priority 16. Clearing priority 16
leaves no active slots, so the message falls back to Relinquish_Default.

## Simulate while out of service

```elixir
{:ok, stored} = write.(stored, :out_of_service, true, :property_write)
{:error, :out_of_service} = command.(stored, "Running", :application_write, nil)
{:ok, stored} = command.(stored, "Test message", :property_write, 8)

{:ok, stored} = write.(stored, :reliability_evaluation_inhibit, true, :property_write)
{:ok, stored} = write.(stored, :reliability, :process_error, :application_write)
:process_error = stored.object.reliability
true = stored.object.status_flags.fault

{:ok, stored} = write.(stored, :out_of_service, false, :application_write)
:no_fault_detected = stored.object.reliability
false = stored.object.status_flags.fault

read = Context.new({:property_read, :present_value, nil}, state: stored.state)
{:ok, stored} = Lifecycle.prepare_read(stored.object, read)
{:ok, "Test message"} = CharacterStringValue.get_property(stored.object, :present_value)
nil = stored.next_execution
```

Out of service, local application writes to Present_Value are blocked. BACnet
commands still arbitrate. Either write origin can supply a simulated Reliability
report. Returning to service keeps the current message and masks Reliability
while inhibition remains enabled.

Retain the result of `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2`
before reading. An active reporting delay can request a monotonic wakeup. After a
restart, initialize the restored properties with fresh runtime state and refresh any Reliability report
held only in the previous state.

## Intrinsic reporting

Create the local object with `intrinsic_reporting: true` to enable reporting.
CHANGE_OF_CHARACTERSTRING matches Present_Value against Alarm_Values.
FAULT_CHARACTERSTRING uses Fault_Values while reliability evaluation is
enabled. A configured nonempty string can match a substring of Present_Value,
and an empty string matches an empty Present_Value. When both algorithms
match, the fault takes precedence.

With Fault_Values configured, the fault algorithm supplies Reliability while
evaluation is enabled. Set Reliability_Evaluation_Inhibit to true before an
out-of-service simulation write to retain the written Reliability.

Call `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after
committing each result. The
[intrinsic reporting example](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-intrinsic-transitions)
shows when to send a notification and how to handle acknowledgment.
