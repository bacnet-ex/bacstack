# `BACnet.Protocol.Services.Ack.ReadPropertyAck`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/ack/read_property_ack.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.Ack.ReadPropertyAck{
  object_identifier: BACnet.Protocol.ObjectIdentifier.t(),
  property_array_index: non_neg_integer() | nil,
  property_identifier:
    BACnet.Protocol.Constants.property_identifier() | non_neg_integer(),
  property_value:
    BACnet.Protocol.ApplicationTags.Encoding.t()
    | [BACnet.Protocol.ApplicationTags.Encoding.t()]
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.ComplexACK.t()) :: {:ok, t()} | {:error, term()}
```

# `to_apdu`

```elixir
@spec to_apdu(t(), 0..255) ::
  {:ok, BACnet.Protocol.APDU.ComplexACK.t()} | {:error, term()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
