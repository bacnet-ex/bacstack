# `BACnet.Protocol.AccessSpecification`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/access_specification.ex#L1)

Represents BACnet Access Specification, used in BACnet `Read-Property-Multiple` and `Write-Property-Multiple`,
as Read Access Specification and Write Access Specification, respectively.

# `t`

```elixir
@type t() :: %BACnet.Protocol.AccessSpecification{
  object_identifier: BACnet.Protocol.ObjectIdentifier.t(),
  properties: [
    BACnet.Protocol.AccessSpecification.Property.t()
    | :all
    | :required
    | :optional
  ]
}
```

# `encode`

```elixir
@spec encode(t(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding_list()} | {:error, term()}
```

Encodes a BACnet Read/Write Access Specification into BACnet application tags encoding.

# `parse`

```elixir
@spec parse(BACnet.Protocol.ApplicationTags.encoding_list()) ::
  {:ok, {t(), rest :: BACnet.Protocol.ApplicationTags.encoding_list()}}
  | {:error, term()}
```

Parses a BACnet Read/Write Access Specification from BACnet application tags encoding.

# `valid?`

```elixir
@spec valid?(t()) :: boolean()
```

Validates whether the given access specification is in form valid.

It only validates the struct is valid as per type specification.

Be aware, this function does not know whether it is a read or
write access specification, thus it can't verify if the special
property identifiers (atoms) are as per BACnet specification.
Only read supports the special property identifiers.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
