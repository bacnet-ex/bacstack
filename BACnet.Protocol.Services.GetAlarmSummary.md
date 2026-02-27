# `BACnet.Protocol.Services.GetAlarmSummary`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/get_alarm_summary.ex#L1)

This module represents the BACnet Get Alarm Summary service.

The Get Alarm Summary service is used to get a list of active alarms from a device.
Active alarm refers to all abnormal events.

Service Description (ASHRAE 135):
> The GetAlarmSummary service is used by a client BACnet-user to obtain a summary of "active alarms." The term "active
> alarm" refers to BACnet standard objects that have an Event_State property whose value is not equal to NORMAL and a
> Notify_Type property whose value is ALARM. The GetEnrollmentSummary service provides a more sophisticated approach
> with various kinds of filters.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.GetAlarmSummary{}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.ConfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Confirmed Service Request into a Get Alarm Summary Service.

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

Get the Confirmed Service request for the given Get Alarm Summary Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
