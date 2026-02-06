defmodule BACnet.Protocol.EventAlgorithms.ChangeOfStateTest do
  alias BACnet.Protocol.EventAlgorithms.ChangeOfState
  alias BACnet.Protocol.EventParameters.ChangeOfState, as: Params
  alias BACnet.Protocol.NotificationParameters.ChangeOfState, as: Notify
  alias BACnet.Protocol.PropertyState
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :event_algorithms
  @moduletag :protocol_data_structures

  doctest ChangeOfState

  test "assert tag number of event parameters is correct" do
    assert 1 = Params.get_tag_number()
  end

  test "create new state" do
    assert %ChangeOfState{} =
             ChangeOfState.new(%PropertyState{type: :boolean_value, value: false}, %Params{
               alarm_values: [%PropertyState{type: :boolean_value, value: false}],
               time_delay: 0,
               time_delay_normal: 0
             })
  end

  test "create new state fails for invalid monitored_value" do
    assert_raise FunctionClauseError, fn ->
      ChangeOfState.new(0, %Params{
        alarm_values: [%PropertyState{type: :boolean_value, value: false}],
        time_delay: 0,
        time_delay_normal: 0
      })
    end
  end

  test "create new state fails for type mismatch monitored_value" do
    assert_raise ArgumentError, fn ->
      ChangeOfState.new(%PropertyState{type: :boolean_value, value: false}, %Params{
        alarm_values: [
          %PropertyState{type: :boolean_value, value: false},
          %PropertyState{type: :binary_value, value: false}
        ],
        time_delay: 0,
        time_delay_normal: 0
      })
    end
  end

  test "create new state fails for invalid params" do
    assert_raise FunctionClauseError, fn ->
      ChangeOfState.new(%PropertyState{type: :boolean_value, value: false}, %{})
    end
  end

  test "execute on same state stays normal" do
    state =
      ChangeOfState.new(%PropertyState{type: :boolean_value, value: false}, %Params{
        alarm_values: [%PropertyState{type: :boolean_value, value: true}],
        time_delay: 0,
        time_delay_normal: 0
      })

    assert {:no_event, ^state} = ChangeOfState.execute(state)
    assert {:no_event, ^state} = ChangeOfState.execute(state)
    assert {:no_event, ^state} = ChangeOfState.execute(state)
    Process.sleep(1000)
    assert {:no_event, ^state} = ChangeOfState.execute(state)
    assert {:no_event, ^state} = ChangeOfState.execute(state)
    assert {:no_event, ^state} = ChangeOfState.execute(state)
  end

  test "execute on state normal and update to offnormal (no time delay)" do
    state =
      ChangeOfState.new(%PropertyState{type: :boolean_value, value: false}, %Params{
        alarm_values: [%PropertyState{type: :boolean_value, value: true}],
        time_delay: 0,
        time_delay_normal: nil
      })

    # Value does not match alarm value
    assert {:no_event, ^state} = ChangeOfState.execute(state)

    # Value does not match alarm value
    new_state = %{state | monitored_value: %PropertyState{type: :boolean_value, value: false}}

    assert {:no_event, %{current_state: :normal} = _state} = ChangeOfState.execute(new_state)

    # Value matches alarm value
    new_state2 = %{state | monitored_value: %PropertyState{type: :boolean_value, value: true}}

    assert {:event, %{current_state: :offnormal} = new_state2, event} =
             ChangeOfState.execute(new_state2)

    assert {:no_event, %{current_state: :offnormal} = _state} = ChangeOfState.execute(new_state2)

    assert %Notify{
             new_state: %PropertyState{type: :boolean_value, value: true},
             status_flags: %StatusFlags{in_alarm: true}
           } = event
  end

  test "execute on state normal and update to offnormal (no time delay), try with second value in alarm values" do
    state =
      ChangeOfState.new(%PropertyState{type: :integer_value, value: 0}, %Params{
        alarm_values: [
          %PropertyState{type: :integer_value, value: 1},
          %PropertyState{type: :integer_value, value: 3}
        ],
        time_delay: 0,
        time_delay_normal: nil
      })

    # Value does not match alarm value
    assert {:no_event, ^state} = ChangeOfState.execute(state)

    # Value does not match alarm value
    new_state = %{state | monitored_value: %PropertyState{type: :integer_value, value: 2}}

    assert {:no_event, %{current_state: :normal} = _state} = ChangeOfState.execute(new_state)

    # Value matches alarm value
    new_state2 = %{state | monitored_value: %PropertyState{type: :integer_value, value: 3}}

    assert {:event, %{current_state: :offnormal} = new_state2, event} =
             ChangeOfState.execute(new_state2)

    assert {:no_event, %{current_state: :offnormal} = _state} = ChangeOfState.execute(new_state2)

    assert %Notify{
             new_state: %PropertyState{type: :integer_value, value: 3},
             status_flags: %StatusFlags{in_alarm: true}
           } = event
  end

  test "execute on state offnormal and update to normal (no time delay)" do
    state =
      ChangeOfState.new(%PropertyState{type: :boolean_value, value: true}, %Params{
        alarm_values: [%PropertyState{type: :boolean_value, value: true}],
        time_delay: 0,
        time_delay_normal: nil
      })

    state = %{
      state
      | current_state: :offnormal,
        last_value: %PropertyState{type: :boolean_value, value: true}
    }

    # Value does not match alarm value
    assert {:no_event, ^state} = ChangeOfState.execute(state)

    # Value does not match alarm value
    new_state = %{state | monitored_value: %PropertyState{type: :boolean_value, value: false}}

    assert {:event, %{current_state: :normal} = _state, event} = ChangeOfState.execute(new_state)

    assert %Notify{
             new_state: %PropertyState{type: :boolean_value, value: false},
             status_flags: %StatusFlags{in_alarm: false}
           } = event
  end

  test "execute on state offnormal and new event on different alarm value (no time delay)" do
    state =
      ChangeOfState.new(%PropertyState{type: :integer_value, value: 1}, %Params{
        alarm_values: [
          %PropertyState{type: :integer_value, value: 1},
          %PropertyState{type: :integer_value, value: 3}
        ],
        time_delay: 0,
        time_delay_normal: nil
      })

    state = %{
      state
      | current_state: :offnormal,
        last_value: %PropertyState{type: :integer_value, value: 1}
    }

    # Value does not match first alarm value, but second alarm value
    new_state = %{state | monitored_value: %PropertyState{type: :integer_value, value: 3}}

    assert {:event, %{current_state: :offnormal} = _state, event} =
             ChangeOfState.execute(new_state)

    assert %Notify{
             new_state: %PropertyState{type: :integer_value, value: 3},
             status_flags: %StatusFlags{in_alarm: true}
           } = event
  end

  test "execute on state normal and update to offnormal and back to normal (with time delay, no time delay normal)" do
    state =
      ChangeOfState.new(%PropertyState{type: :boolean_value, value: false}, %Params{
        alarm_values: [%PropertyState{type: :boolean_value, value: true}],
        time_delay: 1,
        time_delay_normal: nil
      })

    assert {:no_event, ^state} = ChangeOfState.execute(state)

    # Value does not match alarm value
    new_state = %{state | monitored_value: %PropertyState{type: :boolean_value, value: false}}

    assert {:no_event, _state} = ChangeOfState.execute(new_state)

    # Value matches alarm value
    new_state2 = %{state | monitored_value: %PropertyState{type: :boolean_value, value: true}}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfState.execute(new_state2)

    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfState.execute(new_state2)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state2 = %{new_state2 | dt_offnormal: DateTime.add(new_state2.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :offnormal} = new_state2, event} =
             ChangeOfState.execute(new_state2)

    assert {:no_event, _state} = ChangeOfState.execute(new_state2)

    assert %Notify{
             new_state: %PropertyState{type: :boolean_value, value: true},
             status_flags: %StatusFlags{in_alarm: true}
           } = event

    # Now change back to normal after time_delay
    new_state3 = %{
      new_state2
      | monitored_value: %PropertyState{type: :boolean_value, value: false}
    }

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfState.execute(new_state3)

    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfState.execute(new_state3)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state3 = %{new_state3 | dt_normal: DateTime.add(new_state3.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = new_state3, event2} =
             ChangeOfState.execute(new_state3)

    assert {:no_event, _state} = ChangeOfState.execute(new_state3)

    assert %Notify{
             new_state: %PropertyState{type: :boolean_value, value: false},
             status_flags: %StatusFlags{in_alarm: false}
           } = event2
  end

  test "execute on state normal and update to offnormal and back to normal (with time delay and time delay normal)" do
    state =
      ChangeOfState.new(%PropertyState{type: :boolean_value, value: false}, %Params{
        alarm_values: [%PropertyState{type: :boolean_value, value: true}],
        time_delay: 1,
        time_delay_normal: 2
      })

    assert {:no_event, ^state} = ChangeOfState.execute(state)

    # Value does not match alarm value
    new_state = %{state | monitored_value: %PropertyState{type: :boolean_value, value: false}}

    assert {:no_event, _state} = ChangeOfState.execute(new_state)

    # Value matches alarm value
    new_state2 = %{state | monitored_value: %PropertyState{type: :boolean_value, value: true}}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfState.execute(new_state2)

    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfState.execute(new_state2)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state2 = %{new_state2 | dt_offnormal: DateTime.add(new_state2.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :offnormal} = new_state2, event} =
             ChangeOfState.execute(new_state2)

    assert {:no_event, _state} = ChangeOfState.execute(new_state2)

    assert %Notify{
             new_state: %PropertyState{type: :boolean_value, value: true},
             status_flags: %StatusFlags{in_alarm: true}
           } = event

    # Now change back to normal after time_delay
    new_state3 = %{
      new_state2
      | monitored_value: %PropertyState{type: :boolean_value, value: false}
    }

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfState.execute(new_state3)

    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfState.execute(new_state3)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state3 = %{new_state3 | dt_normal: DateTime.add(new_state3.dt_normal, -1, :second)}

    # No event yet, two seconds need to pass
    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfState.execute(new_state3)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state3 = %{new_state3 | dt_normal: DateTime.add(new_state3.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = new_state3, event2} =
             ChangeOfState.execute(new_state3)

    assert {:no_event, _state} = ChangeOfState.execute(new_state3)

    assert %Notify{
             new_state: %PropertyState{type: :boolean_value, value: false},
             status_flags: %StatusFlags{in_alarm: false}
           } = event2
  end

  test "execute on state offnormal and new event on different alarm value (with time delay)" do
    state =
      ChangeOfState.new(%PropertyState{type: :boolean_value, value: true}, %Params{
        alarm_values: [
          %PropertyState{type: :boolean_value, value: true},
          %PropertyState{type: :boolean_value, value: false}
        ],
        time_delay: 1,
        time_delay_normal: nil
      })

    state = %{
      state
      | current_state: :offnormal,
        last_value: %PropertyState{type: :boolean_value, value: true}
    }

    # Value does not match first alarm value, but second alarm value
    new_state = %{state | monitored_value: %PropertyState{type: :boolean_value, value: false}}

    assert {:delayed_event, %{current_state: :offnormal} = new_state} =
             ChangeOfState.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_offnormal: DateTime.add(new_state.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :offnormal} = _state, event} =
             ChangeOfState.execute(new_state)

    assert %Notify{
             new_state: %PropertyState{type: :boolean_value, value: false},
             status_flags: %StatusFlags{in_alarm: true}
           } = event
  end

  test "update invalid params" do
    state =
      ChangeOfState.new(%PropertyState{type: :boolean_value, value: false}, %Params{
        alarm_values: [%PropertyState{type: :boolean_value, value: true}],
        time_delay: 1,
        time_delay_normal: 2
      })

    assert_raise ArgumentError, fn -> ChangeOfState.update(state, [:hello]) end
  end

  test "update unknown key" do
    state =
      ChangeOfState.new(%PropertyState{type: :boolean_value, value: false}, %Params{
        alarm_values: [%PropertyState{type: :boolean_value, value: true}],
        time_delay: 1,
        time_delay_normal: 2
      })

    assert_raise ArgumentError, fn -> ChangeOfState.update(state, hello: :there) end
  end

  test "update monitored_value" do
    state =
      ChangeOfState.new(%PropertyState{type: :boolean_value, value: false}, %Params{
        alarm_values: [%PropertyState{type: :boolean_value, value: true}],
        time_delay: 1,
        time_delay_normal: 2
      })

    assert %ChangeOfState{monitored_value: %PropertyState{type: :boolean_value, value: true}} =
             ChangeOfState.update(state,
               monitored_value: %PropertyState{type: :boolean_value, value: true}
             )
  end

  test "update monitored_value invalid value" do
    state =
      ChangeOfState.new(%PropertyState{type: :boolean_value, value: false}, %Params{
        alarm_values: [%PropertyState{type: :boolean_value, value: true}],
        time_delay: 1,
        time_delay_normal: 2
      })

    assert_raise ArgumentError, fn -> ChangeOfState.update(state, monitored_value: false) end

    assert_raise ArgumentError, fn ->
      ChangeOfState.update(state,
        monitored_value: %PropertyState{type: :binary_value, value: false}
      )
    end
  end

  test "update parameters" do
    state =
      ChangeOfState.new(%PropertyState{type: :boolean_value, value: false}, %Params{
        alarm_values: [%PropertyState{type: :boolean_value, value: true}],
        time_delay: 1,
        time_delay_normal: 2
      })

    new_params = %Params{
      alarm_values: [%PropertyState{type: :boolean_value, value: false}],
      time_delay: 1,
      time_delay_normal: nil
    }

    assert %ChangeOfState{parameters: ^new_params} =
             ChangeOfState.update(state, parameters: new_params)
  end

  test "update parameters invalid value" do
    state =
      ChangeOfState.new(%PropertyState{type: :boolean_value, value: false}, %Params{
        alarm_values: [%PropertyState{type: :boolean_value, value: true}],
        time_delay: 1,
        time_delay_normal: 2
      })

    assert_raise ArgumentError, fn -> ChangeOfState.update(state, parameters: nil) end

    new_params = %Params{
      alarm_values: [%PropertyState{type: :binary_value, value: false}],
      time_delay: 1,
      time_delay_normal: nil
    }

    assert_raise ArgumentError, fn ->
      ChangeOfState.update(state, parameters: new_params)
    end
  end

  test "update status_flags" do
    state =
      ChangeOfState.new(%PropertyState{type: :boolean_value, value: false}, %Params{
        alarm_values: [%PropertyState{type: :boolean_value, value: true}],
        time_delay: 1,
        time_delay_normal: 2
      })

    new_flags = %StatusFlags{
      in_alarm: true,
      fault: false,
      out_of_service: true,
      overridden: false
    }

    assert %ChangeOfState{status_flags: ^new_flags} =
             ChangeOfState.update(state, status_flags: new_flags)
  end

  test "update status_flags invalid value" do
    state =
      ChangeOfState.new(%PropertyState{type: :boolean_value, value: false}, %Params{
        alarm_values: [%PropertyState{type: :boolean_value, value: true}],
        time_delay: 1,
        time_delay_normal: 2
      })

    assert_raise ArgumentError, fn -> ChangeOfState.update(state, status_flags: nil) end
  end
end
