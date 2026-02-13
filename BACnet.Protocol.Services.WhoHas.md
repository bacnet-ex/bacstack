# `BACnet.Protocol.Services.WhoHas`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/who_has.ex#L1)

This module represents the BACnet Who-Has service.

The Who-Has service is used to find a specific object (by identifier or name),
either by querying all or a subset of BACnet devices.

Service Description (ASHRAE 135):
> The Who-Has service is used by a sending BACnet-user to identify the device object identifiers and network addresses of
> other BACnet devices whose local databases contain an object with a given Object_Name or a given Object_Identifier.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.WhoHas{
  device_id_high_limit: non_neg_integer() | nil,
  device_id_low_limit: non_neg_integer() | nil,
  object: BACnet.Protocol.ObjectIdentifier.t() | String.t()
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.UnconfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Unconfirmed Service Request into a Who-Has Service.

# `get_name`

```elixir
@spec get_name() :: atom()
```

Get the service name atom.

# `is_confirmed`

```elixir
@spec is_confirmed() :: false
```

Whether the service is of type confirmed or unconfirmed.

# `to_apdu`

```elixir
@spec to_apdu(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.APDU.UnconfirmedServiceRequest.t()} | {:error, term()}
```

Get the Unconfirmed Service request for the given Who-Has Service.

Additional supported `request_data`:
  - `encoding: atom()` - Optional. The encoding of the object name (defaults to `:utf8`).

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
