defmodule BACnet.Protocol.LimitEnableTest do
  alias BACnet.Protocol.LimitEnable

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest LimitEnable

  test "decode limit enable" do
    assert {:ok,
            {%LimitEnable{
               low_limit_enable: true,
               high_limit_enable: false
             }, []}} = LimitEnable.parse(bitstring: {true, false})
  end

  test "decode limit enable 2" do
    assert {:ok,
            {%LimitEnable{
               low_limit_enable: false,
               high_limit_enable: true
             }, []}} = LimitEnable.parse(bitstring: {false, true})
  end

  test "decode invalid limit enable" do
    assert {:error, :invalid_tags} = LimitEnable.parse([])
  end

  test "encode limit enable" do
    assert {:ok, [bitstring: {true, false}]} =
             LimitEnable.encode(%LimitEnable{
               low_limit_enable: true,
               high_limit_enable: false
             })
  end

  test "encode limit enable 2" do
    assert {:ok, [bitstring: {false, true}]} =
             LimitEnable.encode(%LimitEnable{
               low_limit_enable: false,
               high_limit_enable: true
             })
  end

  test "from bitstring limit enable" do
    assert %LimitEnable{
             low_limit_enable: true,
             high_limit_enable: true
           } = LimitEnable.from_bitstring({true, true})
  end

  test "from bitstring limit enable wrong bitstring" do
    assert_raise FunctionClauseError, fn ->
      LimitEnable.from_bitstring({true, true, true})
    end
  end

  test "to bitstring limit enable" do
    assert {:bitstring, {true, true}} =
             LimitEnable.to_bitstring(%LimitEnable{
               low_limit_enable: true,
               high_limit_enable: true
             })
  end

  test "valid limit enable" do
    assert true ==
             LimitEnable.valid?(%LimitEnable{
               low_limit_enable: true,
               high_limit_enable: true
             })

    assert true ==
             LimitEnable.valid?(%LimitEnable{
               low_limit_enable: false,
               high_limit_enable: false
             })
  end

  test "invalid limit enable" do
    assert false ==
             LimitEnable.valid?(%LimitEnable{
               low_limit_enable: :hello,
               high_limit_enable: true
             })

    assert false ==
             LimitEnable.valid?(%LimitEnable{
               low_limit_enable: true,
               high_limit_enable: :hello
             })
  end
end
