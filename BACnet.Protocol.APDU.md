# `BACnet.Protocol.APDU`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/apdu.ex#L1)

This module provides decoding of Application Data Units (APDU).
Encoding of APDUs are directly handled in the APDU modules.

APDUs can be segmented and thus will require processing and merging the segments.
The module `BACnet.Stack.SegmentsStore` fulfills this purpose and
thus all `incomplete` tuples received from `decode/1` should be passed
to an instance of that module (preferably under a supervisor).
Only `ComplexACK` and `ConfirmedServiceRequest` APDUs can be segmented,
as specified by the BACnet protocol specification.
See also the `BACnet.Stack.SegmentsStore` module documentation.

See also:
- `BACnet.Protocol.APDU.Abort`
- `BACnet.Protocol.APDU.ComplexACK`
- `BACnet.Protocol.APDU.ConfirmedServiceRequest`
- `BACnet.Protocol.APDU.Error`
- `BACnet.Protocol.APDU.Reject`
- `BACnet.Protocol.APDU.SegmentACK`
- `BACnet.Protocol.APDU.SimpleACK`
- `BACnet.Protocol.APDU.UnconfirmedServiceRequest`

# `decode`

```elixir
@spec decode(binary()) ::
  {:ok, BACnet.Protocol.apdu()}
  | {:error, term()}
  | {:incomplete, BACnet.Protocol.IncompleteAPDU.t()}
```

Decodes the APDU. The binary data must contain only APDU data.
The data must contain the APDU header (such as the PDU type byte).

If the APDU is segmented, this function will return an incomplete tuple,
which must be handled by the `BACnet.Stack.SegmentsStore` module.

See the `BACnet.Stack.SegmentsStore` module documentation for
more information about incoming segmentation (`:segmented_receive`).

# `decode_abort`

```elixir
@spec decode_abort(binary()) ::
  {:ok, BACnet.Protocol.APDU.Abort.t()} | {:error, term()}
```

Decodes the Abort APDU from binary data.
The data must contain the APDU header (such as the PDU type byte).

# `decode_complex_ack`

```elixir
@spec decode_complex_ack(binary()) ::
  {:ok, BACnet.Protocol.APDU.ComplexACK.t()}
  | {:error, term()}
  | {:incomplete, BACnet.Protocol.IncompleteAPDU.t()}
```

Decodes the Complex ACK APDU from binary data.
The data must contain the APDU header (such as the PDU type byte).

When encountering segmentation, this function will return an `incomplete` tuple.
See `BACnet.Protocol` module for more information.

# `decode_confirmed_request`

```elixir
@spec decode_confirmed_request(binary()) ::
  {:ok, BACnet.Protocol.APDU.ConfirmedServiceRequest.t()}
  | {:error, term()}
  | {:incomplete, BACnet.Protocol.IncompleteAPDU.t()}
```

Decodes the Confirmed Service Request APDU from binary data.
The data must contain the APDU header (such as the PDU type byte).

When encountering segmentation, this function will return an `incomplete` tuple.
See `BACnet.Protocol` module for more information.

# `decode_error`

```elixir
@spec decode_error(binary()) ::
  {:ok, BACnet.Protocol.APDU.Error.t()} | {:error, term()}
```

Decodes the Error APDU from binary data.
The data must contain the APDU header (such as the PDU type byte).

# `decode_reject`

```elixir
@spec decode_reject(binary()) ::
  {:ok, BACnet.Protocol.APDU.Reject.t()} | {:error, term()}
```

Decodes the Reject APDU from binary data.
The data must contain the APDU header (such as the PDU type byte).

# `decode_segment_ack`

```elixir
@spec decode_segment_ack(binary()) ::
  {:ok, BACnet.Protocol.APDU.SegmentACK.t()} | {:error, term()}
```

Decodes the Segment ACK APDU from binary data.
The data must contain the APDU header (such as the PDU type byte).

# `decode_simple_ack`

```elixir
@spec decode_simple_ack(binary()) ::
  {:ok, BACnet.Protocol.APDU.SimpleACK.t()} | {:error, term()}
```

Decodes the Simple ACK APDU from binary data.
The data must contain the APDU header (such as the PDU type byte).

# `decode_unconfirmed_request`

```elixir
@spec decode_unconfirmed_request(binary()) ::
  {:ok, BACnet.Protocol.APDU.UnconfirmedServiceRequest.t()} | {:error, term()}
```

Decodes the Unconfirmed Service Request APDU from binary data.
The data must contain the APDU header (such as the PDU type byte).

# `get_invoke_id_from_raw_apdu`

```elixir
@spec get_invoke_id_from_raw_apdu(binary()) ::
  {:ok, invoke_id :: byte()} | {:error, term()}
```

Extracts the invoke ID from the given raw APDU.

This is useful for replying to APDUs, which can not be properly fully decoded.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
