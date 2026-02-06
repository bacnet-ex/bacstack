defmodule BACnet.Protocol.NotificationParameters.ComplexEventTypeTest do
  alias BACnet.BeamTypes
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.NotificationParameters
  alias BACnet.Protocol.NotificationParameters.ComplexEventType
  alias BACnet.Protocol.PropertyValue

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest ComplexEventType

  defmacrop inline_call(exec) do
    {value, _bind} = Code.eval_quoted(exec, [], __CALLER__)

    quote generated: true do
      unquote(Macro.escape(value))
    end
  end

  test "create struct by hand is valid according to typespec" do
    assert true ==
             BeamTypes.check_type({:struct, ComplexEventType}, %ComplexEventType{
               property_values: []
             })
  end

  test "get tag number" do
    assert 6 = ComplexEventType.get_tag_number()
  end

  test "encode" do
    assert {:ok, {:constructed, {6, [], 0}}} =
             NotificationParameters.encode(%ComplexEventType{
               property_values: []
             })

    assert {:ok,
            {:constructed,
             {6,
              [
                {:tagged, {0, "U", 1}},
                {:constructed, {2, {:real, 5.0}, 0}}
              ],
              0}}} =
             NotificationParameters.encode(%ComplexEventType{
               property_values: [
                 %PropertyValue{
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: Encoding.create!({:real, 5.0}),
                   priority: nil
                 }
               ]
             })

    assert {:ok,
            {:constructed,
             {6,
              [
                {:tagged, {0, "U", 1}},
                {:constructed, {2, {:real, 5.0}, 0}},
                {:tagged, {0, "U", 1}},
                {:tagged, {1, <<52>>, 1}},
                {:constructed, {2, {:double, 1.0}, 0}}
              ],
              0}}} =
             NotificationParameters.encode(%ComplexEventType{
               property_values: [
                 %PropertyValue{
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: Encoding.create!({:real, 5.0}),
                   priority: nil
                 },
                 %PropertyValue{
                   property_identifier: :present_value,
                   property_array_index: 52,
                   property_value: Encoding.create!({:double, 1.0}),
                   priority: nil
                 }
               ]
             })
  end

  test "encode failure" do
    assert {:error, :invalid_params} =
             NotificationParameters.encode(%ComplexEventType{
               property_values: 5.0
             })
  end

  test "encode invalid data" do
    assert {:error, :invalid_value} =
             NotificationParameters.encode(%ComplexEventType{
               property_values: [
                 %PropertyValue{
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: %Encoding{type: nil, encoding: :hello, extras: [], value: nil},
                   priority: nil
                 }
               ]
             })
  end

  test "decode" do
    assert {:ok,
            %ComplexEventType{
              property_values: []
            }} = NotificationParameters.parse({:constructed, {6, [], 0}})

    assert {:ok,
            %ComplexEventType{
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
                {6,
                 [
                   {:tagged, {0, "U", 1}},
                   {:constructed, {2, {:real, 5.0}, 0}}
                 ], 0}}
             )

    assert {:ok,
            %ComplexEventType{
              property_values: [
                %PropertyValue{
                  property_identifier: :present_value,
                  property_array_index: nil,
                  property_value: inline_call(Encoding.create!({:real, 5.0})),
                  priority: nil
                },
                %PropertyValue{
                  property_identifier: :present_value,
                  property_array_index: 52,
                  property_value: inline_call(Encoding.create!({:double, 1.0})),
                  priority: nil
                }
              ]
            }} =
             NotificationParameters.parse(
               {:constructed,
                {6,
                 [
                   {:tagged, {0, "U", 1}},
                   {:constructed, {2, {:real, 5.0}, 0}},
                   {:tagged, {0, "U", 1}},
                   {:tagged, {1, <<52>>, 1}},
                   {:constructed, {2, {:double, 1.0}, 0}}
                 ], 0}}
             )
  end

  test "decode invalid" do
    assert {:error, :invalid_tag} =
             NotificationParameters.parse({:constructed, {6, {:null, nil}, 0}})

    assert {:error, :invalid_tags} = NotificationParameters.parse({:constructed, {6, [nil], 0}})
  end

  test "decode invalid data" do
    assert {:error, :unknown_tag_encoding} =
             NotificationParameters.parse(
               {:constructed,
                {6,
                 [
                   {:tagged, {0, <<>>, 0}},
                   {:constructed, {2, {:real, 5.0}, 0}},
                   {:tagged, {0, "U", 1}},
                   {:tagged, {1, <<52>>, 1}},
                   {:constructed, {2, {:double, 1.0}, 0}}
                 ], 0}}
             )
  end
end
