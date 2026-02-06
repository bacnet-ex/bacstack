# `BACnet.Protocol.Services.UnconfirmedPrivateTransfer`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/unconfirmed_private_transfer.ex#L1)

This module represents the BACnet Unconfirmed Private Transfer service.

The Unconfirmed Private Transfer service is used to invoke proprietary or non-standard services in a BACnet device.

Service Description (ASHRAE 135):
> The UnconfirmedPrivateTransfer is used by a client BACnet-user to invoke proprietary or non-standard services in a
> remote device. The specific proprietary services that may be provided by a given device are not defined by this standard.
> The PrivateTransfer services provide a mechanism for specifying a particular proprietary service in a standardized manner.
> The only required parameters for these services are a vendor identification code and a service number. Additional
> parameters may be supplied for each service if required. The form and content of these additional parameters, if any, are not
> defined by this standard. The vendor identification code and service number together serve to unambiguously identify the
> intended purpose of the information conveyed by the remainder of the APDU or the service to be performed by the remote
> device based on parameters in the remainder of the APDU.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.UnconfirmedPrivateTransfer{
  parameters: [BACnet.Protocol.ApplicationTags.Encoding.t()] | nil,
  service_number: non_neg_integer(),
  vendor_id: BACnet.Protocol.ApplicationTags.unsigned16()
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.UnconfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Unconfirmed Service Request into an Unconfirmed Private Transfer Service.

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

Get the Unconfirmed Service request for the given Unconfirmed Private Transfer Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
