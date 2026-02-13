# `BACnet.Protocol.FaultParameters`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/fault_parameters.ex#L1)

BACnet has various different types of fault parameters.
Each of them is represented by a different module.

Consult the module `BACnet.Protocol.FaultAlgorithms` for
details about each fault's algorithm.

# `fault_parameter`

```elixir
@type fault_parameter() ::
  BACnet.Protocol.FaultParameters.None.t()
  | BACnet.Protocol.FaultParameters.FaultCharacterString.t()
  | BACnet.Protocol.FaultParameters.FaultExtended.t()
  | BACnet.Protocol.FaultParameters.FaultLifeSafety.t()
  | BACnet.Protocol.FaultParameters.FaultState.t()
  | BACnet.Protocol.FaultParameters.FaultStatusFlags.t()
```

Possible BACnet fault parameters.

# `encode`

```elixir
@spec encode(fault_parameter(), Keyword.t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding()} | {:error, term()}
```

# `parse`

```elixir
@spec parse(binary()) :: {:ok, fault_parameter()} | {:error, term()}
```

# `valid?`

```elixir
@spec valid?(fault_parameter()) :: boolean()
```

Validates whether the given fault parameter is in form valid.

It only validates the struct is valid as per type specification.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
