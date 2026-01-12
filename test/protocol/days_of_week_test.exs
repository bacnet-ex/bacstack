defmodule BACnet.Protocol.DaysOfWeekTest do
  alias BACnet.Protocol.DaysOfWeek

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest DaysOfWeek

  test "decode dow" do
    assert {:ok,
            {%DaysOfWeek{
               monday: true,
               tuesday: false,
               wednesday: false,
               thursday: true,
               friday: false,
               saturday: false,
               sunday: true
             }, []}} = DaysOfWeek.parse(bitstring: {true, false, false, true, false, false, true})
  end

  test "decode dow 2" do
    assert {:ok,
            {%DaysOfWeek{
               monday: false,
               tuesday: true,
               wednesday: false,
               thursday: false,
               friday: true,
               saturday: false,
               sunday: false
             }, []}} =
             DaysOfWeek.parse(bitstring: {false, true, false, false, true, false, false})
  end

  test "decode dow 3" do
    assert {:ok,
            {%DaysOfWeek{
               monday: false,
               tuesday: false,
               wednesday: true,
               thursday: false,
               friday: false,
               saturday: true,
               sunday: false
             }, []}} =
             DaysOfWeek.parse(bitstring: {false, false, true, false, false, true, false})
  end

  test "decode invalid dow" do
    assert {:error, :invalid_tags} = DaysOfWeek.parse([])
  end

  test "encode dow" do
    assert {:ok, [bitstring: {true, false, false, true, false, false, true}]} =
             DaysOfWeek.encode(%DaysOfWeek{
               monday: true,
               tuesday: false,
               wednesday: false,
               thursday: true,
               friday: false,
               saturday: false,
               sunday: true
             })
  end

  test "encode dow 2" do
    assert {:ok, [bitstring: {false, true, false, false, true, false, false}]} =
             DaysOfWeek.encode(%DaysOfWeek{
               monday: false,
               tuesday: true,
               wednesday: false,
               thursday: false,
               friday: true,
               saturday: false,
               sunday: false
             })
  end

  test "encode dow 3" do
    assert {:ok, [bitstring: {false, false, true, false, false, true, false}]} =
             DaysOfWeek.encode(%DaysOfWeek{
               monday: false,
               tuesday: false,
               wednesday: true,
               thursday: false,
               friday: false,
               saturday: true,
               sunday: false
             })
  end

  test "from bitstring dow" do
    assert %DaysOfWeek{
             monday: true,
             tuesday: true,
             wednesday: true,
             thursday: true,
             friday: true,
             saturday: false,
             sunday: false
           } = DaysOfWeek.from_bitstring({true, true, true, true, true, false, false})
  end

  test "from bitstring dow wrong bitstring" do
    assert_raise FunctionClauseError, fn ->
      DaysOfWeek.from_bitstring({true, true, true, true, true, false})
    end
  end

  test "to bitstring dow" do
    assert {:bitstring, {true, true, true, true, true, false, false}} =
             DaysOfWeek.to_bitstring(%DaysOfWeek{
               monday: true,
               tuesday: true,
               wednesday: true,
               thursday: true,
               friday: true,
               saturday: false,
               sunday: false
             })
  end

  test "valid dow" do
    assert true ==
             DaysOfWeek.valid?(%DaysOfWeek{
               monday: true,
               tuesday: true,
               wednesday: true,
               thursday: true,
               friday: true,
               saturday: false,
               sunday: false
             })

    assert true ==
             DaysOfWeek.valid?(%DaysOfWeek{
               monday: false,
               tuesday: false,
               wednesday: false,
               thursday: false,
               friday: false,
               saturday: true,
               sunday: true
             })
  end

  test "invalid dow" do
    assert false ==
             DaysOfWeek.valid?(%DaysOfWeek{
               monday: :hello,
               tuesday: true,
               wednesday: true,
               thursday: true,
               friday: true,
               saturday: false,
               sunday: false
             })

    assert false ==
             DaysOfWeek.valid?(%DaysOfWeek{
               monday: true,
               tuesday: :hello,
               wednesday: true,
               thursday: true,
               friday: true,
               saturday: false,
               sunday: false
             })

    assert false ==
             DaysOfWeek.valid?(%DaysOfWeek{
               monday: true,
               tuesday: true,
               wednesday: :hello,
               thursday: true,
               friday: true,
               saturday: false,
               sunday: false
             })

    assert false ==
             DaysOfWeek.valid?(%DaysOfWeek{
               monday: true,
               tuesday: true,
               wednesday: true,
               thursday: :hello,
               friday: true,
               saturday: false,
               sunday: false
             })

    assert false ==
             DaysOfWeek.valid?(%DaysOfWeek{
               monday: true,
               tuesday: true,
               wednesday: true,
               thursday: true,
               friday: :hello,
               saturday: false,
               sunday: false
             })

    assert false ==
             DaysOfWeek.valid?(%DaysOfWeek{
               monday: true,
               tuesday: true,
               wednesday: true,
               thursday: true,
               friday: true,
               saturday: :hello,
               sunday: false
             })

    assert false ==
             DaysOfWeek.valid?(%DaysOfWeek{
               monday: true,
               tuesday: true,
               wednesday: true,
               thursday: true,
               friday: true,
               saturday: false,
               sunday: :hello
             })
  end
end
