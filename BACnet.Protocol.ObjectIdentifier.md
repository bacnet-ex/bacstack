# `BACnet.Protocol.ObjectIdentifier`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/object_identifier.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.ObjectIdentifier{
  instance: non_neg_integer(),
  type: BACnet.Protocol.Constants.object_type()
}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes an object identifier into application tags encoding.

# `from_number`

```elixir
@spec from_number(non_neg_integer()) :: {:ok, t()} | {:error, term()}
```

Parses the number and retrieves the object identifier from an object identifier number.

The object identifier number is a 32bit non-negative integer
which consists of a 10bit object type number and 22bit instance number.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses an object identifier from application tags encoding.

There's actually nothing special that needs to be done here, it just unwraps
and gets the `{:object_identifier, t()}` tuple from the head of the tags list.
The conversion is already handled by `ApplicationTags`.

# `to_number`

```elixir
@spec to_number(t()) :: non_neg_integer()
```

Converts the struct into an object identifier number.

The object identifier number is a 32bit non-negative integer
which consists of a 10bit object type number and 22bit instance number.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given object identifier is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
