defmodule BACnet.Protocol.NotificationParameters.DoubleOutOfRangeTest do
  alias BACnet.Internal
  alias BACnet.Protocol.NotificationParameters
  alias BACnet.Protocol.NotificationParameters.DoubleOutOfRange
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest DoubleOutOfRange

  defmacrop inline_call(exec) do
    {value, _bind} = Code.eval_quoted(exec, [], __CALLER__)

    quote generated: true do
      unquote(Macro.escape(value))
    end
  end

  test "create struct by hand is valid according to typespec" do
    assert true ==
             Internal.check_type({:struct, DoubleOutOfRange}, %DoubleOutOfRange{
               exceeding_value: 5.0,
               deadband: 1.0,
               exceeded_limit: 1.0,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "get tag number" do
    assert 14 = DoubleOutOfRange.get_tag_number()
  end

  test "encode" do
    assert {:ok,
            {:constructed,
             {14,
              [
                tagged: {0, <<64, 20, 0, 0, 0, 0, 0, 0>>, 8},
                tagged: {1, <<4, 0>>, 2},
                tagged: {2, <<63, 240, 0, 0, 0, 0, 0, 0>>, 8},
                tagged: {3, <<64, 16, 0, 0, 0, 0, 0, 0>>, 8}
              ],
              0}}} =
             NotificationParameters.encode(%DoubleOutOfRange{
               exceeding_value: 5.0,
               deadband: 1.0,
               exceeded_limit: 4.0,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode failure 1" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%DoubleOutOfRange{
               exceeding_value: 5,
               deadband: 1.0,
               exceeded_limit: 1.0,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode failure 2" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%DoubleOutOfRange{
               exceeding_value: 5.0,
               deadband: nil,
               exceeded_limit: 1.0,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode failure 3" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%DoubleOutOfRange{
               exceeding_value: 5.0,
               deadband: 1.0,
               exceeded_limit: false,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode failure 4" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%DoubleOutOfRange{
               exceeding_value: 5.0,
               deadband: 1.0,
               exceeded_limit: 1.0,
               status_flags: {false}
             })
  end

  test "decode" do
    assert {:ok,
            %DoubleOutOfRange{
              exceeding_value: 5.0,
              deadband: 1.0,
              exceeded_limit: 4.0,
              status_flags: inline_call(StatusFlags.from_bitstring({false, false, false, false}))
            }} =
             NotificationParameters.parse(
               {:constructed,
                {14,
                 [
                   tagged: {0, <<64, 20, 0, 0, 0, 0, 0, 0>>, 8},
                   tagged: {1, <<4, 0>>, 2},
                   tagged: {2, <<63, 240, 0, 0, 0, 0, 0, 0>>, 8},
                   tagged: {3, <<64, 16, 0, 0, 0, 0, 0, 0>>, 8}
                 ], 0}}
             )
  end

  test "decode invalid" do
    assert {:error, :invalid_notification_values} =
             NotificationParameters.parse(
               {:constructed,
                {14,
                 [
                   tagged: {0, <<6, 128>>, 4}
                 ], 0}}
             )
  end

  test "decode invalid data" do
    assert {:error, :invalid_data} =
             NotificationParameters.parse(
               {:constructed,
                {14,
                 [
                   tagged: {0, <<>>, 0},
                   tagged: {1, <<4, 0>>, 2},
                   tagged: {2, <<63, 240, 0, 0, 0, 0, 0, 0>>, 8},
                   tagged: {3, <<64, 16, 0, 0, 0, 0, 0, 0>>, 8}
                 ], 0}}
             )
  end

  test "decode assert valid status flags bits count" do
    assert {:error, :invalid_notification_values} =
             NotificationParameters.parse(
               {:constructed,
                {14,
                 [
                   tagged: {0, <<64, 20, 0, 0, 0, 0, 0, 0>>, 8},
                   tagged: {1, <<5, 0>>, 2},
                   tagged: {2, <<64, 16, 0, 0, 0, 0, 0, 0>>, 8},
                   tagged: {3, <<64, 16, 0, 0, 0, 0, 0, 0>>, 8}
                 ], 0}}
             )
  end
end
