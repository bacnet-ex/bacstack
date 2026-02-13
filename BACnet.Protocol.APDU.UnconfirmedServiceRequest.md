# `BACnet.Protocol.APDU.UnconfirmedServiceRequest`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/apdu/unconfirmed_service_request.ex#L1)

Unconfirmed Service Request APDUs are used to convey the information
contained in unconfirmed service request primitives.

Unconfirmed Service Requests are as their name implies unconfirmed,
that means a response is not required. Some services will trigger
a response from BACnet servers that match with the service request.
For example, this may be a `I Am` being transmitted due to a `Who Is` received.

This module has functions for encoding Unconfirmed Service Request APDUs.
Decoding is handled by `BACnet.Protocol.APDU`.

This module implements the `BACnet.Stack.EncoderProtocol`.

# `service`

```elixir
@type service() ::
  BACnet.Protocol.Services.IAm.t()
  | BACnet.Protocol.Services.IHave.t()
  | BACnet.Protocol.Services.WhoHas.t()
  | BACnet.Protocol.Services.WhoIs.t()
  | BACnet.Protocol.Services.TimeSynchronization.t()
  | BACnet.Protocol.Services.UnconfirmedCovNotification.t()
  | BACnet.Protocol.Services.UnconfirmedEventNotification.t()
  | BACnet.Protocol.Services.UnconfirmedPrivateTransfer.t()
  | BACnet.Protocol.Services.UnconfirmedTextMessage.t()
  | BACnet.Protocol.Services.UtcTimeSynchronization.t()
  | BACnet.Protocol.Services.WriteGroup.t()
```

BACnet Unconfirmed Service Request service structs.

# `t`

```elixir
@type t() :: %BACnet.Protocol.APDU.UnconfirmedServiceRequest{
  parameters: BACnet.Protocol.ApplicationTags.encoding_list(),
  service:
    BACnet.Protocol.Constants.unconfirmed_service_choice() | non_neg_integer()
}
```

Represents the Application Data Unit (APDU) Unconfirmed Service Request.

To allow forward compatibility, reason is allowed to be an integer.

# `encode`

```elixir
@spec encode(t()) :: {:ok, iodata()} | {:error, term()}
```

Encodes the Unconfirmed Service Request APDU into binary data.

# `to_service`

```elixir
@spec to_service(t()) :: {:ok, service()} | {:error, term()} | :not_supported
```

Converts the APDU into a service, if supported and possible.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
