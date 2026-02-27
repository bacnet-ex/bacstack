# `BACnet.Stack.Client.State`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/client.ex#L209)

Internal module for `BACnet.Stack.Client`.

It is used as `GenServer` state.

# `app_timer_key`

```elixir
@type app_timer_key() ::
  {address :: term(), device_id :: non_neg_integer() | nil, invoke_id :: byte()}
```

Key for the application reply timer.

# `t`

```elixir
@type t() :: %BACnet.Stack.Client.State{
  apdu_timeouts: BACnet.Stack.Client.apdu_timeouts(),
  apdu_timers: %{optional(app_timer_key()) =&gt; BACnet.Stack.Client.ApduTimer.t()},
  app_reply_mapping: %{optional(reference()) =&gt; app_timer_key()},
  app_reply_timers: %{
    optional(app_timer_key()) =&gt; BACnet.Stack.Client.ReplyTimer.t()
  },
  notification_receiver: [Process.dest()],
  opts: %{
    apdu_retries: non_neg_integer(),
    apdu_timeout: pos_integer(),
    disable_app_timeout: boolean(),
    disable_invoke_id_management: boolean(),
    npci_source: BACnet.Protocol.NpciTarget.t() | nil,
    segmented_rcv_window_overwrite: boolean(),
    supervisor_mod: module()
  },
  segmentator: BACnet.Stack.Segmentator.server(),
  segments_store: BACnet.Stack.SegmentsStore.server(),
  transport_broadcast_addr: term(),
  transport_mod: module(),
  transport_pid: BACnet.Stack.TransportBehaviour.transport(),
  transport_portal: BACnet.Stack.TransportBehaviour.portal()
}
```

Representative type for its purpose.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
