# `BACnet.Protocol.APDU.Error`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/apdu/error.ex#L1)

Error APDUs are used to the information contained in a
service response primitive that indicates the reason why
a previous confirmed service request failed,
either in its entirety or only partially.

This module has functions for encoding Error APDUs.
Decoding is handled by `BACnet.Protocol.APDU`.

This module implements the `BACnet.Stack.EncoderProtocol`.

# `t`

```elixir
@type t() :: %BACnet.Protocol.APDU.Error{
  class: BACnet.Protocol.Constants.error_class() | non_neg_integer(),
  code: BACnet.Protocol.Constants.error_code() | non_neg_integer(),
  invoke_id: 0..255,
  payload: BACnet.Protocol.ApplicationTags.encoding_list(),
  service:
    BACnet.Protocol.Constants.confirmed_service_choice() | non_neg_integer()
}
```

Represents the Application Data Unit (APDU) Error.

To allow forward compatibility, some fields are allowed to be an integer.

# `encode`

```elixir
@spec encode(t()) :: {:ok, iodata()} | {:error, Exception.t()}
```

Encodes the Error APDU into binary data.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
