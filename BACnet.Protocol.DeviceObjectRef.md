# `BACnet.Protocol.DeviceObjectRef`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/device_object_ref.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.DeviceObjectRef{
  device_identifier: BACnet.Protocol.ObjectIdentifier.t() | nil,
  object_identifier: BACnet.Protocol.ObjectIdentifier.t()
}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet device object reference into application tags encoding.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet device object reference into a struct.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given device object reference is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
