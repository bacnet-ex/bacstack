defmodule BACnet.Protocol.NotificationParameters.ChangeOfCharacterStringTest do
  alias BACnet.BeamTypes
  alias BACnet.Protocol.NotificationParameters
  alias BACnet.Protocol.NotificationParameters.ChangeOfCharacterString
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest ChangeOfCharacterString

  defmacrop inline_call(exec) do
    {value, _bind} = Code.eval_quoted(exec, [], __CALLER__)

    quote generated: true do
      unquote(Macro.escape(value))
    end
  end

  test "create struct by hand is valid according to typespec" do
    assert true ==
             BeamTypes.check_type({:struct, ChangeOfCharacterString}, %ChangeOfCharacterString{
               alarm_value: "hi",
               changed_value: "hello",
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "get tag number" do
    assert 17 = ChangeOfCharacterString.get_tag_number()
  end

  test "encode" do
    assert {:ok,
            {:constructed,
             {17,
              [
                tagged: {0, <<0, 104, 101, 108, 108, 111>>, 6},
                tagged: {1, <<4, 0>>, 2},
                tagged: {2, <<0, 104, 105>>, 3}
              ],
              0}}} =
             NotificationParameters.encode(%ChangeOfCharacterString{
               alarm_value: "hi",
               changed_value: "hello",
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode failure 1" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%ChangeOfCharacterString{
               alarm_value: "",
               changed_value: 5.0,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode failure 2" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%ChangeOfCharacterString{
               alarm_value: "",
               changed_value: "hello",
               status_flags: {false}
             })
  end

  test "encode failure 3" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%ChangeOfCharacterString{
               alarm_value: nil,
               changed_value: "hello",
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "decode" do
    assert {:ok,
            %ChangeOfCharacterString{
              alarm_value: "hi",
              changed_value: "hello",
              status_flags: inline_call(StatusFlags.from_bitstring({false, false, false, false}))
            }} =
             NotificationParameters.parse(
               {:constructed,
                {17,
                 [
                   tagged: {0, <<0, 104, 101, 108, 108, 111>>, 6},
                   tagged: {1, <<4, 0>>, 2},
                   tagged: {2, <<0, 104, 105>>, 3}
                 ], 0}}
             )
  end

  test "decode invalid" do
    assert {:error, :invalid_notification_values} =
             NotificationParameters.parse(
               {:constructed,
                {17,
                 [
                   tagged: {0, <<0, 104, 101, 108, 108, 111>>, 6},
                   tagged: {1, <<4, 0>>, 2}
                 ], 0}}
             )
  end

  test "decode invalid data" do
    assert {:error, :invalid_data} =
             NotificationParameters.parse(
               {:constructed,
                {17,
                 [
                   tagged: {0, <<>>, 0},
                   tagged: {1, <<4, 0>>, 2},
                   tagged: {2, <<0, 104, 105>>, 3}
                 ], 0}}
             )
  end

  test "decode assert valid status flags bits count" do
    assert {:error, :invalid_notification_values} =
             NotificationParameters.parse(
               {:constructed,
                {17,
                 [
                   tagged: {0, <<0, 104, 101, 108, 108, 111>>, 6},
                   tagged: {1, <<5, 0>>, 2}
                 ], 0}}
             )
  end
end
