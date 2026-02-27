# `BACnet.Protocol.Services.DeviceCommunicationControl`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/device_communication_control.ex#L1)

This module represents the BACnet Device Communication Control service.

The Device Communication Control service is used to control the communication of a device.

Service Description (ASHRAE 135):
> The DeviceCommunicationControl service is used by a client BACnet-user to instruct a remote device to stop initiating and
> optionally stop responding to all APDUs (except DeviceCommunicationControl or, if supported, ReinitializeDevice) on the
> communication network or internetwork for a specified duration of time. This service is primarily used by a human operator
> for diagnostic purposes. A password may be required from the client BACnet-user prior to executing the service. The time
> duration may be set to "indefinite," meaning communication must be re-enabled by a DeviceCommunicationControl or, if
> supported, ReinitializeDevice service, not by time.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.DeviceCommunicationControl{
  password: String.t() | nil,
  state: BACnet.Protocol.Constants.enable_disable(),
  time_duration: BACnet.Protocol.ApplicationTags.unsigned16() | nil
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.ConfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Confirmed Service Request into a Device Communication Control Service.

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

Get the Confirmed Service request for the given Device Communication Control Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
