defmodule BACnet.Protocol.NotificationParameters.ChangeOfReliabilityTest do
  alias BACnet.BeamTypes
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.NotificationParameters
  alias BACnet.Protocol.NotificationParameters.ChangeOfReliability
  alias BACnet.Protocol.PropertyValue
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest ChangeOfReliability

  defmacrop inline_call(exec) do
    {value, _bind} = Code.eval_quoted(exec, [], __CALLER__)

    quote generated: true do
      unquote(Macro.escape(value))
    end
  end

  test "create struct by hand is valid according to typespec" do
    assert true ==
             BeamTypes.check_type({:struct, ChangeOfReliability}, %ChangeOfReliability{
               reliability: :no_fault_detected,
               status_flags: StatusFlags.from_bitstring({false, false, false, false}),
               property_values: []
             })
  end

  test "get tag number" do
    assert 19 = ChangeOfReliability.get_tag_number()
  end

  test "encode" do
    assert {:ok,
            {:constructed,
             {19,
              [
                tagged: {0, <<0>>, 1},
                tagged: {1, <<4, 0>>, 2},
                constructed: {2, [], 0}
              ],
              0}}} =
             NotificationParameters.encode(%ChangeOfReliability{
               reliability: :no_fault_detected,
               status_flags: StatusFlags.from_bitstring({false, false, false, false}),
               property_values: []
             })

    assert {:ok,
            {:constructed,
             {19,
              [
                tagged: {0, <<0>>, 1},
                tagged: {1, <<4, 0>>, 2},
                constructed:
                  {2,
                   [
                     {:tagged, {0, "U", 1}},
                     {:constructed, {2, {:real, 5.0}, 0}}
                   ], 0}
              ],
              0}}} =
             NotificationParameters.encode(%ChangeOfReliability{
               reliability: :no_fault_detected,
               status_flags: StatusFlags.from_bitstring({false, false, false, false}),
               property_values: [
                 %PropertyValue{
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: Encoding.create!({:real, 5.0}),
                   priority: nil
                 }
               ]
             })
  end

  test "encode unknown reliability" do
    assert {:error, {:unknown_reliability, :hello_there}} =
             NotificationParameters.encode(%ChangeOfReliability{
               reliability: :hello_there,
               status_flags: StatusFlags.from_bitstring({false, false, false, false}),
               property_values: []
             })
  end

  test "decode" do
    assert {:ok,
            %ChangeOfReliability{
              reliability: :no_fault_detected,
              status_flags: inline_call(StatusFlags.from_bitstring({false, false, false, false})),
              property_values: []
            }} =
             NotificationParameters.parse(
               {:constructed,
                {19,
                 [
                   tagged: {0, <<0>>, 1},
                   tagged: {1, <<4, 0>>, 2},
                   constructed: {2, [], 0}
                 ], 0}}
             )

    assert {:ok,
            %ChangeOfReliability{
              reliability: :no_fault_detected,
              status_flags: inline_call(StatusFlags.from_bitstring({false, false, false, false})),
              property_values: [
                %PropertyValue{
                  property_identifier: :present_value,
                  property_array_index: nil,
                  property_value: inline_call(Encoding.create!({:real, 5.0})),
                  priority: nil
                }
              ]
            }} =
             NotificationParameters.parse(
               {:constructed,
                {19,
                 [
                   tagged: {0, <<0>>, 1},
                   tagged: {1, <<4, 0>>, 2},
                   constructed:
                     {2,
                      [
                        {:tagged, {0, "U", 1}},
                        {:constructed, {2, {:real, 5.0}, 0}}
                      ], 0}
                 ], 0}}
             )
  end

  test "decode invalid" do
    assert {:error, :invalid_notification_values} =
             NotificationParameters.parse(
               {:constructed,
                {19,
                 [
                   tagged: {0, <<0>>, 1},
                   tagged: {1, <<4, 0>>, 2}
                 ], 0}}
             )
  end

  test "decode invalid data" do
    assert {:error, :invalid_data} =
             NotificationParameters.parse(
               {:constructed,
                {19,
                 [
                   tagged: {0, <<>>, 0},
                   tagged: {1, <<4, 0>>, 2},
                   constructed:
                     {2,
                      [
                        {:tagged, {0, "U", 1}},
                        {:constructed, {2, {:real, 5.0}, 0}}
                      ], 0}
                 ], 0}}
             )
  end

  test "decode assert valid status flags bits count" do
    assert {:error, :invalid_notification_values} =
             NotificationParameters.parse(
               {:constructed,
                {19,
                 [
                   tagged: {0, <<0>>, 1},
                   tagged: {1, <<5, 0>>, 2}
                 ], 0}}
             )
  end

  test "decode unknown reliability" do
    assert {:error, {:unknown_reliability, 255}} =
             NotificationParameters.parse(
               {:constructed,
                {19,
                 [
                   tagged: {0, <<255>>, 1},
                   tagged: {1, <<4, 0>>, 2},
                   constructed: {2, [], 0}
                 ], 0}}
             )
  end
end
