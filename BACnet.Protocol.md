# `BACnet.Protocol`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol.ex#L1)

This module is mostly used for basic decoding of BACnet frames (Protocol Data Units - PDU).

This module handles decoding of BVLL (and delegates specifics), NPCI and NSDU.
APDU is completely covered by `BACnet.Protocol.APDU`.

For BACnet Virtual Link Layer (BVLL), it will handle it and delegate,
once it determines it is a BVLC function. BVLC function codes
such as distribute broadcast, original broad- and unicast and
forwarded NPDU are handled by this module directly.
Currently only BVLL type 0x81 (BACnet/IPv4) is implemented.

For Network Protocol Control Information (NPCI),
it will handle all decoding associated with it and handle field handling.

For Network Service Data Unit (NSDU), it will handle all decoding associated
with the regular BACnet types, excluding reserved and vendor proprietary.

For Application Data Unit (APDU), see the `BACnet.Protocol.APDU` module.

See also the following modules:
- `BACnet.Protocol.APDU`
- `BACnet.Protocol.BvlcFunction`
- `BACnet.Protocol.NPCI`
- `BACnet.Protocol.NetworkLayerProtocolMessage`

# `apdu`

```elixir
@type apdu() ::
  BACnet.Protocol.APDU.ConfirmedServiceRequest.t()
  | BACnet.Protocol.APDU.UnconfirmedServiceRequest.t()
  | BACnet.Protocol.APDU.ComplexACK.t()
  | BACnet.Protocol.APDU.SimpleACK.t()
  | BACnet.Protocol.APDU.SegmentACK.t()
  | BACnet.Protocol.APDU.Abort.t()
  | BACnet.Protocol.APDU.Error.t()
  | BACnet.Protocol.APDU.Reject.t()
```

BACnet Application Data Units (APDU).

# `bvlc`

```elixir
@type bvlc() ::
  BACnet.Protocol.BvlcForwardedNPDU.t()
  | BACnet.Protocol.BvlcFunction.t()
  | BACnet.Protocol.BvlcResult.t()
  | :distribute_broadcast_to_network
  | :original_broadcast
  | :original_unicast
```

BACnet Virtual Link Control (BVLC), used in BACnet/IP.

Transports that do not use BVLC shall use `:original_unicast` or
`:original_broadcast`, depending on whether it's a broadcast or not.

# `decode_bvll`

```elixir
@spec decode_bvll(non_neg_integer(), non_neg_integer(), binary()) ::
  {:ok, {bvlc_size :: non_neg_integer(), bvlc :: bvlc(), rest :: binary()}}
  | {:error, term()}
```

Decodes the BVLL header of a BACnet/IP packet.

# `decode_npci`

```elixir
@spec decode_npci(binary()) ::
  {:ok, {BACnet.Protocol.NPCI.t(), rest :: binary()}} | {:error, term()}
```

Decodes the NPCI header of a BACnet packet.

# `decode_npdu`

```elixir
@spec decode_npdu(BACnet.Protocol.NPCI.t(), binary()) ::
  {:ok,
   {type :: :network | :apdu,
    BACnet.Protocol.NetworkLayerProtocolMessage.t() | binary()}}
  | {:error, term()}
```

Decodes the NPDU of a BACnet packet.

For network messages, it decodes the NSDU.
For application messages, it simply returns the APDU for further processing.

# `decode_nsdu`

```elixir
@spec decode_nsdu(binary()) ::
  {:ok, BACnet.Protocol.NetworkLayerProtocolMessage.t()} | {:error, term()}
```

Decodes the NSDU of a BACnet packet.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
