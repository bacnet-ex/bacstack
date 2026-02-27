# `BACnet.Protocol.Device.ObjectTypesSupported`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/device/object_types_supported.ex#L1)

BACnet object types need to be supported by the device, in order for a BACnet client
to be able to handle them.

This module contains a struct that represents the support state for each object type.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Device.ObjectTypesSupported{
  access_credential: boolean(),
  access_door: boolean(),
  access_point: boolean(),
  access_rights: boolean(),
  access_user: boolean(),
  access_zone: boolean(),
  accumulator: boolean(),
  alert_enrollment: boolean(),
  analog_input: boolean(),
  analog_output: boolean(),
  analog_value: boolean(),
  averaging: boolean(),
  binary_input: boolean(),
  binary_lighting_output: boolean(),
  binary_output: boolean(),
  binary_value: boolean(),
  bitstring_value: boolean(),
  calendar: boolean(),
  channel: boolean(),
  character_string_value: boolean(),
  command: boolean(),
  credential_data_input: boolean(),
  date_pattern_value: boolean(),
  date_value: boolean(),
  datetime_pattern_value: boolean(),
  datetime_value: boolean(),
  device: boolean(),
  elevator_group: boolean(),
  escalator: boolean(),
  event_enrollment: boolean(),
  event_log: boolean(),
  file: boolean(),
  global_group: boolean(),
  group: boolean(),
  integer_value: boolean(),
  large_analog_value: boolean(),
  life_safety_point: boolean(),
  life_safety_zone: boolean(),
  lift: boolean(),
  lighting_output: boolean(),
  load_control: boolean(),
  loop: boolean(),
  multi_state_input: boolean(),
  multi_state_output: boolean(),
  multi_state_value: boolean(),
  network_port: boolean(),
  network_security: boolean(),
  notification_class: boolean(),
  notification_forwarder: boolean(),
  octet_string_value: boolean(),
  positive_integer_value: boolean(),
  program: boolean(),
  pulse_converter: boolean(),
  schedule: boolean(),
  structured_view: boolean(),
  time_pattern_value: boolean(),
  time_value: boolean(),
  timer: boolean(),
  trend_log: boolean(),
  trend_log_multiple: boolean()
}
```

Represents which BACnet object types are supported.

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes the struct into BACnet application tag bitstring.

# `new`

```elixir
@spec new() :: t()
```

Creates a new struct, defaulting to the local implementation status.
See `ObjectsUtility.get_supported_object_types/0`.

# `parse`

```elixir
@spec parse(
  BACnet.Protocol.ApplicationTags.encoding()
  | BACnet.Protocol.ApplicationTags.Encoding.t()
  | BACnet.Protocol.ApplicationTags.encoding_list()
) :: {:ok, t()} | {:error, term()}
```

Decodes the BACnet application tag bitstring into a struct.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
