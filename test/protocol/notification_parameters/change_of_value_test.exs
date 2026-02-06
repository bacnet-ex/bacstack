defmodule BACnet.Protocol.NotificationParameters.ChangeOfValueTest do
  alias BACnet.BeamTypes
  alias BACnet.Protocol.NotificationParameters
  alias BACnet.Protocol.NotificationParameters.ChangeOfValue
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest ChangeOfValue

  defmacrop inline_call(exec) do
    {value, _bind} = Code.eval_quoted(exec, [], __CALLER__)

    quote generated: true do
      unquote(Macro.escape(value))
    end
  end

  test "create struct by hand is valid according to typespec" do
    assert true ==
             BeamTypes.check_type({:struct, ChangeOfValue}, %ChangeOfValue{
               changed_bits: nil,
               changed_value: 5.0,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })

    assert true ==
             BeamTypes.check_type({:struct, ChangeOfValue}, %ChangeOfValue{
               changed_bits: {true, true},
               changed_value: nil,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "get tag number" do
    assert 2 = ChangeOfValue.get_tag_number()
  end

  test "encode bits" do
    assert {:ok,
            {:constructed,
             {2,
              [
                constructed: {0, {:tagged, {0, <<6, 192>>, 2}}, 0},
                tagged: {1, <<4, 0>>, 2}
              ],
              0}}} =
             NotificationParameters.encode(%ChangeOfValue{
               changed_bits: {true, true},
               changed_value: nil,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode value" do
    assert {:ok,
            {:constructed,
             {2,
              [
                constructed: {0, {:tagged, {1, <<64, 160, 0, 0>>, 4}}, 0},
                tagged: {1, <<4, 0>>, 2}
              ],
              0}}} =
             NotificationParameters.encode(%ChangeOfValue{
               changed_bits: nil,
               changed_value: 5.0,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode failure 1" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%ChangeOfValue{
               changed_bits: false,
               changed_value: nil,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode failure 2" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%ChangeOfValue{
               changed_bits: nil,
               changed_value: 5,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode failure 3" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%ChangeOfValue{
               changed_bits: 1,
               changed_value: 5.0,
               status_flags: StatusFlags.from_bitstring({false, false, false, false})
             })
  end

  test "encode failure 4" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%ChangeOfValue{
               changed_bits: 1,
               changed_value: nil,
               status_flags: {false}
             })
  end

  test "decode bits" do
    assert {:ok,
            %ChangeOfValue{
              changed_bits: {true, true},
              changed_value: nil,
              status_flags: inline_call(StatusFlags.from_bitstring({false, false, false, false}))
            }} =
             NotificationParameters.parse(
               {:constructed,
                {2,
                 [
                   constructed: {0, {:tagged, {0, <<6, 192>>, 2}}, 0},
                   tagged: {1, <<4, 0>>, 2}
                 ], 0}}
             )
  end

  test "decode value" do
    assert {:ok,
            %ChangeOfValue{
              changed_bits: nil,
              changed_value: 5.0,
              status_flags: inline_call(StatusFlags.from_bitstring({false, false, false, false}))
            }} =
             NotificationParameters.parse(
               {:constructed,
                {2,
                 [
                   constructed: {0, {:tagged, {1, <<64, 160, 0, 0>>, 4}}, 0},
                   tagged: {1, <<4, 0>>, 2}
                 ], 0}}
             )
  end

  test "decode invalid" do
    assert {:error, :invalid_notification_values} =
             NotificationParameters.parse(
               {:constructed,
                {2,
                 [
                   constructed: {0, {:tagged, {1, <<5>>, 1}}, 0}
                 ], 0}}
             )
  end

  test "decode invalid data" do
    assert {:error, :invalid_data} =
             NotificationParameters.parse(
               {:constructed,
                {2,
                 [
                   constructed: {0, {:tagged, {1, <<>>, 0}}, 0},
                   tagged: {1, <<4, 0>>, 2}
                 ], 0}}
             )
  end

  test "decode assert valid status flags bits count" do
    assert {:error, :invalid_notification_values} =
             NotificationParameters.parse(
               {:constructed,
                {2,
                 [
                   constructed: {0, {:tagged, {0, <<6, 192>>, 2}}, 0},
                   tagged: {1, <<5, 0>>, 2}
                 ], 0}}
             )
  end
end
