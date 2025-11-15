defmodule BACnet.Protocol.PropertyRefTest do
  alias BACnet.Protocol.PropertyRef

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest PropertyRef

  test "decode ref" do
    assert {:ok,
            {%PropertyRef{
               property_identifier: :acked_transitions,
               property_array_index: nil
             }, []}} = PropertyRef.parse(tagged: {0, <<0>>, 1})
  end

  test "decode ref with array index" do
    assert {:ok,
            {%PropertyRef{
               property_identifier: :acked_transitions,
               property_array_index: 250
             },
             []}} =
             PropertyRef.parse(
               tagged: {0, <<0>>, 1},
               tagged: {1, <<250>>, 1}
             )
  end

  test "decode ref unknown property" do
    assert {:ok,
            {%PropertyRef{
               property_identifier: 520,
               property_array_index: nil
             }, []}} = PropertyRef.parse(tagged: {0, <<520::size(16)>>, 2})
  end

  test "decode invalid ref missing pattern" do
    assert {:error, :invalid_tags} = PropertyRef.parse([])
  end

  test "decode invalid ref invalid tag" do
    assert {:error, :invalid_data} = PropertyRef.parse(tagged: {0, <<>>, 1})
  end

  test "encode ref" do
    assert {:ok,
            [
              tagged: {0, <<0>>, 1}
            ]} =
             PropertyRef.encode(%PropertyRef{
               property_identifier: :acked_transitions,
               property_array_index: nil
             })
  end

  test "encode ref with array index" do
    assert {:ok,
            [
              tagged: {0, <<0>>, 1},
              tagged: {1, <<250>>, 1}
            ]} =
             PropertyRef.encode(%PropertyRef{
               property_identifier: :acked_transitions,
               property_array_index: 250
             })
  end

  test "encode ref unknown property" do
    assert {:ok,
            [
              tagged: {0, <<520::size(16)>>, 2}
            ]} =
             PropertyRef.encode(%PropertyRef{
               property_identifier: 520,
               property_array_index: nil
             })
  end

  test "encode invalid ref" do
    assert {:error, :invalid_value} =
             PropertyRef.encode(%PropertyRef{
               property_identifier: 5.0,
               property_array_index: nil
             })
  end

  test "valid ref" do
    assert true ==
             PropertyRef.valid?(%PropertyRef{
               property_identifier: :acked_transitions,
               property_array_index: nil
             })

    assert true ==
             PropertyRef.valid?(%PropertyRef{
               property_identifier: :acked_transitions,
               property_array_index: 250
             })

    assert true ==
             PropertyRef.valid?(%PropertyRef{
               property_identifier: 520,
               property_array_index: nil
             })
  end

  test "invalid ref" do
    assert false ==
             PropertyRef.valid?(%PropertyRef{
               property_identifier: :hello,
               property_array_index: nil
             })

    assert false ==
             PropertyRef.valid?(%PropertyRef{
               property_identifier: 520,
               property_array_index: :hello
             })
  end
end
