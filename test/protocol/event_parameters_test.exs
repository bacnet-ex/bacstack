defmodule BACnet.Protocol.EventParametersTest do
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.EventParameters
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.PropertyState
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest EventParameters

  test "assert tag numbers of event parameters" do
    assert 0 = EventParameters.ChangeOfBitstring.get_tag_number()
    assert 1 = EventParameters.ChangeOfState.get_tag_number()
    assert 2 = EventParameters.ChangeOfValue.get_tag_number()
    assert 3 = EventParameters.CommandFailure.get_tag_number()
    assert 4 = EventParameters.FloatingLimit.get_tag_number()
    assert 5 = EventParameters.OutOfRange.get_tag_number()
    assert 8 = EventParameters.ChangeOfLifeSafety.get_tag_number()
    assert 9 = EventParameters.Extended.get_tag_number()
    assert 10 = EventParameters.BufferReady.get_tag_number()
    assert 11 = EventParameters.UnsignedRange.get_tag_number()
    assert 14 = EventParameters.DoubleOutOfRange.get_tag_number()
    assert 15 = EventParameters.SignedOutOfRange.get_tag_number()
    assert 16 = EventParameters.UnsignedOutOfRange.get_tag_number()
    assert 17 = EventParameters.ChangeOfCharacterString.get_tag_number()
    assert 18 = EventParameters.ChangeOfStatusFlags.get_tag_number()
    assert 20 = EventParameters.None.get_tag_number()
  end

  test "decode event change of bitstring 1 alarm value" do
    tag =
      {:constructed,
       {0,
        [
          tagged: {0, <<0>>, 1},
          tagged: {1, <<5, 128>>, 2},
          constructed: {2, {:bitstring, {false, true, false}}, 0}
        ], 0}}

    expected = %EventParameters.ChangeOfBitstring{
      alarm_values: [{false, true, false}],
      bitmask: {true, false, false},
      time_delay: 0,
      time_delay_normal: nil
    }

    assert {:ok, ^expected} = EventParameters.parse(tag)
    assert {:ok, ^expected} = EventParameters.ChangeOfBitstring.from_app_encoding([tag])
  end

  test "decode event change of bitstring 2 alarm values" do
    tag =
      {:constructed,
       {0,
        [
          tagged: {0, "2", 1},
          tagged: {1, <<5, 128>>, 2},
          constructed: {2, [bitstring: {false, true, false}, bitstring: {false, false, true}], 0}
        ], 0}}

    expected = %EventParameters.ChangeOfBitstring{
      alarm_values: [{false, true, false}, {false, false, true}],
      bitmask: {true, false, false},
      time_delay: 50,
      time_delay_normal: nil
    }

    assert {:ok, ^expected} = EventParameters.parse(tag)
    assert {:ok, ^expected} = EventParameters.ChangeOfBitstring.from_app_encoding([tag])
  end

  test "encode event change of bitstring 1 alarm value" do
    params = %EventParameters.ChangeOfBitstring{
      alarm_values: [{false, true, false}],
      bitmask: {true, false, false},
      time_delay: 0,
      time_delay_normal: nil
    }

    expected =
      {:constructed,
       {0,
        [
          tagged: {0, <<0>>, 1},
          tagged: {1, <<5, 128>>, 2},
          constructed: {2, [{:bitstring, {false, true, false}}], 0}
        ], 0}}

    assert {:ok, ^expected} = EventParameters.encode(params)
    assert {:ok, ^expected} = EventParameters.ChangeOfBitstring.to_app_encoding(params)
  end

  test "encode event change of bitstring 2 alarm values" do
    params = %EventParameters.ChangeOfBitstring{
      alarm_values: [{false, true, false}, {false, false, true}],
      bitmask: {true, false, false},
      time_delay: 50,
      time_delay_normal: nil
    }

    expected =
      {:constructed,
       {0,
        [
          tagged: {0, "2", 1},
          tagged: {1, <<5, 128>>, 2},
          constructed: {2, [bitstring: {false, true, false}, bitstring: {false, false, true}], 0}
        ], 0}}

    assert {:ok, ^expected} = EventParameters.encode(params)
    assert {:ok, ^expected} = EventParameters.ChangeOfBitstring.to_app_encoding(params)
  end

  test "decode event change of state" do
    tag =
      {:constructed,
       {1,
        [
          tagged: {0, "d", 1},
          constructed: {1, [tagged: {7, <<1>>, 1}, tagged: {7, <<4>>, 1}], 0}
        ], 0}}

    expected = %EventParameters.ChangeOfState{
      alarm_values: [
        %PropertyState{
          type: :reliability,
          value: :no_sensor
        },
        %PropertyState{
          type: :reliability,
          value: :open_loop
        }
      ],
      time_delay: 100,
      time_delay_normal: nil
    }

    assert {:ok, ^expected} = EventParameters.parse(tag)
    assert {:ok, ^expected} = EventParameters.ChangeOfState.from_app_encoding([tag])
  end

  test "encode event change of state" do
    params = %EventParameters.ChangeOfState{
      alarm_values: [
        %PropertyState{
          type: :reliability,
          value: :no_sensor
        },
        %PropertyState{
          type: :reliability,
          value: :open_loop
        }
      ],
      time_delay: 100,
      time_delay_normal: nil
    }

    expected =
      {:constructed,
       {1,
        [
          tagged: {0, "d", 1},
          constructed: {1, [tagged: {7, <<1>>, 1}, tagged: {7, <<4>>, 1}], 0}
        ], 0}}

    assert {:ok, ^expected} = EventParameters.encode(params)
    assert {:ok, ^expected} = EventParameters.ChangeOfState.to_app_encoding(params)
  end

  test "decode event change of value float" do
    tag =
      {:constructed,
       {2, [tagged: {0, "x", 1}, constructed: {1, {:tagged, {1, <<63, 0, 0, 0>>, 4}}, 0}], 0}}

    expected = %EventParameters.ChangeOfValue{
      increment: 0.5,
      bitmask: nil,
      time_delay: 120,
      time_delay_normal: nil
    }

    assert {:ok, ^expected} = EventParameters.parse(tag)
    assert {:ok, ^expected} = EventParameters.ChangeOfValue.from_app_encoding([tag])
  end

  test "encode event change of value float" do
    params = %EventParameters.ChangeOfValue{
      increment: 0.5,
      bitmask: nil,
      time_delay: 120,
      time_delay_normal: nil
    }

    expected =
      {:constructed,
       {2, [tagged: {0, "x", 1}, constructed: {1, {:tagged, {1, <<63, 0, 0, 0>>, 4}}, 0}], 0}}

    assert {:ok, ^expected} = EventParameters.encode(params)
    assert {:ok, ^expected} = EventParameters.ChangeOfValue.to_app_encoding(params)
  end

  test "decode event change of value bitmask" do
    tag =
      {:constructed,
       {2, [tagged: {0, "x", 1}, constructed: {1, {:tagged, {0, <<5, 64>>, 2}}, 0}], 0}}

    expected = %EventParameters.ChangeOfValue{
      increment: nil,
      bitmask: {false, true, false},
      time_delay: 120,
      time_delay_normal: nil
    }

    assert {:ok, ^expected} = EventParameters.parse(tag)
    assert {:ok, ^expected} = EventParameters.ChangeOfValue.from_app_encoding([tag])
  end

  test "encode event change of value bitmask" do
    params = %EventParameters.ChangeOfValue{
      increment: nil,
      bitmask: {false, true, false},
      time_delay: 120,
      time_delay_normal: nil
    }

    expected =
      {:constructed,
       {2, [tagged: {0, "x", 1}, constructed: {1, {:tagged, {0, <<5, 64>>, 2}}, 0}], 0}}

    assert {:ok, ^expected} = EventParameters.encode(params)
    assert {:ok, ^expected} = EventParameters.ChangeOfValue.to_app_encoding(params)
  end

  test "decode event command failure" do
    tag =
      {:constructed,
       {3,
        [
          tagged: {0, "d", 1},
          constructed: {1, [tagged: {0, <<0, 192, 0, 20>>, 4}, tagged: {1, "U", 1}], 0}
        ], 0}}

    expected = %EventParameters.CommandFailure{
      feedback_value: %DeviceObjectPropertyRef{
        device_identifier: nil,
        object_identifier: %ObjectIdentifier{type: :binary_input, instance: 20},
        property_identifier: :present_value,
        property_array_index: nil
      },
      time_delay: 100,
      time_delay_normal: nil
    }

    assert {:ok, ^expected} = EventParameters.parse(tag)
    assert {:ok, ^expected} = EventParameters.CommandFailure.from_app_encoding([tag])
  end

  test "encode event command failure" do
    params = %EventParameters.CommandFailure{
      feedback_value: %DeviceObjectPropertyRef{
        device_identifier: nil,
        object_identifier: %ObjectIdentifier{type: :binary_input, instance: 20},
        property_identifier: :present_value,
        property_array_index: nil
      },
      time_delay: 100,
      time_delay_normal: nil
    }

    expected =
      {:constructed,
       {3,
        [
          tagged: {0, "d", 1},
          constructed: {1, [tagged: {0, <<0, 192, 0, 20>>, 4}, tagged: {1, "U", 1}], 0}
        ], 0}}

    assert {:ok, ^expected} = EventParameters.encode(params)
    assert {:ok, ^expected} = EventParameters.CommandFailure.to_app_encoding(params)
  end

  test "decode event floating limit" do
    tag =
      {:constructed,
       {4,
        [
          tagged: {0, <<200>>, 1},
          constructed: {1, [tagged: {0, <<0, 128, 0, 10>>, 4}, tagged: {1, "U", 1}], 0},
          tagged: {2, <<64, 144, 0, 0>>, 4},
          tagged: {3, <<64, 160, 0, 0>>, 4},
          tagged: {4, <<63, 192, 0, 0>>, 4}
        ], 0}}

    expected = %EventParameters.FloatingLimit{
      setpoint: %DeviceObjectPropertyRef{
        device_identifier: nil,
        object_identifier: %ObjectIdentifier{type: :analog_value, instance: 10},
        property_identifier: :present_value,
        property_array_index: nil
      },
      low_diff_limit: 4.5,
      high_diff_limit: 5.0,
      deadband: 1.5,
      time_delay: 200,
      time_delay_normal: nil
    }

    assert {:ok, ^expected} = EventParameters.parse(tag)
    assert {:ok, ^expected} = EventParameters.FloatingLimit.from_app_encoding([tag])
  end

  test "encode event floating limit" do
    params = %EventParameters.FloatingLimit{
      setpoint: %DeviceObjectPropertyRef{
        device_identifier: nil,
        object_identifier: %ObjectIdentifier{type: :analog_value, instance: 10},
        property_identifier: :present_value,
        property_array_index: nil
      },
      low_diff_limit: 4.5,
      high_diff_limit: 5.0,
      deadband: 1.5,
      time_delay: 200,
      time_delay_normal: nil
    }

    expected =
      {:constructed,
       {4,
        [
          tagged: {0, <<200>>, 1},
          constructed: {1, [tagged: {0, <<0, 128, 0, 10>>, 4}, tagged: {1, "U", 1}], 0},
          tagged: {2, <<64, 144, 0, 0>>, 4},
          tagged: {3, <<64, 160, 0, 0>>, 4},
          tagged: {4, <<63, 192, 0, 0>>, 4}
        ], 0}}

    assert {:ok, ^expected} = EventParameters.encode(params)
    assert {:ok, ^expected} = EventParameters.FloatingLimit.to_app_encoding(params)
  end

  test "decode event out of range" do
    tag =
      {:constructed,
       {5,
        [
          tagged: {0, "d", 1},
          tagged: {1, <<63, 192, 0, 0>>, 4},
          tagged: {2, <<64, 32, 0, 0>>, 4},
          tagged: {3, <<63, 128, 0, 0>>, 4}
        ], 0}}

    expected = %EventParameters.OutOfRange{
      low_limit: 1.5,
      high_limit: 2.5,
      deadband: 1.0,
      time_delay: 100,
      time_delay_normal: nil
    }

    assert {:ok, ^expected} = EventParameters.parse(tag)
    assert {:ok, ^expected} = EventParameters.OutOfRange.from_app_encoding([tag])
  end

  test "encode event out of range" do
    params = %EventParameters.OutOfRange{
      low_limit: 1.5,
      high_limit: 2.5,
      deadband: 1.0,
      time_delay: 100,
      time_delay_normal: nil
    }

    expected =
      {:constructed,
       {5,
        [
          tagged: {0, "d", 1},
          tagged: {1, <<63, 192, 0, 0>>, 4},
          tagged: {2, <<64, 32, 0, 0>>, 4},
          tagged: {3, <<63, 128, 0, 0>>, 4}
        ], 0}}

    assert {:ok, ^expected} = EventParameters.encode(params)
    assert {:ok, ^expected} = EventParameters.OutOfRange.to_app_encoding(params)
  end

  # TODO: Event Parameter 8+9 (6 = Complex Event Type, 7 unused)

  test "decode event buffer ready" do
    tag = {:constructed, {10, [tagged: {0, <<192>>, 1}, tagged: {1, <<0>>, 1}], 0}}

    expected = %EventParameters.BufferReady{
      threshold: 192,
      previous_count: 0
    }

    assert {:ok, ^expected} = EventParameters.parse(tag)
    assert {:ok, ^expected} = EventParameters.BufferReady.from_app_encoding([tag])
  end

  test "encode event buffer ready" do
    params = %EventParameters.BufferReady{
      threshold: 192,
      previous_count: 0
    }

    expected = {:constructed, {10, [tagged: {0, <<192>>, 1}, tagged: {1, <<0>>, 1}], 0}}

    assert {:ok, ^expected} = EventParameters.encode(params)
    assert {:ok, ^expected} = EventParameters.BufferReady.to_app_encoding(params)
  end

  test "decode event unsigned range" do
    tag =
      {:constructed, {11, [tagged: {0, "d", 1}, tagged: {1, <<5>>, 1}, tagged: {2, <<6>>, 1}], 0}}

    expected = %EventParameters.UnsignedRange{
      low_limit: 5,
      high_limit: 6,
      time_delay: 100,
      time_delay_normal: nil
    }

    assert {:ok, ^expected} = EventParameters.parse(tag)
    assert {:ok, ^expected} = EventParameters.UnsignedRange.from_app_encoding([tag])
  end

  test "encode event unsigned range" do
    params = %EventParameters.UnsignedRange{
      low_limit: 5,
      high_limit: 6,
      time_delay: 100,
      time_delay_normal: nil
    }

    expected =
      {:constructed, {11, [tagged: {0, "d", 1}, tagged: {1, <<5>>, 1}, tagged: {2, <<6>>, 1}], 0}}

    assert {:ok, ^expected} = EventParameters.encode(params)
    assert {:ok, ^expected} = EventParameters.UnsignedRange.to_app_encoding(params)
  end

  # TODO: Event Parameter 12+13

  test "decode event double out of range" do
    tag =
      {:constructed,
       {14,
        [
          tagged: {0, "d", 1},
          tagged: {1, <<64, 8, 0, 0, 0, 0, 0, 0>>, 8},
          tagged: {2, <<64, 16, 0, 0, 0, 0, 0, 0>>, 8},
          tagged: {3, <<64, 20, 0, 0, 0, 0, 0, 0>>, 8}
        ], 0}}

    expected = %EventParameters.DoubleOutOfRange{
      low_limit: 3.0,
      high_limit: 4.0,
      deadband: 5.0,
      time_delay: 100,
      time_delay_normal: nil
    }

    assert {:ok, ^expected} = EventParameters.parse(tag)
    assert {:ok, ^expected} = EventParameters.DoubleOutOfRange.from_app_encoding([tag])
  end

  test "encode event double out of range" do
    params = %EventParameters.DoubleOutOfRange{
      low_limit: 3.0,
      high_limit: 4.0,
      deadband: 5.0,
      time_delay: 100,
      time_delay_normal: nil
    }

    expected =
      {:constructed,
       {14,
        [
          tagged: {0, "d", 1},
          tagged: {1, <<64, 8, 0, 0, 0, 0, 0, 0>>, 8},
          tagged: {2, <<64, 16, 0, 0, 0, 0, 0, 0>>, 8},
          tagged: {3, <<64, 20, 0, 0, 0, 0, 0, 0>>, 8}
        ], 0}}

    assert {:ok, ^expected} = EventParameters.encode(params)
    assert {:ok, ^expected} = EventParameters.DoubleOutOfRange.to_app_encoding(params)
  end

  test "decode event signed out of range" do
    tag =
      {:constructed,
       {15,
        [
          tagged: {0, "d", 1},
          tagged: {1, <<2>>, 1},
          tagged: {2, <<3>>, 1},
          tagged: {3, <<4>>, 1}
        ], 0}}

    expected = %EventParameters.SignedOutOfRange{
      low_limit: 2,
      high_limit: 3,
      deadband: 4,
      time_delay: 100,
      time_delay_normal: nil
    }

    assert {:ok, ^expected} = EventParameters.parse(tag)
    assert {:ok, ^expected} = EventParameters.SignedOutOfRange.from_app_encoding([tag])
  end

  test "encode event signed out of range" do
    params = %EventParameters.SignedOutOfRange{
      low_limit: 2,
      high_limit: 3,
      deadband: 4,
      time_delay: 100,
      time_delay_normal: nil
    }

    expected =
      {:constructed,
       {15,
        [
          tagged: {0, "d", 1},
          tagged: {1, <<2>>, 1},
          tagged: {2, <<3>>, 1},
          tagged: {3, <<4>>, 1}
        ], 0}}

    assert {:ok, ^expected} = EventParameters.encode(params)
    assert {:ok, ^expected} = EventParameters.SignedOutOfRange.to_app_encoding(params)
  end

  # --- Failure / error paths ---

  test "from_app_encoding invalid encoding for all types" do
    for module <- [
          EventParameters.BufferReady,
          EventParameters.ChangeOfBitstring,
          EventParameters.ChangeOfCharacterString,
          EventParameters.ChangeOfLifeSafety,
          EventParameters.ChangeOfState,
          EventParameters.ChangeOfStatusFlags,
          EventParameters.ChangeOfValue,
          EventParameters.CommandFailure,
          EventParameters.DoubleOutOfRange,
          EventParameters.Extended,
          EventParameters.FloatingLimit,
          EventParameters.None,
          EventParameters.OutOfRange,
          EventParameters.SignedOutOfRange,
          EventParameters.UnsignedOutOfRange,
          EventParameters.UnsignedRange
        ] do
      assert {:error, :invalid_encoding} = module.from_app_encoding(:not_a_list)
      assert {:error, :invalid_encoding} = module.from_app_encoding([])
      assert {:error, :invalid_encoding} = module.from_app_encoding([:a, :b])
    end
  end

  @dopr %DeviceObjectPropertyRef{
    device_identifier: nil,
    object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1},
    property_identifier: :present_value,
    property_array_index: nil
  }

  @invalid_dopr %DeviceObjectPropertyRef{
    device_identifier: nil,
    object_identifier: %ObjectIdentifier{type: :analog_input, instance: -1},
    property_identifier: :present_value,
    property_array_index: nil
  }

  test "decode invalid tag" do
    assert {:error, :invalid_tag} = EventParameters.parse(:hello)
    assert {:error, :invalid_tag} = EventParameters.parse({:constructed, {99, [], 0}})
  end

  test "decode access event not supported" do
    assert {:error, :not_supported_event_type} =
             EventParameters.parse({:constructed, {13, [], 0}})
  end

  test "encode change of bitstring invalid params" do
    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.ChangeOfBitstring{
               alarm_values: [{false, true}],
               bitmask: {true, false},
               time_delay: -1,
               time_delay_normal: nil
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.ChangeOfBitstring{
               alarm_values: :not_a_list,
               bitmask: {true},
               time_delay: 0,
               time_delay_normal: nil
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.ChangeOfBitstring{
               alarm_values: [false],
               bitmask: {true},
               time_delay: 0,
               time_delay_normal: nil
             })
  end

  test "decode change of bitstring invalid structure" do
    assert {:error, :invalid_event_values} =
             EventParameters.parse({:constructed, {0, [], 0}})
  end

  test "decode change of bitstring invalid data" do
    assert {:error, :invalid_data} =
             EventParameters.parse(
               {:constructed,
                {0,
                 [
                   tagged: {0, <<>>, 0},
                   tagged: {1, <<5, 128>>, 2},
                   constructed: {2, {:bitstring, {false, true, false}}, 0}
                 ], 0}}
             )
  end

  test "decode change of bitstring invalid alarm values" do
    assert {:error, :invalid_alarm_values_parameter} =
             EventParameters.parse(
               {:constructed,
                {0,
                 [
                   tagged: {0, <<0>>, 1},
                   tagged: {1, <<5, 128>>, 2},
                   constructed: {2, [{:unsigned_integer, 1}], 0}
                 ], 0}}
             )
  end

  test "encode change of state invalid params" do
    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.ChangeOfState{
               alarm_values: [%PropertyState{type: :boolean_value, value: true}],
               time_delay: -1,
               time_delay_normal: nil
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.ChangeOfState{
               alarm_values: [true],
               time_delay: 0,
               time_delay_normal: nil
             })
  end

  test "encode change of state property state error" do
    assert {:error, {:error, :not_supported}} =
             EventParameters.encode(%EventParameters.ChangeOfState{
               alarm_values: [%PropertyState{type: :hello, value: :word}],
               time_delay: 0,
               time_delay_normal: nil
             })
  end

  test "decode change of state invalid structure" do
    assert {:error, :invalid_event_values} =
             EventParameters.parse({:constructed, {1, [], 0}})
  end

  test "decode change of state invalid data" do
    assert {:error, :invalid_data} =
             EventParameters.parse(
               {:constructed,
                {1, [tagged: {0, <<>>, 0}, constructed: {1, [tagged: {0, <<1>>, 1}], 0}], 0}}
             )
  end

  test "decode change of state invalid alarm values" do
    assert {:error, :invalid_alarm_values_parameter} =
             EventParameters.parse(
               {:constructed,
                {1, [tagged: {0, "d", 1}, constructed: {1, [tagged: {0, <<>>, 0}], 0}], 0}}
             )
  end

  test "encode change of value invalid params" do
    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.ChangeOfValue{
               increment: 0.5,
               bitmask: nil,
               time_delay: -1,
               time_delay_normal: nil
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.ChangeOfValue{
               increment: 0.5,
               bitmask: :not_a_tuple,
               time_delay: 0,
               time_delay_normal: nil
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.ChangeOfValue{
               increment: :not_a_float,
               bitmask: nil,
               time_delay: 0,
               time_delay_normal: nil
             })
  end

  test "decode change of value invalid structure" do
    assert {:error, :invalid_event_values} =
             EventParameters.parse({:constructed, {2, [], 0}})
  end

  test "decode change of value invalid data" do
    assert {:error, :invalid_data} =
             EventParameters.parse(
               {:constructed,
                {2,
                 [tagged: {0, <<>>, 0}, constructed: {1, {:tagged, {1, <<63, 0, 0, 0>>, 4}}, 0}],
                 0}}
             )
  end

  test "decode change of value invalid cov criteria" do
    assert {:error, :invalid_cov_criteria} =
             EventParameters.parse(
               {:constructed,
                {2, [tagged: {0, "x", 1}, constructed: {1, {:tagged, {2, <<1>>, 1}}, 0}], 0}}
             )
  end

  test "encode command failure invalid params" do
    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.CommandFailure{
               feedback_value: @dopr,
               time_delay: -1,
               time_delay_normal: nil
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.CommandFailure{
               feedback_value: :not_a_ref,
               time_delay: 0,
               time_delay_normal: nil
             })
  end

  test "encode command failure device object property ref error" do
    assert {:error, :invalid_value} =
             EventParameters.encode(%EventParameters.CommandFailure{
               feedback_value: @invalid_dopr,
               time_delay: 0,
               time_delay_normal: nil
             })
  end

  test "decode command failure invalid structure" do
    assert {:error, :invalid_event_values} =
             EventParameters.parse({:constructed, {3, [], 0}})
  end

  test "decode command failure invalid data" do
    assert {:error, :invalid_data} =
             EventParameters.parse(
               {:constructed,
                {3,
                 [
                   tagged: {0, <<>>, 0},
                   constructed: {1, [tagged: {0, <<0, 192, 0, 20>>, 4}, tagged: {1, "U", 1}], 0}
                 ], 0}}
             )
  end

  test "decode command failure invalid feedback ref" do
    assert {:error, :invalid_tags} =
             EventParameters.parse(
               {:constructed, {3, [tagged: {0, "d", 1}, constructed: {1, [], 0}], 0}}
             )
  end

  test "encode floating limit invalid params" do
    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.FloatingLimit{
               setpoint: @dopr,
               low_diff_limit: 1.0,
               high_diff_limit: 2.0,
               deadband: 0.5,
               time_delay: -1,
               time_delay_normal: nil
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.FloatingLimit{
               setpoint: :not_a_ref,
               low_diff_limit: 1.0,
               high_diff_limit: 2.0,
               deadband: 0.5,
               time_delay: 0,
               time_delay_normal: nil
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.FloatingLimit{
               setpoint: @dopr,
               low_diff_limit: 1,
               high_diff_limit: 2.0,
               deadband: 0.5,
               time_delay: 0,
               time_delay_normal: nil
             })
  end

  test "encode floating limit device object property ref error" do
    assert {:error, :invalid_value} =
             EventParameters.encode(%EventParameters.FloatingLimit{
               setpoint: @invalid_dopr,
               low_diff_limit: 1.0,
               high_diff_limit: 2.0,
               deadband: 0.5,
               time_delay: 0,
               time_delay_normal: nil
             })
  end

  test "decode floating limit invalid structure" do
    assert {:error, :invalid_event_values} =
             EventParameters.parse({:constructed, {4, [], 0}})
  end

  test "decode floating limit invalid data" do
    assert {:error, :invalid_data} =
             EventParameters.parse(
               {:constructed,
                {4,
                 [
                   tagged: {0, <<>>, 0},
                   constructed: {1, [tagged: {0, <<0, 128, 0, 10>>, 4}, tagged: {1, "U", 1}], 0},
                   tagged: {2, <<64, 144, 0, 0>>, 4},
                   tagged: {3, <<64, 160, 0, 0>>, 4},
                   tagged: {4, <<63, 192, 0, 0>>, 4}
                 ], 0}}
             )
  end

  test "encode out of range invalid params" do
    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.OutOfRange{
               low_limit: 1.0,
               high_limit: 2.0,
               deadband: 0.5,
               time_delay: -1,
               time_delay_normal: nil
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.OutOfRange{
               low_limit: 1,
               high_limit: 2.0,
               deadband: 0.5,
               time_delay: 0,
               time_delay_normal: nil
             })
  end

  test "decode out of range invalid structure" do
    assert {:error, :invalid_event_values} =
             EventParameters.parse({:constructed, {5, [], 0}})
  end

  test "decode out of range invalid data" do
    assert {:error, :invalid_data} =
             EventParameters.parse(
               {:constructed,
                {5,
                 [
                   tagged: {0, <<>>, 0},
                   tagged: {1, <<63, 192, 0, 0>>, 4},
                   tagged: {2, <<64, 32, 0, 0>>, 4},
                   tagged: {3, <<63, 128, 0, 0>>, 4}
                 ], 0}}
             )
  end

  # TODO: Event Parameter 8+9 (6 = Complex Event Type, 7 unused) happy path
  # Failure paths for types without BTL-verified happy path payloads:

  test "encode change of life safety invalid params" do
    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.ChangeOfLifeSafety{
               mode: @dopr,
               alarm_values: [:quiet],
               life_safety_alarm_values: [:active],
               time_delay: -1,
               time_delay_normal: nil
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.ChangeOfLifeSafety{
               mode: :not_a_ref,
               alarm_values: [:quiet],
               life_safety_alarm_values: [:active],
               time_delay: 0,
               time_delay_normal: nil
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.ChangeOfLifeSafety{
               mode: @dopr,
               alarm_values: ["not_atom"],
               life_safety_alarm_values: [:active],
               time_delay: 0,
               time_delay_normal: nil
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.ChangeOfLifeSafety{
               mode: @dopr,
               alarm_values: [:quiet],
               life_safety_alarm_values: [1],
               time_delay: 0,
               time_delay_normal: nil
             })
  end

  test "encode change of life safety unknown life safety alarm value" do
    assert {:error, {:unknown_life_safety_alarm_value, :hello_there}} =
             EventParameters.encode(%EventParameters.ChangeOfLifeSafety{
               mode: @dopr,
               alarm_values: [:quiet],
               life_safety_alarm_values: [:hello_there],
               time_delay: 0,
               time_delay_normal: nil
             })
  end

  test "encode change of life safety unknown alarm value" do
    assert {:error, {:unknown_alarm_value, :hello_there}} =
             EventParameters.encode(%EventParameters.ChangeOfLifeSafety{
               mode: @dopr,
               alarm_values: [:hello_there],
               life_safety_alarm_values: [:quiet],
               time_delay: 0,
               time_delay_normal: nil
             })
  end

  test "encode change of life safety device object property ref error" do
    assert {:error, :invalid_value} =
             EventParameters.encode(%EventParameters.ChangeOfLifeSafety{
               mode: @invalid_dopr,
               alarm_values: [:quiet],
               life_safety_alarm_values: [:active],
               time_delay: 0,
               time_delay_normal: nil
             })
  end

  test "decode change of life safety invalid structure" do
    assert {:error, :invalid_event_values} =
             EventParameters.parse({:constructed, {8, [], 0}})
  end

  test "decode change of life safety invalid data" do
    assert {:error, :invalid_data} =
             EventParameters.parse(
               {:constructed,
                {8,
                 [
                   tagged: {0, <<>>, 0},
                   constructed: {1, [{:enumerated, 0}], 0},
                   constructed: {2, [{:enumerated, 0}], 0},
                   constructed: {3, [tagged: {0, <<0, 0, 0, 1>>, 4}, tagged: {1, "U", 1}], 0}
                 ], 0}}
             )
  end

  test "decode change of life safety unknown life safety alarm value" do
    assert {:error, {:unknown_life_safety_alarm_value, {:enumerated, 255}}} =
             EventParameters.parse(
               {:constructed,
                {8,
                 [
                   tagged: {0, <<0>>, 1},
                   constructed: {1, [{:enumerated, 255}], 0},
                   constructed: {2, [{:enumerated, 0}], 0},
                   constructed: {3, [tagged: {0, <<0, 0, 0, 1>>, 4}, tagged: {1, "U", 1}], 0}
                 ], 0}}
             )
  end

  test "decode change of life safety invalid enumerated in life safety values" do
    assert {:error, :unknown_tag_encoding} =
             EventParameters.parse(
               {:constructed,
                {8,
                 [
                   tagged: {0, <<0>>, 1},
                   constructed: {1, [{:boolean, true}], 0},
                   constructed: {2, [{:enumerated, 0}], 0},
                   constructed: {3, [tagged: {0, <<0, 0, 0, 1>>, 4}, tagged: {1, "U", 1}], 0}
                 ], 0}}
             )
  end

  test "decode change of life safety invalid enumerated in alarm values" do
    assert {:error, :unknown_tag_encoding} =
             EventParameters.parse(
               {:constructed,
                {8,
                 [
                   tagged: {0, <<0>>, 1},
                   constructed: {1, [{:enumerated, 0}], 0},
                   constructed: {2, [{:boolean, true}], 0},
                   constructed: {3, [tagged: {0, <<0, 0, 0, 1>>, 4}, tagged: {1, "U", 1}], 0}
                 ], 0}}
             )
  end

  test "decode change of life safety unknown alarm value" do
    assert {:error, {:unknown_alarm_value, {:enumerated, 255}}} =
             EventParameters.parse(
               {:constructed,
                {8,
                 [
                   tagged: {0, <<0>>, 1},
                   constructed: {1, [{:enumerated, 0}], 0},
                   constructed: {2, [{:enumerated, 255}], 0},
                   constructed: {3, [tagged: {0, <<0, 0, 0, 1>>, 4}, tagged: {1, "U", 1}], 0}
                 ], 0}}
             )
  end

  test "decode change of life safety invalid mode ref" do
    assert {:error, :invalid_tags} =
             EventParameters.parse(
               {:constructed,
                {8,
                 [
                   tagged: {0, <<0>>, 1},
                   constructed: {1, [{:enumerated, 0}], 0},
                   constructed: {2, [{:enumerated, 0}], 0},
                   constructed: {3, [], 0}
                 ], 0}}
             )
  end

  test "encode extended invalid params" do
    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.Extended{
               vendor_id: -1,
               extended_event_type: 1,
               parameters: []
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.Extended{
               vendor_id: 65_536,
               extended_event_type: 1,
               parameters: []
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.Extended{
               vendor_id: 0,
               extended_event_type: -1,
               parameters: []
             })
  end

  test "decode extended invalid structure" do
    assert {:error, :invalid_event_values} =
             EventParameters.parse({:constructed, {9, [], 0}})
  end

  test "decode extended invalid data" do
    assert {:error, :invalid_data} =
             EventParameters.parse(
               {:constructed,
                {9,
                 [
                   tagged: {0, <<>>, 0},
                   tagged: {1, <<1>>, 1},
                   constructed: {2, [], 0}
                 ], 0}}
             )
  end

  test "decode extended invalid vendor id" do
    assert {:error, :invalid_vendor_id_value} =
             EventParameters.parse(
               {:constructed,
                {9,
                 [
                   tagged: {0, <<1, 17, 112>>, 3},
                   tagged: {1, <<1>>, 1},
                   constructed: {2, [], 0}
                 ], 0}}
             )
  end

  test "decode extended invalid extended event type data" do
    assert {:error, :invalid_data} =
             EventParameters.parse(
               {:constructed,
                {9,
                 [
                   tagged: {0, <<0>>, 1},
                   tagged: {1, <<>>, 0},
                   constructed: {2, [], 0}
                 ], 0}}
             )
  end

  test "encode buffer ready invalid params" do
    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.BufferReady{
               threshold: -1,
               previous_count: 0
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.BufferReady{
               threshold: 0x1_0000_0000,
               previous_count: 0
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.BufferReady{
               threshold: 0,
               previous_count: -1
             })
  end

  test "decode buffer ready invalid structure" do
    assert {:error, :invalid_event_values} =
             EventParameters.parse({:constructed, {10, [], 0}})
  end

  test "decode buffer ready invalid data" do
    assert {:error, :invalid_data} =
             EventParameters.parse(
               {:constructed, {10, [tagged: {0, <<>>, 0}, tagged: {1, <<0>>, 1}], 0}}
             )
  end

  test "decode buffer ready invalid previous count" do
    assert {:error, :invalid_previous_count_value} =
             EventParameters.parse(
               {:constructed,
                {10, [tagged: {0, <<192>>, 1}, tagged: {1, <<1, 0, 0, 0, 0>>, 5}], 0}}
             )
  end

  test "encode unsigned range invalid params" do
    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.UnsignedRange{
               low_limit: 5,
               high_limit: 6,
               time_delay: -1,
               time_delay_normal: nil
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.UnsignedRange{
               low_limit: -1,
               high_limit: 6,
               time_delay: 0,
               time_delay_normal: nil
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.UnsignedRange{
               low_limit: 5,
               high_limit: -1,
               time_delay: 0,
               time_delay_normal: nil
             })
  end

  test "decode unsigned range invalid structure" do
    assert {:error, :invalid_event_values} =
             EventParameters.parse({:constructed, {11, [], 0}})
  end

  test "decode unsigned range invalid data" do
    assert {:error, :invalid_data} =
             EventParameters.parse(
               {:constructed,
                {11, [tagged: {0, <<>>, 0}, tagged: {1, <<5>>, 1}, tagged: {2, <<6>>, 1}], 0}}
             )
  end

  test "encode double out of range invalid params" do
    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.DoubleOutOfRange{
               low_limit: 1.0,
               high_limit: 2.0,
               deadband: 0.5,
               time_delay: -1,
               time_delay_normal: nil
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.DoubleOutOfRange{
               low_limit: 1,
               high_limit: 2.0,
               deadband: 0.5,
               time_delay: 0,
               time_delay_normal: nil
             })
  end

  test "decode double out of range invalid structure" do
    assert {:error, :invalid_event_values} =
             EventParameters.parse({:constructed, {14, [], 0}})
  end

  test "decode double out of range invalid data" do
    assert {:error, :invalid_data} =
             EventParameters.parse(
               {:constructed,
                {14,
                 [
                   tagged: {0, <<>>, 0},
                   tagged: {1, <<64, 8, 0, 0, 0, 0, 0, 0>>, 8},
                   tagged: {2, <<64, 16, 0, 0, 0, 0, 0, 0>>, 8},
                   tagged: {3, <<64, 20, 0, 0, 0, 0, 0, 0>>, 8}
                 ], 0}}
             )
  end

  test "encode signed out of range invalid params" do
    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.SignedOutOfRange{
               low_limit: 2,
               high_limit: 3,
               deadband: 4,
               time_delay: -1,
               time_delay_normal: nil
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.SignedOutOfRange{
               low_limit: 2.0,
               high_limit: 3,
               deadband: 4,
               time_delay: 0,
               time_delay_normal: nil
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.SignedOutOfRange{
               low_limit: 2,
               high_limit: 3,
               deadband: -1,
               time_delay: 0,
               time_delay_normal: nil
             })
  end

  test "decode signed out of range invalid structure" do
    assert {:error, :invalid_event_values} =
             EventParameters.parse({:constructed, {15, [], 0}})
  end

  test "decode signed out of range invalid data" do
    assert {:error, :invalid_data} =
             EventParameters.parse(
               {:constructed,
                {15,
                 [
                   tagged: {0, <<>>, 0},
                   tagged: {1, <<2>>, 1},
                   tagged: {2, <<3>>, 1},
                   tagged: {3, <<4>>, 1}
                 ], 0}}
             )
  end

  test "encode unsigned out of range invalid params" do
    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.UnsignedOutOfRange{
               low_limit: 1,
               high_limit: 2,
               deadband: 0,
               time_delay: -1,
               time_delay_normal: nil
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.UnsignedOutOfRange{
               low_limit: -1,
               high_limit: 2,
               deadband: 0,
               time_delay: 0,
               time_delay_normal: nil
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.UnsignedOutOfRange{
               low_limit: 1,
               high_limit: -1,
               deadband: 0,
               time_delay: 0,
               time_delay_normal: nil
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.UnsignedOutOfRange{
               low_limit: 1,
               high_limit: 2,
               deadband: -1,
               time_delay: 0,
               time_delay_normal: nil
             })
  end

  test "decode unsigned out of range invalid structure" do
    assert {:error, :invalid_event_values} =
             EventParameters.parse({:constructed, {16, [], 0}})
  end

  test "decode unsigned out of range invalid data" do
    assert {:error, :invalid_data} =
             EventParameters.parse(
               {:constructed,
                {16,
                 [
                   tagged: {0, <<>>, 0},
                   tagged: {1, <<1>>, 1},
                   tagged: {2, <<2>>, 1},
                   tagged: {3, <<0>>, 1}
                 ], 0}}
             )
  end

  test "decode unsigned out of range invalid later fields" do
    assert {:error, :invalid_data} =
             EventParameters.parse(
               {:constructed,
                {16,
                 [
                   tagged: {0, "d", 1},
                   tagged: {1, <<1>>, 1},
                   tagged: {2, <<2>>, 1},
                   tagged: {3, <<>>, 0}
                 ], 0}}
             )
  end

  test "encode change of character string invalid params" do
    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.ChangeOfCharacterString{
               alarm_values: ["hello"],
               time_delay: -1,
               time_delay_normal: nil
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.ChangeOfCharacterString{
               alarm_values: [123],
               time_delay: 0,
               time_delay_normal: nil
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.ChangeOfCharacterString{
               alarm_values: :not_a_list,
               time_delay: 0,
               time_delay_normal: nil
             })
  end

  test "decode change of character string invalid structure" do
    assert {:error, :invalid_event_values} =
             EventParameters.parse({:constructed, {17, [], 0}})
  end

  test "decode change of character string invalid data" do
    assert {:error, :invalid_data} =
             EventParameters.parse(
               {:constructed,
                {17,
                 [
                   tagged: {0, <<>>, 0},
                   constructed: {1, [{:character_string, "x"}], 0}
                 ], 0}}
             )
  end

  test "encode change of status flags invalid params" do
    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.ChangeOfStatusFlags{
               selected_flags: StatusFlags.from_bitstring({false, false, false, false}),
               time_delay: -1,
               time_delay_normal: nil
             })

    assert {:error, :invalid_params} =
             EventParameters.encode(%EventParameters.ChangeOfStatusFlags{
               selected_flags: {false, false, false, false},
               time_delay: 0,
               time_delay_normal: nil
             })
  end

  test "decode change of status flags invalid structure" do
    assert {:error, :invalid_event_values} =
             EventParameters.parse({:constructed, {18, [], 0}})
  end

  test "decode change of status flags invalid data" do
    assert {:error, :invalid_data} =
             EventParameters.parse(
               {:constructed, {18, [tagged: {0, <<>>, 0}, tagged: {1, <<4, 0>>, 2}], 0}}
             )
  end

  test "decode change of status flags invalid flags data" do
    assert {:error, :invalid_data} =
             EventParameters.parse(
               {:constructed, {18, [tagged: {0, <<0>>, 1}, tagged: {1, <<>>, 0}], 0}}
             )
  end

  test "encode none" do
    params = %EventParameters.None{}
    expected = {:constructed, {20, {:null, nil}, 0}}

    assert {:ok, ^expected} = EventParameters.encode(params)
    assert {:ok, ^expected} = EventParameters.None.to_app_encoding(params)
  end

  test "decode none" do
    tag = {:constructed, {20, {:null, nil}, 0}}
    expected = %EventParameters.None{}

    assert {:ok, ^expected} = EventParameters.parse(tag)
    assert {:ok, ^expected} = EventParameters.None.from_app_encoding([tag])
  end

  test "decode none tagged empty" do
    tag = {:tagged, {20, "", 0}}
    expected = %EventParameters.None{}

    assert {:ok, ^expected} = EventParameters.parse(tag)
    assert {:ok, ^expected} = EventParameters.None.from_app_encoding([tag])
  end

  test "decode none invalid structure" do
    assert {:error, :invalid_event_values} =
             EventParameters.parse({:constructed, {20, [{:boolean, true}], 0}})
  end

  test "valid? event parameters" do
    assert true ==
             EventParameters.valid?(%EventParameters.ChangeOfBitstring{
               alarm_values: [{false, true}],
               bitmask: {true, false},
               time_delay: 0,
               time_delay_normal: nil
             })

    assert false ==
             EventParameters.valid?(%EventParameters.ChangeOfBitstring{
               alarm_values: [{false, true}],
               bitmask: {true, false},
               time_delay: -1,
               time_delay_normal: nil
             })

    assert true ==
             EventParameters.valid?(%EventParameters.OutOfRange{
               low_limit: 1.0,
               high_limit: 2.0,
               deadband: 0.5,
               time_delay: 0,
               time_delay_normal: nil
             })

    assert false ==
             EventParameters.valid?(%EventParameters.OutOfRange{
               low_limit: 1,
               high_limit: 2.0,
               deadband: 0.5,
               time_delay: 0,
               time_delay_normal: nil
             })

    assert true == EventParameters.valid?(%EventParameters.None{})
  end
end
