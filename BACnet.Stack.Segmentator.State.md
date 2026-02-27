# `BACnet.Stack.Segmentator.State`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/segmentator.ex#L106)

Internal module for `BACnet.Stack.Segmentator`.

It is used as `GenServer` state.

# `t`

```elixir
@type t() :: %BACnet.Stack.Segmentator.State{
  opts: map(),
  sequences: %{
    optional({destination_address :: term(), invoke_id :: byte()}) =&gt;
      %BACnet.Stack.Segmentator.Sequence{
        destination: term(),
        invoke_id: term(),
        module: term(),
        monotonic_time: term(),
        portal: term(),
        retry_count: term(),
        segments: term(),
        send_opts: term(),
        seq_timer: term(),
        sequence_number: term(),
        server: term(),
        timer: term(),
        transport: term(),
        window_size: term()
      }
  }
}
```

Representative type for its purpose.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
