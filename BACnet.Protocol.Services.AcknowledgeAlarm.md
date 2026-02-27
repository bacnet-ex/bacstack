# `BACnet.Protocol.Services.AcknowledgeAlarm`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/acknowledge_alarm.ex#L1)

This module represents the BACnet Acknowledge Alarm service.

The Acknowledge Alarm service is used to acknowledge a human operator has seen the alarm notification.

Service Description (ASHRAE 135):
> In some systems a device may need to know that an operator has seen the alarm notification. The AcknowledgeAlarm service
> is used by a notification-client to acknowledge that a human operator has seen and responded to an event notification with
> 'AckRequired' = TRUE. Ensuring that the acknowledgment actually comes from a person with appropriate authority is a local
> matter. This service may be used in conjunction with either the ConfirmedEventNotification service or the
> UnconfirmedEventNotification service.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.AcknowledgeAlarm{
  acknowledge_source: String.t(),
  event_object: BACnet.Protocol.ObjectIdentifier.t(),
  event_state_acknowledged: BACnet.Protocol.Constants.event_state(),
  event_timestamp: BACnet.Protocol.BACnetTimestamp.t(),
  process_identifier: BACnet.Protocol.ApplicationTags.unsigned32(),
  time_of_ack: BACnet.Protocol.BACnetTimestamp.t()
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.ConfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Confirmed Service Request into an Acknowledge Alarm Service.

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

Get the Confirmed Service request for the given Acknowledge Alarm Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
