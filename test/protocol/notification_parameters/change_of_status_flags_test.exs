defmodule BACnet.Protocol.NotificationParameters.ChangeOfStatusFlagsTest do
  alias BACnet.BeamTypes
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.NotificationParameters
  alias BACnet.Protocol.NotificationParameters.ChangeOfStatusFlags
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest ChangeOfStatusFlags

  defmacrop inline_call(exec) do
    {value, _bind} = Code.eval_quoted(exec, [], __CALLER__)

    quote generated: true do
      unquote(Macro.escape(value))
    end
  end

  test "create struct by hand is valid according to typespec" do
    assert true ==
             BeamTypes.check_type({:struct, ChangeOfStatusFlags}, %ChangeOfStatusFlags{
               present_value: Encoding.create!({:signed_integer, -127}),
               referenced_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "get tag number" do
    assert 18 = ChangeOfStatusFlags.get_tag_number()
  end

  test "encode" do
    assert {:ok,
            {:constructed,
             {18,
              [
                constructed: {0, {:signed_integer, -127}, 0},
                tagged: {1, <<4, 0>>, 2}
              ],
              0}}} =
             NotificationParameters.encode(%ChangeOfStatusFlags{
               present_value: Encoding.create!({:signed_integer, -127}),
               referenced_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode optional" do
    assert {:ok,
            {:constructed,
             {18,
              [
                tagged: {1, <<4, 0>>, 2}
              ],
              0}}} =
             NotificationParameters.encode(%ChangeOfStatusFlags{
               present_value: nil,
               referenced_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode failure 1" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%ChangeOfStatusFlags{
               present_value: false,
               referenced_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode failure 2" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%ChangeOfStatusFlags{
               present_value: Encoding.create!({:signed_integer, -127}),
               referenced_flags: {false}
             })
  end

  test "encode invalid data" do
    assert {:error, :invalid_value} =
             NotificationParameters.encode(%ChangeOfStatusFlags{
               present_value: %Encoding{type: nil, encoding: :hello, extras: [], value: nil},
               referenced_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "decode" do
    assert {:ok,
            %ChangeOfStatusFlags{
              present_value: inline_call(Encoding.create!({:signed_integer, -127})),
              referenced_flags:
                inline_call(StatusFlags.from_bitstring({false, false, false, false}))
            }} =
             NotificationParameters.parse(
               {:constructed,
                {18,
                 [
                   constructed: {0, {:signed_integer, -127}, 0},
                   tagged: {1, <<4, 0>>, 2}
                 ], 0}}
             )
  end

  test "decode optional" do
    assert {:ok,
            %ChangeOfStatusFlags{
              present_value: nil,
              referenced_flags:
                inline_call(StatusFlags.from_bitstring({false, false, false, false}))
            }} =
             NotificationParameters.parse(
               {:constructed,
                {18,
                 [
                   tagged: {1, <<4, 0>>, 2}
                 ], 0}}
             )
  end

  test "decode invalid" do
    assert {:error, :missing_pattern} =
             NotificationParameters.parse(
               {:constructed,
                {18,
                 [
                   tagged: {2, <<4, 0>>, 2}
                 ], 0}}
             )
  end

  test "decode invalid data" do
    assert {:error, :unknown_tag_encoding} =
             NotificationParameters.parse(
               {:constructed,
                {18,
                 [
                   tagged: {1, <<>>, 0}
                 ], 0}}
             )
  end

  test "decode assert valid status flags bits count" do
    assert {:error, :invalid_notification_values} =
             NotificationParameters.parse(
               {:constructed,
                {18,
                 [
                   tagged: {1, <<5, 0>>, 2}
                 ], 0}}
             )
  end
end
