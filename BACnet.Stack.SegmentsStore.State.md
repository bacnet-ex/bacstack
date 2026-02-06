# `BACnet.Stack.SegmentsStore.State`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/segments_store.ex#L96)

Internal module for `BACnet.Stack.SegmentsStore`.

It is used as `GenServer` state.

# `t`

```elixir
@type t() :: %BACnet.Stack.SegmentsStore.State{
  opts: map(),
  sequences: %{
    optional({source_address :: term(), invoke_id :: byte()}) =&gt;
      %BACnet.Stack.SegmentsStore.Sequence{
        count_segments: term(),
        duplicate_count: term(),
        initial_sequence_number: term(),
        invoke_id: term(),
        last_sequence_number: term(),
        last_sequence_time: term(),
        monotonic_time: term(),
        portal: term(),
        segments: term(),
        send_opts: term(),
        server: term(),
        source_address: term(),
        timeout_count: term(),
        timer: term(),
        transport_module: term(),
        window_size: term()
      }
  }
}
```

Representative type for its purpose.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
