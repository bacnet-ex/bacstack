# `BACnet.Stack.BBMD.State`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/bbmd.ex#L102)

Internal module for `BACnet.Stack.BBMD`.

It is used as `GenServer` state.

# `t`

```elixir
@type t() :: %BACnet.Stack.BBMD.State{
  bdt: [BACnet.Protocol.BroadcastDistributionTableEntry.t()],
  client: BACnet.Stack.BBMD.ClientRef.t(),
  opts: %{
    bdt_readonly: boolean(),
    max_fd_registrations: pos_integer(),
    proxy_mode: boolean()
  },
  paused: boolean(),
  registrations: %{
    optional({:inet.ip_address(), :inet.port_number()}) =&gt;
      BACnet.Stack.BBMD.Registration.t()
  }
}
```

Representative type for its purpose.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
