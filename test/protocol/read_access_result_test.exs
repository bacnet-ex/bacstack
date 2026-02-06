defmodule BACnet.Protocol.ReadAccessResultTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ReadAccessResult

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest ReadAccessResult

  test "decode read access result" do
    assert {:ok,
            {%ReadAccessResult{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 1
               },
               results: [%ReadAccessResult.ReadResult{}]
             },
             []}} =
             ReadAccessResult.parse(
               tagged: {0, <<0::size(10), 1::size(22)>>, 4},
               constructed:
                 {1,
                  [
                    tagged: {2, "U", 1},
                    constructed: {4, {:enumerated, 1}, 0}
                  ], 0}
             )
  end

  test "decode read access result multi" do
    assert {:ok,
            {%ReadAccessResult{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 1
               },
               results: [%ReadAccessResult.ReadResult{}, %ReadAccessResult.ReadResult{}]
             },
             []}} =
             ReadAccessResult.parse(
               tagged: {0, <<0::size(10), 1::size(22)>>, 4},
               constructed:
                 {1,
                  [
                    tagged: {2, "U", 1},
                    constructed: {4, {:enumerated, 1}, 0},
                    tagged: {2, "U", 1},
                    constructed: {4, {:enumerated, 1}, 0}
                  ], 0}
             )
  end

  test "decode read access result empty" do
    assert {:ok,
            {%ReadAccessResult{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               results: []
             }, []}} = ReadAccessResult.parse(tagged: {0, <<0::size(10), 2::size(22)>>, 4})
  end

  test "decode read access result empty invalid" do
    assert {:error, :invalid_tags} =
             ReadAccessResult.parse(
               tagged: {0, <<0::size(10), 1::size(22)>>, 4},
               constructed: {1, [], 0}
             )
  end

  test "decode read access result invalid missing" do
    assert {:error, :invalid_tags} =
             ReadAccessResult.parse(tagged: {2, <<0::size(10), 1::size(22)>>, 4})
  end

  test "decode read access result error" do
    assert {:error, :invalid_value_and_error} =
             ReadAccessResult.parse(
               tagged: {0, <<0::size(10), 1::size(22)>>, 4},
               constructed:
                 {1,
                  [
                    tagged: {2, "U", 1}
                  ], 0}
             )
  end

  test "encode read access result" do
    assert {:ok,
            [
              tagged: {0, <<0::size(10), 1::size(22)>>, 4},
              constructed:
                {1,
                 [
                   tagged: {2, "U", 1},
                   constructed: {4, {:enumerated, 1}, 0}
                 ], 0}
            ]} =
             ReadAccessResult.encode(%ReadAccessResult{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 1
               },
               results: [
                 %ReadAccessResult.ReadResult{
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: Encoding.create!({:enumerated, 1}),
                   error: nil
                 }
               ]
             })
  end

  test "encode read access result multi" do
    assert {:ok,
            [
              tagged: {0, <<0::size(10), 1::size(22)>>, 4},
              constructed:
                {1,
                 [
                   tagged: {2, "U", 1},
                   constructed: {4, {:enumerated, 1}, 0},
                   tagged: {2, "U", 1},
                   constructed: {4, {:enumerated, 1}, 0}
                 ], 0}
            ]} =
             ReadAccessResult.encode(%ReadAccessResult{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 1
               },
               results: [
                 %ReadAccessResult.ReadResult{
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: Encoding.create!({:enumerated, 1}),
                   error: nil
                 },
                 %ReadAccessResult.ReadResult{
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: Encoding.create!({:enumerated, 1}),
                   error: nil
                 }
               ]
             })
  end

  test "encode read access result empty" do
    assert {:ok,
            [
              tagged: {0, <<0, 0, 0, 2>>, 4}
            ]} =
             ReadAccessResult.encode(%ReadAccessResult{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               results: []
             })
  end

  test "encode read access result error" do
    assert {:error, :invalid_value} =
             ReadAccessResult.encode(%ReadAccessResult{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               results: [
                 %ReadAccessResult.ReadResult{
                   property_identifier: -1,
                   property_array_index: nil,
                   property_value: Encoding.create!({:enumerated, 1}),
                   error: nil
                 }
               ]
             })
  end

  test "valid read access result" do
    assert true ==
             ReadAccessResult.valid?(%ReadAccessResult{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               results: []
             })

    assert true ==
             ReadAccessResult.valid?(%ReadAccessResult{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 1
               },
               results: [
                 %ReadAccessResult.ReadResult{
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: Encoding.create!({:enumerated, 1}),
                   error: nil
                 }
               ]
             })

    assert true ==
             ReadAccessResult.valid?(%ReadAccessResult{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 1
               },
               results: [
                 %ReadAccessResult.ReadResult{
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: Encoding.create!({:enumerated, 1}),
                   error: nil
                 },
                 %ReadAccessResult.ReadResult{
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: Encoding.create!({:enumerated, 1}),
                   error: nil
                 }
               ]
             })

    assert true ==
             ReadAccessResult.valid?(%ReadAccessResult{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 1
               },
               results: [
                 %ReadAccessResult.ReadResult{
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: nil,
                   error: %BACnetError{
                     class: 1,
                     code: 1
                   }
                 }
               ]
             })

    assert true ==
             ReadAccessResult.valid?(%ReadAccessResult{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 1
               },
               results: [
                 %ReadAccessResult.ReadResult{
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: Encoding.create!({:enumerated, 1}),
                   error: nil
                 },
                 %ReadAccessResult.ReadResult{
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: nil,
                   error: %BACnetError{
                     class: 1,
                     code: 1
                   }
                 }
               ]
             })
  end

  test "invalid read access result" do
    assert false ==
             ReadAccessResult.valid?(%ReadAccessResult{
               object_identifier: :hello_there,
               results: []
             })

    assert false ==
             ReadAccessResult.valid?(%ReadAccessResult{
               object_identifier: %ObjectIdentifier{
                 type: :hello_there,
                 instance: 2
               },
               results: []
             })

    assert false ==
             ReadAccessResult.valid?(%ReadAccessResult{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               results: :hello_there
             })

    assert false ==
             ReadAccessResult.valid?(%ReadAccessResult{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               results: [:hello_there]
             })

    assert false ==
             ReadAccessResult.valid?(%ReadAccessResult{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 2
               },
               results: [
                 %ReadAccessResult.ReadResult{
                   property_identifier: :present_value,
                   property_array_index: nil,
                   property_value: nil,
                   error: :hello_there
                 }
               ]
             })
  end
end
