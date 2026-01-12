defmodule BACnet.Test.Protocol.ApplicationTags.EncodingTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.ObjectIdentifier

  use ExUnit.Case, async: true

  @moduletag :application_tags

  doctest Encoding

  test_data = [
    {:primitive, :null, nil, [], []},
    {:primitive, :boolean, false, [], []},
    {:primitive, :boolean, true, [], []},
    {:primitive, :unsigned_integer, 245, [], []},
    {:primitive, :signed_integer, -255, [], []},
    {:primitive, :real, 3.141, [], []},
    {:primitive, :double, 3.141, [], []},
    {:primitive, :octet_string, <<0>>, [], []},
    {:primitive, :character_string, "H", [], []},
    {:primitive, :bitstring, {false, true}, [], []},
    {:primitive, :enumerated, 1, [], []},
    {:primitive, :date, %BACnetDate{year: 2022, month: 12, day: :even, weekday: 5}, [], []},
    {:primitive, :time, %BACnetTime{hour: 23, minute: 59, second: 59, hundredth: 245}, [], []},
    {:primitive, :object_identifier, %ObjectIdentifier{type: :device, instance: 259_509}, [], []},
    {:tagged, nil, {2, <<0>>, 1}, <<0>>, [tag_number: 2], []},
    {:tagged, :boolean, {2, <<1>>, 1}, true, [context: :hello, tag_number: 2],
     [cast_type: :boolean, context: :hello]},
    {:constructed, nil, {1, <<0>>, 1}, <<0>>, [tag_number: 1], []},
    {:constructed, nil, {1, :hello, 0}, :hello, [tag_number: 1], []},
    {:constructed, :real, {155, {:real, 6.9}, 0}, 6.9, [tag_number: 155], []}
  ]

  for {{encoding, type, value, extras, opts}, index} <- Enum.with_index(test_data, 1) do
    test "create and verify #{encoding} #{type} (1-#{index})" do
      assert {:ok,
              %Encoding{
                encoding: unquote(encoding),
                extras: unquote(Macro.escape(extras)),
                type: unquote(type),
                value: unquote(Macro.escape(value))
              }} =
               Encoding.create(
                 {unquote(Macro.escape(type)), unquote(Macro.escape(value))},
                 unquote(opts)
               )
    end
  end

  for {{encoding, type, value, expanded_value, extras, opts}, index} <-
        Enum.with_index(test_data, 1) do
    test "create and verify #{encoding} #{type} (2-#{index})" do
      assert {:ok,
              %Encoding{
                encoding: unquote(encoding),
                extras: unquote(Macro.escape(extras)),
                type: unquote(type),
                value: unquote(Macro.escape(expanded_value))
              }} =
               Encoding.create({unquote(encoding), unquote(Macro.escape(value))}, unquote(opts))
    end

    test "create and to_encoding #{encoding} #{type} (2-#{index})" do
      assert {:ok, {unquote(encoding), unquote(Macro.escape(value))}} =
               Encoding.to_encoding(%Encoding{
                 encoding: unquote(encoding),
                 extras: unquote(Macro.escape(extras)),
                 type: unquote(type),
                 value: unquote(Macro.escape(expanded_value))
               })
    end
  end

  test "create invalid encoding" do
    assert {:error, :invalid_encoding} = Encoding.create({:hello, :there})
  end

  test "create ignore nil option" do
    assert {:ok, %Encoding{encoding: :primitive, type: :boolean, value: false, extras: []}} =
             Encoding.create({:boolean, false}, context: nil)
  end

  test "create valid encoder" do
    fun = fn a -> a end

    assert {:ok,
            %Encoding{encoding: :primitive, type: :boolean, value: false, extras: [encoder: ^fun]}} =
             Encoding.create({:boolean, false}, encoder: fun)
  end

  test "create invalid encoder" do
    assert_raise ArgumentError, fn ->
      Encoding.create({:boolean, true}, encoder: fn a, b -> a * b end)
    end
  end

  test "create! valid encoding" do
    assert %Encoding{encoding: :primitive, type: :boolean, value: false} =
             Encoding.create!({:boolean, false})
  end

  test "create! invalid encoding" do
    assert_raise Encoding.Error, fn ->
      Encoding.create!({:hello, :there})
    end
  end

  test "create and run encoder" do
    encoder = fn a -> !a end

    assert {:ok, {:boolean, true}} =
             {:boolean, false}
             |> Encoding.create!(encoder: encoder)
             |> Encoding.to_encoding()
  end

  test "create and run encoder with context" do
    encoder = fn a -> !a end

    assert {:ok, {:boolean, true}} =
             {:boolean, false}
             |> Encoding.create!(context: true, encoder: encoder)
             |> Encoding.to_encoding()
  end

  test "create and run encoder tagged with context" do
    encoder = fn a -> a end

    assert {:ok, {:tagged, {0, <<0>>, 1}}} =
             {:tagged, {0, <<0>>, 1}}
             |> Encoding.create!(context: true, encoder: encoder)
             |> Encoding.to_encoding()
  end

  test "create and run encoder with ok-tuple response" do
    encoder = fn a -> {:ok, !a} end

    assert {:ok, {:boolean, true}} =
             {:boolean, false}
             |> Encoding.create!(context: true, encoder: encoder)
             |> Encoding.to_encoding()
  end

  test "create and run encoder with error-tuple response" do
    encoder = fn _a -> {:error, :no} end

    assert {:error, :no} =
             {:boolean, false}
             |> Encoding.create!(context: true, encoder: encoder)
             |> Encoding.to_encoding()
  end

  test "to_encoding! valid encoding" do
    assert {:boolean, false} =
             Encoding.to_encoding!(%Encoding{
               encoding: :primitive,
               type: :boolean,
               value: false,
               extras: []
             })
  end

  test "to_encoding! invalid encoding" do
    assert_raise Encoding.Error, fn ->
      Encoding.to_encoding!(%Encoding{encoding: :tagged, type: nil, value: nil, extras: []})
    end
  end
end
