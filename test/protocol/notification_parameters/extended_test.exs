defmodule BACnet.Protocol.NotificationParameters.ExtendedTest do
  alias BACnet.BeamTypes
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.NotificationParameters
  alias BACnet.Protocol.NotificationParameters.Extended

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest Extended

  defmacrop inline_call(exec) do
    {value, _bind} = Code.eval_quoted(exec, [], __CALLER__)

    quote generated: true do
      unquote(Macro.escape(value))
    end
  end

  test "create struct by hand is valid according to typespec" do
    assert true ==
             BeamTypes.check_type({:struct, Extended}, %Extended{
               vendor_id: 5,
               extended_notification_type: 9,
               parameters: [Encoding.create!({:real, 6.9})]
             })
  end

  test "get tag number" do
    assert 9 = Extended.get_tag_number()
  end

  test "encode" do
    assert {:ok,
            {:constructed,
             {9,
              [
                tagged: {0, <<5>>, 1},
                tagged: {1, <<9>>, 1},
                constructed: {2, [real: 6.9, boolean: false], 0}
              ], 0}}} =
             NotificationParameters.encode(%Extended{
               vendor_id: 5,
               extended_notification_type: 9,
               parameters: [Encoding.create!({:real, 6.9}), Encoding.create!({:boolean, false})]
             })
  end

  test "encode failure 1" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%Extended{
               vendor_id: -1,
               extended_notification_type: 9,
               parameters: [Encoding.create!({:real, 6.9})]
             })
  end

  test "encode failure 2" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%Extended{
               vendor_id: 65_536,
               extended_notification_type: 9,
               parameters: [Encoding.create!({:real, 6.9})]
             })
  end

  test "encode failure 3" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%Extended{
               vendor_id: 1,
               extended_notification_type: -1,
               parameters: [Encoding.create!({:real, 6.9})]
             })
  end

  test "encode failure 4" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%Extended{
               vendor_id: 1,
               extended_notification_type: 9,
               parameters: [nil]
             })
  end

  test "encode failure 5" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%Extended{
               vendor_id: 1,
               extended_notification_type: 9,
               parameters: nil
             })
  end

  test "encode invalid data" do
    assert {:error, :invalid_value} =
             NotificationParameters.encode(%Extended{
               vendor_id: 5,
               extended_notification_type: 9,
               parameters: [%Encoding{type: nil, encoding: :hello, extras: [], value: nil}]
             })
  end

  test "decode" do
    assert {:ok,
            %Extended{
              vendor_id: 5,
              extended_notification_type: 9,
              parameters:
                inline_call([Encoding.create!({:real, 6.9}), Encoding.create!({:boolean, false})])
            }} =
             NotificationParameters.parse(
               {:constructed,
                {9,
                 [
                   tagged: {0, <<5>>, 1},
                   tagged: {1, <<9>>, 1},
                   constructed: {2, [real: 6.9, boolean: false], 0}
                 ], 0}}
             )
  end

  test "decode invalid" do
    assert {:error, :invalid_notification_values} =
             NotificationParameters.parse(
               {:constructed,
                {9,
                 [
                   tagged: {0, <<5>>, 1},
                   tagged: {1, <<1>>, 1}
                 ], 0}}
             )
  end

  test "decode invalid data" do
    assert {:error, :invalid_data} =
             NotificationParameters.parse(
               {:constructed,
                {9,
                 [
                   tagged: {0, <<>>, 0},
                   tagged: {1, <<9>>, 1},
                   constructed: {2, [real: 6.9, boolean: false], 0}
                 ], 0}}
             )
  end
end
