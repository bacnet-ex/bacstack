# `BACnet.Protocol.BACnetArray`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/bacnet_array.ex#L1)

A BACnet Array is a structured datatype in ordered sequences.
A BACnet Array consists of data elements each having the same datatype.

The components of a BACnet Array may be individually accessed for read and write,
using an array index. An array index of zero specifies the size
of the array. The index zero can not be directly written to using `set_item/3`,
use `truncate/1` instead.

When a BACnet Array has a fixed size, the array can not be resized
and any attempts will fail to do so. The BACnet array of fixed size
will contain elements with the default value, which will be returned
upon call to `to_list/1` or inside `reduce_while/3`.

# `items`

```elixir
@opaque items(subtype)
```

Implementation detail and thus private API. Changes to it do not count
towards Semantic Versioning.

# `t`

```elixir
@type t() :: t(term())
```

Base type for the BACnet array.

# `t`

```elixir
@type t(subtype) :: t(subtype, nil)
```

Base type with subtype for the BACnet array.

# `t`

```elixir
@type t(subtype, fixed_size) :: %BACnet.Protocol.BACnetArray{
  fixed_size: fixed_size,
  items: items(subtype),
  size: non_neg_integer()
}
```

Representative type for the BACnet array.

The items get typed as `subtype`. `fixed_size` is either
a number in the range of `non_neg_integer` or `nil`.

A fixed size array can not change its size.

# `fetch`

```elixir
@spec fetch(t(subtype), non_neg_integer()) :: {:ok, subtype} | :error
when subtype: var
```

Fetch an item from the array.

This is implemented for the `Access` module.

# `fixed_size?`

```elixir
@spec fixed_size?(t()) :: boolean()
```

Check whether the BACnet array has a fixed size.

# `from_indexed_list`

```elixir
@spec from_indexed_list(Enumerable.t(subtype), boolean(), default) ::
  t(subtype | default) | no_return()
when default: term()
```

Create a new BACnet array from the given index list.

The indexed list is a list of `{index, item}`, where index is a positive integer.
The indexes do not need to be consecutively or sequentially ordered.
Note however that interleaved values leave the default value at the "holes",
which you will get upon calling `get_item/2`. See also `get_item/2`.

The list will be iterated once to insert them into the array.
Optionally the resulting array can have a fixed size (derived from the list length).

# `from_list`

```elixir
@spec from_list(Enumerable.t(subtype), boolean(), default) ::
  t(subtype | default) | no_return()
when default: var
```

Create a new BACnet array from the given list.

Optionally the resulting array can have a fixed size (derived from the list length).

# `get_default`

```elixir
@spec get_default(t()) :: term()
```

Get the default value for the BACnet array.

# `get_item`

```elixir
@spec get_item(t(subtype), non_neg_integer()) :: {:ok, subtype} | :error
when subtype: var
```

Get the item from the specified position.

Arrays with interleaved values will typically use the default value,
as such when getting interleave positions, you will get the default value.
However `:undefined` is handled special and will return `:error` instead.

Position `0` conveniently returns the size (as specified by ASHRAE 135).

# `new`

```elixir
@spec new(non_neg_integer() | nil, term()) :: t()
```

Creates a new array. When specifying a fixed size,
the array can not grow or shrink.

There's no distinction between an unset value (an empty position)
or an explicitely set value to the default value.

# `reduce_while`

```elixir
@spec reduce_while(
  t(subtype),
  term(),
  (item :: subtype, accumulator :: term() -&gt; {:cont, term()} | {:halt, term()})
) :: term()
```

Reduce the array items to an accumulator. See `Enum.reduce_while/3`.

# `remove_item`

```elixir
@spec remove_item(t(subtype), non_neg_integer()) ::
  {:ok, t(subtype)} | {:error, term()}
```

Remove an item from the array. This function ignores positions greater than its capacity.

Non-fixed size arrays get resized. Fixed size arrays will have the position reset to the
default value.

# `set_item`

```elixir
@spec set_item(t(subtype), non_neg_integer() | nil, subtype) ::
  {:ok, t(subtype)} | {:error, term()}
when subtype: var
```

Inserts an item at the specified position into the array.

Position `nil` can be used to append to the end of the array.
Positions greater than the size of the array + 1 can not be used.

# `size`

```elixir
@spec size(t()) :: non_neg_integer()
```

Get the size of the array.

# `to_list`

```elixir
@spec to_list(t(subtype)) :: [subtype] when subtype: var
```

Get all items as a list.

# `truncate`

```elixir
@spec truncate(t(subtype)) :: t(subtype)
```

Truncates the array to size zero.

# `valid?`

```elixir
@spec valid?(t(), BACnet.BeamTypes.typechecker_types()) :: boolean()
```

Validates whether the given BACnet array is in form valid.
A type can be given to be verified, so that each entry
is either the default value or of that type (see `BACnet.BeamTypes.check_type/2`).

If none or `:any` is given, no particular validation occurs.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
