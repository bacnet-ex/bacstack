defmodule BACnet.Protocol.EventAlgorithms.ChangeOfValueTest do
  alias BACnet.Protocol.EventAlgorithms.ChangeOfValue
  alias BACnet.Protocol.EventParameters.ChangeOfValue, as: Params
  alias BACnet.Protocol.NotificationParameters.ChangeOfValue, as: Notify
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :event_algorithms
  @moduletag :protocol_data_structures

  doctest ChangeOfValue

  test "assert tag number of event parameters is correct" do
    assert 2 = Params.get_tag_number()
  end

  test "create new state bitstring" do
    assert %ChangeOfValue{} =
             ChangeOfValue.new({false, false}, %Params{
               increment: nil,
               bitmask: {true, false},
               time_delay: 0,
               time_delay_normal: 0
             })
  end

  test "create new state bitstring fails for invalid tuple monitored_value" do
    assert_raise ArgumentError, fn ->
      ChangeOfValue.new({false, 0}, %Params{
        increment: nil,
        bitmask: {true, false},
        time_delay: 0,
        time_delay_normal: 0
      })
    end
  end

  test "create new state bitstring fails for invalid params" do
    assert_raise ArgumentError, fn ->
      ChangeOfValue.new({false, 0}, %Params{
        increment: nil,
        bitmask: nil,
        time_delay: 0,
        time_delay_normal: 0
      })
    end
  end

  test "create new state float" do
    assert %ChangeOfValue{} =
             ChangeOfValue.new(0.0, %Params{
               increment: 1.0,
               bitmask: nil,
               time_delay: 0,
               time_delay_normal: 0
             })
  end

  test "create new state float fails for invalid params" do
    assert_raise ArgumentError, fn ->
      ChangeOfValue.new(0.0, %Params{
        increment: nil,
        bitmask: nil,
        time_delay: 0,
        time_delay_normal: 0
      })
    end
  end

  test "create new state fails for invalid monitored_value" do
    assert_raise FunctionClauseError, fn ->
      ChangeOfValue.new(0, %Params{
        increment: nil,
        bitmask: {true, false},
        time_delay: 0,
        time_delay_normal: 0
      })
    end
  end

  test "create new state fails for invalid params" do
    assert_raise FunctionClauseError, fn ->
      ChangeOfValue.new({}, %{})
    end
  end

  test "bitstring execute on same state stays normal" do
    state =
      ChangeOfValue.new({false, false}, %Params{
        increment: nil,
        bitmask: {true, false},
        time_delay: 0,
        time_delay_normal: 0
      })

    assert {:no_event, ^state} = ChangeOfValue.execute(state)
    assert {:no_event, ^state} = ChangeOfValue.execute(state)
    assert {:no_event, ^state} = ChangeOfValue.execute(state)
    Process.sleep(1000)
    assert {:no_event, ^state} = ChangeOfValue.execute(state)
    assert {:no_event, ^state} = ChangeOfValue.execute(state)
    assert {:no_event, ^state} = ChangeOfValue.execute(state)
  end

  test "bitstring execute on state normal (no time delay)" do
    state =
      ChangeOfValue.new({false, false}, %Params{
        increment: nil,
        bitmask: {true, false},
        time_delay: 0,
        time_delay_normal: nil
      })

    # Value does not match bitmask
    assert {:no_event, ^state} = ChangeOfValue.execute(state)

    # Value does not match bitmask
    new_state = %{state | monitored_value: {false, true}}

    assert {:no_event, %{current_state: :normal} = _state} = ChangeOfValue.execute(new_state)

    # Value matches bitmask
    new_state2 = %{state | monitored_value: {true, true}}

    assert {:event, %{current_state: :normal} = new_state2, event} =
             ChangeOfValue.execute(new_state2)

    assert {:no_event, %{current_state: :normal} = _state} =
             ChangeOfValue.execute(new_state2)

    assert %Notify{
             changed_bits: {true, true},
             changed_value: nil,
             status_flags: %StatusFlags{in_alarm: false}
           } =
             event
  end

  test "bitstring execute on state normal with change back (with time delay, no time delay normal)" do
    state =
      ChangeOfValue.new({false, false}, %Params{
        increment: nil,
        bitmask: {true, false},
        time_delay: 1,
        time_delay_normal: nil
      })

    assert {:no_event, ^state} = ChangeOfValue.execute(state)

    # Value does not match bitmask
    new_state = %{state | monitored_value: {false, true}}

    assert {:no_event, _state} = ChangeOfValue.execute(new_state)

    # Value matches bitmask
    new_state2 = %{state | monitored_value: {true, true}}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfValue.execute(new_state2)

    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfValue.execute(new_state2)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state2 = %{new_state2 | dt_normal: DateTime.add(new_state2.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = new_state2, event} =
             ChangeOfValue.execute(new_state2)

    assert {:no_event, _state} = ChangeOfValue.execute(new_state2)

    assert %Notify{
             changed_bits: {true, true},
             changed_value: nil,
             status_flags: %StatusFlags{in_alarm: false}
           } =
             event

    # Now change back to normal after time_delay
    new_state3 = %{new_state2 | monitored_value: {true, false}}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state3} =
             ChangeOfValue.execute(new_state3)

    assert {:delayed_event, %{current_state: :normal} = new_state3} =
             ChangeOfValue.execute(new_state3)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state3 = %{new_state3 | dt_normal: DateTime.add(new_state3.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = new_state3, event2} =
             ChangeOfValue.execute(new_state3)

    assert {:no_event, _state} = ChangeOfValue.execute(new_state3)

    assert %Notify{
             changed_bits: {true, false},
             changed_value: nil,
             status_flags: %StatusFlags{in_alarm: false}
           } = event2
  end

  test "bitstring execute on state normal (with time delay and time delay normal)" do
    state =
      ChangeOfValue.new({false, false}, %Params{
        increment: nil,
        bitmask: {true, false},
        time_delay: 1,
        time_delay_normal: 2
      })

    assert {:no_event, ^state} = ChangeOfValue.execute(state)

    # Value does not match bitmask
    new_state = %{state | monitored_value: {false, true}}

    assert {:no_event, _state} = ChangeOfValue.execute(new_state)

    # Value matches bitmask
    new_state2 = %{new_state | monitored_value: {true, false}}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfValue.execute(new_state2)

    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfValue.execute(new_state2)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state2 = %{new_state2 | dt_normal: DateTime.add(new_state2.dt_normal, -1, :second)}

    # No event yet, two seconds need to pass
    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfValue.execute(new_state2)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state2 = %{new_state2 | dt_normal: DateTime.add(new_state2.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = new_state2, event2} =
             ChangeOfValue.execute(new_state2)

    assert {:no_event, _state} = ChangeOfValue.execute(new_state2)

    assert %Notify{
             changed_bits: {true, false},
             changed_value: nil,
             status_flags: %StatusFlags{in_alarm: false}
           } = event2
  end

  test "float execute on same state stays normal" do
    state =
      ChangeOfValue.new(0.0, %Params{
        increment: 1.0,
        bitmask: nil,
        time_delay: 0,
        time_delay_normal: 0
      })

    assert {:no_event, ^state} = ChangeOfValue.execute(state)
    assert {:no_event, ^state} = ChangeOfValue.execute(state)
    assert {:no_event, ^state} = ChangeOfValue.execute(state)
    Process.sleep(1000)
    assert {:no_event, ^state} = ChangeOfValue.execute(state)
    assert {:no_event, ^state} = ChangeOfValue.execute(state)
    assert {:no_event, ^state} = ChangeOfValue.execute(state)
  end

  test "float execute on state normal (no time delay)" do
    state =
      ChangeOfValue.new(0.0, %Params{
        increment: 1.0,
        bitmask: nil,
        time_delay: 0,
        time_delay_normal: 0
      })

    # Value does not match increment
    assert {:no_event, ^state} = ChangeOfValue.execute(state)

    # Value does not match increment
    new_state = %{state | monitored_value: 0.5}

    assert {:no_event, %{current_state: :normal} = _state} = ChangeOfValue.execute(new_state)

    # Value matches increment
    new_state2 = %{state | monitored_value: 1.0}

    assert {:event, %{current_state: :normal} = new_state2, event} =
             ChangeOfValue.execute(new_state2)

    assert {:no_event, %{current_state: :normal} = _state} =
             ChangeOfValue.execute(new_state2)

    assert %Notify{
             changed_bits: nil,
             changed_value: 1.0,
             status_flags: %StatusFlags{in_alarm: false}
           } =
             event

    # Value matches increment (negative)
    new_state3 = %{state | monitored_value: -1.0}

    assert {:event, %{current_state: :normal} = new_state3, event2} =
             ChangeOfValue.execute(new_state3)

    assert {:no_event, %{current_state: :normal} = _state} =
             ChangeOfValue.execute(new_state3)

    assert %Notify{
             changed_bits: nil,
             changed_value: -1.0,
             status_flags: %StatusFlags{in_alarm: false}
           } =
             event2
  end

  test "float execute on state normal with change back (with time delay, no time delay normal)" do
    state =
      ChangeOfValue.new(0.0, %Params{
        increment: 1.0,
        bitmask: nil,
        time_delay: 1,
        time_delay_normal: nil
      })

    assert {:no_event, ^state} = ChangeOfValue.execute(state)

    # Value does not match increment
    new_state = %{state | monitored_value: 0.6}

    assert {:no_event, _state} = ChangeOfValue.execute(new_state)

    # Value matches increment
    new_state2 = %{state | monitored_value: 1.0}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfValue.execute(new_state2)

    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfValue.execute(new_state2)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state2 = %{new_state2 | dt_normal: DateTime.add(new_state2.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = new_state2, event} =
             ChangeOfValue.execute(new_state2)

    assert {:no_event, _state} = ChangeOfValue.execute(new_state2)

    assert %Notify{
             changed_bits: nil,
             changed_value: 1.0,
             status_flags: %StatusFlags{in_alarm: false}
           } =
             event

    # Now change back to normal after time_delay
    new_state3 = %{new_state2 | monitored_value: +0.0}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state3} =
             ChangeOfValue.execute(new_state3)

    assert {:delayed_event, %{current_state: :normal} = new_state3} =
             ChangeOfValue.execute(new_state3)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state3 = %{new_state3 | dt_normal: DateTime.add(new_state3.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = new_state3, event2} =
             ChangeOfValue.execute(new_state3)

    assert {:no_event, _state} = ChangeOfValue.execute(new_state3)

    assert %Notify{
             changed_bits: nil,
             changed_value: +0.0,
             status_flags: %StatusFlags{in_alarm: false}
           } = event2
  end

  test "float execute on state normal (with time delay and time delay normal)" do
    state =
      ChangeOfValue.new(0.0, %Params{
        increment: 1.0,
        bitmask: nil,
        time_delay: 1,
        time_delay_normal: 2
      })

    assert {:no_event, ^state} = ChangeOfValue.execute(state)

    # Value does not match increment
    new_state = %{state | monitored_value: 0.6}

    assert {:no_event, _state} = ChangeOfValue.execute(new_state)

    # Value matches increment
    new_state2 = %{new_state | monitored_value: 1.0}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfValue.execute(new_state2)

    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfValue.execute(new_state2)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state2 = %{new_state2 | dt_normal: DateTime.add(new_state2.dt_normal, -1, :second)}

    # No event yet, two seconds need to pass
    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfValue.execute(new_state2)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state2 = %{new_state2 | dt_normal: DateTime.add(new_state2.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = new_state2, event2} =
             ChangeOfValue.execute(new_state2)

    assert {:no_event, _state} = ChangeOfValue.execute(new_state2)

    assert %Notify{
             changed_bits: nil,
             changed_value: 1.0,
             status_flags: %StatusFlags{in_alarm: false}
           } = event2
  end

  test "update invalid params" do
    state =
      ChangeOfValue.new({false, false}, %Params{
        increment: nil,
        bitmask: {true, false},
        time_delay: 1,
        time_delay_normal: 2
      })

    assert_raise ArgumentError, fn -> ChangeOfValue.update(state, [:hello]) end
  end

  test "update unknown key" do
    state =
      ChangeOfValue.new({false, false}, %Params{
        increment: nil,
        bitmask: {true, false},
        time_delay: 1,
        time_delay_normal: 2
      })

    assert_raise ArgumentError, fn -> ChangeOfValue.update(state, hello: :there) end
  end

  test "update monitored_value bitstring" do
    state =
      ChangeOfValue.new({false, false}, %Params{
        increment: nil,
        bitmask: {true, false},
        time_delay: 1,
        time_delay_normal: 2
      })

    assert %ChangeOfValue{monitored_value: {true, true}} =
             ChangeOfValue.update(state, monitored_value: {true, true})
  end

  test "update monitored_value float" do
    state =
      ChangeOfValue.new(0.3, %Params{
        increment: 1.0,
        bitmask: nil,
        time_delay: 1,
        time_delay_normal: 2
      })

    assert %ChangeOfValue{monitored_value: +0.0} =
             ChangeOfValue.update(state, monitored_value: 0.0)
  end

  test "update monitored_value bitstring invalid value" do
    state =
      ChangeOfValue.new({false, false}, %Params{
        increment: nil,
        bitmask: {true, false},
        time_delay: 1,
        time_delay_normal: 2
      })

    assert_raise ArgumentError, fn -> ChangeOfValue.update(state, monitored_value: false) end
    assert_raise ArgumentError, fn -> ChangeOfValue.update(state, monitored_value: {false, 0}) end
  end

  test "update monitored_value float invalid value" do
    state =
      ChangeOfValue.new(0.0, %Params{
        increment: 0.0,
        bitmask: nil,
        time_delay: 1,
        time_delay_normal: 2
      })

    assert_raise ArgumentError, fn -> ChangeOfValue.update(state, monitored_value: false) end
    assert_raise ArgumentError, fn -> ChangeOfValue.update(state, monitored_value: 5) end
  end

  test "update parameters bitstring" do
    state =
      ChangeOfValue.new({false, false}, %Params{
        increment: nil,
        bitmask: {true, false},
        time_delay: 1,
        time_delay_normal: 2
      })

    new_params = %Params{
      increment: nil,
      bitmask: {true, false},
      time_delay: 1,
      time_delay_normal: nil
    }

    assert %ChangeOfValue{parameters: ^new_params} =
             ChangeOfValue.update(state, parameters: new_params)
  end

  test "update parameters float" do
    state =
      ChangeOfValue.new(6.9, %Params{
        increment: 1.0,
        bitmask: nil,
        time_delay: 1,
        time_delay_normal: 2
      })

    new_params = %Params{
      increment: 12.0,
      bitmask: nil,
      time_delay: 1,
      time_delay_normal: nil
    }

    assert %ChangeOfValue{parameters: ^new_params} =
             ChangeOfValue.update(state, parameters: new_params)
  end

  test "update parameters bitstring invalid value" do
    state =
      ChangeOfValue.new({false, false}, %Params{
        increment: nil,
        bitmask: {true, false},
        time_delay: 1,
        time_delay_normal: 2
      })

    assert_raise ArgumentError, fn -> ChangeOfValue.update(state, parameters: nil) end
  end

  test "update parameters float invalid value" do
    state =
      ChangeOfValue.new(0.0, %Params{
        increment: 1.0,
        bitmask: nil,
        time_delay: 1,
        time_delay_normal: 2
      })

    assert_raise ArgumentError, fn -> ChangeOfValue.update(state, parameters: nil) end
  end

  test "update status_flags bitstring" do
    state =
      ChangeOfValue.new({false, false}, %Params{
        increment: nil,
        bitmask: {true, false},
        time_delay: 1,
        time_delay_normal: 2
      })

    new_flags = %StatusFlags{
      in_alarm: true,
      fault: false,
      out_of_service: true,
      overridden: false
    }

    assert %ChangeOfValue{status_flags: ^new_flags} =
             ChangeOfValue.update(state, status_flags: new_flags)
  end

  test "update status_flags bitstring invalid value" do
    state =
      ChangeOfValue.new({false, false}, %Params{
        increment: nil,
        bitmask: {true, false},
        time_delay: 1,
        time_delay_normal: 2
      })

    assert_raise ArgumentError, fn -> ChangeOfValue.update(state, status_flags: nil) end
  end

  test "update status_flags float" do
    state =
      ChangeOfValue.new(0.0, %Params{
        increment: 1.0,
        bitmask: nil,
        time_delay: 1,
        time_delay_normal: 2
      })

    new_flags = %StatusFlags{
      in_alarm: true,
      fault: false,
      out_of_service: true,
      overridden: false
    }

    assert %ChangeOfValue{status_flags: ^new_flags} =
             ChangeOfValue.update(state, status_flags: new_flags)
  end

  test "update status_flags float invalid value" do
    state =
      ChangeOfValue.new(0.0, %Params{
        increment: 1.0,
        bitmask: nil,
        time_delay: 1,
        time_delay_normal: 2
      })

    assert_raise ArgumentError, fn -> ChangeOfValue.update(state, status_flags: nil) end
  end
end
