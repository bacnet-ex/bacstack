# `BACnet.Protocol.CalendarEntry`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/calendar_entry.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.CalendarEntry{
  date: BACnet.Protocol.BACnetDate.t() | nil,
  date_range: BACnet.Protocol.DateRange.t() | nil,
  type: :date | :date_range | :week_n_day,
  week_n_day: BACnet.Protocol.WeekNDay.t() | nil
}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encode a calendar entry into application tag-encoded.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parse application tag-encoded calendar entry into a struct.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given BACnet calendar entry is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
