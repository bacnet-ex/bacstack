# `BACnet.Protocol.Services.GetEnrollmentSummary`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/get_enrollment_summary.ex#L1)

This module represents the BACnet Get Enrollment Summary service.

The Get Enrollment Summary service is used to get a list of event-initiating objects.
Several different filters may be applied.

Service Description (ASHRAE 135):
> The GetEnrollmentSummary service is used by a client BACnet-user to obtain a summary of event-initiating objects. Several
> different filters may be applied to define the search criteria. This service may be used to obtain summaries of objects with any
> event type and is thus a superset of the functionality provided by the GetAlarmSummary Service.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.GetEnrollmentSummary{
  acknowledgment_filter: :all | :acked | :not_acked,
  enrollment_filter:
    {process_identifier :: BACnet.Protocol.ApplicationTags.unsigned32(),
     BACnet.Protocol.Recipient.t()}
    | nil,
  event_state_filter: BACnet.Protocol.Constants.event_state() | nil,
  event_type_filter: BACnet.Protocol.Constants.event_type() | nil,
  notification_class_filter: non_neg_integer() | nil,
  priority_filter:
    {min :: BACnet.Protocol.ApplicationTags.unsigned8(),
     max :: BACnet.Protocol.ApplicationTags.unsigned8()}
    | nil
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.ConfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Confirmed Service Request into a Get Enrollment Summary Service.

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

Get the Confirmed Service request for the given Get Enrollment Summary Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
