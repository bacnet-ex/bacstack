# `BACnet.Protocol.ObjectTypes.Command`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/object_types/command.ex#L1)

The Command object type defines a standardized object whose properties represent
the externally visible characteristics of a multi-action command procedure.
A Command object is used to write a set of values to a group of object properties,
based on the "action code" that is written to the Present_Value of the Command object.
Whenever the Present_Value property of the Command object is written to,
it triggers the Command object to take a set of actions that change the values of
a set of other objects' properties.

The Command object would typically be used to represent a complex context involving
multiple variables. The Command object is particularly useful for representing contexts
that have multiple states. For example, a particular zone of a building might have
three states: UNOCCUPIED, WARMUP, and OCCUPIED. To establish the operating context
for each state, numerous objects' properties may need to be changed to a collection
of known values. For example, when unoccupied, the temperature setpoint might be 18°C
and the lights might be off. When occupied, the setpoint might be 22°C and the lights
turned on, etc.

The Command object defines the relationship between a given state and those values
that shall be written to a collection of different objects' properties to realize that state.
Normally, a Command object is passive. Its In_Process property is FALSE, indicating
that the Command object is waiting for its Present_Value property to be written with a value.
When Present_Value is written, the Command object shall begin a sequence of actions.
The In_Process property shall be set to TRUE, indicating that the Command object has begun
processing one of a set of action sequences that is selected based on the particular value
written to the Present_Value property. If an attempt is made to write to the Present_Value
property through WriteProperty services while In_Process is TRUE, then a Result(-) shall be
returned with 'error class' = OBJECT and 'error code' = BUSY, rejecting the write.

The new value of the Present_Value property determines which sequence of actions the Command
object shall take. These actions are specified in an array of action lists indexed by this value.
The Action property contains these lists. A given list may be empty, in which case no action
takes place, except that In_Process is returned to FALSE and All_Writes_Successful is set to TRUE.
If the list is not empty, then for each action in the list the Command object shall write a
particular value to a particular property of a particular object in a particular BACnet Device.
Note, however, that the capability to write to remote devices is not required.
Note also that the Command object does not guarantee that every write will be successful,
and no attempt is made by the Command object to "roll back" successfully written properties
to their previous values in the event that one or more writes fail. If any of the writes fail,
then the All_Writes_Successful property is set to FALSE and the Write_Successful flag for that
BACnetActionCommand is set to FALSE. If the Quit_On_Failure flag is TRUE for the failed
BACnetActionCommand, then all subsequent BACnetActionCommands in the list shall have their
Write_Successful flag set to FALSE. If an individual write succeeds, then the Write_Successful flag
for that BACnetActionCommand shall be set to TRUE. If all the writes are successful,
then the All_Writes_Successful property is set to TRUE. Once all the writes have been processed
to completion by the Command object, the In_Process property is set back to FALSE and the
Command object becomes passive again, waiting for another command.

It is important to note that the particular value that is written to the Present_Value property
is not what triggers the action, but the act of writing itself. Thus if the Present_Value property
has the value 5 and it is again written with the value 5, then the 5th list of actions will be
performed again. Writing zero to the Present_Value causes no action to be taken and is the same as
invoking an empty list of actions. The Command object is a powerful concept with many beneficial applications.
However, there are unique aspects of the Command object that can cause confusing or destructive side effects
if the Command object is improperly configured. Since the Command object can manipulate other
objects' properties, it is possible that a Command object could be configured to command itself.
In such a case, the In_Process property acts as an interlock and protects the Command object
from selfoscillation.
However, it is also possible for a Command object to command another Command object that commands the first
Command object and so on. The possibility exists for Command objects that command GROUP objects.
In these cases of "circular referencing," it is possible for confusing side effects to occur.
When references occur to objects in other BACnet Devices, there is an increased possibility of time delays,
which could cause oscillatory behavior between Command objects that are improperly configured
in such a circular manner. Caution should be exercised when configuring Command objects
that reference objects outside the BACnet device that contains them.

(ASHRAE 135 - Clause 12.10)

---------------------------------------------------------------------------
The following part has been automatically generated.

<details>
<summary>Click to expand</summary>

This module defines a BACnet object of the type `command`. The following properties are defined:

