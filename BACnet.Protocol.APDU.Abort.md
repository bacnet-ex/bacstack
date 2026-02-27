# `BACnet.Protocol.APDU.Abort`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/apdu/abort.ex#L1)

Abort APDUs are used to terminate a transaction between two peers.

This module has functions for encoding Abort APDUs.
Decoding is handled by `BACnet.Protocol.APDU`.

This module implements the `BACnet.Stack.EncoderProtocol`.

# `t`

```elixir
@type t() :: %BACnet.Protocol.APDU.Abort{
  invoke_id: 0..255,
  reason: BACnet.Protocol.Constants.abort_reason() | non_neg_integer(),
  sent_by_server: boolean()
}
```

Represents the Application Data Unit (APDU) Abort.

To allow forward compatibility, reason is allowed to be an integer.

# `encode`

```elixir
@spec encode(t()) :: {:ok, iodata()} | {:error, Exception.t()}
```

Encodes the Abort APDU into binary data.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
