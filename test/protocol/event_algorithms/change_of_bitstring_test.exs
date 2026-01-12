defmodule BACnet.Protocol.EventAlgorithms.ChangeOfBitstringTest do
  alias BACnet.Protocol.EventAlgorithms.ChangeOfBitstring
  alias BACnet.Protocol.EventParameters.ChangeOfBitstring, as: Params
  alias BACnet.Protocol.NotificationParameters.ChangeOfBitstring, as: Notify
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :event_algorithms
  @moduletag :protocol_data_structures

  doctest ChangeOfBitstring

  test "assert tag number of event parameters is correct" do
    assert 0 = Params.get_tag_number()
  end

  test "create new state" do
    assert %ChangeOfBitstring{} =
             ChangeOfBitstring.new({false, false}, %Params{
               alarm_values: [{false, true}],
               bitmask: {true, true},
               time_delay: 0,
               time_delay_normal: 0
             })
  end

  test "create new state fails for invalid monitored_value" do
    assert_raise FunctionClauseError, fn ->
      ChangeOfBitstring.new(0, %Params{
        alarm_values: [{false, true}],
        bitmask: {true, true},
        time_delay: 0,
        time_delay_normal: 0
      })
    end
  end

  test "create new state fails for invalid tuple monitored_value" do
    assert_raise ArgumentError, fn ->
      ChangeOfBitstring.new({false, 0}, %Params{
        alarm_values: [{false, true}],
        bitmask: {true, true},
        time_delay: 0,
        time_delay_normal: 0
      })
    end
  end

  test "create new state fails for invalid params" do
    assert_raise FunctionClauseError, fn ->
      ChangeOfBitstring.new({}, %{})
    end
  end

  test "execute on same state stays normal" do
    state =
      ChangeOfBitstring.new({false, false}, %Params{
        alarm_values: [{false, true}],
        bitmask: {true, true},
        time_delay: 0,
        time_delay_normal: 0
      })

    assert {:no_event, ^state} = ChangeOfBitstring.execute(state)
    assert {:no_event, ^state} = ChangeOfBitstring.execute(state)
    assert {:no_event, ^state} = ChangeOfBitstring.execute(state)
    Process.sleep(1000)
    assert {:no_event, ^state} = ChangeOfBitstring.execute(state)
    assert {:no_event, ^state} = ChangeOfBitstring.execute(state)
    assert {:no_event, ^state} = ChangeOfBitstring.execute(state)
  end

  test "execute on state normal and update to offnormal (no time delay)" do
    state =
      ChangeOfBitstring.new({false, false}, %Params{
        alarm_values: [{true, true}],
        bitmask: {true, true},
        time_delay: 0,
        time_delay_normal: nil
      })

    # Value does not match alarm value
    assert {:no_event, ^state} = ChangeOfBitstring.execute(state)

    # Value does not match alarm value
    new_state = %{state | monitored_value: {false, true}}

    assert {:no_event, %{current_state: :normal} = _state} = ChangeOfBitstring.execute(new_state)

    # Value matches alarm value
    new_state2 = %{state | monitored_value: {true, true}}

    assert {:event, %{current_state: :offnormal} = new_state2, event} =
             ChangeOfBitstring.execute(new_state2)

    assert {:no_event, %{current_state: :offnormal} = _state} =
             ChangeOfBitstring.execute(new_state2)

    assert %Notify{referenced_bitstring: {true, true}, status_flags: %StatusFlags{in_alarm: true}} =
             event
  end

  test "execute on state normal and update to offnormal (no time delay), try with second value in alarm values" do
    state =
      ChangeOfBitstring.new({false, false}, %Params{
        alarm_values: [{true, false}, {true, true}],
        bitmask: {true, true},
        time_delay: 0,
        time_delay_normal: nil
      })

    # Value does not match alarm value
    assert {:no_event, ^state} = ChangeOfBitstring.execute(state)

    # Value does not match alarm value
    new_state = %{state | monitored_value: {false, true}}

    assert {:no_event, %{current_state: :normal} = _state} = ChangeOfBitstring.execute(new_state)

    # Value matches alarm value
    new_state2 = %{state | monitored_value: {true, true}}

    assert {:event, %{current_state: :offnormal} = new_state2, event} =
             ChangeOfBitstring.execute(new_state2)

    assert {:no_event, %{current_state: :offnormal} = _state} =
             ChangeOfBitstring.execute(new_state2)

    assert %Notify{referenced_bitstring: {true, true}, status_flags: %StatusFlags{in_alarm: true}} =
             event
  end

  test "execute on state normal and update to offnormal (no time delay) - one bit bitmask" do
    state =
      ChangeOfBitstring.new({false, false}, %Params{
        alarm_values: [{false, true}],
        bitmask: {false, true},
        time_delay: 0,
        time_delay_normal: nil
      })

    # Value does not match alarm value
    assert {:no_event, ^state} = ChangeOfBitstring.execute(state)

    # Value matches alarm value
    new_state = %{state | monitored_value: {false, true}}

    assert {:event, %{current_state: :offnormal} = _state, event} =
             ChangeOfBitstring.execute(new_state)

    assert %Notify{
             referenced_bitstring: {false, true},
             status_flags: %StatusFlags{in_alarm: true}
           } = event

    # Value matches alarm value
    new_state2 = %{state | monitored_value: {true, true}}

    assert {:event, %{current_state: :offnormal} = new_state2, event} =
             ChangeOfBitstring.execute(new_state2)

    assert {:no_event, %{current_state: :offnormal} = _state} =
             ChangeOfBitstring.execute(new_state2)

    assert %Notify{referenced_bitstring: {true, true}, status_flags: %StatusFlags{in_alarm: true}} =
             event

    # Value does not match alarm value
    new_state3 = %{state | monitored_value: {true, false}}

    assert {:no_event, %{current_state: :normal} = _state} = ChangeOfBitstring.execute(new_state3)
  end

  test "execute on state offnormal and update to normal (no time delay)" do
    state =
      ChangeOfBitstring.new({true, true}, %Params{
        alarm_values: [{true, true}],
        bitmask: {true, true},
        time_delay: 0,
        time_delay_normal: nil
      })

    state = %{state | current_state: :offnormal, last_value: {true, true}}

    # Value does not match alarm value
    assert {:no_event, ^state} = ChangeOfBitstring.execute(state)

    # Value does not match alarm value
    new_state = %{state | monitored_value: {false, true}}

    assert {:event, %{current_state: :normal} = _state, event} =
             ChangeOfBitstring.execute(new_state)

    assert %Notify{
             referenced_bitstring: {false, true},
             status_flags: %StatusFlags{in_alarm: false}
           } = event
  end

  test "execute on state offnormal and new event on different alarm value (no time delay)" do
    state =
      ChangeOfBitstring.new({true, true}, %Params{
        alarm_values: [{true, true}, {false, true}],
        bitmask: {true, true},
        time_delay: 0,
        time_delay_normal: nil
      })

    state = %{state | current_state: :offnormal, last_value: {true, true}}

    # Value does not match first alarm value, but second alarm value
    new_state = %{state | monitored_value: {false, true}}

    assert {:event, %{current_state: :offnormal} = _state, event} =
             ChangeOfBitstring.execute(new_state)

    assert %Notify{
             referenced_bitstring: {false, true},
             status_flags: %StatusFlags{in_alarm: true}
           } = event
  end

  test "execute on state normal and update to offnormal and back to normal (with time delay, no time delay normal)" do
    state =
      ChangeOfBitstring.new({false, false}, %Params{
        alarm_values: [{true, true}],
        bitmask: {true, true},
        time_delay: 1,
        time_delay_normal: nil
      })

    assert {:no_event, ^state} = ChangeOfBitstring.execute(state)

    # Value does not match alarm value
    new_state = %{state | monitored_value: {false, true}}

    assert {:no_event, _state} = ChangeOfBitstring.execute(new_state)

    # Value matches alarm value
    new_state2 = %{state | monitored_value: {true, true}}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfBitstring.execute(new_state2)

    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfBitstring.execute(new_state2)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state2 = %{new_state2 | dt_offnormal: DateTime.add(new_state2.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :offnormal} = new_state2, event} =
             ChangeOfBitstring.execute(new_state2)

    assert {:no_event, _state} = ChangeOfBitstring.execute(new_state2)

    assert %Notify{referenced_bitstring: {true, true}, status_flags: %StatusFlags{in_alarm: true}} =
             event

    # Now change back to normal after time_delay
    new_state3 = %{new_state2 | monitored_value: {true, false}}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfBitstring.execute(new_state3)

    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfBitstring.execute(new_state3)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state3 = %{new_state3 | dt_normal: DateTime.add(new_state3.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = new_state3, event2} =
             ChangeOfBitstring.execute(new_state3)

    assert {:no_event, _state} = ChangeOfBitstring.execute(new_state3)

    assert %Notify{
             referenced_bitstring: {true, false},
             status_flags: %StatusFlags{in_alarm: false}
           } = event2
  end

  test "execute on state normal and update to offnormal and back to normal (with time delay and time delay normal)" do
    state =
      ChangeOfBitstring.new({false, false}, %Params{
        alarm_values: [{true, true}],
        bitmask: {true, true},
        time_delay: 1,
        time_delay_normal: 2
      })

    assert {:no_event, ^state} = ChangeOfBitstring.execute(state)

    # Value does not match alarm value
    new_state = %{state | monitored_value: {false, true}}

    assert {:no_event, _state} = ChangeOfBitstring.execute(new_state)

    # Value matches alarm value
    new_state2 = %{state | monitored_value: {true, true}}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfBitstring.execute(new_state2)

    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfBitstring.execute(new_state2)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state2 = %{new_state2 | dt_offnormal: DateTime.add(new_state2.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :offnormal} = new_state2, event} =
             ChangeOfBitstring.execute(new_state2)

    assert {:no_event, _state} = ChangeOfBitstring.execute(new_state2)

    assert %Notify{referenced_bitstring: {true, true}, status_flags: %StatusFlags{in_alarm: true}} =
             event

    # Now change back to normal after time_delay
    new_state3 = %{new_state2 | monitored_value: {true, false}}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfBitstring.execute(new_state3)

    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfBitstring.execute(new_state3)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state3 = %{new_state3 | dt_normal: DateTime.add(new_state3.dt_normal, -1, :second)}

    # No event yet, two seconds need to pass
    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfBitstring.execute(new_state3)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state3 = %{new_state3 | dt_normal: DateTime.add(new_state3.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = new_state3, event2} =
             ChangeOfBitstring.execute(new_state3)

    assert {:no_event, _state} = ChangeOfBitstring.execute(new_state3)

    assert %Notify{
             referenced_bitstring: {true, false},
             status_flags: %StatusFlags{in_alarm: false}
           } = event2
  end

  test "execute on state offnormal and new event on different alarm value (with time delay)" do
    state =
      ChangeOfBitstring.new({true, true}, %Params{
        alarm_values: [{true, true}, {false, true}],
        bitmask: {true, true},
        time_delay: 1,
        time_delay_normal: nil
      })

    state = %{state | current_state: :offnormal, last_value: {true, true}}

    # Value does not match first alarm value, but second alarm value
    new_state = %{state | monitored_value: {false, true}}

    assert {:delayed_event, %{current_state: :offnormal} = new_state} =
             ChangeOfBitstring.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_offnormal: DateTime.add(new_state.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :offnormal} = _state, event} =
             ChangeOfBitstring.execute(new_state)

    assert %Notify{
             referenced_bitstring: {false, true},
             status_flags: %StatusFlags{in_alarm: true}
           } = event
  end

  test "update invalid params" do
    state =
      ChangeOfBitstring.new({false, false}, %Params{
        alarm_values: [{true, true}],
        bitmask: {true, true},
        time_delay: 1,
        time_delay_normal: 2
      })

    assert_raise ArgumentError, fn -> ChangeOfBitstring.update(state, [:hello]) end
  end

  test "update unknown key" do
    state =
      ChangeOfBitstring.new({false, false}, %Params{
        alarm_values: [{true, true}],
        bitmask: {true, true},
        time_delay: 1,
        time_delay_normal: 2
      })

    assert_raise ArgumentError, fn -> ChangeOfBitstring.update(state, hello: :there) end
  end

  test "update monitored_value" do
    state =
      ChangeOfBitstring.new({false, false}, %Params{
        alarm_values: [{true, true}],
        bitmask: {true, true},
        time_delay: 1,
        time_delay_normal: 2
      })

    assert %ChangeOfBitstring{monitored_value: {true, true}} =
             ChangeOfBitstring.update(state, monitored_value: {true, true})
  end

  test "update monitored_value invalid value" do
    state =
      ChangeOfBitstring.new({false, false}, %Params{
        alarm_values: [{true, true}],
        bitmask: {true, true},
        time_delay: 1,
        time_delay_normal: 2
      })

    assert_raise ArgumentError, fn -> ChangeOfBitstring.update(state, monitored_value: false) end

    assert_raise ArgumentError, fn ->
      ChangeOfBitstring.update(state, monitored_value: {false, 0})
    end
  end

  test "update parameters" do
    state =
      ChangeOfBitstring.new({false, false}, %Params{
        alarm_values: [{true, true}],
        bitmask: {true, true},
        time_delay: 1,
        time_delay_normal: 2
      })

    new_params = %Params{
      alarm_values: [{false, true}],
      bitmask: {true, false},
      time_delay: 1,
      time_delay_normal: nil
    }

    assert %ChangeOfBitstring{parameters: ^new_params} =
             ChangeOfBitstring.update(state, parameters: new_params)
  end

  test "update parameters invalid value" do
    state =
      ChangeOfBitstring.new({false, false}, %Params{
        alarm_values: [{true, true}],
        bitmask: {true, true},
        time_delay: 1,
        time_delay_normal: 2
      })

    assert_raise ArgumentError, fn -> ChangeOfBitstring.update(state, parameters: nil) end
  end

  test "update status_flags" do
    state =
      ChangeOfBitstring.new({false, false}, %Params{
        alarm_values: [{true, true}],
        bitmask: {true, true},
        time_delay: 1,
        time_delay_normal: 2
      })

    new_flags = %StatusFlags{
      in_alarm: true,
      fault: false,
      out_of_service: true,
      overridden: false
    }

    assert %ChangeOfBitstring{status_flags: ^new_flags} =
             ChangeOfBitstring.update(state, status_flags: new_flags)
  end

  test "update status_flags invalid value" do
    state =
      ChangeOfBitstring.new({false, false}, %Params{
        alarm_values: [{true, true}],
        bitmask: {true, true},
        time_delay: 1,
        time_delay_normal: 2
      })

    assert_raise ArgumentError, fn -> ChangeOfBitstring.update(state, status_flags: nil) end
  end
end
