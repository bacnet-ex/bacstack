# `BACnet.Protocol.ObjectTypes.Device`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/object_types/device.ex#L1)

The Device object type defines a standardized object whose properties represent
the externally visible characteristics of a BACnet Device.
There shall be exactly one Device object in each BACnet Device.
A Device object is referenced by its Object_Identifier property,
which is not only unique to the BACnet Device that maintains this object
but is also unique throughout the BACnet internetwork.

(ASHRAE 135 - Clause 12.11)

---------------------------------------------------------------------------
The following part has been automatically generated.

<details>
<summary>Click to expand</summary>

This module defines a BACnet object of the type `device`. The following properties are defined:

| Property | Revision | Required | Readonly | Protected | Intrinsic |
|----------|----------|----------|----------|-----------|-----------|
| active_cov_subscriptions |  |  | X |  |  |
| align_intervals |  |  |  |  |  |
| apdu_segment_timeout |  |  | X |  |  |
| apdu_timeout |  | X | X |  |  |
| application_software_version |  | X | X |  |  |
| auto_slave_discovery |  |  |  |  |  |
| backup_and_restore_state |  |  | X |  |  |
| backup_failure_timeout |  |  | X |  |  |
| backup_preparation_time |  |  | X |  |  |
| configuration_files |  |  | X |  |  |
| database_revision |  | X | X |  |  |
| daylight_savings_status |  |  | X |  |  |
| description |  |  |  |  |  |
| device_address_binding |  | X |  |  |  |
| firmware_revision |  | X | X |  |  |
| interval_offset |  |  |  |  |  |
| last_restart_reason |  |  | X |  |  |
| last_restore_time |  |  | X |  |  |
| local_date |  |  | X |  |  |
| local_time |  |  | X |  |  |
| location |  |  |  |  |  |
| manual_slave_address_binding |  |  |  |  |  |
| max_apdu_length_accepted |  | X | X |  |  |
| max_info_frames |  |  | X |  |  |
| max_master |  |  | X |  |  |
| max_segments_accepted |  |  | X |  |  |
| model_name |  | X | X |  |  |
| number_of_apdu_retries |  | X | X |  |  |
| object_instance |  | X | X |  |  |
| object_list |  | X | X |  |  |
| object_name |  | X | X |  |  |
| profile_name |  |  |  |  |  |
| protocol_object_types_supported |  | X | X |  |  |
| protocol_revision |  | X | X |  |  |
| protocol_services_supported |  | X | X |  |  |
| protocol_version |  | X | X |  |  |
| restart_notification_recipients |  |  |  |  |  |
| restore_completion_time |  |  | X |  |  |
| restore_preparation_time |  |  | X |  |  |
| segmentation_supported |  | X | X |  |  |
| serial_number |  |  |  |  |  |
| slave_address_binding |  |  |  |  |  |
| slave_proxy_enable |  |  |  |  |  |
| structured_object_list |  | X | X |  |  |
| system_status |  | X | X |  |  |
| time_of_device_restart |  |  | X |  |  |
| time_synchronization_recipients |  |  |  |  |  |
| utc_offset |  |  | X |  |  |
| utc_time_synchronization_recipients |  |  |  |  |  |
| vendor_identifier |  | X | X |  |  |
| vendor_name |  | X | X |  |  |

The following properties have additional semantics:

