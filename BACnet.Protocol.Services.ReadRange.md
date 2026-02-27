# `BACnet.Protocol.Services.ReadRange`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/read_range.ex#L1)

This module represents the BACnet Read Range service.

The Read Range service is used to read range of a property of an object.

Service Description (ASHRAE 135):
> The ReadRange service is used by a client BACnet-user to read a specific range of data items representing a subset of data
> available within a specified object property. The service may be used with any list or array of lists property.

# `range`

```elixir
@type range() ::
  {:by_position,
   {reference_index :: non_neg_integer(),
    count :: BACnet.Protocol.ApplicationTags.signed16()}}
  | {:by_seq_number,
     {reference_seq_number :: BACnet.Protocol.ApplicationTags.unsigned32(),
      count :: BACnet.Protocol.ApplicationTags.signed16()}}
  | {:by_time,
     {reference_time :: BACnet.Protocol.BACnetDateTime.t(),
      count :: BACnet.Protocol.ApplicationTags.signed16()}}
```

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.ReadRange{
  object_identifier: BACnet.Protocol.ObjectIdentifier.t(),
  property_array_index: non_neg_integer() | nil,
  property_identifier:
    BACnet.Protocol.Constants.property_identifier() | non_neg_integer(),
  range: range() | nil
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.ConfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Confirmed Service Request into a Read Range Service.

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

Get the Confirmed Service request for the given Read Range Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
