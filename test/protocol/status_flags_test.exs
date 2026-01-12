defmodule BACnet.Protocol.StatusFlagsTest do
  alias BACnet.Protocol.StatusFlags

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest StatusFlags

  test "decode status flags" do
    assert {:ok,
            {%StatusFlags{
               in_alarm: true,
               fault: false,
               overridden: false,
               out_of_service: false
             }, []}} = StatusFlags.parse(bitstring: {true, false, false, false})
  end

  test "decode status flags 2" do
    assert {:ok,
            {%StatusFlags{
               in_alarm: false,
               fault: true,
               overridden: false,
               out_of_service: false
             }, []}} = StatusFlags.parse(bitstring: {false, true, false, false})
  end

  test "decode status flags 3" do
    assert {:ok,
            {%StatusFlags{
               in_alarm: false,
               fault: false,
               overridden: true,
               out_of_service: false
             }, []}} = StatusFlags.parse(bitstring: {false, false, true, false})
  end

  test "decode status flags 4" do
    assert {:ok,
            {%StatusFlags{
               in_alarm: false,
               fault: false,
               overridden: false,
               out_of_service: true
             }, []}} = StatusFlags.parse(bitstring: {false, false, false, true})
  end

  test "decode invalid status flags" do
    assert {:error, :invalid_tags} = StatusFlags.parse([])
  end

  test "encode status flags" do
    assert {:ok, [bitstring: {true, false, false, false}]} =
             StatusFlags.encode(%StatusFlags{
               in_alarm: true,
               fault: false,
               overridden: false,
               out_of_service: false
             })
  end

  test "encode status flags 2" do
    assert {:ok, [bitstring: {false, true, false, false}]} =
             StatusFlags.encode(%StatusFlags{
               in_alarm: false,
               fault: true,
               overridden: false,
               out_of_service: false
             })
  end

  test "encode status flags 3" do
    assert {:ok, [bitstring: {false, false, true, false}]} =
             StatusFlags.encode(%StatusFlags{
               in_alarm: false,
               fault: false,
               overridden: true,
               out_of_service: false
             })
  end

  test "encode status flags 4" do
    assert {:ok, [bitstring: {false, false, false, true}]} =
             StatusFlags.encode(%StatusFlags{
               in_alarm: false,
               fault: false,
               overridden: false,
               out_of_service: true
             })
  end

  test "from bitstring status flags" do
    assert %StatusFlags{
             in_alarm: true,
             fault: true,
             overridden: true,
             out_of_service: true
           } = StatusFlags.from_bitstring({true, true, true, true})
  end

  test "from bitstring status flags wrong bitstring" do
    assert_raise FunctionClauseError, fn ->
      StatusFlags.from_bitstring({true, true, true})
    end
  end

  test "to bitstring status flags" do
    assert {:bitstring, {true, true, true, false}} =
             StatusFlags.to_bitstring(%StatusFlags{
               in_alarm: true,
               fault: true,
               overridden: true,
               out_of_service: false
             })
  end

  test "valid status flags" do
    assert true ==
             StatusFlags.valid?(%StatusFlags{
               in_alarm: true,
               fault: true,
               overridden: true,
               out_of_service: true
             })

    assert true ==
             StatusFlags.valid?(%StatusFlags{
               in_alarm: false,
               fault: false,
               overridden: false,
               out_of_service: false
             })
  end

  test "invalid status flags" do
    assert false ==
             StatusFlags.valid?(%StatusFlags{
               in_alarm: :hello,
               fault: true,
               overridden: true,
               out_of_service: true
             })

    assert false ==
             StatusFlags.valid?(%StatusFlags{
               in_alarm: true,
               fault: :hello,
               overridden: true,
               out_of_service: true
             })

    assert false ==
             StatusFlags.valid?(%StatusFlags{
               in_alarm: true,
               fault: true,
               overridden: :hello,
               out_of_service: true
             })

    assert false ==
             StatusFlags.valid?(%StatusFlags{
               in_alarm: true,
               fault: true,
               overridden: true,
               out_of_service: :hello
             })
  end
end
