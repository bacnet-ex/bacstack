# `BACnet.Protocol.Services.SubscribeCov`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/subscribe_cov.ex#L1)

This module represents the BACnet Subscribe COV service.

The Subscribe COV service is used to subscribe to changes of an object. The standardized objects that may optionally
provide COV support and the change of value algorithms they shall employ are summarized in ASHRAE 135 Table 13-1.

Service Description (ASHRAE 135):
> The SubscribeCOV service is used by a COV-client to subscribe for the receipt of notifications of changes that may occur to
> the properties of a particular object. Certain BACnet standard objects may optionally support COV reporting. If a standard
> object provides COV reporting, then changes of value of specific properties of the object, in some cases based on
> programmable increments, trigger COV notifications to be sent to one or more subscriber clients. Typically, COV
> notifications are sent to supervisory programs in BACnet client devices or to operators or logging devices. Proprietary objects
> may support COV reporting at the implementor's option. The standardized objects that may optionally provide COV support
> and the change of value algorithms they shall employ are summarized in Table 13-1.
> The subscription establishes a connection between the change of value detection and reporting mechanism within the COVserver
> device and a "process" within the COV-client device. Notifications of changes are issued by the COV-server device
> when changes occur after the subscription has been established. The ConfirmedCOVNotification and
> UnconfirmedCOVNotification services are used by the COV-server device to convey change notifications. The choice of
> confirmed or unconfirmed service is made at the time the subscription is established.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.SubscribeCov{
  issue_confirmed_notifications: boolean() | nil,
  lifetime: non_neg_integer() | nil,
  monitored_object: BACnet.Protocol.ObjectIdentifier.t(),
  process_identifier: BACnet.Protocol.ApplicationTags.unsigned32()
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.ConfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Confirmed Service Request into a Subscribe COV Service.

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

Get the Confirmed Service request for the given Subscribe COV Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
