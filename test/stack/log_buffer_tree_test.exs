defmodule BACnet.Stack.LogBufferTreeTest do
  alias BACnet.Stack.LogBufferBehaviour
  alias BACnet.Stack.LogBufferTree

  use BACnet.Test.Stack.Case, async: true

  @moduletag :stack
  @moduletag :log_buffer

  test "implements every LogBufferBehaviour callback" do
    Code.ensure_loaded!(LogBufferTree)

    for {name, arity} <- LogBufferBehaviour.behaviour_info(:callbacks) do
      assert function_exported?(LogBufferTree, name, arity)
    end
  end

  test "new creates an empty unbounded buffer" do
    buffer = LogBufferTree.new()

    assert buffer.max_size == nil
    assert LogBufferTree.get_size(buffer) == 0
    assert LogBufferTree.to_list(buffer) == []
    assert LogBufferTree.peek(buffer) == :error
    assert LogBufferTree.peek_r(buffer) == :error
    assert LogBufferTree.checkout(buffer) == {nil, buffer}
    assert LogBufferTree.read_range(buffer, 1) == []
    assert LogBufferTree.drop(buffer) == buffer
    assert LogBufferTree.new(nil) == buffer
  end

  test "get_max_size returns nil for unbounded buffers" do
    assert LogBufferTree.get_max_size(LogBufferTree.new()) == nil
    assert LogBufferTree.get_max_size(LogBufferTree.new(nil)) == nil
    assert LogBufferTree.get_max_size(LogBufferTree.from_list([])) == nil
    assert LogBufferTree.get_max_size(LogBufferTree.from_list([1, 2, 3])) == nil

    buffer = LogBufferTree.new()
    buffer = LogBufferTree.checkin(buffer, :record)
    assert LogBufferTree.get_max_size(buffer) == nil
    assert LogBufferTree.get_max_size(LogBufferTree.truncate(buffer)) == nil
  end

  test "get_max_size returns the configured limit independently of the current size" do
    assert LogBufferTree.get_max_size(LogBufferTree.new(1)) == 1
    assert LogBufferTree.get_max_size(LogBufferTree.new(5)) == 5
    assert LogBufferTree.get_max_size(LogBufferTree.from_list([], 5)) == 5
    assert LogBufferTree.get_max_size(LogBufferTree.from_list([1, 2], 5)) == 5
    assert LogBufferTree.get_max_size(LogBufferTree.from_list([1, 2, 3], 3)) == 3
    assert LogBufferTree.get_max_size(LogBufferTree.from_list([1, 2, 3, 4], 3)) == 3
  end

  test "get_max_size is preserved by overflow, checkout, drop and truncate" do
    buffer = LogBufferTree.from_list([1, 2, 3], 3)
    buffer = LogBufferTree.checkin(buffer, 4)
    assert LogBufferTree.get_max_size(buffer) == 3

    assert {2, buffer} = LogBufferTree.checkout(buffer)
    assert LogBufferTree.get_max_size(buffer) == 3

    buffer = LogBufferTree.drop(buffer)
    assert LogBufferTree.get_max_size(buffer) == 3
    assert LogBufferTree.get_max_size(LogBufferTree.drop(buffer, 100)) == 3
    assert LogBufferTree.get_max_size(LogBufferTree.truncate(buffer)) == 3
  end

  test "constructors reject invalid capacities and non-list sources" do
    assert_raise FunctionClauseError, fn -> LogBufferTree.new(0) end
    assert_raise FunctionClauseError, fn -> LogBufferTree.new(-1) end
    assert_raise FunctionClauseError, fn -> LogBufferTree.new(1.5) end
    assert_raise FunctionClauseError, fn -> LogBufferTree.from_list([1], 0) end
    assert_raise FunctionClauseError, fn -> LogBufferTree.from_list([1], -1) end
    assert_raise FunctionClauseError, fn -> LogBufferTree.from_list(:invalid, 2) end
  end

  test "checkin retains insertion order and checkout removes the oldest item" do
    original = LogBufferTree.new()

    buffer =
      original
      |> LogBufferTree.checkin(:first)
      |> LogBufferTree.checkin(:second)
      |> LogBufferTree.checkin(:third)

    assert LogBufferTree.get_size(buffer) == 3
    assert LogBufferTree.to_list(buffer) == [:first, :second, :third]
    assert LogBufferTree.peek(buffer) == {:ok, :first}
    assert LogBufferTree.peek_r(buffer) == {:ok, :third}
    assert LogBufferTree.to_list(original) == []

    assert {:first, remaining} = LogBufferTree.checkout(buffer)
    assert LogBufferTree.to_list(remaining) == [:second, :third]
    assert LogBufferTree.get_size(remaining) == 2
    assert LogBufferTree.peek(remaining) == {:ok, :second}
    assert LogBufferTree.peek_r(remaining) == {:ok, :third}
    assert LogBufferTree.to_list(buffer) == [:first, :second, :third]
  end

  test "bounded buffers drop only the oldest item on overflow" do
    original = LogBufferTree.from_list([1, 2, 3], 3)
    buffer = Enum.reduce(4..20, original, &LogBufferTree.checkin(&2, &1))

    assert LogBufferTree.get_size(buffer) == 3
    assert LogBufferTree.to_list(buffer) == [18, 19, 20]
    assert LogBufferTree.peek(buffer) == {:ok, 18}
    assert LogBufferTree.peek_r(buffer) == {:ok, 20}
    assert LogBufferTree.read_range(buffer, 0, 10) == [18, 19, 20]
    assert LogBufferTree.read_range(buffer, 1, 2) == [19, 20]
    assert LogBufferTree.to_list(original) == [1, 2, 3]
  end

  test "a capacity of one supports repeated overflow and checkout" do
    buffer = LogBufferTree.new(1)
    buffer = buffer |> LogBufferTree.checkin(1) |> LogBufferTree.checkin(2)

    assert LogBufferTree.to_list(buffer) == [2]
    assert LogBufferTree.get_size(buffer) == 1
    assert LogBufferTree.read_range(buffer, 1) == [2]
    assert {2, empty} = LogBufferTree.checkout(buffer)
    assert LogBufferTree.get_size(empty) == 0
    assert LogBufferTree.peek(empty) == :error
    assert LogBufferTree.peek_r(empty) == :error

    refilled = empty |> LogBufferTree.checkin(3) |> LogBufferTree.checkin(4)
    assert LogBufferTree.to_list(refilled) == [4]
  end

  test "from_list retains the newest items within its capacity" do
    assert LogBufferTree.to_list(LogBufferTree.from_list([])) == []
    assert LogBufferTree.to_list(LogBufferTree.from_list([], 3)) == []
    assert LogBufferTree.to_list(LogBufferTree.from_list([1, 2, 3])) == [1, 2, 3]
    assert LogBufferTree.to_list(LogBufferTree.from_list([1, 2], 5)) == [1, 2]

    buffer = LogBufferTree.from_list([1, 2, 3, 4, 5], 3)

    assert buffer.max_size == 3
    assert LogBufferTree.get_size(buffer) == 3
    assert LogBufferTree.peek(buffer) == {:ok, 3}
    assert LogBufferTree.peek_r(buffer) == {:ok, 5}
    assert LogBufferTree.read_range(buffer, 5) == [3, 4, 5]
    assert LogBufferTree.to_list(LogBufferTree.checkin(buffer, 6)) == [4, 5, 6]
    assert LogBufferTree.to_list(LogBufferTree.from_list([1, 2, 3], 1)) == [3]
  end

  test "drop removes the oldest items without reusing their keys" do
    original = LogBufferTree.from_list([1, 2, 3, 4, 5], 5)
    buffer = LogBufferTree.drop(original, 2)

    assert LogBufferTree.to_list(LogBufferTree.drop(original)) == [2, 3, 4, 5]
    assert LogBufferTree.get_size(buffer) == 3
    assert LogBufferTree.peek(buffer) == {:ok, 3}
    assert LogBufferTree.read_range(buffer, 1, 9) == [4, 5]

    buffer = buffer |> LogBufferTree.checkin(6) |> LogBufferTree.checkin(7)
    assert LogBufferTree.to_list(buffer) == [3, 4, 5, 6, 7]
    assert LogBufferTree.to_list(LogBufferTree.checkin(buffer, 8)) == [4, 5, 6, 7, 8]
    assert LogBufferTree.to_list(original) == [1, 2, 3, 4, 5]
  end

  test "drop at or beyond the size clears the buffer and preserves its capacity" do
    buffer = LogBufferTree.from_list([1, 2, 3], 3)

    assert LogBufferTree.to_list(LogBufferTree.drop(buffer, 3)) == []
    assert LogBufferTree.to_list(LogBufferTree.drop(buffer, 100)) == []
    assert LogBufferTree.get_size(LogBufferTree.drop(buffer, 100)) == 0

    refilled =
      buffer
      |> LogBufferTree.drop(100)
      |> LogBufferTree.checkin(4)
      |> LogBufferTree.checkin(5)
      |> LogBufferTree.checkin(6)
      |> LogBufferTree.checkin(7)

    assert refilled.max_size == 3
    assert LogBufferTree.to_list(refilled) == [5, 6, 7]
  end

  test "truncate preserves the capacity, key counter and earlier snapshots" do
    original = LogBufferTree.from_list([1, 2, 3], 2)
    empty = LogBufferTree.truncate(original)

    assert empty.max_size == 2
    assert empty.next_key == original.next_key
    assert LogBufferTree.get_size(empty) == 0
    assert LogBufferTree.to_list(empty) == []
    assert LogBufferTree.read_range(empty, 0, 1) == []
    assert LogBufferTree.peek(empty) == :error
    assert LogBufferTree.peek_r(empty) == :error
    assert LogBufferTree.checkout(empty) == {nil, empty}

    refilled =
      empty |> LogBufferTree.checkin(8) |> LogBufferTree.checkin(9) |> LogBufferTree.checkin(10)

    assert LogBufferTree.to_list(refilled) == [9, 10]
    assert LogBufferTree.to_list(original) == [2, 3]
  end

  test "read_range uses offsets from the oldest retained item and clips its count" do
    buffer = LogBufferTree.from_list([1, 2, 3, 4, 5])

    assert LogBufferTree.read_range(buffer, 2) == [1, 2]
    assert LogBufferTree.read_range(buffer, 1, 2) == [2, 3]
    assert LogBufferTree.read_range(buffer, 3, 10) == [4, 5]
    assert LogBufferTree.read_range(buffer, 4, 1) == [5]
    assert LogBufferTree.read_range(buffer, 5, 1) == []
    assert LogBufferTree.read_range(buffer, 100, 1) == []
  end

  test "read_range rejects negative offsets and non-positive counts" do
    buffer = LogBufferTree.from_list([1, 2])

    assert_raise FunctionClauseError, fn -> LogBufferTree.read_range(buffer, -1, 1) end
    assert_raise FunctionClauseError, fn -> LogBufferTree.read_range(buffer, 0, 0) end
    assert_raise FunctionClauseError, fn -> LogBufferTree.read_range(buffer, 0, -1) end
    assert_raise FunctionClauseError, fn -> LogBufferTree.read_range(buffer, 0.5, 1) end
    assert_raise FunctionClauseError, fn -> LogBufferTree.read_range(buffer, 0, 1.5) end
  end

  test "nil, false and duplicate values pass through unchanged" do
    items = [nil, false, {:record, 23.4}, {:record, 23.4}, nil]
    buffer = LogBufferTree.from_list(items)

    assert LogBufferTree.to_list(buffer) == items
    assert LogBufferTree.read_range(buffer, 10) == items
    assert LogBufferTree.peek(buffer) == {:ok, nil}
    assert LogBufferTree.peek_r(buffer) == {:ok, nil}
    assert {nil, remaining} = LogBufferTree.checkout(buffer)
    assert LogBufferTree.get_size(remaining) == 4
    assert LogBufferTree.peek(remaining) == {:ok, false}
  end

  test "internal keys continue beyond the BACnet sequence-number limit" do
    buffer = %LogBufferTree{
      items: :gb_trees.from_orddict([{4_294_967_294, :first}, {4_294_967_295, :second}]),
      max_size: 2,
      size: 2,
      next_key: 4_294_967_296
    }

    buffer = buffer |> LogBufferTree.checkin(:third) |> LogBufferTree.checkin(:fourth)

    assert LogBufferTree.to_list(buffer) == [:third, :fourth]
    assert LogBufferTree.read_range(buffer, 0, 10) == [:third, :fourth]
    assert LogBufferTree.peek(buffer) == {:ok, :third}
    assert LogBufferTree.peek_r(buffer) == {:ok, :fourth}
  end

  test "a full paginated scan after extensive overflow preserves every retained record" do
    buffer = Enum.reduce(1..10_000, LogBufferTree.new(1_000), &LogBufferTree.checkin(&2, &1))

    pages = Enum.flat_map(0..9, &LogBufferTree.read_range(buffer, &1 * 100, 100))

    assert pages == Enum.to_list(9_001..10_000)
    assert pages == LogBufferTree.to_list(buffer)
    assert LogBufferTree.get_size(buffer) == 1_000
  end

  test "bounded mixed operations match a list model" do
    check_operations(7)
  end

  test "unbounded mixed operations match a list model" do
    check_operations(nil)
  end

  defp check_operations(capacity) do
    Enum.reduce(1..300, {LogBufferTree.new(capacity), []}, fn index, {buffer, expected} ->
      {updated, items} =
        case rem(index, 17) do
          0 ->
            {LogBufferTree.truncate(buffer), []}

          1 ->
            {LogBufferTree.drop(buffer, 2), Enum.drop(expected, 2)}

          2 ->
            {item, updated} = LogBufferTree.checkout(buffer)
            {expected_item, items} = List.pop_at(expected, 0)
            assert item == expected_item
            {updated, items}

          _other ->
            item = if rem(index, 3) == 0, do: nil, else: rem(index, 5)
            items = expected ++ [item]
            items = if capacity == nil, do: items, else: Enum.take(items, -capacity)
            {LogBufferTree.checkin(buffer, item), items}
        end

      assert LogBufferTree.to_list(updated) == items
      assert LogBufferTree.get_size(updated) == length(items)
      assert LogBufferTree.read_range(updated, 2, 5) == Enum.slice(items, 2, 5)
      assert LogBufferTree.peek(updated) == if(items == [], do: :error, else: {:ok, hd(items)})

      assert LogBufferTree.peek_r(updated) ==
               if(items == [], do: :error, else: {:ok, List.last(items)})

      assert LogBufferTree.to_list(buffer) == expected

      {updated, items}
    end)
  end
end
