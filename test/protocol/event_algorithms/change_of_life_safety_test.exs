defmodule BACnet.Protocol.EventAlgorithms.ChangeOfLifeSafetyTest do
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.EventAlgorithms.ChangeOfLifeSafety
  alias BACnet.Protocol.EventParameters.ChangeOfLifeSafety, as: Params
  alias BACnet.Protocol.NotificationParameters.ChangeOfLifeSafety, as: Notify
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :event_algorithms
  @moduletag :protocol_data_structures

  doctest ChangeOfLifeSafety

  test "assert tag number of event parameters is correct" do
    assert 8 = Params.get_tag_number()
  end

  test "create new state" do
    assert %ChangeOfLifeSafety{} =
             ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
               mode: %DeviceObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
                 property_identifier: :present_value,
                 property_array_index: nil,
                 device_identifier: nil
               },
               alarm_values: [:alarm, :holdup],
               life_safety_alarm_values: [:fault, :local_alarm],
               time_delay: 0,
               time_delay_normal: 0
             })
  end

  test "create new state fails for invalid monitored_value" do
    assert_raise ArgumentError, fn ->
      ChangeOfLifeSafety.new(0, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })
    end
  end

  test "create new state fails for invalid mode" do
    assert_raise ArgumentError, fn ->
      ChangeOfLifeSafety.new(:quiet, 0, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })
    end
  end

  test "create new state fails for invalid operation_expected" do
    assert_raise ArgumentError, fn ->
      ChangeOfLifeSafety.new(:quiet, :off, 0, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })
    end
  end

  test "create new state fails for invalid params" do
    assert_raise FunctionClauseError, fn ->
      ChangeOfLifeSafety.new(:quiet, :off, :none, %{})
    end
  end

  test "execute on same state stays normal" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)
    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)
    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)
    Process.sleep(1000)
    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)
    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)
    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)
  end

  test "execute on state normal and update to normal on mode change" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)

    # Mode change
    new_state2 = %{state | mode: :enabled}

    assert {:event, %{current_state: :normal} = new_state2, event} =
             ChangeOfLifeSafety.execute(new_state2)

    assert {:no_event, %{current_state: :normal} = _state} =
             ChangeOfLifeSafety.execute(new_state2)

    assert %Notify{
             new_state: :quiet,
             new_mode: :enabled,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: false}
           } =
             event
  end

  test "execute on state offnormal and update to offnormal on mode change" do
    state =
      ChangeOfLifeSafety.new(:alarm, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    state = %{state | current_state: :offnormal, last_value: :alarm}

    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)

    # Mode change
    new_state2 = %{state | mode: :enabled}

    assert {:event, %{current_state: :offnormal} = new_state2, event} =
             ChangeOfLifeSafety.execute(new_state2)

    assert {:no_event, %{current_state: :offnormal} = _state} =
             ChangeOfLifeSafety.execute(new_state2)

    assert %Notify{
             new_state: :alarm,
             new_mode: :enabled,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: true}
           } =
             event
  end

  test "execute on state life safety alarm and update to life safety alarm on mode change" do
    state =
      ChangeOfLifeSafety.new(:fault, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    state = %{state | current_state: :life_safety_alarm, last_value: :fault}

    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)

    # Mode change
    new_state2 = %{state | mode: :enabled}

    assert {:event, %{current_state: :life_safety_alarm} = new_state2, event} =
             ChangeOfLifeSafety.execute(new_state2)

    assert {:no_event, %{current_state: :life_safety_alarm} = _state} =
             ChangeOfLifeSafety.execute(new_state2)

    assert %Notify{
             new_state: :fault,
             new_mode: :enabled,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: true}
           } =
             event
  end

  test "execute on state normal and update to offnormal (no time delay)" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    # Value does not match alarm value
    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)

    # Value does not match alarm value
    new_state = %{state | monitored_value: :pre_alarm}

    assert {:no_event, %{current_state: :normal} = _state} = ChangeOfLifeSafety.execute(new_state)

    # Value matches alarm value
    new_state2 = %{state | monitored_value: :alarm}

    assert {:event, %{current_state: :offnormal} = new_state2, event} =
             ChangeOfLifeSafety.execute(new_state2)

    assert {:no_event, %{current_state: :offnormal} = _state} =
             ChangeOfLifeSafety.execute(new_state2)

    assert %Notify{
             new_state: :alarm,
             new_mode: :off,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: true}
           } =
             event
  end

  test "execute on state normal and update to offnormal (no time delay), try with second value in alarm values" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    # Value does not match alarm value
    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)

    # Value does not match alarm value
    new_state = %{state | monitored_value: :pre_alarm}

    assert {:no_event, %{current_state: :normal} = _state} = ChangeOfLifeSafety.execute(new_state)

    # Value matches alarm value
    new_state2 = %{state | monitored_value: :holdup}

    assert {:event, %{current_state: :offnormal} = new_state2, event} =
             ChangeOfLifeSafety.execute(new_state2)

    assert {:no_event, %{current_state: :offnormal} = _state} =
             ChangeOfLifeSafety.execute(new_state2)

    assert %Notify{
             new_state: :holdup,
             new_mode: :off,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: true}
           } =
             event
  end

  test "execute on state normal and update to life safety alarm (no time delay)" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    # Value does not match life safety alarm value
    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)

    # Value does not match life safety alarm value
    new_state = %{state | monitored_value: :pre_alarm}

    assert {:no_event, %{current_state: :normal} = _state} = ChangeOfLifeSafety.execute(new_state)

    # Value matches life safety alarm value
    new_state2 = %{state | monitored_value: :fault}

    assert {:event, %{current_state: :life_safety_alarm} = new_state2, event} =
             ChangeOfLifeSafety.execute(new_state2)

    assert {:no_event, %{current_state: :life_safety_alarm} = _state} =
             ChangeOfLifeSafety.execute(new_state2)

    assert %Notify{
             new_state: :fault,
             new_mode: :off,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: true}
           } =
             event
  end

  test "execute on state normal and update to life safety alarm (no time delay), try with second value in alarm values" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    # Value does not match life safety alarm value
    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)

    # Value does not match life safety alarm value
    new_state = %{state | monitored_value: :pre_alarm}

    assert {:no_event, %{current_state: :normal} = _state} = ChangeOfLifeSafety.execute(new_state)

    # Value matches life safety alarm value
    new_state2 = %{state | monitored_value: :local_alarm}

    assert {:event, %{current_state: :life_safety_alarm} = new_state2, event} =
             ChangeOfLifeSafety.execute(new_state2)

    assert {:no_event, %{current_state: :life_safety_alarm} = _state} =
             ChangeOfLifeSafety.execute(new_state2)

    assert %Notify{
             new_state: :local_alarm,
             new_mode: :off,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: true}
           } =
             event
  end

  test "execute on state offnormal and update to normal (no time delay)" do
    state =
      ChangeOfLifeSafety.new(:alarm, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    state = %{state | current_state: :offnormal, last_value: :alarm}

    # Value does match alarm value
    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)

    # Value does not match alarm value
    new_state = %{state | monitored_value: :quiet}

    assert {:event, %{current_state: :normal} = _state, event} =
             ChangeOfLifeSafety.execute(new_state)

    assert %Notify{
             new_state: :quiet,
             new_mode: :off,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: false}
           } =
             event
  end

  test "execute on state life safety alarm and update to normal (no time delay)" do
    state =
      ChangeOfLifeSafety.new(:fault, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    state = %{state | current_state: :life_safety_alarm, last_value: :fault}

    # Value does match life safety alarm value 1
    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)

    # Value does match life safety alarm value 2
    new_state = %{state | monitored_value: :quiet}

    assert {:event, %{current_state: :normal} = _state, event} =
             ChangeOfLifeSafety.execute(new_state)

    assert %Notify{
             new_state: :quiet,
             new_mode: :off,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: false}
           } =
             event
  end

  test "execute on state offnormal and new event on different alarm value (no time delay)" do
    state =
      ChangeOfLifeSafety.new(:alarm, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    state = %{state | current_state: :offnormal, last_value: :alarm}

    # Value does match alarm value 1
    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)

    # Value does match alarm value 2
    new_state = %{state | monitored_value: :holdup}

    assert {:event, %{current_state: :offnormal} = _state, event} =
             ChangeOfLifeSafety.execute(new_state)

    assert %Notify{
             new_state: :holdup,
             new_mode: :off,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: true}
           } =
             event
  end

  test "execute on state offnormal and update to life safety alarm (no time delay)" do
    state =
      ChangeOfLifeSafety.new(:alarm, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    state = %{state | current_state: :offnormal, last_value: :alarm}

    # Value does match alarm value 1
    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)

    # Value does not match alarm value but matches life safety alarm value
    new_state = %{state | monitored_value: :fault}

    assert {:event, %{current_state: :life_safety_alarm} = _state, event} =
             ChangeOfLifeSafety.execute(new_state)

    assert %Notify{
             new_state: :fault,
             new_mode: :off,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: true}
           } =
             event
  end

  test "execute on state life safety alarm and new event on different life safety alarm value (no time delay)" do
    state =
      ChangeOfLifeSafety.new(:fault, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    state = %{state | current_state: :life_safety_alarm, last_value: :fault}

    # Value does not match alarm value
    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)

    # Value does not match alarm value
    new_state = %{state | monitored_value: :local_alarm}

    assert {:event, %{current_state: :life_safety_alarm} = _state, event} =
             ChangeOfLifeSafety.execute(new_state)

    assert %Notify{
             new_state: :local_alarm,
             new_mode: :off,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: true}
           } =
             event
  end

  test "execute on state life safety alarm and update to offnormal (no time delay)" do
    state =
      ChangeOfLifeSafety.new(:fault, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    state = %{state | current_state: :life_safety_alarm, last_value: :fault}

    # Value does match life safety alarm value
    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)

    # Value does match alarm value
    new_state = %{state | monitored_value: :alarm}

    assert {:event, %{current_state: :offnormal} = _state, event} =
             ChangeOfLifeSafety.execute(new_state)

    assert %Notify{
             new_state: :alarm,
             new_mode: :off,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: true}
           } =
             event
  end

  test "execute on state normal and update to offnormal and back to normal (with time delay, no time delay normal)" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 1,
        time_delay_normal: nil
      })

    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)

    # Value does not match alarm value
    new_state = %{state | monitored_value: :supervisory}

    assert {:no_event, _state} = ChangeOfLifeSafety.execute(new_state)

    # Value matches alarm value
    new_state2 = %{state | monitored_value: :alarm}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfLifeSafety.execute(new_state2)

    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfLifeSafety.execute(new_state2)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state2 = %{new_state2 | dt_offnormal: DateTime.add(new_state2.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :offnormal} = new_state2, event} =
             ChangeOfLifeSafety.execute(new_state2)

    assert {:no_event, _state} = ChangeOfLifeSafety.execute(new_state2)

    assert %Notify{
             new_state: :alarm,
             new_mode: :off,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: true}
           } =
             event

    # Now change back to normal after time_delay
    new_state3 = %{new_state2 | monitored_value: :supervisory}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfLifeSafety.execute(new_state3)

    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfLifeSafety.execute(new_state3)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state3 = %{new_state3 | dt_normal: DateTime.add(new_state3.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = new_state3, event2} =
             ChangeOfLifeSafety.execute(new_state3)

    assert {:no_event, _state} = ChangeOfLifeSafety.execute(new_state3)

    assert %Notify{
             new_state: :supervisory,
             new_mode: :off,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: false}
           } =
             event2
  end

  test "execute on state normal and update to offnormal and back to normal (with time delay and time delay normal)" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 1,
        time_delay_normal: 2
      })

    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)

    # Value does not match alarm value
    new_state = %{state | monitored_value: :supervisory}

    assert {:no_event, _state} = ChangeOfLifeSafety.execute(new_state)

    # Value matches alarm value
    new_state2 = %{state | monitored_value: :alarm}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfLifeSafety.execute(new_state2)

    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfLifeSafety.execute(new_state2)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state2 = %{new_state2 | dt_offnormal: DateTime.add(new_state2.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :offnormal} = new_state2, event} =
             ChangeOfLifeSafety.execute(new_state2)

    assert {:no_event, _state} = ChangeOfLifeSafety.execute(new_state2)

    assert %Notify{
             new_state: :alarm,
             new_mode: :off,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: true}
           } =
             event

    # Now change back to normal after time_delay
    new_state3 = %{new_state2 | monitored_value: :supervisory}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfLifeSafety.execute(new_state3)

    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfLifeSafety.execute(new_state3)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state3 = %{new_state3 | dt_normal: DateTime.add(new_state3.dt_normal, -1, :second)}

    # No event yet, two seconds need to pass
    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfLifeSafety.execute(new_state3)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state3 = %{new_state3 | dt_normal: DateTime.add(new_state3.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = new_state3, event2} =
             ChangeOfLifeSafety.execute(new_state3)

    assert {:no_event, _state} = ChangeOfLifeSafety.execute(new_state3)

    assert %Notify{
             new_state: :supervisory,
             new_mode: :off,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: false}
           } =
             event2
  end

  test "execute on state offnormal and new event on different alarm value (with time delay)" do
    state =
      ChangeOfLifeSafety.new(:alarm, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 1,
        time_delay_normal: 2
      })

    state = %{state | current_state: :offnormal, last_value: :alarm}

    # Value does not match first alarm value, but second alarm value
    new_state = %{state | monitored_value: :holdup}

    assert {:delayed_event, %{current_state: :offnormal} = new_state} =
             ChangeOfLifeSafety.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_offnormal: DateTime.add(new_state.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :offnormal} = _state, event} =
             ChangeOfLifeSafety.execute(new_state)

    assert %Notify{
             new_state: :holdup,
             new_mode: :off,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: true}
           } =
             event
  end

  test "execute on state offnormal and update to life safety alarm (with time delay)" do
    state =
      ChangeOfLifeSafety.new(:alarm, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 1,
        time_delay_normal: 2
      })

    state = %{state | current_state: :offnormal, last_value: :alarm}

    # Value does match life safety alarm
    new_state = %{state | monitored_value: :fault}

    assert {:delayed_event, %{current_state: :offnormal} = new_state} =
             ChangeOfLifeSafety.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_life_alarm: DateTime.add(new_state.dt_life_alarm, -1, :second)}

    assert {:event, %{current_state: :life_safety_alarm} = _state, event} =
             ChangeOfLifeSafety.execute(new_state)

    assert %Notify{
             new_state: :fault,
             new_mode: :off,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: true}
           } =
             event
  end

  test "execute on state normal and update to offnormal immediately on mode change (with time delay)" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 1,
        time_delay_normal: nil
      })

    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)

    # Value does not match alarm value
    new_state = %{state | monitored_value: :supervisory}

    assert {:no_event, _state} = ChangeOfLifeSafety.execute(new_state)

    # Value matches alarm value
    new_state2 = %{state | monitored_value: :alarm}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfLifeSafety.execute(new_state2)

    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfLifeSafety.execute(new_state2)

    # Update mode
    new_state3 = %{new_state2 | mode: :enabled}

    assert {:event, %{current_state: :offnormal} = new_state3, event} =
             ChangeOfLifeSafety.execute(new_state3)

    assert {:no_event, _state} = ChangeOfLifeSafety.execute(new_state3)

    assert %Notify{
             new_state: :alarm,
             new_mode: :enabled,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: true}
           } =
             event
  end

  test "execute on state offnormal and update to normal immediately on mode change (with time delay)" do
    state =
      ChangeOfLifeSafety.new(:alarm, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 1,
        time_delay_normal: nil
      })

    state = %{state | current_state: :offnormal, last_value: :alarm}

    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)

    # Value does not match alarm value
    new_state = %{state | monitored_value: :quiet}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :offnormal} = new_state} =
             ChangeOfLifeSafety.execute(new_state)

    assert {:delayed_event, %{current_state: :offnormal} = new_state} =
             ChangeOfLifeSafety.execute(new_state)

    # Update mode
    new_state2 = %{new_state | mode: :enabled}

    assert {:event, %{current_state: :normal} = new_state2, event} =
             ChangeOfLifeSafety.execute(new_state2)

    assert {:no_event, _state} = ChangeOfLifeSafety.execute(new_state2)

    assert %Notify{
             new_state: :quiet,
             new_mode: :enabled,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: false}
           } =
             event
  end

  test "execute on state offnormal and update to life safety alarm immediately on mode change (with time delay)" do
    state =
      ChangeOfLifeSafety.new(:alarm, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 1,
        time_delay_normal: nil
      })

    state = %{state | current_state: :offnormal, last_value: :alarm}

    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)

    # Value does not match alarm value
    new_state = %{state | monitored_value: :fault}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :offnormal} = new_state} =
             ChangeOfLifeSafety.execute(new_state)

    assert {:delayed_event, %{current_state: :offnormal} = new_state} =
             ChangeOfLifeSafety.execute(new_state)

    # Update mode
    new_state2 = %{new_state | mode: :enabled}

    assert {:event, %{current_state: :life_safety_alarm} = new_state2, event} =
             ChangeOfLifeSafety.execute(new_state2)

    assert {:no_event, _state} = ChangeOfLifeSafety.execute(new_state2)

    assert %Notify{
             new_state: :fault,
             new_mode: :enabled,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: true}
           } =
             event
  end

  test "execute on state normal and update to life safety alarm and back to normal (with time delay, no time delay normal)" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 1,
        time_delay_normal: nil
      })

    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)

    # Value does not match life safety alarm value
    new_state = %{state | monitored_value: :supervisory}

    assert {:no_event, _state} = ChangeOfLifeSafety.execute(new_state)

    # Value matches life safety alarm value
    new_state2 = %{state | monitored_value: :fault}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfLifeSafety.execute(new_state2)

    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfLifeSafety.execute(new_state2)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state2 = %{
      new_state2
      | dt_life_alarm: DateTime.add(new_state2.dt_life_alarm, -1, :second)
    }

    assert {:event, %{current_state: :life_safety_alarm} = new_state2, event} =
             ChangeOfLifeSafety.execute(new_state2)

    assert {:no_event, _state} = ChangeOfLifeSafety.execute(new_state2)

    assert %Notify{
             new_state: :fault,
             new_mode: :off,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: true}
           } =
             event

    # Now change back to normal after time_delay
    new_state3 = %{new_state2 | monitored_value: :supervisory}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :life_safety_alarm} = new_state3} =
             ChangeOfLifeSafety.execute(new_state3)

    assert {:delayed_event, %{current_state: :life_safety_alarm} = new_state3} =
             ChangeOfLifeSafety.execute(new_state3)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state3 = %{new_state3 | dt_normal: DateTime.add(new_state3.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = new_state3, event2} =
             ChangeOfLifeSafety.execute(new_state3)

    assert {:no_event, _state} = ChangeOfLifeSafety.execute(new_state3)

    assert %Notify{
             new_state: :supervisory,
             new_mode: :off,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: false}
           } =
             event2
  end

  test "execute on state normal and update to life safety alarm and back to normal (with time delay and time delay normal)" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 1,
        time_delay_normal: 2
      })

    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)

    # Value does not match life safety alarm value
    new_state = %{state | monitored_value: :supervisory}

    assert {:no_event, _state} = ChangeOfLifeSafety.execute(new_state)

    # Value matches life safety alarm value
    new_state2 = %{state | monitored_value: :fault}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfLifeSafety.execute(new_state2)

    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfLifeSafety.execute(new_state2)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state2 = %{
      new_state2
      | dt_life_alarm: DateTime.add(new_state2.dt_life_alarm, -1, :second)
    }

    assert {:event, %{current_state: :life_safety_alarm} = new_state2, event} =
             ChangeOfLifeSafety.execute(new_state2)

    assert {:no_event, _state} = ChangeOfLifeSafety.execute(new_state2)

    assert %Notify{
             new_state: :fault,
             new_mode: :off,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: true}
           } =
             event

    # Now change back to normal after time_delay
    new_state3 = %{new_state2 | monitored_value: :supervisory}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :life_safety_alarm} = new_state3} =
             ChangeOfLifeSafety.execute(new_state3)

    assert {:delayed_event, %{current_state: :life_safety_alarm} = new_state3} =
             ChangeOfLifeSafety.execute(new_state3)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state3 = %{new_state3 | dt_normal: DateTime.add(new_state3.dt_normal, -1, :second)}

    # No event yet, two seconds need to pass
    assert {:delayed_event, %{current_state: :life_safety_alarm} = new_state3} =
             ChangeOfLifeSafety.execute(new_state3)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state3 = %{new_state3 | dt_normal: DateTime.add(new_state3.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = new_state3, event2} =
             ChangeOfLifeSafety.execute(new_state3)

    assert {:no_event, _state} = ChangeOfLifeSafety.execute(new_state3)

    assert %Notify{
             new_state: :supervisory,
             new_mode: :off,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: false}
           } =
             event2
  end

  test "execute on state life safety alarm and new event on different life safety alarm value (with time delay)" do
    state =
      ChangeOfLifeSafety.new(:alarm, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 1,
        time_delay_normal: 2
      })

    state = %{state | current_state: :life_safety_alarm, last_value: :alarm}

    # Value does not match first alarm value, but second alarm value
    new_state = %{state | monitored_value: :local_alarm}

    assert {:delayed_event, %{current_state: :life_safety_alarm} = new_state} =
             ChangeOfLifeSafety.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_life_alarm: DateTime.add(new_state.dt_life_alarm, -1, :second)}

    assert {:event, %{current_state: :life_safety_alarm} = _state, event} =
             ChangeOfLifeSafety.execute(new_state)

    assert %Notify{
             new_state: :local_alarm,
             new_mode: :off,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: true}
           } =
             event
  end

  test "execute on state life safety alarm and update to offnormal (with time delay)" do
    state =
      ChangeOfLifeSafety.new(:fault, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 1,
        time_delay_normal: 2
      })

    state = %{state | current_state: :life_safety_alarm, last_value: :fault}

    # Value does match alarm
    new_state = %{state | monitored_value: :alarm}

    assert {:delayed_event, %{current_state: :life_safety_alarm} = new_state} =
             ChangeOfLifeSafety.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_offnormal: DateTime.add(new_state.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :offnormal} = _state, event} =
             ChangeOfLifeSafety.execute(new_state)

    assert %Notify{
             new_state: :alarm,
             new_mode: :off,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: true}
           } =
             event
  end

  test "execute on state normal and update to life safety alarm immediately on mode change (with time delay)" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 1,
        time_delay_normal: nil
      })

    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)

    # Value does not match life safety alarm value
    new_state = %{state | monitored_value: :supervisory}

    assert {:no_event, _state} = ChangeOfLifeSafety.execute(new_state)

    # Value matches life safety alarm value
    new_state2 = %{state | monitored_value: :fault}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfLifeSafety.execute(new_state2)

    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfLifeSafety.execute(new_state2)

    # Update mode
    new_state3 = %{new_state2 | mode: :enabled}

    assert {:event, %{current_state: :life_safety_alarm} = new_state3, event} =
             ChangeOfLifeSafety.execute(new_state3)

    assert {:no_event, _state} = ChangeOfLifeSafety.execute(new_state3)

    assert %Notify{
             new_state: :fault,
             new_mode: :enabled,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: true}
           } =
             event
  end

  test "execute on state life safety alarm and update to normal immediately on mode change (with time delay)" do
    state =
      ChangeOfLifeSafety.new(:fault, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 1,
        time_delay_normal: nil
      })

    state = %{state | current_state: :life_safety_alarm, last_value: :fault}

    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)

    # Value does not match life safety alarm value
    new_state = %{state | monitored_value: :quiet}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :life_safety_alarm} = new_state} =
             ChangeOfLifeSafety.execute(new_state)

    assert {:delayed_event, %{current_state: :life_safety_alarm} = new_state} =
             ChangeOfLifeSafety.execute(new_state)

    # Update mode
    new_state2 = %{new_state | mode: :enabled}

    assert {:event, %{current_state: :normal} = new_state2, event} =
             ChangeOfLifeSafety.execute(new_state2)

    assert {:no_event, _state} = ChangeOfLifeSafety.execute(new_state2)

    assert %Notify{
             new_state: :quiet,
             new_mode: :enabled,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: false}
           } =
             event
  end

  test "execute on state life safety alarm and update to offnormal immediately on mode change (with time delay)" do
    state =
      ChangeOfLifeSafety.new(:fault, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 1,
        time_delay_normal: nil
      })

    state = %{state | current_state: :life_safety_alarm, last_value: :fault}

    assert {:no_event, ^state} = ChangeOfLifeSafety.execute(state)

    # Value does not match life safety alarm value
    new_state = %{state | monitored_value: :alarm}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :life_safety_alarm} = new_state} =
             ChangeOfLifeSafety.execute(new_state)

    assert {:delayed_event, %{current_state: :life_safety_alarm} = new_state} =
             ChangeOfLifeSafety.execute(new_state)

    # Update mode
    new_state2 = %{new_state | mode: :enabled}

    assert {:event, %{current_state: :offnormal} = new_state2, event} =
             ChangeOfLifeSafety.execute(new_state2)

    assert {:no_event, _state} = ChangeOfLifeSafety.execute(new_state2)

    assert %Notify{
             new_state: :alarm,
             new_mode: :enabled,
             operation_expected: :none,
             status_flags: %StatusFlags{in_alarm: true}
           } =
             event
  end

  test "update invalid params" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    assert_raise ArgumentError, fn -> ChangeOfLifeSafety.update(state, [:hello]) end
  end

  test "update unknown key" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    assert_raise ArgumentError, fn -> ChangeOfLifeSafety.update(state, hello: :there) end
  end

  test "update mode" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    assert %ChangeOfLifeSafety{mode: :enabled} =
             ChangeOfLifeSafety.update(state, mode: :enabled)
  end

  test "update mode invalid value" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    assert_raise ArgumentError, fn -> ChangeOfLifeSafety.update(state, mode: false) end
  end

  test "update monitored_value" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    assert %ChangeOfLifeSafety{monitored_value: :supervisory} =
             ChangeOfLifeSafety.update(state, monitored_value: :supervisory)
  end

  test "update monitored_value invalid value" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    assert_raise ArgumentError, fn -> ChangeOfLifeSafety.update(state, monitored_value: false) end
  end

  test "update operation_expected" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    assert %ChangeOfLifeSafety{operation_expected: :reset_fault} =
             ChangeOfLifeSafety.update(state, operation_expected: :reset_fault)
  end

  test "update operation_expected invalid value" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    assert_raise ArgumentError, fn ->
      ChangeOfLifeSafety.update(state, operation_expected: false)
    end
  end

  test "update parameters" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    new_params = %Params{
      mode: %DeviceObjectPropertyRef{
        object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
        property_identifier: :present_value,
        property_array_index: nil,
        device_identifier: nil
      },
      alarm_values: [:holdup],
      life_safety_alarm_values: [:fault],
      time_delay: 1,
      time_delay_normal: nil
    }

    assert %ChangeOfLifeSafety{parameters: ^new_params} =
             ChangeOfLifeSafety.update(state, parameters: new_params)
  end

  test "update parameters invalid value" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    assert_raise ArgumentError, fn -> ChangeOfLifeSafety.update(state, parameters: nil) end
  end

  test "update status_flags" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    new_flags = %StatusFlags{
      in_alarm: true,
      fault: false,
      out_of_service: true,
      overridden: false
    }

    assert %ChangeOfLifeSafety{status_flags: ^new_flags} =
             ChangeOfLifeSafety.update(state, status_flags: new_flags)
  end

  test "update status_flags invalid value" do
    state =
      ChangeOfLifeSafety.new(:quiet, :off, :none, %Params{
        mode: %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :life_safety_point, instance: 0},
          property_identifier: :present_value,
          property_array_index: nil,
          device_identifier: nil
        },
        alarm_values: [:alarm, :holdup],
        life_safety_alarm_values: [:fault, :local_alarm],
        time_delay: 0,
        time_delay_normal: 0
      })

    assert_raise ArgumentError, fn -> ChangeOfLifeSafety.update(state, status_flags: nil) end
  end
end
