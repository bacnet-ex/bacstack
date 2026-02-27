# `BACnet.Protocol.LogMultipleRecord`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/log_multiple_record.ex#L1)

# `log_data`

```elixir
@type log_data() ::
  BACnet.Protocol.ApplicationTags.Encoding.t()
  | BACnet.Protocol.BACnetError.t()
  | nil
```

Representative type for log data - possible values it can take.

# `t`

```elixir
@type t() :: %BACnet.Protocol.LogMultipleRecord{
  log_data:
    [log_data()] | BACnet.Protocol.LogStatus.t() | {:time_change, float()},
  timestamp: BACnet.Protocol.BACnetDateTime.t()
}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encode a BACnet log multiple record into application tag-encoded.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parse a BACnet log multiple record from application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given log multiple record is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
