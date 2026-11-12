defmodule BACnet.Test.Protocol.ObjectExecution.EventReportingTest do
  use ExUnit.Case, async: true

  alias BACnet.Protocol.EventAlgorithms.ChangeOfState
  alias BACnet.Protocol.EventAlgorithms.None
  alias BACnet.Protocol.EventParameters
  alias BACnet.Protocol.FaultAlgorithms.FaultState
  alias BACnet.Protocol.FaultParameters
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.ObjectTypes.BinaryInput
  alias BACnet.Protocol.PropertyState

  test "the fault runner distinguishes initial and retained transitions" do
    fault = %PropertyState{type: :unsigned_value, value: 2}
    normal = %{fault | value: 1}
    parameters = %FaultParameters.FaultState{fault_values: [fault]}

    assert {:multi_state_fault, state, :initial} =
             EventReporting.run_fault_algorithm(FaultState, [fault, parameters], [], nil)

    assert {:multi_state_fault, ^state, nil} =
             EventReporting.run_fault_algorithm(FaultState, [fault, parameters], [], state)

    assert {:no_fault_detected, _recovered, :retained} =
             EventReporting.run_fault_algorithm(
               FaultState,
               [fault, parameters],
               [monitored_value: normal],
               state
             )
  end

  test "records event fields without a class, acknowledges the timestamp and resets detection" do
    {:ok, object} = BinaryInput.create(10, "Input", %{}, intrinsic_reporting: true)
    ctx = Context.new(:periodic, now: ~U[2026-11-11 10:00:00Z], monotonic_time: 10)
    {alarm, transition} = EventReporting.record(object, :offnormal, :change_of_state, nil, ctx)

    result = %Result{
      object: alarm,
      state: %{reporting: %{transition: transition}},
      next_execution: nil
    }

    assert EventReporting.transition(result) == transition
    assert EventReporting.transition(%{result | state: %{transition: transition}}) == nil
    assert EventReporting.transition(%{result | state: nil}) == nil

    assert transition.routing == nil
    assert transition.from_state == :normal
    assert alarm.event_state == :offnormal
    assert alarm.status_flags.in_alarm
    assert alarm.event_timestamps.to_offnormal == transition.timestamp
    assert alarm.event_message_texts.to_offnormal == transition.message_text

    assert {:ok, acknowledged} =
             EventReporting.acknowledge(alarm, :to_offnormal, transition.timestamp)

    assert acknowledged.acked_transitions.to_offnormal

    assert {:error, {:services, :invalid_timestamp}} =
             EventReporting.acknowledge(
               object,
               :to_offnormal,
               ObjectsMacro.get_default_bacnet_timestamp()
             )

    assert EventReporting.reset(alarm) == object
  end

  test "builds a normal notification with the live value and the alarm flag cleared" do
    value = %PropertyState{type: :binary_value, value: true}

    parameters = %EventParameters.ChangeOfState{
      alarm_values: [value],
      time_delay: 0,
      time_delay_normal: nil
    }

    algorithm = ChangeOfState.new(value, parameters)

    assert %{new_state: ^value, status_flags: %{in_alarm: false}} =
             EventReporting.normal_notification(algorithm)
  end

  test "algorithms without notification parameters yield no normal payload" do
    assert EventReporting.normal_notification(%None{}) == nil
  end
end
