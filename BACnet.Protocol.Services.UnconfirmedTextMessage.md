# `BACnet.Protocol.Services.UnconfirmedTextMessage`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/unconfirmed_text_message.ex#L1)

This module represents the BACnet Unconfirmed Text Message service.

The Unconfirmed Text Message service is used to send a text message to one or more devices. What devices do with
the text message is a local matter of the recipient.

Service Description (ASHRAE 135):
> The UnconfirmedTextMessage service is used by a client BACnet-user to send a text message to one or more BACnet
> devices. This service may be broadcast, multicast, or addressed to a single recipient. This service may be used in cases
> where confirmation that the text message was received is not required. Messages may be prioritized into normal or urgent
> categories. In addition, a given text message may optionally be classified by a numeric class code or class identification
> string. This classification may be used by receiving BACnet devices to determine how to handle the text message. For
> example, the message class might indicate a particular output device on which to print text or a set of actions to take when
> the text message is received. In any case, the interpretation of the class is a local matter.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.UnconfirmedTextMessage{
  class: non_neg_integer() | String.t() | nil,
  message: String.t(),
  priority: :normal | :urgent,
  source_device: BACnet.Protocol.ObjectIdentifier.t()
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.UnconfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Unconfirmed Service Request into an Unconfirmed Text Message Service.

# `get_name`

```elixir
@spec get_name() :: atom()
```

Get the service name atom.

# `is_confirmed`

```elixir
@spec is_confirmed() :: false
```

Whether the service is of type confirmed or unconfirmed.

# `to_apdu`

```elixir
@spec to_apdu(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.APDU.UnconfirmedServiceRequest.t()} | {:error, term()}
```

Get the Unconfirmed Service request for the given Unconfirmed Text Message Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
