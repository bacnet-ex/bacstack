# `BACnet.Protocol.Services.Common`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/common.ex#L1)

This module implements the parsing for some services, which are available as both confirmed
and unconfirmed. So instead of implementing the same parsing and encoding twice, this module
is the common ground for these services.

# `after_encode_convert`

```elixir
@spec after_encode_convert(
  map(),
  Keyword.t(),
  module(),
  BACnet.Protocol.Constants.confirmed_service_choice() | non_neg_integer()
) ::
  {:ok,
   BACnet.Protocol.APDU.ConfirmedServiceRequest.t()
   | BACnet.Protocol.APDU.UnconfirmedServiceRequest.t()}
```

After encode, this function can be used to turn the request parameters into a service request.

This function is used in the `Services.*` modules. Any wrong usage can only be blamed onto the user themself.

# `decode_cov_notification`

```elixir
@spec decode_cov_notification(
  BACnet.Protocol.APDU.ConfirmedServiceRequest.t()
  | BACnet.Protocol.APDU.UnconfirmedServiceRequest.t()
) :: {:ok, map()} | {:error, term()}
```

Decodes the unconfirmed or confirmed cov notification service into a base map.

This function is used by the `ConfirmedCovNotification` and `UnconfirmedCovNotification` modules.

# `decode_event_notification`

```elixir
@spec decode_event_notification(
  BACnet.Protocol.APDU.ConfirmedServiceRequest.t()
  | BACnet.Protocol.APDU.UnconfirmedServiceRequest.t()
) :: {:ok, map()} | {:error, term()}
```

Decodes the unconfirmed or confirmed event notification service into a base map.

This function is used by the `ConfirmedEventNotification` and `UnconfirmedEventNotification` modules.

# `decode_private_transfer`

```elixir
@spec decode_private_transfer(
  BACnet.Protocol.APDU.ConfirmedServiceRequest.t()
  | BACnet.Protocol.APDU.UnconfirmedServiceRequest.t()
) :: {:ok, map()} | {:error, term()}
```

Decodes the unconfirmed or confirmed private transfer service into a base map.

This function is used by the `ConfirmedPrivateTransfer` and `UnconfirmedPrivateTransfer` modules.

# `decode_text_message`

```elixir
@spec decode_text_message(
  BACnet.Protocol.APDU.ConfirmedServiceRequest.t()
  | BACnet.Protocol.APDU.UnconfirmedServiceRequest.t()
) :: {:ok, map()} | {:error, term()}
```

Decodes the unconfirmed or confirmed text message service into a base map.

This function is used by the `ConfirmedTextMessage` and `UnconfirmedTextMessage` modules.

# `encode_cov_notification`

```elixir
@spec encode_cov_notification(
  BACnet.Protocol.Services.ConfirmedCovNotification.t()
  | BACnet.Protocol.Services.UnconfirmedCovNotification.t(),
  Keyword.t()
) :: {:ok, map()} | {:error, term()}
```

Encodes the unconfirmed or confirmed COV notification service into a base map.

This function is used by the `ConfirmedCovNotification` and `UnconfirmedCovNotification` modules.

# `encode_event_notification`

```elixir
@spec encode_event_notification(
  BACnet.Protocol.Services.ConfirmedEventNotification.t()
  | BACnet.Protocol.Services.UnconfirmedEventNotification.t(),
  Keyword.t()
) :: {:ok, map()} | {:error, term()}
```

Encodes the unconfirmed or confirmed event notification service into a base map.

This function is used by the `ConfirmedEventNotification` and `UnconfirmedEventNotification` modules.

# `encode_private_transfer`

```elixir
@spec encode_private_transfer(
  BACnet.Protocol.Services.ConfirmedPrivateTransfer.t()
  | BACnet.Protocol.Services.UnconfirmedPrivateTransfer.t(),
  Keyword.t()
) :: {:ok, map()} | {:error, term()}
```

Encodes the unconfirmed or confirmed private transfer service into a base map.

This function is used by the `ConfirmedPrivateTransfer` and `UnconfirmedPrivateTransfer` modules.

# `encode_text_message`

```elixir
@spec encode_text_message(
  BACnet.Protocol.Services.ConfirmedTextMessage.t()
  | BACnet.Protocol.Services.UnconfirmedTextMessage.t(),
  Keyword.t()
) :: {:ok, map()} | {:error, term()}
```

Encodes the unconfirmed or confirmed text message service into a base map.

This function is used by the `ConfirmedTextMessage` and `UnconfirmedTextMessage` modules.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
