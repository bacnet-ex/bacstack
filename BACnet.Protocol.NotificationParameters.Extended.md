# `BACnet.Protocol.NotificationParameters.Extended`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/notification_parameters.ex#L255)

Represents the BACnet event algorithm `Extended` notification parameters.

The Extended event algorithm detects notification conditions based on a proprietary event algorithm. The proprietary notification
algorithm uses parameters and conditions defined by the vendor. The algorithm is identified by a vendor-specific notification type
that is in the scope of the vendor's vendor identification code. The algorithm may, at the vendor's discretion, indicate a new
notification state, a transition to the same notification state, or no transition to the Event-State-Detection. The indicated new notification states
may be NORMAL, and any OffNormal notification state. FAULT notification state may not be indicated by this algorithm. For the
purpose of proprietary evaluation of unreliability conditions that may result in FAULT notification state, a FAULT_EXTENDED
fault algorithm shall be used.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.10.

# `t`

```elixir
@type t() :: %BACnet.Protocol.NotificationParameters.Extended{
  extended_notification_type: non_neg_integer(),
  parameters: [BACnet.Protocol.ApplicationTags.Encoding.t()],
  vendor_id: BACnet.Protocol.ApplicationTags.unsigned16()
}
```

Representative type for the notification parameter.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
