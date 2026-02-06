# `BACnet.Protocol.Utility`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/utility.ex#L1)

Various utility functions to help with the BACnet protocol.

# `pattern_extract_tags`
*macro* 

```elixir
@spec pattern_extract_tags(
  BACnet.Protocol.ApplicationTags.encoding_list(),
  any(),
  BACnet.Protocol.ApplicationTags.primitive_type()
  | (BACnet.Protocol.ApplicationTags.encoding() -&gt;
       {:ok, any()} | {:error, any()})
  | nil,
  boolean()
) :: Macro.t()
```

Helper function to extract and unfold the tag from a linked list of BACnet application tags.

Returns `{:ok, value, rest}` if the tag was found and successfully unfolded (if needed to),
returns `{:error, :missing_pattern}` if tag was not found and is not optional,
returns `{:error, term}` otherwise. `value` is unwrapped and does not contain the tag tuple,
if the tag value was unfolded. Otherwise it's the complete tag encoding tuple.

It also allows to give an anonymous function or capture with arity 1,
which transforms the complete tag encoding tuple (if found).
It must return `{:ok, value}` or `{:error, term}`. In case of `:ok`,
this will be transformed to `{:ok, value, rest}`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
