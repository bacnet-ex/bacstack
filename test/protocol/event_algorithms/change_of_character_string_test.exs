defmodule BACnet.Protocol.EventAlgorithms.ChangeOfCharacterStringTest do
  alias BACnet.Protocol.EventAlgorithms.ChangeOfCharacterString
  alias BACnet.Protocol.EventParameters.ChangeOfCharacterString, as: Params
  alias BACnet.Protocol.NotificationParameters.ChangeOfCharacterString, as: Notify
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :event_algorithms
  @moduletag :protocol_data_structures

  doctest ChangeOfCharacterString

  test "assert tag number of event parameters is correct" do
    assert 17 = Params.get_tag_number()
  end

  test "create new state" do
    assert %ChangeOfCharacterString{} =
             ChangeOfCharacterString.new("hello", %Params{
               alarm_values: ["high ground"],
               time_delay: 0,
               time_delay_normal: 0
             })
  end

  test "create new state fails for invalid monitored_value" do
    assert_raise FunctionClauseError, fn ->
      ChangeOfCharacterString.new(0, %Params{
        alarm_values: ["high ground"],
        time_delay: 0,
        time_delay_normal: 0
      })
    end

    assert_raise ArgumentError, fn ->
      ChangeOfCharacterString.new(<<4, 3, 255, 255, 255>>, %Params{
        alarm_values: ["high ground"],
        time_delay: 0,
        time_delay_normal: 0
      })
    end
  end

  test "create new state fails for invalid params" do
    assert_raise FunctionClauseError, fn ->
      ChangeOfCharacterString.new("hello", %{})
    end
  end

  test "execute on same state stays normal" do
    state =
      ChangeOfCharacterString.new("hello", %Params{
        alarm_values: ["high ground"],
        time_delay: 0,
        time_delay_normal: 0
      })

    assert {:no_event, ^state} = ChangeOfCharacterString.execute(state)
    assert {:no_event, ^state} = ChangeOfCharacterString.execute(state)
    assert {:no_event, ^state} = ChangeOfCharacterString.execute(state)
    Process.sleep(1000)
    assert {:no_event, ^state} = ChangeOfCharacterString.execute(state)
    assert {:no_event, ^state} = ChangeOfCharacterString.execute(state)
    assert {:no_event, ^state} = ChangeOfCharacterString.execute(state)
  end

  test "execute on state normal and update to offnormal (no time delay)" do
    state =
      ChangeOfCharacterString.new("hello", %Params{
        alarm_values: ["high ground"],
        time_delay: 0,
        time_delay_normal: nil
      })

    # Value does not match alarm value
    assert {:no_event, ^state} = ChangeOfCharacterString.execute(state)

    # Value does not match alarm value
    changed_value = %{state | monitored_value: "hello"}

    assert {:no_event, %{current_state: :normal} = _state} =
             ChangeOfCharacterString.execute(changed_value)

    # Value matches alarm value
    changed_value2 = %{state | monitored_value: "high ground"}

    assert {:event, %{current_state: :offnormal} = changed_value2, event} =
             ChangeOfCharacterString.execute(changed_value2)

    assert {:no_event, %{current_state: :offnormal} = _state} =
             ChangeOfCharacterString.execute(changed_value2)

    assert %Notify{
             changed_value: "high ground",
             alarm_value: "high ground",
             status_flags: %StatusFlags{in_alarm: true}
           } = event
  end

  test "execute on state normal and update to offnormal with empty string (no time delay)" do
    state =
      ChangeOfCharacterString.new("hello", %Params{
        alarm_values: [""],
        time_delay: 0,
        time_delay_normal: nil
      })

    # Value does not match alarm value
    assert {:no_event, ^state} = ChangeOfCharacterString.execute(state)

    # Value does not match alarm value
    changed_value = %{state | monitored_value: "hello"}

    assert {:no_event, %{current_state: :normal} = _state} =
             ChangeOfCharacterString.execute(changed_value)

    # Value matches alarm value
    changed_value2 = %{state | monitored_value: ""}

    assert {:event, %{current_state: :offnormal} = changed_value2, event} =
             ChangeOfCharacterString.execute(changed_value2)

    assert {:no_event, %{current_state: :offnormal} = _state} =
             ChangeOfCharacterString.execute(changed_value2)

    assert %Notify{
             changed_value: "",
             alarm_value: "",
             status_flags: %StatusFlags{in_alarm: true}
           } = event
  end

  test "execute on state normal and update NOT to offnormal due to case mismatch (no time delay)" do
    state =
      ChangeOfCharacterString.new("hello", %Params{
        alarm_values: ["high ground"],
        time_delay: 0,
        time_delay_normal: nil
      })

    # Value does not match alarm value
    assert {:no_event, ^state} = ChangeOfCharacterString.execute(state)

    # Value does not match alarm value
    changed_value = %{state | monitored_value: "hello"}

    assert {:no_event, %{current_state: :normal} = _state} =
             ChangeOfCharacterString.execute(changed_value)

    # Value matches NOT alarm value (case sensitive)
    changed_value2 = %{state | monitored_value: "High ground"}

    assert {:no_event, %{current_state: :normal} = _state} =
             ChangeOfCharacterString.execute(changed_value2)
  end

  test "execute on state normal and update to offnormal (no time delay), try with second value in alarm values (mid word, nil ignored)" do
    state =
      ChangeOfCharacterString.new("hello", %Params{
        alarm_values: ["high ground", nil, "or"],
        time_delay: 0,
        time_delay_normal: nil
      })

    # Value does not match alarm value
    assert {:no_event, ^state} = ChangeOfCharacterString.execute(state)

    # Value does not match alarm value
    changed_value = %{state | monitored_value: "case"}

    assert {:no_event, %{current_state: :normal} = _state} =
             ChangeOfCharacterString.execute(changed_value)

    # Value matches alarm value
    changed_value2 = %{state | monitored_value: "world"}

    assert {:event, %{current_state: :offnormal} = changed_value2, event} =
             ChangeOfCharacterString.execute(changed_value2)

    assert {:no_event, %{current_state: :offnormal} = _state} =
             ChangeOfCharacterString.execute(changed_value2)

    assert %Notify{
             changed_value: "world",
             alarm_value: "or",
             status_flags: %StatusFlags{in_alarm: true}
           } = event
  end

  test "execute on state offnormal and update to normal (no time delay)" do
    state =
      ChangeOfCharacterString.new("high ground", %Params{
        alarm_values: ["high ground"],
        time_delay: 0,
        time_delay_normal: nil
      })

    state = %{
      state
      | current_state: :offnormal,
        last_value: "high ground",
        last_alarm_value: "high ground"
    }

    # Value does not match alarm value
    assert {:no_event, ^state} = ChangeOfCharacterString.execute(state)

    # Value does not match alarm value
    new_state = %{state | monitored_value: "hello"}

    assert {:event, %{current_state: :normal} = _state, event} =
             ChangeOfCharacterString.execute(new_state)

    assert %Notify{
             changed_value: "hello",
             alarm_value: "high ground",
             status_flags: %StatusFlags{in_alarm: false}
           } = event
  end

  test "execute on state offnormal and new event on different alarm value (no time delay)" do
    state =
      ChangeOfCharacterString.new("hello", %Params{
        alarm_values: ["hello", nil, "or"],
        time_delay: 0,
        time_delay_normal: nil
      })

    state = %{
      state
      | current_state: :offnormal,
        last_value: "hello"
    }

    # Value does not match first alarm value, but second alarm value
    new_state = %{state | monitored_value: "world"}

    assert {:event, %{current_state: :offnormal} = _state, event} =
             ChangeOfCharacterString.execute(new_state)

    assert %Notify{
             changed_value: "world",
             alarm_value: "or",
             status_flags: %StatusFlags{in_alarm: true}
           } = event
  end

  test "execute on state normal and update to offnormal and back to normal (with time delay, no time delay normal)" do
    state =
      ChangeOfCharacterString.new("hello", %Params{
        alarm_values: ["high ground"],
        time_delay: 1,
        time_delay_normal: nil
      })

    assert {:no_event, ^state} = ChangeOfCharacterString.execute(state)

    # Value does not match alarm value
    new_state = %{state | monitored_value: "hello"}

    assert {:no_event, _state} = ChangeOfCharacterString.execute(new_state)

    # Value matches alarm value
    new_state2 = %{state | monitored_value: "high ground"}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfCharacterString.execute(new_state2)

    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfCharacterString.execute(new_state2)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state2 = %{new_state2 | dt_offnormal: DateTime.add(new_state2.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :offnormal} = new_state2, event} =
             ChangeOfCharacterString.execute(new_state2)

    assert {:no_event, _state} = ChangeOfCharacterString.execute(new_state2)

    assert %Notify{
             changed_value: "high ground",
             alarm_value: "high ground",
             status_flags: %StatusFlags{in_alarm: true}
           } = event

    # Now change back to normal after time_delay
    new_state3 = %{
      new_state2
      | monitored_value: "hello"
    }

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfCharacterString.execute(new_state3)

    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfCharacterString.execute(new_state3)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state3 = %{new_state3 | dt_normal: DateTime.add(new_state3.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = new_state3, event2} =
             ChangeOfCharacterString.execute(new_state3)

    assert {:no_event, _state} = ChangeOfCharacterString.execute(new_state3)

    assert %Notify{
             changed_value: "hello",
             alarm_value: "high ground",
             status_flags: %StatusFlags{in_alarm: false}
           } = event2
  end

  test "execute on state normal and update to offnormal and back to normal (with time delay and time delay normal)" do
    state =
      ChangeOfCharacterString.new("hello", %Params{
        alarm_values: ["high ground"],
        time_delay: 1,
        time_delay_normal: 2
      })

    assert {:no_event, ^state} = ChangeOfCharacterString.execute(state)

    # Value does not match alarm value
    new_state = %{state | monitored_value: "hello"}

    assert {:no_event, _state} = ChangeOfCharacterString.execute(new_state)

    # Value matches alarm value
    new_state2 = %{state | monitored_value: "high ground"}

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfCharacterString.execute(new_state2)

    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfCharacterString.execute(new_state2)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state2 = %{new_state2 | dt_offnormal: DateTime.add(new_state2.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :offnormal} = new_state2, event} =
             ChangeOfCharacterString.execute(new_state2)

    assert {:no_event, _state} = ChangeOfCharacterString.execute(new_state2)

    assert %Notify{
             changed_value: "high ground",
             alarm_value: "high ground",
             status_flags: %StatusFlags{in_alarm: true}
           } = event

    # Now change back to normal after time_delay
    new_state3 = %{
      new_state2
      | monitored_value: "hello"
    }

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfCharacterString.execute(new_state3)

    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfCharacterString.execute(new_state3)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state3 = %{new_state3 | dt_normal: DateTime.add(new_state3.dt_normal, -1, :second)}

    # No event yet, two seconds need to pass
    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfCharacterString.execute(new_state3)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state3 = %{new_state3 | dt_normal: DateTime.add(new_state3.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = new_state3, event2} =
             ChangeOfCharacterString.execute(new_state3)

    assert {:no_event, _state} = ChangeOfCharacterString.execute(new_state3)

    assert %Notify{
             changed_value: "hello",
             alarm_value: "high ground",
             status_flags: %StatusFlags{in_alarm: false}
           } = event2
  end

  test "execute on state offnormal and new event on different alarm value (with time delay)" do
    state =
      ChangeOfCharacterString.new("high ground", %Params{
        alarm_values: [
          "high ground",
          "hello"
        ],
        time_delay: 1,
        time_delay_normal: nil
      })

    state = %{
      state
      | current_state: :offnormal,
        last_value: "high ground"
    }

    # Value does not match first alarm value, but second alarm value
    new_state = %{state | monitored_value: "hello"}

    assert {:delayed_event, %{current_state: :offnormal} = new_state} =
             ChangeOfCharacterString.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_offnormal: DateTime.add(new_state.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :offnormal} = _state, event} =
             ChangeOfCharacterString.execute(new_state)

    assert %Notify{
             changed_value: "hello",
             alarm_value: "hello",
             status_flags: %StatusFlags{in_alarm: true}
           } = event
  end

  test "execute on state offnormal and new event on different alarm value and empty string (with time delay)" do
    state =
      ChangeOfCharacterString.new("high ground", %Params{
        alarm_values: [
          "high ground",
          nil,
          ""
        ],
        time_delay: 1,
        time_delay_normal: nil
      })

    state = %{
      state
      | current_state: :offnormal,
        last_value: "high ground"
    }

    # Value does not match first alarm value, but second alarm value
    new_state = %{state | monitored_value: ""}

    assert {:delayed_event, %{current_state: :offnormal} = new_state} =
             ChangeOfCharacterString.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_offnormal: DateTime.add(new_state.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :offnormal} = _state, event} =
             ChangeOfCharacterString.execute(new_state)

    assert %Notify{
             changed_value: "",
             alarm_value: "",
             status_flags: %StatusFlags{in_alarm: true}
           } = event
  end

  test "update invalid params" do
    state =
      ChangeOfCharacterString.new("hello", %Params{
        alarm_values: ["world"],
        time_delay: 1,
        time_delay_normal: 2
      })

    assert_raise ArgumentError, fn -> ChangeOfCharacterString.update(state, [:hello]) end
  end

  test "update unknown key" do
    state =
      ChangeOfCharacterString.new("hello", %Params{
        alarm_values: ["world"],
        time_delay: 1,
        time_delay_normal: 2
      })

    assert_raise ArgumentError, fn -> ChangeOfCharacterString.update(state, hello: :there) end
  end

  test "update monitored_value" do
    state =
      ChangeOfCharacterString.new("hello", %Params{
        alarm_values: ["world"],
        time_delay: 1,
        time_delay_normal: 2
      })

    assert %ChangeOfCharacterString{monitored_value: "world"} =
             ChangeOfCharacterString.update(state,
               monitored_value: "world"
             )
  end

  test "update monitored_value invalid value" do
    state =
      ChangeOfCharacterString.new("hello", %Params{
        alarm_values: ["world"],
        time_delay: 1,
        time_delay_normal: 2
      })

    assert_raise ArgumentError, fn ->
      ChangeOfCharacterString.update(state, monitored_value: false)
    end

    assert_raise ArgumentError, fn ->
      ChangeOfCharacterString.update(state,
        monitored_value: <<4, 3, 255, 255, 255>>
      )
    end
  end

  test "update parameters" do
    state =
      ChangeOfCharacterString.new("hello", %Params{
        alarm_values: ["world"],
        time_delay: 1,
        time_delay_normal: 2
      })

    new_params = %Params{
      alarm_values: ["hello"],
      time_delay: 1,
      time_delay_normal: nil
    }

    assert %ChangeOfCharacterString{parameters: ^new_params} =
             ChangeOfCharacterString.update(state, parameters: new_params)
  end

  test "update parameters invalid value" do
    state =
      ChangeOfCharacterString.new("hello", %Params{
        alarm_values: ["world"],
        time_delay: 1,
        time_delay_normal: 2
      })

    assert_raise ArgumentError, fn -> ChangeOfCharacterString.update(state, parameters: nil) end
  end

  test "update status_flags" do
    state =
      ChangeOfCharacterString.new("hello", %Params{
        alarm_values: ["world"],
        time_delay: 1,
        time_delay_normal: 2
      })

    new_flags = %StatusFlags{
      in_alarm: true,
      fault: false,
      out_of_service: true,
      overridden: false
    }

    assert %ChangeOfCharacterString{status_flags: ^new_flags} =
             ChangeOfCharacterString.update(state, status_flags: new_flags)
  end

  test "update status_flags invalid value" do
    state =
      ChangeOfCharacterString.new("hello", %Params{
        alarm_values: ["world"],
        time_delay: 1,
        time_delay_normal: 2
      })

    assert_raise ArgumentError, fn -> ChangeOfCharacterString.update(state, status_flags: nil) end
  end
end
