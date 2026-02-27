# `BACnet.Protocol.Device.ServicesSupported`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/device/services_supported.ex#L1)

BACnet Services need to be supported by the device, in order for a BACnet client
to be able to invoke them.

This module contains a struct that represents the support state for each service.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Device.ServicesSupported{
  acknowledge_alarm: boolean(),
  add_list_element: boolean(),
  atomic_read_file: boolean(),
  atomic_write_file: boolean(),
  authenticate: boolean(),
  confirmed_cov_notification: boolean(),
  confirmed_cov_notification_multiple: boolean(),
  confirmed_event_notification: boolean(),
  confirmed_private_transfer: boolean(),
  confirmed_text_message: boolean(),
  create_object: boolean(),
  delete_object: boolean(),
  device_communication_control: boolean(),
  get_alarm_summary: boolean(),
  get_enrollment_summary: boolean(),
  get_event_information: boolean(),
  i_am: boolean(),
  i_have: boolean(),
  life_safety_operation: boolean(),
  read_property: boolean(),
  read_property_conditional: boolean(),
  read_property_multiple: boolean(),
  read_range: boolean(),
  reinitialize_device: boolean(),
  remove_list_element: boolean(),
  request_key: boolean(),
  subscribe_cov: boolean(),
  subscribe_cov_property: boolean(),
  subscribe_cov_property_multiple: boolean(),
  time_synchronization: boolean(),
  unconfirmed_cov_notification: boolean(),
  unconfirmed_cov_notification_multiple: boolean(),
  unconfirmed_event_notification: boolean(),
  unconfirmed_private_transfer: boolean(),
  unconfirmed_text_message: boolean(),
  utc_time_synchronization: boolean(),
  vt_close: boolean(),
  vt_data: boolean(),
  vt_open: boolean(),
  who_has: boolean(),
  who_is: boolean(),
  write_group: boolean(),
  write_property: boolean(),
  write_property_multiple: boolean()
}
```

Represents which BACnet protocol services are supported.

The following services are deprecated:
- authenticate
- request_key

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes the struct into BACnet application tag bitstring.

# `parse`

```elixir
@spec parse(
  BACnet.Protocol.ApplicationTags.encoding()
  | BACnet.Protocol.ApplicationTags.Encoding.t()
  | [
      BACnet.Protocol.ApplicationTags.encoding()
      | BACnet.Protocol.ApplicationTags.Encoding.t()
    ]
) :: {:ok, t()} | {:error, term()}
```

Decodes the BACnet application tag bitstring into a struct.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
