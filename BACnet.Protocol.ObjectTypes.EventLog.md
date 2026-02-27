# `BACnet.Protocol.ObjectTypes.EventLog`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/object_types/event_log.ex#L1)

An Event Log object records event notifications with timestamps and other
pertinent data in an internal buffer for subsequent retrieval.
Each timestamped buffer entry is called an event log "record".

Each Event Log object maintains an internal, optionally fixed-size buffer.
This buffer fills or grows as event log records are added.
If the buffer becomes full, the least recent records are overwritten when
new records are added, or collection may be set to stop.
Event log records are transferred as BACnetEventLogRecords using
the ReadRange service. The buffer may be cleared by writing a zero to
the Record_Count property. The determination of which notifications are
placed into the log is a local matter. Each record in the buffer has an
implied SequenceNumber that is equal to the value of the Total_Record_Count
property immediately after the record is added.

Logging may be enabled and disabled through the Enable property and
at dates and times specified by the Start_Time and Stop_Time properties.
Event Log enabling and disabling is recorded in the event log buffer.
Event reporting (notification) may be provided to facilitate automatic
fetching of event log records by processes on other devices such as fileservers.
Support is provided for algorithmic reporting; optionally, intrinsic reporting may be provided.
Event Log objects that support intrinsic reporting shall apply the BUFFER_READY event algorithm.

In intrinsic reporting, when the number of records specified by
the Notification_Threshold property has been collected since the previous
notification (or startup), a new notification is sent to all subscribed devices.
In response to a notification, subscribers may fetch all of the new records.
If a subscriber needs to fetch all of the new records, it should use
the 'By Sequence Number' form of the ReadRange service request.
A missed notification may be detected by a subscriber if the 'Current Notification'
parameter received in the previous BUFFER_READY notification is different than
the 'Previous Notification' parameter of the current BUFFER_READY notification.
If the ReadRange-ACK response to the ReadRange request issued under these conditions
has the FIRST_ITEM bit of the 'Result Flags' parameter set to TRUE, event log records
have probably been missed by this subscriber. The acquisition of log records by
remote devices has no effect upon the state of the Event Log object itself.
This allows completely independent, but properly sequential, access to its log records
by all remote devices. Any remote device can independently update its records at any time.

(ASHRAE 135 - Clause 12.27)

---------------------------------------------------------------------------
The following part has been automatically generated.

<details>
<summary>Click to expand</summary>

This module defines a BACnet object of the type `event_log`. The following properties are defined:

| Property | Revision | Required | Readonly | Protected | Intrinsic |
|----------|----------|----------|----------|-----------|-----------|
| acked_transitions |  |  | X |  | X |
| buffer_size |  | X | X |  |  |
| description |  |  |  |  |  |
| enable |  | X |  |  |  |
| event_algorithm_inhibit |  |  |  |  | X |
| event_algorithm_inhibit_ref |  |  |  |  | X |
| event_detection_enable |  |  |  |  | X |
| event_enable |  |  |  |  | X |
| event_message_texts |  |  | X |  | X |
| event_message_texts_config |  |  |  |  | X |
| event_state |  | X |  |  |  |
| event_timestamps |  |  | X |  | X |
| last_notify_record |  |  |  |  | X |
| limit_enable |  |  |  |  | X |
| log_buffer |  | X |  |  |  |
| notification_class |  |  |  |  | X |
| notification_threshold |  |  |  |  | X |
| notify_type |  |  |  |  | X |
| object_instance |  | X | X |  |  |
| object_name |  | X | X |  |  |
| profile_name |  |  |  |  |  |
| record_count |  | X |  |  |  |
| records_since_notification |  |  |  |  | X |
| reliability |  |  |  |  |  |
| reliability_evaluation_inhibit |  |  |  |  |  |
| start_time |  |  |  |  |  |
| status_flags |  | X | X |  |  |
| stop_time |  |  |  |  |  |
| stop_when_full |  | X |  |  |  |
| time_delay |  |  |  |  | X |
| time_delay_normal |  |  |  |  | X |
| total_record_count |  | X | X |  |  |

The following properties have additional semantics:

