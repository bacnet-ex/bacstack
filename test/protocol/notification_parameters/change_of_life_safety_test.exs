defmodule BACnet.Protocol.NotificationParameters.ChangeOfLifeSafetyTest do
  alias BACnet.BeamTypes
  alias BACnet.Protocol.NotificationParameters
  alias BACnet.Protocol.NotificationParameters.ChangeOfLifeSafety
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest ChangeOfLifeSafety

  defmacrop inline_call(exec) do
    {value, _bind} = Code.eval_quoted(exec, [], __CALLER__)

    quote generated: true do
      unquote(Macro.escape(value))
    end
  end

  test "create struct by hand is valid according to typespec" do
    assert true ==
             BeamTypes.check_type({:struct, ChangeOfLifeSafety}, %ChangeOfLifeSafety{
               operation_expected: :none,
               new_state: :active,
               new_mode: :on,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "get tag number" do
    assert 8 = ChangeOfLifeSafety.get_tag_number()
  end

  test "encode" do
    assert {:ok,
            {:constructed,
             {8,
              [
                tagged: {0, <<7>>, 1},
                tagged: {1, <<1>>, 1},
                tagged: {2, <<4, 0>>, 2},
                tagged: {3, <<0>>, 1}
              ],
              0}}} =
             NotificationParameters.encode(%ChangeOfLifeSafety{
               operation_expected: :none,
               new_state: :active,
               new_mode: :on,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode failure 1" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%ChangeOfLifeSafety{
               operation_expected: :none,
               new_state: :active,
               new_mode: :on,
               status_flags: {false}
             })
  end

  test "encode unknown operation" do
    assert {:error, {:unknown_life_safety_operation, :hello_there}} =
             NotificationParameters.encode(%ChangeOfLifeSafety{
               operation_expected: :hello_there,
               new_state: :active,
               new_mode: :on,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode unknown state" do
    assert {:error, {:unknown_life_safety_state, :hello_there}} =
             NotificationParameters.encode(%ChangeOfLifeSafety{
               operation_expected: :none,
               new_state: :hello_there,
               new_mode: :on,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode unknown mode" do
    assert {:error, {:unknown_life_safety_mode, :hello_there}} =
             NotificationParameters.encode(%ChangeOfLifeSafety{
               operation_expected: :none,
               new_state: :active,
               new_mode: :hello_there,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "decode" do
    assert {:ok,
            %ChangeOfLifeSafety{
              operation_expected: :none,
              new_state: :active,
              new_mode: :on,
              status_flags: inline_call(StatusFlags.from_bitstring({false, false, false, false}))
            }} =
             NotificationParameters.parse(
               {:constructed,
                {8,
                 [
                   tagged: {0, <<7>>, 1},
                   tagged: {1, <<1>>, 1},
                   tagged: {2, <<4, 0>>, 2},
                   tagged: {3, <<0>>, 1}
                 ], 0}}
             )
  end

  test "decode invalid" do
    assert {:error, :invalid_notification_values} =
             NotificationParameters.parse(
               {:constructed,
                {8,
                 [
                   tagged: {0, <<0>>, 1},
                   tagged: {2, <<0>>, 1},
                   tagged: {3, <<0>>, 1}
                 ], 0}}
             )
  end

  test "decode invalid data" do
    assert {:error, :invalid_data} =
             NotificationParameters.parse(
               {:constructed,
                {8,
                 [
                   tagged: {0, <<>>, 0},
                   tagged: {1, <<1>>, 1},
                   tagged: {2, <<4, 0>>, 2},
                   tagged: {3, <<0>>, 1}
                 ], 0}}
             )
  end

  test "decode assert valid status flags bits count" do
    assert {:error, :invalid_notification_values} =
             NotificationParameters.parse(
               {:constructed,
                {8,
                 [
                   tagged: {0, <<7>>, 1},
                   tagged: {1, <<1>>, 1},
                   tagged: {2, <<5, 0>>, 2}
                 ], 0}}
             )
  end

  test "decode unknown operation" do
    assert {:error, {:unknown_life_safety_operation, 255}} =
             NotificationParameters.parse(
               {:constructed,
                {8,
                 [
                   tagged: {0, <<7>>, 1},
                   tagged: {1, <<1>>, 1},
                   tagged: {2, <<4, 0>>, 2},
                   tagged: {3, <<255>>, 1}
                 ], 0}}
             )
  end

  test "decode unknown state" do
    assert {:error, {:unknown_life_safety_state, 255}} =
             NotificationParameters.parse(
               {:constructed,
                {8,
                 [
                   tagged: {0, <<255>>, 1},
                   tagged: {1, <<1>>, 1},
                   tagged: {2, <<4, 0>>, 2},
                   tagged: {3, <<0>>, 1}
                 ], 0}}
             )
  end

  test "decode unknown mode" do
    assert {:error, {:unknown_life_safety_mode, 255}} =
             NotificationParameters.parse(
               {:constructed,
                {8,
                 [
                   tagged: {0, <<7>>, 1},
                   tagged: {1, <<255>>, 1},
                   tagged: {2, <<4, 0>>, 2},
                   tagged: {3, <<0>>, 1}
                 ], 0}}
             )
  end
end
