# `BACnet.Protocol.Services.AddListElement`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/add_list_element.ex#L1)

This module represents the BACnet Add List Element service.

The Add List Element service is used to add elements to a list property.

Service Description (ASHRAE 135):
> The AddListElement service is used by a client BACnet-user to add one or more list elements
> to an object property that is a list.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.AddListElement{
  elements: [BACnet.Protocol.ApplicationTags.Encoding.t()],
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

Converts the given Confirmed Service Request into an Add List Element Service.

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

Get the Confirmed Service request for the given Add List Element Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
