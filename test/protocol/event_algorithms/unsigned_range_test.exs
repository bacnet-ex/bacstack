defmodule BACnet.Protocol.EventAlgorithms.UnsignedRangeTest do
  alias BACnet.Protocol.EventAlgorithms.UnsignedRange
  alias BACnet.Protocol.EventParameters.UnsignedRange, as: Params
  alias BACnet.Protocol.NotificationParameters.UnsignedRange, as: Notify
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :event_algorithms
  @moduletag :protocol_data_structures

  doctest UnsignedRange

  test "assert tag number of event parameters is correct" do
    assert 11 = Params.get_tag_number()
  end

  test "create new state" do
    assert %UnsignedRange{} =
             UnsignedRange.new(
               3,
               %Params{
                 low_limit: 2,
                 high_limit: 7,
                 time_delay: 0,
                 time_delay_normal: nil
               }
             )
  end

  test "create new state fails for invalid monitored_value" do
    assert_raise FunctionClauseError, fn ->
      UnsignedRange.new(
        -1,
        %Params{
          low_limit: 2,
          high_limit: 7,
          time_delay: 0,
          time_delay_normal: nil
        }
      )
    end

    assert_raise FunctionClauseError, fn ->
      UnsignedRange.new(0.0, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 0,
        time_delay_normal: nil
      })
    end
  end

  test "create new state fails for invalid params" do
    assert_raise FunctionClauseError, fn ->
      UnsignedRange.new(0, %{})
    end
  end

  test "execute on same state stays normal" do
    state =
      UnsignedRange.new(3, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 0,
        time_delay_normal: nil
      })

    assert {:no_event, ^state} = UnsignedRange.execute(state)
    assert {:no_event, ^state} = UnsignedRange.execute(state)
    assert {:no_event, ^state} = UnsignedRange.execute(state)
    Process.sleep(1000)
    assert {:no_event, ^state} = UnsignedRange.execute(state)
    assert {:no_event, ^state} = UnsignedRange.execute(state)
    assert {:no_event, ^state} = UnsignedRange.execute(state)
  end

  test "execute on state normal and update to high_limit (no time delay)" do
    state =
      UnsignedRange.new(3, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 0,
        time_delay_normal: nil
      })

    # Value is not greater than high limit
    assert {:no_event, ^state} = UnsignedRange.execute(state)

    # Value is not greater than high limit
    new_state = %{state | monitored_value: 7}

    assert {:no_event, %{current_state: :normal} = _state} = UnsignedRange.execute(new_state)

    # Value is greater than high limit
    new_state2 = %{state | monitored_value: 8}

    assert {:event, %{current_state: :high_limit} = new_state2, event} =
             UnsignedRange.execute(new_state2)

    assert {:no_event, %{current_state: :high_limit} = _state} = UnsignedRange.execute(new_state2)

    assert %Notify{
             exceeding_value: 8,
             status_flags: %StatusFlags{in_alarm: true},
             exceeded_limit: 7
           } = event
  end

  test "execute on state normal and update to low_limit (no time delay)" do
    state =
      UnsignedRange.new(3, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 0,
        time_delay_normal: nil
      })

    # Value is not less than low limit
    assert {:no_event, ^state} = UnsignedRange.execute(state)

    # Value is not less than low limit
    new_state = %{state | monitored_value: 2}

    assert {:no_event, %{current_state: :normal} = _state} = UnsignedRange.execute(new_state)

    # Value is less than low limit
    new_state2 = %{state | monitored_value: 1}

    assert {:event, %{current_state: :low_limit} = new_state2, event} =
             UnsignedRange.execute(new_state2)

    assert {:no_event, %{current_state: :low_limit} = _state} = UnsignedRange.execute(new_state2)

    assert %Notify{
             exceeding_value: 1,
             status_flags: %StatusFlags{in_alarm: true},
             exceeded_limit: 2
           } = event
  end

  test "execute on state high_limit and update to normal (no time delay)" do
    state =
      UnsignedRange.new(8, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 0,
        time_delay_normal: nil
      })

    state = %{
      state
      | current_state: :high_limit,
        last_value: 8
    }

    # Value is still on high_limit
    assert {:no_event, ^state} = UnsignedRange.execute(state)

    # Value is not greater than high_limit
    new_state2 = %{state | monitored_value: 7}

    assert {:event, %{current_state: :normal} = _state, event} = UnsignedRange.execute(new_state2)

    assert %Notify{
             exceeding_value: 7,
             status_flags: %StatusFlags{in_alarm: false},
             exceeded_limit: 7
           } = event

    # Value is not greater than high_limit
    new_state3 = %{state | monitored_value: 4}

    assert {:event, %{current_state: :normal} = _state, event2} =
             UnsignedRange.execute(new_state3)

    assert %Notify{
             exceeding_value: 4,
             status_flags: %StatusFlags{in_alarm: false},
             exceeded_limit: 7
           } = event2
  end

  test "execute on state low_limit and update to normal (no time delay)" do
    state =
      UnsignedRange.new(1, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 0,
        time_delay_normal: nil
      })

    state = %{
      state
      | current_state: :low_limit,
        last_value: 1
    }

    # Value is still on low_limit
    assert {:no_event, ^state} = UnsignedRange.execute(state)

    # Value is not less than low_limit
    new_state2 = %{state | monitored_value: 2}

    assert {:event, %{current_state: :normal} = _state, event} = UnsignedRange.execute(new_state2)

    assert %Notify{
             exceeding_value: 2,
             status_flags: %StatusFlags{in_alarm: false},
             exceeded_limit: 2
           } = event

    # Value is greater than low_limit
    new_state3 = %{state | monitored_value: 5}

    assert {:event, %{current_state: :normal} = _state, event2} =
             UnsignedRange.execute(new_state3)

    assert %Notify{
             exceeding_value: 5,
             status_flags: %StatusFlags{in_alarm: false},
             exceeded_limit: 2
           } = event2
  end

  test "execute on state high_limit and update to low_limit (no time delay)" do
    state =
      UnsignedRange.new(8, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 0,
        time_delay_normal: nil
      })

    state = %{
      state
      | current_state: :high_limit,
        last_value: 8
    }

    # Value is still on high_limit
    assert {:no_event, ^state} = UnsignedRange.execute(state)

    # Value is less than low_limit
    new_state = %{state | monitored_value: 1}

    assert {:event, %{current_state: :low_limit} = _state, event} =
             UnsignedRange.execute(new_state)

    assert %Notify{
             exceeding_value: 1,
             status_flags: %StatusFlags{in_alarm: true},
             exceeded_limit: 2
           } = event
  end

  test "execute on state low_limit and update to high_limit (no time delay)" do
    state =
      UnsignedRange.new(1, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 0,
        time_delay_normal: nil
      })

    state = %{
      state
      | current_state: :low_limit,
        last_value: 1
    }

    # Value is still on low_limit
    assert {:no_event, ^state} = UnsignedRange.execute(state)

    # Value is greater than high_limit
    new_state2 = %{state | monitored_value: 8}

    assert {:event, %{current_state: :high_limit} = _state, event} =
             UnsignedRange.execute(new_state2)

    assert %Notify{
             exceeding_value: 8,
             status_flags: %StatusFlags{in_alarm: true},
             exceeded_limit: 7
           } = event
  end

  test "execute on state normal and update to high_limit (with time delay, no time delay normal)" do
    state =
      UnsignedRange.new(3, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 1,
        time_delay_normal: nil
      })

    # Value is not greater than high limit
    assert {:no_event, ^state} = UnsignedRange.execute(state)

    # Value is greater than high limit
    new_state = %{state | monitored_value: 8}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state} =
             UnsignedRange.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_offnormal: DateTime.add(new_state.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :high_limit} = new_state, event} =
             UnsignedRange.execute(new_state)

    assert {:no_event, %{current_state: :high_limit} = _state} = UnsignedRange.execute(new_state)

    assert %Notify{
             exceeding_value: 8,
             status_flags: %StatusFlags{in_alarm: true},
             exceeded_limit: 7
           } = event
  end

  test "execute on state normal and update to low_limit (with time delay, no time delay normal)" do
    state =
      UnsignedRange.new(3, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 1,
        time_delay_normal: nil
      })

    # Value is not less than low limit
    assert {:no_event, ^state} = UnsignedRange.execute(state)

    # Value is less than low limit
    new_state = %{state | monitored_value: 1}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state} =
             UnsignedRange.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_offnormal: DateTime.add(new_state.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :low_limit} = new_state, event} =
             UnsignedRange.execute(new_state)

    assert {:no_event, %{current_state: :low_limit} = _state} = UnsignedRange.execute(new_state)

    assert %Notify{
             exceeding_value: 1,
             status_flags: %StatusFlags{in_alarm: true},
             exceeded_limit: 2
           } = event
  end

  test "execute on state high_limit and update to normal (with time delay, no time delay normal)" do
    state =
      UnsignedRange.new(8, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 1,
        time_delay_normal: nil
      })

    state = %{
      state
      | current_state: :high_limit,
        last_value: 8
    }

    # Value is still on high_limit
    assert {:no_event, ^state} = UnsignedRange.execute(state)

    # Value is not greater than high_limit
    new_state = %{state | monitored_value: 4}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :high_limit} = new_state} =
             UnsignedRange.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_normal: DateTime.add(new_state.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = _state, event} = UnsignedRange.execute(new_state)

    assert %Notify{
             exceeding_value: 4,
             status_flags: %StatusFlags{in_alarm: false},
             exceeded_limit: 7
           } = event
  end

  test "execute on state low_limit and update to normal (with time delay, no time delay normal)" do
    state =
      UnsignedRange.new(1, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 1,
        time_delay_normal: nil
      })

    state = %{
      state
      | current_state: :low_limit,
        last_value: 1
    }

    # Value is still on low_limit
    assert {:no_event, ^state} = UnsignedRange.execute(state)

    # Value is greater than low_limit
    new_state = %{state | monitored_value: 2}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :low_limit} = new_state} =
             UnsignedRange.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_normal: DateTime.add(new_state.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = _state, event} = UnsignedRange.execute(new_state)

    assert %Notify{
             exceeding_value: 2,
             status_flags: %StatusFlags{in_alarm: false},
             exceeded_limit: 2
           } = event
  end

  test "execute on state high_limit and update to low_limit (with time delay, no time delay normal)" do
    state =
      UnsignedRange.new(8, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 1,
        time_delay_normal: nil
      })

    state = %{
      state
      | current_state: :high_limit,
        last_value: 8
    }

    # Value is still on high_limit
    assert {:no_event, ^state} = UnsignedRange.execute(state)

    # Value is less than low_limit
    new_state = %{state | monitored_value: 1}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :high_limit} = new_state} =
             UnsignedRange.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_offnormal: DateTime.add(new_state.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :low_limit} = _state, event} =
             UnsignedRange.execute(new_state)

    assert %Notify{
             exceeding_value: 1,
             status_flags: %StatusFlags{in_alarm: true},
             exceeded_limit: 2
           } = event
  end

  test "execute on state low_limit and update to high_limit (with time delay, no time delay normal)" do
    state =
      UnsignedRange.new(1, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 1,
        time_delay_normal: nil
      })

    state = %{
      state
      | current_state: :low_limit,
        last_value: 1
    }

    # Value is still on low_limit
    assert {:no_event, ^state} = UnsignedRange.execute(state)

    # Value is greater than high_limit
    new_state = %{state | monitored_value: 8}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :low_limit} = new_state} =
             UnsignedRange.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_offnormal: DateTime.add(new_state.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :high_limit} = _state, event} =
             UnsignedRange.execute(new_state)

    assert %Notify{
             exceeding_value: 8,
             status_flags: %StatusFlags{in_alarm: true},
             exceeded_limit: 7
           } = event
  end

  test "execute on state high_limit and update to normal (with time delay and time delay normal)" do
    state =
      UnsignedRange.new(8, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 1,
        time_delay_normal: 2
      })

    state = %{
      state
      | current_state: :high_limit,
        last_value: 8
    }

    # Value is still on high_limit
    assert {:no_event, ^state} = UnsignedRange.execute(state)

    # Value is not greater than high_limit
    new_state = %{state | monitored_value: 7}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :high_limit} = new_state} =
             UnsignedRange.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_normal: DateTime.add(new_state.dt_normal, -1, :second)}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :high_limit} = new_state} =
             UnsignedRange.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_normal: DateTime.add(new_state.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = _state, event} = UnsignedRange.execute(new_state)

    assert %Notify{
             exceeding_value: 7,
             status_flags: %StatusFlags{in_alarm: false},
             exceeded_limit: 7
           } = event
  end

  test "execute on state low_limit and update to normal (with time delay and time delay normal)" do
    state =
      UnsignedRange.new(1, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 1,
        time_delay_normal: 2
      })

    state = %{
      state
      | current_state: :low_limit,
        last_value: 1
    }

    # Value is still on low_limit
    assert {:no_event, ^state} = UnsignedRange.execute(state)

    # Value is greater than low_limit
    new_state = %{state | monitored_value: 2}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :low_limit} = new_state} =
             UnsignedRange.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_normal: DateTime.add(new_state.dt_normal, -1, :second)}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :low_limit} = new_state} =
             UnsignedRange.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_normal: DateTime.add(new_state.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = _state, event} = UnsignedRange.execute(new_state)

    assert %Notify{
             exceeding_value: 2,
             status_flags: %StatusFlags{in_alarm: false},
             exceeded_limit: 2
           } = event
  end

  test "update invalid params" do
    state =
      UnsignedRange.new(3, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 0,
        time_delay_normal: nil
      })

    assert_raise ArgumentError, fn -> UnsignedRange.update(state, [:hello]) end
  end

  test "update unknown key" do
    state =
      UnsignedRange.new(3, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 0,
        time_delay_normal: nil
      })

    assert_raise ArgumentError, fn -> UnsignedRange.update(state, hello: :there) end
  end

  test "update monitored_value" do
    state =
      UnsignedRange.new(3, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 0,
        time_delay_normal: nil
      })

    assert %UnsignedRange{monitored_value: 6} =
             UnsignedRange.update(state, monitored_value: 6)
  end

  test "update monitored_value invalid value" do
    state =
      UnsignedRange.new(3, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 0,
        time_delay_normal: nil
      })

    assert_raise ArgumentError, fn -> UnsignedRange.update(state, monitored_value: false) end
    assert_raise ArgumentError, fn -> UnsignedRange.update(state, monitored_value: 0.0) end
    assert_raise ArgumentError, fn -> UnsignedRange.update(state, monitored_value: -1) end
  end

  test "update parameters" do
    state =
      UnsignedRange.new(3, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 0,
        time_delay_normal: nil
      })

    new_params = %Params{
      low_limit: 1,
      high_limit: 3,
      time_delay: 15,
      time_delay_normal: 5
    }

    assert %UnsignedRange{parameters: ^new_params} =
             UnsignedRange.update(state, parameters: new_params)
  end

  test "update parameters invalid value" do
    state =
      UnsignedRange.new(3, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 0,
        time_delay_normal: nil
      })

    assert_raise ArgumentError, fn -> UnsignedRange.update(state, parameters: nil) end
  end

  test "update status_flags" do
    state =
      UnsignedRange.new(3, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 0,
        time_delay_normal: nil
      })

    new_flags = %StatusFlags{
      in_alarm: true,
      fault: false,
      out_of_service: true,
      overridden: false
    }

    assert %UnsignedRange{status_flags: ^new_flags} =
             UnsignedRange.update(state, status_flags: new_flags)
  end

  test "update status_flags invalid value" do
    state =
      UnsignedRange.new(3, %Params{
        low_limit: 2,
        high_limit: 7,
        time_delay: 0,
        time_delay_normal: nil
      })

    assert_raise ArgumentError, fn -> UnsignedRange.update(state, status_flags: nil) end
  end
end
