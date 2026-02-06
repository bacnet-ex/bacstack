# `BACnet.Protocol.EnrollmentSummary`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/enrollment_summary.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.EnrollmentSummary{
  event_state: BACnet.Protocol.Constants.event_state(),
  event_type: BACnet.Protocol.Constants.event_type(),
  notification_class: non_neg_integer() | nil,
  object_identifier: BACnet.Protocol.ObjectIdentifier.t(),
  priority: byte()
}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet enrollment summary into BACnet application tags encoding.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet enrollment summary from BACnet application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given enrollment summary is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
