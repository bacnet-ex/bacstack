# `BACnet.Protocol.Services.TimeSynchronization`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/time_synchronization.ex#L1)

This module represents the BACnet Time Synchronization service.

The Time Synchronization service is used to send the correct local date and time onto the BACnet network or to a single recipient.

Service Description (ASHRAE 135):
> The TimeSynchronization service is used by a requesting BACnet-user to notify a remote device of the correct current time.
> This service may be broadcast, multicast, or addressed to a single recipient. Its purpose is to notify recipients of the correct
> current time so that devices may synchronize their internal clocks with one another.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.TimeSynchronization{
  date: BACnet.Protocol.BACnetDate.t(),
  time: BACnet.Protocol.BACnetTime.t()
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.UnconfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Unconfirmed Service Request into an TimeSynchronization Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

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

Get the Unconfirmed Service request for the given TimeSynchronization Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
