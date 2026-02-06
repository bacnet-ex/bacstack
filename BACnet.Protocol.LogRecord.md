# `BACnet.Protocol.LogRecord`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/log_record.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.LogRecord{
  log_datum:
    BACnet.Protocol.LogStatus.t()
    | BACnet.Protocol.ApplicationTags.Encoding.t()
    | BACnet.Protocol.BACnetError.t()
    | {:time_change, float()}
    | nil,
  status_flags: BACnet.Protocol.StatusFlags.t() | nil,
  timestamp: BACnet.Protocol.BACnetDateTime.t()
}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encode a BACnet log record into application tag-encoded.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parse a BACnet log record from application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given log record is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
