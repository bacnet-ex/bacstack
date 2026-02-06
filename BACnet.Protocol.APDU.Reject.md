# `BACnet.Protocol.APDU.Reject`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/apdu/reject.ex#L1)

Reject APDUs are used to reject a received confirmed service request
based on syntactical flaws or other protocol errors that prevent
the PDU from being interpreted or the requested service from being provided.
Only confirmed request PDUs may be rejected (see ASHRAE 135 Clause 18.8).
A Reject APDU shall be sent only before the execution of the service.

This module has functions for encoding Reject APDUs.
Decoding is handled by `BACnet.Protocol.APDU`.

This module implements the `BACnet.Stack.EncoderProtocol`.

# `t`

```elixir
@type t() :: %BACnet.Protocol.APDU.Reject{
  invoke_id: 0..255,
  reason: BACnet.Protocol.Constants.reject_reason() | non_neg_integer()
}
```

Represents the Application Data Unit (APDU) Reject.

To allow forward compatibility, reason is allowed to be an integer.

# `encode`

```elixir
@spec encode(t()) :: {:ok, iodata()} | {:error, Exception.t()}
```

Encodes the Reject APDU into binary data.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
