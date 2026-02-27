# `BACnet.Protocol.ObjectsUtility`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/objects_utility.ex#L1)

This module offers utility functions that work on all object types.

This is mostly complementary to the object module itself and offers some
additional generic functions for working with objects.

Some functions will call `Code.ensure_loaded/1` on object modules to ensure the
module is loaded and available - however only if `Mix.env/0` does not return `:prod`.
If this library is a dependency in a project, Mix always compiles dependencies in `:prod`.
To override this behaviour, see `mix help deps`.

# `is_object`
*macro* 

Checks whether the given struct is a supported BACnet object (see `t:bacnet_object/0`).

Note: This guard is not widely used by this module itself, but may be useful for others.

# `is_object_intrinsic`
*macro* 

Checks whether the given BACnet object has Intrinsic Reporting enabled.

This is the same functionality as `intrinsic_reporting?/1`, but as a guard.

# `is_object_local`
*macro* 

Checks whether the given BACnet object is a local object (identified through metadata).

A local object is a BACnet object that resides in the local BACnet device (this bacstack).

# `is_object_remote`
*macro* 

Checks whether the given BACnet object is a remote object (identified through metadata).

A remote object is a BACnet object that resides in a remote BACnet device - as such
some operations don't work (such as adding optional properties).

# `bacnet_object`

```elixir
@type bacnet_object() ::
  BACnet.Protocol.ObjectTypes.Accumulator.t()
  | BACnet.Protocol.ObjectTypes.AnalogInput.t()
  | BACnet.Protocol.ObjectTypes.AnalogOutput.t()
  | BACnet.Protocol.ObjectTypes.AnalogValue.t()
  | BACnet.Protocol.ObjectTypes.Averaging.t()
  | BACnet.Protocol.ObjectTypes.BinaryInput.t()
  | BACnet.Protocol.ObjectTypes.BinaryOutput.t()
  | BACnet.Protocol.ObjectTypes.BinaryValue.t()
  | BACnet.Protocol.ObjectTypes.BitstringValue.t()
  | BACnet.Protocol.ObjectTypes.Calendar.t()
  | BACnet.Protocol.ObjectTypes.CharacterStringValue.t()
  | BACnet.Protocol.ObjectTypes.Command.t()
  | BACnet.Protocol.ObjectTypes.DatePatternValue.t()
  | BACnet.Protocol.ObjectTypes.DateTimePatternValue.t()
  | BACnet.Protocol.ObjectTypes.DateTimeValue.t()
  | BACnet.Protocol.ObjectTypes.DateValue.t()
  | BACnet.Protocol.ObjectTypes.Device.t()
  | BACnet.Protocol.ObjectTypes.EventEnrollment.t()
  | BACnet.Protocol.ObjectTypes.EventLog.t()
  | BACnet.Protocol.ObjectTypes.File.t()
  | BACnet.Protocol.ObjectTypes.Group.t()
  | BACnet.Protocol.ObjectTypes.IntegerValue.t()
  | BACnet.Protocol.ObjectTypes.LargeAnalogValue.t()
  | BACnet.Protocol.ObjectTypes.Loop.t()
  | BACnet.Protocol.ObjectTypes.MultistateInput.t()
  | BACnet.Protocol.ObjectTypes.MultistateOutput.t()
  | BACnet.Protocol.ObjectTypes.MultistateValue.t()
  | BACnet.Protocol.ObjectTypes.NotificationClass.t()
  | BACnet.Protocol.ObjectTypes.OctetStringValue.t()
  | BACnet.Protocol.ObjectTypes.PositiveIntegerValue.t()
  | BACnet.Protocol.ObjectTypes.Program.t()
  | BACnet.Protocol.ObjectTypes.PulseConverter.t()
  | BACnet.Protocol.ObjectTypes.Schedule.t()
  | BACnet.Protocol.ObjectTypes.StructuredView.t()
  | BACnet.Protocol.ObjectTypes.TimePatternValue.t()
  | BACnet.Protocol.ObjectTypes.TimeValue.t()
  | BACnet.Protocol.ObjectTypes.TrendLog.t()
  | BACnet.Protocol.ObjectTypes.TrendLogMultiple.t()
```

BACnet object types that this module works with.

# `cast_properties_to_object_option`

