# `BACnet.Protocol.EventAlgorithms.Extended`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/event_algorithms/extended.ex#L1)

Implements the BACnet event algorithm `Extended`.

The Extended event algorithm detects event conditions based on a proprietary event algorithm.
The proprietary event algorithm uses algorithms and conditions defined by the vendor.
The algorithm is identified by a vendor-specific event type that is in the scope of the
vendor's vendor identification code. The algorithm may, at the vendor's discretion,
indicate a new event state, a transition to the same event state, or no transition to the
Event-State-Detection. The indicated new event states may be NORMAL, and any OffNormal event state.
FAULT event state may not be indicated by this algorithm. For the purpose of proprietary evaluation
of unreliability conditions that may result in FAULT event state,
a FAULT_EXTENDED fault algorithm shall be used.

For more specific information about the event algorithm, consult ASHRAE 135 13.3.10.

This module has NO implementation.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
