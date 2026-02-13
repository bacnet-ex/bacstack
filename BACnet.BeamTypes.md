# `BACnet.BeamTypes`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/beam_types.ex#L1)

Contains functions to resolve typespecs and types from BEAM bytecode
into a type declaration and functions to validate those types against values.

During compilation, it uses a compilation tracer (as configured in the bacstack Mix Project)
to track fresh compiled modules and stores them in persistent term for lookup later.

The types are mostly used for BACnet object type declarations, where those types are
at compile-time resolved, so compilation tracing is a huge need for development.
Modules that have not changed and are not compiled, are read from the BEAM file.

The module `BACnet.Protocol.ObjectsMacro` and `BACnet.Protocol.ObjectsUtility` use this
module to resolve and validate types accurately to the need of ASHRAE 135 BACnet specification.

# `typechecker_types`

```elixir
@type typechecker_types() ::
  nil
  | :any
  | :boolean
  | :string
  | :octet_string
  | :signed_integer
  | :unsigned_integer
  | :real
  | :double
  | :bitstring
  | {:array, typechecker_types()}
  | {:array, typechecker_types(), pos_integer()}
  | {:constant, atom()}
  | {:in_list, term()}
  | {:in_range, integer(), integer()}
  | {:list, typechecker_types()}
  | {:literal, term()}
  | {:struct, module()}
  | {:tuple, [typechecker_types()]}
  | {:type_list, [typechecker_types()]}
  | {:with_validator, typechecker_types(), (term() -&gt; boolean())}
  | {:with_validator, typechecker_types(), Macro.t()}
```

Valid type checker types. This is mostly used for BACnet object properties.

Following types are supported:
- `nil` - `nil`
- `:any` - `any()`/`term()`
- `:boolean` - `boolean()`
- `:string` - `String.t()`
- `:octet_string` - `binary()`
- `:signed_integer` - `integer()`
- `:unsigned_integer` - `non_neg_integer()`
- `:real` - `float()`, also allowing `:NaN`, `:inf`, `:infn`
- `:double` - value check same as `:real` (for `bac_object/2`, this type must be explicitely specified)
- `:bitstring` - tuple of booleans
- `{:array, subtype}` (validates a `BACnetArray` and every value of it being of `subtype`)
- `{:array, subtype, fixed_size}` (validates a `BACnetArray` with fixed size of `fixed_size` and every value of it being of `subtype`)
- `{:constant, type}` - `Constants.type()`
- `{:in_list, values}`
- `{:in_range, low, high}` - `x..y`
- `{:list, type}` - `[type()]`
- `{:literal, value_check}` (checks if `value` equals to `value_check` using the match `===/2` operator)
- `{:struct, module}` (calls the module's `valid?/1` function, if exported)
- `{:tuple, [type]}` (checks in sequence if the tuple element matches to the type in the same index)
- `{:type_list, [type]}` - `type_a()|type_b()` (checks if the value passes one of the type checks in `types` list)
- `{:with_validator, type, (term() -> boolean())}` - First checks the type and then calls the validator function.
- `{:with_validator, type, validator_function_ast}` - First checks the type and then calls the validator function,
   which is AST that gets first evaluated and then called with the value. The AST must evaluate to a single arity function.

# `check_type`

```elixir
@spec check_type(typechecker_types(), term()) :: boolean()
```

Checks the type of value and verifies more complex type it is of the same type as the given type.

# `generate_valid_clause`

```elixir
@spec generate_valid_clause(module(), Macro.Env.t()) :: Macro.t()
```

Generates `valid?/1` clause body based on the given module's `:t` typespec,
it must reference a struct.

# `resolve_struct_type`

```elixir
@spec resolve_struct_type(module(), atom(), Macro.Env.t(), Keyword.t()) :: map()
```

Resolves a type (struct) to a map of fields to typespecs (`resolve_type/2`-like).

This function only works with BACnet data structures and not with types, such as
exposed by the module `ApplicationTags`. Since `tuples` are used in that module to
structure data together, `tuples` are used in BACnet data structures as bitstrings
(as seen in `ApplicationTags` bitstrings).
As such wrong typespecs will be generated and cannot be used for validation.

For structs that do not define any fields, an empty map will be returned.

Tuple types such as `{binary(), integer()}` will be resolved to `{:tuple, [:octet_string, :integer]}`.

```elixir
iex(1)> resolve_struct_type(BACnet.Protocol.EventParameters.ChangeOfBitstring, :t, __ENV__)
%{
  alarm_values: {:list, :bitstring},
  bitmask: :bitstring,
  time_delay: :unsigned_integer,
  time_delay_normal: {:type_list, [:unsigned_integer, {:literal, nil}]}
}
```

Available options:
- `ignore_underlined_keys: boolean()` - Ignores/skips keys starting with `_`, as such the
  resolved types will exclude types for underline-prefixed keys.

# `resolve_type`

```elixir
@spec resolve_type(Macro.t(), Macro.Env.t()) :: term()
```

Resolves an AST type to something `check_type/2` works with.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
