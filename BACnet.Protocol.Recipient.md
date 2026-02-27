# `BACnet.Protocol.Recipient`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/recipient.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.Recipient{
  address: BACnet.Protocol.RecipientAddress.t() | nil,
  device: BACnet.Protocol.ObjectIdentifier.t() | nil,
  type: :address | :device
}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet recipient into application tags encoding.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Decodes the given application tags encoding into a BACnet recipient.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given BACnet recipient is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
