# `BACnet.Protocol.Services.Ack.ConfirmedPrivateTransferAck`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/ack/confirmed_private_transfer_ack.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.Ack.ConfirmedPrivateTransferAck{
  result: [BACnet.Protocol.ApplicationTags.Encoding.t()],
  service_number: non_neg_integer(),
  vendor_id: BACnet.Protocol.ApplicationTags.unsigned16()
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
