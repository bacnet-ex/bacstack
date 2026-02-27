# `BACnet.Protocol.EventParameters.BufferReady`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_parameters.ex#L268)

Represents the BACnet event algorithm `BufferReady` parameters.

The BufferReady event algorithm detects whether a defined number of records have been added to a log buffer since
start of operation or the previous event, whichever is most recent.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.7.

# `t`

```elixir
@type t() :: %BACnet.Protocol.EventParameters.BufferReady{
  previous_count: BACnet.Protocol.ApplicationTags.unsigned32(),
  threshold: non_neg_integer()
}
```

Representative type for the event parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
