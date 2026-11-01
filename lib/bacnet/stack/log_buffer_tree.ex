defmodule BACnet.Stack.LogBufferTree do
  @moduledoc """
  Log buffer backed by an ordered tree with monotonic integer keys.
  The type of the item is not enforced.

  Like `BACnet.Stack.LogBuffer`, this buffer retains insertion order and can
  discard the oldest item on overflow. It favors range reads and ordered scans:
  `read_range/3` seeks to the first requested record and iterates only the
  requested portion, while `to_list/1` traverses the tree in order.

  Keys are private to the buffer and independent of BACnet sequence numbers and
  timestamps. Removing items does not reuse their keys. Earlier buffer values
  remain valid snapshots after appending, dropping or truncating records.

  Select this implementation with `log_buffer_module: BACnet.Stack.LogBufferTree`
  when starting `BACnet.Stack.TrendLogger`.
  """

  alias BACnet.Protocol.EventLogRecord
  alias BACnet.Protocol.LogMultipleRecord
  alias BACnet.Protocol.LogRecord

  @behaviour BACnet.Stack.LogBufferBehaviour

  @typedoc """
  Log buffer item type. Items pass through unchanged.
  """
  @type item :: EventLogRecord.t() | LogRecord.t() | LogMultipleRecord.t()

  @typedoc """
  Private storage representation.
  """
  @opaque items :: :gb_trees.tree(non_neg_integer(), item())

  @typedoc """
  Representative type for the log buffer.
  """
  @type t :: %__MODULE__{
          items: items(),
          max_size: pos_integer() | nil,
          size: non_neg_integer(),
          next_key: non_neg_integer()
        }

  @fields [:items, :max_size, :size, :next_key]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Creates an empty buffer with an optional maximum size.
  """
  @spec new(pos_integer() | nil) :: t()
  def new(max_size \\ nil) when is_nil(max_size) or (is_integer(max_size) and max_size >= 1) do
    %__MODULE__{items: :gb_trees.empty(), max_size: max_size, size: 0, next_key: 0}
  end

  @doc """
  Appends an item, dropping the oldest item if the buffer is already full.
  """
  @spec checkin(t(), item()) :: t()
  def checkin(%__MODULE__{} = buffer, item) do
    {items, size} =
      if buffer.max_size != nil and buffer.size == buffer.max_size do
        {:gb_trees.delete(buffer.next_key - buffer.size, buffer.items), buffer.size}
      else
        {buffer.items, buffer.size + 1}
      end

    %__MODULE__{
      buffer
      | items: :gb_trees.insert(buffer.next_key, item, items),
        size: size,
        next_key: buffer.next_key + 1
    }
  end

  @doc """
  Removes and returns the oldest item, or returns `nil` for an empty buffer.
  """
  @spec checkout(t()) :: {item() | nil, t()}
  def checkout(%__MODULE__{size: 0} = buffer), do: {nil, buffer}

  def checkout(%__MODULE__{} = buffer) do
    {_key, item, items} = :gb_trees.take_smallest(buffer.items)
    {item, %__MODULE__{buffer | items: items, size: buffer.size - 1}}
  end

  @doc """
  Drops the specified number of oldest items, or clears the buffer if fewer remain.
  """
  @spec drop(t(), pos_integer()) :: t()
  def drop(buffer, amount \\ 1)

  def drop(%__MODULE__{} = buffer, amount) when is_integer(amount) and amount >= 1 do
    if amount >= buffer.size do
      truncate(buffer)
    else
      oldest_key = buffer.next_key - buffer.size

      items =
        Enum.reduce(oldest_key..(oldest_key + amount - 1), buffer.items, fn key, items ->
          :gb_trees.delete(key, items)
        end)

      %__MODULE__{buffer | items: items, size: buffer.size - amount}
    end
  end

  @doc """
  Creates a buffer from a list, whose head is the oldest item.

  If a maximum size is specified, only the newest items fitting that size are
  retained. Building the buffer takes O(n) time.
  """
  @spec from_list(list(), pos_integer() | nil) :: t()
  def from_list(list, max_size \\ nil)
      when is_list(list) and (is_nil(max_size) or (is_integer(max_size) and max_size >= 1)) do
    length = length(list)
    retained = if max_size == nil, do: list, else: Enum.drop(list, max(0, length - max_size))
    pairs = Enum.with_index(retained, fn item, index -> {index, item} end)
    size = if max_size == nil, do: length, else: min(length, max_size)

    %__MODULE__{
      items: :gb_trees.from_orddict(pairs),
      max_size: max_size,
      size: size,
      next_key: size
    }
  end

  @doc """
  Get the maximum size of the log buffer.
  """
  @spec get_max_size(t()) :: non_neg_integer() | nil
  def get_max_size(%__MODULE__{max_size: size}), do: size

  @doc """
  Get the size of the log buffer.
  """
  @spec get_size(t()) :: non_neg_integer()
  def get_size(%__MODULE__{size: size}), do: size

  @doc """
  Returns the oldest item without removing it, or `:error` for an empty buffer.
  """
  @spec peek(t()) :: {:ok, item()} | :error
  def peek(%__MODULE__{size: 0}), do: :error

  def peek(%__MODULE__{} = buffer) do
    {:ok, :gb_trees.get(buffer.next_key - buffer.size, buffer.items)}
  end

  @doc """
  Returns the newest item without removing it, or `:error` for an empty buffer.
  """
  @spec peek_r(t()) :: {:ok, item()} | :error
  def peek_r(%__MODULE__{size: 0}), do: :error

  def peek_r(%__MODULE__{} = buffer) do
    {:ok, :gb_trees.get(buffer.next_key - 1, buffer.items)}
  end

  @doc """
  Reads up to `count` items starting at the zero-based offset from the oldest item.

  Seeking uses the tree's key index. Only the requested records are collected;
  offsets past the end return an empty list.
  """
  @spec read_range(t(), non_neg_integer(), pos_integer()) :: [item()]
  def read_range(buffer, offset \\ 0, count)

  def read_range(%__MODULE__{} = buffer, offset, count)
      when is_integer(offset) and offset >= 0 and is_integer(count) and count >= 1 do
    if offset >= buffer.size do
      []
    else
      first_key = buffer.next_key - buffer.size + offset
      iterator = :gb_trees.iterator_from(first_key, buffer.items)
      take_range(iterator, min(count, buffer.size - offset), [])
    end
  end

  @doc """
  Returns all items in insertion order in O(n) time.
  """
  @spec to_list(t()) :: [item()]
  def to_list(%__MODULE__{} = buffer), do: :gb_trees.values(buffer.items)

  @doc """
  Clears the buffer while keeping its maximum size and next internal key.
  """
  @spec truncate(t()) :: t()
  def truncate(%__MODULE__{} = buffer) do
    %__MODULE__{buffer | items: :gb_trees.empty(), size: 0}
  end

  @spec take_range(:gb_trees.iter(non_neg_integer(), item()), non_neg_integer(), [item()]) ::
          [item()]
  defp take_range(_iterator, 0, acc), do: Enum.reverse(acc)

  defp take_range(iterator, count, acc) do
    {_key, item, next} = :gb_trees.next(iterator)
    take_range(next, count - 1, [item | acc])
  end
end
