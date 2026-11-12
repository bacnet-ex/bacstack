<!--t: Driving a Multistate Input -->

# Driving a Multistate Input

`BACnet.Protocol.ObjectTypes.MultistateInput` exposes a discrete state determined by a
driver or local algorithm. The
[object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
needs to supply observations, serialize operations and retain results for each instance.

Run the walkthrough with `mix run examples/objects_lifecycle/multistate_input_lifecycle.exs`.
You can also paste the Elixir blocks into IEx in order.

## Initialize and supply a sample

```elixir
alias BACnet.Protocol.BACnetArray
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.MultistateInput

{:ok, object} = MultistateInput.create(10, "Valve position", %{
  number_of_states: 3,
  state_text: BACnetArray.from_list(["Closed", "Partly open", "Open"]),
  present_value: 1,
  interface_value: :undefined,
  reliability: :no_fault_detected
})
{:ok, stored} = Lifecycle.execute(object, Context.new(:initialization))

commit = fn stored, candidate, trigger ->
  context = Context.new(trigger, state: stored.state)

  with {:ok, candidate} <- candidate,
       {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, context) do
    stored = %{stored | object: prepared}
    Lifecycle.execute(stored.object, context)
  end
end

sample = fn stored, value ->
  commit.(stored, MultistateInput.set_input(stored.object, value),
    {:application_write, :present_value, nil, nil})
end

write = fn stored, property, value, origin ->
  commit.(stored, MultistateInput.update_property(stored.object, property, value),
    {origin, property, nil, nil})
end

{:ok, stored} = sample.(stored, 2)
2 = stored.object.present_value
2 = stored.object.interface_value
```

The host needs to retain the complete successful
`BACnet.Protocol.ObjectExecution.Result` before exposing the write. A rejected
write leaves the previous result in storage. Deliver each accepted write, including
same-value writes. `BACnet.Protocol.ObjectTypes.MultistateInput.set_input/2` builds
a candidate and validates the supplied state in 1..Number_Of_States.

## Isolate the simulated value from the observation

```elixir
{:error, :write_access_denied} = write.(stored, :present_value, 2, :property_write)
{:ok, stored} = write.(stored, :out_of_service, true, :property_write)
{:ok, stored} = write.(stored, :present_value, 3, :property_write)
{:ok, stored} = sample.(stored, 1)
3 = stored.object.present_value
1 = stored.object.interface_value

{:ok, stored} = sample.(stored, :undefined)
3 = stored.object.present_value
:undefined = stored.object.interface_value
:no_fault_detected = stored.object.reliability
```

The optional Interface_Value exposes the physical state independently of simulation.
`:undefined` encodes as BACnet NULL. An ordinary simulation write leaves Interface_Value
alone. Use `:application_write` for a local observation and `:property_write` for a BACnet
request, including a request handled by a local callback. The host needs to enforce
service permissions and array indices. BACnet writes to Interface_Value are rejected.

## Simulate Reliability and resume sampling

```elixir
{:ok, stored} = write.(stored, :reliability_evaluation_inhibit, true, :property_write)
{:ok, stored} = write.(stored, :reliability, :process_error, :application_write)
:process_error = stored.object.reliability
true = stored.object.status_flags.fault

{:ok, stored} = write.(stored, :out_of_service, false, :property_write)
3 = stored.object.present_value
:no_fault_detected = stored.object.reliability
false = stored.object.status_flags.fault
{:ok, stored} = sample.(stored, 2)
2 = stored.object.present_value
2 = stored.object.interface_value
```

The Reliability write above is deliberate simulation. The host needs to suppress
automatic driver Reliability reports during isolation. Either origin may supply
simulated Reliability. Returning to service restores a known physical Reliability
report subject to inhibition and preserves the simulated Present_Value until a fresh
sample arrives.

## Resize the state set and read

```elixir
{:error, {:invalid_configuration, :interface_value}} =
  write.(stored, :number_of_states, 1, :application_write)
{:ok, stored} = write.(stored, :number_of_states, 2, :application_write)
["Closed", "Partly open"] = BACnetArray.to_list(stored.object.state_text)
{:error, {:value_failed_property_validation, :state_text}} =
  write.(stored, :state_text, BACnetArray.from_list(["Closed"]), :property_write)

read = Context.new({:property_read, :present_value, nil}, state: stored.state)
{:ok, stored} = Lifecycle.prepare_read(stored.object, read)
{:ok, 2} = MultistateInput.get_property(stored.object, :present_value)
nil = stored.next_execution
```

Number_Of_States is read-only to BACnet clients. Local count edits resize selected labels.
Before reducing the count, bring Present_Value and any known Interface_Value into the
new range. A State_Text replacement must match the existing count.

Retain the result of `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` before
reading. Replace any previous wakeup request with the one from the retained result.
After restart, initialize from restored properties with fresh runtime state and refresh
any suppressed Reliability report retained only in the old state.

## Intrinsic reporting

Create the local object with `intrinsic_reporting: true` to enable reporting.
CHANGE_OF_STATE compares the sampled or simulated Present_Value with
Alarm_Values. FAULT_STATE compares it with Fault_Values while reliability
evaluation is enabled. A state in both lists produces a reliability fault
first. If the fault clears while an alarm applies, the host handles the
committed return-to-normal transition before running its immediate
continuation.

With Fault_Values configured, the fault algorithm supplies Reliability while
evaluation is enabled. Set Reliability_Evaluation_Inhibit to true before an
out-of-service simulation write to retain the written Reliability.

Call `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after
committing each result. The
[intrinsic reporting example](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-intrinsic-transitions)
shows when to send a notification and how to handle acknowledgment.
