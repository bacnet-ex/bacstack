defmodule BACnet.Protocol.EventAlgorithms.FloatingLimitTest do
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.EventAlgorithms.FloatingLimit
  alias BACnet.Protocol.EventParameters.FloatingLimit, as: Params
  alias BACnet.Protocol.NotificationParameters.FloatingLimit, as: Notify
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :event_algorithms
  @moduletag :protocol_data_structures

  doctest FloatingLimit

  test "assert tag number of event parameters is correct" do
    assert 4 = Params.get_tag_number()
  end

  test "create new state" do
    assert %FloatingLimit{} =
             FloatingLimit.new(3.0, %Params{
               setpoint: %DeviceObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
                 property_identifier: :present_value,
                 property_array_index: nil,
                 device_identifier: nil
               },
               low_diff_limit: 4.0,
               high_diff_limit: 5.0,
               deadband: 2.0,
               time_delay: 0,
               time_delay_normal: nil
             })
  end

  test "create new state fails for invalid monitored_value" do
    assert_raise FunctionClauseError, fn ->
      FloatingLimit.new(0, %Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 0,
        time_delay_normal: nil
      })
    end
  end

  test "create new state fails for invalid params" do
    assert_raise FunctionClauseError, fn ->
      FloatingLimit.new(0.0, %{})
    end
  end

  test "execute on state without setpoint fails" do
    state =
      FloatingLimit.new(3.0, %Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 0,
        time_delay_normal: nil
      })

    assert_raise ArgumentError, fn ->
      FloatingLimit.execute(state)
    end
  end

  test "execute on same state stays normal" do
    state =
      3.0
      |> FloatingLimit.new(%Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 0,
        time_delay_normal: nil
      })
      |> FloatingLimit.update(setpoint: 2.0)

    assert {:no_event, ^state} = FloatingLimit.execute(state)
    assert {:no_event, ^state} = FloatingLimit.execute(state)
    assert {:no_event, ^state} = FloatingLimit.execute(state)
    Process.sleep(1000)
    assert {:no_event, ^state} = FloatingLimit.execute(state)
    assert {:no_event, ^state} = FloatingLimit.execute(state)
    assert {:no_event, ^state} = FloatingLimit.execute(state)
  end

  test "execute on state normal and update to high_limit (no time delay)" do
    state =
      3.0
      |> FloatingLimit.new(%Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 0,
        time_delay_normal: nil
      })
      |> FloatingLimit.update(setpoint: 2.0)

    # Value is not greater than high limit
    assert {:no_event, ^state} = FloatingLimit.execute(state)

    # Value is not greater than high limit
    new_state = %{state | monitored_value: 7.0}

    assert {:no_event, %{current_state: :normal} = _state} = FloatingLimit.execute(new_state)

    # Value is greater than high limit
    new_state2 = %{state | monitored_value: 7.1}

    assert {:event, %{current_state: :high_limit} = new_state2, event} =
             FloatingLimit.execute(new_state2)

    assert {:no_event, %{current_state: :high_limit} = _state} = FloatingLimit.execute(new_state2)

    assert %Notify{
             reference_value: 7.1,
             status_flags: %StatusFlags{in_alarm: true},
             setpoint_value: 2.0,
             error_limit: 5.0
           } = event
  end

  test "execute on state normal and update to low_limit (no time delay)" do
    state =
      3.0
      |> FloatingLimit.new(%Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 0,
        time_delay_normal: nil
      })
      |> FloatingLimit.update(setpoint: 2.0)

    # Value is not less than low limit
    assert {:no_event, ^state} = FloatingLimit.execute(state)

    # Value is not less than low limit
    new_state = %{state | monitored_value: -2.0}

    assert {:no_event, %{current_state: :normal} = _state} = FloatingLimit.execute(new_state)

    # Value is less than low limit
    new_state2 = %{state | monitored_value: -2.1}

    assert {:event, %{current_state: :low_limit} = new_state2, event} =
             FloatingLimit.execute(new_state2)

    assert {:no_event, %{current_state: :low_limit} = _state} = FloatingLimit.execute(new_state2)

    assert %Notify{
             reference_value: -2.1,
             status_flags: %StatusFlags{in_alarm: true},
             setpoint_value: 2.0,
             error_limit: 4.0
           } = event
  end

  test "execute on state high_limit and update to normal (no time delay)" do
    state =
      7.1
      |> FloatingLimit.new(%Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 0,
        time_delay_normal: nil
      })
      |> FloatingLimit.update(setpoint: 2.0)

    state = %{
      state
      | current_state: :high_limit,
        last_value: 7.1
    }

    # Value is still on high_limit
    assert {:no_event, ^state} = FloatingLimit.execute(state)

    # Value is not greater than high_limit, but still not below deadband
    new_state = %{state | monitored_value: 5.0}

    assert {:no_event, ^new_state} = FloatingLimit.execute(new_state)

    # Value is not greater than high_limit and below deadband
    new_state2 = %{state | monitored_value: 4.9}

    assert {:event, %{current_state: :normal} = _state, event} = FloatingLimit.execute(new_state2)

    assert %Notify{
             reference_value: 4.9,
             status_flags: %StatusFlags{in_alarm: false},
             setpoint_value: 2.0,
             error_limit: 5.0
           } = event
  end

  test "execute on state low_limit and update to normal (no time delay)" do
    state =
      -2.1
      |> FloatingLimit.new(%Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 0,
        time_delay_normal: nil
      })
      |> FloatingLimit.update(setpoint: 2.0)

    state = %{
      state
      | current_state: :low_limit,
        last_value: -2.1
    }

    # Value is still on low_limit
    assert {:no_event, ^state} = FloatingLimit.execute(state)

    # Value is greater than low_limit, but still not above deadband
    new_state = %{state | monitored_value: +0.0}

    assert {:no_event, ^new_state} = FloatingLimit.execute(new_state)

    # Value is greater than low_limit and above deadband
    new_state2 = %{state | monitored_value: 0.1}

    assert {:event, %{current_state: :normal} = _state, event} = FloatingLimit.execute(new_state2)

    assert %Notify{
             reference_value: 0.1,
             status_flags: %StatusFlags{in_alarm: false},
             setpoint_value: 2.0,
             error_limit: 4.0
           } = event
  end

  test "execute on state high_limit and update to low_limit (no time delay)" do
    state =
      7.1
      |> FloatingLimit.new(%Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 0,
        time_delay_normal: nil
      })
      |> FloatingLimit.update(setpoint: 2.0)

    state = %{
      state
      | current_state: :high_limit,
        last_value: 7.1
    }

    # Value is still on high_limit
    assert {:no_event, ^state} = FloatingLimit.execute(state)

    # Value is less than low_limit
    new_state = %{state | monitored_value: -2.1}

    assert {:event, %{current_state: :low_limit} = _state, event} =
             FloatingLimit.execute(new_state)

    assert %Notify{
             reference_value: -2.1,
             status_flags: %StatusFlags{in_alarm: true},
             setpoint_value: 2.0,
             error_limit: 4.0
           } = event
  end

  test "execute on state low_limit and update to high_limit (no time delay)" do
    state =
      -2.1
      |> FloatingLimit.new(%Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 0,
        time_delay_normal: nil
      })
      |> FloatingLimit.update(setpoint: 2.0)

    state = %{
      state
      | current_state: :low_limit,
        last_value: -2.1
    }

    # Value is still on low_limit
    assert {:no_event, ^state} = FloatingLimit.execute(state)

    # Value is greater than high_limit
    new_state2 = %{state | monitored_value: 7.1}

    assert {:event, %{current_state: :high_limit} = _state, event} =
             FloatingLimit.execute(new_state2)

    assert %Notify{
             reference_value: 7.1,
             status_flags: %StatusFlags{in_alarm: true},
             setpoint_value: 2.0,
             error_limit: 5.0
           } = event
  end

  test "execute on state normal and update to high_limit (with time delay, no time delay normal)" do
    state =
      3.0
      |> FloatingLimit.new(%Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 1,
        time_delay_normal: nil
      })
      |> FloatingLimit.update(setpoint: 2.0)

    # Value is not greater than high limit
    assert {:no_event, ^state} = FloatingLimit.execute(state)

    # Value is greater than high limit
    new_state = %{state | monitored_value: 7.1}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state} =
             FloatingLimit.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_offnormal: DateTime.add(new_state.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :high_limit} = new_state, event} =
             FloatingLimit.execute(new_state)

    assert {:no_event, %{current_state: :high_limit} = _state} = FloatingLimit.execute(new_state)

    assert %Notify{
             reference_value: 7.1,
             status_flags: %StatusFlags{in_alarm: true},
             setpoint_value: 2.0,
             error_limit: 5.0
           } = event
  end

  test "execute on state normal and update to low_limit (with time delay, no time delay normal)" do
    state =
      3.0
      |> FloatingLimit.new(%Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 1,
        time_delay_normal: nil
      })
      |> FloatingLimit.update(setpoint: 2.0)

    # Value is not less than low limit
    assert {:no_event, ^state} = FloatingLimit.execute(state)

    # Value is less than low limit
    new_state = %{state | monitored_value: -2.1}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state} =
             FloatingLimit.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_offnormal: DateTime.add(new_state.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :low_limit} = new_state, event} =
             FloatingLimit.execute(new_state)

    assert {:no_event, %{current_state: :low_limit} = _state} = FloatingLimit.execute(new_state)

    assert %Notify{
             reference_value: -2.1,
             status_flags: %StatusFlags{in_alarm: true},
             setpoint_value: 2.0,
             error_limit: 4.0
           } = event
  end

  test "execute on state high_limit and update to normal (with time delay, no time delay normal)" do
    state =
      7.1
      |> FloatingLimit.new(%Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 1,
        time_delay_normal: nil
      })
      |> FloatingLimit.update(setpoint: 2.0)

    state = %{
      state
      | current_state: :high_limit,
        last_value: 7.1
    }

    # Value is still on high_limit
    assert {:no_event, ^state} = FloatingLimit.execute(state)

    # Value is not greater than high_limit and below deadband
    new_state = %{state | monitored_value: 4.9}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :high_limit} = new_state} =
             FloatingLimit.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_normal: DateTime.add(new_state.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = _state, event} = FloatingLimit.execute(new_state)

    assert %Notify{
             reference_value: 4.9,
             status_flags: %StatusFlags{in_alarm: false},
             setpoint_value: 2.0,
             error_limit: 5.0
           } = event
  end

  test "execute on state low_limit and update to normal (with time delay, no time delay normal)" do
    state =
      -2.1
      |> FloatingLimit.new(%Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 1,
        time_delay_normal: nil
      })
      |> FloatingLimit.update(setpoint: 2.0)

    state = %{
      state
      | current_state: :low_limit,
        last_value: -2.1
    }

    # Value is still on low_limit
    assert {:no_event, ^state} = FloatingLimit.execute(state)

    # Value is greater than low_limit and above deadband
    new_state = %{state | monitored_value: 0.1}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :low_limit} = new_state} =
             FloatingLimit.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_normal: DateTime.add(new_state.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = _state, event} = FloatingLimit.execute(new_state)

    assert %Notify{
             reference_value: 0.1,
             status_flags: %StatusFlags{in_alarm: false},
             setpoint_value: 2.0,
             error_limit: 4.0
           } = event
  end

  test "execute on state high_limit and update to low_limit (with time delay, no time delay normal)" do
    state =
      7.1
      |> FloatingLimit.new(%Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 1,
        time_delay_normal: nil
      })
      |> FloatingLimit.update(setpoint: 2.0)

    state = %{
      state
      | current_state: :high_limit,
        last_value: 7.1
    }

    # Value is still on high_limit
    assert {:no_event, ^state} = FloatingLimit.execute(state)

    # Value is less than low_limit
    new_state = %{state | monitored_value: -2.1}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :high_limit} = new_state} =
             FloatingLimit.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_offnormal: DateTime.add(new_state.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :low_limit} = _state, event} =
             FloatingLimit.execute(new_state)

    assert %Notify{
             reference_value: -2.1,
             status_flags: %StatusFlags{in_alarm: true},
             setpoint_value: 2.0,
             error_limit: 4.0
           } = event
  end

  test "execute on state low_limit and update to high_limit (with time delay, no time delay normal)" do
    state =
      -2.1
      |> FloatingLimit.new(%Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 1,
        time_delay_normal: nil
      })
      |> FloatingLimit.update(setpoint: 2.0)

    state = %{
      state
      | current_state: :low_limit,
        last_value: -2.1
    }

    # Value is still on low_limit
    assert {:no_event, ^state} = FloatingLimit.execute(state)

    # Value is greater than high_limit
    new_state = %{state | monitored_value: 7.1}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :low_limit} = new_state} =
             FloatingLimit.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_offnormal: DateTime.add(new_state.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :high_limit} = _state, event} =
             FloatingLimit.execute(new_state)

    assert %Notify{
             reference_value: 7.1,
             status_flags: %StatusFlags{in_alarm: true},
             setpoint_value: 2.0,
             error_limit: 5.0
           } = event
  end

  test "execute on state high_limit and update to normal (with time delay and time delay normal)" do
    state =
      7.1
      |> FloatingLimit.new(%Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 1,
        time_delay_normal: 2
      })
      |> FloatingLimit.update(setpoint: 2.0)

    state = %{
      state
      | current_state: :high_limit,
        last_value: 7.1
    }

    # Value is still on high_limit
    assert {:no_event, ^state} = FloatingLimit.execute(state)

    # Value is not greater than high_limit and below deadband
    new_state = %{state | monitored_value: 4.9}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :high_limit} = new_state} =
             FloatingLimit.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_normal: DateTime.add(new_state.dt_normal, -1, :second)}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :high_limit} = new_state} =
             FloatingLimit.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_normal: DateTime.add(new_state.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = _state, event} = FloatingLimit.execute(new_state)

    assert %Notify{
             reference_value: 4.9,
             status_flags: %StatusFlags{in_alarm: false},
             setpoint_value: 2.0,
             error_limit: 5.0
           } = event
  end

  test "execute on state low_limit and update to normal (with time delay and time delay normal)" do
    state =
      -2.1
      |> FloatingLimit.new(%Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 1,
        time_delay_normal: 2
      })
      |> FloatingLimit.update(setpoint: 2.0)

    state = %{
      state
      | current_state: :low_limit,
        last_value: -2.1
    }

    # Value is still on low_limit
    assert {:no_event, ^state} = FloatingLimit.execute(state)

    # Value is greater than low_limit and above deadband
    new_state = %{state | monitored_value: 0.1}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :low_limit} = new_state} =
             FloatingLimit.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_normal: DateTime.add(new_state.dt_normal, -1, :second)}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :low_limit} = new_state} =
             FloatingLimit.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_normal: DateTime.add(new_state.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = _state, event} = FloatingLimit.execute(new_state)

    assert %Notify{
             reference_value: 0.1,
             status_flags: %StatusFlags{in_alarm: false},
             setpoint_value: 2.0,
             error_limit: 4.0
           } = event
  end

  test "update invalid params" do
    state =
      FloatingLimit.new(3.0, %Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 0,
        time_delay_normal: nil
      })

    assert_raise ArgumentError, fn -> FloatingLimit.update(state, [:hello]) end
  end

  test "update unknown key" do
    state =
      FloatingLimit.new(3.0, %Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 0,
        time_delay_normal: nil
      })

    assert_raise ArgumentError, fn -> FloatingLimit.update(state, hello: :there) end
  end

  test "update monitored_value" do
    state =
      FloatingLimit.new(3.0, %Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 0,
        time_delay_normal: nil
      })

    assert %FloatingLimit{monitored_value: 6.9} =
             FloatingLimit.update(state, monitored_value: 6.9)
  end

  test "update monitored_value invalid value" do
    state =
      FloatingLimit.new(3.0, %Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 0,
        time_delay_normal: nil
      })

    assert_raise ArgumentError, fn -> FloatingLimit.update(state, monitored_value: false) end
  end

  test "update setpoint" do
    state =
      FloatingLimit.new(3.0, %Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 0,
        time_delay_normal: nil
      })

    assert %FloatingLimit{setpoint: 6.9} = FloatingLimit.update(state, setpoint: 6.9)
  end

  test "update setpoint invalid value" do
    state =
      FloatingLimit.new(3.0, %Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 0,
        time_delay_normal: nil
      })

    assert_raise ArgumentError, fn -> FloatingLimit.update(state, setpoint: false) end
  end

  test "update parameters" do
    state =
      FloatingLimit.new(3.0, %Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 0,
        time_delay_normal: nil
      })

    new_params = %Params{
      setpoint: %DeviceObjectPropertyRef{
        object_identifier: %ObjectIdentifier{type: :analog_value, instance: 5},
        property_identifier: :fault_limit,
        property_array_index: nil,
        device_identifier: nil
      },
      low_diff_limit: 1.0,
      high_diff_limit: 1.0,
      deadband: 6.0,
      time_delay: 5,
      time_delay_normal: nil
    }

    assert %FloatingLimit{parameters: ^new_params} =
             FloatingLimit.update(state, parameters: new_params)
  end

  test "update parameters invalid value" do
    state =
      FloatingLimit.new(3.0, %Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 0,
        time_delay_normal: nil
      })

    assert_raise ArgumentError, fn -> FloatingLimit.update(state, parameters: nil) end
  end

  test "update status_flags" do
    state =
      FloatingLimit.new(3.0, %Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 0,
        time_delay_normal: nil
      })

    new_flags = %StatusFlags{
      in_alarm: true,
      fault: false,
      out_of_service: true,
      overridden: false
    }

    assert %FloatingLimit{status_flags: ^new_flags} =
             FloatingLimit.update(state, status_flags: new_flags)
  end

  test "update status_flags invalid value" do
    state =
      FloatingLimit.new(3.0, %Params{
        setpoint: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :analog_value, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        low_diff_limit: 4.0,
        high_diff_limit: 5.0,
        deadband: 2.0,
        time_delay: 0,
        time_delay_normal: nil
      })

    assert_raise ArgumentError, fn -> FloatingLimit.update(state, status_flags: nil) end
  end
end
