defmodule BACnet.Protocol.EventAlgorithms.SignedOutOfRangeTest do
  alias BACnet.Protocol.EventAlgorithms.SignedOutOfRange
  alias BACnet.Protocol.EventParameters.SignedOutOfRange, as: Params
  alias BACnet.Protocol.LimitEnable
  alias BACnet.Protocol.NotificationParameters.SignedOutOfRange, as: Notify
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :event_algorithms
  @moduletag :protocol_data_structures

  doctest SignedOutOfRange

  test "assert tag number of event parameters is correct" do
    assert 15 = Params.get_tag_number()
  end

  test "create new state" do
    assert %SignedOutOfRange{} =
             SignedOutOfRange.new(
               -1,
               %LimitEnable{low_limit_enable: true, high_limit_enable: true},
               %Params{
                 low_limit: -2,
                 high_limit: 7,
                 deadband: 2,
                 time_delay: 0,
                 time_delay_normal: nil
               }
             )

    assert %SignedOutOfRange{} =
             SignedOutOfRange.new(
               3,
               %LimitEnable{low_limit_enable: true, high_limit_enable: true},
               %Params{
                 low_limit: -2,
                 high_limit: 7,
                 deadband: 2,
                 time_delay: 0,
                 time_delay_normal: nil
               }
             )
  end

  test "create new state fails for invalid monitored_value" do
    assert_raise FunctionClauseError, fn ->
      SignedOutOfRange.new(
        0.0,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 0,
          time_delay_normal: nil
        }
      )
    end
  end

  test "create new state fails for invalid params" do
    assert_raise FunctionClauseError, fn ->
      SignedOutOfRange.new(0, %LimitEnable{low_limit_enable: true, high_limit_enable: true}, %{})
    end
  end

  test "execute on same state stays normal" do
    state =
      SignedOutOfRange.new(
        3,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    assert {:no_event, ^state} = SignedOutOfRange.execute(state)
    assert {:no_event, ^state} = SignedOutOfRange.execute(state)
    assert {:no_event, ^state} = SignedOutOfRange.execute(state)
    Process.sleep(1000)
    assert {:no_event, ^state} = SignedOutOfRange.execute(state)
    assert {:no_event, ^state} = SignedOutOfRange.execute(state)
    assert {:no_event, ^state} = SignedOutOfRange.execute(state)
  end

  test "execute on state normal and update to high_limit (no time delay)" do
    state =
      SignedOutOfRange.new(
        3,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    # Value is not greater than high limit
    assert {:no_event, ^state} = SignedOutOfRange.execute(state)

    # Value is not greater than high limit
    new_state = %{state | monitored_value: 7}

    assert {:no_event, %{current_state: :normal} = _state} = SignedOutOfRange.execute(new_state)

    # Value is greater than high limit
    new_state2 = %{state | monitored_value: 8}

    assert {:event, %{current_state: :high_limit} = new_state2, event} =
             SignedOutOfRange.execute(new_state2)

    assert {:no_event, %{current_state: :high_limit} = _state} =
             SignedOutOfRange.execute(new_state2)

    assert %Notify{
             exceeding_value: 8,
             status_flags: %StatusFlags{in_alarm: true},
             deadband: 2,
             exceeded_limit: 7
           } = event
  end

  test "execute on state normal and stay on normal instead high_limit due to limit enable (no time delay)" do
    state =
      SignedOutOfRange.new(
        3,
        %LimitEnable{low_limit_enable: true, high_limit_enable: false},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    # Value is not greater than high limit
    assert {:no_event, ^state} = SignedOutOfRange.execute(state)

    # Value is greater than high limit
    new_state = %{state | monitored_value: 8}

    assert {:no_event, %{current_state: :normal} = _state} = SignedOutOfRange.execute(new_state)
  end

  test "execute on state normal and update to low_limit (no time delay)" do
    state =
      SignedOutOfRange.new(
        3,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    # Value is not less than low limit
    assert {:no_event, ^state} = SignedOutOfRange.execute(state)

    # Value is not less than low limit
    new_state = %{state | monitored_value: -2}

    assert {:no_event, %{current_state: :normal} = _state} = SignedOutOfRange.execute(new_state)

    # Value is less than low limit
    new_state2 = %{state | monitored_value: -3}

    assert {:event, %{current_state: :low_limit} = new_state2, event} =
             SignedOutOfRange.execute(new_state2)

    assert {:no_event, %{current_state: :low_limit} = _state} =
             SignedOutOfRange.execute(new_state2)

    assert %Notify{
             exceeding_value: -3,
             status_flags: %StatusFlags{in_alarm: true},
             deadband: 2,
             exceeded_limit: -2
           } = event
  end

  test "execute on state normal and stay on normal instead low_limit due to limit enable (no time delay)" do
    state =
      SignedOutOfRange.new(
        3,
        %LimitEnable{low_limit_enable: false, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    # Value is not less than low limit
    assert {:no_event, ^state} = SignedOutOfRange.execute(state)

    # Value is less than low limit
    new_state = %{state | monitored_value: -3}

    assert {:no_event, %{current_state: :normal} = _state} = SignedOutOfRange.execute(new_state)
  end

  test "execute on state high_limit and update to normal (no time delay)" do
    state =
      SignedOutOfRange.new(
        8,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    state = %{
      state
      | current_state: :high_limit,
        last_value: 8
    }

    # Value is still on high_limit
    assert {:no_event, ^state} = SignedOutOfRange.execute(state)

    # Value is not greater than high_limit, but still not below deadband
    new_state = %{state | monitored_value: 5}

    assert {:no_event, ^new_state} = SignedOutOfRange.execute(new_state)

    # Value is not greater than high_limit and below deadband
    new_state2 = %{state | monitored_value: 4}

    assert {:event, %{current_state: :normal} = _state, event} =
             SignedOutOfRange.execute(new_state2)

    assert %Notify{
             exceeding_value: 4,
             status_flags: %StatusFlags{in_alarm: false},
             deadband: 2,
             exceeded_limit: 7
           } = event
  end

  test "execute on state high_limit and update to normal due to limit enable (no time delay)" do
    state =
      SignedOutOfRange.new(
        8,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    state = %{
      state
      | current_state: :high_limit,
        last_value: 8
    }

    # Value is still on high_limit
    assert {:no_event, ^state} = SignedOutOfRange.execute(state)

    # Value is not greater than high_limit, but still not below deadband
    new_state = %{
      state
      | limit_enable: %LimitEnable{low_limit_enable: true, high_limit_enable: false}
    }

    assert {:event, %{current_state: :normal} = _state, event} =
             SignedOutOfRange.execute(new_state)

    assert %Notify{
             exceeding_value: 8,
             status_flags: %StatusFlags{in_alarm: false},
             deadband: 2,
             exceeded_limit: 7
           } = event
  end

  test "execute on state low_limit and update to normal (no time delay)" do
    state =
      SignedOutOfRange.new(
        -3,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    state = %{
      state
      | current_state: :low_limit,
        last_value: -3
    }

    # Value is still on low_limit
    assert {:no_event, ^state} = SignedOutOfRange.execute(state)

    # Value is greater than low_limit, but still not above deadband
    new_state = %{state | monitored_value: 0}

    assert {:no_event, ^new_state} = SignedOutOfRange.execute(new_state)

    # Value is greater than low_limit and above deadband
    new_state2 = %{state | monitored_value: 1}

    assert {:event, %{current_state: :normal} = _state, event} =
             SignedOutOfRange.execute(new_state2)

    assert %Notify{
             exceeding_value: 1,
             status_flags: %StatusFlags{in_alarm: false},
             deadband: 2,
             exceeded_limit: -2
           } = event
  end

  test "execute on state low_limit and update to normal due to limit enable (no time delay)" do
    state =
      SignedOutOfRange.new(
        -3,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    state = %{
      state
      | current_state: :low_limit,
        last_value: -3
    }

    # Value is still on low_limit
    assert {:no_event, ^state} = SignedOutOfRange.execute(state)

    # Value is not greater than high_limit, but still not below deadband
    new_state = %{
      state
      | limit_enable: %LimitEnable{low_limit_enable: false, high_limit_enable: true}
    }

    assert {:event, %{current_state: :normal} = _state, event} =
             SignedOutOfRange.execute(new_state)

    assert %Notify{
             exceeding_value: -3,
             status_flags: %StatusFlags{in_alarm: false},
             deadband: 2,
             exceeded_limit: -2
           } = event
  end

  test "execute on state high_limit and update to low_limit (no time delay)" do
    state =
      SignedOutOfRange.new(
        8,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    state = %{
      state
      | current_state: :high_limit,
        last_value: 8
    }

    # Value is still on high_limit
    assert {:no_event, ^state} = SignedOutOfRange.execute(state)

    # Value is less than low_limit
    new_state = %{state | monitored_value: -3}

    assert {:event, %{current_state: :low_limit} = _state, event} =
             SignedOutOfRange.execute(new_state)

    assert %Notify{
             exceeding_value: -3,
             status_flags: %StatusFlags{in_alarm: true},
             deadband: 2,
             exceeded_limit: -2
           } = event
  end

  test "execute on state low_limit and update to high_limit (no time delay)" do
    state =
      SignedOutOfRange.new(
        -3,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    state = %{
      state
      | current_state: :low_limit,
        last_value: -3
    }

    # Value is still on low_limit
    assert {:no_event, ^state} = SignedOutOfRange.execute(state)

    # Value is greater than high_limit
    new_state2 = %{state | monitored_value: 8}

    assert {:event, %{current_state: :high_limit} = _state, event} =
             SignedOutOfRange.execute(new_state2)

    assert %Notify{
             exceeding_value: 8,
             status_flags: %StatusFlags{in_alarm: true},
             deadband: 2,
             exceeded_limit: 7
           } = event
  end

  test "execute on state normal and update to high_limit (with time delay, no time delay normal)" do
    state =
      SignedOutOfRange.new(
        3,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 1,
          time_delay_normal: nil
        }
      )

    # Value is not greater than high limit
    assert {:no_event, ^state} = SignedOutOfRange.execute(state)

    # Value is greater than high limit
    new_state = %{state | monitored_value: 8}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state} =
             SignedOutOfRange.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_offnormal: DateTime.add(new_state.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :high_limit} = new_state, event} =
             SignedOutOfRange.execute(new_state)

    assert {:no_event, %{current_state: :high_limit} = _state} =
             SignedOutOfRange.execute(new_state)

    assert %Notify{
             exceeding_value: 8,
             status_flags: %StatusFlags{in_alarm: true},
             deadband: 2,
             exceeded_limit: 7
           } = event
  end

  test "execute on state normal and update to low_limit (with time delay, no time delay normal)" do
    state =
      SignedOutOfRange.new(
        3,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 1,
          time_delay_normal: nil
        }
      )

    # Value is not less than low limit
    assert {:no_event, ^state} = SignedOutOfRange.execute(state)

    # Value is less than low limit
    new_state = %{state | monitored_value: -3}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state} =
             SignedOutOfRange.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_offnormal: DateTime.add(new_state.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :low_limit} = new_state, event} =
             SignedOutOfRange.execute(new_state)

    assert {:no_event, %{current_state: :low_limit} = _state} =
             SignedOutOfRange.execute(new_state)

    assert %Notify{
             exceeding_value: -3,
             status_flags: %StatusFlags{in_alarm: true},
             deadband: 2,
             exceeded_limit: -2
           } = event
  end

  test "execute on state high_limit and update to normal (with time delay, no time delay normal)" do
    state =
      SignedOutOfRange.new(
        8,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 1,
          time_delay_normal: nil
        }
      )

    state = %{
      state
      | current_state: :high_limit,
        last_value: 8
    }

    # Value is still on high_limit
    assert {:no_event, ^state} = SignedOutOfRange.execute(state)

    # Value is not greater than high_limit and below deadband
    new_state = %{state | monitored_value: 4}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :high_limit} = new_state} =
             SignedOutOfRange.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_normal: DateTime.add(new_state.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = _state, event} =
             SignedOutOfRange.execute(new_state)

    assert %Notify{
             exceeding_value: 4,
             status_flags: %StatusFlags{in_alarm: false},
             deadband: 2,
             exceeded_limit: 7
           } = event
  end

  test "execute on state low_limit and update to normal (with time delay, no time delay normal)" do
    state =
      SignedOutOfRange.new(
        -3,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 1,
          time_delay_normal: nil
        }
      )

    state = %{
      state
      | current_state: :low_limit,
        last_value: -3
    }

    # Value is still on low_limit
    assert {:no_event, ^state} = SignedOutOfRange.execute(state)

    # Value is greater than low_limit and above deadband
    new_state = %{state | monitored_value: 1}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :low_limit} = new_state} =
             SignedOutOfRange.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_normal: DateTime.add(new_state.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = _state, event} =
             SignedOutOfRange.execute(new_state)

    assert %Notify{
             exceeding_value: 1,
             status_flags: %StatusFlags{in_alarm: false},
             deadband: 2,
             exceeded_limit: -2
           } = event
  end

  test "execute on state high_limit and update to low_limit (with time delay, no time delay normal)" do
    state =
      SignedOutOfRange.new(
        8,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 1,
          time_delay_normal: nil
        }
      )

    state = %{
      state
      | current_state: :high_limit,
        last_value: 8
    }

    # Value is still on high_limit
    assert {:no_event, ^state} = SignedOutOfRange.execute(state)

    # Value is less than low_limit
    new_state = %{state | monitored_value: -3}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :high_limit} = new_state} =
             SignedOutOfRange.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_offnormal: DateTime.add(new_state.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :low_limit} = _state, event} =
             SignedOutOfRange.execute(new_state)

    assert %Notify{
             exceeding_value: -3,
             status_flags: %StatusFlags{in_alarm: true},
             deadband: 2,
             exceeded_limit: -2
           } = event
  end

  test "execute on state low_limit and update to high_limit (with time delay, no time delay normal)" do
    state =
      SignedOutOfRange.new(
        -3,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 1,
          time_delay_normal: nil
        }
      )

    state = %{
      state
      | current_state: :low_limit,
        last_value: -3
    }

    # Value is still on low_limit
    assert {:no_event, ^state} = SignedOutOfRange.execute(state)

    # Value is greater than high_limit
    new_state = %{state | monitored_value: 8}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :low_limit} = new_state} =
             SignedOutOfRange.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_offnormal: DateTime.add(new_state.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :high_limit} = _state, event} =
             SignedOutOfRange.execute(new_state)

    assert %Notify{
             exceeding_value: 8,
             status_flags: %StatusFlags{in_alarm: true},
             deadband: 2,
             exceeded_limit: 7
           } = event
  end

  test "execute on state high_limit and update to normal (with time delay and time delay normal)" do
    state =
      SignedOutOfRange.new(
        8,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 1,
          time_delay_normal: 2
        }
      )

    state = %{
      state
      | current_state: :high_limit,
        last_value: 8
    }

    # Value is still on high_limit
    assert {:no_event, ^state} = SignedOutOfRange.execute(state)

    # Value is not greater than high_limit and below deadband
    new_state = %{state | monitored_value: 4}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :high_limit} = new_state} =
             SignedOutOfRange.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_normal: DateTime.add(new_state.dt_normal, -1, :second)}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :high_limit} = new_state} =
             SignedOutOfRange.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_normal: DateTime.add(new_state.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = _state, event} =
             SignedOutOfRange.execute(new_state)

    assert %Notify{
             exceeding_value: 4,
             status_flags: %StatusFlags{in_alarm: false},
             deadband: 2,
             exceeded_limit: 7
           } = event
  end

  test "execute on state low_limit and update to normal (with time delay and time delay normal)" do
    state =
      SignedOutOfRange.new(
        -3,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 1,
          time_delay_normal: 2
        }
      )

    state = %{
      state
      | current_state: :low_limit,
        last_value: -3
    }

    # Value is still on low_limit
    assert {:no_event, ^state} = SignedOutOfRange.execute(state)

    # Value is greater than low_limit and above deadband
    new_state = %{state | monitored_value: 1}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :low_limit} = new_state} =
             SignedOutOfRange.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_normal: DateTime.add(new_state.dt_normal, -1, :second)}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :low_limit} = new_state} =
             SignedOutOfRange.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_normal: DateTime.add(new_state.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = _state, event} =
             SignedOutOfRange.execute(new_state)

    assert %Notify{
             exceeding_value: 1,
             status_flags: %StatusFlags{in_alarm: false},
             deadband: 2,
             exceeded_limit: -2
           } = event
  end

  test "update invalid params" do
    state =
      SignedOutOfRange.new(
        3,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    assert_raise ArgumentError, fn -> SignedOutOfRange.update(state, [:hello]) end
  end

  test "update unknown key" do
    state =
      SignedOutOfRange.new(
        3,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    assert_raise ArgumentError, fn -> SignedOutOfRange.update(state, hello: :there) end
  end

  test "update limit_enable" do
    state =
      SignedOutOfRange.new(
        3,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    new_flags = %LimitEnable{low_limit_enable: true, high_limit_enable: false}

    assert %SignedOutOfRange{limit_enable: ^new_flags} =
             SignedOutOfRange.update(state, limit_enable: new_flags)
  end

  test "update limit_enable invalid value" do
    state =
      SignedOutOfRange.new(
        3,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    assert_raise ArgumentError, fn -> SignedOutOfRange.update(state, limit_enable: nil) end
  end

  test "update monitored_value" do
    state =
      SignedOutOfRange.new(
        3,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    assert %SignedOutOfRange{monitored_value: 6} =
             SignedOutOfRange.update(state, monitored_value: 6)
  end

  test "update monitored_value invalid value" do
    state =
      SignedOutOfRange.new(
        3,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    assert_raise ArgumentError, fn -> SignedOutOfRange.update(state, monitored_value: false) end
  end

  test "update parameters" do
    state =
      SignedOutOfRange.new(
        3,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    new_params = %Params{
      low_limit: 1,
      high_limit: 3,
      deadband: 5,
      time_delay: 15,
      time_delay_normal: 5
    }

    assert %SignedOutOfRange{parameters: ^new_params} =
             SignedOutOfRange.update(state, parameters: new_params)
  end

  test "update parameters invalid value" do
    state =
      SignedOutOfRange.new(
        3,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    assert_raise ArgumentError, fn -> SignedOutOfRange.update(state, parameters: nil) end
  end

  test "update status_flags" do
    state =
      SignedOutOfRange.new(
        3,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    new_flags = %StatusFlags{
      in_alarm: true,
      fault: false,
      out_of_service: true,
      overridden: false
    }

    assert %SignedOutOfRange{status_flags: ^new_flags} =
             SignedOutOfRange.update(state, status_flags: new_flags)
  end

  test "update status_flags invalid value" do
    state =
      SignedOutOfRange.new(
        3,
        %LimitEnable{low_limit_enable: true, high_limit_enable: true},
        %Params{
          low_limit: -2,
          high_limit: 7,
          deadband: 2,
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    assert_raise ArgumentError, fn -> SignedOutOfRange.update(state, status_flags: nil) end
  end
end
