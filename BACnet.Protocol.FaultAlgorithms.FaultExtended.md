# `BACnet.Protocol.FaultAlgorithms.FaultExtended`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/fault_algorithms/fault_extended.ex#L1)

Represents the BACnet fault algorithm `FaultExtended`.

The FAULT_EXTENDED fault algorithm detects fault conditions based on a
proprietary fault algorithm. The proprietary fault algorithm uses parameters
and conditions defined by the vendor. The algorithm is identified by a
vendor-specific fault type that is in the scope of the vendor's
vendor identification code. The algorithm may, at the vendor's discretion,
indicate a new reliability, a transition to the same reliability, or
no transition to the reliability-evaluation process.

For more specific information about the fault algorithm, consult ASHRAE 135 13.4.3.

This module has NO implementation.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
