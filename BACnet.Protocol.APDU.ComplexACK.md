# `BACnet.Protocol.APDU.ComplexACK`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/apdu/complex_ack.ex#L1)

Complex ACK APDUs are used to convey the information contained
in a positive service response primitive that contains information
in addition to the fact that the service request
was successfully carried out.

This module has functions for encoding Complex ACK APDUs.
Decoding is handled by `BACnet.Protocol.APDU`.

This module implements the `BACnet.Stack.EncoderProtocol`.

# `t`

```elixir
@type t() :: %BACnet.Protocol.APDU.ComplexACK{
  invoke_id: 0..255,
  payload: BACnet.Protocol.ApplicationTags.encoding_list(),
  proposed_window_size: 1..127 | nil,
  sequence_number: 0..255 | nil,
  service:
    BACnet.Protocol.Constants.confirmed_service_choice() | non_neg_integer()
}
```

Represents the Application Data Unit (APDU) Complex ACK.

To allow forward compatibility, service is allowed to be an integer.

# `encode`

```elixir
@spec encode(t()) :: {:ok, iodata()} | {:error, Exception.t()}
```

Encodes the Complex ACK APDU into binary data.

Note that segmentation is ignored.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
