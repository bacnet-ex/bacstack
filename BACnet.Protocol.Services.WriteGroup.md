# `BACnet.Protocol.Services.WriteGroup`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/write_group.ex#L1)

This module represents the BACnet Write Group service.

The Write Group service is used to write efficiently values to a large number of devices and objects.

Service Description (ASHRAE 135):
> The purpose of WriteGroup is to facilitate the efficient distribution of values to a large number of devices and objects.
> WriteGroup provides compact representations for data values that allow rapid transfer of many values. See Clause 12-53 and
> Figure 12-10.
> The WriteGroup service is used by a sending BACnet-user to update arbitrary Channel objects' Present_Value properties for
> a particular numbered control group. The WriteGroup service is an unconfirmed service. Upon receipt of a WriteGroup
> service request, all devices that are members of the specified control group shall write to their corresponding Channel objects'
> Present_Value properties with the value applicable to the Channel Number, if any. A device shall be considered to be a
> member of a control group if that device has one or more Channel objects for which the 'Group Number' from the service
> appears in its Control_Groups property. If the receiving device does not contain one or more Channel objects with matching
> channel numbers, then those values shall be ignored.
> The WriteGroup service may be unicast, multicast, broadcast locally, on a particular remote network, or using the global
> BACnet network address. Since global broadcasts are generally discouraged, the use of multiple directed broadcasts is
> preferred.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.WriteGroup{
  changelist: [BACnet.Protocol.GroupChannelValue.t()],
  group_number: BACnet.Protocol.ApplicationTags.unsigned32(),
  inhibit_delay: boolean() | nil,
  write_priority: 1..16
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.UnconfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Unconfirmed Service Request into a Write Group Service.

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

Get the Unconfirmed Service request for the given Write Group Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
