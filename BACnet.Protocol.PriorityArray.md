# `BACnet.Protocol.PriorityArray`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/priority_array.ex#L1)

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

# `t`

```elixir
@type t() :: t(term())
```

Base type for the BACnet Priority Array.

# `t`

```elixir
@type t(subtype) :: %BACnet.Protocol.PriorityArray{
  priority_1: subtype | nil,
  priority_10: subtype | nil,
  priority_11: subtype | nil,
  priority_12: subtype | nil,
  priority_13: subtype | nil,
  priority_14: subtype | nil,
  priority_15: subtype | nil,
  priority_16: subtype | nil,
  priority_2: subtype | nil,
  priority_3: subtype | nil,
  priority_4: subtype | nil,
  priority_5: subtype | nil,
  priority_6: subtype | nil,
  priority_7: subtype | nil,
  priority_8: subtype | nil,
  priority_9: subtype | nil
}
```

Represents the BACnet Priority Array with 16 priorities.
The lowest priority number has the highest priority.

If a priority is nil, the priority is unset.

# `fetch`

```elixir
@spec fetch(t(subtype), 1..16 | atom()) :: {:ok, subtype | nil} when subtype: var
```

Fetches the value for a specific `key` in the given `array`.

`key` is the priority number or the struct field name.

This function is implemented for the `Access` behaviour and
allows to access the fields using the priority number (or the atom key).

This function will raise for an invalid atom key.

# `from_array`

```elixir
@spec from_array(BACnet.Protocol.BACnetArray.t(subtype)) :: t(subtype)
```

Create a Priority Array from a BACnetArray.

The types of the array values are not checked. However,
they should all be the same. The size of the array must
be 16 or smaller (lower priorities will be `nil`).

# `from_list`

```elixir
@spec from_list(Enumerable.t(subtype)) :: t(subtype)
```

Create a Priority Array from a list (or any other enumerable).

The types of the list values are not checked. However,
they should all be the same. The length of the list must
be 16 or smaller (lower priorities will be `nil`).

When using a key-value based enumerable, if the key is a priority number,
then it will be used as such.

# `get_and_update`

```elixir
@spec get_and_update(
  t(subtype),
  1..16 | atom(),
  (subtype | nil -&gt;
     {current_value :: subtype | nil, new_value :: subtype | nil} | :pop)
) :: {current_value :: subtype | nil, new_struct :: t(subtype)}
when subtype: var
```

Gets the value from `key` and updates it, all in one pass.

`key` is the priority number or the struct field name.

`fun` is called with the current value under `key` in `array` and must return
a two-element tuple: the current value (the retrieved value, which can be operated
on before being returned) and the new value to be stored under `key`
in the resulting new array. `fun` may also return `:pop`,
which means the current value will be set to `nil`.

This function is implemented for the `Access` behaviour.

# `get_value`

```elixir
@spec get_value(t(subtype)) :: {priority :: 1..16, value :: subtype} | nil
```

Get the highest active priority value. If none is active, `nil` is returned.

# `pop`

```elixir
@spec pop(t(subtype), 1..16 | atom()) ::
  {value :: subtype | nil, updated_array :: t(subtype)}
```

Resets the value associated with `key` in `array` to `nil` and
returns the value and the updated array.

`key` is the priority number or the struct field name.

It returns `{value, updated_array}` where `value` is the value of
the key and `updated_map` is the result of setting `key` to `nil`.

This function is implemented for the `Access` behaviour.

# `to_array`

```elixir
@spec to_array(t(subtype)) :: BACnet.Protocol.BACnetArray.t(subtype | nil)
```

Create a BACnetArray from a Priority Array.

# `to_list`

```elixir
@spec to_list(t(subtype)) :: [subtype | nil] when subtype: var
```

Create a list from a Priority Array.

# `valid?`

```elixir
@spec valid?(t(), BACnet.BeamTypes.typechecker_types()) :: boolean()
```

Validates whether the given priority array is in form valid.

It only validates the struct is valid as per type specification.

Optionally, a type can be given to be verified, so that each priority
is either nil or of that type (see `BACnet.BeamTypes.check_type/2`).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
