defmodule BACnet.Protocol.FaultAlgorithms.FaultStateTest do
  alias BACnet.Protocol.FaultAlgorithms.FaultState
  alias BACnet.Protocol.FaultParameters.FaultState, as: Params
  alias BACnet.Protocol.PropertyState

  use ExUnit.Case, async: true

  @moduletag :fault_algorithms
  @moduletag :protocol_data_structures

  doctest FaultState

  @value %PropertyState{type: :boolean_value, value: false}

  @fault_value1 %PropertyState{type: :boolean_value, value: true}
  @fault_value2 %PropertyState{type: :integer_value, value: 5}
  @fault_value3 %PropertyState{type: :integer_value, value: 13}

  test "assert tag number of fault parameters is correct" do
    assert 4 = Params.get_tag_number()
  end

  test "create new state" do
    assert %FaultState{} =
             FaultState.new(@value, %Params{
               fault_values: [@fault_value1]
             })
  end

  test "create new state fails for invalid monitored_value" do
    assert_raise FunctionClauseError, fn ->
      FaultState.new(0.5, %Params{
        fault_values: [@fault_value1]
      })
    end

    assert_raise FunctionClauseError, fn ->
      FaultState.new(%{}, %Params{
        fault_values: [@fault_value1]
      })
    end

    assert_raise ArgumentError, fn ->
      FaultState.new(@fault_value2, %Params{
        fault_values: [@fault_value1]
      })
    end
  end

  test "create new state fails for invalid params" do
    assert_raise FunctionClauseError, fn ->
      FaultState.new(@value, %{})
    end
  end

  test "execute on same state stays no_fault_detected" do
    state =
      FaultState.new(@value, %Params{
        fault_values: [@fault_value1]
      })

    assert {:no_event, ^state} = FaultState.execute(state)
    assert {:no_event, ^state} = FaultState.execute(state)
    assert {:no_event, ^state} = FaultState.execute(state)
    Process.sleep(1000)
    assert {:no_event, ^state} = FaultState.execute(state)
    assert {:no_event, ^state} = FaultState.execute(state)
    assert {:no_event, ^state} = FaultState.execute(state)
  end

  test "execute on state no_fault_detected and update to multi_state_fault" do
    state =
      FaultState.new(@value, %Params{
        fault_values: [@fault_value1]
      })

    assert {:no_event, ^state} = FaultState.execute(state)
    state2 = %{state | monitored_value: @fault_value1}

    assert {:event, %FaultState{current_reliability: :multi_state_fault}, :multi_state_fault} =
             FaultState.execute(state2)
  end

  test "execute on state no_fault_detected and update to multi_state_fault (second value)" do
    state =
      FaultState.new(%PropertyState{type: :integer_value, value: 0}, %Params{
        fault_values: [@fault_value2, @fault_value3]
      })

    assert {:no_event, ^state} = FaultState.execute(state)
    state2 = %{state | monitored_value: @fault_value3}

    assert {:event, %FaultState{current_reliability: :multi_state_fault}, :multi_state_fault} =
             FaultState.execute(state2)
  end

  test "execute on state multi_state_fault and new event on different value" do
    state =
      FaultState.new(@fault_value2, %Params{
        fault_values: [@fault_value2, @fault_value3]
      })

    state = %{state | current_reliability: :multi_state_fault, last_value: @fault_value2}

    # New monitored_value does not match to the second fault value, but the first fault value
    new_state = %{state | monitored_value: @fault_value3}

    assert {:event, %FaultState{current_reliability: :multi_state_fault}, :multi_state_fault} =
             FaultState.execute(new_state)
  end

  test "execute on state multi_state_fault and update to no_fault_detected" do
    state =
      FaultState.new(@fault_value1, %Params{
        fault_values: [@fault_value1]
      })

    state = %{state | current_reliability: :multi_state_fault, last_value: @fault_value1}

    # New monitored_value does not match any fault values
    new_state = %{state | monitored_value: @value}

    assert {:event, %FaultState{current_reliability: :no_fault_detected}, :no_fault_detected} =
             FaultState.execute(new_state)
  end

  test "update invalid params" do
    state =
      FaultState.new(@value, %Params{
        fault_values: [@fault_value1]
      })

    assert_raise ArgumentError, fn -> FaultState.update(state, [:hello]) end
  end

  test "update unknown key" do
    state =
      FaultState.new(@value, %Params{
        fault_values: [@fault_value1]
      })

    assert_raise ArgumentError, fn -> FaultState.update(state, hello: :there) end
  end

  test "update monitored_value" do
    state =
      FaultState.new(@value, %Params{
        fault_values: [@fault_value1]
      })

    assert %FaultState{monitored_value: @fault_value1} =
             FaultState.update(state, monitored_value: @fault_value1)
  end

  test "update monitored_value invalid value" do
    state =
      FaultState.new(@value, %Params{
        fault_values: [@fault_value1]
      })

    assert_raise ArgumentError, fn -> FaultState.update(state, monitored_value: 0.5) end

    assert_raise ArgumentError, fn ->
      FaultState.update(state, monitored_value: @fault_value2)
    end
  end

  test "update parameters" do
    state =
      FaultState.new(@value, %Params{
        fault_values: [@fault_value1]
      })

    params = %Params{fault_values: []}

    assert %FaultState{parameters: ^params} =
             FaultState.update(state, parameters: params)
  end

  test "update parameters invalid value" do
    state =
      FaultState.new(@value, %Params{
        fault_values: [@fault_value1]
      })

    params = %Params{fault_values: [@fault_value2]}

    assert_raise ArgumentError, fn -> FaultState.update(state, parameters: nil) end
    assert_raise ArgumentError, fn -> FaultState.update(state, parameters: params) end
  end
end
