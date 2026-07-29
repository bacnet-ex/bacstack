defmodule BACnet.Protocol.NameValueTest do
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.NameValue

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest NameValue

  test "parse accepts name only (semantic tag)" do
    # name = "room"
    {:ok, name_tag} = ApplicationTags.create_tag_encoding(0, :character_string, "room")

    assert {:ok, {%NameValue{name: "room", value: nil}, []}} =
             NameValue.parse([name_tag])
  end

  test "parse accepts name + primitive Encoding value (unsigned)" do
    {:ok, name_tag} = ApplicationTags.create_tag_encoding(0, :character_string, "count")
    val_tag = {:unsigned_integer, 42}

    # Encoding.create expects the raw tagged form from ApplicationTags
    assert {:ok,
            {%NameValue{name: "count", value: %Encoding{encoding: :primitive, value: 42}}, []}} =
             NameValue.parse([name_tag, val_tag])
  end

  test "parse accepts name + character_string primitive value" do
    {:ok, name_tag} = ApplicationTags.create_tag_encoding(0, :character_string, "key")
    val_tag = {:character_string, "hello"}

    assert {:ok, {nv, []}} = NameValue.parse([name_tag, val_tag])
    assert nv.name == "key"
    assert match?(%Encoding{encoding: :primitive, value: "hello"}, nv.value)
  end

  test "parse rejects invalid structure" do
    assert {:error, :invalid_tags} = NameValue.parse([])
    assert {:error, :invalid_tags} = NameValue.parse([{:tagged, {5, <<>>, 0}}])

    assert {:error, :invalid_value} =
             NameValue.parse([{:tagged, {0, "\0Hello", 5}}, {:tagged, {1, <<>>, 0}}])

    assert {:error, :invalid_encoding} = NameValue.parse([{:tagged, {0, "\0Hello", 5}}, {:calle}])
  end

  test "encode name only (value: nil)" do
    nv = %NameValue{name: "semantic-tag", value: nil}

    assert {:ok, [name_tag]} = NameValue.encode(nv)
    assert {:tagged, {0, _, _}} = name_tag
  end

  test "encode name + primitive Encoding value" do
    nv = %NameValue{name: "count", value: Encoding.create!({:unsigned_integer, 42})}

    assert {:ok, [name_tag, value_tag]} = NameValue.encode(nv)
    assert {:tagged, {0, _, _}} = name_tag
    assert {:unsigned_integer, 42} = value_tag
  end

  test "encode rejects invalid name" do
    assert {:error, :invalid_name} = NameValue.encode(%NameValue{name: "", value: nil})

    assert {:error, :invalid_utf8_string} =
             NameValue.encode(%NameValue{name: <<192>>, value: nil})
  end

  test "encode rejects invalid value type" do
    nv = %NameValue{name: "bad", value: "not an Encoding"}
    assert {:error, :invalid_value} = NameValue.encode(nv)
  end

  test "valid? accepts proper entries" do
    assert NameValue.valid?(%NameValue{name: "foo", value: nil})

    {:ok, enc} = Encoding.create({:unsigned_integer, 42})
    assert NameValue.valid?(%NameValue{name: "bar", value: enc})
  end

  test "valid? rejects invalid entries" do
    refute NameValue.valid?(%NameValue{name: "", value: nil})
    refute NameValue.valid?(%NameValue{name: "x", value: "invalid"})
    refute NameValue.valid?(%NameValue{name: "x", value: %{encoding: :constructed}})
  end

  test "valid? rejects semicolon in name" do
    # ASHRAE Y.1.4 specifies:
    # "To allow tag names to be concatenated, tag names shall not contain semicolon characters."
    refute NameValue.valid?(%NameValue{name: ";", value: nil})
  end
end
