defmodule BACnet.Protocol.FaultAlgorithms.FaultLifeSafetyTest do
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.FaultAlgorithms.FaultLifeSafety
  alias BACnet.Protocol.FaultParameters.FaultLifeSafety, as: Params
  alias BACnet.Protocol.ObjectIdentifier

  use ExUnit.Case, async: true

  @moduletag :fault_algorithms
  @moduletag :protocol_data_structures

  doctest FaultLifeSafety

  @mode_objref %DeviceObjectPropertyRef{
    object_identifier: %ObjectIdentifier{type: :integer_value, instance: 0},
    property_identifier: :present_value,
    property_array_index: nil,
    device_identifier: nil
  }

  test "assert tag number of fault parameters is correct" do
    assert 3 = Params.get_tag_number()
  end

  test "create new state" do
    assert %FaultLifeSafety{} =
             FaultLifeSafety.new(:active, :off, %Params{
               fault_values: [:fault],
               mode: @mode_objref
             })
  end

  test "create new state fails for invalid monitored_value" do
    assert_raise FunctionClauseError, fn ->
      FaultLifeSafety.new(0, :off, %Params{
        fault_values: [:fault],
        mode: @mode_objref
      })
    end

    assert_raise ArgumentError, fn ->
      FaultLifeSafety.new(:hello, :off, %Params{
        fault_values: [:fault],
        mode: @mode_objref
      })
    end
  end

  test "create new state fails for invalid mode" do
    assert_raise FunctionClauseError, fn ->
      FaultLifeSafety.new(:active, 0, %Params{
        fault_values: [:fault],
        mode: @mode_objref
      })
    end

    assert_raise ArgumentError, fn ->
      FaultLifeSafety.new(:active, :hello, %Params{
        fault_values: [:fault],
        mode: @mode_objref
      })
    end
  end

  test "create new state fails for invalid params" do
    assert_raise FunctionClauseError, fn ->
      FaultLifeSafety.new(:active, :off, %{})
    end
  end

  test "execute on same state stays no_fault_detected" do
    state =
      FaultLifeSafety.new(:active, :off, %Params{
        fault_values: [:fault],
        mode: @mode_objref
      })

    assert {:no_event, ^state} = FaultLifeSafety.execute(state)
    assert {:no_event, ^state} = FaultLifeSafety.execute(state)
    assert {:no_event, ^state} = FaultLifeSafety.execute(state)
    Process.sleep(1000)
    assert {:no_event, ^state} = FaultLifeSafety.execute(state)
    assert {:no_event, ^state} = FaultLifeSafety.execute(state)
    assert {:no_event, ^state} = FaultLifeSafety.execute(state)
  end

  test "execute on state no_fault_detected and update to multi_state_fault" do
    state =
      FaultLifeSafety.new(:blocked, :off, %Params{
        fault_values: [:fault],
        mode: @mode_objref
      })

    assert {:no_event, ^state} = FaultLifeSafety.execute(state)
    state2 = %{state | monitored_value: :fault}

    assert {:event, %FaultLifeSafety{current_reliability: :multi_state_fault}, :multi_state_fault} =
             FaultLifeSafety.execute(state2)
  end

  test "execute on state no_fault_detected and update to multi_state_fault (second value)" do
    state =
      FaultLifeSafety.new(:blocked, :off, %Params{
        fault_values: [:fault, :alarm],
        mode: @mode_objref
      })

    assert {:no_event, ^state} = FaultLifeSafety.execute(state)
    state2 = %{state | monitored_value: :alarm}

    assert {:event, %FaultLifeSafety{current_reliability: :multi_state_fault}, :multi_state_fault} =
             FaultLifeSafety.execute(state2)
  end

  test "execute on state multi_state_fault and new event on different value" do
    state =
      FaultLifeSafety.new(:alarm, :off, %Params{
        fault_values: [:fault, :alarm],
        mode: @mode_objref
      })

    state = %{state | current_reliability: :multi_state_fault, last_value: :alarm}

    # New monitored_value does not match to the second fault value, but the first fault value
    new_state = %{state | monitored_value: :fault}

    assert {:event, %FaultLifeSafety{current_reliability: :multi_state_fault}, :multi_state_fault} =
             FaultLifeSafety.execute(new_state)
  end

  test "execute on state multi_state_fault and new event on mode change" do
    state =
      FaultLifeSafety.new(:alarm, :off, %Params{
        fault_values: [:fault, :alarm],
        mode: @mode_objref
      })

    state = %{state | current_reliability: :multi_state_fault, last_value: :alarm}

    # Mode change triggers a new event
    new_state = %{state | mode: :test}

    assert {:event, %FaultLifeSafety{current_reliability: :multi_state_fault}, :multi_state_fault} =
             FaultLifeSafety.execute(new_state)
  end

  test "execute on state multi_state_fault and update to no_fault_detected" do
    state =
      FaultLifeSafety.new(:alarm, :off, %Params{
        fault_values: [:fault, :alarm],
        mode: @mode_objref
      })

    state = %{state | current_reliability: :multi_state_fault, last_value: :alarm}

    # New monitored_value does not match any fault values
    new_state = %{state | monitored_value: :active}

    assert {:event, %FaultLifeSafety{current_reliability: :no_fault_detected}, :no_fault_detected} =
             FaultLifeSafety.execute(new_state)
  end

  test "update invalid params" do
    state =
      FaultLifeSafety.new(:active, :off, %Params{
        fault_values: [:fault],
        mode: @mode_objref
      })

    assert_raise ArgumentError, fn -> FaultLifeSafety.update(state, [:hello]) end
  end

  test "update unknown key" do
    state =
      FaultLifeSafety.new(:active, :off, %Params{
        fault_values: [:fault],
        mode: @mode_objref
      })

    assert_raise ArgumentError, fn -> FaultLifeSafety.update(state, hello: :there) end
  end

  test "update monitored_value" do
    state =
      FaultLifeSafety.new(:active, :off, %Params{
        fault_values: [:fault],
        mode: @mode_objref
      })

    assert %FaultLifeSafety{monitored_value: :alarm} =
             FaultLifeSafety.update(state, monitored_value: :alarm)
  end

  test "update monitored_value invalid value" do
    state =
      FaultLifeSafety.new(:active, :off, %Params{
        fault_values: [:fault],
        mode: @mode_objref
      })

    assert_raise ArgumentError, fn -> FaultLifeSafety.update(state, monitored_value: 0.5) end
    assert_raise ArgumentError, fn -> FaultLifeSafety.update(state, monitored_value: :hello) end
  end

  test "update mode" do
    state =
      FaultLifeSafety.new(:active, :off, %Params{
        fault_values: [:fault],
        mode: @mode_objref
      })

    assert %FaultLifeSafety{mode: :armed} =
             FaultLifeSafety.update(state, mode: :armed)
  end

  test "update mode invalid value" do
    state =
      FaultLifeSafety.new(:active, :off, %Params{
        fault_values: [:fault],
        mode: @mode_objref
      })

    assert_raise ArgumentError, fn -> FaultLifeSafety.update(state, mode: 0.5) end
    assert_raise ArgumentError, fn -> FaultLifeSafety.update(state, mode: :hello) end
  end

  test "update parameters" do
    state =
      FaultLifeSafety.new(:active, :off, %Params{
        fault_values: [:fault],
        mode: @mode_objref
      })

    params = %Params{fault_values: [], mode: @mode_objref}

    assert %FaultLifeSafety{parameters: ^params} =
             FaultLifeSafety.update(state, parameters: params)
  end

  test "update parameters invalid value" do
    state =
      FaultLifeSafety.new(:active, :off, %Params{
        fault_values: [:fault],
        mode: @mode_objref
      })

    assert_raise ArgumentError, fn -> FaultLifeSafety.update(state, parameters: nil) end
  end
end
