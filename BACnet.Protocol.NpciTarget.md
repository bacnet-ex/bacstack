# `BACnet.Protocol.NpciTarget`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/npci_target.ex#L1)

Network Protocol Control Information targets are used to describe
source and destination targets (network and address information) inside
of Network Protocol Control Information (`BACnet.Protocol.NPCI`).

BACnet describes the following address sizes for the different
transport layers (data link layer):

| Data Link Layer     | DLEN | SLEN | Encoding Rules                               |
|:-------------------:|:----:|:----:|:---------------------------------------------|
| ARCnet              | 1    | 1    | MAC layer representation                     |
| BACnet/IP           | 6    | 6    | IP address and Port (ASHRAE 135 Annex J.1.2) |
| Ethernet            | 6    | 6    | MAC layer representation                     |
| LonTalk (broadcast) | 2    | 2    | Special encoding (ASHRAE 135 6.2.2.2)        |
| LonTalk (multicast) | 2    | 2    | Special encoding (ASHRAE 135 6.2.2.2)        |
| LonTalk (unicast)   | 2    | 2    | Special encoding (ASHRAE 135 6.2.2.2)        |
| LonTalk (Neuron ID) | 7    | 6    | Special encoding (ASHRAE 135 6.2.2.2)        |
| MS/TP               | 1    | 1    | MAC layer representation                     |
| ZigBee              | 3    | 3    | VMAC address (ASHRAE 135 Annex H.7)          |

# `is_global_broadcast`
*macro* 

Checks if the NPCI target is a global broadcast (net == 65535).

# `is_remote_broadcast`
*macro* 

Checks if the NPCI target is a remote broadcast (address == nil).

# `is_remote_station`
*macro* 

Checks if the NPCI target is neither a global broadcast nor a remote broadcast.

# `t`

```elixir
@type t() :: %BACnet.Protocol.NpciTarget{
  address: non_neg_integer() | nil,
  net: 1..65535
}
```

Represents a NPCI target, such as used for source or destination.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