| Property | Has Default | Has Init | Implicit Relationships | Validators | Annotations |
|----------|-------------|----------|------------------------|------------|-------------|
| active_cov_subscriptions | X |  |  |  |  |
| align_intervals | X |  | interval_offset |  |  |
| apdu_segment_timeout |  |  |  |  | `required_when: {:{}, [line: 128, column: 35], [:property, :segmentation_supported, :!=, :no_segmentation]}` |
| apdu_timeout | X |  |  |  |  |
| application_software_version | X |  |  |  |  |
| auto_slave_discovery |  |  | slave_address_binding |  |  |
| backup_and_restore_state |  |  |  |  | `required_when: {:opts, :supports_backup_restore}` |
| backup_failure_timeout |  |  | backup_preparation_time | Type | `required_when: {:opts, :supports_backup_restore}` |
| backup_preparation_time |  |  | restore_preparation_time | Type | `required_when: {:opts, :supports_backup_restore}` |
| configuration_files |  |  | last_restore_time |  | `required_when: {:opts, :supports_backup_restore}` |
| database_revision | X |  |  |  |  |
| device_address_binding | X |  |  |  |  |
| firmware_revision | X |  |  |  |  |
| interval_offset | X |  |  |  |  |
| last_restart_reason | X |  | time_of_device_restart |  |  |
| last_restore_time |  |  | backup_failure_timeout |  | `required_when: {:opts, :supports_backup_restore}` |
| local_date |  | X |  |  |  |
| local_time |  | X |  |  |  |
| manual_slave_address_binding | X |  |  |  |  |
| max_apdu_length_accepted | X |  |  |  |  |
| max_master |  |  | max_info_frames | Type |  |
| max_segments_accepted |  |  |  |  | `required_when: {:{}, [line: 133, column: 35], [:property, :segmentation_supported, :!=, :no_segmentation]}` |
| model_name | X |  |  |  |  |
| number_of_apdu_retries | X |  |  |  |  |
| object_list | X |  |  |  |  |
| protocol_object_types_supported | X |  |  |  |  |
| protocol_revision | X |  |  |  |  |
| protocol_services_supported | X |  |  |  |  |
| protocol_version | X |  |  |  |  |
| restart_notification_recipients | X |  |  |  | `required_when: {:&, [line: 175, column: 35], [{:and, [line: 175, column: 48], [{:is_map, [line: 175, column: 37], [{:&, [line: 175, column: 44], [1]}]}, {:==, [line: 175, column: 74], [{{:., [from_brackets: true, line: 175, column: 54], [Access, :get]}, [from_brackets: true, line: 175, column: 54], [{:&, [line: 175, column: 52], [2]}, :supports_restart]}, true]}]}]}` |
| restore_completion_time |  |  | backup_and_restore_state | Type | `required_when: {:opts, :supports_backup_restore}` |
| restore_preparation_time |  |  | restore_completion_time | Type | `required_when: {:opts, :supports_backup_restore}` |
| slave_address_binding | X |  | manual_slave_address_binding |  |  |
| slave_proxy_enable |  |  | auto_slave_discovery |  |  |
| structured_object_list | X |  |  |  |  |
| system_status | X |  |  |  |  |
| time_of_device_restart | X |  | restart_notification_recipients |  |  |
| time_synchronization_recipients | X |  | interval_offset |  |  |
| utc_offset | X |  |  |  |  |
| utc_time_synchronization_recipients | X |  | interval_offset |  |  |
| vendor_identifier |  |  |  | Type |  |
| vendor_name | X |  |  |  |  |

The following table shows the default values and/or init functions:

