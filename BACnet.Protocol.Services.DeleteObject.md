# `BACnet.Protocol.Services.DeleteObject`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/delete_object.ex#L1)

This module represents the BACnet Delete Object service.

The Delete Object service is used to delete an existing object in the remote device.

Service Description (ASHRAE 135):
> The DeleteObject service is used by a client BACnet-user to delete an existing object. Although this service is general in the
> sense that it can be applied to any object type, it is expected that most objects in a control system cannot be deleted by this
> service because they are protected as a security feature. There are some objects, however, that may be created and deleted
> dynamically. Group objects and Event Enrollment objects are examples. This service is primarily used to delete objects of
> these types but may also be used to remove vendor-specific deletable objects.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.DeleteObject{
  object_specifier: BACnet.Protocol.ObjectIdentifier.t()
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.ConfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Confirmed Service Request into a Delete Object Service.

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

Get the Confirmed Service request for the given Delete Object Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
