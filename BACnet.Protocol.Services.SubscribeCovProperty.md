# `BACnet.Protocol.Services.SubscribeCovProperty`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/subscribe_cov_property.ex#L1)

This module represents the BACnet Subscribe COV Property service.

The Subscribe COV Property service is used to get subscribe to changes for a particular property of an object.

Service Description (ASHRAE 135):
> The SubscribeCOVProperty service is used by a COV-client to subscribe for the receipt of notifications of changes that may
> occur to the properties of a particular object. Any object may optionally support COV reporting. If a standard object provides
> COV reporting, then changes of value of subscribed-to properties of the object, in some cases based on programmable
> increments, trigger COV notifications to be sent to one or more subscriber clients. Typically, COV notifications are sent to
> supervisory programs in BACnet client devices or to operators or logging devices.
> The subscription establishes a connection between the change of value detection and reporting mechanism within the COVserver
> device and a "process" within the COV-client device. Notifications of changes are issued by the COV-server device
> when changes occur after the subscription has been established. The ConfirmedCOVNotification and
> UnconfirmedCOVNotification services are used by the COV-server device to convey change notifications. The choice of
> confirmed or unconfirmed service is made at the time the subscription is established. Any object, proprietary or standard,
> may support COV reporting for any property at the implementor's option.
> The SubscribeCOVProperty service differs from the SubscribeCOV service in that it allows monitoring of properties other
> than those listed in Table 13-1.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.SubscribeCovProperty{
  cov_increment: float() | nil,
  issue_confirmed_notifications: boolean() | nil,
  lifetime: non_neg_integer() | nil,
  monitored_object: BACnet.Protocol.ObjectIdentifier.t(),
  monitored_property: BACnet.Protocol.PropertyRef.t(),
  process_identifier: BACnet.Protocol.ApplicationTags.unsigned32()
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.ConfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Confirmed Service Request into a Subscribe COV Property Service.

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

Get the Confirmed Service request for the given Subscribe COV Property Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
