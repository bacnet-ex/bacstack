# `BACnet.Protocol.Services.WritePropertyMultiple`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/write_property_multiple.ex#L1)

This module represents the BACnet Write Property Multiple service.

The Write Property Multiple service is used to write to one or more properties of one or more objects,
if commandable, with priority.

Service Description (ASHRAE 135):
> The WriteProperty service is used by a client BACnet-user to modify the value of a single specified property of a BACnet
> object. This service potentially allows write access to any property of any object, whether a BACnet-defined object or not.
> Some implementors may wish to restrict write access to certain properties of certain objects. In such cases, an attempt to
> modify a restricted property shall result in the return of an error of 'Error Class' PROPERTY and 'Error Code'
> WRITE_ACCESS_DENIED. Note that these restricted properties may be accessible through the use of Virtual Terminal
> services or other means at the discretion of the implementor.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.WritePropertyMultiple{
  list: [BACnet.Protocol.AccessSpecification.t()]
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.ConfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Confirmed Service Request into a Write Property Multiple Service.

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

Get the Confirmed Service request for the given Write Property Multiple Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
