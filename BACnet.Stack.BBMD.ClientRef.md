# `BACnet.Stack.BBMD.ClientRef`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/bbmd.ex#L46)

Internal module for `BACnet.Stack.BBMD`.

It is used to keep track of the necessary
client and transport information.

# `t`

```elixir
@type t() :: %BACnet.Stack.BBMD.ClientRef{
  broadcast_addr: {:inet.ip_address(), :inet.port_number()},
  ip_addr: {:inet.ip_address(), :inet.port_number()},
  portal: BACnet.Stack.TransportBehaviour.portal(),
  ref: BACnet.Stack.Client.server(),
  transport: BACnet.Stack.TransportBehaviour.transport(),
  transport_module: module()
}
```

Representative type for its purpose.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
