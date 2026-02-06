# `BACnet.Stack.SegmentsStore.Sequence`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/segments_store.ex#L44)

Internal module for `BACnet.Stack.SegmentsStore`.

It is used to keep track of segmentation status and information,
segmentation segments and transport information.

# `t`

```elixir
@type t() :: %BACnet.Stack.SegmentsStore.Sequence{
  count_segments: non_neg_integer(),
  duplicate_count: non_neg_integer(),
  initial_sequence_number: non_neg_integer(),
  invoke_id: non_neg_integer(),
  last_sequence_number: non_neg_integer() | nil,
  last_sequence_time: integer() | nil,
  monotonic_time: integer(),
  portal: BACnet.Stack.TransportBehaviour.portal(),
  segments: [binary()],
  send_opts: Keyword.t(),
  server: boolean(),
  source_address: term(),
  timeout_count: non_neg_integer(),
  timer: term(),
  transport_module: module(),
  window_size: non_neg_integer()
}
```

Representative type for its purpose.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