| Property | Revision | Required | Readonly | Protected | Intrinsic |
|----------|----------|----------|----------|-----------|-----------|
| action |  | X | X |  |  |
| action_text |  |  |  |  |  |
| all_writes_successful |  | X | X |  |  |
| description |  |  |  |  |  |
| in_process |  | X |  |  |  |
| object_instance |  | X | X |  |  |
| object_name |  | X | X |  |  |
| present_value |  | X |  |  |  |
| profile_name |  |  |  |  |  |

The following properties have additional semantics:

| Property | Has Default | Has Init | Implicit Relationships | Validators | Annotations |
|----------|-------------|----------|------------------------|------------|-------------|
| action | X |  |  |  |  |
| action_text |  |  |  | Fun |  |
| present_value | X |  |  |  |  |

The following table shows the default values and/or init functions:

| Property | Default Value | Init Function |
|----------|---------------|---------------|
| action | <a title="#BACnet.Protocol.BACnetArray<size: 0, items: [], fixed_size: nil>">`%BACnet.Protocol.BACnetArray{...}`</a> |  |
| present_value | `0` |  |
</details>

# `common_object_opts`

```elixir
@type common_object_opts() ::
  {:allow_unknown_properties, boolean()}
  | {:ignore_unknown_properties, boolean()}
  | {:revision, BACnet.Protocol.Constants.protocol_revision()}
```

Common object options for creation - all are optional.

- `allow_unknown_properties` - Properties that are unknown to the object implementation are usually rejected.
  With this option, unknown properties (numeric identifiers usually means we dont know them) are accepted
  and put into a separate map. This does mean we can not validate or write them.
  Types of the values can be anything at this point. While you can read unknown properties with atom
  or integer as property identifier, you can only remove numeric unknown property identifiers from an object.
  Property identifiers of type `atom` are only accepted, if it is a remote object (object implementation is only
  enforced if it is a local object). Numeric property identifiers are accepted regardless of remote object or not.
  For remote objects, this means you have to write "raw values" (usually `Encoding` structs).
- `ignore_unknown_properties` - Properties that are unknown to the object implementation are usually rejected.
  With this option, unknown properties get ignored, as if they were not specified.
- `revision` - The BACnet protocol revision to check required properties against.
  Optional properties are regardless of revision available.
  See `t:BACnet.Protocol.Constants.protocol_revision/0` for the available revisions.

# `object_opts`

```elixir
@type object_opts() :: common_object_opts()
```

Available object options.

# `property_name`

```elixir
@type property_name() ::
  :action
  | :action_text
  | :all_writes_successful
  | :description
  | :in_process
  | :object_instance
  | :object_name
  | :present_value
  | :profile_name
```

Available property names for this object.

# `property_update_error`

```elixir
@type property_update_error() ::
  {:error,
   {error :: atom(),
    property :: BACnet.Protocol.Constants.property_identifier()}}
```

The structure for property errors.

# `t`

```elixir
@type t() :: %BACnet.Protocol.ObjectTypes.Command{
  _metadata: internal_metadata(),
  _unknown_properties: %{
    optional(atom() | non_neg_integer()) =&gt;
      term()
      | BACnet.Protocol.ApplicationTags.Encoding.t()
      | [BACnet.Protocol.ApplicationTags.Encoding.t()]
  },
  action: BACnet.Protocol.BACnetArray.t(BACnet.Protocol.ActionList.t()),
  action_text: BACnet.Protocol.BACnetArray.t(String.t()) | nil,
  all_writes_successful: boolean(),
  description: String.t() | nil,
  in_process: boolean(),
  object_instance: non_neg_integer(),
  object_name: String.t(),
  present_value: non_neg_integer(),
  profile_name: String.t() | nil
}
```

Represents a Command object. All keys should be treated as read-only,
all updates should go only through `update_property/3`.

# `add_property`

```elixir
@spec add_property(t(), BACnet.Protocol.Constants.property_identifier(), term()) ::
  {:ok, t()} | property_update_error()
```

Adds an optional property to an object.
Remote objects can not be mutated using this operation.

Please note that properties of services can **not** be dynamically added and instead
the object must be newly created using `create/4`.

# `create`

```elixir
@spec create(
  non_neg_integer(),
  String.t(),
  %{optional(property_name() | atom() | non_neg_integer()) =&gt; term()},
  [object_opts() | internal_metadata()]
) :: {:ok, t()} | property_update_error()
```