| Property | Default Value | Init Function |
|----------|---------------|---------------|
| active_cov_subscriptions | `[]` |  |
| apdu_timeout | `3000` |  |
| application_software_version | `"bacstack-ex v0.1.0"` |  |
| database_revision | `1` |  |
| device_address_binding | `[]` |  |
| firmware_revision | `"bacstack-ex v0.1.0"` |  |
| interval_offset | `""` |  |
| last_restart_reason | `:unknown` |  |
| local_date |  | `BACnet.Protocol.BACnetDate.utc_today/0` |
| local_time |  | `BACnet.Protocol.BACnetTime.utc_now/0` |
| manual_slave_address_binding | `[]` |  |
| max_apdu_length_accepted | `1476` |  |
| model_name | `"bacstack-ex"` |  |
| number_of_apdu_retries | `3` |  |
| object_list | <a title="#BACnet.Protocol.BACnetArray<size: 0, items: [], fixed_size: nil>">`%BACnet.Protocol.BACnetArray{...}`</a> |  |
| protocol_object_types_supported | <a title="%BACnet.Protocol.Device.ObjectTypesSupported{lift: false, escalator: false, elevator_group: false, network_port: false, binary_lighting_output: false, lighting_output: false, channel: false, alert_enrollment: false, notification_forwarder: false, time_value: false, time_pattern_value: false, positive_integer_value: false, octet_string_value: false, large_analog_value: false, integer_value: false, datetime_value: false, datetime_pattern_value: false, date_value: false, date_pattern_value: false, character_string_value: false, bitstring_value: false, network_security: false, credential_data_input: false, access_zone: false, access_user: false, access_rights: false, access_point: false, access_credential: false, timer: false, access_door: false, structured_view: false, load_control: false, trend_log_multiple: false, global_group: false, event_log: false, pulse_converter: false, accumulator: false, life_safety_zone: false, life_safety_point: false, trend_log: false, multi_state_value: false, averaging: false, schedule: false, program: false, notification_class: false, multi_state_output: false, multi_state_input: false, loop: false, group: false, file: false, ...}">`%BACnet.Protocol.Device.ObjectTypesSupported{...}`</a> |  |
| protocol_revision | `0` |  |
| protocol_services_supported | <a title="%BACnet.Protocol.Device.ServicesSupported{unconfirmed_cov_notification_multiple: false, confirmed_cov_notification_multiple: false, subscribe_cov_property_multiple: false, write_group: false, get_event_information: false, subscribe_cov_property: false, life_safety_operation: false, utc_time_synchronization: false, read_range: false, who_is: false, who_has: false, time_synchronization: false, unconfirmed_text_message: false, unconfirmed_private_transfer: false, unconfirmed_event_notification: false, unconfirmed_cov_notification: false, i_have: false, i_am: false, request_key: false, authenticate: false, vt_data: false, vt_close: false, vt_open: false, reinitialize_device: false, confirmed_text_message: false, confirmed_private_transfer: false, device_communication_control: false, write_property_multiple: false, write_property: false, read_property_multiple: false, read_property_conditional: false, read_property: false, delete_object: false, create_object: false, remove_list_element: false, add_list_element: false, atomic_write_file: false, atomic_read_file: false, subscribe_cov: false, get_enrollment_summary: false, get_alarm_summary: false, confirmed_event_notification: false, confirmed_cov_notification: false, acknowledge_alarm: false}">`%BACnet.Protocol.Device.ServicesSupported{...}`</a> |  |
| protocol_version | `1` |  |
| restart_notification_recipients | `[]` |  |
| slave_address_binding | `[]` |  |
| structured_object_list | <a title="#BACnet.Protocol.BACnetArray<size: 0, items: [], fixed_size: nil>">`%BACnet.Protocol.BACnetArray{...}`</a> |  |
| system_status | `:operational` |  |
| time_of_device_restart | <a title="%BACnet.Protocol.BACnetTimestamp{type: :datetime, time: nil, sequence_number: nil, datetime: %BACnet.Protocol.BACnetDateTime{date: %BACnet.Protocol.BACnetDate{year: :unspecified, month: :unspecified, day: :unspecified, weekday: :unspecified}, time: %BACnet.Protocol.BACnetTime{hour: :unspecified, minute: :unspecified, second: :unspecified, hundredth: :unspecified}}}">`%BACnet.Protocol.BACnetTimestamp{...}`</a> |  |
| time_synchronization_recipients | `[]` |  |
| utc_offset | `0` |  |
| utc_time_synchronization_recipients | `[]` |  |
| vendor_name | `""` |  |
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
  {:supports_backup_restore, boolean()}
  | {:supports_restart, boolean()}
  | common_object_opts()
