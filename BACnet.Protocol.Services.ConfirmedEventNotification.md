# `BACnet.Protocol.Services.ConfirmedEventNotification`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/confirmed_event_notification.ex#L1)

This module represents the BACnet Confirmed Event Notification service.

The Confirmed Event Notification service is used to notify a subscriber of an event that has occurred and requires an
acknowledge by the subscriber of reception of this event notification.

Service Description (ASHRAE 135):
> The ConfirmedEventNotification service is used by a notification-server to notify a remote device that an event has occurred
> and that the notification-server needs a confirmation that the notification has been received. This confirmation means only
> that the device received the message. It does not imply that a human operator has been notified. A separate
> AcknowledgeAlarm service is used to indicate that an operator has acknowledged the receipt of the notification if the
> notification specifies that acknowledgment is required. If multiple recipients must be notified, a separate invocation of this
> service shall be used to notify each intended recipient. If a confirmation that a notification was received is not needed, then
> the UnconfirmedEventNotification may be used.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.ConfirmedEventNotification{
  ack_required: boolean() | nil,
  event_object: BACnet.Protocol.ObjectIdentifier.t(),
  event_type: BACnet.Protocol.Constants.event_type(),
  event_values:
    BACnet.Protocol.NotificationParameters.notification_parameter() | nil,
  from_state: BACnet.Protocol.Constants.event_state() | nil,
  initiating_device: BACnet.Protocol.ObjectIdentifier.t(),
  message_text: String.t() | nil,
  notification_class: non_neg_integer(),
  notify_type: BACnet.Protocol.Constants.notify_type(),
  priority: BACnet.Protocol.ApplicationTags.unsigned8(),
  process_identifier: BACnet.Protocol.ApplicationTags.unsigned32(),
  timestamp: BACnet.Protocol.BACnetTimestamp.t(),
  to_state: BACnet.Protocol.Constants.event_state() | nil
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.ConfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Confirmed Service Request into a Confirmed Event Notification Service.

# `get_name`

```elixir
@spec get_name() :: atom()
```

Get the service name atom.

# `is_confirmed`

```elixir
@spec is_confirmed() :: true
```

Whether the service is of type confirmed or unconfirmed.

# `to_apdu`

```elixir
@spec to_apdu(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.APDU.ConfirmedServiceRequest.t()} | {:error, term()}
```

Get the Confirmed Service request for the given Confirmed Event Notification Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
