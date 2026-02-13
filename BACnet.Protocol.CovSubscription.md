# `BACnet.Protocol.CovSubscription`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/cov_subscription.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.CovSubscription{
  cov_increment: float() | nil,
  issue_confirmed_notifications: boolean(),
  monitored_object_property: BACnet.Protocol.ObjectPropertyRef.t(),
  recipient: BACnet.Protocol.Recipient.t(),
  recipient_process: non_neg_integer(),
  time_remaining: non_neg_integer()
}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a COV subscription struct into BACnet application tags encoding.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet COV subscription application tags encoding into a struct.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given COV subscription is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
