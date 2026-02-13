# `BACnet.Protocol.WeekNDay`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/week_n_day.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.WeekNDay{
  month: 1..12 | :even | :odd | :unspecified,
  week_of_month: 1..6 | :unspecified,
  weekday: 1..7 | :unspecified
}
```

Represents a BACnet Week And Day, which can have unspecified (= any) or even/odd values.

Week of month specifies which week of the month:
- `1` - Days numbered 1-7
- `2` - Days numbered 8-14
- `3` - Days numbered 15-21
- `4` - Days numbered 22-28
- `5` - Days numbered 29-31
- `6` - Last 7 days of this month

Weekday specifies the day of the week, starting with monday to sunday (1-7).

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet week and day into application tags encoding.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet week and day from application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given BACnet week and day is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
