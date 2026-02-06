defmodule BACnet.Protocol.PropertyValueTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.PropertyValue

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest PropertyValue

  defmacrop inline_call(exec) do
    {value, _bind} = Code.eval_quoted(exec, [], __CALLER__)

    quote generated: true do
      unquote(Macro.escape(value))
    end
  end

  test "decode property value" do
    assert {:ok,
            {%PropertyValue{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: inline_call(Encoding.create!({:enumerated, 0})),
               priority: nil
             },
             []}} =
             PropertyValue.parse(
               tagged: {0, "U", 1},
               constructed: {2, {:enumerated, 0}, 0}
             )
  end

  test "decode property value with numeric identifier" do
    assert {:ok,
            {%PropertyValue{
               property_identifier: 512,
               property_array_index: nil,
               property_value: inline_call(Encoding.create!({:enumerated, 0})),
               priority: nil
             },
             []}} =
             PropertyValue.parse(
               tagged: {0, <<512::size(16)>>, 2},
               constructed: {2, {:enumerated, 0}, 0}
             )
  end

  test "decode property value with array index" do
    assert {:ok,
            {%PropertyValue{
               property_identifier: :present_value,
               property_array_index: 20,
               property_value: inline_call(Encoding.create!({:enumerated, 0})),
               priority: nil
             },
             []}} =
             PropertyValue.parse(
               tagged: {0, "U", 1},
               tagged: {1, <<20>>, 1},
               constructed: {2, {:enumerated, 0}, 0}
             )
  end

  test "decode property value with priority" do
    assert {:ok,
            {%PropertyValue{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: inline_call(Encoding.create!({:enumerated, 0})),
               priority: 5
             },
             []}} =
             PropertyValue.parse(
               tagged: {0, "U", 1},
               constructed: {2, {:enumerated, 0}, 0},
               tagged: {3, <<5>>, 1}
             )
  end

  test "decode property value with all" do
    assert {:ok,
            {%PropertyValue{
               property_identifier: :present_value,
               property_array_index: 20,
               property_value: inline_call(Encoding.create!({:enumerated, 0})),
               priority: 5
             },
             []}} =
             PropertyValue.parse(
               tagged: {0, "U", 1},
               tagged: {1, <<20>>, 1},
               constructed: {2, {:enumerated, 0}, 0},
               tagged: {3, <<5>>, 1}
             )
  end

  test "decode property value missing pattern error" do
    assert {:error, :invalid_tags} =
             PropertyValue.parse(
               tagged: {1, "U", 1},
               constructed: {2, {:enumerated, 1}, 0}
             )
  end

  test "decode property value error" do
    assert {:error, :invalid_data} = PropertyValue.parse(tagged: {0, "", 1})
  end

  test "decode all property values" do
    assert {:ok,
            [
              %PropertyValue{
                property_identifier: :present_value,
                property_array_index: nil,
                property_value: inline_call(Encoding.create!({:enumerated, 1})),
                priority: nil
              },
              %PropertyValue{
                property_identifier: :present_value,
                property_array_index: nil,
                property_value: inline_call(Encoding.create!({:enumerated, 2})),
                priority: nil
              },
              %PropertyValue{
                property_identifier: :present_value,
                property_array_index: nil,
                property_value: inline_call(Encoding.create!({:enumerated, 3})),
                priority: nil
              }
            ]} =
             PropertyValue.parse_all(
               tagged: {0, "U", 1},
               constructed: {2, {:enumerated, 1}, 0},
               tagged: {0, "U", 1},
               constructed: {2, {:enumerated, 2}, 0},
               tagged: {0, "U", 1},
               constructed: {2, {:enumerated, 3}, 0}
             )
  end

  test "decode all property values empty error" do
    assert {:error, :invalid_tags} = PropertyValue.parse_all([])
  end

  test "decode all property values midway error" do
    assert {:error, :invalid_tags} =
             PropertyValue.parse_all(
               tagged: {0, "U", 1},
               constructed: {2, {:enumerated, 1}, 0},
               tagged: {1, "U", 1}
             )
  end

  test "encode property value" do
    assert {:ok,
            [
              tagged: {0, "U", 1},
              constructed: {2, {:enumerated, 0}, 0}
            ]} =
             PropertyValue.encode(%PropertyValue{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: Encoding.create!({:enumerated, 0}),
               priority: nil
             })
  end

  test "encode property value numeric identifier" do
    assert {:ok,
            [
              tagged: {0, <<512::size(16)>>, 2},
              constructed: {2, {:enumerated, 0}, 0}
            ]} =
             PropertyValue.encode(%PropertyValue{
               property_identifier: 512,
               property_array_index: nil,
               property_value: Encoding.create!({:enumerated, 0}),
               priority: nil
             })
  end

  test "encode property value with array index" do
    assert {:ok,
            [
              tagged: {0, "U", 1},
              tagged: {1, <<20>>, 1},
              constructed: {2, {:enumerated, 0}, 0}
            ]} =
             PropertyValue.encode(%PropertyValue{
               property_identifier: :present_value,
               property_array_index: 20,
               property_value: Encoding.create!({:enumerated, 0}),
               priority: nil
             })
  end

  test "encode property value with priority" do
    assert {:ok,
            [
              tagged: {0, "U", 1},
              constructed: {2, {:enumerated, 0}, 0},
              tagged: {3, <<5>>, 1}
            ]} =
             PropertyValue.encode(%PropertyValue{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: Encoding.create!({:enumerated, 0}),
               priority: 5
             })
  end

  test "encode property value with all" do
    assert {:ok,
            [
              tagged: {0, "U", 1},
              tagged: {1, <<20>>, 1},
              constructed: {2, {:enumerated, 0}, 0},
              tagged: {3, <<5>>, 1}
            ]} =
             PropertyValue.encode(%PropertyValue{
               property_identifier: :present_value,
               property_array_index: 20,
               property_value: Encoding.create!({:enumerated, 0}),
               priority: 5
             })
  end

  test "encode property value error" do
    assert {:error, :invalid_value} =
             PropertyValue.encode(%PropertyValue{
               property_identifier: -1,
               property_array_index: 20,
               property_value: Encoding.create!({:enumerated, 0}),
               priority: 5
             })
  end

  test "encode all property values" do
    assert {:ok,
            [
              tagged: {0, "U", 1},
              constructed: {2, {:enumerated, 1}, 0},
              tagged: {0, "U", 1},
              constructed: {2, {:enumerated, 2}, 0},
              tagged: {0, "U", 1},
              constructed: {2, {:enumerated, 3}, 0}
            ]} =
             PropertyValue.encode_all([
               %PropertyValue{
                 property_identifier: :present_value,
                 property_array_index: nil,
                 property_value: Encoding.create!({:enumerated, 1}),
                 priority: nil
               },
               %PropertyValue{
                 property_identifier: :present_value,
                 property_array_index: nil,
                 property_value: Encoding.create!({:enumerated, 2}),
                 priority: nil
               },
               %PropertyValue{
                 property_identifier: :present_value,
                 property_array_index: nil,
                 property_value: Encoding.create!({:enumerated, 3}),
                 priority: nil
               }
             ])
  end

  test "encode all property value list empty" do
    assert {:ok, []} = PropertyValue.encode_all([])
  end

  test "encode all property value error" do
    assert {:error, :invalid_value} =
             PropertyValue.encode_all([
               %PropertyValue{
                 property_identifier: -1,
                 property_array_index: 20,
                 property_value: Encoding.create!({:enumerated, 0}),
                 priority: 5
               }
             ])

    assert {:error, :invalid_value} =
             PropertyValue.encode_all([
               %PropertyValue{
                 property_identifier: :present_value,
                 property_array_index: nil,
                 property_value: Encoding.create!({:enumerated, 1}),
                 priority: nil
               },
               %PropertyValue{
                 property_identifier: -1,
                 property_array_index: 20,
                 property_value: Encoding.create!({:enumerated, 0}),
                 priority: 5
               },
               %PropertyValue{
                 property_identifier: :present_value,
                 property_array_index: nil,
                 property_value: Encoding.create!({:enumerated, 1}),
                 priority: nil
               }
             ])
  end

  test "encode all property value invalid list element error" do
    assert {:error, :invalid_list_element} = PropertyValue.encode_all([:hello_there])
  end

  test "valid property value" do
    assert true ==
             PropertyValue.valid?(%PropertyValue{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: Encoding.create!({:enumerated, 1}),
               priority: nil
             })

    assert true ==
             PropertyValue.valid?(%PropertyValue{
               property_identifier: 512,
               property_array_index: nil,
               property_value: Encoding.create!({:enumerated, 1}),
               priority: nil
             })

    assert true ==
             PropertyValue.valid?(%PropertyValue{
               property_identifier: :present_value,
               property_array_index: 5122,
               property_value: Encoding.create!({:enumerated, 1}),
               priority: nil
             })

    assert true ==
             PropertyValue.valid?(%PropertyValue{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: Encoding.create!({:enumerated, 1}),
               priority: 5
             })
  end

  test "invalid property value" do
    assert false ==
             PropertyValue.valid?(%PropertyValue{
               property_identifier: nil,
               property_array_index: nil,
               property_value: Encoding.create!({:enumerated, 1}),
               priority: nil
             })

    assert false ==
             PropertyValue.valid?(%PropertyValue{
               property_identifier: :hello_there,
               property_array_index: nil,
               property_value: Encoding.create!({:enumerated, 1}),
               priority: nil
             })

    assert false ==
             PropertyValue.valid?(%PropertyValue{
               property_identifier: -1,
               property_array_index: nil,
               property_value: Encoding.create!({:enumerated, 1}),
               priority: nil
             })

    assert false ==
             PropertyValue.valid?(%PropertyValue{
               property_identifier: :present_value,
               property_array_index: :hello_there,
               property_value: Encoding.create!({:enumerated, 1}),
               priority: nil
             })

    assert false ==
             PropertyValue.valid?(%PropertyValue{
               property_identifier: :present_value,
               property_array_index: -5,
               property_value: Encoding.create!({:enumerated, 1}),
               priority: nil
             })

    assert false ==
             PropertyValue.valid?(%PropertyValue{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: nil,
               priority: nil
             })

    assert false ==
             PropertyValue.valid?(%PropertyValue{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: :hello_there,
               priority: nil
             })

    assert false ==
             PropertyValue.valid?(%PropertyValue{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: Encoding.create!({:enumerated, 1}),
               priority: 0
             })

    assert false ==
             PropertyValue.valid?(%PropertyValue{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: Encoding.create!({:enumerated, 1}),
               priority: 17
             })

    assert false ==
             PropertyValue.valid?(%PropertyValue{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: Encoding.create!({:enumerated, 1}),
               priority: :hello_there
             })
  end
end
