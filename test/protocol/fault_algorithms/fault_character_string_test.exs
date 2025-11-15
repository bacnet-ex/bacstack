defmodule BACnet.Protocol.FaultAlgorithms.FaultCharacterStringTest do
  alias BACnet.Protocol.FaultAlgorithms.FaultCharacterString
  alias BACnet.Protocol.FaultParameters.FaultCharacterString, as: Params

  use ExUnit.Case, async: true

  @moduletag :fault_algorithms
  @moduletag :protocol_data_structures

  doctest FaultCharacterString

  test "assert tag number of fault parameters is correct" do
    assert 1 = Params.get_tag_number()
  end

  test "create new state" do
    assert %FaultCharacterString{} =
             FaultCharacterString.new("Hello World", %Params{
               fault_values: ["Hello"]
             })
  end

  test "create new state fails for invalid monitored_value" do
    assert_raise FunctionClauseError, fn ->
      FaultCharacterString.new(0.5, %Params{
        fault_values: ["Hello"]
      })
    end

    assert_raise ArgumentError, fn ->
      FaultCharacterString.new(<<255, 255, 255, 252>>, %Params{
        fault_values: ["Hello"]
      })
    end
  end

  test "create new state fails for invalid params" do
    assert_raise FunctionClauseError, fn ->
      FaultCharacterString.new("Hello World", %{})
    end
  end

  test "execute on same state stays no_fault_detected" do
    state =
      FaultCharacterString.new("Hello World", %Params{
        fault_values: ["hello"]
      })

    assert {:no_event, ^state} = FaultCharacterString.execute(state)
    assert {:no_event, ^state} = FaultCharacterString.execute(state)
    assert {:no_event, ^state} = FaultCharacterString.execute(state)
    Process.sleep(1000)
    assert {:no_event, ^state} = FaultCharacterString.execute(state)
    assert {:no_event, ^state} = FaultCharacterString.execute(state)
    assert {:no_event, ^state} = FaultCharacterString.execute(state)
  end

  test "execute on state no_fault_detected and update to multi_state_fault" do
    state =
      FaultCharacterString.new("", %Params{
        fault_values: ["Hello"]
      })

    assert {:no_event, ^state} = FaultCharacterString.execute(state)
    state2 = %{state | monitored_value: "Hello World"}

    assert {:event, %FaultCharacterString{current_reliability: :multi_state_fault},
            :multi_state_fault} = FaultCharacterString.execute(state2)
  end

  test "execute on state no_fault_detected and update to multi_state_fault (end)" do
    state =
      FaultCharacterString.new("", %Params{
        fault_values: ["rld"]
      })

    assert {:no_event, ^state} = FaultCharacterString.execute(state)
    state2 = %{state | monitored_value: "Hello World"}

    assert {:event, %FaultCharacterString{current_reliability: :multi_state_fault} = state3,
            :multi_state_fault} = FaultCharacterString.execute(state2)

    # Event must not repeat on same state
    assert {:no_event, ^state3} = FaultCharacterString.execute(state3)
  end

  test "execute on state no_fault_detected and update to multi_state_fault (middle)" do
    state =
      FaultCharacterString.new("", %Params{
        fault_values: ["lo Wo"]
      })

    assert {:no_event, ^state} = FaultCharacterString.execute(state)
    state2 = %{state | monitored_value: "Hello World"}

    assert {:event, %FaultCharacterString{current_reliability: :multi_state_fault},
            :multi_state_fault} = FaultCharacterString.execute(state2)
  end

  test "execute on state no_fault_detected and stay due to character case sensitivy" do
    state =
      FaultCharacterString.new("", %Params{
        fault_values: ["hello"]
      })

    assert {:no_event, ^state} = FaultCharacterString.execute(state)
    state2 = %{state | monitored_value: "Hello World"}

    assert {:no_event, ^state2} = FaultCharacterString.execute(state2)
  end

  test "execute on state no_fault_detected and stay due not empty monitored_value" do
    state =
      FaultCharacterString.new("Hello World", %Params{
        fault_values: [""]
      })

    assert {:no_event, ^state} = FaultCharacterString.execute(state)
  end

  test "execute on state no_fault_detected and stay due not empty fault value" do
    state =
      FaultCharacterString.new("", %Params{
        fault_values: ["hello"]
      })

    assert {:no_event, ^state} = FaultCharacterString.execute(state)
  end

  test "execute on state no_fault_detected and update to multi_state_fault (second value)" do
    state =
      FaultCharacterString.new("", %Params{
        fault_values: ["hello", "World"]
      })

    assert {:no_event, ^state} = FaultCharacterString.execute(state)
    state2 = %{state | monitored_value: "Hello World"}

    assert {:event, %FaultCharacterString{current_reliability: :multi_state_fault},
            :multi_state_fault} = FaultCharacterString.execute(state2)
  end

  test "execute on state no_fault_detected and update to multi_state_fault (empty value)" do
    state =
      FaultCharacterString.new("World", %Params{
        fault_values: ["hello", ""]
      })

    assert {:no_event, ^state} = FaultCharacterString.execute(state)
    state2 = %{state | monitored_value: ""}

    assert {:event, %FaultCharacterString{current_reliability: :multi_state_fault},
            :multi_state_fault} = FaultCharacterString.execute(state2)
  end

  test "execute on state multi_state_fault and new event on different value" do
    state =
      FaultCharacterString.new("Hello World", %Params{
        fault_values: ["hello", "World"]
      })

    state = %{state | current_reliability: :multi_state_fault, last_fault_value: "World"}

    # New monitored_value does not match to the second fault value, but the first fault value
    new_state = %{state | monitored_value: "hello world"}

    assert {:event, %FaultCharacterString{current_reliability: :multi_state_fault},
            :multi_state_fault} = FaultCharacterString.execute(new_state)
  end

  test "execute on state multi_state_fault and update to no_fault_detected" do
    state =
      FaultCharacterString.new("Hello World", %Params{
        fault_values: ["hello", "World"]
      })

    state = %{state | current_reliability: :multi_state_fault, last_fault_value: "World"}

    # New monitored_value does not match any fault values
    new_state = %{state | monitored_value: "I have the high ground"}

    assert {:event, %FaultCharacterString{current_reliability: :no_fault_detected},
            :no_fault_detected} = FaultCharacterString.execute(new_state)
  end

  test "update invalid params" do
    state =
      FaultCharacterString.new("Hello World", %Params{
        fault_values: ["hello", "World"]
      })

    assert_raise ArgumentError, fn -> FaultCharacterString.update(state, [:hello]) end
  end

  test "update unknown key" do
    state =
      FaultCharacterString.new("Hello World", %Params{
        fault_values: ["hello", "World"]
      })

    assert_raise ArgumentError, fn -> FaultCharacterString.update(state, hello: :there) end
  end

  test "update monitored_value" do
    state =
      FaultCharacterString.new("Hello World", %Params{
        fault_values: ["hello", "World"]
      })

    assert %FaultCharacterString{monitored_value: "hi"} =
             FaultCharacterString.update(state, monitored_value: "hi")
  end

  test "update monitored_value invalid value" do
    state =
      FaultCharacterString.new("Hello World", %Params{
        fault_values: ["hello", "World"]
      })

    assert_raise ArgumentError, fn -> FaultCharacterString.update(state, monitored_value: 0.5) end

    assert_raise ArgumentError, fn ->
      FaultCharacterString.update(state, monitored_value: <<255, 255, 255, 252>>)
    end
  end

  test "update parameters" do
    state =
      FaultCharacterString.new("Hello World", %Params{
        fault_values: ["hello", "World"]
      })

    params = %Params{fault_values: []}

    assert %FaultCharacterString{parameters: ^params} =
             FaultCharacterString.update(state, parameters: params)
  end

  test "update parameters invalid value" do
    state =
      FaultCharacterString.new("Hello World", %Params{
        fault_values: ["hello", "World"]
      })

    assert_raise ArgumentError, fn -> FaultCharacterString.update(state, parameters: nil) end
  end
end
