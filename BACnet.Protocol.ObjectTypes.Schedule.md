# `BACnet.Protocol.ObjectTypes.Schedule`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/object_types/schedule.ex#L1)

The Schedule object type defines a standardized object used to describe a periodic schedule
that may recur during a range of dates, with optional exceptions at arbitrary times on
arbitrary dates. The Schedule object also serves as a binding between these scheduled times
and the writing of specified "values" to specific properties of specific objects at those times.

Schedules are divided into days, of which there are two types: normal days within a week and
exception days. Both types of days can specify scheduling events for either the full day or
portions of a day, and a priority mechanism defines which scheduled event is in control at any
given time. The current state of the Schedule object is represented by the value of its
Present_Value property, which is normally calculated using the time/value pairs from the
Weekly_Schedule and Exception_Schedule properties, with a default value for use when no schedules
are in effect. Details of this calculation are provided in the description of the Present_Value property.

Versions of the Schedule object prior to Protocol_Revision 4 only support schedules that define
an entire day, from midnight to midnight. For compatibility with these versions, this whole day
behavior can be achieved by using a specific schedule format.
Weekly_Schedule and Exception_Schedule values that begin at 00:00, and do not use any NULL values,
will define schedules for the entire day. Property values in this format will produce the same
results in all versions of the Schedule object.

Schedule objects may optionally support intrinsic reporting to facilitate the reporting of fault conditions.
Schedule objects that support intrinsic reporting shall apply the NONE event algorithm.

(ASHRAE 135 - Clause 12.24)

---------------------------------------------------------------------------
The following part has been automatically generated.

<details>
<summary>Click to expand</summary>

This module defines a BACnet object of the type `schedule`. The following properties are defined:

| Property | Revision | Required | Readonly | Protected | Intrinsic |
|----------|----------|----------|----------|-----------|-----------|
| acked_transitions |  |  | X |  | X |
| description |  |  |  |  |  |
| effective_period |  | X |  |  |  |
| event_algorithm_inhibit |  |  |  |  | X |
| event_algorithm_inhibit_ref |  |  |  |  | X |
| event_detection_enable |  |  |  |  | X |
| event_enable |  |  |  |  | X |
| event_message_texts |  |  | X |  | X |
| event_message_texts_config |  |  |  |  | X |
| event_timestamps |  |  | X |  | X |
| exception_schedule |  |  |  |  |  |
| limit_enable |  |  |  |  | X |
| list_of_object_property_references |  | X |  |  |  |
| notification_class |  |  |  |  | X |
| notify_type |  |  |  |  | X |
| object_instance |  | X | X |  |  |
| object_name |  | X | X |  |  |
| out_of_service |  | X |  |  |  |
| present_value |  | X |  |  |  |
| priority_for_writing |  | X |  |  |  |
| profile_name |  |  |  |  |  |
| reliability |  | X |  |  |  |
| reliability_evaluation_inhibit |  |  |  |  |  |
| schedule_default |  | X |  |  |  |
| status_flags |  | X | X |  |  |
| time_delay |  |  |  |  | X |
| time_delay_normal |  |  |  |  | X |
| weekly_schedule |  |  |  |  |  |

The following properties have additional semantics:

| Property | Has Default | Has Init | Implicit Relationships | Validators | Annotations |
|----------|-------------|----------|------------------------|------------|-------------|
| effective_period | X |  |  |  |  |
| event_algorithm_inhibit_ref |  |  | event_algorithm_inhibit |  |  |
| list_of_object_property_references | X |  |  |  |  |
| present_value | X |  |  |  |  |
| priority_for_writing | X |  |  |  |  |
| schedule_default | X |  |  |  |  |
| weekly_schedule |  | X |  |  |  |

The following table shows the default values and/or init functions:

