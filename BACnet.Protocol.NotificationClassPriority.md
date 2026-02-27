# `BACnet.Protocol.NotificationClassPriority`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/notification_class_priority.ex#L1)

The notification class priority BACnet array is used to convey the priority
used for event notifications. A lower number indicates a higher priority.

# `t`

```elixir
@type t() :: %BACnet.Protocol.NotificationClassPriority{
  to_fault: 0..255,
  to_normal: 0..255,
  to_offnormal: 0..255
}
```

Represents the notification class priority array (three priorities).

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet notification class priority (BACnetArray[3] of Unsigned) into BACnet application tags encoding.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet notification class priority (BACnetArray[3] of Unsigned) from BACnet application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given notification class priority is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
