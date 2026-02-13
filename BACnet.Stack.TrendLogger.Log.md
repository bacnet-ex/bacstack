# `BACnet.Stack.TrendLogger.Log`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/trend_logger.ex#L99)

Internal module for `BACnet.Stack.TrendLogger`.

It is used to keep track of logging objects,
the log buffer, intrinsic reporting and other
necessary information.

# `t`

```elixir
@type t() :: %BACnet.Stack.TrendLogger.Log{
  buffer: BACnet.Stack.LogBufferBehaviour.t(),
  enabled: boolean(),
  intrinsic_reporting: BACnet.Protocol.EventAlgorithms.BufferReady.t() | nil,
  mode: BACnet.Protocol.Constants.logging_type(),
  object: BACnet.Stack.TrendLogger.object(),
  seq_number: non_neg_integer()
}
```

Representative type for its purpose.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
