defmodule BACnet.Protocol.BACnetErrorTest do
  alias BACnet.Protocol.BACnetError

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest BACnetError

  test "decode error" do
    assert {:ok, {%BACnetError{class: :property, code: :no_space_to_write_property}, []}} =
             BACnetError.parse(enumerated: 2, enumerated: 20)
  end

  test "decode error with numeric class" do
    assert {:ok, {%BACnetError{class: 2550, code: :no_space_to_write_property}, []}} =
             BACnetError.parse(enumerated: 2550, enumerated: 20)
  end

  test "decode error with numeric code" do
    assert {:ok, {%BACnetError{class: :property, code: 65535}, []}} =
             BACnetError.parse(enumerated: 2, enumerated: 65535)
  end

  test "decode invalid error" do
    assert {:error, :invalid_tags} = BACnetError.parse(enumerated: 2)
  end

  test "encode error" do
    assert {:ok, [enumerated: 2, enumerated: 20]} =
             BACnetError.encode(%BACnetError{class: :property, code: :no_space_to_write_property})
  end

  test "encode error with numeric class" do
    assert {:ok, [enumerated: 2550, enumerated: 20]} =
             BACnetError.encode(%BACnetError{class: 2550, code: :no_space_to_write_property})
  end

  test "encode error with numeric code" do
    assert {:ok, [enumerated: 2, enumerated: 65535]} =
             BACnetError.encode(%BACnetError{class: :property, code: 65535})
  end

  test "valid error" do
    assert true ==
             BACnetError.valid?(%BACnetError{class: :property, code: :no_space_to_write_property})

    assert true == BACnetError.valid?(%BACnetError{class: :object, code: 53})
    assert true == BACnetError.valid?(%BACnetError{class: 2, code: :no_space_to_write_property})
  end

  test "invalid error" do
    assert false ==
             BACnetError.valid?(%BACnetError{class: :hello, code: :no_space_to_write_property})

    assert false == BACnetError.valid?(%BACnetError{class: :property, code: :hello})
    assert false == BACnetError.valid?(%BACnetError{class: 128_345, code: :hello})
    assert false == BACnetError.valid?(%BACnetError{class: :property, code: 128_346})
  end
end
