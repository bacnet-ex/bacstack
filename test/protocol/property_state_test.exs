defmodule BACnet.Protocol.PropertyStateTest do
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.PropertyState

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest PropertyState

  test_data = [
    {"boolean value false", :boolean_value, false, <<0>>, []},
    {"boolean value true", :boolean_value, true, <<1>>, []},
    {"binary value false", :binary_value, false, <<0>>, []},
    {"binary value true", :binary_value, true, <<1>>, []},
    {"event type", :event_type, :change_of_value, <<2>>, []},
    {"polarity", :polarity, :normal, <<0>>, []},
    {"program change", :program_change, :load, <<1>>, []},
    {"program state", :program_state, :running, <<2>>, []},
    {"reason for halt", :reason_for_halt, :internal, <<2>>, []},
    {"reliability", :reliability, :no_sensor, <<1>>, []},
    {"state", :state, :normal, <<0>>, []},
    {"system status", :system_status, :non_operational, <<4>>, []},
    {"engineering units", :units, :percent, <<98>>, []},
    {"unsigned value", :unsigned_value, 91, <<91>>, []},
    {"life safety mode", :life_safety_mode, :on, <<1>>, []},
    {"life safety state", :life_safety_state, :active, <<7>>, []},
    {"restart reason", :restart_reason, :warmstart, <<2>>, []},
    {"door alarm state", :door_alarm_state, :alarm, <<1>>, []},
    {"action", :action, :direct, <<0>>, []},
    {"door secured status", :door_secured_status, :unknown, <<2>>, []},
    {"door status", :door_status, :closed, <<0>>, []},
    {"door value", :door_value, :unlock, <<1>>, []},
    {"file access method", :file_access_method, :stream_access, <<1>>, []},
    {"lock status", :lock_status, :unlocked, <<1>>, []},
    {"life safety operation", :life_safety_operation, :reset, <<4>>, []},
    {"maintenance", :maintenance, :periodic_test, <<1>>, []},
    {"node type", :node_type, :device, <<3>>, []},
    {"notify type", :notify_type, :alarm, <<0>>, []},
    {"security level", :security_level, :signed, <<2>>, []},
    {"shed state", :shed_state, :shed_compliant, <<2>>, []},
    {"silenced state", :silenced_state, :all_silenced, <<3>>, []},
    {"backup state", :backup_state, :idle, <<0>>, []},
    {"write status", :write_status, :successful, <<2>>, []},
    {"lighting in progress", :lighting_in_progress, :fade_active, <<1>>, []},
    {"lighting operation", :lighting_operation, :fade_to, <<1>>, []},
    {"lighting transition", :lighting_transition, :ramp, <<2>>, []},
    {"integer value", :integer_value, 42, <<42>>, []}
  ]

  for {description, type_data, encode_data, raw_decode_data, encode_opts} <- test_data do
    decode_data = [
      {:tagged,
       {Constants.by_name!(:property_state, type_data), raw_decode_data,
        byte_size(raw_decode_data)}}
    ]

    test "decode #{description}" do
      assert {:ok,
              {%PropertyState{
                 type: unquote(type_data),
                 value: unquote(Macro.escape(encode_data))
               }, []}} = PropertyState.parse(unquote(Macro.escape(decode_data)))
    end

    test "decode invalid #{description}" do
      assert {:error, :invalid_data} =
               PropertyState.parse([
                 {:tagged, {Constants.by_name!(:property_state, unquote(type_data)), <<>>, 0}}
               ])
    end

    unless encode_opts[:skip_encode] do
      test "encode #{description}" do
        assert {:ok, unquote(Macro.escape(decode_data))} =
                 PropertyState.encode(
                   %PropertyState{
                     type: unquote(type_data),
                     value: unquote(Macro.escape(encode_data))
                   },
                   unquote(encode_opts)
                 )
      end
    end

    test "valid #{description}" do
      assert true ==
               PropertyState.valid?(%PropertyState{
                 type: unquote(type_data),
                 value: unquote(Macro.escape(encode_data))
               })

      assert false ==
               PropertyState.valid?(%PropertyState{
                 type: unquote(type_data),
                 value: if(is_boolean(unquote(Macro.escape(encode_data))), do: 1, else: false)
               })
    end
  end

  test "decode property state empty list" do
    assert {:error, :invalid_tags} = PropertyState.parse([])
  end

  test "decode unknown property state" do
    assert {:error, :not_supported} = PropertyState.parse([{:tagged, {999_999, <<>>, 0}}])
  end

  test "encode unknown property state" do
    assert {:error, :not_supported} =
             PropertyState.encode(%PropertyState{type: :hello, value: :word})
  end

  test_data_unsupported = [
    {"access event", :access_event},
    {"zone occupancy state", :zone_occupancy_state},
    {"access credential disable reason", :access_credential_disable_reason},
    {"access credential disable", :access_credential_disable},
    {"authentication status", :authentication_status}
  ]

  for {description, type_data} <- test_data_unsupported do
    decode_data = [{:tagged, {Constants.by_name!(:property_state, type_data), <<1>>, 1}}]

    test "decode #{description}" do
      assert {:error, :not_supported} = PropertyState.parse(unquote(Macro.escape(decode_data)))
    end
  end
end
