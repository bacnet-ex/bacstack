# `BACnet.Protocol.BACnetDateTime`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/bacnet_date_time.ex#L1)

A BACnet DateTime is used to represent date with timepoints.
It wraps both `BACnetDate` and `BACnetTime`.

This module provides some helpers to convert `DateTime` and `NaiveDateTime`
into a `BACnetDateTime` and back.

# `t`

```elixir
@type t() :: %BACnet.Protocol.BACnetDateTime{
  date: BACnet.Protocol.BACnetDate.t(),
  time: BACnet.Protocol.BACnetTime.t()
}
```

Represents a BACnet DateTime. It wraps both BACnet Date and Time.

# `compare`

```elixir
@spec compare(t(), t()) :: :gt | :eq | :lt
```

Compares two BACnet DateTime.

Returns `:gt` if first datetime is later than the second,
and `:lt` for vice versa.
If the two datetimes are equal, `:eq` is returned.

Note that this is achieved by converting to `DateTime` and then
comparing them.

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes the given BACnet DateTime into an application tag.

For tagged encoding, you'll have to strip this down further
using manual efforts.

# `from_datetime`

```elixir
@spec from_datetime(DateTime.t()) :: t()
```

Converts a `DateTime` to a BACnet DateTime.

# `from_naive_datetime`

```elixir
@spec from_naive_datetime(NaiveDateTime.t()) :: t()
```

Converts a `NaiveDateTime` to a BACnet DateTime.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet DateTime from BACnet application tags encoding.

# `specific?`

```elixir
@spec specific?(t()) :: boolean()
```

Checks whether the given BACnet DateTime is a specific date-time value
(every component is a numeric value).

# `to_datetime`

```elixir
@spec to_datetime(t(), Calendar.time_zone(), Calendar.time_zone_database()) ::
  {:ok, DateTime.t()} | {:error, term()}
```

Converts the BACnet DateTime to a `DateTime`.

# `to_datetime!`

```elixir
@spec to_datetime!(t(), Calendar.time_zone(), Calendar.time_zone_database()) ::
  DateTime.t() | no_return()
```

Bang-version of `to_datetime/1`.

# `to_naive_datetime`

```elixir
@spec to_naive_datetime(t()) :: {:ok, NaiveDateTime.t()} | {:error, term()}
```

Converts the BACnet DateTime to a `NaiveDateTime`.

# `to_naive_datetime!`

```elixir
@spec to_naive_datetime!(t()) :: NaiveDateTime.t() | no_return()
```

Bang-version of `to_naive_datetime/1`.

# `utc_now`

```elixir
@spec utc_now() :: t()
```

Creates a new BACnet DateTime for the current UTC datetime.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given BACnet datetime is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
