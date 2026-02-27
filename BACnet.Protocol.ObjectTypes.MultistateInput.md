# `BACnet.Protocol.ObjectTypes.MultistateInput`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/object_types/multistate_input.ex#L1)

The Multi-state Input object type defines a standardized object whose Present_Value
represents the result of an algorithmic process within the BACnet Device in which
the object resides.

The algorithmic process itself is a local matter and is not defined by the protocol.
For example, the Present_Value or state of the Multi-state Input object may be the
result of a logical combination of multiple binary inputs or the threshold of one or
more analog inputs or the result of a mathematical computation.
The Present_Value property is an integer number representing the state.
The State_Text property associates a description with each state.

Multi-state Input objects that support intrinsic reporting shall apply the CHANGE_OF_STATE event algorithm.
For reliability-evaluation, the FAULT_STATE fault algorithm can be applied.

(ASHRAE 135 - Clause 12.18)

---------------------------------------------------------------------------
The following part has been automatically generated.

<details>
<summary>Click to expand</summary>

This module defines a BACnet object of the type `multi_state_input`. The following properties are defined:

| Property | Revision | Required | Readonly | Protected | Intrinsic |
|----------|----------|----------|----------|-----------|-----------|
| acked_transitions |  |  | X |  | X |
| alarm_values |  |  |  |  | X |
| description |  |  |  |  |  |
| device_type |  |  |  |  |  |
| event_algorithm_inhibit |  |  |  |  | X |
| event_algorithm_inhibit_ref |  |  |  |  | X |
| event_detection_enable |  |  |  |  | X |
| event_enable |  |  |  |  | X |
| event_message_texts |  |  | X |  | X |
| event_message_texts_config |  |  |  |  | X |
| event_state |  | X |  |  |  |
| event_timestamps |  |  | X |  | X |
| fault_values |  |  |  |  |  |
| limit_enable |  |  |  |  | X |
| notification_class |  |  |  |  | X |
| notify_type |  |  |  |  | X |
| number_of_states |  | X | X |  |  |
| object_instance |  | X | X |  |  |
| object_name |  | X | X |  |  |
| out_of_service |  | X |  |  |  |
| present_value |  | X |  |  |  |
| profile_name |  |  |  |  |  |
| reliability |  |  |  |  |  |
| reliability_evaluation_inhibit |  |  |  |  |  |
| state_text |  |  |  |  |  |
| status_flags |  | X | X |  |  |
| time_delay |  |  |  |  | X |
| time_delay_normal |  |  |  |  | X |

The following properties have additional semantics:

| Property | Has Default | Has Init | Implicit Relationships | Validators | Annotations |
|----------|-------------|----------|------------------------|------------|-------------|
| alarm_values | X |  |  |  |  |
| event_algorithm_inhibit_ref |  |  | event_algorithm_inhibit |  |  |
| fault_values | X |  | reliability |  |  |
| number_of_states | X |  |  | Type |  |
| present_value | X |  |  | Fun/Type |  |
| reliability |  |  | reliability_evaluation_inhibit |  |  |
| state_text |  |  |  | Fun |  |

The following table shows the default values and/or init functions:

| Property | Default Value | Init Function |
|----------|---------------|---------------|
| alarm_values | `[]` |  |
| fault_values | `[]` |  |
| number_of_states | `1` |  |
| present_value | `1` |  |
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
@type object_opts() :: {:intrinsic_reporting, boolean()} | common_object_opts()
```

Available object options.

# `property_name`

```elixir
@type property_name() ::
  :acked_transitions
  | :alarm_values
  | :description
  | :device_type
  | :event_algorithm_inhibit
  | :event_algorithm_inhibit_ref
  | :event_detection_enable
  | :event_enable
  | :event_message_texts
  | :event_message_texts_config
  | :event_state
  | :event_timestamps
  | :fault_values
  | :limit_enable
  | :notification_class
  | :notify_type
  | :number_of_states
  | :object_instance
  | :object_name
  | :out_of_service
  | :present_value
  | :profile_name
  | :reliability
  | :reliability_evaluation_inhibit
  | :state_text
  | :status_flags
  | :time_delay
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
@type t() :: %BACnet.Protocol.ObjectTypes.MultistateInput{
  _metadata: internal_metadata(),
  _unknown_properties: %{
    optional(atom() | non_neg_integer()) =&gt;
      term()
      | BACnet.Protocol.ApplicationTags.Encoding.t()
      | [BACnet.Protocol.ApplicationTags.Encoding.t()]
  },
  acked_transitions: BACnet.Protocol.EventTransitionBits.t() | nil,
  alarm_values: [non_neg_integer()] | nil,
  description: String.t() | nil,
  device_type: String.t() | nil,
  event_algorithm_inhibit: boolean() | nil,
  event_algorithm_inhibit_ref: BACnet.Protocol.ObjectPropertyRef.t() | nil,
  event_detection_enable: boolean() | nil,
  event_enable: BACnet.Protocol.EventTransitionBits.t() | nil,
  event_message_texts: BACnet.Protocol.EventMessageTexts.t() | nil,
  event_message_texts_config: BACnet.Protocol.EventMessageTexts.t() | nil,
  event_state: BACnet.Protocol.Constants.event_state(),
  event_timestamps: BACnet.Protocol.EventTimestamps.t() | nil,
  fault_values: [non_neg_integer()] | nil,
  limit_enable: BACnet.Protocol.LimitEnable.t() | nil,
  notification_class: non_neg_integer() | nil,
  notify_type: BACnet.Protocol.Constants.notify_type() | nil,
  number_of_states: pos_integer(),
  object_instance: non_neg_integer(),
  object_name: String.t(),
  out_of_service: boolean(),
  present_value: pos_integer(),
  profile_name: String.t() | nil,
  reliability: BACnet.Protocol.Constants.reliability() | nil,
  reliability_evaluation_inhibit: boolean() | nil,
  state_text: BACnet.Protocol.BACnetArray.t(String.t(), pos_integer()) | nil,
  status_flags: BACnet.Protocol.StatusFlags.t(),
  time_delay: non_neg_integer() | nil,
  time_delay_normal: non_neg_integer() | nil
}
```

Represents an Multistate Input object. All keys should be treated as read-only,
all updates should go only through `update_property/3`.

Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
then the properties can not be nil.

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

# `intrinsic_reporting?`

```elixir
@spec intrinsic_reporting?(t()) :: boolean()
```

Checks if the given object has Intrinsic Reporting enabled.

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
