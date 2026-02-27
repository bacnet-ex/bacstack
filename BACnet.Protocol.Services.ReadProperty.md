# `BACnet.Protocol.Services.ReadProperty`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/read_property.ex#L1)

This module represents the BACnet Read Property service.

The Read Property service is used to read a property of an object.

Service Description (ASHRAE 135):
> The ReadProperty service is used by a client BACnet-user to request the value of one property of one BACnet Object. This
> service allows read access to any property of any object, whether a BACnet-defined object or not.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.ReadProperty{
  object_identifier: BACnet.Protocol.ObjectIdentifier.t(),
  property_array_index: non_neg_integer() | nil,
  property_identifier:
    BACnet.Protocol.Constants.property_identifier() | non_neg_integer()
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.ConfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Confirmed Service Request into a Read Property Service.

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

Get the Confirmed Service request for the given Read Property Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
