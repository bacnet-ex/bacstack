# `BACnet.Protocol.BvlcFunction`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/bvlc_function.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.BvlcFunction{
  data:
    [BACnet.Protocol.BroadcastDistributionTableEntry.t()]
    | [BACnet.Protocol.ForeignDeviceTableEntry.t()]
    | (delete_foreign_device_table_entry ::
         BACnet.Protocol.ForeignDeviceTableEntry.t())
    | (read_broadcast_distribution_table :: nil)
    | (read_foreign_device_table :: nil)
    | (register_foreign_device :: non_neg_integer()),
  function: BACnet.Protocol.Constants.bvlc_result_purpose()
}
```

# `decode`

```elixir
@spec decode(non_neg_integer(), binary()) :: {:ok, t()} | {:error, term()}
```

Decodes BACnet Virtual Link Control Functions into a struct.

Supported are the following BVLC functions:
- Delete-Foreign-Device-Table-Entry
- Read-Broadcast-Distribution-Table
- Read-Broadcast-Distribution-Table-Ack
- Read-Foreign-Device-Table
- Read-Foreign-Device-Table-Ack
- Register-Foreign-Device
- Write-Broadcast-Distribution-Table

# `encode`

```elixir
@spec encode(t()) ::
  {:ok, {bvlc_function :: non_neg_integer(), data :: binary()}}
  | {:error, term()}
```

Encodes BACnet Virtual Link Control Functions into binary data.

Supported are the following BVLC functions:
- Delete-Foreign-Device-Table-Entry
- Read-Broadcast-Distribution-Table
- Read-Broadcast-Distribution-Table-Ack
- Read-Foreign-Device-Table
- Read-Foreign-Device-Table-Ack
- Register-Foreign-Device
- Write-Broadcast-Distribution-Table

---

*Consult [api-reference.md](api-reference.md) for complete listing*
