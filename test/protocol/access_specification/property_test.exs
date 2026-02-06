defmodule PropertyTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.AccessSpecification.Property
  alias BACnet.Protocol.Constants

  require Constants
  use ExUnit.Case, async: true

  @moduletag :application_tags

  doctest Property

  test "decode read access property" do
    assert {:ok,
            {%Property{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: nil
             },
             []}} =
             Property.parse(
               tagged: {0, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1}
             )
  end

  test "decode read access property with numeric identifier" do
    assert {:ok,
            {%Property{
               property_identifier: 526,
               property_array_index: nil,
               property_value: nil
             }, []}} = Property.parse(tagged: {0, <<526::size(16)>>, 2})
  end

  test "decode read access property with array index" do
    assert {:ok,
            {%Property{
               property_identifier: :present_value,
               property_array_index: 1,
               property_value: nil
             },
             []}} =
             Property.parse(
               tagged: {0, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1},
               tagged: {1, <<1>>, 1}
             )
  end

  test "decode read access property with special property all" do
    assert {:ok, {:all, []}} =
             Property.parse(
               tagged: {0, <<Constants.macro_by_name(:property_identifier, :all)>>, 1}
             )
  end

  test "decode read access property with special property required" do
    assert {:ok, {:required, []}} =
             Property.parse(
               tagged: {0, <<Constants.macro_by_name(:property_identifier, :required)>>, 1}
             )
  end

  test "decode read access property with special property optional" do
    assert {:ok, {:optional, []}} =
             Property.parse(
               tagged: {0, <<Constants.macro_by_name(:property_identifier, :optional)>>, 1}
             )
  end

  test "decode write access property" do
    value = Encoding.create!({:boolean, false})

    assert {:ok,
            {%Property{
               property_identifier: :present_value,
               property_array_index: 1,
               property_value: ^value
             },
             []}} =
             Property.parse(
               tagged: {0, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1},
               tagged: {1, <<1>>, 1},
               constructed: {2, {:boolean, false}, 0}
             )
  end

  test "decode invalid access property missing tags" do
    assert {:error, :invalid_tags} = Property.parse([])
  end

  test "decode invalid access property invalid tags" do
    assert {:error, :unknown_tag_encoding} = Property.parse(tagged: {0, <<>>, 0})
  end

  test "encode read access property" do
    assert {:ok,
            [
              tagged: {0, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1}
            ]} =
             Property.encode(%Property{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: nil
             })
  end

  test "encode read access property with numeric identifier" do
    assert {:ok,
            [
              tagged: {0, <<526::size(16)>>, 2}
            ]} =
             Property.encode(%Property{
               property_identifier: 526,
               property_array_index: nil,
               property_value: nil
             })
  end

  test "encode read access property with array index" do
    assert {:ok,
            [
              tagged: {0, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1},
              tagged: {1, <<1>>, 1}
            ]} =
             Property.encode(%Property{
               property_identifier: :present_value,
               property_array_index: 1,
               property_value: nil
             })
  end

  test "encode read access property with special property all" do
    assert {:ok, [tagged: {0, <<Constants.macro_by_name(:property_identifier, :all)>>, 1}]} =
             Property.encode(:all)
  end

  test "encode read access property with special property required" do
    assert {:ok,
            [
              tagged: {0, <<Constants.macro_by_name(:property_identifier, :required)>>, 1}
            ]} = Property.encode(:required)
  end

  test "encode read access property with special property optional" do
    assert {:ok,
            [
              tagged: {0, <<Constants.macro_by_name(:property_identifier, :optional)>>, 1}
            ]} = Property.encode(:optional)
  end

  test "encode write access property" do
    assert {:ok,
            [
              tagged: {0, <<Constants.macro_by_name(:property_identifier, :present_value)>>, 1},
              tagged: {1, <<1>>, 1},
              constructed: {2, {:boolean, false}, 0}
            ]} =
             Property.encode(%Property{
               property_identifier: :present_value,
               property_array_index: 1,
               property_value: Encoding.create!({:boolean, false})
             })
  end

  test "encode access property invalid atom" do
    assert {:error, :invalid_value} =
             Property.encode(%Property{
               property_identifier: 6.9,
               property_array_index: nil,
               property_value: nil
             })
  end

  test "encode access property invalid array index" do
    assert {:error, :invalid_value} =
             Property.encode(%Property{
               property_identifier: :present_value,
               property_array_index: :hello,
               property_value: nil
             })
  end

  test "valid access property" do
    assert true ==
             Property.valid?(%Property{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: nil
             })

    assert true ==
             Property.valid?(%Property{
               property_identifier: 521,
               property_array_index: nil,
               property_value: nil
             })

    assert true ==
             Property.valid?(%Property{
               property_identifier: :present_value,
               property_array_index: 1,
               property_value: nil
             })

    assert true ==
             Property.valid?(%Property{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: Encoding.create!({:boolean, false})
             })

    assert true ==
             Property.valid?(%Property{
               property_identifier: :present_value,
               property_array_index: 55,
               property_value: Encoding.create!({:boolean, false})
             })
  end

  test "invalid access property" do
    assert false ==
             Property.valid?(%Property{
               property_identifier: :hello,
               property_array_index: nil,
               property_value: nil
             })

    assert false ==
             Property.valid?(%Property{
               property_identifier: :hello,
               property_array_index: :there,
               property_value: nil
             })

    assert false ==
             Property.valid?(%Property{
               property_identifier: :hello,
               property_array_index: :there,
               property_value: :kenobi
             })
  end
end
