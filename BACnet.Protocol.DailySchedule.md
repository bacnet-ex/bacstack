# `BACnet.Protocol.DailySchedule`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/daily_schedule.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.DailySchedule{schedule: [BACnet.Protocol.TimeValue.t()]}
```

Represents a BACnet Daily Schedule.

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encode a BACnet daily schedule into application tag-encoded.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parse a BACnet daily schedule from application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given daily schedule is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
