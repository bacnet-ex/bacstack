# `BACnet.Protocol.Services.GetEventInformation`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/get_event_information.ex#L1)

This module represents the BACnet Get Event Information service.

The Get Event Information service is used to get a list of active event states from a device.
Active event states refers to all abnormal events of event-initiating objects.

Service Description (ASHRAE 135):
> The GetEventInformation service is used by a client BACnet-user to obtain a summary of all "active event states". The term
> "active event states" refers to all event-initiating objects that
>   (a) have an Event_State property whose value is not equal to NORMAL, or
>   (b) have an Acked_Transitions property, which has at least one of the bits (TO_OFFNORMAL, TO_FAULT, TO_NORMAL) set to FALSE.
> This service is intended to be implemented in all devices that generate event notifications.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.GetEventInformation{
  last_received_object_identifier: BACnet.Protocol.ObjectIdentifier.t() | nil
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.ConfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Confirmed Service Request into a Get Event Information Service.

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

Get the Confirmed Service request for the given Get Event Information Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
