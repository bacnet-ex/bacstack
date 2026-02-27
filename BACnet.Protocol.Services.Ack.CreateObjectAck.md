# `BACnet.Protocol.Services.Ack.CreateObjectAck`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/ack/create_object_ack.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.Ack.CreateObjectAck{
  object_identifier: BACnet.Protocol.ObjectIdentifier.t()
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
