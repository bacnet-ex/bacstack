# `BACnet.Protocol.Services.Error.DeleteObjectError`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/services/error/delete_object_error.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.Services.Error.DeleteObjectError{
  error_class: BACnet.Protocol.Constants.error_class() | non_neg_integer(),
  error_code: BACnet.Protocol.Constants.error_code() | non_neg_integer(),
  first_failed_element_number: non_neg_integer()
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
