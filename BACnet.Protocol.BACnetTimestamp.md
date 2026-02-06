# `BACnet.Protocol.BACnetTimestamp`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/bacnet_timestamp.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.BACnetTimestamp{
  datetime: BACnet.Protocol.BACnetDateTime.t() | nil,
  sequence_number: non_neg_integer() | nil,
  time: BACnet.Protocol.BACnetTime.t() | nil,
  type: :time | :sequence_number | :datetime
}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes the given BACnet timestamp into an application tag.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Decodes the given application tags encoding into a BACnet timestamp.

Example:

    iex> BACnetTimestamp.parse([{:tagged, {0, <<2, 12, 49, 0>>, 4}}])
    {:ok,
    {%BACnetTimestamp{
      datetime: nil,
      sequence_number: nil,
      time: %BACnetTime{
        hour: 2,
        hundredth: 0,
        minute: 12,
        second: 49
      },
      type: :time
    }, []}}

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given BACnet timestamp is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
