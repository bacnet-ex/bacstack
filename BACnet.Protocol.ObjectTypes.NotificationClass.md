# `BACnet.Protocol.ObjectTypes.NotificationClass`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/object_types/notification_class.ex#L1)

The Notification Class object type defines a standardized object that represents
and contains information required for the distribution of event notifications
within BACnet systems. Notification Classes are useful for event-initiating objects
that have identical needs in terms of how their notifications should be handled,
what the destination(s) for their notifications should be, and how they should
be acknowledged. A notification class defines how event notifications shall be
prioritized in their handling according to TO_OFFNORMAL, TO_FAULT, and TO_NORMAL events;
whether these categories of events require acknowledgment (nearly always by a
human operator); and what destination devices or processes should receive notifications.

The purpose of prioritization is to provide a means to ensure that alarms or event
notifications with critical time considerations are not unnecessarily delayed.
The possible range of priorities is 0 - 255. A lower number indicates a higher priority.
The priority and the Network Priority (Clause 6.2.2) are associated as defined in Table 13-5.

Priorities may be assigned to TO_OFFNORMAL, TO_FAULT, and TO_NORMAL events
individually within a notification class. The purpose of acknowledgment is to
provide assurance that a notification has been acted upon by some other agent,
rather than simply having been received correctly by another device.
In most cases, acknowledgments come from human operators.
TO_OFFNORMAL, TO_FAULT, and TO_NORMAL events may, or may not, require individual
acknowledgment within a notification class.
It is often necessary for event notifications to be sent to multiple destinations or
to different destinations based on the time of day or day of week.

Notification Classes may specify a list of destinations, each of which is qualified by time
day of week, and type of handling. A destination specifies a set of days of the week
(Monday through Sunday) during which the destination is considered viable by
the Notification Class object. In addition, each destination has a FromTime and ToTime,
which specify a window using specific times, on those days of the week,
during which the destination is viable. If an event that uses a Notification Class object
occurs and the day is one of the days of the week that is valid for a given destination and
the time is within the window specified in the destination, then the destination shall be
sent a notification. Destinations may be further qualified, as applicable, by any combination
of the three event transitions TO_OFFNORMAL, TO_FAULT, or TO_NORMAL.
The destination also defines the recipient device to receive the notification and a process
within the device. Processes are identified by numeric handles that are only meaningful to
the destination device. The administration of these handles is a local matter.
The recipient device may be specified by either its unique Device Object_Identifier
or its BACnetAddress. In the latter case, a specific node address, a multicast address,
or a broadcast address may be used. The destination further specifies whether the notification
shall be sent using a confirmed or unconfirmed event notification.

(ASHRAE 135 - Clause 12.21)

---------------------------------------------------------------------------
The following part has been automatically generated.

<details>
<summary>Click to expand</summary>

This module defines a BACnet object of the type `notification_class`. The following properties are defined:

| Property | Revision | Required | Readonly | Protected | Intrinsic |
|----------|----------|----------|----------|-----------|-----------|
| ack_required |  | X |  |  |  |
| description |  |  |  |  |  |
| notification_class |  | X |  |  |  |
| object_instance |  | X | X |  |  |
| object_name |  | X | X |  |  |
| priority |  | X |  |  |  |
| profile_name |  |  |  |  |  |
| recipient_list |  | X |  |  |  |

The following properties have additional semantics:

| Property | Has Default | Has Init | Implicit Relationships | Validators | Annotations |
|----------|-------------|----------|------------------------|------------|-------------|
| ack_required | X |  |  |  |  |
| priority | X |  |  |  |  |
| recipient_list | X |  |  |  |  |

The following table shows the default values and/or init functions:

| Property | Default Value | Init Function |
|----------|---------------|---------------|
| ack_required | <a title="%BACnet.Protocol.EventTransitionBits{to_offnormal: true, to_fault: true, to_normal: true}">`%BACnet.Protocol.EventTransitionBits{...}`</a> |  |
| priority | <a title="%BACnet.Protocol.NotificationClassPriority{to_offnormal: 0, to_fault: 0, to_normal: 0}">`%BACnet.Protocol.NotificationClassPriority{...}`</a> |  |
| recipient_list | `[]` |  |
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
  :ack_required
  | :description
  | :notification_class
  | :object_instance
  | :object_name
  | :priority
  | :profile_name
  | :recipient_list
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
@type t() :: %BACnet.Protocol.ObjectTypes.NotificationClass{
  _metadata: internal_metadata(),
  _unknown_properties: %{
    optional(atom() | non_neg_integer()) =&gt;
      term()
      | BACnet.Protocol.ApplicationTags.Encoding.t()
      | [BACnet.Protocol.ApplicationTags.Encoding.t()]
  },
  ack_required: BACnet.Protocol.EventTransitionBits.t(),
  description: String.t() | nil,
  notification_class: non_neg_integer(),
  object_instance: non_neg_integer(),
  object_name: String.t(),
  priority: BACnet.Protocol.NotificationClassPriority.t(),
  profile_name: String.t() | nil,
  recipient_list: [BACnet.Protocol.Destination.t()]
}
```

Represents a Notification Class object. All keys should be treated as read-only,
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