| Property | Has Default | Has Init | Implicit Relationships | Validators | Annotations |
|----------|-------------|----------|------------------------|------------|-------------|
| buffer_size |  |  |  | Fun/Type |  |
| enable | X |  |  |  |  |
| event_algorithm_inhibit_ref |  |  | event_algorithm_inhibit |  |  |
| event_state | X |  |  |  |  |
| last_notify_record | X |  |  | Type |  |
| log_buffer | X |  |  | Fun |  |
| notification_threshold | X |  |  | Type |  |
| record_count | X |  |  | Type |  |
| records_since_notification | X |  |  | Type |  |
| reliability |  |  | reliability_evaluation_inhibit |  |  |
| start_time |  |  | stop_time |  |  |
| total_record_count | X |  |  | Type |  |

The following table shows the default values and/or init functions:

| Property | Default Value | Init Function |
|----------|---------------|---------------|
| enable | `true` |  |
| event_state | `:normal` |  |
| last_notify_record | `0` |  |
| log_buffer | `[]` |  |
| notification_threshold | `0` |  |
| record_count | `0` |  |
| records_since_notification | `0` |  |
| total_record_count | `0` |  |
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
  | :buffer_size
  | :description
  | :enable
  | :event_algorithm_inhibit
  | :event_algorithm_inhibit_ref
  | :event_detection_enable
  | :event_enable
  | :event_message_texts
  | :event_message_texts_config
  | :event_state
  | :event_timestamps
  | :last_notify_record
  | :limit_enable
  | :log_buffer
  | :notification_class
  | :notification_threshold
  | :notify_type
  | :object_instance
  | :object_name
  | :profile_name
  | :record_count
  | :records_since_notification
  | :reliability
  | :reliability_evaluation_inhibit
  | :start_time
  | :status_flags
  | :stop_time
  | :stop_when_full
  | :time_delay
  | :time_delay_normal
  | :total_record_count
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
@type t() :: %BACnet.Protocol.ObjectTypes.EventLog{
  _metadata: internal_metadata(),
  _unknown_properties: %{
    optional(atom() | non_neg_integer()) =&gt;
      term()
      | BACnet.Protocol.ApplicationTags.Encoding.t()
      | [BACnet.Protocol.ApplicationTags.Encoding.t()]
  },
  acked_transitions: BACnet.Protocol.EventTransitionBits.t() | nil,
  buffer_size: BACnet.Protocol.ApplicationTags.unsigned32(),
  description: String.t() | nil,
  enable: boolean(),
  event_algorithm_inhibit: boolean() | nil,
  event_algorithm_inhibit_ref: BACnet.Protocol.ObjectPropertyRef.t() | nil,
  event_detection_enable: boolean() | nil,
  event_enable: BACnet.Protocol.EventTransitionBits.t() | nil,
  event_message_texts: BACnet.Protocol.EventMessageTexts.t() | nil,
  event_message_texts_config: BACnet.Protocol.EventMessageTexts.t() | nil,
  event_state: BACnet.Protocol.Constants.event_state(),
  event_timestamps: BACnet.Protocol.EventTimestamps.t() | nil,
  last_notify_record: BACnet.Protocol.ApplicationTags.unsigned32() | nil,
  limit_enable: BACnet.Protocol.LimitEnable.t() | nil,
  log_buffer: [BACnet.Protocol.EventLogRecord.t()],
  notification_class: non_neg_integer() | nil,
  notification_threshold: BACnet.Protocol.ApplicationTags.unsigned32() | nil,
  notify_type: BACnet.Protocol.Constants.notify_type() | nil,
  object_instance: non_neg_integer(),
  object_name: String.t(),
  profile_name: String.t() | nil,
  record_count: BACnet.Protocol.ApplicationTags.unsigned32(),
  records_since_notification:
    BACnet.Protocol.ApplicationTags.unsigned32() | nil,
  reliability: BACnet.Protocol.Constants.reliability() | nil,
  reliability_evaluation_inhibit: boolean() | nil,
  start_time: BACnet.Protocol.BACnetDateTime.t() | nil,
  status_flags: BACnet.Protocol.StatusFlags.t(),
  stop_time: BACnet.Protocol.BACnetDateTime.t() | nil,
  stop_when_full: boolean(),
  time_delay: non_neg_integer() | nil,
  time_delay_normal: non_neg_integer() | nil,
  total_record_count: BACnet.Protocol.ApplicationTags.unsigned32()
}
```

Represents a Event Log object. All keys should be treated as read-only,
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
