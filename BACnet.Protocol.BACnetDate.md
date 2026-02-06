# `BACnet.Protocol.BACnetDate`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/bacnet_date.ex#L1)

A BACnet Date is used to represent dates, but also can represent unspecific dates,
such as a single component being unspecified (i.e. can match anything in that component),
or can be something like targeting even or odd numbers.

This can be used, for example, for Calendar functionality
(such as defining holidays occurring on the same day of year).

This module provides some helpers to convert `Date` into a `BACnetDate` and back.

# `t`

```elixir
@type t() :: %BACnet.Protocol.BACnetDate{
  day: 1..31 | :even | :odd | :last | :unspecified,
  month: 1..12 | :even | :odd | :unspecified,
  weekday: 1..7 | :unspecified,
  year: 1900..2154 | :unspecified
}
```

Represents a BACnet Date, which can have unspecified (= any) or even/odd values.

Weekday specifies the day of the week, starting with monday to sunday (1-7).

# `compare`

```elixir
@spec compare(t(), t()) :: :gt | :eq | :lt
```

Compares two BACnet Date.

Returns `:gt` if first date is later than the second,
and `:lt` for vice versa.
If the two dates are equal, `:eq` is returned.

Note that this is achieved by converting to `Date` and then
comparing them.

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes the given BACnet Date into an application tag.

# `from_date`

```elixir
@spec from_date(Date.t()) :: t()
```

Converts a `Date` to a BACnet Date.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet Date from BACnet application tags encoding.

# `specific?`

```elixir
@spec specific?(t()) :: boolean()
```

Checks whether the given BACnet Date is a specific date value
(every component is a numeric value, `:last` in the day component counts as specific).

# `to_date`

```elixir
@spec to_date(t(), Date.t()) :: {:ok, Date.t()} | {:error, term()}
```

Converts the BACnet Date to a `Date`.

If any of the fields are unspecified, the reference date (current UTC value) is used.
In case of even or odd, either the current or the previous value of the reference date is used.

# `to_date!`

```elixir
@spec to_date!(t(), Date.t()) :: Date.t() | no_return()
```

Bang-version of `to_date/1`.

# `utc_today`

```elixir
@spec utc_today() :: t()
```

Creates a new BACnet Date with the current UTC date.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given BACnet date is in form valid.

It only validates the struct is valid as per type specification,
it does not validate that the day matches the weekday.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
