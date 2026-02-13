# `BACnet.Protocol.Services.LifeSafetyOperation`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/life_safety_operation.ex#L1)

This module represents the BACnet Life Safety Operation service.

The Life Safety Operation service is used to provide a mechanism for human operators to silence audible or visual appliances,
reset notification appliances, or unsilence previously silenced appliances.

Service Description (ASHRAE 135):
> The LifeSafetyOperation service is intended for use in fire, life safety and security systems to provide a mechanism for
> conveying specific instructions from a human operator to accomplish any of the following objectives:
>   (a) silence audible or visual notification appliances,
>   (b) reset latched notification appliances, or
>   (c) unsilence previously silenced audible or visual notification appliances.
> Ensuring that the LifeSafetyOperation request actually comes from a person with appropriate authority is a local matter.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.LifeSafetyOperation{
  object_identifier: BACnet.Protocol.ObjectIdentifier.t() | nil,
  request: BACnet.Protocol.Constants.life_safety_operation(),
  requesting_process_identifier: BACnet.Protocol.ApplicationTags.unsigned32(),
  requesting_source: String.t()
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.ConfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Confirmed Service Request into a Life Safety Operation Service.

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

Get the Confirmed Service request for the given Life Safety Operation Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
