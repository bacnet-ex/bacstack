# `BACnet.Stack.Client.ReplyTimer`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/client.ex#L166)

Internal module for `BACnet.Stack.Client`.

It is used as reply timer for incoming APDUs.
It holds together all the necessary information
to fire when the application does not respond
fast enough and will reply negatively to the
remote BACnet client.

# `t`

```elixir
@type t() :: %BACnet.Stack.Client.ReplyTimer{
  bvlc: BACnet.Protocol.bvlc(),
  device_id: non_neg_integer() | nil,
  has_retried: boolean(),
  monotonic_time: integer(),
  npci: BACnet.Protocol.NPCI.t(),
  portal: BACnet.Stack.TransportBehaviour.portal(),
  ref: reference(),
  service_req: BACnet.Protocol.apdu(),
  source_addr: term(),
  timer: reference() | nil
}
```

Representative type for its purpose.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
