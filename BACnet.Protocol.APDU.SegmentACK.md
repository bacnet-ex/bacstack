# `BACnet.Protocol.APDU.SegmentACK`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/apdu/segment_ack.ex#L1)

Segment ACK APDUs are used to acknowledge the receipt of one or more frames
containing portions of a segmented message. It may also request the
next segment or segments of the segmented message.

This module has functions for encoding Segment ACK APDUs.
Decoding is handled by `BACnet.Protocol.APDU`.

This module implements the `BACnet.Stack.EncoderProtocol`.

# `t`

```elixir
@type t() :: %BACnet.Protocol.APDU.SegmentACK{
  actual_window_size: 1..127,
  invoke_id: 0..255,
  negative_ack: boolean(),
  sent_by_server: boolean(),
  sequence_number: 0..255
}
```

Represents the Application Data Unit (APDU) Segment ACK.

# `encode`

```elixir
@spec encode(t()) :: {:ok, iodata()} | {:error, Exception.t()}
```

Encodes the Segment ACK APDU into binary data.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