```

Available object options.

# `property_name`

```elixir
@type property_name() ::
  :active_cov_subscriptions
  | :align_intervals
  | :apdu_segment_timeout
  | :apdu_timeout
  | :application_software_version
  | :auto_slave_discovery
  | :backup_and_restore_state
  | :backup_failure_timeout
  | :backup_preparation_time
  | :configuration_files
  | :database_revision
  | :daylight_savings_status
  | :description
  | :device_address_binding
  | :firmware_revision
  | :interval_offset
  | :last_restart_reason
  | :last_restore_time
  | :local_date
  | :local_time
  | :location
  | :manual_slave_address_binding
  | :max_apdu_length_accepted
  | :max_info_frames
  | :max_master
  | :max_segments_accepted
  | :model_name
  | :number_of_apdu_retries
  | :object_instance
  | :object_list
  | :object_name
  | :profile_name
  | :protocol_object_types_supported
  | :protocol_revision
  | :protocol_services_supported
  | :protocol_version
  | :restart_notification_recipients
  | :restore_completion_time
  | :restore_preparation_time
  | :segmentation_supported
  | :serial_number
  | :slave_address_binding
  | :slave_proxy_enable
  | :structured_object_list
  | :system_status
  | :time_of_device_restart
  | :time_synchronization_recipients
  | :utc_offset
  | :utc_time_synchronization_recipients
  | :vendor_identifier
  | :vendor_name
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
@type t() :: %BACnet.Protocol.ObjectTypes.Device{
  _metadata: internal_metadata(),
  _unknown_properties: %{
    optional(atom() | non_neg_integer()) =&gt;
      term()
      | BACnet.Protocol.ApplicationTags.Encoding.t()
      | [BACnet.Protocol.ApplicationTags.Encoding.t()]
  },
  active_cov_subscriptions: [BACnet.Protocol.CovSubscription.t()] | nil,
  align_intervals: boolean() | nil,
  apdu_segment_timeout: non_neg_integer() | nil,
  apdu_timeout: non_neg_integer(),
  application_software_version: String.t(),
  auto_slave_discovery: BACnet.Protocol.BACnetArray.t(boolean()) | nil,
  backup_and_restore_state: BACnet.Protocol.Constants.backup_state() | nil,
  backup_failure_timeout: BACnet.Protocol.ApplicationTags.unsigned16() | nil,
  backup_preparation_time: BACnet.Protocol.ApplicationTags.unsigned16() | nil,
  configuration_files:
    BACnet.Protocol.BACnetArray.t(BACnet.Protocol.ObjectIdentifier.t()) | nil,
  database_revision: non_neg_integer(),
  daylight_savings_status: boolean() | nil,
  description: String.t() | nil,
  device_address_binding: [BACnet.Protocol.AddressBinding.t()],
  firmware_revision: String.t(),
  interval_offset: String.t() | nil,
  last_restart_reason: BACnet.Protocol.Constants.restart_reason() | nil,
  last_restore_time: BACnet.Protocol.BACnetTimestamp.t() | nil,
  local_date: BACnet.Protocol.BACnetDate.t() | nil,
  local_time: BACnet.Protocol.BACnetTime.t() | nil,
  location: String.t() | nil,
  manual_slave_address_binding: [BACnet.Protocol.AddressBinding.t()] | nil,
  max_apdu_length_accepted: 50..1476,
  max_info_frames: non_neg_integer() | nil,
  max_master: 1..127 | nil,
  max_segments_accepted: non_neg_integer() | nil,
  model_name: String.t(),
  number_of_apdu_retries: non_neg_integer(),
  object_instance: non_neg_integer(),
  object_list:
    BACnet.Protocol.BACnetArray.t(BACnet.Protocol.ObjectIdentifier.t()),
  object_name: String.t(),
  profile_name: String.t() | nil,
  protocol_object_types_supported:
    BACnet.Protocol.Device.ObjectTypesSupported.t(),
  protocol_revision: non_neg_integer(),
  protocol_services_supported: BACnet.Protocol.Device.ServicesSupported.t(),
  protocol_version: non_neg_integer(),
  restart_notification_recipients: [BACnet.Protocol.Recipient.t()] | nil,
  restore_completion_time: BACnet.Protocol.ApplicationTags.unsigned16() | nil,
  restore_preparation_time: BACnet.Protocol.ApplicationTags.unsigned16() | nil,
  segmentation_supported: BACnet.Protocol.Constants.segmentation(),
  serial_number: String.t() | nil,
  slave_address_binding: [BACnet.Protocol.AddressBinding.t()] | nil,
  slave_proxy_enable: BACnet.Protocol.BACnetArray.t(boolean()) | nil,
  structured_object_list:
    BACnet.Protocol.BACnetArray.t(BACnet.Protocol.ObjectIdentifier.t()),
  system_status: BACnet.Protocol.Constants.device_status(),
  time_of_device_restart: BACnet.Protocol.BACnetTimestamp.t() | nil,
  time_synchronization_recipients: [BACnet.Protocol.Recipient.t()] | nil,
  utc_offset: integer() | nil,
  utc_time_synchronization_recipients: [BACnet.Protocol.Recipient.t()] | nil,
  vendor_identifier: BACnet.Protocol.ApplicationTags.unsigned16(),
  vendor_name: String.t()
}
```

Represents a Device object. All keys should be treated as read-only,
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

# `get_vendor_ids`

```elixir
@spec get_vendor_ids() :: %{optional(non_neg_integer()) =&gt; String.t()}
```

Get the list of known vendor IDs to vendor names.

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
