defmodule BACnet.Protocol.NotificationParameters.CommandFailureTest do
  alias BACnet.BeamTypes
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.NotificationParameters
  alias BACnet.Protocol.NotificationParameters.CommandFailure
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest CommandFailure

  defmacrop inline_call(exec) do
    {value, _bind} = Code.eval_quoted(exec, [], __CALLER__)

    quote generated: true do
      unquote(Macro.escape(value))
    end
  end

  test "create struct by hand is valid according to typespec" do
    assert true ==
             BeamTypes.check_type({:struct, CommandFailure}, %CommandFailure{
               command_value: Encoding.create!({:boolean, true}),
               feedback_value: Encoding.create!({:boolean, true}),
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "get tag number" do
    assert 3 = CommandFailure.get_tag_number()
  end

  test "encode" do
    assert {:ok,
            {:constructed,
             {3,
              [
                constructed: {0, {:boolean, true}, 0},
                tagged: {1, <<4, 192>>, 2},
                constructed: {2, {:boolean, true}, 0}
              ],
              0}}} =
             NotificationParameters.encode(%CommandFailure{
               command_value: Encoding.create!({:boolean, true}),
               feedback_value: Encoding.create!({:boolean, true}),
               status_flags: StatusFlags.from_bitstring({true, true, false, false})
             })
  end

  test "encode failure 1" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%CommandFailure{
               command_value: false,
               feedback_value: Encoding.create!({:boolean, true}),
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode failure 2" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%CommandFailure{
               command_value: Encoding.create!({:boolean, true}),
               feedback_value: false,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode failure 3" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%CommandFailure{
               command_value: Encoding.create!({:boolean, true}),
               feedback_value: Encoding.create!({:boolean, true}),
               status_flags: {false}
             })
  end

  test "encode invalid data" do
    assert {:error, :invalid_value} =
             NotificationParameters.encode(%CommandFailure{
               command_value: %Encoding{type: nil, encoding: :hello, extras: [], value: nil},
               feedback_value: Encoding.create!({:boolean, true}),
               status_flags: StatusFlags.from_bitstring({true, true, false, false})
             })
  end

  test "decode" do
    assert {:ok,
            %CommandFailure{
              command_value: inline_call(Encoding.create!({:boolean, true})),
              feedback_value: inline_call(Encoding.create!({:boolean, true})),
              status_flags: inline_call(StatusFlags.from_bitstring({true, true, false, false}))
            }} =
             NotificationParameters.parse(
               {:constructed,
                {3,
                 [
                   constructed: {0, {:boolean, true}, 1},
                   tagged: {1, <<4, 192>>, 2},
                   constructed: {2, {:boolean, true}, 1}
                 ], 0}}
             )
  end

  test "decode invalid" do
    assert {:error, :invalid_notification_values} =
             NotificationParameters.parse(
               {:constructed,
                {3,
                 [
                   constructed: {0, {:boolean, false}, 1}
                 ], 0}}
             )
  end

  test "decode invalid data" do
    assert {:error, :invalid_data} =
             NotificationParameters.parse(
               {:constructed,
                {3,
                 [
                   constructed: {0, {:boolean, true}, 1},
                   tagged: {1, <<>>, 0},
                   constructed: {2, {:boolean, true}, 1}
                 ], 0}}
             )
  end

  test "decode assert valid status flags bits count" do
    assert {:error, :invalid_notification_values} =
             NotificationParameters.parse(
               {:constructed,
                {3,
                 [
                   constructed: {0, {:boolean, false}, 1},
                   tagged: {1, <<5, 0>>, 2},
                   constructed: {2, {:boolean, false}, 1}
                 ], 0}}
             )
  end
end
