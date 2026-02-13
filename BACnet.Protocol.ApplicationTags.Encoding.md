# `BACnet.Protocol.ApplicationTags.Encoding`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/application_tags/encoding.ex#L1)

This module should help dealing with application tags encodings in user code, as
application tags encoding can be more easily dealt with as the values can be accessed directly.

# `create_option`

```elixir
@type create_option() ::
  {:cast_type, BACnet.Protocol.ApplicationTags.primitive_type()}
  | {:context, any()}
  | {:encoder, (any() -&gt; {:ok, any()} | {:error, any()} | any())}
```

Valid create options. For a description on each option, see `create/2`.

# `create_options`

```elixir
@type create_options() :: [create_option()]
```

List of create options.

# `t`

```elixir
@type t() :: %BACnet.Protocol.ApplicationTags.Encoding{
  encoding: :primitive | :tagged | :constructed,
  extras: Keyword.t(),
  type: BACnet.Protocol.ApplicationTags.primitive_type() | nil,
  value: term()
}
```

Represents application tags encoding with a slightly more enjoyable structure.

For tagged and constructed encodings, the extras contains `:tag_number`.
Extras may also contain `:context` and `:encoder`, if passed to `create/2`.

# `create`

```elixir
@spec create(BACnet.Protocol.ApplicationTags.encoding(), create_options()) ::
  {:ok, t()} | {:error, term()}
```

Creates a struct from the application tags encoding.

Tagged encodings can be optionally casted to primitive types.

Available options:
- `cast_type: ApplicationTags.primitive_type()` - Optional. Casts the tagged encoding to the primitive type.
- `context: any()` - Optional. A user-defined value for matching by the user, untouched by the module.
- `encoder: (any() -> {:ok, any()} | {:error, any()} | any())`- Optional. An encoder function to use on the value,
  before creating the application tags encoding.

# `create!`

```elixir
@spec create!(BACnet.Protocol.ApplicationTags.encoding(), create_options()) ::
  t() | no_return()
```

Bang version of `create/2`.

# `to_encoding`

```elixir
@spec to_encoding(t()) ::
  {:ok, BACnet.Protocol.ApplicationTags.encoding()} | {:error, term()}
```

Reverses the process and brings it back to its raw form.

# `to_encoding!`

```elixir
@spec to_encoding!(t()) :: BACnet.Protocol.ApplicationTags.encoding() | no_return()
```

Bang version of `to_encoding/1`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
