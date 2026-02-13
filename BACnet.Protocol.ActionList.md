# `BACnet.Protocol.ActionList`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/action_list.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.ActionList{actions: [BACnet.Protocol.ActionCommand.t()]}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encode a BACnet action list into application tag-encoded.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parse a BACnet action list from application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given action list is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
