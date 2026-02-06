defmodule BACnet.Protocol.FaultAlgorithms.FaultStatusFlagsTest do
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.FaultAlgorithms.FaultStatusFlags
  alias BACnet.Protocol.FaultParameters.FaultStatusFlags, as: Params
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :fault_algorithms
  @moduletag :protocol_data_structures

  doctest FaultStatusFlags

  @objref %DeviceObjectPropertyRef{
    object_identifier: %ObjectIdentifier{type: :integer_value, instance: 0},
    property_identifier: :status_flags,
    property_array_index: nil,
    device_identifier: nil
  }

  test "assert tag number of fault parameters is correct" do
    assert 5 = Params.get_tag_number()
  end

  test "create new state" do
    assert %FaultStatusFlags{} =
             FaultStatusFlags.new(
               StatusFlags.from_bitstring({false, false, false, false}),
               %Params{
                 status_flags: @objref
               }
             )
  end

  test "create new state fails for invalid monitored_value" do
    assert_raise FunctionClauseError, fn ->
      FaultStatusFlags.new(0.5, %Params{
        status_flags: @objref
      })
    end
  end

  test "create new state fails for invalid params" do
    assert_raise FunctionClauseError, fn ->
      FaultStatusFlags.new(StatusFlags.from_bitstring({false, false, false, false}), %{})
    end
  end

  test "execute on same state stays no_fault_detected" do
    state =
      FaultStatusFlags.new(StatusFlags.from_bitstring({false, false, false, false}), %Params{
        status_flags: @objref
      })

    assert {:no_event, ^state} = FaultStatusFlags.execute(state)
    assert {:no_event, ^state} = FaultStatusFlags.execute(state)
    assert {:no_event, ^state} = FaultStatusFlags.execute(state)
    Process.sleep(1000)
    assert {:no_event, ^state} = FaultStatusFlags.execute(state)
    assert {:no_event, ^state} = FaultStatusFlags.execute(state)
    assert {:no_event, ^state} = FaultStatusFlags.execute(state)
  end

  test "execute on state no_fault_detected and update to member_fault" do
    state =
      FaultStatusFlags.new(StatusFlags.from_bitstring({false, false, false, false}), %Params{
        status_flags: @objref
      })

    assert {:no_event, ^state} = FaultStatusFlags.execute(state)
    state2 = %{state | monitored_value: StatusFlags.from_bitstring({false, true, false, false})}

    assert {:event, %FaultStatusFlags{current_reliability: :member_fault}, :member_fault} =
             FaultStatusFlags.execute(state2)
  end

  test "execute on state multi_state_fault and update to no_fault_detected" do
    state =
      FaultStatusFlags.new(StatusFlags.from_bitstring({false, true, false, false}), %Params{
        status_flags: @objref
      })

    state = %{state | current_reliability: :member_fault}

    new_state = %{
      state
      | monitored_value: StatusFlags.from_bitstring({false, false, false, false})
    }

    assert {:event, %FaultStatusFlags{current_reliability: :no_fault_detected},
            :no_fault_detected} = FaultStatusFlags.execute(new_state)
  end

  test "update invalid params" do
    state =
      FaultStatusFlags.new(StatusFlags.from_bitstring({false, true, false, false}), %Params{
        status_flags: @objref
      })

    assert_raise ArgumentError, fn -> FaultStatusFlags.update(state, [:hello]) end
  end

  test "update unknown key" do
    state =
      FaultStatusFlags.new(StatusFlags.from_bitstring({false, true, false, false}), %Params{
        status_flags: @objref
      })

    assert_raise ArgumentError, fn -> FaultStatusFlags.update(state, hello: :there) end
  end

  test "update monitored_value" do
    state =
      FaultStatusFlags.new(StatusFlags.from_bitstring({false, true, false, false}), %Params{
        status_flags: @objref
      })

    new_flags = StatusFlags.from_bitstring({false, true, false, false})

    assert %FaultStatusFlags{monitored_value: ^new_flags} =
             FaultStatusFlags.update(state, monitored_value: new_flags)
  end

  test "update monitored_value invalid value" do
    state =
      FaultStatusFlags.new(StatusFlags.from_bitstring({false, true, false, false}), %Params{
        status_flags: @objref
      })

    assert_raise ArgumentError, fn -> FaultStatusFlags.update(state, monitored_value: 0.5) end
  end

  test "update parameters" do
    state =
      FaultStatusFlags.new(StatusFlags.from_bitstring({false, true, false, false}), %Params{
        status_flags: @objref
      })

    params = %Params{
      status_flags: %DeviceObjectPropertyRef{
        object_identifier: %ObjectIdentifier{type: :device, instance: 10},
        property_identifier: :status_flags,
        property_array_index: nil,
        device_identifier: nil
      }
    }

    assert %FaultStatusFlags{parameters: ^params} =
             FaultStatusFlags.update(state, parameters: params)
  end

  test "update parameters invalid value" do
    state =
      FaultStatusFlags.new(StatusFlags.from_bitstring({false, true, false, false}), %Params{
        status_flags: @objref
      })

    assert_raise ArgumentError, fn -> FaultStatusFlags.update(state, parameters: nil) end
  end
end
