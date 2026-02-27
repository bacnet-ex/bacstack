# `BACnet.Protocol.Services.IAm`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/i_am.ex#L1)

This module represents the BACnet I-Am service.

The I-Am service is used as a response to the Who-Is service. It may also be used to announce itself (the device).

Service Description (ASHRAE 135):
> The I-Am service is used to respond to Who-Is service requests. However, the IAm service request may be issued at any time.
> It does not need to be preceded by the receipt of a Who-Is service request.
> In particular, a device may wish to broadcast an I-Am service request when it powers up. The network address is derived either
> from the MAC address associated with the I-Am service request, if the device issuing the request is on the local network, or
> from the NPCI if the device is on a remote network.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.IAm{
  device: BACnet.Protocol.ObjectIdentifier.t(),
  max_apdu: pos_integer(),
  segmentation_supported: BACnet.Protocol.Constants.segmentation(),
  vendor_id: BACnet.Protocol.ApplicationTags.unsigned16()
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.UnconfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Unconfirmed Service Request into an I-Am Service.

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

Get the Unconfirmed Service request for the given I-Am Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
