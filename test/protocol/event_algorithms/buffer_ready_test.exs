defmodule BACnet.Protocol.EventAlgorithms.BufferReadyTest do
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.EventAlgorithms.BufferReady
  alias BACnet.Protocol.EventParameters.BufferReady, as: Params
  alias BACnet.Protocol.NotificationParameters.BufferReady, as: Notify
  alias BACnet.Protocol.ObjectIdentifier

  use ExUnit.Case, async: true

  @moduletag :event_algorithms
  @moduletag :protocol_data_structures

  doctest BufferReady

  test "assert tag number of event parameters is correct" do
    assert 10 = Params.get_tag_number()
  end

  test "create new state" do
    assert %BufferReady{} =
             BufferReady.new(
               0,
               %DeviceObjectPropertyRef{
                 object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
                 property_identifier: :log_buffer,
                 property_array_index: nil,
                 device_identifier: nil
               },
               %Params{
                 threshold: 50,
                 previous_count: 0
               }
             )
  end

  test "create new state fails for invalid monitored_value" do
    assert_raise FunctionClauseError, fn ->
      BufferReady.new(
        0.0,
        %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
          property_identifier: :log_buffer,
          property_array_index: nil,
          device_identifier: nil
        },
        %Params{
          threshold: 50,
          previous_count: 0
        }
      )
    end

    assert_raise FunctionClauseError, fn ->
      BufferReady.new(
        -1,
        %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
          property_identifier: :log_buffer,
          property_array_index: nil,
          device_identifier: nil
        },
        %Params{
          threshold: 50,
          previous_count: 0
        }
      )
    end

    assert_raise FunctionClauseError, fn ->
      BufferReady.new(
        4_294_967_296,
        %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
          property_identifier: :log_buffer,
          property_array_index: nil,
          device_identifier: nil
        },
        %Params{
          threshold: 50,
          previous_count: 0
        }
      )
    end
  end

  test "create new state fails for invalid log_buffer" do
    assert_raise FunctionClauseError, fn ->
      BufferReady.new(0, %{}, %Params{
        threshold: 50,
        previous_count: 0
      })
    end
  end

  test "create new state fails for invalid params" do
    assert_raise FunctionClauseError, fn ->
      BufferReady.new(
        0,
        %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
          property_identifier: :log_buffer,
          property_array_index: nil,
          device_identifier: nil
        },
        %{}
      )
    end
  end

  test "execute on same state stays normal" do
    state =
      BufferReady.new(
        0,
        %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
          property_identifier: :log_buffer,
          property_array_index: nil,
          device_identifier: nil
        },
        %Params{
          threshold: 50,
          previous_count: 0
        }
      )

    assert {:no_event, ^state} = BufferReady.execute(state)
    assert {:no_event, ^state} = BufferReady.execute(state)
    assert {:no_event, ^state} = BufferReady.execute(state)
    Process.sleep(1000)
    assert {:no_event, ^state} = BufferReady.execute(state)
    assert {:no_event, ^state} = BufferReady.execute(state)
    assert {:no_event, ^state} = BufferReady.execute(state)
  end

  test "execute on state normal with threshold = 0 does not update" do
    state =
      BufferReady.new(
        0,
        %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
          property_identifier: :log_buffer,
          property_array_index: nil,
          device_identifier: nil
        },
        %Params{
          threshold: 0,
          previous_count: 0
        }
      )

    assert {:no_event, ^state} = BufferReady.execute(state)

    new_state2 = %{state | monitored_value: 231_244_214}

    assert {:no_event, ^new_state2} = BufferReady.execute(new_state2)
    assert {:no_event, ^new_state2} = BufferReady.execute(new_state2)
  end

  test "execute on state normal below threshold does not update" do
    state =
      BufferReady.new(
        0,
        %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
          property_identifier: :log_buffer,
          property_array_index: nil,
          device_identifier: nil
        },
        %Params{
          threshold: 50,
          previous_count: 0
        }
      )

    assert {:no_event, ^state} = BufferReady.execute(state)

    new_state2 = %{state | monitored_value: 49}

    assert {:no_event, ^new_state2} = BufferReady.execute(new_state2)
    assert {:no_event, ^new_state2} = BufferReady.execute(new_state2)
  end

  test "execute on state normal below threshold does not update with previous" do
    state =
      BufferReady.new(
        0,
        %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
          property_identifier: :log_buffer,
          property_array_index: nil,
          device_identifier: nil
        },
        %Params{
          threshold: 50,
          previous_count: 0
        }
      )

    assert {:no_event, ^state} = BufferReady.execute(state)

    new_params = %{state.parameters | previous_count: 423}
    new_state2 = %{state | monitored_value: 450, parameters: new_params}

    assert {:no_event, ^new_state2} = BufferReady.execute(new_state2)
    assert {:no_event, ^new_state2} = BufferReady.execute(new_state2)
  end

  test "execute on state normal on threshold does update" do
    state =
      BufferReady.new(
        0,
        %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
          property_identifier: :log_buffer,
          property_array_index: nil,
          device_identifier: nil
        },
        %Params{
          threshold: 50,
          previous_count: 0
        }
      )

    assert {:no_event, ^state} = BufferReady.execute(state)

    new_state2 = %{state | monitored_value: 50}

    assert {:event, %{current_state: :normal} = new_state2, event} =
             BufferReady.execute(new_state2)

    assert {:no_event, %{current_state: :normal} = _state} =
             BufferReady.execute(new_state2)

    assert %Notify{
             buffer_property: %DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
               property_identifier: :log_buffer,
               property_array_index: nil,
               device_identifier: nil
             },
             previous_notification: 0,
             current_notification: 50
           } =
             event
  end

  test "execute on state normal above threshold does update" do
    state =
      BufferReady.new(
        0,
        %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
          property_identifier: :log_buffer,
          property_array_index: nil,
          device_identifier: nil
        },
        %Params{
          threshold: 50,
          previous_count: 0
        }
      )

    assert {:no_event, ^state} = BufferReady.execute(state)

    new_state2 = %{state | monitored_value: 51}

    assert {:event, %{current_state: :normal} = new_state2, event} =
             BufferReady.execute(new_state2)

    assert {:no_event, %{current_state: :normal} = _state} =
             BufferReady.execute(new_state2)

    assert %Notify{
             buffer_property: %DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
               property_identifier: :log_buffer,
               property_array_index: nil,
               device_identifier: nil
             },
             previous_notification: 0,
             current_notification: 51
           } =
             event
  end

  test "execute on state normal on threshold does update with previous" do
    state =
      BufferReady.new(
        423,
        %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
          property_identifier: :log_buffer,
          property_array_index: nil,
          device_identifier: nil
        },
        %Params{
          threshold: 50,
          previous_count: 423
        }
      )

    assert {:no_event, ^state} = BufferReady.execute(state)

    new_state2 = %{state | monitored_value: 473}

    assert {:event, %{current_state: :normal} = new_state2, event} =
             BufferReady.execute(new_state2)

    assert {:no_event, %{current_state: :normal} = _state} =
             BufferReady.execute(new_state2)

    assert %Notify{
             buffer_property: %DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
               property_identifier: :log_buffer,
               property_array_index: nil,
               device_identifier: nil
             },
             previous_notification: 423,
             current_notification: 473
           } =
             event
  end

  test "execute on state normal with int overflow on threshold does update with previous" do
    state =
      BufferReady.new(
        4_294_967_267,
        %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
          property_identifier: :log_buffer,
          property_array_index: nil,
          device_identifier: nil
        },
        %Params{
          threshold: 50,
          previous_count: 4_294_967_267
        }
      )

    assert {:no_event, ^state} = BufferReady.execute(state)

    new_state2 = %{state | monitored_value: 22}

    assert {:event, %{current_state: :normal} = new_state2, event} =
             BufferReady.execute(new_state2)

    assert {:no_event, %{current_state: :normal} = _state} =
             BufferReady.execute(new_state2)

    assert %Notify{
             buffer_property: %DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
               property_identifier: :log_buffer,
               property_array_index: nil,
               device_identifier: nil
             },
             previous_notification: 4_294_967_267,
             current_notification: 22
           } =
             event
  end

  test "execute on state normal with int overflow above threshold does update with previous" do
    state =
      BufferReady.new(
        4_294_967_267,
        %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
          property_identifier: :log_buffer,
          property_array_index: nil,
          device_identifier: nil
        },
        %Params{
          threshold: 50,
          previous_count: 4_294_967_267
        }
      )

    assert {:no_event, ^state} = BufferReady.execute(state)

    new_state2 = %{state | monitored_value: 88}

    assert {:event, %{current_state: :normal} = new_state2, event} =
             BufferReady.execute(new_state2)

    assert {:no_event, %{current_state: :normal} = _state} =
             BufferReady.execute(new_state2)

    assert %Notify{
             buffer_property: %DeviceObjectPropertyRef{
               object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
               property_identifier: :log_buffer,
               property_array_index: nil,
               device_identifier: nil
             },
             previous_notification: 4_294_967_267,
             current_notification: 88
           } =
             event
  end

  test "update invalid params" do
    state =
      BufferReady.new(
        0,
        %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
          property_identifier: :log_buffer,
          property_array_index: nil,
          device_identifier: nil
        },
        %Params{
          threshold: 50,
          previous_count: 0
        }
      )

    assert_raise ArgumentError, fn -> BufferReady.update(state, [:hello]) end
  end

  test "update unknown key" do
    state =
      BufferReady.new(
        0,
        %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
          property_identifier: :log_buffer,
          property_array_index: nil,
          device_identifier: nil
        },
        %Params{
          threshold: 50,
          previous_count: 0
        }
      )

    assert_raise ArgumentError, fn -> BufferReady.update(state, hello: :there) end
  end

  test "update monitored_value" do
    state =
      BufferReady.new(
        0,
        %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
          property_identifier: :log_buffer,
          property_array_index: nil,
          device_identifier: nil
        },
        %Params{
          threshold: 50,
          previous_count: 0
        }
      )

    assert %BufferReady{monitored_value: 42} =
             BufferReady.update(state, monitored_value: 42)

    assert %BufferReady{monitored_value: 0} =
             BufferReady.update(state, monitored_value: 0)

    assert %BufferReady{monitored_value: 4_294_967_295} =
             BufferReady.update(state, monitored_value: 4_294_967_295)
  end

  test "update monitored_value invalid value" do
    state =
      BufferReady.new(
        0,
        %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
          property_identifier: :log_buffer,
          property_array_index: nil,
          device_identifier: nil
        },
        %Params{
          threshold: 50,
          previous_count: 0
        }
      )

    assert_raise ArgumentError, fn -> BufferReady.update(state, monitored_value: false) end
    assert_raise ArgumentError, fn -> BufferReady.update(state, monitored_value: -1) end

    assert_raise ArgumentError, fn ->
      BufferReady.update(state, monitored_value: 4_294_967_296)
    end
  end

  test "update parameters" do
    state =
      BufferReady.new(
        0,
        %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
          property_identifier: :log_buffer,
          property_array_index: nil,
          device_identifier: nil
        },
        %Params{
          threshold: 50,
          previous_count: 0
        }
      )

    new_params = %Params{
      threshold: 2444,
      previous_count: 153
    }

    assert %BufferReady{parameters: ^new_params} =
             BufferReady.update(state, parameters: new_params)
  end

  test "update parameters invalid value" do
    state =
      BufferReady.new(
        0,
        %DeviceObjectPropertyRef{
          object_identifier: %ObjectIdentifier{type: :trendlog, instance: 0},
          property_identifier: :log_buffer,
          property_array_index: nil,
          device_identifier: nil
        },
        %Params{
          threshold: 50,
          previous_count: 0
        }
      )

    assert_raise ArgumentError, fn -> BufferReady.update(state, parameters: nil) end
  end
end