```elixir
@type cast_properties_to_object_option() ::
  {:allow_unknown_properties, boolean() | :no_unpack}
  | {:ignore_unknown_properties, boolean()}
  | {:remote_device_id, non_neg_integer()}
  | {:revision, BACnet.Protocol.Constants.protocol_revision()}
  | {:object_opts, Keyword.t()}
```

Valid options for `cast_properties_to_object/3`.

`allow_unknown_properties` allows `:no_unpack` as synonym for `true`.

# `cast_property_to_value_option`

```elixir
@type cast_property_to_value_option() :: {:allow_partial, boolean()}
```

Valid options for `cast_property_to_value/4`.

# `cast_read_properties_ack_option`

```elixir
@type cast_read_properties_ack_option() ::
  {:allow_unknown_properties, boolean() | :no_unpack}
  | {:ignore_array_indexes, boolean()}
  | {:ignore_invalid_properties, boolean()}
  | {:ignore_object_identifier_mismatch, boolean()}
  | {:ignore_unknown_properties, boolean()}
```

Valid options for `cast_read_properties_ack/3`.

# `cast_value_to_property_option`

```elixir
@type cast_value_to_property_option() ::
  {:allow_nil, boolean()} | {:allow_partial, boolean()}
```

Valid options for `cast_value_to_property/4`.

# `add_property`

```elixir
@spec add_property(
  bacnet_object(),
  BACnet.Protocol.Constants.property_identifier(),
  term()
) ::
  {:ok, bacnet_object()} | {:error, term()}
```

Adds an optional property to an object (see `t:bacnet_object/0`).

Please note that properties of services can **not** be dynamically added and instead
the object must be newly created.

This function calls to the object module directly, as such it enforces the `t:bacnet_object/0` contract.

# `cast_properties_to_object`

```elixir
@spec cast_properties_to_object(
  BACnet.Protocol.ObjectIdentifier.t(),
  %{
    optional(
      BACnet.Protocol.Constants.property_identifier()
      | atom()
      | non_neg_integer()
    ) =&gt; term()
  },
  [cast_properties_to_object_option()]
) :: {:ok, bacnet_object()} | {:error, {atom(), term()}} | {:error, term()}
```

Create an object from a map of properties.
This function is used for remote objects, not for local objects.

This function invokes the object module's `create` function.

Note: In prod environment, required modules are not explicitely loaded.

The following options are available:
- `allow_unknown_properties: boolean()` - Optional. Allows unknown property identifiers - which means we have no validation (defaults to `false`).
- `ignore_unknown_properties: boolean()` - Optional. Ignores properties the object module doesn't support (defaults to `false`).
- `remote_device_id: non_neg_integer()` - Optional. Adds the remote BACnet device ID to the object (ID is used for trend logging).
- `revision: Constants.protocol_revision()` - Optional. The BACnet protocol revision to check the properties against.
- `object_opts: Keyword.t()` - Optional. All other object creation options to pass to the `create` function.

# `cast_property_to_value`

```elixir
@spec cast_property_to_value(
  BACnet.Protocol.ObjectIdentifier.t(),
  BACnet.Protocol.Constants.property_identifier(),
  BACnet.Protocol.ApplicationTags.Encoding.t()
  | [BACnet.Protocol.ApplicationTags.Encoding.t()],
  [cast_property_to_value_option()]
) :: {:ok, term()} | {:error, {atom(), term()}} | {:error, term()}
```

Casts a property from application tag `Encoding` to a more sane data type.

To cast the property to the proper data type, the correct object module needs to be known,
which contains that property. The object module will tell us which data type should it be.
As such, an object identifier is required.

Note: In prod environment, required modules are not explicitely loaded.

The following options are available:
- `allow_partial: boolean()` - Optional. Allows partial values of array or list properties (a single value).

# `cast_read_properties_ack`

```elixir
@spec cast_read_properties_ack(
  BACnet.Protocol.ObjectIdentifier.t(),
  [
    BACnet.Protocol.Services.Ack.ReadPropertyAck.t()
    | BACnet.Protocol.Services.Ack.ReadPropertyMultipleAck.t()
  ],
  [cast_read_properties_ack_option()]
) ::
  {:ok,
   %{
     optional(
       BACnet.Protocol.Constants.property_identifier()
       | atom()
       | non_neg_integer()
     ) =&gt; term()
   }}
  | {:error, {atom(), term()}}
  | {:error, term()}
```

Casts the properties and its values from `Read-Property-(Multiple-)Ack`s into a map of properties.

Note: In prod environment, required modules are not explicitely loaded.

