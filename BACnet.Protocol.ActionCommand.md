# `BACnet.Protocol.ActionCommand`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/action_command.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.ActionCommand{
  device_identifier: BACnet.Protocol.ObjectIdentifier.t() | nil,
  object_identifier: BACnet.Protocol.ObjectIdentifier.t(),
  post_delay: non_neg_integer() | nil,
  priority: 1..16 | nil,
  property_array_index: non_neg_integer() | nil,
  property_identifier:
    BACnet.Protocol.Constants.property_identifier() | non_neg_integer(),
  property_value: BACnet.Protocol.ApplicationTags.Encoding.t(),
  quit_on_failure: boolean(),
  write_successful: boolean()
}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encode a BACnet action command into application tag-encoded.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parse a BACnet action command from application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given action command is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
