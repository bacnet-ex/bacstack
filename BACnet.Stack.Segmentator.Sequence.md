# `BACnet.Stack.Segmentator.Sequence`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/segmentator.ex#L58)

Internal module for `BACnet.Stack.Segmentator`.

It is used to keep track of segmentation status and information,
segmentation segments and transport information.

# `t`

```elixir
@type t() :: %BACnet.Stack.Segmentator.Sequence{
  destination: term(),
  invoke_id: byte(),
  module: module(),
  monotonic_time: integer(),
  portal: term(),
  retry_count: non_neg_integer(),
  segments: map(),
  send_opts: Keyword.t(),
  seq_timer: term(),
  sequence_number: non_neg_integer(),
  server: boolean(),
  timer: term(),
  transport: term(),
  window_size: pos_integer()
}
```

Representative type for its purpose.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
