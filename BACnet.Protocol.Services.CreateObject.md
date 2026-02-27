# `BACnet.Protocol.Services.CreateObject`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/create_object.ex#L1)

This module represents the BACnet Create Object service.

The Create Object service is used to dynamically create an object in the remote device.

Service Description (ASHRAE 135):
> The CreateObject service is used by a client BACnet-user to create a new instance of an object. This service may be used to
> create instances of both standard and vendor specific objects. The standard object types supported by this service shall be
> specified in the PICS. The properties of standard objects created with this service may be initialized in two ways: initial
> values may be provided as part of the CreateObject service request or values may be written to the newly created object using
> the BACnet WriteProperty services. The initialization of non-standard objects is a local matter. The behavior of objects
> created by this service that are not supplied, or only partially supplied, with initial property values is dependent upon the
> device and is a local matter.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.CreateObject{
  initial_values: [BACnet.Protocol.PropertyValue.t()],
  object_specifier:
    BACnet.Protocol.ObjectIdentifier.t()
    | BACnet.Protocol.Constants.object_type()
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.ConfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Confirmed Service Request into a Create Object Service.

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

Get the Confirmed Service request for the given Create Object Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
