# `BACnet.Protocol.AddressBinding`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/address_binding.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.AddressBinding{
  address: binary(),
  device_identifier: BACnet.Protocol.ObjectIdentifier.t(),
  network: BACnet.Protocol.NetworkLayerProtocolMessage.dnet()
}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet address binding into BACnet application tags encoding.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet address binding from BACnet application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given address binding is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
