# `BACnet.Protocol.Services.UnconfirmedCovNotification`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/unconfirmed_cov_notification.ex#L1)

This module represents the BACnet Unconfirmed COV Notification service (Change Of Value).

The Unconfirmed COV Notification service is used to notify a subscriber of a changed value or changed values.

Service Description (ASHRAE 135):
> The UnconfirmedCOVNotification Service is used to notify subscribers about changes that may have occurred to the
> properties of a particular object, or to distribute object properties of wide interest (such as outside air conditions) to many
> devices simultaneously without a subscription. Subscriptions for COV notifications are made using the SubscribeCOV
> service. For unsubscribed notifications, the algorithm for determining when to issue this service is a local matter and may be
> based on a change of value, periodic updating, or some other criteria.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.UnconfirmedCovNotification{
  initiating_device: BACnet.Protocol.ObjectIdentifier.t(),
  monitored_object: BACnet.Protocol.ObjectIdentifier.t(),
  process_identifier: BACnet.Protocol.ApplicationTags.unsigned32(),
  property_values: [BACnet.Protocol.PropertyValue.t()],
  time_remaining: non_neg_integer()
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.UnconfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Unconfirmed Service Request into an Unconfirmed COV Notification Service.

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

Get the Unconfirmed Service request for the given Unconfirmed COV Notification Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
