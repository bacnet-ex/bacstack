# `BACnet.Stack.LogBuffer`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/log_buffer.ex#L1)

Simple log buffer implementation for event and trend logs.
The type of the item is not enforced.

The log buffer can maintain a maximum buffer size by dropping the oldest item
on overflow (ring buffer).

# `item`

```elixir
@type item() ::
  BACnet.Protocol.EventLogRecord.t()
  | BACnet.Protocol.LogRecord.t()
  | BACnet.Protocol.LogMultipleRecord.t()
```

Log buffer item type.

# `items`

```elixir
@opaque items()
```

Implementation detail and thus private API. Changes to it do not count
towards Semantic Versioning.

# `t`

```elixir
@type t() :: %BACnet.Stack.LogBuffer{
  items: items(),
  max_size: pos_integer() | nil,
  size: non_neg_integer()
}
```

Representative type for the log buffer.

# `checkin`

```elixir
@spec checkin(t(), item()) :: t()
```

Checks in an item.

If the log buffer has a max size, the max size will be maintained (meaning
the oldest item gets dropped on overflow).

# `checkout`

```elixir
@spec checkout(t()) :: {item :: item() | nil, new_buffer :: t()}
```

Checks out the oldest item in the log buffer.

If the log buffer is empty, `nil` will be returned as item.

# `drop`

```elixir
@spec drop(t(), pos_integer()) :: t()
```

Drops the specified amount of oldest items from the log buffer.

# `from_list`

```elixir
@spec from_list(list(), pos_integer() | nil) :: t()
```

Creates a new log buffer from the given list, with an optional max size.
The head of the list will be the oldest entry in the log buffer.

If a max size is specified, the list will be truncated to the max size (from the end).
The queue length will be calculated in any case. This operation is O(n).

# `get_size`

```elixir
@spec get_size(t()) :: non_neg_integer()
```

Get the size of the log buffer.

# `new`

```elixir
@spec new(pos_integer() | nil) :: t()
```

Creates a new log buffer with an optional max size.

# `peek`

```elixir
@spec peek(t()) :: {:ok, item()} | :error
```

Peeks into the log buffer and returns the oldest item without removing it.

# `peek_r`

```elixir
@spec peek_r(t()) :: {:ok, item()} | :error
```

Peeks into the log buffer and returns the newest item without removing it.

# `read_range`

```elixir
@spec read_range(t(), non_neg_integer(), pos_integer()) :: [item()]
```

Reads the specified count, starting from the given position (offset), from the log buffer.

# `to_list`

```elixir
@spec to_list(t()) :: [item()]
```

Creates a list from the log buffer.

# `truncate`

```elixir
@spec truncate(t()) :: t()
```

Truncates the log buffer to size zero.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
