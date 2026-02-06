defmodule BACnet.Protocol.NotificationParameters.ChangeOfBitstringTest do
  alias BACnet.BeamTypes
  alias BACnet.Protocol.NotificationParameters
  alias BACnet.Protocol.NotificationParameters.ChangeOfBitstring
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest ChangeOfBitstring

  defmacrop inline_call(exec) do
    {value, _bind} = Code.eval_quoted(exec, [], __CALLER__)

    quote generated: true do
      unquote(Macro.escape(value))
    end
  end

  test "create struct by hand is valid according to typespec" do
    assert true ==
             BeamTypes.check_type({:struct, ChangeOfBitstring}, %ChangeOfBitstring{
               referenced_bitstring: {true, false},
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "get tag number" do
    assert 0 = ChangeOfBitstring.get_tag_number()
  end

  test "encode" do
    assert {:ok,
            {:constructed,
             {0,
              [
                tagged: {0, <<6, 128>>, 2},
                tagged: {1, <<4, 0>>, 2}
              ],
              0}}} =
             NotificationParameters.encode(%ChangeOfBitstring{
               referenced_bitstring: {true, false},
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode failure 1" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%ChangeOfBitstring{
               referenced_bitstring: 5.0,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode failure 2" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%ChangeOfBitstring{
               referenced_bitstring: {true, false},
               status_flags: {false}
             })
  end

  test "decode" do
    assert {:ok,
            %ChangeOfBitstring{
              referenced_bitstring: {true, false},
              status_flags: inline_call(StatusFlags.from_bitstring({false, false, false, false}))
            }} =
             NotificationParameters.parse(
               {:constructed,
                {0,
                 [
                   tagged: {0, <<6, 128>>, 2},
                   tagged: {1, <<4, 0>>, 2}
                 ], 0}}
             )
  end

  test "decode invalid" do
    assert {:error, :invalid_notification_values} =
             NotificationParameters.parse(
               {:constructed,
                {0,
                 [
                   tagged: {0, <<6, 128>>, 2}
                 ], 0}}
             )
  end

  test "decode invalid data" do
    assert {:error, :invalid_data} =
             NotificationParameters.parse(
               {:constructed,
                {0,
                 [
                   tagged: {0, <<>>, 0},
                   tagged: {1, <<4, 0>>, 2}
                 ], 0}}
             )
  end

  test "decode assert valid status flags bits count" do
    assert {:error, :invalid_notification_values} =
             NotificationParameters.parse(
               {:constructed,
                {0,
                 [
                   tagged: {0, <<6, 128>>, 2},
                   tagged: {1, <<5, 0>>, 2}
                 ], 0}}
             )
  end
end
