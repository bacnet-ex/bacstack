defmodule BACnet.Stack.LogBufferBehaviour do
  @moduledoc """
  A behaviour for log buffer implementations, most notably for the `BACnet.Stack.TrendLogger` module.

  The behaviour contains the functions from the `BACnet.Stack.LogBuffer` module,
  the default log buffer implementation used by `BACnet.Stack.TrendLogger`.

  Using a behaviour allows exchanging the implementation with a different one,
  for example backed by SQLite.
  """

  @typedoc """
  The item that gets check in into the log buffer.
  """
  @type item :: term()

  @typedoc """
  A module implementing the Log Buffer Behaviour.
  """
  @type mod :: module()

  @typedoc """
  The data structure representing the log buffer.
  """
  @type t :: term()

  @doc """
  Creates a new log buffer with an optional max size.
  """
  @callback new(max_size :: pos_integer() | nil) :: t()

  @doc """
  Checks in an item.

  If the log buffer has a max size, the max size will be maintained (meaning
  the oldest item gets dropped on overflow).
  """
  @callback checkin(buffer :: t(), item()) :: t()

  @doc """
  Checks out the oldest item in the log buffer.

  If the log buffer is empty, `nil` will be returned as item.
  """
  @callback checkout(buffer :: t()) :: {item :: item() | nil, new_buffer :: t()}

  @doc """
  Drops the specified amount of oldest items from the log buffer.
  """
  @callback drop(buffer :: t(), amount :: pos_integer()) :: t()

  @doc """
  Creates a new log buffer from the given list, with an optional max size.
  The head of the list will be the oldest entry in the log buffer.

  If a max size is specified, the list will be truncated to the max size (from the end).
  The queue length will be calculated in any case. This operation is O(n).
  """
  @callback from_list(source :: list(), max_size :: pos_integer() | nil) :: t()

  @doc """
  Get the size of the log buffer.
  """
  @callback get_size(buffer :: t()) :: non_neg_integer()

  @doc """
  Peeks into the log buffer and returns the oldest item without removing it.
  """
  @callback peek(buffer :: t()) :: {:ok, item()} | :error

  @doc """
  Peeks into the log buffer and returns the newest item without removing it.
  """
  @callback peek_r(buffer :: t()) :: {:ok, item()} | :error

  @doc """
  Reads the specified count, starting from the given position (offset), from the log buffer.
  """
  @callback read_range(buffer :: t(), offset :: non_neg_integer(), count :: pos_integer()) :: [
              item()
            ]

  @doc """
  Creates a list from the log buffer.
  """
  @callback to_list(buffer :: t()) :: [item()]

  @doc """
  Truncates the log buffer to size zero.
  """
  @callback truncate(buffer :: t()) :: t()
end
