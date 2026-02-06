# `BACnet.Stack.BBMD.Registration`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/bbmd.ex#L78)

Internal module for `BACnet.Stack.BBMD`.

It is used to track registration of Foreign Device
inside the BBMD.

# `t`

```elixir
@type t() :: %BACnet.Stack.BBMD.Registration{
  expires_at: NaiveDateTime.t() | nil,
  state: :active | :waiting_for_ack | :uninitialized,
  target: {:inet.ip_address(), :inet.port_number()},
  timer: reference(),
  ttl: non_neg_integer()
}
```

Representative type for its purpose.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
