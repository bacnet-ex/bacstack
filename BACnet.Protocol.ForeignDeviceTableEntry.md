# `BACnet.Protocol.ForeignDeviceTableEntry`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/foreign_device_table_entry.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.ForeignDeviceTableEntry{
  ip: :inet.ip4_address(),
  port: :inet.port_number(),
  remaining_time: non_neg_integer() | nil,
  time_to_live: non_neg_integer() | nil
}
```

# `decode`

```elixir
@spec decode(binary()) :: {:ok, {t(), rest :: binary()}} | {:error, term()}
```

Decodes a Foreign Device Table Entry from binary data.

# `encode`

```elixir
@spec encode(t()) :: {:ok, binary()} | {:error, term()}
```

Encodes the Foreign Device Table Entry to binary data.

If both `time_to_live` and `remaining_time` are nil,
they are not included in the binary
(useful for `Delete-Foreign-Device-Table-Entry`)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
