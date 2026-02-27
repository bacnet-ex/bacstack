# `BACnet.Protocol.Services.UnconfirmedEventNotification`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/unconfirmed_event_notification.ex#L1)

This module represents the BACnet Unconfirmed Event Notification service.

The Unconfirmed Event Notification service is used to notify a subscriber of an event that has occurred.

Service Description (ASHRAE 135):
> The UnconfirmedEventNotification service is used by a notification-server to notify a remote device that an event has
> occurred. Its purpose is to notify recipients that an event has occurred, but confirmation that the notification was received is
> not required. Applications that require confirmation that the notification was received by the remote device should use the
> ConfirmedEventNotification service. The fact that this is an unconfirmed service does not mean it is inappropriate for
> notification of alarms. Events of type Alarm may require a human acknowledgment that is conveyed using the
> AcknowledgeAlarm service. Thus, using an unconfirmed service to announce the alarm has no effect on the ability to
> confirm that an operator has been notified. Any device that executes this service shall support programmable process
> identifiers to allow broadcast and multicast 'Process Identifier' parameters to be assigned on a per installation basis.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.UnconfirmedEventNotification{
  ack_required: boolean() | nil,
  event_object: BACnet.Protocol.ObjectIdentifier.t(),
  event_type: BACnet.Protocol.Constants.event_type(),
  event_values:
    BACnet.Protocol.NotificationParameters.notification_parameter() | nil,
  from_state: BACnet.Protocol.Constants.event_state() | nil,
  initiating_device: BACnet.Protocol.ObjectIdentifier.t(),
  message_text: String.t() | nil,
  notification_class: non_neg_integer(),
  notify_type: :alarm | :event | :ack_notification,
  priority: BACnet.Protocol.ApplicationTags.unsigned8(),
  process_identifier: BACnet.Protocol.ApplicationTags.unsigned32(),
  timestamp: BACnet.Protocol.BACnetTimestamp.t(),
  to_state: BACnet.Protocol.Constants.event_state() | nil
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.UnconfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Unconfirmed Service Request into an Unconfirmed Event Notification Service.

# `get_name`

```elixir
@spec get_name() :: atom()
```

Get the service name atom.

# `is_confirmed`

```elixir
@spec is_confirmed() :: false
```

Whether the service is of type confirmed or unconfirmed.

# `to_apdu`

```elixir
@spec to_apdu(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.APDU.UnconfirmedServiceRequest.t()} | {:error, term()}
```

Get the Unconfirmed Service request for the given Unconfirmed Event Notification Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
