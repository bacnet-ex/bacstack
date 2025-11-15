defmodule BACnet.Protocol.BACnetArrayTest do
  alias BACnet.Protocol.BACnetArray

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest BACnetArray

  test "new array" do
    assert %BACnetArray{fixed_size: nil, size: 0} = BACnetArray.new()
  end

  test "new array fixed" do
    assert %BACnetArray{fixed_size: 7, size: 7} = BACnetArray.new(7)
  end

  test "new array with default" do
    assert %BACnetArray{fixed_size: nil, size: 0} = array = BACnetArray.new(nil, nil)
    assert nil == BACnetArray.get_default(array)
  end

  test "new array fixed with default" do
    assert %BACnetArray{fixed_size: 7, size: 7} = array = BACnetArray.new(7, true)
    assert true == BACnetArray.get_default(array)
  end

  test "is fixed size array" do
    assert false == BACnetArray.fixed_size?(BACnetArray.new())
    assert true == BACnetArray.fixed_size?(BACnetArray.new(7))
  end

  test "from list array" do
    assert %BACnetArray{size: 3} = arr = BACnetArray.from_list([2, 5, 9])
    assert false == BACnetArray.fixed_size?(arr)
  end

  test "from list fixed array" do
    assert %BACnetArray{fixed_size: 3, size: 3} = arr = BACnetArray.from_list([2, 5, 9], true)
    assert true == BACnetArray.fixed_size?(arr)
  end

  test "from indexed list array" do
    assert %BACnetArray{size: 6} = arr = BACnetArray.from_indexed_list([{1, 2}, {3, 5}, {6, 9}])
    assert false == BACnetArray.fixed_size?(arr)

    assert {:ok, 2} = BACnetArray.get_item(arr, 1)
    assert :error = BACnetArray.get_item(arr, 2)
    assert {:ok, 5} = BACnetArray.get_item(arr, 3)
    assert :error = BACnetArray.get_item(arr, 4)
    assert :error = BACnetArray.get_item(arr, 5)
    assert {:ok, 9} = BACnetArray.get_item(arr, 6)
    assert :error = BACnetArray.get_item(arr, 7)
  end

  test "get default array" do
    assert :undefined == BACnetArray.get_default(BACnetArray.new())
    assert true == BACnetArray.get_default(BACnetArray.new(nil, true))
    assert true == BACnetArray.get_default(BACnetArray.new(7, true))
  end

  test "fetch array" do
    array = BACnetArray.from_list([2, 5, 9])
    assert {:ok, 2} = BACnetArray.fetch(array, 1)
    assert :error = BACnetArray.fetch(array, 4)
    assert_raise FunctionClauseError, fn -> BACnetArray.fetch(array, -1) end
    assert_raise FunctionClauseError, fn -> BACnetArray.fetch(array, 0) end
  end

  test "get item array" do
    array = BACnetArray.from_list([2, 5, 9])
    assert {:ok, 3} = BACnetArray.get_item(array, 0)
    assert {:ok, 2} = BACnetArray.get_item(array, 1)
    assert {:ok, 5} = BACnetArray.get_item(array, 2)
    assert {:ok, 9} = BACnetArray.get_item(array, 3)
    assert :error = BACnetArray.get_item(array, 4)
    assert :error = BACnetArray.get_item(array, 10)
    assert_raise FunctionClauseError, fn -> BACnetArray.get_item(array, -1) end
  end

  test "get item array non-special default" do
    array = BACnetArray.from_list([2, 5, 9], false, nil)
    {:ok, array} = BACnetArray.set_item(array, 4, nil)

    assert {:ok, 4} = BACnetArray.get_item(array, 0)
    assert {:ok, 2} = BACnetArray.get_item(array, 1)
    assert {:ok, 5} = BACnetArray.get_item(array, 2)
    assert {:ok, 9} = BACnetArray.get_item(array, 3)
    assert {:ok, nil} = BACnetArray.get_item(array, 4)
  end

  test "reduce while array" do
    assert :ok =
             BACnetArray.reduce_while(BACnetArray.new(), :ok, fn _val, _acc ->
               raise "Should not have been invoked"
             end)

    assert 10 =
             BACnetArray.reduce_while(BACnetArray.from_list([2, 3, 4]), 1, fn val, acc ->
               {:cont, val + acc}
             end)

    assert 6 =
             BACnetArray.reduce_while(BACnetArray.from_list([2, 3, 4]), 1, fn
               3 = val, acc -> {:halt, val + acc}
               val, acc -> {:cont, val + acc}
             end)
  end

  test "remote item array" do
    array = BACnetArray.from_list([2, 5, 9])
    assert {:error, :invalid_position} = BACnetArray.remove_item(array, 0)
    assert_raise FunctionClauseError, fn -> BACnetArray.remove_item(array, -1) end

    assert {:ok, ^array} = BACnetArray.remove_item(array, 10)
    assert {:ok, %BACnetArray{size: 2} = array} = BACnetArray.remove_item(array, 3)
    assert {:ok, %BACnetArray{size: 1} = array} = BACnetArray.remove_item(array, 2)
    assert {:ok, 2} = BACnetArray.get_item(array, 1)

    array = BACnetArray.from_list([2, 5, 9])
    assert {:ok, %BACnetArray{size: 2} = array} = BACnetArray.remove_item(array, 3)
    assert {:ok, %BACnetArray{size: 2} = array} = BACnetArray.remove_item(array, 1)
    assert {:ok, 5} = BACnetArray.get_item(array, 2)
  end

  test "remote item fixed array" do
    array = BACnetArray.from_list([2, 5, 9], true)

    assert {:error, :invalid_position} = BACnetArray.remove_item(array, 0)
    assert_raise FunctionClauseError, fn -> BACnetArray.remove_item(array, -1) end

    assert {:ok, ^array} = BACnetArray.remove_item(array, 10)
    assert {:ok, %BACnetArray{size: 3} = array} = BACnetArray.remove_item(array, 3)
    assert {:ok, %BACnetArray{size: 3} = array} = BACnetArray.remove_item(array, 1)
    assert {:ok, 5} = BACnetArray.get_item(array, 2)
  end

  test "set item array" do
    array = BACnetArray.new()

    assert {:ok, %BACnetArray{size: 1} = array} = BACnetArray.set_item(array, 1, 5)
    assert {:ok, %BACnetArray{size: 2} = array} = BACnetArray.set_item(array, 2, 553)
    assert {:ok, %BACnetArray{size: 2} = array} = BACnetArray.set_item(array, 2, 52)
    assert {:ok, %BACnetArray{size: 3} = array} = BACnetArray.set_item(array, nil, 99)
    assert [5, 52, 99] = BACnetArray.to_list(array)

    assert {:error, :invalid_position} = BACnetArray.set_item(array, 0, 1)
    assert {:error, :invalid_position} = BACnetArray.set_item(array, 5, 1)
    assert_raise FunctionClauseError, fn -> BACnetArray.set_item(array, -1, 1) end
  end

  test "set item array fixed" do
    array = BACnetArray.new(3)

    assert {:ok, %BACnetArray{size: 3} = array} = BACnetArray.set_item(array, 1, 5)
    assert {:ok, %BACnetArray{size: 3} = array} = BACnetArray.set_item(array, 2, 553)
    assert {:ok, %BACnetArray{size: 3} = array} = BACnetArray.set_item(array, 2, 52)
    assert {:error, :array_full} = BACnetArray.set_item(array, nil, 991)
    assert {:ok, %BACnetArray{size: 3} = array} = BACnetArray.set_item(array, 3, 99)
    assert {:error, :array_full} = BACnetArray.set_item(array, nil, 992)
    assert [5, 52, 99] = BACnetArray.to_list(array)
  end

  test "size array" do
    assert 0 == BACnetArray.size(BACnetArray.new())
    assert 3 == BACnetArray.size(BACnetArray.new(3))
    assert 5 == BACnetArray.size(BACnetArray.from_list([5, 6, 8, 23, 51]))
  end

  test "to list array" do
    array = BACnetArray.from_list([1, 3, 6, 9, 12])
    assert [1, 3, 6, 9, 12] = BACnetArray.to_list(array)

    array = BACnetArray.from_list([1, 3, 6, 9, 12], true)
    {:ok, array} = BACnetArray.remove_item(array, 3)
    assert [1, 3, :undefined, 9, 12] = BACnetArray.to_list(array)
  end

  test "truncate array" do
    arr = :array.new()

    assert %BACnetArray{size: 0, items: ^arr} =
             BACnetArray.truncate(BACnetArray.from_list([1, 3, 6, 9, 12]))
  end

  test "valid array" do
    array = BACnetArray.from_list([1, 3, 6, 9, 12])
    assert true == BACnetArray.valid?(array)
    assert true == BACnetArray.valid?(array, :signed_integer)
    assert false == BACnetArray.valid?(array, :real)
  end

  test "valid array fixed" do
    array = BACnetArray.from_list([1, 3, 6, 9, 12], true)
    {:ok, array} = BACnetArray.remove_item(array, 3)

    assert true == BACnetArray.valid?(array)
    assert true == BACnetArray.valid?(array, :signed_integer)
    assert false == BACnetArray.valid?(array, :real)
  end
end
