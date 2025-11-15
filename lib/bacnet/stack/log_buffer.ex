defmodule BACnet.Stack.LogBuffer do
  @moduledoc """
  Simple log buffer implementation for event and trend logs.
  The type of the item is not enforced.

  The log buffer can maintain a maximum buffer size by dropping the oldest item
  on overflow (ring buffer).
  """

  alias BACnet.Protocol.EventLogRecord
  alias BACnet.Protocol.LogMultipleRecord
  alias BACnet.Protocol.LogRecord

  @behaviour BACnet.Stack.LogBufferBehaviour

  @typedoc """
  Log buffer item type.
  """
  @type item :: EventLogRecord.t() | LogRecord.t() | LogMultipleRecord.t()

  @typedoc """
  Implementation detail and thus private API. Changes to it do not count
  towards Semantic Versioning.
  """
  @opaque items :: :queue.queue(item())

  @typedoc """
  Representative type for the log buffer.
  """
  @type t :: %__MODULE__{
          items: items(),
          max_size: pos_integer() | nil,
          size: non_neg_integer()
        }

  @fields [:items, :max_size, :size]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Creates a new log buffer with an optional max size.
  """
  @spec new(pos_integer() | nil) :: t()
  def new(max_size \\ nil) when is_nil(max_size) or (is_integer(max_size) and max_size >= 1) do
    %__MODULE__{
      items: :queue.new(),
      max_size: max_size,
      size: 0
    }
  end

  @doc """
  Checks in an item.

  If the log buffer has a max size, the max size will be maintained (meaning
  the oldest item gets dropped on overflow).
  """
  @spec checkin(t(), item()) :: t()
  def checkin(%__MODULE__{} = buffer, item) do
    middle_queue = :queue.in(item, buffer.items)

    {new_queue, new_size} =
      case %{buffer | size: buffer.size + 1} do
        %{max_size: nil, size: size} -> {middle_queue, size}
        %{max_size: max, size: size} when size > max -> {:queue.drop(middle_queue), buffer.size}
        %{size: size} -> {middle_queue, size}
      end

    %__MODULE__{buffer | items: new_queue, size: new_size}
  end

  @doc """
  Checks out the oldest item in the log buffer.

  If the log buffer is empty, `nil` will be returned as item.
  """
  @spec checkout(t()) :: {item :: item() | nil, new_buffer :: t()}
  def checkout(%__MODULE__{} = buffer) do
    {item, new_queue, new_size} =
      case :queue.out(buffer.items) do
        {{:value, item}, q2} -> {item, q2, buffer.size - 1}
        {:empty, q1} -> {nil, q1, buffer.size}
      end

    {item, %__MODULE__{buffer | items: new_queue, size: new_size}}
  end

  @doc """
  Drops the specified amount of oldest items from the log buffer.
  """
  @spec drop(t(), pos_integer()) :: t()
  def drop(buffer, amount \\ 1)

  def drop(%__MODULE__{size: size} = buffer, amount) when is_integer(amount) and amount >= size do
    truncate(buffer)
  end

  def drop(%__MODULE__{} = buffer, amount) when is_integer(amount) and amount >= 1 do
    %__MODULE__{
      buffer
      | items:
          Enum.reduce(1..min(amount, buffer.size)//1, buffer.items, fn _index, acc ->
            :queue.drop(acc)
          end),
        size: max(0, buffer.size - amount)
    }
  end

  @doc """
  Creates a new log buffer from the given list, with an optional max size.
  The head of the list will be the oldest entry in the log buffer.

  If a max size is specified, the list will be truncated to the max size (from the end).
  The queue length will be calculated in any case. This operation is O(n).
  """
  @spec from_list(list(), pos_integer() | nil) :: t()
  def from_list(list, max_size \\ nil)
      when (is_list(list) and is_nil(max_size)) or (is_integer(max_size) and max_size >= 1) do
    buffer =
      list
      |> then(fn list ->
        if max_size do
          list
          |> Enum.reverse()
          |> Enum.take(max_size)
          |> Enum.reverse()
        else
          list
        end
      end)
      |> :queue.from_list()

    %__MODULE__{
      items: buffer,
      max_size: max_size,
      size: :queue.len(buffer)
    }
  end

  @doc """
  Get the size of the log buffer.
  """
  @spec get_size(t()) :: non_neg_integer()
  def get_size(%__MODULE__{size: size} = _buffer) do
    size
  end

  @doc """
  Peeks into the log buffer and returns the oldest item without removing it.
  """
  @spec peek(t()) :: {:ok, item()} | :error
  def peek(%__MODULE__{} = buffer) do
    case :queue.peek(buffer.items) do
      {:value, item} -> {:ok, item}
      :empty -> :error
    end
  end

  @doc """
  Peeks into the log buffer and returns the newest item without removing it.
  """
  @spec peek_r(t()) :: {:ok, item()} | :error
  def peek_r(%__MODULE__{} = buffer) do
    case :queue.peek_r(buffer.items) do
      {:value, item} -> {:ok, item}
      :empty -> :error
    end
  end

  @doc """
  Reads the specified count, starting from the given position (offset), from the log buffer.
  """
  @spec read_range(t(), non_neg_integer(), pos_integer()) :: [item()]
  def read_range(%__MODULE__{} = buffer, offset \\ 0, count)
      when is_integer(offset) and offset >= 0 and is_integer(count) and count >= 1 do
    Enum.slice(:queue.to_list(buffer.items), offset, count)
  end

  @doc """
  Creates a list from the log buffer.
  """
  @spec to_list(t()) :: [item()]
  def to_list(%__MODULE__{} = buffer) do
    :queue.to_list(buffer.items)
  end

  @doc """
  Truncates the log buffer to size zero.
  """
  @spec truncate(t()) :: t()
  def truncate(%__MODULE__{} = buffer) do
    %__MODULE__{buffer | items: :queue.new(), size: 0}
  end
end
