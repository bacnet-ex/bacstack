defmodule BACnet.Protocol.EventAlgorithms.CommandFailureTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.EventAlgorithms.CommandFailure
  alias BACnet.Protocol.EventParameters.CommandFailure, as: Params
  alias BACnet.Protocol.NotificationParameters.CommandFailure, as: Notify
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :event_algorithms
  @moduletag :protocol_data_structures

  doctest CommandFailure

  test "assert tag number of event parameters is correct" do
    assert 3 = Params.get_tag_number()
  end

  test "create new state" do
    assert %CommandFailure{} =
             CommandFailure.new(
               %Encoding{encoding: :primitive, type: :boolean, value: false, extras: []},
               %Params{
                 feedback_value: %Encoding{
                   encoding: :primitive,
                   type: :boolean,
                   value: false,
                   extras: []
                 },
                 time_delay: 0,
                 time_delay_normal: 0
               }
             )
  end

  test "create new state matching types" do
    assert %CommandFailure{} =
             CommandFailure.new(
               %Encoding{encoding: :primitive, type: :boolean, value: false, extras: []},
               %Params{
                 feedback_value: %Encoding{
                   encoding: :primitive,
                   type: :boolean,
                   value: false,
                   extras: []
                 },
                 time_delay: 0,
                 time_delay_normal: 0
               }
             )
  end

  test "create new state matching types with type=nil" do
    assert %CommandFailure{} =
             CommandFailure.new(
               %Encoding{encoding: :primitive, type: nil, value: :raw, extras: []},
               %Params{
                 feedback_value: %Encoding{
                   encoding: :primitive,
                   type: :hello,
                   value: :hello,
                   extras: []
                 },
                 time_delay: 0,
                 time_delay_normal: 0
               }
             )

    assert %CommandFailure{} =
             CommandFailure.new(
               %Encoding{encoding: :primitive, type: nil, value: "Hello", extras: []},
               %Params{
                 feedback_value: %Encoding{
                   encoding: :primitive,
                   type: :hello,
                   value: "Hi",
                   extras: []
                 },
                 time_delay: 0,
                 time_delay_normal: 0
               }
             )

    assert %CommandFailure{} =
             CommandFailure.new(
               %Encoding{encoding: :primitive, type: nil, value: <<15::size(4)>>, extras: []},
               %Params{
                 feedback_value: %Encoding{
                   encoding: :primitive,
                   type: :hello,
                   value: <<1::size(4)>>,
                   extras: []
                 },
                 time_delay: 0,
                 time_delay_normal: 0
               }
             )

    assert %CommandFailure{} =
             CommandFailure.new(
               %Encoding{encoding: :primitive, type: nil, value: false, extras: []},
               %Params{
                 feedback_value: %Encoding{
                   encoding: :primitive,
                   type: :hello,
                   value: false,
                   extras: []
                 },
                 time_delay: 0,
                 time_delay_normal: 0
               }
             )

    assert %CommandFailure{} =
             CommandFailure.new(
               %Encoding{encoding: :primitive, type: nil, value: 6.9, extras: []},
               %Params{
                 feedback_value: %Encoding{
                   encoding: :primitive,
                   type: :hello,
                   value: 42.0,
                   extras: []
                 },
                 time_delay: 0,
                 time_delay_normal: 0
               }
             )

    assert %CommandFailure{} =
             CommandFailure.new(
               %Encoding{encoding: :primitive, type: nil, value: -1, extras: []},
               %Params{
                 feedback_value: %Encoding{
                   encoding: :primitive,
                   type: :hello,
                   value: 6,
                   extras: []
                 },
                 time_delay: 0,
                 time_delay_normal: 0
               }
             )

    assert %CommandFailure{} =
             CommandFailure.new(
               %Encoding{encoding: :primitive, type: nil, value: {false, false}, extras: []},
               %Params{
                 feedback_value: %Encoding{
                   encoding: :primitive,
                   type: :hello,
                   value: {true, false},
                   extras: []
                 },
                 time_delay: 0,
                 time_delay_normal: 0
               }
             )
  end

  test "create new state matching types unknown types" do
    assert_raise ArgumentError, fn ->
      CommandFailure.new(
        %Encoding{encoding: :primitive, type: nil, value: [], extras: []},
        %Params{
          feedback_value: %Encoding{
            encoding: :primitive,
            type: :hello,
            value: [],
            extras: []
          },
          time_delay: 0,
          time_delay_normal: 0
        }
      )
    end

    assert_raise ArgumentError, fn ->
      CommandFailure.new(
        %Encoding{encoding: :primitive, type: nil, value: %{}, extras: []},
        %Params{
          feedback_value: %Encoding{
            encoding: :primitive,
            type: :hello,
            value: %{},
            extras: []
          },
          time_delay: 0,
          time_delay_normal: 0
        }
      )
    end
  end

  test "create new state fails for invalid monitored_value" do
    assert_raise FunctionClauseError, fn ->
      CommandFailure.new(0, %Params{
        feedback_value: %Encoding{encoding: :primitive, type: :boolean, value: false, extras: []},
        time_delay: 0,
        time_delay_normal: 0
      })
    end
  end

  test "create new state fails for type mismatch monitored_value" do
    assert_raise ArgumentError, fn ->
      CommandFailure.new(
        %Encoding{encoding: :primitive, type: :boolean, value: false, extras: []},
        %Params{
          feedback_value: %Encoding{
            encoding: :primitive,
            type: :signed_integer,
            value: 1,
            extras: []
          },
          time_delay: 0,
          time_delay_normal: 0
        }
      )
    end
  end

  test "create new state fails for invalid params" do
    assert_raise FunctionClauseError, fn ->
      CommandFailure.new(
        %Encoding{encoding: :primitive, type: :boolean, value: false, extras: []},
        %{}
      )
    end
  end

  test "execute on same state stays normal" do
    state =
      CommandFailure.new(
        %Encoding{encoding: :primitive, type: :boolean, value: false, extras: []},
        %Params{
          feedback_value: %Encoding{
            encoding: :primitive,
            type: :boolean,
            value: false,
            extras: []
          },
          time_delay: 0,
          time_delay_normal: 0
        }
      )

    assert {:no_event, ^state} = CommandFailure.execute(state)
    assert {:no_event, ^state} = CommandFailure.execute(state)
    assert {:no_event, ^state} = CommandFailure.execute(state)
    Process.sleep(1000)
    assert {:no_event, ^state} = CommandFailure.execute(state)
    assert {:no_event, ^state} = CommandFailure.execute(state)
    assert {:no_event, ^state} = CommandFailure.execute(state)
  end

  test "execute on state normal and update to offnormal (no time delay)" do
    state =
      CommandFailure.new(
        %Encoding{encoding: :primitive, type: :boolean, value: false, extras: []},
        %Params{
          feedback_value: %Encoding{
            encoding: :primitive,
            type: :boolean,
            value: false,
            extras: []
          },
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    # Value does match feedback value
    assert {:no_event, ^state} = CommandFailure.execute(state)

    # Value does match feedback value
    new_state = %{
      state
      | monitored_value: %Encoding{
          encoding: :primitive,
          type: :boolean,
          value: false,
          extras: []
        }
    }

    assert {:no_event, %{current_state: :normal} = _state} = CommandFailure.execute(new_state)

    # Value does not match feedback value
    new_state2 = %{
      state
      | monitored_value: %Encoding{
          encoding: :primitive,
          type: :boolean,
          value: true,
          extras: []
        }
    }

    assert {:event, %{current_state: :offnormal} = new_state2, event} =
             CommandFailure.execute(new_state2)

    assert {:no_event, %{current_state: :offnormal} = _state} = CommandFailure.execute(new_state2)

    assert %Notify{
             command_value: %Encoding{
               encoding: :primitive,
               type: :boolean,
               value: true,
               extras: []
             },
             feedback_value: %Encoding{
               encoding: :primitive,
               type: :boolean,
               value: false,
               extras: []
             },
             status_flags: %StatusFlags{in_alarm: true}
           } = event
  end

  test "execute on state offnormal and update to normal (no time delay)" do
    state =
      CommandFailure.new(
        %Encoding{encoding: :primitive, type: :boolean, value: true, extras: []},
        %Params{
          feedback_value: %Encoding{
            encoding: :primitive,
            type: :boolean,
            value: false,
            extras: []
          },
          time_delay: 0,
          time_delay_normal: nil
        }
      )

    state = %{
      state
      | current_state: :offnormal,
        last_value: %Encoding{encoding: :primitive, type: :boolean, value: true, extras: []}
    }

    # Value does not match feedback value
    assert {:no_event, ^state} = CommandFailure.execute(state)

    # Value does match feedback value
    new_state = %{
      state
      | monitored_value: %Encoding{
          encoding: :primitive,
          type: :boolean,
          value: false,
          extras: []
        }
    }

    assert {:event, %{current_state: :normal} = _state, event} = CommandFailure.execute(new_state)

    assert %Notify{
             command_value: %Encoding{
               encoding: :primitive,
               type: :boolean,
               value: false,
               extras: []
             },
             feedback_value: %Encoding{
               encoding: :primitive,
               type: :boolean,
               value: false,
               extras: []
             },
             status_flags: %StatusFlags{in_alarm: false}
           } = event
  end

  test "execute on state normal and update to offnormal and back to normal (with time delay, no time delay normal)" do
    state =
      CommandFailure.new(
        %Encoding{encoding: :primitive, type: :boolean, value: false, extras: []},
        %Params{
          feedback_value: %Encoding{
            encoding: :primitive,
            type: :boolean,
            value: false,
            extras: []
          },
          time_delay: 1,
          time_delay_normal: nil
        }
      )

    assert {:no_event, ^state} = CommandFailure.execute(state)

    # Value does match feedback value
    new_state = %{
      state
      | monitored_value: %Encoding{
          encoding: :primitive,
          type: :boolean,
          value: false,
          extras: []
        }
    }

    assert {:no_event, _state} = CommandFailure.execute(new_state)

    # Value does not match feedback value
    new_state2 = %{
      state
      | monitored_value: %Encoding{
          encoding: :primitive,
          type: :boolean,
          value: true,
          extras: []
        }
    }

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             CommandFailure.execute(new_state2)

    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             CommandFailure.execute(new_state2)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state2 = %{new_state2 | dt_offnormal: DateTime.add(new_state2.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :offnormal} = new_state2, event} =
             CommandFailure.execute(new_state2)

    assert {:no_event, _state} = CommandFailure.execute(new_state2)

    assert %Notify{
             command_value: %Encoding{
               encoding: :primitive,
               type: :boolean,
               value: true,
               extras: []
             },
             feedback_value: %Encoding{
               encoding: :primitive,
               type: :boolean,
               value: false,
               extras: []
             },
             status_flags: %StatusFlags{in_alarm: true}
           } = event

    # Now change back to normal after time_delay
    new_state3 = %{
      new_state2
      | monitored_value: %Encoding{
          encoding: :primitive,
          type: :boolean,
          value: false,
          extras: []
        }
    }

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             CommandFailure.execute(new_state3)

    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             CommandFailure.execute(new_state3)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state3 = %{new_state3 | dt_normal: DateTime.add(new_state3.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = new_state3, event2} =
             CommandFailure.execute(new_state3)

    assert {:no_event, _state} = CommandFailure.execute(new_state3)

    assert %Notify{
             command_value: %Encoding{
               encoding: :primitive,
               type: :boolean,
               value: false,
               extras: []
             },
             feedback_value: %Encoding{
               encoding: :primitive,
               type: :boolean,
               value: false,
               extras: []
             },
             status_flags: %StatusFlags{in_alarm: false}
           } = event2
  end

  test "execute on state normal and update to offnormal and back to normal (with time delay and time delay normal)" do
    state =
      CommandFailure.new(
        %Encoding{encoding: :primitive, type: :boolean, value: false, extras: []},
        %Params{
          feedback_value: %Encoding{
            encoding: :primitive,
            type: :boolean,
            value: false,
            extras: []
          },
          time_delay: 1,
          time_delay_normal: 2
        }
      )

    assert {:no_event, ^state} = CommandFailure.execute(state)

    # Value does match feedback value
    new_state = %{
      state
      | monitored_value: %Encoding{
          encoding: :primitive,
          type: :boolean,
          value: false,
          extras: []
        }
    }

    assert {:no_event, _state} = CommandFailure.execute(new_state)

    # Value does not match feedback value
    new_state2 = %{
      state
      | monitored_value: %Encoding{
          encoding: :primitive,
          type: :boolean,
          value: true,
          extras: []
        }
    }

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             CommandFailure.execute(new_state2)

    assert {:delayed_event, %{current_state: :normal} = new_state2} =
             CommandFailure.execute(new_state2)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state2 = %{new_state2 | dt_offnormal: DateTime.add(new_state2.dt_offnormal, -1, :second)}

    assert {:event, %{current_state: :offnormal} = new_state2, event} =
             CommandFailure.execute(new_state2)

    assert {:no_event, _state} = CommandFailure.execute(new_state2)

    assert %Notify{
             command_value: %Encoding{
               encoding: :primitive,
               type: :boolean,
               value: true,
               extras: []
             },
             feedback_value: %Encoding{
               encoding: :primitive,
               type: :boolean,
               value: false,
               extras: []
             },
             status_flags: %StatusFlags{in_alarm: true}
           } = event

    # Now change back to normal after time_delay
    new_state3 = %{
      new_state2
      | monitored_value: %Encoding{
          encoding: :primitive,
          type: :boolean,
          value: false,
          extras: []
        }
    }

    # No event yet, time delay needs to pass
    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             CommandFailure.execute(new_state3)

    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             CommandFailure.execute(new_state3)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state3 = %{new_state3 | dt_normal: DateTime.add(new_state3.dt_normal, -1, :second)}

    # No event yet, two seconds need to pass
    assert {:delayed_event, %{current_state: :offnormal} = new_state3} =
             CommandFailure.execute(new_state3)

    # Manipulate time to skip having to do Process.sleep(...)
    new_state3 = %{new_state3 | dt_normal: DateTime.add(new_state3.dt_normal, -1, :second)}

    assert {:event, %{current_state: :normal} = new_state3, event2} =
             CommandFailure.execute(new_state3)

    assert {:no_event, _state} = CommandFailure.execute(new_state3)

    assert %Notify{
             command_value: %Encoding{
               encoding: :primitive,
               type: :boolean,
               value: false,
               extras: []
             },
             feedback_value: %Encoding{
               encoding: :primitive,
               type: :boolean,
               value: false,
               extras: []
             },
             status_flags: %StatusFlags{in_alarm: false}
           } = event2
  end

  test "update invalid params" do
    state =
      CommandFailure.new(
        %Encoding{encoding: :primitive, type: :boolean, value: false, extras: []},
        %Params{
          feedback_value: %Encoding{encoding: :primitive, type: :boolean, value: true, extras: []},
          time_delay: 1,
          time_delay_normal: 2
        }
      )

    assert_raise ArgumentError, fn -> CommandFailure.update(state, [:hello]) end
  end

  test "update unknown key" do
    state =
      CommandFailure.new(
        %Encoding{encoding: :primitive, type: :boolean, value: false, extras: []},
        %Params{
          feedback_value: %Encoding{encoding: :primitive, type: :boolean, value: true, extras: []},
          time_delay: 1,
          time_delay_normal: 2
        }
      )

    assert_raise ArgumentError, fn -> CommandFailure.update(state, hello: :there) end
  end

  test "update monitored_value" do
    state =
      CommandFailure.new(
        %Encoding{encoding: :primitive, type: :boolean, value: false, extras: []},
        %Params{
          feedback_value: %Encoding{encoding: :primitive, type: :boolean, value: true, extras: []},
          time_delay: 1,
          time_delay_normal: 2
        }
      )

    assert %CommandFailure{
             monitored_value: %Encoding{
               encoding: :primitive,
               type: :boolean,
               value: true,
               extras: []
             }
           } =
             CommandFailure.update(state,
               monitored_value: %Encoding{
                 encoding: :primitive,
                 type: :boolean,
                 value: true,
                 extras: []
               }
             )
  end

  test "update monitored_value invalid value" do
    state =
      CommandFailure.new(
        %Encoding{encoding: :primitive, type: :boolean, value: false, extras: []},
        %Params{
          feedback_value: %Encoding{encoding: :primitive, type: :boolean, value: true, extras: []},
          time_delay: 1,
          time_delay_normal: 2
        }
      )

    assert_raise ArgumentError, fn -> CommandFailure.update(state, monitored_value: false) end

    assert_raise ArgumentError, fn ->
      CommandFailure.update(state,
        monitored_value: %Encoding{
          encoding: :primitive,
          type: :signed_integer,
          value: 1,
          extras: []
        }
      )
    end
  end

  test "update parameters" do
    state =
      CommandFailure.new(
        %Encoding{encoding: :primitive, type: :boolean, value: false, extras: []},
        %Params{
          feedback_value: %Encoding{encoding: :primitive, type: :boolean, value: true, extras: []},
          time_delay: 1,
          time_delay_normal: 2
        }
      )

    new_params = %Params{
      feedback_value: %Encoding{encoding: :primitive, type: :boolean, value: false, extras: []},
      time_delay: 1,
      time_delay_normal: nil
    }

    assert %CommandFailure{parameters: ^new_params} =
             CommandFailure.update(state, parameters: new_params)
  end

  test "update parameters invalid value" do
    state =
      CommandFailure.new(
        %Encoding{encoding: :primitive, type: :boolean, value: false, extras: []},
        %Params{
          feedback_value: %Encoding{encoding: :primitive, type: :boolean, value: true, extras: []},
          time_delay: 1,
          time_delay_normal: 2
        }
      )

    assert_raise ArgumentError, fn -> CommandFailure.update(state, parameters: nil) end

    new_params = %Params{
      feedback_value: %Encoding{encoding: :primitive, type: :signed_integer, value: 1, extras: []},
      time_delay: 1,
      time_delay_normal: nil
    }

    assert_raise ArgumentError, fn ->
      CommandFailure.update(state, parameters: new_params)
    end
  end

  test "update status_flags" do
    state =
      CommandFailure.new(
        %Encoding{encoding: :primitive, type: :boolean, value: false, extras: []},
        %Params{
          feedback_value: %Encoding{encoding: :primitive, type: :boolean, value: true, extras: []},
          time_delay: 1,
          time_delay_normal: 2
        }
      )

    new_flags = %StatusFlags{
      in_alarm: true,
      fault: false,
      out_of_service: true,
      overridden: false
    }

    assert %CommandFailure{status_flags: ^new_flags} =
             CommandFailure.update(state, status_flags: new_flags)
  end

  test "update status_flags invalid value" do
    state =
      CommandFailure.new(
        %Encoding{encoding: :primitive, type: :boolean, value: false, extras: []},
        %Params{
          feedback_value: %Encoding{encoding: :primitive, type: :boolean, value: true, extras: []},
          time_delay: 1,
          time_delay_normal: 2
        }
      )

    assert_raise ArgumentError, fn -> CommandFailure.update(state, status_flags: nil) end
  end
end