The following options are available:
- `allow_unknown_properties: boolean() | :no_unpack` - Optional. Allows unknown property identifiers - which means we have no validation (defaults to `false`).
- `ignore_array_indexes: boolean()` - Optional. Ignores property array indexes as they are currently not supported (defaults to `false`).
- `ignore_invalid_properties: boolean()` - Optional. Ignores invalid properties (defaults to `false`).
- `ignore_object_identifier_mismatch: boolean()` - Optional. Ignores mismatches between object identifiers (defaults to `false`).
- `ignore_unknown_properties: boolean()` - Optional. Ignores unknown property identifiers (defaults to `false`).

# `cast_value_to_property`

```elixir
@spec cast_value_to_property(
  BACnet.Protocol.ObjectIdentifier.t(),
  BACnet.Protocol.Constants.property_identifier(),
  term() | [term()],
  [cast_value_to_property_option()]
) ::
  {:ok,
   BACnet.Protocol.ApplicationTags.Encoding.t()
   | [BACnet.Protocol.ApplicationTags.Encoding.t()]}
  | {:error, {atom(), term()}}
  | {:error, term()}
```

Casts a property value to application tag `Encoding`.

To cast the property from the proper data type, the correct object module needs to be known,
which contains that property. The object module will tell us which data type should it be.
As such, an object identifier is required. No validation happens on the data.

Note: In prod environment, required modules are not explicitely loaded.

The following options are available:
- `allow_nil: boolean()` - Optional. Allows `nil` values (only useful for present value with write priority).
- `allow_partial: boolean()` - Optional. Allows partial values of array or list properties (a single value).

# `delete_object_type_mapping`

```elixir
@spec delete_object_type_mapping(BACnet.Protocol.Constants.object_type()) :: :ok
```

Delete an object type to module relationship from the mappings.

See also `get_object_type_mappings/0` for more information.

# `get_object_identifier`

```elixir
@spec get_object_identifier(bacnet_object()) :: BACnet.Protocol.ObjectIdentifier.t()
```

Get the object identifier for the BACnet object. The `bacnet_object` contract is enforced.

# `get_object_type`

```elixir
@spec get_object_type(bacnet_object()) :: BACnet.Protocol.Constants.object_type()
```

Get the BACnet object type. The `bacnet_object` contract is enforced.

# `get_object_type_mappings`

```elixir
@spec get_object_type_mappings() :: %{
  optional(BACnet.Protocol.Constants.object_type()) =&gt; module()
}
```

Get the object type to module mappings.

This mapping is used for object properties casting (such as `cast_property_to_value/4`).
This mapping is stored in `:persistent_term` and is automatically populated on first use
with all object types from the `bacstack` application.

# `get_priority_value`

```elixir
@spec get_priority_value(bacnet_object()) ::
  {priority :: 1..16, value :: term()} | nil
```

Get the active priority value from the priority array, or nil.

# `get_properties`

```elixir
@spec get_properties(bacnet_object()) :: [
  BACnet.Protocol.Constants.property_identifier()
]
```

Get the list of properties the object has.

# `get_property`

```elixir
@spec get_property(bacnet_object(), BACnet.Protocol.Constants.property_identifier()) ::
  {:ok, term()} | {:error, term()}
```

Get the property of an object (see `t:bacnet_object/0`).

This function calls to the object module directly, as such it enforces the `t:bacnet_object/0` contract.

# `get_remote_device_id`

```elixir
@spec get_remote_device_id(bacnet_object()) :: {:ok, non_neg_integer()} | :error | nil
```

Get the remote device ID for remote objects.

For remote objects with no remote device ID attached,
this function will return `:error`.
For local objects, this function will return `nil`.

# `has_priority_array?`

```elixir
@spec has_priority_array?(bacnet_object()) :: boolean()
```

Checks whether the given object has a priority array.
This function does not verify if the property is in the properties list of the object.

# `has_property?`

```elixir
@spec has_property?(bacnet_object(), BACnet.Protocol.Constants.property_identifier()) ::
  boolean()
```

Checks if the given object has the given property.

> #### Implementation Detail {: .info}
> This function is O(n), as it traverses the properties list.
> This actually represents what on the BACnet side can be seen, as only properties in the
> properties list can be used (observable).

# `intrinsic_reporting?`

```elixir
@spec intrinsic_reporting?(bacnet_object()) :: boolean()
```

Checks if the given object has Intrinsic Reporting enabled.

