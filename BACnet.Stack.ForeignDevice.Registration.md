# `BACnet.Stack.ForeignDevice.Registration`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/foreign_device.ex#L44)

Internal module for `BACnet.Stack.ForeignDevice`.

It is used to track registration as Foreign Device
in a remote BBMD.

# `t`

```elixir
@type t() :: %BACnet.Stack.ForeignDevice.Registration{
  bbmd: {:inet.ip_address(), :inet.port_number()},
  expires_at: NaiveDateTime.t() | nil,
  status: :registered | :waiting_for_ack | :uninitialized,
  timer: reference()
}
```

Representative type for its purpose.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
