# `BACnet.Protocol.Services.ConfirmedPrivateTransfer`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/confirmed_private_transfer.ex#L1)

This module represents the BACnet Confirmed Private Transfer service.

The Confirmed Private Transfer service is used to invoke proprietary or non-standard services in a BACnet device.

Service Description (ASHRAE 135):
> The ConfirmedPrivateTransfer is used by a client BACnet-user to invoke proprietary or non-standard services in a remote
> device. The specific proprietary services that may be provided by a given device are not defined by this standard. The
> PrivateTransfer services provide a mechanism for specifying a particular proprietary service in a standardized manner. The
> only required parameters for these services are a vendor identification code and a service number. Additional parameters
> may be supplied for each service if required. The form and content of these additional parameters, if any, are not defined by
> this standard. The vendor identification code and service number together serve to unambiguously identify the intended
> purpose of the information conveyed by the remainder of the APDU or the service to be performed by the remote device
> based on parameters in the remainder of the APDU.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.ConfirmedPrivateTransfer{
  parameters: [BACnet.Protocol.ApplicationTags.Encoding.t()] | nil,
  service_number: non_neg_integer(),
  vendor_id: pos_integer()
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.ConfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Confirmed Service Request into a Confirmed Private Transfer Service.

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

Get the Confirmed Service request for the given Confirmed Private Transfer Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
