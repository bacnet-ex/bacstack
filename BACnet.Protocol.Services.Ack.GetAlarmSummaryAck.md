# `BACnet.Protocol.Services.Ack.GetAlarmSummaryAck`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/ack/get_alarm_summary_ack.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.Ack.GetAlarmSummaryAck{
  summaries: [BACnet.Protocol.AlarmSummary.t()]
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
