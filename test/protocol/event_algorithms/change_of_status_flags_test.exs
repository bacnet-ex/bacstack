defmodule BACnet.Protocol.EventAlgorithms.ChangeOfStatusFlagsTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.EventAlgorithms.ChangeOfStatusFlags
  alias BACnet.Protocol.EventParameters.ChangeOfStatusFlags, as: Params
  alias BACnet.Protocol.NotificationParameters.ChangeOfStatusFlags, as: Notify
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :event_algorithms
  @moduletag :protocol_data_structures

  doctest ChangeOfStatusFlags

  test "assert tag number of event parameters is correct" do
    assert 18 = Params.get_tag_number()
  end

  test "create new state" do
    assert %ChangeOfStatusFlags{} =
             ChangeOfStatusFlags.new(
               %StatusFlags{
                 in_alarm: false,
                 fault: false,
                 out_of_service: false,
                 overridden: false
               },
               nil,
               %Params{
                 selected_flags: %StatusFlags{
                   in_alarm: true,
                   fault: false,
                   out_of_service: true,
                   overridden: false
                 },
                 time_delay: 0,
                 time_delay_normal: 0
               }
             )

    assert %ChangeOfStatusFlags{} =
             ChangeOfStatusFlags.new(
               %StatusFlags{
                 in_alarm: false,
                 fault: false,
                 out_of_service: false,
                 overridden: false
               },
               Encoding.create!({:real, 42.0}),
               %Params{
                 selected_flags: %StatusFlags{
                   in_alarm: true,
                   fault: false,
                   out_of_service: true,
                   overridden: false
                 },
                 time_delay: 0,
                 time_delay_normal: 0
               }
             )
  end

  test "create new state fails for invalid monitored_value" do
    assert_raise FunctionClauseError, fn ->
      ChangeOfStatusFlags.new(0, nil, %Params{
        selected_flags: %StatusFlags{
          in_alarm: true,
          fault: false,
          out_of_service: true,
          overridden: false
        },
        time_delay: 0,
        time_delay_normal: 0
      })
    end
  end

  test "create new state fails for invalid present_value" do
    assert_raise ArgumentError, fn ->
      ChangeOfStatusFlags.new(
        %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: false
        },
        %{},
        %Params{
          selected_flags: %StatusFlags{
            in_alarm: true,
            fault: false,
            out_of_service: true,
            overridden: false
          },
          time_delay: 0,
          time_delay_normal: nil
        }
      )
    end
  end

  test "create new state fails for invalid params" do
    assert_raise FunctionClauseError, fn ->
      ChangeOfStatusFlags.new("hello", %{})
    end
  end

  test "execute on same state stays normal" do
    state =
      ChangeOfStatusFlags.new(
        %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: false
        },
        nil,
        %Params{
          selected_flags: %StatusFlags{
            in_alarm: true,
            fault: false,
            out_of_service: true,
            overridden: false
          },
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    assert {:no_event, ^state} = ChangeOfStatusFlags.execute(state)
    assert {:no_event, ^state} = ChangeOfStatusFlags.execute(state)
    assert {:no_event, ^state} = ChangeOfStatusFlags.execute(state)
    Process.sleep(1000)
    assert {:no_event, ^state} = ChangeOfStatusFlags.execute(state)
    assert {:no_event, ^state} = ChangeOfStatusFlags.execute(state)
    assert {:no_event, ^state} = ChangeOfStatusFlags.execute(state)
  end

  test "execute on state normal and update to offnormal (no time delay)" do
    state =
      ChangeOfStatusFlags.new(
        %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: false
        },
        nil,
        %Params{
          selected_flags: %StatusFlags{
            in_alarm: true,
            fault: false,
            out_of_service: true,
            overridden: false
          },
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    # Value does not match alarm value
    assert {:no_event, ^state} = ChangeOfStatusFlags.execute(state)

    # Value does not match alarm value
    changed_value = %{
      state
      | monitored_value: %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: true
        }
    }

    assert {:no_event, %{current_state: :normal} = _state} =
             ChangeOfStatusFlags.execute(changed_value)

    # Value matches alarm value
    changed_value2 = %{
      state
      | monitored_value: %StatusFlags{
          in_alarm: true,
          fault: false,
          out_of_service: false,
          overridden: false
        }
    }

    assert {:event, %{current_state: :offnormal} = changed_value2, event} =
             ChangeOfStatusFlags.execute(changed_value2)

    assert {:no_event, %{current_state: :offnormal} = _state} =
             ChangeOfStatusFlags.execute(changed_value2)

    assert %Notify{
             present_value: nil,
             referenced_flags: %StatusFlags{
               in_alarm: true,
               fault: false,
               out_of_service: false,
               overridden: false
             }
           } = event
  end

  test "execute on state normal and update to offnormal with present value (no time delay)" do
    pv = Encoding.create!({:real, 42.0})

    state =
      ChangeOfStatusFlags.new(
        %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: false
        },
        pv,
        %Params{
          selected_flags: %StatusFlags{
            in_alarm: true,
            fault: false,
            out_of_service: true,
            overridden: false
          },
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    # Value does not match alarm value
    assert {:no_event, ^state} = ChangeOfStatusFlags.execute(state)

    # Value does not match alarm value
    changed_value = %{
      state
      | monitored_value: %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: true
        }
    }

    assert {:no_event, %{current_state: :normal} = _state} =
             ChangeOfStatusFlags.execute(changed_value)

    # Value matches alarm value
    changed_value2 = %{
      state
      | monitored_value: %StatusFlags{
          in_alarm: true,
          fault: false,
          out_of_service: false,
          overridden: false
        }
    }

    assert {:event, %{current_state: :offnormal} = changed_value2, event} =
             ChangeOfStatusFlags.execute(changed_value2)

    assert {:no_event, %{current_state: :offnormal} = _state} =
             ChangeOfStatusFlags.execute(changed_value2)

    assert %Notify{
             present_value: ^pv,
             referenced_flags: %StatusFlags{
               in_alarm: true,
               fault: false,
               out_of_service: false,
               overridden: false
             }
           } = event
  end

  test "execute on state normal and update to offnormal (no time delay), try with second flag" do
    state =
      ChangeOfStatusFlags.new(
        %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: false
        },
        nil,
        %Params{
          selected_flags: %StatusFlags{
            in_alarm: true,
            fault: false,
            out_of_service: true,
            overridden: false
          },
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    # Value does not match alarm value
    assert {:no_event, ^state} = ChangeOfStatusFlags.execute(state)

    # Value does not match alarm value
    changed_value = %{
      state
      | monitored_value: %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: true
        }
    }

    assert {:no_event, %{current_state: :normal} = _state} =
             ChangeOfStatusFlags.execute(changed_value)

    # Value matches alarm value
    changed_value2 = %{
      state
      | monitored_value: %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: true,
          overridden: false
        }
    }

    assert {:event, %{current_state: :offnormal} = changed_value2, event} =
             ChangeOfStatusFlags.execute(changed_value2)

    assert {:no_event, %{current_state: :offnormal} = _state} =
             ChangeOfStatusFlags.execute(changed_value2)

    assert %Notify{
             present_value: nil,
             referenced_flags: %StatusFlags{
               in_alarm: false,
               fault: false,
               out_of_service: true,
               overridden: false
             }
           } = event
  end

  test "execute on state normal and update to offnormal with present value (no time delay), try with second flag" do
    pv = Encoding.create!({:real, 42.0})

    state =
      ChangeOfStatusFlags.new(
        %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: false
        },
        pv,
        %Params{
          selected_flags: %StatusFlags{
            in_alarm: true,
            fault: false,
            out_of_service: true,
            overridden: false
          },
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    # Value does not match alarm value
    assert {:no_event, ^state} = ChangeOfStatusFlags.execute(state)

    # Value does not match alarm value
    changed_value = %{
      state
      | monitored_value: %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: true
        }
    }

    assert {:no_event, %{current_state: :normal} = _state} =
             ChangeOfStatusFlags.execute(changed_value)

    # Value matches alarm value
    changed_value2 = %{
      state
      | monitored_value: %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: true,
          overridden: false
        }
    }

    assert {:event, %{current_state: :offnormal} = changed_value2, event} =
             ChangeOfStatusFlags.execute(changed_value2)

    assert {:no_event, %{current_state: :offnormal} = _state} =
             ChangeOfStatusFlags.execute(changed_value2)

    assert %Notify{
             present_value: ^pv,
             referenced_flags: %StatusFlags{
               in_alarm: false,
               fault: false,
               out_of_service: true,
               overridden: false
             }
           } = event
  end

  test "execute on state offnormal and update to normal (no time delay)" do
    state =
      ChangeOfStatusFlags.new(
        %StatusFlags{
          in_alarm: true,
          fault: false,
          out_of_service: false,
          overridden: false
        },
        nil,
        %Params{
          selected_flags: %StatusFlags{
            in_alarm: true,
            fault: false,
            out_of_service: true,
            overridden: false
          },
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    state = %{
      state
      | current_state: :offnormal,
        last_value: 8
    }

    # Value does not match alarm value
    assert {:no_event, ^state} = ChangeOfStatusFlags.execute(state)

    # Value does not match alarm value
    new_state = %{
      state
      | monitored_value: %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: false
        }
    }

    assert {:event, %{current_state: :normal} = _state, event} =
             ChangeOfStatusFlags.execute(new_state)

    assert %Notify{
             present_value: nil,
             referenced_flags: %StatusFlags{
               in_alarm: false,
               fault: false,
               out_of_service: false,
               overridden: false
             }
           } = event
  end

  test "execute on state offnormal and update to normal with present value (no time delay)" do
    pv = Encoding.create!({:boolean, false})

    state =
      ChangeOfStatusFlags.new(
        %StatusFlags{
          in_alarm: true,
          fault: false,
          out_of_service: false,
          overridden: false
        },
        pv,
        %Params{
          selected_flags: %StatusFlags{
            in_alarm: true,
            fault: false,
            out_of_service: true,
            overridden: false
          },
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    state = %{
      state
      | current_state: :offnormal,
        last_value: 8
    }

    # Value does not match alarm value
    assert {:no_event, ^state} = ChangeOfStatusFlags.execute(state)

    # Value does not match alarm value
    new_state = %{
      state
      | monitored_value: %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: false
        }
    }

    assert {:event, %{current_state: :normal} = _state, event} =
             ChangeOfStatusFlags.execute(new_state)

    assert %Notify{
             present_value: ^pv,
             referenced_flags: %StatusFlags{
               in_alarm: false,
               fault: false,
               out_of_service: false,
               overridden: false
             }
           } = event
  end

  test "execute on state offnormal and new event on different alarm value (no time delay)" do
    state =
      ChangeOfStatusFlags.new(
        %StatusFlags{
          in_alarm: true,
          fault: false,
          out_of_service: false,
          overridden: false
        },
        nil,
        %Params{
          selected_flags: %StatusFlags{
            in_alarm: true,
            fault: false,
            out_of_service: true,
            overridden: false
          },
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    state = %{
      state
      | current_state: :offnormal,
        last_value: 8
    }

    # Value does not match first alarm flag, but second alarm flag
    new_state = %{
      state
      | monitored_value: %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: true,
          overridden: false
        }
    }

    assert {:event, %{current_state: :offnormal, last_value: 1} = _state, event} =
             ChangeOfStatusFlags.execute(new_state)

    assert %Notify{
             present_value: nil,
             referenced_flags: %StatusFlags{
               in_alarm: false,
               fault: false,
               out_of_service: true,
               overridden: false
             }
           } = event
  end

  test "execute on state offnormal and new event on additional alarm value (no time delay)" do
    state =
      ChangeOfStatusFlags.new(
        %StatusFlags{
          in_alarm: true,
          fault: false,
          out_of_service: false,
          overridden: false
        },
        nil,
        %Params{
          selected_flags: %StatusFlags{
            in_alarm: true,
            fault: false,
            out_of_service: true,
            overridden: false
          },
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    state = %{
      state
      | current_state: :offnormal,
        last_value: 8
    }

    # Value does match both alarm flags
    new_state = %{
      state
      | monitored_value: %StatusFlags{
          in_alarm: true,
          fault: false,
          out_of_service: true,
          overridden: false
        }
    }

    assert {:event, %{current_state: :offnormal, last_value: 9} = _state, event} =
             ChangeOfStatusFlags.execute(new_state)

    assert %Notify{
             present_value: nil,
             referenced_flags: %StatusFlags{
               in_alarm: true,
               fault: false,
               out_of_service: true,
               overridden: false
             }
           } = event
  end

  test "execute on state offnormal and no update on unselected flag (no time delay)" do
    state =
      ChangeOfStatusFlags.new(
        %StatusFlags{
          in_alarm: true,
          fault: false,
          out_of_service: false,
          overridden: false
        },
        nil,
        %Params{
          selected_flags: %StatusFlags{
            in_alarm: true,
            fault: false,
            out_of_service: true,
            overridden: false
          },
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    state = %{
      state
      | current_state: :offnormal,
        last_value: 8
    }

    # Value new flag does not match selected flags
    new_state = %{
      state
      | monitored_value: %StatusFlags{
          in_alarm: true,
          fault: true,
          out_of_service: false,
          overridden: false
        }
    }

    assert {:no_event, ^new_state} = ChangeOfStatusFlags.execute(new_state)
  end

  test "execute on state normal and update to offnormal and back to normal (with time delay, no time delay normal)" do
    state =
      ChangeOfStatusFlags.new(
        %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: false
        },
        nil,
        %Params{
          selected_flags: %StatusFlags{
            in_alarm: true,
            fault: false,
            out_of_service: true,
            overridden: false
          },
          time_delay: 1,
          time_delay_normal: nil
        }
      )

    assert {:no_event, ^state} = ChangeOfStatusFlags.execute(state)

    # Value does not match alarm flag
    new_state = %{
      state
      | monitored_value: %StatusFlags{
          in_alarm: false,
          fault: true,
          out_of_service: false,
          overridden: false
        }
    }

    assert {:no_event, _state} = ChangeOfStatusFlags.execute(new_state)

    # Value matches alarm flag
    new_state2 = %{
      state
      | monitored_value: %StatusFlags{
          in_alarm: true,
          fault: false,
          out_of_service: false,
          overridden: false
        }
    }

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfStatusFlags.execute(new_state2)

    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfStatusFlags.execute(new_state2)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state2 = %{new_state2 | dt_offnormal: DateTime.add(new_state2.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :offnormal} = new_state2, event} =
             ChangeOfStatusFlags.execute(new_state2)

    assert {:no_event, _state} = ChangeOfStatusFlags.execute(new_state2)

    assert %Notify{
             present_value: nil,
             referenced_flags: %StatusFlags{
               in_alarm: true,
               fault: false,
               out_of_service: false,
               overridden: false
             }
           } = event

    # Now change back to normal after time_delay
    new_state3 = %{
      new_state2
      | monitored_value: %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: false
        }
    }

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfStatusFlags.execute(new_state3)

    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfStatusFlags.execute(new_state3)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state3 = %{new_state3 | dt_normal: DateTime.add(new_state3.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = new_state3, event2} =
             ChangeOfStatusFlags.execute(new_state3)

    assert {:no_event, _state} = ChangeOfStatusFlags.execute(new_state3)

    assert %Notify{
             present_value: nil,
             referenced_flags: %StatusFlags{
               in_alarm: false,
               fault: false,
               out_of_service: false,
               overridden: false
             }
           } = event2
  end

  test "execute on state normal and update to offnormal and back to normal (with time delay and time delay normal)" do
    state =
      ChangeOfStatusFlags.new(
        %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: false
        },
        nil,
        %Params{
          selected_flags: %StatusFlags{
            in_alarm: true,
            fault: false,
            out_of_service: true,
            overridden: false
          },
          time_delay: 1,
          time_delay_normal: 2
        }
      )

    assert {:no_event, ^state} = ChangeOfStatusFlags.execute(state)

    # Value does not match alarm flag
    new_state = %{
      state
      | monitored_value: %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: true
        }
    }

    assert {:no_event, _state} = ChangeOfStatusFlags.execute(new_state)

    # Value matches alarm flag
    new_state2 = %{
      state
      | monitored_value: %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: true,
          overridden: false
        }
    }

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfStatusFlags.execute(new_state2)

    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             ChangeOfStatusFlags.execute(new_state2)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state2 = %{new_state2 | dt_offnormal: DateTime.add(new_state2.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :offnormal} = new_state2, event} =
             ChangeOfStatusFlags.execute(new_state2)

    assert {:no_event, _state} = ChangeOfStatusFlags.execute(new_state2)

    assert %Notify{
             present_value: nil,
             referenced_flags: %StatusFlags{
               in_alarm: false,
               fault: false,
               out_of_service: true,
               overridden: false
             }
           } = event

    # Now change back to normal after time_delay
    new_state3 = %{
      new_state2
      | monitored_value: %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: false
        }
    }

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfStatusFlags.execute(new_state3)

    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfStatusFlags.execute(new_state3)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state3 = %{new_state3 | dt_normal: DateTime.add(new_state3.dt_normal, -1, :second)}

    # No event yet, two seconds need to pass
    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             ChangeOfStatusFlags.execute(new_state3)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state3 = %{new_state3 | dt_normal: DateTime.add(new_state3.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = new_state3, event2} =
             ChangeOfStatusFlags.execute(new_state3)

    assert {:no_event, _state} = ChangeOfStatusFlags.execute(new_state3)

    assert %Notify{
             present_value: nil,
             referenced_flags: %StatusFlags{
               in_alarm: false,
               fault: false,
               out_of_service: false,
               overridden: false
             }
           } = event2
  end

  test "execute on state offnormal and new event on different alarm flag (with time delay)" do
    pv = Encoding.create!({:null, nil})

    state =
      ChangeOfStatusFlags.new(
        %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: false
        },
        pv,
        %Params{
          selected_flags: %StatusFlags{
            in_alarm: true,
            fault: false,
            out_of_service: true,
            overridden: false
          },
          time_delay: 1,
          time_delay_normal: nil
        }
      )

    state = %{
      state
      | current_state: :offnormal,
        last_value: 8
    }

    # Value does not match first alarm flag, but second alarm flag
    new_state = %{
      state
      | monitored_value: %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: true,
          overridden: false
        }
    }

    assert {:delayed_event, %{current_state: :offnormal} = new_state} =
             ChangeOfStatusFlags.execute(new_state)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state = %{new_state | dt_offnormal: DateTime.add(new_state.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :offnormal} = _state, event} =
             ChangeOfStatusFlags.execute(new_state)

    assert %Notify{
             present_value: ^pv,
             referenced_flags: %StatusFlags{
               in_alarm: false,
               fault: false,
               out_of_service: true,
               overridden: false
             }
           } = event
  end

  test "update invalid params" do
    state =
      ChangeOfStatusFlags.new(
        %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: false
        },
        nil,
        %Params{
          selected_flags: %StatusFlags{
            in_alarm: true,
            fault: false,
            out_of_service: true,
            overridden: false
          },
          time_delay: 1,
          time_delay_normal: 2
        }
      )

    assert_raise ArgumentError, fn -> ChangeOfStatusFlags.update(state, [:hello]) end
  end

  test "update unknown key" do
    state =
      ChangeOfStatusFlags.new(
        %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: false
        },
        nil,
        %Params{
          selected_flags: %StatusFlags{
            in_alarm: true,
            fault: false,
            out_of_service: true,
            overridden: false
          },
          time_delay: 1,
          time_delay_normal: 2
        }
      )

    assert_raise ArgumentError, fn -> ChangeOfStatusFlags.update(state, hello: :there) end
  end

  test "update monitored_value" do
    state =
      ChangeOfStatusFlags.new(
        %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: false
        },
        nil,
        %Params{
          selected_flags: %StatusFlags{
            in_alarm: true,
            fault: false,
            out_of_service: true,
            overridden: false
          },
          time_delay: 1,
          time_delay_normal: 2
        }
      )

    assert %ChangeOfStatusFlags{
             monitored_value: %StatusFlags{
               in_alarm: false,
               fault: false,
               out_of_service: false,
               overridden: true
             }
           } =
             ChangeOfStatusFlags.update(state,
               monitored_value: %StatusFlags{
                 in_alarm: false,
                 fault: false,
                 out_of_service: false,
                 overridden: true
               }
             )
  end

  test "update monitored_value invalid value" do
    state =
      ChangeOfStatusFlags.new(
        %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: false
        },
        nil,
        %Params{
          selected_flags: %StatusFlags{
            in_alarm: true,
            fault: false,
            out_of_service: true,
            overridden: false
          },
          time_delay: 1,
          time_delay_normal: 2
        }
      )

    assert_raise ArgumentError, fn ->
      ChangeOfStatusFlags.update(state, monitored_value: false)
    end
  end

  test "update parameters" do
    state =
      ChangeOfStatusFlags.new(
        %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: false
        },
        nil,
        %Params{
          selected_flags: %StatusFlags{
            in_alarm: true,
            fault: false,
            out_of_service: true,
            overridden: false
          },
          time_delay: 1,
          time_delay_normal: 2
        }
      )

    new_params = %Params{
      selected_flags: %StatusFlags{
        in_alarm: false,
        fault: true,
        out_of_service: false,
        overridden: true
      },
      time_delay: 0,
      time_delay_normal: nil
    }

    assert %ChangeOfStatusFlags{parameters: ^new_params} =
             ChangeOfStatusFlags.update(state, parameters: new_params)
  end

  test "update parameters invalid value" do
    state =
      ChangeOfStatusFlags.new(
        %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: false
        },
        nil,
        %Params{
          selected_flags: %StatusFlags{
            in_alarm: true,
            fault: false,
            out_of_service: true,
            overridden: false
          },
          time_delay: 1,
          time_delay_normal: 2
        }
      )

    assert_raise ArgumentError, fn -> ChangeOfStatusFlags.update(state, parameters: nil) end
  end

  test "update present_value" do
    state =
      ChangeOfStatusFlags.new(
        %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: false
        },
        nil,
        %Params{
          selected_flags: %StatusFlags{
            in_alarm: true,
            fault: false,
            out_of_service: true,
            overridden: false
          },
          time_delay: 1,
          time_delay_normal: 2
        }
      )

    new_pv = Encoding.create!({:null, nil})

    assert %ChangeOfStatusFlags{present_value: ^new_pv} =
             ChangeOfStatusFlags.update(state, present_value: new_pv)

    assert %ChangeOfStatusFlags{present_value: nil} =
             ChangeOfStatusFlags.update(state, present_value: nil)
  end

  test "update present_value invalid value" do
    state =
      ChangeOfStatusFlags.new(
        %StatusFlags{
          in_alarm: false,
          fault: false,
          out_of_service: false,
          overridden: false
        },
        nil,
        %Params{
          selected_flags: %StatusFlags{
            in_alarm: true,
            fault: false,
            out_of_service: true,
            overridden: false
          },
          time_delay: 1,
          time_delay_normal: 2
        }
      )

    assert_raise ArgumentError, fn -> ChangeOfStatusFlags.update(state, present_value: true) end
  end
end
