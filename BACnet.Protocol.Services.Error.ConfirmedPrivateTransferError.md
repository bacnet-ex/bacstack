# `BACnet.Protocol.Services.Error.ConfirmedPrivateTransferError`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/error/confirmed_private_transfer_error.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.Error.ConfirmedPrivateTransferError{
  error_class: BACnet.Protocol.Constants.error_class(),
  error_code: BACnet.Protocol.Constants.error_code() | non_neg_integer(),
  invoke_id: term(),
  parameters: BACnet.Protocol.ApplicationTags.encoding_list() | nil,
  service_number: non_neg_integer(),
  vendor_id: BACnet.Protocol.ApplicationTags.unsigned16()
}
```

# `from_apdu`

```elixir
@spec from_apdu(BACnet.Protocol.APDU.Error.t()) :: {:ok, t()} | {:error, term()}
```

# `to_apdu`

```elixir
@spec to_apdu(t(), 0..255) :: {:ok, BACnet.Protocol.APDU.Error.t()} | {:error, term()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
