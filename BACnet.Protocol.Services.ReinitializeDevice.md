# `BACnet.Protocol.Services.ReinitializeDevice`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/reinitialize_device.ex#L1)

This module represents the BACnet Reinitialize Device service.

The Device Communication Control service is used to instruct a device to reboot or reset to a predefined state,
or to control backup or restore services.

Service Description (ASHRAE 135):
> The ReinitializeDevice service is used by a client BACnet-user to instruct a remote device to reboot itself (cold start), reset
> itself to some predefined initial state (warm start), or to control the backup or restore procedure. Resetting or rebooting a
> device is primarily initiated by a human operator for diagnostic purposes. Use of this service during the backup or restore
> procedure is usually initiated on behalf of the user by the device controlling the backup or restore. Due to the sensitive
> nature of this service, a password may be required by the responding BACnet-user prior to executing the service.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.ReinitializeDevice{
  password: String.t() | nil,
  reinitialized_state: BACnet.Protocol.Constants.reinitialized_state()
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.ConfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Confirmed Service Request into a Reinitialize Device Service.

# `get_name`

```elixir
@spec get_name() :: atom()
```

Get the service name atom.

# `is_confirmed`

```elixir
@spec is_confirmed() :: true
```

Whether the service is of type confirmed or unconfirmed.

# `to_apdu`

```elixir
@spec to_apdu(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.APDU.ConfirmedServiceRequest.t()} | {:error, term()}
```

Get the Confirmed Service request for the given Reinitialize Device Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
