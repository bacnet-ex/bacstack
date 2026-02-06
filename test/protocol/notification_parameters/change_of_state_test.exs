defmodule BACnet.Protocol.NotificationParameters.ChangeOfStateTest do
  alias BACnet.BeamTypes
  alias BACnet.Protocol.NotificationParameters
  alias BACnet.Protocol.NotificationParameters.ChangeOfState
  alias BACnet.Protocol.PropertyState
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest ChangeOfState

  defmacrop inline_call(exec) do
    {value, _bind} = Code.eval_quoted(exec, [], __CALLER__)

    quote generated: true do
      unquote(Macro.escape(value))
    end
  end

  test "create struct by hand is valid according to typespec" do
    assert true ==
             BeamTypes.check_type({:struct, ChangeOfState}, %ChangeOfState{
               new_state: %PropertyState{type: :boolean_value, value: false},
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "get tag number" do
    assert 1 = ChangeOfState.get_tag_number()
  end

  test "encode" do
    assert {:ok,
            {:constructed,
             {1,
              [
                constructed: {0, {:tagged, {0, <<0>>, 1}}, 0},
                tagged: {1, <<4, 0>>, 2}
              ],
              0}}} =
             NotificationParameters.encode(%ChangeOfState{
               new_state: %PropertyState{type: :boolean_value, value: false},
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode failure 1" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%ChangeOfState{
               new_state: false,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode failure 2" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%ChangeOfState{
               new_state: %PropertyState{type: :boolean_value, value: false},
               status_flags: {false}
             })
  end

  test "encode invalid data" do
    assert {:error, :not_supported} =
             NotificationParameters.encode(%ChangeOfState{
               new_state: %PropertyState{type: nil, value: false},
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "decode" do
    assert {:ok,
            %ChangeOfState{
              new_state: %PropertyState{type: :boolean_value, value: false},
              status_flags: inline_call(StatusFlags.from_bitstring({false, false, false, false}))
            }} =
             NotificationParameters.parse(
               {:constructed,
                {1,
                 [
                   constructed: {0, {:tagged, {0, <<0>>, 1}}, 0},
                   tagged: {1, <<4, 0>>, 2}
                 ], 0}}
             )
  end

  test "decode invalid" do
    assert {:error, :invalid_notification_values} =
             NotificationParameters.parse(
               {:constructed,
                {1,
                 [
                   constructed: {0, [tagged: {0, <<0>>, 1}], 0}
                 ], 0}}
             )
  end

  test "decode invalid data" do
    assert {:error, :invalid_data} =
             NotificationParameters.parse(
               {:constructed,
                {1,
                 [
                   constructed: {0, {:tagged, {0, <<>>, 0}}, 0},
                   tagged: {1, <<4, 0>>, 2}
                 ], 0}}
             )
  end

  test "decode assert valid status flags bits count" do
    assert {:error, :invalid_notification_values} =
             NotificationParameters.parse(
               {:constructed,
                {1,
                 [
                   constructed: {0, {:tagged, {0, <<0>>, 1}}, 0},
                   tagged: {1, <<5, 0>>, 2}
                 ], 0}}
             )
  end
end
