# `BACnet.Stack.LogBufferBehaviour`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/log_buffer_behaviour.ex#L1)

A behaviour for log buffer implementations, most notably for the `BACnet.Stack.TrendLogger` module.

The behaviour contains the functions from the `BACnet.Stack.LogBuffer` module,
the default log buffer implementation used by `BACnet.Stack.TrendLogger`.

Using a behaviour allows exchanging the implementation with a different one,
for example backed by SQLite.

# `item`

```elixir
@type item() :: term()
```

The item that gets check in into the log buffer.

# `mod`

```elixir
@type mod() :: module()
```

A module implementing the Log Buffer Behaviour.

# `t`

```elixir
@type t() :: term()
```

The data structure representing the log buffer.

# `checkin`

```elixir
@callback checkin(buffer :: t(), item()) :: t()
```

Checks in an item.

If the log buffer has a max size, the max size will be maintained (meaning
the oldest item gets dropped on overflow).

# `checkout`

```elixir
@callback checkout(buffer :: t()) :: {item :: item() | nil, new_buffer :: t()}
```

Checks out the oldest item in the log buffer.

If the log buffer is empty, `nil` will be returned as item.

# `drop`

```elixir
@callback drop(buffer :: t(), amount :: pos_integer()) :: t()
```

Drops the specified amount of oldest items from the log buffer.

# `from_list`

```elixir
@callback from_list(source :: list(), max_size :: pos_integer() | nil) :: t()
```

Creates a new log buffer from the given list, with an optional max size.
The head of the list will be the oldest entry in the log buffer.

If a max size is specified, the list will be truncated to the max size (from the end).
The queue length will be calculated in any case. This operation is O(n).

# `get_size`

```elixir
@callback get_size(buffer :: t()) :: non_neg_integer()
```

Get the size of the log buffer.

# `new`

```elixir
@callback new(max_size :: pos_integer() | nil) :: t()
```

Creates a new log buffer with an optional max size.

# `peek`

```elixir
@callback peek(buffer :: t()) :: {:ok, item()} | :error
```

Peeks into the log buffer and returns the oldest item without removing it.

# `peek_r`

```elixir
@callback peek_r(buffer :: t()) :: {:ok, item()} | :error
```

Peeks into the log buffer and returns the newest item without removing it.

# `read_range`

```elixir
@callback read_range(buffer :: t(), offset :: non_neg_integer(), count :: pos_integer()) ::
  [item()]
```

Reads the specified count, starting from the given position (offset), from the log buffer.

# `to_list`

```elixir
@callback to_list(buffer :: t()) :: [item()]
```

Creates a list from the log buffer.

# `truncate`

```elixir
@callback truncate(buffer :: t()) :: t()
```

Truncates the log buffer to size zero.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
