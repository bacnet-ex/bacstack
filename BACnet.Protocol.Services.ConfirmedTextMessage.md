# `BACnet.Protocol.Services.ConfirmedTextMessage`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/confirmed_text_message.ex#L1)

This module represents the BACnet Confirmed Text Message service.

The Confirmed Text Message service is used to send a text message to one devices. What the device does with
the text message is a local matter of the recipient.

Service Description (ASHRAE 135):
> The ConfirmedTextMessage service is used by a client BACnet-user to send a text message to another BACnet device. This
> service is not a broadcast or multicast service. This service may be used in cases when confirmation that the text message
> was received is required. The confirmation does not guarantee that a human operator has seen the message. Messages may
> be prioritized into normal or urgent categories. In addition, a given text message may be optionally classified by a numeric
> class code or class identification string. This classification may be used by the receiving BACnet device to determine how
> to handle the text message. For example, the message class might indicate a particular output device on which to print text
> or a set of actions to take when the text is received. In any case, the interpretation of the class is a local matter.

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.ConfirmedTextMessage{
  class: non_neg_integer() | String.t() | nil,
  message: String.t(),
  priority: :normal | :urgent,
  source_device: BACnet.Protocol.ObjectIdentifier.t()
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.ConfirmedServiceRequest.t()) ::
  {:ok, t()} | {:error, term()}
```

Converts the given Unconfirmed Service Request into an Confirmed Text Message Service.

# `get_name`

```elixir
@spec get_name() :: atom()
```

Get the service name atom.

# `is_confirmed`

```elixir
@spec is_confirmed() :: true
```

Whether the service is of type confirmed or unconfirmed.

# `to_apdu`

```elixir
@spec to_apdu(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.APDU.ConfirmedServiceRequest.t()} | {:error, term()}
```

Get the Confirmed Service request for the given Confirmed Text Message Service.

See the `BACnet.Protocol.Services.Protocol` function documentation for more information.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
