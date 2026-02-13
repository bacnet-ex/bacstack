# `BACnet.Protocol.ResultFlags`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/result_flags.ex#L1)

BACnet Result Flags conveys several flags that describe characteristics of the response data.

* The FIRST_ITEM flag indicates whether this response includes the first list or array element
  (in the case of positional indexing), or the oldest timestamped item (in the case of time indexing).
* The LAST_ITEM flag indicates whether this response includes the last list or array element
  (in the case of positional indexing), or the newest timestamped item (in the case of time indexing).
* The MORE_ITEMS flag indicates whether more items matched the request but were not transmittable within the PDU.

# `t`

```elixir
@type t() :: %BACnet.Protocol.ResultFlags{
  first_item: boolean(),
  last_item: boolean(),
  more_items: boolean()
}
```

Represents BACnet result flags.

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet result flags into application tags encoding.

# `from_bitstring`

```elixir
@spec from_bitstring(tuple()) :: t()
```

Creates from an application tag bitstring a result flags.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet result flags from application tags encoding.

# `to_bitstring`

```elixir
@spec to_bitstring(t()) :: BACnet.Protocol.ApplicationTags.primitive_encoding()
```

Creates an application tag bitstring from a result flags.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given result flags is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
