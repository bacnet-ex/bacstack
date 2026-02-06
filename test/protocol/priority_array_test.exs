defmodule BACnet.Protocol.PriorityArrayTest do
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.PriorityArray

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest PriorityArray

  test "fetch index verify atoms" do
    for num <- 1..16 do
      PriorityArray.fetch(%PriorityArray{}, :"priority_#{num}")
    end
  end

  test "fetch index verify numbers" do
    for num <- 1..16 do
      PriorityArray.fetch(%PriorityArray{}, num)
    end
  end

  test "fetch index as number" do
    assert {:ok, 5.0} = PriorityArray.fetch(%PriorityArray{priority_5: 5.0}, 5)
  end

  test "fetch index as atom" do
    assert {:ok, 5.0} = PriorityArray.fetch(%PriorityArray{priority_5: 5.0}, :priority_5)
  end

  test "fetch invalid index" do
    assert_raise FunctionClauseError, fn ->
      PriorityArray.fetch(%PriorityArray{}, 17)
    end

    assert_raise FunctionClauseError, fn ->
      PriorityArray.fetch(%PriorityArray{}, :hello)
    end
  end

  test "from array empty list" do
    assert %PriorityArray{} == PriorityArray.from_array(BACnetArray.from_list([]))
  end

  test "from array six elements" do
    assert %PriorityArray{priority_5: 5, priority_6: 6} ==
             PriorityArray.from_array(BACnetArray.from_list([nil, nil, nil, nil, 5, 6]))
  end

  test "from array 16 elements as nil" do
    assert %PriorityArray{} ==
             PriorityArray.from_array(BACnetArray.from_list(List.duplicate(nil, 16)))
  end

  test "from array too many elements" do
    assert_raise ArgumentError, fn ->
      PriorityArray.from_array(BACnetArray.from_list(List.duplicate(nil, 17)))
    end
  end

  test "from list empty list" do
    assert %PriorityArray{} == PriorityArray.from_list([])
  end

  test "from list six elements list" do
    assert %PriorityArray{priority_5: 5, priority_6: 6} ==
             PriorityArray.from_list([nil, nil, nil, nil, 5, 6])
  end

  test "from list 16 elements list as nil" do
    assert %PriorityArray{} == PriorityArray.from_list(List.duplicate(nil, 16))
  end

  test "from list empty map" do
    assert %PriorityArray{} == PriorityArray.from_list(%{})
  end

  test "from list six elements map" do
    assert %PriorityArray{priority_5: 5.0, priority_6: 6.0} ==
             PriorityArray.from_list(%{
               1 => nil,
               2 => nil,
               3 => nil,
               4 => nil,
               5 => 5.0,
               6 => 6.0
             })
  end

  test "from list 16 elements map as nil" do
    assert %PriorityArray{} == PriorityArray.from_list(Map.new(1..16, fn key -> {key, nil} end))
  end

  test "from list too many elements" do
    assert_raise ArgumentError, fn ->
      PriorityArray.from_list(Map.new(1..17, fn key -> {key, nil} end))
    end
  end

  test "from list six elements kw-list" do
    assert %PriorityArray{priority_5: 5.0, priority_6: 6.0} ==
             PriorityArray.from_list([{1, nil}, {2, nil}, {3, nil}, {4, nil}, {5, 5.0}, {6, 6.0}])
  end

  test "get and update value" do
    assert {1.5, %PriorityArray{priority_5: 6.9}} ==
             PriorityArray.get_and_update(%PriorityArray{priority_5: 1.5}, 5, fn val ->
               {val, 6.9}
             end)

    assert {1.6, %PriorityArray{priority_5: 6.9}} ==
             PriorityArray.get_and_update(%PriorityArray{priority_5: 3.5}, 5, fn _val ->
               {1.6, 6.9}
             end)
  end

  test "get and update pop" do
    assert {1.5, %PriorityArray{}} ==
             PriorityArray.get_and_update(%PriorityArray{priority_5: 1.5}, 5, fn _val -> :pop end)
  end

  test "get and update invalid value" do
    assert_raise RuntimeError, fn ->
      PriorityArray.get_and_update(%PriorityArray{}, 5, fn _val -> :hello end)
    end
  end

  test "get and update invalid index" do
    assert_raise FunctionClauseError, fn ->
      PriorityArray.get_and_update(%PriorityArray{}, 17, fn _val -> :pop end)
    end

    assert_raise FunctionClauseError, fn ->
      PriorityArray.get_and_update(%PriorityArray{}, :hello, fn _val -> :pop end)
    end
  end

  test "get priority nil" do
    assert nil == PriorityArray.get_value(%PriorityArray{})
  end

  test "get priority single" do
    assert {6, 1.0} == PriorityArray.get_value(%PriorityArray{priority_6: 1.0})
  end

  test "get priority multiple" do
    assert {1, +0.0} ==
             PriorityArray.get_value(%PriorityArray{
               priority_1: 0.0,
               priority_6: 1.0,
               priority_8: 6.9
             })
  end

  test "pop index as num" do
    assert {1.0, %PriorityArray{}} == PriorityArray.pop(%PriorityArray{priority_6: 1.0}, 6)
  end

  test "pop index as atom" do
    assert {1.0, %PriorityArray{}} ==
             PriorityArray.pop(%PriorityArray{priority_6: 1.0}, :priority_6)
  end

  test "pop invalid index" do
    assert_raise FunctionClauseError, fn ->
      PriorityArray.pop(%PriorityArray{}, 17)
    end

    assert_raise FunctionClauseError, fn ->
      PriorityArray.pop(%PriorityArray{}, :hello)
    end
  end

  test "to array" do
    assert BACnetArray.from_list([
             +0.0,
             nil,
             nil,
             nil,
             nil,
             1.0,
             nil,
             6.9,
             nil,
             nil,
             nil,
             nil,
             nil,
             nil,
             nil,
             nil
           ]) ==
             PriorityArray.to_array(%PriorityArray{
               priority_1: 0.0,
               priority_6: 1.0,
               priority_8: 6.9
             })
  end

  test "to list" do
    assert [
             +0.0,
             nil,
             nil,
             nil,
             nil,
             1.0,
             nil,
             6.9,
             nil,
             nil,
             nil,
             nil,
             nil,
             nil,
             nil,
             nil
           ] ==
             PriorityArray.to_list(%PriorityArray{
               priority_1: 0.0,
               priority_6: 1.0,
               priority_8: 6.9
             })
  end

  test "valid any type" do
    assert true == PriorityArray.valid?(%PriorityArray{})

    assert true ==
             PriorityArray.valid?(%PriorityArray{
               priority_1: 0.0,
               priority_6: 1.0,
               priority_8: 6.9
             })

    assert true ==
             PriorityArray.valid?(%PriorityArray{
               priority_1: 0,
               priority_6: 1.0,
               priority_8: :hello
             })
  end

  test "valid specific type" do
    assert true == PriorityArray.valid?(%PriorityArray{}, :real)

    assert true ==
             PriorityArray.valid?(
               %PriorityArray{
                 priority_1: 0.0,
                 priority_6: 1.0,
                 priority_8: 6.9
               },
               :real
             )

    assert false ==
             PriorityArray.valid?(
               %PriorityArray{
                 priority_1: 0,
                 priority_6: 1.0,
                 priority_8: :hello
               },
               :real
             )
  end
end
