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
                 code: 65535
               }
             }, []}} =
             ReadResult.parse(
               tagged: {2, "U", 1},
               constructed: {5, [enumerated: 2, enumerated: 65535], 0}
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
                 code: 65535
               }
             }, []}} =
             ReadResult.parse(
               tagged: {2, "U", 1},
               tagged: {3, <<2>>, 1},
               constructed: {5, [enumerated: 2, enumerated: 65535], 0}
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
              constructed: {5, [enumerated: 2, enumerated: 65535], 0}
            ]} =
             ReadResult.encode(%ReadResult{
               property_identifier: :present_value,
               property_array_index: nil,
               property_value: nil,
               error: %BACnetError{
                 class: :property,
                 code: 65535
               }
             })
  end

  test "encode read result error with array index" do
    assert {:ok,
            [
              tagged: {2, "U", 1},
              tagged: {3, <<2>>, 1},
              constructed: {5, [enumerated: 2, enumerated: 65535], 0}
            ]} =
             ReadResult.encode(%ReadResult{
               property_identifier: :present_value,
               property_array_index: 2,
               property_value: nil,
               error: %BACnetError{
                 class: :property,
                 code: 65535
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
               error: %BACnetError{class: :property, code: 65535}
             })

    assert true ==
             ReadResult.valid?(%ReadResult{
               property_identifier: :present_value,
               property_array_index: 5,
               property_value: nil,
               error: %BACnetError{class: :property, code: 65535}
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
               error: %BACnetError{class: :property, code: 65535}
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
               error: %BACnetError{class: :hello_there, code: 65535}
             })
  end
end
