# `BACnet.Protocol.BACnetTime`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/bacnet_time.ex#L1)

A BACnet Time is used to represent timepoints of the day, but also can represent
unspecific timepoints, such as a single component being unspecified
(i.e. can match anything in that component).

This module provides some helpers to convert `Time` into a `BACnetTime` and back.

# `t`

```elixir
@type t() :: %BACnet.Protocol.BACnetTime{
  hour: 0..23 | :unspecified,
  hundredth: 0..99 | :unspecified,
  minute: 0..59 | :unspecified,
  second: 0..59 | :unspecified
}
```

Represents a BACnet Time, which can have unspecified values (= any).

One hundredth corresponds to 0.01 of a second.

# `compare`

```elixir
@spec compare(t(), t()) :: :gt | :eq | :lt
```

Compares two BACnet Time.

Returns `:gt` if first time is later than the second,
and `:lt` for vice versa.
If the two times are equal, `:eq` is returned.

Note that this is achieved by converting to `Time` and then
comparing them.

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes the given BACnet Time into an application tag.

# `from_time`

```elixir
@spec from_time(Time.t()) :: t()
```

Converts a `Time` into a BACnet Time.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet Time from BACnet application tags encoding.

# `specific?`

```elixir
@spec specific?(t()) :: boolean()
```

Checks whether the given BACnet Time is a specific time value
(every component is a numeric value).

# `to_time`

```elixir
@spec to_time(t(), Time.t()) :: {:ok, Time.t()} | {:error, term()}
```

Converts a BACnet Time into a `Time`.

If any of the fields are unspecified, the reference time (current UTC value) is used.

# `to_time!`

```elixir
@spec to_time!(t(), Time.t()) :: Time.t() | no_return()
```

Bang-version of `to_time/1`.

# `utc_now`

```elixir
@spec utc_now() :: t()
```

Creates a new BACnet Time with the current UTC time.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given BACnet time is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
