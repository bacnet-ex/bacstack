defmodule BACnet.Protocol.ReadAccessResult.ReadResultTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.ReadAccessResult.ReadResult

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest ReadResult

  defmacrop inline_call(exec) do
    {value, _bind} = Code.eval_quoted(exec, [], __CALLER__)

    quote generated: true do
      unquote(Macro.escape(value))
    end
  end

  test "decode read result value" do
    assert {:ok,
            {%ReadResult{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: inline_call(Encoding.create!({:enumerated, 1})),
               error: nil
             }, []}} =
             ReadResult.parse(
               tagged: {2, "U", 1},
               constructed: {4, {:enumerated, 1}, 0}
             )
  end

  test "decode read result value list" do
    # We do this because Elixir is NOT able to add the sign and
    # then yells at US for not adding the sign
    real_val = Encoding.create!({:real, +0.0})

    assert {:ok,
            {%ReadResult{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: [
                 inline_call(Encoding.create!({:enumerated, 1})),
                 ^real_val
               ],
               error: nil
             }, []}} =
             ReadResult.parse(
               tagged: {2, "U", 1},
               constructed: {4, [{:enumerated, 1}, {:real, 0.0}], 0}
             )
  end

  test "decode read result value with array index" do
    assert {:ok,
            {%ReadResult{
               property_identifier: :present_value,
               property_array_index: 2,
               property_value: inline_call(Encoding.create!({:enumerated, 1})),
               error: nil
             }, []}} =
             ReadResult.parse(
               tagged: {2, "U", 1},
               tagged: {3, <<2>>, 1},
               constructed: {4, {:enumerated, 1}, 0}
             )
  end

  test "decode read result error" do
    assert {:ok,
            {%ReadResult{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: nil,
               error: %BACnetError{
                 class: :property,
                 code: 65_535
               }
             }, []}} =
             ReadResult.parse(
               tagged: {2, "U", 1},
               constructed: {5, [enumerated: 2, enumerated: 65_535], 0}
             )
  end

  test "decode read result error with array index" do
    assert {:ok,
            {%ReadResult{
               property_identifier: :present_value,
               property_array_index: 2,
               property_value: nil,
               error: %BACnetError{
                 class: :property,
                 code: 65_535
               }
             }, []}} =
             ReadResult.parse(
               tagged: {2, "U", 1},
               tagged: {3, <<2>>, 1},
               constructed: {5, [enumerated: 2, enumerated: 65_535], 0}
             )
  end

  test "decode read result invalid" do
    assert {:error, :invalid_value_and_error} = ReadResult.parse(tagged: {2, "U", 1})
  end

  test "decode read result error invalid" do
    assert {:error, :invalid_tags} =
             ReadResult.parse(
               tagged: {2, "U", 1},
               constructed: {5, [], 0}
             )
  end

  test "decode read result error invalid both given" do
    assert {:error, :invalid_value_and_error} =
             ReadResult.parse(
               tagged: {2, "U", 1},
               constructed: {4, {:enumerated, 1}, 0},
               constructed: {5, [enumerated: 2, enumerated: 65_535], 0}
             )
  end

  test "encode read result value" do
    assert {:ok,
            [
              tagged: {2, "U", 1},
              constructed: {4, {:enumerated, 1}, 0}
            ]} =
             ReadResult.encode(%ReadResult{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: inline_call(Encoding.create!({:enumerated, 1})),
               error: nil
             })
  end

  test "encode read result value invalid encoding" do
    assert {:error, :invalid_value} =
             ReadResult.encode(%ReadResult{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: %Encoding{encoding: :help, extras: [], type: nil, value: nil},
               error: nil
             })
  end

  test "encode read result value list" do
    assert {:ok,
            [
              tagged: {2, "U", 1},
              constructed: {4, [{:enumerated, 1}, {:real, +0.0}], 0}
            ]} =
             ReadResult.encode(%ReadResult{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: [
                 inline_call(Encoding.create!({:enumerated, 1})),
                 inline_call(Encoding.create!({:real, 0.0}))
               ],
               error: nil
             })
  end

  test "encode read result value list invalid encoding" do
    assert {:error, :invalid_value} =
             ReadResult.encode(%ReadResult{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: [%Encoding{encoding: :help, extras: [], type: nil, value: nil}],
               error: nil
             })
  end

  test "encode read result value with array index" do
    assert {:ok,
            [
              tagged: {2, "U", 1},
              tagged: {3, <<2>>, 1},
              constructed: {4, {:enumerated, 1}, 0}
            ]} =
             ReadResult.encode(%ReadResult{
               property_identifier: :present_value,
               property_array_index: 2,
               property_value: inline_call(Encoding.create!({:enumerated, 1})),
               error: nil
             })
  end

  test "encode read result error" do
    assert {:ok,
            [
              tagged: {2, "U", 1},
              constructed: {5, [enumerated: 2, enumerated: 65_535], 0}
            ]} =
             ReadResult.encode(%ReadResult{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: nil,
               error: %BACnetError{
                 class: :property,
                 code: 65_535
               }
             })
  end

  test "encode read result error with array index" do
    assert {:ok,
            [
              tagged: {2, "U", 1},
              tagged: {3, <<2>>, 1},
              constructed: {5, [enumerated: 2, enumerated: 65_535], 0}
            ]} =
             ReadResult.encode(%ReadResult{
               property_identifier: :present_value,
               property_array_index: 2,
               property_value: nil,
               error: %BACnetError{
                 class: :property,
                 code: 65_535
               }
             })
  end

  test "encode read result invalid" do
    assert {:error, :invalid_value_and_error} =
             ReadResult.encode(%ReadResult{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: nil,
               error: nil
             })
  end

  test "encode read result rejects both property value and access error" do
    assert {:error, :invalid_value_and_error} =
             ReadResult.encode(%ReadResult{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: Encoding.create!({:enumerated, 1}),
               error: %BACnetError{class: :property, code: :unknown_property}
             })
  end

  test "decode read result rejects the all selector" do
    assert {:error, :invalid_property_identifier} =
             ReadResult.parse(
               tagged: {2, <<0x08>>, 1},
               constructed: {4, {:enumerated, 1}, 0}
             )
  end

  test "decode read result rejects the required selector" do
    assert {:error, :invalid_property_identifier} =
             ReadResult.parse(
               tagged: {2, <<0x69>>, 1},
               constructed: {4, {:enumerated, 1}, 0}
             )
  end

  test "decode read result rejects the optional selector" do
    assert {:error, :invalid_property_identifier} =
             ReadResult.parse(
               tagged: {2, <<0x50>>, 1},
               constructed: {4, {:enumerated, 1}, 0}
             )
  end

  test "encode read result rejects the all selector (:all)" do
    assert {:error, :invalid_property_identifier} =
             ReadResult.encode(%ReadResult{
               property_identifier: :all,
               property_array_index: nil,
               property_value: Encoding.create!({:enumerated, 1}),
               error: nil
             })
  end

  test "encode read result rejects the all selector (8)" do
    assert {:error, :invalid_property_identifier} =
             ReadResult.encode(%ReadResult{
               property_identifier: 0x08,
               property_array_index: nil,
               property_value: Encoding.create!({:enumerated, 1}),
               error: nil
             })
  end

  test "encode read result rejects the required selector (:required)" do
    assert {:error, :invalid_property_identifier} =
             ReadResult.encode(%ReadResult{
               property_identifier: :required,
               property_array_index: nil,
               property_value: Encoding.create!({:enumerated, 1}),
               error: nil
             })
  end

  test "encode read result rejects the required selector (105)" do
    assert {:error, :invalid_property_identifier} =
             ReadResult.encode(%ReadResult{
               property_identifier: 0x69,
               property_array_index: nil,
               property_value: Encoding.create!({:enumerated, 1}),
               error: nil
             })
  end

  test "encode read result rejects the optional selector (:optional)" do
    assert {:error, :invalid_property_identifier} =
             ReadResult.encode(%ReadResult{
               property_identifier: :optional,
               property_array_index: nil,
               property_value: Encoding.create!({:enumerated, 1}),
               error: nil
             })
  end

  test "encode read result rejects the optional selector (80)" do
    assert {:error, :invalid_property_identifier} =
             ReadResult.encode(%ReadResult{
               property_identifier: 0x50,
               property_array_index: nil,
               property_value: Encoding.create!({:enumerated, 1}),
               error: nil
             })
  end

  test "rejects selectors in access errors" do
    error = %BACnetError{class: :object, code: :unknown_object}

    for {selector, id} <- [all: 8, required: 105, optional: 80] do
      tags = [tagged: {2, <<id>>, 1}, constructed: {5, [enumerated: 1, enumerated: 31], 0}]

      result = %ReadResult{
        property_identifier: selector,
        property_array_index: nil,
        property_value: nil,
        error: error
      }

      assert {:error, :invalid_property_identifier} = ReadResult.encode(result)

      assert {:error, :invalid_property_identifier} =
               ReadResult.encode(%{result | property_identifier: id})

      assert {:error, :invalid_property_identifier} = ReadResult.parse(tags)
      refute ReadResult.valid?(result)
      refute ReadResult.valid?(%{result | property_identifier: id})

      value = Encoding.create!({:enumerated, 1})
      refute ReadResult.valid?(%{result | property_value: value, error: nil})

      refute ReadResult.valid?(%{
               result
               | property_identifier: id,
                 property_value: [],
                 error: nil
             })
    end
  end

  test "valid read result" do
    assert true ==
             ReadResult.valid?(%ReadResult{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: Encoding.create!({:enumerated, 1}),
               error: nil
             })

    assert true ==
             ReadResult.valid?(%ReadResult{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: [Encoding.create!({:enumerated, 1})],
               error: nil
             })

    assert true ==
             ReadResult.valid?(%ReadResult{
               property_identifier: :present_value,
               property_array_index: 2,
               property_value: Encoding.create!({:enumerated, 1}),
               error: nil
             })

    assert true ==
             ReadResult.valid?(%ReadResult{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: nil,
               error: %BACnetError{class: :property, code: 65_535}
             })

    assert true ==
             ReadResult.valid?(%ReadResult{
               property_identifier: :present_value,
               property_array_index: 5,
               property_value: nil,
               error: %BACnetError{class: :property, code: 65_535}
             })

    assert true ==
             ReadResult.valid?(%ReadResult{
               property_identifier: 512,
               property_array_index: nil,
               property_value: Encoding.create!({:enumerated, 1}),
               error: nil
             })

    assert true ==
             ReadResult.valid?(%ReadResult{
               property_identifier: 512,
               property_array_index: nil,
               property_value: [Encoding.create!({:enumerated, 1})],
               error: nil
             })

    assert true ==
             ReadResult.valid?(%ReadResult{
               property_identifier: 512,
               property_array_index: nil,
               property_value: nil,
               error: %BACnetError{class: :property, code: 65_535}
             })
  end

  test "invalid read result" do
    assert false ==
             ReadResult.valid?(%ReadResult{
               property_identifier: :hello_there,
               property_array_index: nil,
               property_value: Encoding.create!({:enumerated, 1}),
               error: nil
             })

    assert false ==
             ReadResult.valid?(%ReadResult{
               property_identifier: -5,
               property_array_index: nil,
               property_value: Encoding.create!({:enumerated, 1}),
               error: nil
             })

    assert false ==
             ReadResult.valid?(%ReadResult{
               property_identifier: :present_value,
               property_array_index: :hello_there,
               property_value: Encoding.create!({:enumerated, 1}),
               error: nil
             })

    assert false ==
             ReadResult.valid?(%ReadResult{
               property_identifier: :present_value,
               property_array_index: -5,
               property_value: Encoding.create!({:enumerated, 1}),
               error: nil
             })

    assert false ==
             ReadResult.valid?(%ReadResult{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: :hello_there,
               error: nil
             })

    assert false ==
             ReadResult.valid?(%ReadResult{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: nil,
               error: nil
             })

    assert false ==
             ReadResult.valid?(%ReadResult{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: nil,
               error: :hello_there
             })

    assert false ==
             ReadResult.valid?(%ReadResult{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: nil,
               error: %BACnetError{class: :hello_there, code: 65_535}
             })
  end
end
