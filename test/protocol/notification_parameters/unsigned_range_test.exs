defmodule BACnet.Protocol.NotificationParameters.UnsignedRangeTest do
  alias BACnet.BeamTypes
  alias BACnet.Protocol.NotificationParameters
  alias BACnet.Protocol.NotificationParameters.UnsignedRange
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest UnsignedRange

  defmacrop inline_call(exec) do
    {value, _bind} = Code.eval_quoted(exec, [], __CALLER__)

    quote generated: true do
      unquote(Macro.escape(value))
    end
  end

  test "create struct by hand is valid according to typespec" do
    assert true ==
             BeamTypes.check_type({:struct, UnsignedRange}, %UnsignedRange{
               exceeding_value: 5,
               exceeded_limit: 1,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "get tag number" do
    assert 11 = UnsignedRange.get_tag_number()
  end

  test "encode" do
    assert {:ok,
            {:constructed,
             {11,
              [
                tagged: {0, <<5>>, 1},
                tagged: {1, <<4, 0>>, 2},
                tagged: {2, <<4>>, 1}
              ], 0}}} =
             NotificationParameters.encode(%UnsignedRange{
               exceeding_value: 5,
               exceeded_limit: 4,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode failure 1" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%UnsignedRange{
               exceeding_value: 5.0,
               exceeded_limit: 1,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode failure 2" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%UnsignedRange{
               exceeding_value: 5,
               exceeded_limit: 1.0,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode failure 3" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%UnsignedRange{
               exceeding_value: 5,
               exceeded_limit: 1,
               status_flags: {false}
             })
  end

  test "decode" do
    assert {:ok,
            %UnsignedRange{
              exceeding_value: 5,
              exceeded_limit: 4,
              status_flags: inline_call(StatusFlags.from_bitstring({false, false, false, false}))
            }} =
             NotificationParameters.parse(
               {:constructed,
                {11,
                 [
                   tagged: {0, <<5>>, 1},
                   tagged: {1, <<4, 0>>, 2},
                   tagged: {2, <<4>>, 1}
                 ], 0}}
             )
  end

  test "decode invalid" do
    assert {:error, :invalid_notification_values} =
             NotificationParameters.parse(
               {:constructed,
                {11,
                 [
                   tagged: {0, <<6, 128>>, 2}
                 ], 0}}
             )
  end

  test "decode invalid data" do
    assert {:error, :invalid_data} =
             NotificationParameters.parse(
               {:constructed,
                {11,
                 [
                   tagged: {0, <<>>, 0},
                   tagged: {1, <<4, 0>>, 2},
                   tagged: {2, <<4>>, 1}
                 ], 0}}
             )
  end

  test "decode assert valid status flags bits count" do
    assert {:error, :invalid_notification_values} =
             NotificationParameters.parse(
               {:constructed,
                {11,
                 [
                   tagged: {0, <<64, 160, 0, 0>>, 4},
                   tagged: {1, <<5, 0>>, 2},
                   tagged: {2, <<64, 128, 0, 0>>, 4}
                 ], 0}}
             )
  end
end
