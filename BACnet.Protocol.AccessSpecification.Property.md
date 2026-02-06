# `BACnet.Protocol.AccessSpecification.Property`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/access_specification/property.ex#L1)

# `t`

```elixir
@type t() :: %BACnet.Protocol.AccessSpecification.Property{
  property_array_index: non_neg_integer() | nil,
  property_identifier:
    BACnet.Protocol.Constants.property_identifier() | non_neg_integer(),
  property_value: BACnet.Protocol.ApplicationTags.Encoding.t() | nil
}
```

# `encode`

```elixir
@spec encode(t() | :all | :required | :optional, Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet Read/Write Access Specification Property into BACnet application tags encoding.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok,
   {t() | :all | :required | :optional,
    rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet Read/Write Access Specification Property from BACnet application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given access specification property is in form valid.

It only validates the struct is valid as per type specification.

Be aware, this function does not know whether it is a read or
write access specification, thus it can't verify if the special
property identifiers (atoms) are as per BACnet specification.
Only read supports the special property identifiers.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
