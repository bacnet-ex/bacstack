# `BACnet.Protocol.APDU.SimpleACK`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/apdu/simple_ack.ex#L1)

Simple ACK APDUs are used to convey the information contained
in a positive service response primitive that contains no other
information except that the service request was successfully carried out.

This module has functions for encoding Simple ACK APDUs.
Decoding is handled by `BACnet.Protocol.APDU`.

This module implements the `BACnet.Stack.EncoderProtocol`.

# `t`

```elixir
@type t() :: %BACnet.Protocol.APDU.SimpleACK{
  invoke_id: 0..255,
  service:
    BACnet.Protocol.Constants.confirmed_service_choice() | non_neg_integer()
}
```

Represents the Application Data Unit (APDU) Simple ACK.

To allow forward compatibility, service is allowed to be an integer.

# `encode`

```elixir
@spec encode(t()) :: {:ok, iodata()} | {:error, Exception.t()}
```

Encodes the Simple ACK APDU into binary data.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
