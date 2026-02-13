# `BACnet.Stack.EncoderProtocol`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/encoder_protocol.ex#L1)

This protocol is used inside the BACnet stack (transport modules) to encode APDU structs into binary BACnet APDUs,
which then are sent through the transport layer.

# `t`

```elixir
@type t() :: term()
```

All the types that implement this protocol.

# `encode`

```elixir
@spec encode(t()) :: iodata()
```

Encodes the struct into a BACnet APDU binary packet.

Any information that is additionally required by the transport layer,
must be added by the transport layer.

Any segmentation that needs to be applied, can not and will not be
respected by this function.

# `encode_segmented`

```elixir
@spec encode_segmented(t(), integer()) :: [iodata()]
```

Same as `encode/1`, but respects the APDU maximum size.

It will output a list of segmented binaries, that can be sent ordered to the transport layer. Rules around segmentation
(such as Segment ACK) still apply for the transport layer.

Conventionally, this function simply takes the encoded body and splits it apart into individual segments
and adds the header.

# `expects_reply`

```elixir
@spec expects_reply(t()) :: boolean()
```

Whether the struct expects a reply (i.e. Confirmed Service Request).

This is useful for NPCI calculation.

# `is_request`

```elixir
@spec is_request(t()) :: boolean()
```

Whether the struct is a request.

# `is_response`

```elixir
@spec is_response(t()) :: boolean()
```

Whether the struct is a response.

# `supports_segmentation`

```elixir
@spec supports_segmentation(t()) :: boolean()
```

Whether the struct can be segmented (supported by the BACnet protocol).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
