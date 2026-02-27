# `BACnet.Protocol.BroadcastDistributionTableEntry`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/broadcast_distribution_table_entry.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.BroadcastDistributionTableEntry{
  ip: :inet.ip4_address(),
  mask: :inet.ip4_address(),
  port: :inet.port_number()
}
```

# `decode`

```elixir
@spec decode(binary()) :: {:ok, {t(), rest :: binary()}} | {:error, term()}
```

Decodes a Broadcast Distribution Table Entry from binary data.

# `encode`

```elixir
@spec encode(t()) :: {:ok, binary()} | {:error, term()}
```

Encodes the Broadcast Distribution Table Entry to binary data.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