Creates a new object struct with the defined properties. Optional properties are not
created when not given, only required, given and dependency properties are created.
Properties with a value of `nil` are ignored.

Only properties that are required for specific services (i.e. Intrinsic Reporting)
are automatically created.

# `get_all_properties`

```elixir
@spec get_all_properties() :: [BACnet.Protocol.Constants.property_identifier()]
```

Auto generated function to get the names of all properties this object supports.

# `get_annotation`

```elixir
@spec get_annotation(property_name()) :: [term()]
```

Auto generated function to get the annotations for the given property name.

# `get_annotations`

```elixir
@spec get_annotations() :: [{name :: property_name(), values :: [term()]}]
```

Auto generated function to get the list of annotations for each property.

# `get_cov_properties`

```elixir
@spec get_cov_properties() :: [BACnet.Protocol.Constants.property_identifier()]
```

Auto generated function to get the names of properties used for COV reporting.

# `get_intrinsic_properties`

```elixir
@spec get_intrinsic_properties() :: [BACnet.Protocol.Constants.property_identifier()]
```

Auto generated function to get the names of intrinsic properties.

# `get_object_identifier`

```elixir
@spec get_object_identifier(t()) :: BACnet.Protocol.ObjectIdentifier.t()
```

Get the BACnet object identifier.

# `get_optional_properties`

```elixir
@spec get_optional_properties() :: [BACnet.Protocol.Constants.property_identifier()]
```

Auto generated function to get the names of optional properties.

# `get_properties`

```elixir
@spec get_properties(t()) :: [BACnet.Protocol.Constants.property_identifier()]
```

Get the list of properties the object has.

# `get_properties_type_map`

```elixir
@spec get_properties_type_map() :: map()
```

Auto generated function to get a map of property name to type.

# `get_property`

```elixir
@spec get_property(
  t(),
  BACnet.Protocol.Constants.property_identifier() | non_neg_integer()
) ::
  {:ok, term()} | property_update_error()
```

Get a property's value from an object.

# `get_protected_properties`

```elixir
@spec get_protected_properties() :: [BACnet.Protocol.Constants.property_identifier()]
```

Auto generated function to get the names of protected properties.

Protected is an annotation and the object modules prevent writing to
this property directly in code. The protected properties are either
written on creation or updated automatically depending on other properties
being written to. Some properties are only written once at creation and
never updated.

# `get_readonly_properties`

```elixir
@spec get_readonly_properties() :: [BACnet.Protocol.Constants.property_identifier()]
```

Auto generated function to get the names of readonly properties.

Readonly is only an annotation that the property should be write protected
on the BACnet side, there is no actual write protection in the object.
This is a hint to the device server. If you need actual write protection, see `protected`.

# `get_required_properties`

```elixir
@spec get_required_properties() :: [BACnet.Protocol.Constants.property_identifier()]
```

Auto generated function to get the names of required properties.

# `has_property?`

```elixir
@spec has_property?(t(), BACnet.Protocol.Constants.property_identifier()) :: boolean()
```

Checks if the given object has the given property.

See `BACnet.Protocol.ObjectsUtility.has_property?/2` for implementation details.

# `property_writable?`

```elixir
@spec property_writable?(t(), BACnet.Protocol.Constants.property_identifier()) ::
  boolean()
```

Checks if the given property is writable.

Check `BACnet.Protocol.ObjectsUtility.property_writable?/2` for a basic run-down.

# `remove_property`

```elixir
@spec remove_property(
  t(),
  BACnet.Protocol.Constants.property_identifier() | non_neg_integer()
) ::
  {:ok, t()} | property_update_error()
```

Removes an optional property from an object. This function is idempotent.
Remote objects can not be mutated using this operation.

Please note that properties of services can **not** be dynamically removed and instead
the object must be newly created using `create/4`. Required properties can not be removed.

# `supports_intrinsic`

```elixir
@spec supports_intrinsic() :: boolean()
```

Auto generated function to check whether the object type supports intrinsic reporting.

# `update_property`

```elixir
@spec update_property(t(), BACnet.Protocol.Constants.property_identifier(), term()) ::
  {:ok, t()} | property_update_error()
```

Updates a property of an object.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
