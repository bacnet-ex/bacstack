# `BACnet.Protocol.ObjectTypes.EventEnrollment`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/object_types/event_enrollment.ex#L1)

The Event Enrollment object type defines a standardized object that represents
and contains the information required for algorithmic reporting of events.
For the general event concepts and algorithmic event reporting, see Clause 13.2.

For the Event Enrollment object, detecting events is accomplished by performing
particular event and fault algorithms on monitored values of a referenced object.
The parameters for the algorithms are provided by the Event Enrollment object.
The standard event algorithms are defined in Clause 13.3.
The standard fault algorithms are defined in Clause 13.4.
Event Enrollment objects do not modify or otherwise influence the state or
operation of the referenced object. For the reliability indication by the
Reliability property of the Event Enrollment object, internal unreliable operation
such as configuration error or communication failure takes precedence over
reliability indication for the monitored object (i.e., MONITORED_OBJECT_FAULT).
Fault indications determined by the fault algorithm, if any, have least precedence.
Clause 13.2 describes the interaction between Event Enrollment objects,
the Notification Class objects, and the Alarm and Event application services.

(ASHRAE 135 - Clause 12.12)

---------------------------------------------------------------------------
The following part has been automatically generated.

<details>
<summary>Click to expand</summary>

This module defines a BACnet object of the type `event_enrollment`. The following properties are defined:

| Property | Revision | Required | Readonly | Protected | Intrinsic |
|----------|----------|----------|----------|-----------|-----------|
| acked_transitions |  |  | X |  |  |
| description |  |  |  |  |  |
| event_algorithm_inhibit |  |  |  |  |  |
| event_algorithm_inhibit_ref |  |  |  |  |  |
| event_detection_enable |  | X |  |  |  |
| event_enable |  | X |  |  |  |
| event_message_texts |  |  | X |  |  |
| event_message_texts_config |  |  |  |  |  |
| event_parameters |  | X |  |  |  |
| event_state |  | X |  |  |  |
| event_timestamps |  |  | X |  |  |
| event_type |  | X |  |  |  |
| fault_parameters |  |  |  |  |  |
| fault_type |  |  | X |  |  |
| notification_class |  | X |  |  |  |
| notify_type |  | X |  |  |  |
| object_instance |  | X | X |  |  |
| object_name |  | X | X |  |  |
| object_property_reference |  | X |  |  |  |
| profile_name |  |  |  |  |  |
| reliability |  |  |  |  |  |
| reliability_evaluation_inhibit |  |  |  |  |  |
| status_flags |  | X |  |  |  |
| time_delay_normal |  |  |  |  |  |

The following properties have additional semantics:

| Property | Has Default | Has Init | Implicit Relationships | Validators | Annotations |
|----------|-------------|----------|------------------------|------------|-------------|
| event_algorithm_inhibit |  |  | event_algorithm_inhibit_ref |  |  |
| event_detection_enable | X |  |  |  |  |
| event_enable | X |  |  |  |  |
| event_parameters | X |  |  |  |  |
| event_state | X |  |  |  |  |
| event_type | X |  |  |  |  |
| notify_type | X |  |  |  |  |
| object_property_reference | X |  |  |  |  |
| reliability |  |  | reliability_evaluation_inhibit |  |  |

The following table shows the default values and/or init functions:

| Property | Default Value | Init Function |
|----------|---------------|---------------|
| event_detection_enable | `true` |  |
| event_enable | <a title="%BACnet.Protocol.EventTransitionBits{to_offnormal: true, to_fault: true, to_normal: true}">`%BACnet.Protocol.EventTransitionBits{...}`</a> |  |
| event_parameters | <a title="%BACnet.Protocol.EventParameters.None{}">`%BACnet.Protocol.EventParameters.None{...}`</a> |  |
| event_state | `:normal` |  |
| event_type | `:none` |  |
| notify_type | `:alarm` |  |
| object_property_reference | <a title="%BACnet.Protocol.DeviceObjectPropertyRef{object_identifier: %BACnet.Protocol.ObjectIdentifier{type: :binary_input, instance: 4194303}, property_identifier: 4194303, property_array_index: nil, device_identifier: nil}">`%BACnet.Protocol.DeviceObjectPropertyRef{...}`</a> |  |
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
  :acked_transitions
  | :description
  | :event_algorithm_inhibit
  | :event_algorithm_inhibit_ref
  | :event_detection_enable
  | :event_enable
  | :event_message_texts
  | :event_message_texts_config
  | :event_parameters
  | :event_state
  | :event_timestamps
  | :event_type
  | :fault_parameters
  | :fault_type
  | :notification_class
  | :notify_type
  | :object_instance
  | :object_name
  | :object_property_reference
  | :profile_name
  | :reliability
  | :reliability_evaluation_inhibit
  | :status_flags
  | :time_delay_normal
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
@type t() :: %BACnet.Protocol.ObjectTypes.EventEnrollment{
  _metadata: internal_metadata(),
  _unknown_properties: %{
    optional(atom() | non_neg_integer()) =&gt;
      term()
      | BACnet.Protocol.ApplicationTags.Encoding.t()
      | [BACnet.Protocol.ApplicationTags.Encoding.t()]
  },
  acked_transitions: BACnet.Protocol.EventTransitionBits.t() | nil,
  description: String.t() | nil,
  event_algorithm_inhibit: boolean() | nil,
  event_algorithm_inhibit_ref: BACnet.Protocol.ObjectPropertyRef.t() | nil,
  event_detection_enable: boolean(),
  event_enable: BACnet.Protocol.EventTransitionBits.t(),
  event_message_texts: BACnet.Protocol.EventMessageTexts.t() | nil,
  event_message_texts_config: BACnet.Protocol.EventMessageTexts.t() | nil,
  event_parameters: BACnet.Protocol.EventParameters.event_parameter(),
  event_state: BACnet.Protocol.Constants.event_state(),
  event_timestamps: BACnet.Protocol.EventTimestamps.t() | nil,
  event_type: BACnet.Protocol.Constants.event_type(),
  fault_parameters: BACnet.Protocol.FaultParameters.fault_parameter() | nil,
  fault_type: BACnet.Protocol.Constants.fault_type() | nil,
  notification_class: non_neg_integer(),
  notify_type: BACnet.Protocol.Constants.notify_type(),
  object_instance: non_neg_integer(),
  object_name: String.t(),
  object_property_reference: BACnet.Protocol.DeviceObjectPropertyRef.t(),
  profile_name: String.t() | nil,
  reliability: BACnet.Protocol.Constants.reliability() | nil,
  reliability_evaluation_inhibit: boolean() | nil,
  status_flags: BACnet.Protocol.StatusFlags.t(),
  time_delay_normal: non_neg_integer() | nil
}
```

Represents an Event Enrollment object. All keys should be treated as read-only,
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
