# `BACnet.Protocol.Services.ReadPropertyMultiple`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/read_property_multiple.ex#L1)

This module represents the BACnet Read Property Multiple service.

The Read Property Multiple service is used to read multiple properties of one or multiple objects.

Service Description (ASHRAE 135):
> The ReadPropertyMultiple service is used by a client BACnet-user to request the values of one or more specified properties
> of one or more BACnet Objects. This service allows read access to any property of any object, whether a BACnet-defined
> object or not. The user may read a single property of a single object, a list of properties of a single object, or any number of
> properties of any number of objects. A 'Read Access Specification' with the property identifier ALL can be used to learn the
> implemented properties of an object along with their values.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.ReadPropertyMultiple{
  list: [BACnet.Protocol.AccessSpecification.t()]
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.ConfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Confirmed Service Request into a Read Property Multiple Service.

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

Get the Confirmed Service request for the given Read Property Multiple Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
