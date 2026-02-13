# `BACnet.Stack.ForeignDevice.State`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/foreign_device.ex#L67)

Internal module for `BACnet.Stack.ForeignDevice`.

It is used as `GenServer` state.

# `t`

```elixir
@type t() :: %BACnet.Stack.ForeignDevice.State{
  bbmd: {:inet.ip_address(), :inet.port_number()},
  broadcast_addr: {:inet.ip_address(), :inet.port_number()},
  client: BACnet.Stack.Client.server(),
  ip_addr: {:inet.ip_address(), :inet.port_number()},
  opts: %{reply_rfd: boolean(), ttl: pos_integer()},
  portal: BACnet.Stack.TransportBehaviour.portal(),
  registration: BACnet.Stack.ForeignDevice.Registration.t(),
  transport: BACnet.Stack.TransportBehaviour.transport(),
  transport_module: module()
}
```

Representative type for its purpose.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
