# `BACnet.Protocol.DateRange`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/date_range.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.DateRange{
  end_date: BACnet.Protocol.BACnetDate.t(),
  start_date: BACnet.Protocol.BACnetDate.t()
}
```

Represents a BACnet Date Range.

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet date range into BACnet application tags encoding.

# `get_date_range`

```elixir
@spec get_date_range(t()) :: {:ok, Date.Range.t()} | {:error, term()}
```

Get a `Date.Range` struct for this date range. Only specific dates are allowed.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet date range from BACnet application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given BACnet date range is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
