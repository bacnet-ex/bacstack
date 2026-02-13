# `BACnet.Protocol.Services.RemoveListElement`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/remove_list_element.ex#L1)

This module represents the BACnet Remove List Element service.

The Remove List Element service is used to remove elements from a list property.

Service Description (ASHRAE 135):
> The RemoveListElement service is used by a client BACnet-user to remove one or more elements from the property of an
> object that is a list. If an element is itself a list, the entire element shall be removed. This service does not operate on nested
> lists.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.RemoveListElement{
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

Converts the given Confirmed Service Request into a Remove List Element Service.

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

Get the Confirmed Service request for the given Remove List Element Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