# `property_writable?`

```elixir
@spec property_writable?(
  bacnet_object(),
  BACnet.Protocol.Constants.property_identifier()
) :: boolean()
```

Checks if the given property is writable.

This implementation checks for arbitary properties, if the property exists
and is not annotated as readonly. For commandable objects and the present value, it
checks if the object is out of service. For the event algorithm inhibit property,
it checks if ref is absent or uninitialized and event detection is enabled.

Object-specific behaviour are not checked and should instead be directly checked
through the object module.

# `put_many_object_type_mapping`

```elixir
@spec put_many_object_type_mapping([
  {BACnet.Protocol.Constants.object_type(), module()}
]) :: :ok
```

Put many object type to module relationships into the mappings at once.

See also `get_object_type_mappings/0` for more information.

# `put_object_type_mapping`

```elixir
@spec put_object_type_mapping(BACnet.Protocol.Constants.object_type(), module()) ::
  :ok
```

Put an object type to module relationship into the mappings.

See also `get_object_type_mappings/0` for more information.

# `remove_property`

```elixir
@spec remove_property(
  bacnet_object(),
  BACnet.Protocol.Constants.property_identifier()
) ::
  {:ok, bacnet_object()} | {:error, term()}
```

Removes an optional property from an object (see `t:bacnet_object/0`). This function is idempotent.

Please note that properties of services can **not** be dynamically removed and instead
the object must be newly created. Required properties can not be removed.

This function calls to the object module directly, as such it enforces the `t:bacnet_object/0` contract.

# `set_priority`

```elixir
@spec set_priority(bacnet_object(), 1..16, term()) ::
  {:ok, bacnet_object()} | {:error, term()}
```

Sets the given priority in the priority array of an object (see `t:bacnet_object/0`).
This function also updates the present value.

This function calls to the object module directly, as such it enforces the `t:bacnet_object/0` contract,
and additionally only objects with a priority array can be used.

# `to_list`

```elixir
@spec to_list(bacnet_object()) :: [
  {BACnet.Protocol.Constants.property_identifier(), term()}
]
```

Turns the given object's properties with their values into a keyword list.
Only properties in the properties list are taken. The `bacnet_object` contract is enforced.

The key `:object_instance` will be converted into `:object_identifier`.

The list is sorted in ascending order by the property name.

# `to_map`

```elixir
@spec to_map(bacnet_object()) :: %{
  optional(BACnet.Protocol.Constants.property_identifier()) =&gt; term()
}
```

Turns the given object's properties with their values into a map.
Only properties in the properties list are taken. The `bacnet_object` contract is enforced.

The key `:object_instance` will be converted into `:object_identifier`.

# `truncate_float_properties`

```elixir
@spec truncate_float_properties(
  bacnet_object(),
  float() | non_neg_integer(),
  :round | :truncate
) :: bacnet_object()
```

Truncates each property, which is a float, to the given precision (float rounding).

When giving an integer as precision, this function will behave just like `Float.round/2`.
When giving a float as precision, this function will determine
the precision (i.e. 1 for `0.1`, 2 for `0.01`, 0 for any value >= `1.0` or `0.0`).
The float value itself is not relevant, only how many decimal points there are.

Depending on the selected mode, the float will be rounded or the value is truncated.

# `update_property`

```elixir
@spec update_property(
  bacnet_object(),
  BACnet.Protocol.Constants.property_identifier(),
  term()
) ::
  {:ok, bacnet_object()} | {:error, term()}
```

Updates a property of an object (see `t:bacnet_object/0`).

This function calls to the object module directly, as such it enforces the `t:bacnet_object/0` contract.

# `validate_float_range`

```elixir
@spec validate_float_range(BACnet.Protocol.ApplicationTags.ieee_float(), %{
  optional(:min_present_value) =&gt;
    BACnet.Protocol.ApplicationTags.ieee_float() | nil,
  optional(:max_present_value) =&gt;
    BACnet.Protocol.ApplicationTags.ieee_float() | nil
}) :: boolean()
```

Validates that the given value is within the `min_present_value` and `max_present_value` (range).

It verifies that the given value is within the configured `min` and `max`, which can also be
`:NaN`, `:inf` and `:infn`.

The given value can not be larger than the configured `max` or smaller than the configured `min`.
In particular, `:NaN` is always allowed as value, regardless of the configured range.

No validation is done if either `min` or `max` is missing (or `nil`).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
