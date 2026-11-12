defmodule BACnet.Stack.LogBufferTest do
  alias BACnet.Stack.LogBuffer
  alias BACnet.Stack.LogBufferBehaviour

  use BACnet.Test.Stack.Case, async: true

  @moduletag :stack
  @moduletag :log_buffer

  test "LogBuffer implements every LogBufferBehaviour callback" do
    Code.ensure_loaded!(LogBuffer)
    callbacks = LogBufferBehaviour.behaviour_info(:callbacks)

    assert callbacks != []

    for {name, arity} <- callbacks do
      assert function_exported?(LogBuffer, name, arity)
    end
  end

  test "new/0 is an empty buffer without a limit" do
    buffer = LogBuffer.new()

    assert LogBuffer.get_size(buffer) == 0
    assert LogBuffer.to_list(buffer) == []
    assert LogBuffer.peek(buffer) == :error
    assert LogBuffer.peek_r(buffer) == :error
    assert {nil, buffer} = LogBuffer.checkout(buffer)
    assert LogBuffer.get_size(buffer) == 0
  end

  test "get_max_size returns nil for unbounded buffers" do
    assert LogBuffer.get_max_size(LogBuffer.new()) == nil
    assert LogBuffer.get_max_size(LogBuffer.new(nil)) == nil
    assert LogBuffer.get_max_size(LogBuffer.from_list([])) == nil
    assert LogBuffer.get_max_size(LogBuffer.from_list([1, 2, 3])) == nil

    buffer = LogBuffer.new()
    buffer = LogBuffer.checkin(buffer, :record)
    assert LogBuffer.get_max_size(buffer) == nil
    assert LogBuffer.get_max_size(LogBuffer.truncate(buffer)) == nil
  end

  test "get_max_size returns the configured limit independently of the current size" do
    assert LogBuffer.get_max_size(LogBuffer.new(1)) == 1
    assert LogBuffer.get_max_size(LogBuffer.new(5)) == 5
    assert LogBuffer.get_max_size(LogBuffer.from_list([], 5)) == 5
    assert LogBuffer.get_max_size(LogBuffer.from_list([1, 2], 5)) == 5
    assert LogBuffer.get_max_size(LogBuffer.from_list([1, 2, 3], 3)) == 3
    assert LogBuffer.get_max_size(LogBuffer.from_list([1, 2, 3, 4], 3)) == 3
  end

  test "get_max_size is preserved by overflow, checkout, drop and truncate" do
    buffer = LogBuffer.from_list([1, 2, 3], 3)
    buffer = LogBuffer.checkin(buffer, 4)
    assert LogBuffer.get_max_size(buffer) == 3

    assert {2, buffer} = LogBuffer.checkout(buffer)
    assert LogBuffer.get_max_size(buffer) == 3

    buffer = LogBuffer.drop(buffer)
    assert LogBuffer.get_max_size(buffer) == 3
    assert LogBuffer.get_max_size(LogBuffer.drop(buffer, 100)) == 3
    assert LogBuffer.get_max_size(LogBuffer.truncate(buffer)) == 3
  end

  test "checkin keeps insertion order and checkout removes the oldest item" do
    buffer =
      LogBuffer.new()
      |> LogBuffer.checkin(1)
      |> LogBuffer.checkin(2)
      |> LogBuffer.checkin(3)

    assert LogBuffer.get_size(buffer) == 3
    assert LogBuffer.to_list(buffer) == [1, 2, 3]
    assert LogBuffer.peek(buffer) == {:ok, 1}
    assert LogBuffer.peek_r(buffer) == {:ok, 3}
    assert LogBuffer.get_size(buffer) == 3

    {oldest, buffer} = LogBuffer.checkout(buffer)
    assert oldest == 1
    assert LogBuffer.to_list(buffer) == [2, 3]
    assert LogBuffer.get_size(buffer) == 2
    assert LogBuffer.peek(buffer) == {:ok, 2}
    assert LogBuffer.peek_r(buffer) == {:ok, 3}
  end

  test "a max size drops the oldest item when the buffer overflows" do
    buffer = Enum.reduce([1, 2], LogBuffer.new(2), &LogBuffer.checkin(&2, &1))

    assert LogBuffer.to_list(buffer) == [1, 2]
    assert LogBuffer.get_size(buffer) == 2

    buffer = LogBuffer.checkin(buffer, 3)

    assert LogBuffer.get_size(buffer) == 2
    assert LogBuffer.to_list(buffer) == [2, 3]
    assert LogBuffer.peek(buffer) == {:ok, 2}
    assert LogBuffer.peek_r(buffer) == {:ok, 3}
  end

  test "new/1 accepts a max size of one" do
    buffer = LogBuffer.new(1)

    buffer =
      buffer
      |> LogBuffer.checkin(:first)
      |> LogBuffer.checkin(:second)

    assert LogBuffer.to_list(buffer) == [:second]
    assert LogBuffer.get_size(buffer) == 1
  end

  test "drop removes the oldest items and truncate clears the buffer" do
    buffer = LogBuffer.from_list([1, 2, 3, 4])

    assert LogBuffer.to_list(LogBuffer.drop(buffer)) == [2, 3, 4]
    assert LogBuffer.get_size(LogBuffer.drop(buffer, 2)) == 2
    assert LogBuffer.to_list(LogBuffer.drop(buffer, 2)) == [3, 4]

    assert LogBuffer.to_list(LogBuffer.drop(buffer, 4)) == []
    assert LogBuffer.get_size(LogBuffer.drop(buffer, 4)) == 0
    assert LogBuffer.to_list(LogBuffer.drop(buffer, 9)) == []

    truncated = LogBuffer.truncate(buffer)
    assert LogBuffer.to_list(truncated) == []
    assert LogBuffer.get_size(truncated) == 0
    assert LogBuffer.peek(truncated) == :error
    assert LogBuffer.peek_r(truncated) == :error
  end

  test "from_list keeps the head as the oldest item and trims to the max size" do
    assert LogBuffer.to_list(LogBuffer.from_list([])) == []
    assert LogBuffer.to_list(LogBuffer.from_list([1, 2, 3])) == [1, 2, 3]
    assert LogBuffer.get_size(LogBuffer.from_list([1, 2, 3], 3)) == 3
    assert LogBuffer.to_list(LogBuffer.from_list([1, 2], 5)) == [1, 2]

    trimmed = LogBuffer.from_list([1, 2, 3, 4, 5], 3)
    assert LogBuffer.to_list(trimmed) == [3, 4, 5]
    assert LogBuffer.get_size(trimmed) == 3
    assert LogBuffer.peek(trimmed) == {:ok, 3}
    assert LogBuffer.peek_r(trimmed) == {:ok, 5}

    only = LogBuffer.from_list([1, 2, 3], 1)
    assert LogBuffer.to_list(only) == [3]
  end

  test "truncate keeps the configured max size" do
    buffer = LogBuffer.from_list([1, 2, 3], 2)
    assert LogBuffer.to_list(buffer) == [2, 3]

    truncated = LogBuffer.truncate(buffer)
    assert LogBuffer.get_size(truncated) == 0

    refilled =
      truncated
      |> LogBuffer.checkin(8)
      |> LogBuffer.checkin(9)
      |> LogBuffer.checkin(10)

    assert LogBuffer.to_list(refilled) == [9, 10]
  end

  test "read_range slices from the oldest item" do
    buffer = LogBuffer.from_list([1, 2, 3, 4, 5])

    assert LogBuffer.read_range(buffer, 2) == [1, 2]
    assert LogBuffer.read_range(buffer, 1, 2) == [2, 3]
    assert LogBuffer.read_range(buffer, 3, 10) == [4, 5]
    assert LogBuffer.read_range(buffer, 5, 1) == []
    assert LogBuffer.read_range(buffer, 0, 1) == [1]
  end

  test "read_range returns an empty list for empty buffers and offsets past the end" do
    empty = LogBuffer.new()
    assert LogBuffer.read_range(empty, 1) == []
    assert LogBuffer.read_range(empty, 0, 10) == []
    assert LogBuffer.read_range(empty, 10, 1) == []

    buffer = LogBuffer.from_list([1, 2, 3])
    assert LogBuffer.read_range(buffer, 3, 1) == []
    assert LogBuffer.read_range(buffer, 3, 10) == []
    assert LogBuffer.read_range(buffer, 100, 1) == []
  end

  test "read_range reads single oldest and newest items from a list-built buffer" do
    buffer = LogBuffer.from_list([1, 2, 3, 4, 5])

    assert LogBuffer.read_range(buffer, 1) == [1]
    assert LogBuffer.read_range(buffer, 4, 1) == [5]
    assert LogBuffer.read_range(buffer, 4, 10) == [5]
    assert LogBuffer.to_list(buffer) == [1, 2, 3, 4, 5]
    assert LogBuffer.get_size(buffer) == 5
  end

  test "read_range reads single oldest and newest items after appending and overflow" do
    buffer = Enum.reduce(1..5, LogBuffer.new(3), &LogBuffer.checkin(&2, &1))

    assert LogBuffer.read_range(buffer, 1) == [3]
    assert LogBuffer.read_range(buffer, 2, 1) == [5]
    assert LogBuffer.read_range(buffer, 2, 10) == [5]
    assert LogBuffer.read_range(buffer, 1, 1) == [4]
    assert LogBuffer.read_range(buffer, 1, 10) == [4, 5]
    assert LogBuffer.to_list(buffer) == [3, 4, 5]
  end

  test "read_range handles a single-item buffer and a clipped count" do
    buffer = LogBuffer.from_list([:only])

    assert LogBuffer.read_range(buffer, 1) == [:only]
    assert LogBuffer.read_range(buffer, 0, 10) == [:only]
    assert LogBuffer.read_range(buffer, 1, 1) == []

    assert {:only, empty} = LogBuffer.checkout(buffer)
    assert LogBuffer.read_range(empty, 1) == []
  end

  test "read_range preserves nil and false items at the ends" do
    buffer = LogBuffer.from_list([nil, :middle, false])

    assert LogBuffer.read_range(buffer, 1) == [nil]
    assert LogBuffer.read_range(buffer, 2, 1) == [false]
    assert LogBuffer.read_range(buffer, 2, 10) == [false]
  end

  test "read_range rejects invalid arguments even for boundary reads" do
    buffer = LogBuffer.from_list([1, 2, 3])
    empty = LogBuffer.new()

    assert_raise FunctionClauseError, fn -> LogBuffer.read_range(buffer, -1, 1) end
    assert_raise FunctionClauseError, fn -> LogBuffer.read_range(buffer, 0.5, 1) end
    assert_raise FunctionClauseError, fn -> LogBuffer.read_range(buffer, 0, 0) end
    assert_raise FunctionClauseError, fn -> LogBuffer.read_range(buffer, 2, -1) end
    assert_raise FunctionClauseError, fn -> LogBuffer.read_range(buffer, 2, 1.5) end
    assert_raise FunctionClauseError, fn -> LogBuffer.read_range(buffer, 3, 0) end
    assert_raise FunctionClauseError, fn -> LogBuffer.read_range(empty, 0, 0) end
  end

  test "items pass through unchanged" do
    item = {:log_record, 23.4}
    buffer = LogBuffer.checkin(LogBuffer.new(), item)

    assert LogBuffer.peek(buffer) == {:ok, item}
    assert {^item, empty} = LogBuffer.checkout(buffer)
    assert LogBuffer.to_list(empty) == []
  end
end
