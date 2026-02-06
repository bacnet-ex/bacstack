# `BACnet.Protocol.Services.Ack.AtomicReadFileAck`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/ack/atomic_read_file_ack.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.Ack.AtomicReadFileAck{
  data: (stream_based :: binary()) | (record_based :: [binary()]),
  eof: boolean(),
  record_count: non_neg_integer() | nil,
  start_position: integer(),
  stream_access: boolean()
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
