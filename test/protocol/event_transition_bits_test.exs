defmodule BACnet.Protocol.EventTransitionBitsTest do
  alias BACnet.Protocol.EventTransitionBits

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest EventTransitionBits

  test "decode event transition bits" do
    assert {:ok,
            {%EventTransitionBits{
               to_offnormal: true,
               to_fault: false,
               to_normal: false
             }, []}} = EventTransitionBits.parse(bitstring: {true, false, false})
  end

  test "decode event transition bits 2" do
    assert {:ok,
            {%EventTransitionBits{
               to_offnormal: false,
               to_fault: true,
               to_normal: false
             }, []}} = EventTransitionBits.parse(bitstring: {false, true, false})
  end

  test "decode event transition bits 3" do
    assert {:ok,
            {%EventTransitionBits{
               to_offnormal: false,
               to_fault: false,
               to_normal: true
             }, []}} = EventTransitionBits.parse(bitstring: {false, false, true})
  end

  test "decode invalid event transition bits" do
    assert {:error, :invalid_tags} = EventTransitionBits.parse([])
  end

  test "encode event transition bits" do
    assert {:ok, [bitstring: {true, false, false}]} =
             EventTransitionBits.encode(%EventTransitionBits{
               to_offnormal: true,
               to_fault: false,
               to_normal: false
             })
  end

  test "encode event transition bits 2" do
    assert {:ok, [bitstring: {false, true, false}]} =
             EventTransitionBits.encode(%EventTransitionBits{
               to_offnormal: false,
               to_fault: true,
               to_normal: false
             })
  end

  test "encode event transition bits 3" do
    assert {:ok, [bitstring: {false, false, true}]} =
             EventTransitionBits.encode(%EventTransitionBits{
               to_offnormal: false,
               to_fault: false,
               to_normal: true
             })
  end

  test "from bitstring event transition bits" do
    assert %EventTransitionBits{
             to_offnormal: true,
             to_fault: true,
             to_normal: true
           } = EventTransitionBits.from_bitstring({true, true, true})
  end

  test "from bitstring event transition bits wrong bitstring" do
    assert_raise FunctionClauseError, fn ->
      EventTransitionBits.from_bitstring({true, true, true, true})
    end
  end

  test "to bitstring event transition bits" do
    assert {:bitstring, {true, true, true}} =
             EventTransitionBits.to_bitstring(%EventTransitionBits{
               to_offnormal: true,
               to_fault: true,
               to_normal: true
             })
  end

  test "valid event transition bits" do
    assert true ==
             EventTransitionBits.valid?(%EventTransitionBits{
               to_offnormal: true,
               to_fault: true,
               to_normal: true
             })

    assert true ==
             EventTransitionBits.valid?(%EventTransitionBits{
               to_offnormal: false,
               to_fault: false,
               to_normal: false
             })
  end

  test "invalid event transition bits" do
    assert false ==
             EventTransitionBits.valid?(%EventTransitionBits{
               to_offnormal: :hello,
               to_fault: true,
               to_normal: true
             })

    assert false ==
             EventTransitionBits.valid?(%EventTransitionBits{
               to_offnormal: true,
               to_fault: :hello,
               to_normal: true
             })

    assert false ==
             EventTransitionBits.valid?(%EventTransitionBits{
               to_offnormal: true,
               to_fault: true,
               to_normal: :hello
             })
  end
end
