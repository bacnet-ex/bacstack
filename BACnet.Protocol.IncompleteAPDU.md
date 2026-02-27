# `BACnet.Protocol.IncompleteAPDU`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/incomplete_apdu.ex#L1)

This module is used to represent a segmented incomplete APDU.

The given struct is to be fed to the `BACnet.Stack.SegmentsStore`, which will handle the segmentation.

# `t`

```elixir
@type t() :: %BACnet.Protocol.IncompleteAPDU{
  data: term(),
  header: term(),
  invoke_id: term(),
  more_follows: term(),
  sequence_number: term(),
  server: term(),
  window_size: term()
}
```

Represents an incomplete APDU.

# `set_window_size`

```elixir
@spec set_window_size(t(), 1..127) :: t()
```

Set the window size field to the given number.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
