<!--t: Driving a Multistate Output -->

# Driving a Multistate Output

`BACnet.Protocol.ObjectTypes.MultistateOutput` represents a command to a
multi-position actuator. The
[object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
needs to serialize writes, retain their results and decide when to apply the
effective command to hardware.

Run the walkthrough from the repository root with
`mix run examples/objects_lifecycle/multistate_output_lifecycle.exs`.
You can also paste the Elixir blocks into IEx in order. They model a driver's
inputs and outputs using values in memory.

## Initialize and command the output

```elixir
alias BACnet.Protocol.BACnetArray
alias BACnet.Protocol.ObjectExecution.Context
alias BACnet.Protocol.ObjectExecution.Lifecycle
alias BACnet.Protocol.ObjectTypes.MultistateOutput

{:ok, object} = MultistateOutput.create(10, "Fan speed", %{
  number_of_states: 3,
  state_text: BACnetArray.from_list(["Off", "Low", "High"]),
  relinquish_default: 1,
  feedback_value: 1,
  interface_value: :undefined,
  reliability: :no_fault_detected
})

start = Context.new(:initialization)
{:ok, stored} = Lifecycle.execute(object, start)
1 = stored.object.present_value
nil = stored.next_execution

write = fn stored, property, value, source, priority ->
  context = Context.new({source, property, nil, priority}, state: stored.state)

  candidate =
    if property == :present_value,
      do: MultistateOutput.set_priority(stored.object, priority || 16, value),
      else: MultistateOutput.update_property(stored.object, property, value)

  with {:ok, candidate} <- candidate,
       {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, context) do
    stored = %{stored | object: prepared}
    Lifecycle.execute(stored.object, context)
  end
end

{:ok, stored} = write.(stored, :present_value, 2, :application_write, nil)
2 = MultistateOutput.get_output(stored.object)
1 = stored.object.feedback_value
:undefined = stored.object.interface_value
```

The host needs to retain the complete successful
`BACnet.Protocol.ObjectExecution.Result` before exposing the write or applying the
command. A rejected write leaves the previous result in storage. Run preparation
and execution for every accepted write, including a command masked by another
priority. The host also needs to enforce service permissions and array indices.

`BACnet.Protocol.ObjectTypes.MultistateOutput.get_output/2` calculates the command
for the driver. The two observation properties keep the values supplied by the
driver. Use `auto_write_feedback: true` when Feedback_Value should instead model
the effective command. Interface_Value remains independent in either mode.

## Isolate hardware and simulate an output state

```elixir
{:ok, stored} = write.(stored, :out_of_service, true, :property_write, nil)
{:ok, stored} = write.(stored, :present_value, 3, :property_write, 8)
3 = stored.object.present_value
1 = MultistateOutput.get_output(stored.object, 1)

{:error, :out_of_service} =
  write.(stored, :feedback_value, 2, :application_write, nil)
{:ok, stored} = write.(stored, :interface_value, 2, :application_write, nil)
2 = stored.object.interface_value
1 = stored.object.feedback_value
```

The host chooses what to do with the equipment while out of service. Here 1 is
the supplied fallback. Both write origins continue to use command prioritization.
BACnet requests retain their origin when handled by a local callback.

A local physical observation can update Interface_Value while the command is
isolated. Select `:undefined` when that observation is unknown, which encodes as
BACnet NULL. Interface_Value is read-only to BACnet clients. Application
Feedback_Value reports are isolated. A BACnet simulation write to Feedback_Value
is available subject to the host's service permissions and the feedback mode.

## Report Reliability and return to service

```elixir
{:ok, stored} = write.(stored, :reliability_evaluation_inhibit, true, :property_write, nil)
{:ok, stored} = write.(stored, :reliability, :process_error, :application_write, nil)
:process_error = stored.object.reliability
true = stored.object.status_flags.fault
{:ok, stored} = write.(stored, :out_of_service, false, :property_write, nil)
:no_fault_detected = stored.object.reliability
false = stored.object.status_flags.fault
3 = MultistateOutput.get_output(stored.object)
```

The Reliability write above is an explicit simulation. The host needs to
suppress automatic hardware Reliability reports during isolation. A retained
physical report becomes effective again on return to service, subject to
inhibition. The driver can then apply the effective command and supply fresh
observations.

## Reconfigure the state count and read the result

```elixir
{:error, {:invalid_configuration, :present_value}} =
  write.(stored, :number_of_states, 2, :application_write, nil)
{:ok, stored} = write.(stored, :present_value, nil, :property_write, 8)
2 = stored.object.present_value
{:ok, stored} = write.(stored, :number_of_states, 2, :application_write, nil)
["Off", "Low"] = BACnetArray.to_list(stored.object.state_text)
{:error, {:value_failed_property_validation, :state_text}} =
  write.(stored, :state_text, BACnetArray.from_list(["Off"]), :property_write, nil)

read = Context.new({:property_read, :present_value, nil}, state: stored.state)
{:ok, stored} = Lifecycle.prepare_read(stored.object, read)
{:ok, 2} = MultistateOutput.get_property(stored.object, :present_value)
nil = stored.next_execution
```

Number_Of_States is read-only to BACnet clients. A local count edit resizes
selected labels. A replacement State_Text array must match the existing count.
A reduction requires every stored command, the default and any known
Interface_Value to fit. Relinquish or update those values first.

Retain the result of `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2`
before reading. Replace any previous wakeup request with the one from the
retained result. After restart, initialize from restored properties
with fresh runtime state. The host needs to refresh any suppressed physical
Reliability report that was retained only in the previous runtime state.

## Intrinsic reporting

Create the local object with `intrinsic_reporting: true` to enable reporting.
COMMAND_FAILURE compares the winning command in Present_Value with
Feedback_Value. Select independent feedback when the actuator reports its
actual state. Modeled feedback follows the winning command. Time_Delay
governs persistent mismatches and Time_Delay_Normal governs recovery after
the values match.

Call `BACnet.Protocol.ObjectExecution.EventReporting.transition/1` after
committing each result. The
[intrinsic reporting example](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-intrinsic-transitions)
shows when to send a notification and how to handle acknowledgment.
