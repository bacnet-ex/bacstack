defmodule BACnet.Protocol.AlarmSummaryTest do
  alias BACnet.Protocol.AlarmSummary
  alias BACnet.Protocol.EventTransitionBits
  alias BACnet.Protocol.ObjectIdentifier

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest AlarmSummary

  test "decode alarm summary" do
    assert {:ok,
            {%AlarmSummary{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1},
               alarm_state: :normal,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: true,
                 to_normal: false
               }
             },
             []}} =
             AlarmSummary.parse([
               {:object_identifier, %ObjectIdentifier{type: :analog_input, instance: 1}},
               {:enumerated, 0},
               {:bitstring, {false, true, false}}
             ])
  end

  test "decode alarm summary 2" do
    assert {:ok,
            {%AlarmSummary{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1},
               alarm_state: :fault,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: false,
                 to_normal: false
               }
             },
             []}} =
             AlarmSummary.parse([
               {:object_identifier, %ObjectIdentifier{type: :analog_input, instance: 1}},
               {:enumerated, 1},
               {:bitstring, {true, false, false}}
             ])
  end

  test "decode alarm summary 3" do
    assert {:ok,
            {%AlarmSummary{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1},
               alarm_state: :normal,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: false,
                 to_normal: true
               }
             },
             []}} =
             AlarmSummary.parse([
               {:object_identifier, %ObjectIdentifier{type: :analog_input, instance: 1}},
               {:enumerated, 0},
               {:bitstring, {false, false, true}}
             ])
  end

  test "decode invalid alarm summary" do
    assert {:error, :invalid_tags} =
             AlarmSummary.parse([
               {:object_identifier, %ObjectIdentifier{type: :analog_input, instance: 1}},
               {:enumerated, 0}
             ])
  end

  test "decode invalid alarm summary unknown alarm state" do
    assert {:error, {:unknown_state, 255}} =
             AlarmSummary.parse([
               {:object_identifier, %ObjectIdentifier{type: :analog_input, instance: 1}},
               {:enumerated, 255},
               {:bitstring, {false, false, true}}
             ])
  end

  test "encode alarm summary" do
    assert {:ok,
            [
              {:object_identifier, %ObjectIdentifier{type: :analog_input, instance: 1}},
              {:enumerated, 0},
              {:bitstring, {true, true, false}}
            ]} =
             AlarmSummary.encode(%AlarmSummary{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1},
               alarm_state: :normal,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: false
               }
             })
  end

  test "encode alarm summary invalid alarm state" do
    assert {:error, {:unknown_state, :hello_there}} =
             AlarmSummary.encode(%AlarmSummary{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1},
               alarm_state: :hello_there,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: true,
                 to_fault: true,
                 to_normal: false
               }
             })
  end

  test "valid alarm summary" do
    assert true ==
             AlarmSummary.valid?(%AlarmSummary{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1},
               alarm_state: :normal,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: true,
                 to_normal: false
               }
             })

    assert true ==
             AlarmSummary.valid?(%AlarmSummary{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1},
               alarm_state: :fault,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: true,
                 to_normal: false
               }
             })
  end

  test "invalid alarm summary" do
    assert false ==
             AlarmSummary.valid?(%AlarmSummary{
               object_identifier: :hello,
               alarm_state: :fault,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: true,
                 to_normal: false
               }
             })

    assert false ==
             AlarmSummary.valid?(%AlarmSummary{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1},
               alarm_state: 523,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: true,
                 to_normal: false
               }
             })

    assert false ==
             AlarmSummary.valid?(%AlarmSummary{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1},
               alarm_state: :fault,
               acknowledged_transitions: %EventTransitionBits{
                 to_offnormal: false,
                 to_fault: :hello,
                 to_normal: false
               }
             })

    assert false ==
             AlarmSummary.valid?(%AlarmSummary{
               object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1},
               alarm_state: :normal,
               acknowledged_transitions: :hello
             })
  end
end
