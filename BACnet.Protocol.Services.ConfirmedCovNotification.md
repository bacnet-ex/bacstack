# `BACnet.Protocol.Services.ConfirmedCovNotification`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/confirmed_cov_notification.ex#L1)

This module represents the BACnet Confirmed COV Notification service.

The Confirmed COV Notification service is used to notify a subscriber of a changed value or changed values and requires an
acknowledge by the subscriber of reception of this event notification.

Service Description (ASHRAE 135):
> The ConfirmedCOVNotification service is used to notify subscribers about changes that may have occurred to the properties
> of a particular object. Subscriptions for COV notifications are made using the SubscribeCOV service or the
> SubscribeCOVProperty service.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.ConfirmedCovNotification{
  initiating_device: BACnet.Protocol.ObjectIdentifier.t(),
  monitored_object: BACnet.Protocol.ObjectIdentifier.t(),
  process_identifier: BACnet.Protocol.ApplicationTags.unsigned32(),
  property_values: [BACnet.Protocol.PropertyValue.t()],
  time_remaining: non_neg_integer()
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.ConfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Confirmed Service Request into a Confirmed COV Notification Service.

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

Get the Confirmed Service request for the given Confirmed COV Notification Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
