# `BACnet.Protocol.Services.IHave`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/i_have.ex#L1)

This module represents the BACnet I-Have service.

The I-Have service is used as a response to the Who-Has service.

Service Description (ASHRAE 135):
> The IHave service is used to respond to Who-Has service requests or to advertise the existence of an object with a given
> Object_Name or Object_Identifier. The I-Have service request may be issued at any time and does not need to be preceded
> by the receipt of a Who-Has service request.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.IHave{
  device: BACnet.Protocol.ObjectIdentifier.t(),
  object: BACnet.Protocol.ObjectIdentifier.t(),
  object_name: String.t()
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.UnconfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Unconfirmed Service Request into an I-Have Service.

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

Get the Unconfirmed Service request for the given I-Have Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
