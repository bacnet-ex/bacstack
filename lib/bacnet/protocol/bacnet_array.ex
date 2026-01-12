defmodule BACnet.Protocol.BACnetArray do
  @moduledoc """
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
  """

  alias BACnet.BeamTypes

  @typedoc """
  Implementation detail and thus private API. Changes to it do not count
  towards Semantic Versioning.
  """
  @opaque items(subtype) :: :array.array(subtype)

  @typedoc """
  Base type for the BACnet array.
  """
  @type t :: t(term())

  @typedoc """
  Base type with subtype for the BACnet array.
  """
  @type t(subtype) :: t(subtype, nil)

  @typedoc """
  Representative type for the BACnet array.

  The items get typed as `subtype`. `fixed_size` is either
  a number in the range of `non_neg_integer` or `nil`.

  A fixed size array can not change its size.
  """
  @type t(subtype, fixed_size) :: %__MODULE__{
          fixed_size: fixed_size,
          items: items(subtype),
          size: non_neg_integer()
        }

  @fields [:fixed_size, :items, :size]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Creates a new array. When specifying a fixed size,
  the array can not grow or shrink.

  There's no distinction between an unset value (an empty position)
  or an explicitely set value to the default value.
  """
  @spec new(non_neg_integer() | nil, term()) :: t()
  def new(fixed_size \\ nil, default_value \\ :undefined)
      when is_nil(fixed_size) or (is_integer(fixed_size) and fixed_size > 0) do
    {items, len} =
      if fixed_size == nil do
        {:array.new(0, default: default_value, fixed: false), 0}
      else
        {:array.new(fixed_size, default: default_value), fixed_size}
      end

    %__MODULE__{
      fixed_size: fixed_size,
      items: items,
      size: len
    }
  end

  @doc """
  Fetch an item from the array.

  This is implemented for the `Access` module.
  """
  @spec fetch(t(subtype), non_neg_integer()) :: {:ok, subtype} | :error when subtype: var
  def fetch(%__MODULE__{} = array, position) when is_integer(position) and position > 0 do
    get_item(array, position)
  end

  @doc """
  Check whether the BACnet array has a fixed size.
  """
  @spec fixed_size?(t()) :: boolean()
  def fixed_size?(%__MODULE__{} = array) do
    array.fixed_size != nil
  end

  @doc """
  Create a new BACnet array from the given list.

  Optionally the resulting array can have a fixed size (derived from the list length).
  """
  @spec from_list(Enumerable.t(subtype), boolean(), default) :: t(subtype | default) | no_return()
        when subtype: var, default: var
  def from_list(collection, fixed_size \\ false, default_value \\ :undefined)
      when is_boolean(fixed_size) do
    Enumerable.impl_for!(collection)

    new_arr =
      collection
      |> Enum.to_list()
      |> :array.from_list(default_value)

    size = :array.size(new_arr)

    %__MODULE__{
      fixed_size: if(fixed_size, do: size),
      items: if(fixed_size, do: :array.fix(new_arr), else: new_arr),
      size: size
    }
  end

  @doc """
  Create a new BACnet array from the given index list.

  The indexed list is a list of `{index, item}`, where index is a positive integer.
  The indexes do not need to be consecutively or sequentially ordered.
  Note however that interleaved values leave the default value at the "holes",
  which you will get upon calling `get_item/2`. See also `get_item/2`.

  The list will be iterated once to insert them into the array.
  Optionally the resulting array can have a fixed size (derived from the list length).
  """
  @spec from_indexed_list(Enumerable.t(subtype), boolean(), default) ::
          t(subtype | default) | no_return()
        when subtype: var, default: term()
  def from_indexed_list(collection, fixed_size \\ false, default_value \\ :undefined)
      when is_boolean(fixed_size) do
    Enumerable.impl_for!(collection)

    arr = :array.new(0, default: default_value, fixed: false)

    new_arr =
      Enum.reduce(collection, arr, fn {index, item}, acc ->
        :array.set(index - 1, item, acc)
      end)

    size = :array.size(new_arr)

    %__MODULE__{
      fixed_size: if(fixed_size, do: size),
      items: if(fixed_size, do: :array.fix(new_arr), else: new_arr),
      size: size
    }
  end

  @doc """
  Get the default value for the BACnet array.
  """
  @spec get_default(t()) :: term()
  def get_default(%__MODULE__{} = array) do
    :array.default(array.items)
  end

  @doc """
  Get the item from the specified position.

  Arrays with interleaved values will typically use the default value,
  as such when getting interleave positions, you will get the default value.
  However `:undefined` is handled special and will return `:error` instead.

  Position `0` conveniently returns the size (as specified by ASHRAE 135).
  """
  @spec get_item(t(subtype), non_neg_integer()) :: {:ok, subtype} | :error when subtype: var
  def get_item(array, position)

  def get_item(%__MODULE__{} = array, 0) do
    {:ok, size(array)}
  end

  def get_item(%__MODULE__{size: len} = _array, position)
      when position > len do
    :error
  end

  def get_item(%__MODULE__{} = array, position) when position > 0 do
    case :array.get(position - 1, array.items) do
      :undefined -> :error
      val -> {:ok, val}
    end
  end

  @doc """
  Reduce the array items to an accumulator. See `Enum.reduce_while/3`.
  """
  @spec reduce_while(
          t(subtype),
          term(),
          (item :: subtype, accumulator :: term() -> {:cont, term()} | {:halt, term()})
        ) ::
          term()
        when subtype: var
  def reduce_while(%__MODULE__{} = array, accumulator, callback) when is_function(callback, 2) do
    Enum.reduce_while(to_list(array), accumulator, callback)
  end

  @doc """
  Remove an item from the array. This function ignores positions greater than its capacity.

  Non-fixed size arrays get resized. Fixed size arrays will have the position reset to the
  default value.
  """
  @spec remove_item(t(subtype), non_neg_integer()) :: {:ok, t(subtype)} | {:error, term()}
        when subtype: var
  def remove_item(array, position)

  def remove_item(%__MODULE__{} = _array, position) when position == 0 do
    {:error, :invalid_position}
  end

  def remove_item(%__MODULE__{size: len} = array, position) when position > len do
    {:ok, array}
  end

  def remove_item(%__MODULE__{fixed_size: nil} = array, position) when position > 0 do
    new_arr = :array.resize(:array.reset(position - 1, array.items))
    {:ok, %{array | items: new_arr, size: :array.size(new_arr)}}
  end

  def remove_item(%__MODULE__{} = array, position) when position > 0 do
    new_arr = :array.reset(position - 1, array.items)
    {:ok, %{array | items: new_arr}}
  end

  @doc """
  Inserts an item at the specified position into the array.

  Position `nil` can be used to append to the end of the array.
  Positions greater than the size of the array + 1 can not be used.
  """
  @spec set_item(t(subtype), non_neg_integer() | nil, subtype) ::
          {:ok, t(subtype)} | {:error, term()}
        when subtype: var
  def set_item(array, position, item)

  def set_item(%__MODULE__{fixed_size: size, size: len} = _array, nil, _item)
      when not is_nil(size) and len >= size do
    {:error, :array_full}
  end

  def set_item(%__MODULE__{} = array, nil, item) do
    new_arr = :array.set(array.size, item, array.items)
    {:ok, %{array | items: new_arr, size: :array.size(new_arr)}}
  end

  def set_item(%__MODULE__{} = _array, position, _item) when position == 0 do
    {:error, :invalid_position}
  end

  def set_item(%__MODULE__{size: len} = _array, position, _item) when position - 1 > len do
    {:error, :invalid_position}
  end

  def set_item(%__MODULE__{} = array, position, item) when position > 0 do
    new_arr = :array.set(position - 1, item, array.items)
    {:ok, %{array | items: new_arr, size: :array.size(new_arr)}}
  end

  @doc """
  Get the size of the array.
  """
  @spec size(t()) :: non_neg_integer()
  def size(%__MODULE__{} = array) do
    array.size
  end

  @doc """
  Get all items as a list.
  """
  @spec to_list(t(subtype)) :: list(subtype) when subtype: var
  def to_list(array)

  def to_list(%__MODULE__{fixed_size: nil} = array) do
    :array.sparse_to_list(array.items)
  end

  def to_list(%__MODULE__{} = array) do
    :array.to_list(array.items)
  end

  @doc """
  Truncates the array to size zero.
  """
  @spec truncate(t(subtype)) :: t(subtype) when subtype: var
  def truncate(%__MODULE__{} = array) do
    new(array.fixed_size, :array.default(array.items))
  end

  @doc """
  Validates whether the given BACnet array is in form valid.
  A type can be given to be verified, so that each entry
  is either the default value or of that type (see `BACnet.BeamTypes.check_type/2`).

  If none or `:any` is given, no particular validation occurs.
  """
  @spec valid?(t(), BeamTypes.typechecker_types()) :: boolean()
  def valid?(t, type \\ :any)

  def valid?(%__MODULE__{} = _t, :any) do
    true
  end

  def valid?(%__MODULE__{} = t, type) do
    default = get_default(t)

    Enum.all?(to_list(t), fn val ->
      val == default or BeamTypes.check_type(type, val)
    end)
  end

  defimpl Inspect do
    import Inspect.Algebra

    @name String.replace("#{@for}", "Elixir.", "")

    # This code has been taken from the Inspect.Map module and slightly adjusted
    def inspect(array, opts) do
      default = :array.default(array.items)

      items =
        array.items
        |> :array.to_list()
        |> Stream.with_index(1)
        |> Stream.reject(fn {val, _pos} -> val == default end)
        |> Enum.map(fn {val, pos} -> {pos, val} end)

      list =
        array
        |> Map.from_struct()
        |> Map.put(:items, items)
        |> Map.to_list()

      map_container_doc(list, @name, opts, &Inspect.List.keyword/2)
    end

    defp map_container_doc(list, name, opts, fun) do
      open = color("#" <> name <> "<", :map, opts)
      sep = color(",", :map, opts)
      close = color(">", :map, opts)
      container_doc(open, list, close, opts, fun, separator: sep, break: :strict)
    end
  end
end
