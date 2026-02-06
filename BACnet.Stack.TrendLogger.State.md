# `BACnet.Stack.TrendLogger.State`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/trend_logger.ex#L132)

Internal module for `BACnet.Stack.TrendLogger`.

It is used as `GenServer` state.

# `t`

```elixir
@type t() :: %BACnet.Stack.TrendLogger.State{
  log_buff_mod: module(),
  logs: %{
    optional(
      {BACnet.Protocol.Constants.object_type(),
       instance_number :: non_neg_integer()}
    ) =&gt; %BACnet.Stack.TrendLogger.Log{
      buffer: term(),
      enabled: term(),
      intrinsic_reporting: term(),
      mode: term(),
      object: term(),
      seq_number: term()
    }
  },
  opts: %{
    cov_cb:
      (pid(),
       BACnet.Protocol.DeviceObjectPropertyRef.t(),
       :sub
       | :unsub,
       non_neg_integer(),
       float()
       | nil -&gt;
         :ok | {:error, term()})
      | nil,
    lookup_cb:
      (BACnet.Protocol.DeviceObjectRef.t() -&gt;
         {:ok, BACnet.Stack.TrendLogger.object()} | {:error, term()}),
    notification_receiver: Process.dest() | nil,
    supervisor: Supervisor.supervisor() | nil,
    timezone: Calendar.time_zone()
  }
}
```

Representative type for its purpose.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