| Property | Default Value | Init Function |
|----------|---------------|---------------|
| effective_period | <a title="%BACnet.Protocol.DateRange{start_date: %BACnet.Protocol.BACnetDate{year: :unspecified, month: :unspecified, day: :unspecified, weekday: :unspecified}, end_date: %BACnet.Protocol.BACnetDate{year: :unspecified, month: :unspecified, day: :unspecified, weekday: :unspecified}}">`%BACnet.Protocol.DateRange{...}`</a> |  |
| list_of_object_property_references | <a title="#BACnet.Protocol.BACnetArray<size: 0, items: [], fixed_size: nil>">`%BACnet.Protocol.BACnetArray{...}`</a> |  |
| present_value | <a title="%BACnet.Protocol.ApplicationTags.Encoding{encoding: :primitive, extras: [], type: :null, value: nil}">`%BACnet.Protocol.ApplicationTags.Encoding{...}`</a> |  |
| priority_for_writing | `16` |  |
| schedule_default | <a title="%BACnet.Protocol.ApplicationTags.Encoding{encoding: :primitive, extras: [], type: :null, value: nil}">`%BACnet.Protocol.ApplicationTags.Encoding{...}`</a> |  |
| weekly_schedule |  | `Utility.Internal.init_fun_schedule_weekly_schedule/0` |
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
@type object_opts() ::
  {:base_type, BACnet.Protocol.ApplicationTags.primitive_type()}
  | common_object_opts()
```

Available object options.

# `property_name`

```elixir
@type property_name() ::
  :acked_transitions
  | :description
  | :effective_period
  | :event_algorithm_inhibit
  | :event_algorithm_inhibit_ref
  | :event_detection_enable
  | :event_enable
  | :event_message_texts
  | :event_message_texts_config
  | :event_timestamps
  | :exception_schedule
  | :limit_enable
  | :list_of_object_property_references
  | :notification_class
  | :notify_type
  | :object_instance
  | :object_name
  | :out_of_service
  | :present_value
  | :priority_for_writing
  | :profile_name
  | :reliability
  | :reliability_evaluation_inhibit
  | :schedule_default
  | :status_flags
  | :time_delay
  | :time_delay_normal
  | :weekly_schedule
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
@type t() :: %BACnet.Protocol.ObjectTypes.Schedule{
  _metadata: internal_metadata(),
  _unknown_properties: %{
    optional(atom() | non_neg_integer()) =&gt;
      term()
      | BACnet.Protocol.ApplicationTags.Encoding.t()
      | [BACnet.Protocol.ApplicationTags.Encoding.t()]
  },
  acked_transitions: BACnet.Protocol.EventTransitionBits.t() | nil,
  description: String.t() | nil,
  effective_period: BACnet.Protocol.DateRange.t(),
  event_algorithm_inhibit: boolean() | nil,
  event_algorithm_inhibit_ref: BACnet.Protocol.ObjectPropertyRef.t() | nil,
  event_detection_enable: boolean() | nil,
  event_enable: BACnet.Protocol.EventTransitionBits.t() | nil,
  event_message_texts: BACnet.Protocol.EventMessageTexts.t() | nil,
  event_message_texts_config: BACnet.Protocol.EventMessageTexts.t() | nil,
  event_timestamps: BACnet.Protocol.EventTimestamps.t() | nil,
  exception_schedule:
    BACnet.Protocol.BACnetArray.t(BACnet.Protocol.SpecialEvent.t()) | nil,
  limit_enable: BACnet.Protocol.LimitEnable.t() | nil,
  list_of_object_property_references:
    BACnet.Protocol.BACnetArray.t(BACnet.Protocol.DeviceObjectPropertyRef.t()),
  notification_class: non_neg_integer() | nil,
  notify_type: BACnet.Protocol.Constants.notify_type() | nil,
  object_instance: non_neg_integer(),
  object_name: String.t(),
  out_of_service: boolean(),
  present_value: BACnet.Protocol.ApplicationTags.Encoding.t(),
  priority_for_writing: 1..16,
  profile_name: String.t() | nil,
  reliability: BACnet.Protocol.Constants.reliability(),
  reliability_evaluation_inhibit: boolean() | nil,
  schedule_default: BACnet.Protocol.ApplicationTags.Encoding.t(),
  status_flags: BACnet.Protocol.StatusFlags.t(),
  time_delay: non_neg_integer() | nil,
  time_delay_normal: non_neg_integer() | nil,
  weekly_schedule:
    BACnet.Protocol.BACnetArray.t(BACnet.Protocol.DailySchedule.t(), 7) | nil
}
```

Represents a Schedule object. All keys should be treated as read-only,
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
