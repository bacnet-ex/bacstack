# `BACnet.Stack.Client.ApduTimer`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/client.ex#L126)

Internal module for `BACnet.Stack.Client`.

It is used as APDU timer for outgoing APDUs.
It holds together all the necessary information
to track the APDU, time, retry count and contains
information that is used to reply to the application.

# `t`

```elixir
@type t() :: %BACnet.Stack.Client.ApduTimer{
  apdu: BACnet.Protocol.apdu(),
  call_ref: term(),
  destination: term(),
  device_id: non_neg_integer() | nil,
  monotonic_time: integer(),
  portal: BACnet.Stack.TransportBehaviour.portal(),
  retry_count: non_neg_integer(),
  send_opts: Keyword.t(),
  timer: reference()
}
```

Representative type for its purpose.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
