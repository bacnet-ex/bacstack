defmodule BACnet.Protocol.PriorityArray do
  @moduledoc """
  The Priority Array is a BACnet means of ensuring Command Prioritization.
  The Priority Array is an array (or in this case a struct) that contains 16 levels of priority,
  each which can take a particular value (each priority must have the same type) or NULL (`nil`).
  The highest priority (lowest array index) with a non-NULL value is the active command.

  ### Command Prioritization

  In building control systems, an object may be manipulated by a number of entities.
  For example, the present value of a Binary Output object may be set by several applications,
  such as demand metering, optimum start/stop, etc.
  Each such application program has a well-defined function it needs to perform.
  When the actions of two or more application programs conflict with regard to the value of a property,
  there is a need to arbitrate between them.
  The objective of the arbitration process is to ensure the desired behavior of an object
  that is manipulated by several program (or non-program) entities.
  For example, a start/stop program may specify that a particular Binary Output should be ON,
  while demand metering may specify that the same Binary Output should be OFF.
  In this case, the OFF should take precedence. An operator may be able to override
  the demand metering program and force the Binary Output ON, in which case the ON should take precedence.

  In BACnet, this arbitration is provided by a prioritization scheme that assigns varying levels
  of priorities to commanding entities on a system-wide basis. Each object that contains a commandable property
  is responsible for acting upon prioritized commands in the order of their priorities.
  While there is a trade-off between the complexity and the robustness of any such mechanism,
  the scheme described here is intended to be effective but applicable to even simple BACnet devices.

  ### Prioritization Mechanism

  For BACnet objects, commands are prioritized based upon a fixed number of priorities
  that are assigned to command-issuing entities.
  A prioritized command (one that is directed at a commandable property of an object) is performed
  via a WriteProperty service request or a WritePropertyMultiple service request.
  The request primitive includes a conditional 'Priority' parameter that ranges from 1 to 16.
  Each commandable property of an object has an associated priority table
  that is represented by a `priority_array` property.
  The PriorityArray consists of an array of commanded values in order of decreasing priority.
  The first value in the array corresponds to priority 1 (highest),
  the second value corresponds to priority 2, and so on,
  to the sixteenth value that corresponds to priority 16 (lowest).

  An entry in the PriorityArray may have a commanded value or a NULL.
  A NULL value indicates that there is no existing command at that priority.
  An object continuously monitors all entries within the priority table in order
  to locate the entry with the highest priority non-NULL value and
  sets the commandable property to this value.

  A commanding entity (application program, operator, etc.) may issue a command
  to write to the commandable property of an object,
  or it may relinquish a command issued earlier. Relinquishing of a command is performed
  by a write operation similar to the command itself,
  except that the commandable property value is NULL.
  Relinquishing a command places a NULL value in the PriorityArray corresponding to the appropriate priority.
  This prioritization approach shall be applied to local actions that change the value
  of commandable properties as well as to write operations via BACnet services.
  """

  alias BACnet.BeamTypes
  alias BACnet.Protocol.BACnetArray

  @typedoc """
  Base type for the BACnet Priority Array.
  """
  @type t :: t(term())

  @typedoc """
  Represents the BACnet Priority Array with 16 priorities.
  The lowest priority number has the highest priority.

  If a priority is nil, the priority is unset.
  """
  @type t(subtype) :: %__MODULE__{
          priority_1: subtype | nil,
          priority_2: subtype | nil,
          priority_3: subtype | nil,
          priority_4: subtype | nil,
          priority_5: subtype | nil,
          priority_6: subtype | nil,
          priority_7: subtype | nil,
          priority_8: subtype | nil,
          priority_9: subtype | nil,
          priority_10: subtype | nil,
          priority_11: subtype | nil,
          priority_12: subtype | nil,
          priority_13: subtype | nil,
          priority_14: subtype | nil,
          priority_15: subtype | nil,
          priority_16: subtype | nil
        }

  @fields [
    :priority_1,
    :priority_2,
    :priority_3,
    :priority_4,
    :priority_5,
    :priority_6,
    :priority_7,
    :priority_8,
    :priority_9,
    :priority_10,
    :priority_11,
    :priority_12,
    :priority_13,
    :priority_14,
    :priority_15,
    :priority_16
  ]
  # We do not need to enforce keys, as default nil is valid
  defstruct @fields

  @priorities Enum.to_list(1..16//1)

  @doc """
  Fetches the value for a specific `key` in the given `array`.

  `key` is the priority number or the struct field name.

  This function is implemented for the `Access` behaviour and
  allows to access the fields using the priority number (or the atom key).

  This function will raise for an invalid atom key.
  """
  @spec fetch(t(subtype), 1..16 | atom()) :: {:ok, subtype | nil} when subtype: var
  def fetch(%__MODULE__{} = array, key) when key in 1..16 or key in @fields do
    Map.fetch(array, key_to_struct_key(key))
  end

  @doc """
  Create a Priority Array from a BACnetArray.

  The types of the array values are not checked. However,
  they should all be the same. The size of the array must
  be 16 or smaller (lower priorities will be `nil`).
  """
  @spec from_array(BACnetArray.t(subtype)) :: t(subtype) when subtype: var
  def from_array(array)

  def from_array(%BACnetArray{size: size} = array) when size <= 16 do
    array
    |> BACnetArray.to_list()
    |> from_list()
  end

  def from_array(%BACnetArray{} = _array) do
    raise ArgumentError, "The array must have a size of maximum 16"
  end

  @doc """
  Create a Priority Array from a list (or any other enumerable).

  The types of the list values are not checked. However,
  they should all be the same. The length of the list must
  be 16 or smaller (lower priorities will be `nil`).

  When using a key-value based enumerable, if the key is a priority number,
  then it will be used as such.
  """
  @spec from_list(Enumerable.t(subtype)) :: t(subtype) when subtype: var
  def from_list(list) do
    Enumerable.impl_for!(list)

    # Force "manual" traversal for lists - as for lists, the whole list will always be traversed!
    unless (is_list(list) and Enum.count_until(list, fn _val -> true end, 17) <= 16) or
             (not is_list(list) and Enum.count_until(list, 17) <= 16) do
      raise ArgumentError, "The list must have a length of maximum 16"
    end

    {prioarr, _pos} =
      Enum.reduce(list, {%{}, 1}, fn
        {key, item}, {acc, prio} when key in 1..16 ->
          {Map.put(acc, int_to_atom(key), item), prio}

        item, {acc, prio} ->
          {Map.put(acc, int_to_atom(prio), item), prio + 1}
      end)

    struct(__MODULE__, prioarr)
  end

  @doc """
  Gets the value from `key` and updates it, all in one pass.

  `key` is the priority number or the struct field name.

  `fun` is called with the current value under `key` in `array` and must return
  a two-element tuple: the current value (the retrieved value, which can be operated
  on before being returned) and the new value to be stored under `key`
  in the resulting new array. `fun` may also return `:pop`,
  which means the current value will be set to `nil`.

  This function is implemented for the `Access` behaviour.
  """
  @spec get_and_update(
          t(subtype),
          1..16 | atom(),
          (subtype | nil -> {current_value :: subtype | nil, new_value :: subtype | nil} | :pop)
        ) :: {current_value :: subtype | nil, new_struct :: t(subtype)}
        when subtype: var
  def get_and_update(%__MODULE__{} = array, key, fun)
      when (key in 1..16//1 or key in @fields) and is_function(fun, 1) do
    actual_key = key_to_struct_key(key)
    {:ok, current} = fetch(array, actual_key)

    case fun.(current) do
      {get, update} ->
        {get, %{array | actual_key => update}}

      :pop ->
        {current, %{array | actual_key => nil}}

      other ->
        raise "the given function must return a two-element tuple or :pop, got: #{inspect(other)}"
    end
  end

  @doc """
  Get the highest active priority value. If none is active, `nil` is returned.
  """
  @spec get_value(t(subtype)) :: {priority :: 1..16, value :: subtype} | nil when subtype: var
  def get_value(%__MODULE__{} = array) do
    get_priority_value(@fields, @priorities, array)
  end

  @doc """
  Resets the value associated with `key` in `array` to `nil` and
  returns the value and the updated array.

  `key` is the priority number or the struct field name.

  It returns `{value, updated_array}` where `value` is the value of
  the key and `updated_map` is the result of setting `key` to `nil`.

  This function is implemented for the `Access` behaviour.
  """
  @spec pop(t(subtype), 1..16 | atom()) :: {value :: subtype | nil, updated_array :: t(subtype)}
        when subtype: var
  def pop(%__MODULE__{} = array, key) when key in 1..16//1 or key in @fields do
    actual_key = key_to_struct_key(key)

    {:ok, value} = fetch(array, key)
    {value, %{array | actual_key => nil}}
  end

  @doc """
  Create a BACnetArray from a Priority Array.
  """
  @spec to_array(t(subtype)) :: BACnetArray.t(subtype | nil) when subtype: var
  def to_array(%__MODULE__{} = array) do
    array
    |> to_list()
    |> BACnetArray.from_list()
  end

  @doc """
  Create a list from a Priority Array.
  """
  @spec to_list(t(subtype)) :: list(subtype | nil) when subtype: var
  def to_list(%__MODULE__{} = array) do
    array
    |> Map.from_struct()
    |> Enum.sort_by(fn {key, _val} -> atom_to_int(key) end)
    |> Enum.map(fn {_key, val} -> val end)
  end

  @doc """
  Validates whether the given priority array is in form valid.

  It only validates the struct is valid as per type specification.

  Optionally, a type can be given to be verified, so that each priority
  is either nil or of that type (see `BACnet.BeamTypes.check_type/2`).
  """
  @spec valid?(t(), BeamTypes.typechecker_types()) :: boolean()
  def valid?(t, type \\ :any)

  def valid?(%__MODULE__{} = t, type) do
    Enum.all?(Map.from_struct(t), fn
      {_key, nil} -> true
      {_key, val} -> BeamTypes.check_type(type, val)
    end)
  end

  defp get_priority_value([], _list, %__MODULE__{} = _array), do: nil

  defp get_priority_value([priority | tail], [prionum | tail2], %__MODULE__{} = array) do
    case Map.get(array, priority) do
      nil -> get_priority_value(tail, tail2, array)
      value -> {prionum, value}
    end
  end

  @spec key_to_struct_key(1..16 | atom()) :: atom()
  defp key_to_struct_key(key) when key in 1..16, do: int_to_atom(key)
  defp key_to_struct_key(key), do: key

  @doc false
  @spec int_to_atom(1..16) :: atom()
  def int_to_atom(1), do: :priority_1
  def int_to_atom(2), do: :priority_2
  def int_to_atom(3), do: :priority_3
  def int_to_atom(4), do: :priority_4
  def int_to_atom(5), do: :priority_5
  def int_to_atom(6), do: :priority_6
  def int_to_atom(7), do: :priority_7
  def int_to_atom(8), do: :priority_8
  def int_to_atom(9), do: :priority_9
  def int_to_atom(10), do: :priority_10
  def int_to_atom(11), do: :priority_11
  def int_to_atom(12), do: :priority_12
  def int_to_atom(13), do: :priority_13
  def int_to_atom(14), do: :priority_14
  def int_to_atom(15), do: :priority_15
  def int_to_atom(16), do: :priority_16

  @doc false
  @spec atom_to_int(atom()) :: 1..16
  def atom_to_int(:priority_1), do: 1
  def atom_to_int(:priority_2), do: 2
  def atom_to_int(:priority_3), do: 3
  def atom_to_int(:priority_4), do: 4
  def atom_to_int(:priority_5), do: 5
  def atom_to_int(:priority_6), do: 6
  def atom_to_int(:priority_7), do: 7
  def atom_to_int(:priority_8), do: 8
  def atom_to_int(:priority_9), do: 9
  def atom_to_int(:priority_10), do: 10
  def atom_to_int(:priority_11), do: 11
  def atom_to_int(:priority_12), do: 12
  def atom_to_int(:priority_13), do: 13
  def atom_to_int(:priority_14), do: 14
  def atom_to_int(:priority_15), do: 15
  def atom_to_int(:priority_16), do: 16
end
