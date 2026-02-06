defmodule BACnet.Protocol.ResultFlagsTest do
  alias BACnet.Protocol.ResultFlags

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest ResultFlags

  test "decode result flags" do
    assert {:ok,
            {%ResultFlags{
               first_item: true,
               last_item: false,
               more_items: false
             }, []}} = ResultFlags.parse(bitstring: {true, false, false})
  end

  test "decode result flags 2" do
    assert {:ok,
            {%ResultFlags{
               first_item: false,
               last_item: true,
               more_items: false
             }, []}} = ResultFlags.parse(bitstring: {false, true, false})
  end

  test "decode result flags 3" do
    assert {:ok,
            {%ResultFlags{
               first_item: false,
               last_item: false,
               more_items: true
             }, []}} = ResultFlags.parse(bitstring: {false, false, true})
  end

  test "decode invalid result flags" do
    assert {:error, :invalid_tags} = ResultFlags.parse([])
  end

  test "encode result flags" do
    assert {:ok, [bitstring: {true, false, false}]} =
             ResultFlags.encode(%ResultFlags{
               first_item: true,
               last_item: false,
               more_items: false
             })
  end

  test "encode result flags 2" do
    assert {:ok, [bitstring: {false, true, false}]} =
             ResultFlags.encode(%ResultFlags{
               first_item: false,
               last_item: true,
               more_items: false
             })
  end

  test "encode result flags 3" do
    assert {:ok, [bitstring: {false, false, true}]} =
             ResultFlags.encode(%ResultFlags{
               first_item: false,
               last_item: false,
               more_items: true
             })
  end

  test "from bitstring result flags" do
    assert %ResultFlags{
             first_item: true,
             last_item: true,
             more_items: true
           } = ResultFlags.from_bitstring({true, true, true})
  end

  test "from bitstring result flags wrong bitstring" do
    assert_raise FunctionClauseError, fn ->
      ResultFlags.from_bitstring({true, true, true, false})
    end
  end

  test "to bitstring result flags" do
    assert {:bitstring, {true, true, true}} =
             ResultFlags.to_bitstring(%ResultFlags{
               first_item: true,
               last_item: true,
               more_items: true
             })
  end

  test "valid result flags" do
    assert true ==
             ResultFlags.valid?(%ResultFlags{
               first_item: true,
               last_item: true,
               more_items: true
             })

    assert true ==
             ResultFlags.valid?(%ResultFlags{
               first_item: false,
               last_item: false,
               more_items: false
             })
  end

  test "invalid result flags" do
    assert false ==
             ResultFlags.valid?(%ResultFlags{
               first_item: :hello,
               last_item: true,
               more_items: true
             })

    assert false ==
             ResultFlags.valid?(%ResultFlags{
               first_item: true,
               last_item: :hello,
               more_items: true
             })

    assert false ==
             ResultFlags.valid?(%ResultFlags{
               first_item: true,
               last_item: true,
               more_items: :hello
             })
  end
end
