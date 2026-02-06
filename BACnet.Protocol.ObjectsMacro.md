# `BACnet.Protocol.ObjectsMacro`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/objects_macro.ex#L1)

This is an internal module for defining BACnet objects.

If you're a library user, there's no need for you to ever deal with this module.

If you want to store the BACnet object definition AST as a persistent module
attribute (`:bacobj_ast`) in each BACnet object module, you can set the key `:store_bacobj_ast`
to `true` for the `:bacstack` application. If `:bacstack` is a dependency of your
Mix project, you will need to recompile bacstack with `mix deps.compile bacstack --force`.

The following has to be taken care of when trying decode/encode properties:
- Check the annotations for decoder/encoder functions (single argument - the plain value (no tag encoding))
- Check the annotations for `encode_as` primitive type declaration (i.e. used to declare enumerated booleans)
- Check the properties types map - 99% should be covered by this (1% is covered by annotations)
- Custom decoding/encoding by hand for special properties (not yet supported properties/objects)

# `decoder`

```elixir
@type decoder() ::
  (BACnet.Protocol.ApplicationTags.Encoding.t()
   | [BACnet.Protocol.ApplicationTags.Encoding.t()] -&gt;
     {:ok, term()} | {:error, term()} | term())
```

BACnet object property decoder function for annotation `decoder`.

Used by `BACnet.Protocol.ObjectsUtility.cast_property_to_value/4`.

`term()` as return is the same as `{:ok, term()}`.

# `encoder`

```elixir
@type encoder() ::
  (term() -&gt;
     {:ok,
      BACnet.Protocol.ApplicationTags.Encoding.t()
      | [BACnet.Protocol.ApplicationTags.Encoding.t()]
      | term()}
     | {:error, term()})
```

BACnet object property encoder function for annotation `encoder`.

Used by `BACnet.Protocol.ObjectsUtility.cast_value_to_property/4`.

# `required_only_when`

```elixir
@type required_only_when() ::
  {:property, name :: BACnet.Protocol.Constants.property_identifier()}
  | {:property, name :: BACnet.Protocol.Constants.property_identifier(),
     value :: term()}
  | {:property, name :: BACnet.Protocol.Constants.property_identifier(),
     operator :: atom(), value :: term()}
  | {:opts, name :: atom()}
  | {:opts, name :: atom(), value :: term()}
  | {:opts, name :: atom(), operator :: atom(), value :: term()}
  | (properties_so_far :: map() -&gt; boolean())
  | (properties_so_far :: map(), metadata :: map() -&gt; boolean())
```

Supported values for annotation `required_when` and `only_when`.

`operator` must be a function from the module `Kernel`.

# `__using__`
*macro* 

Inserts an `import` for the `bac_object/2` macro.

# `bac_object`
*macro* 

Defines a BACnet object.

This macro generates the struct, the necessary functions, helpers, types
and module documentation and inserts these into the AST of the module.

Use `define_bacnet_object/3` to use something that can be used outside of a module
(it produces AST for `bac_object/2`).

### Definition

To use this macro, you need to pass it the BACnet object type (`t:BACnet.Protocol.Constants.object_type/0`) and
the definition of the object in a `do` block.

The definition is built up using the following macros:
- `services/1` - Defines which services are available in keyword notation (services: `intrinsic`).
- `field/3` - Defines each field/property of the object. First the name, then the Elixir typespec,
  following options. When writing typespecs, the typespec will be resolved. It must be noted, not
  all types are supported (i.e. plain maps). The following options are available:
  - `annotation` - Can be used multiple times. Allows to add annotations to the field which can be retrieved
    using `get_annotation/1`. The return value is always a list. The given argument must be allowed to be
    escaped (such as no evaluated functions).
    The given argument should be `{:field_name, value}` or `[field_name: value]`.
    The whole annotations list is flattened, to allow keyword based access through `get_annotation/1`.
  - `bac_type` - Used to override the inherited type from the typespec,
    which is then used for property value typechecks. The value of this field is to be a valid type of
    `t:Internal.typechecker_types/0` or
    `{:with_validator, type of Internal.typechecker_types/0, validator function quote block or capture}`.
    Types given through this option will not be further validated and may lead to runtime errors when
    incorrectly used.
  - `cov` - Property is part of COV Reporting (the "main" property for reporting changes).
  - `default` - Default value for the property. This can be a constant value, function call,
    anonymous function or capture expression (arity 0!).
    Function calls, definitions and captures are executed at compile time.
  - `implicit_relationship` - Implicit relationship between two properties.
    The other property gets automatically added, if one of the relationship gets added.
  - `init_fun` - Used to initialize the property with an initial value
    (only remote function captures with arity 0 allowed). Properties with an `init_fun` get added to the object
    as if the property was required and had a default value, if it's not a remote object.
  - `intrinsic` - Property is part of Intrinsic Reporting.
  - `protected` - The property can not be changed through the functions (i.e. `object_instance` can not be mutated).
  - `readonly` - Annotation that the property should only be readonly (write protected from the BACnet side).
  - `required` - Required property, must always be present.
  - `validator_fun` - Used to verify the property value before inserting.
    This function can accept, zero, one or two arguments (the value and the object itself). During object creation,
    the function will get a plain map of the currently accumulated properties as object.

The macro will verify the structure. Fields with implicit relationships should always have a default value.
Object creation will otherwise fail.

When creating an object and a required property has no default and no value is given at creation,
object creation will fail.

If an object gets created and only one property gets specified of an implicit relationship, the other
property gets automatically added (which explains why it should have a default value).

An example definition looks like this:
```elixir
bac_object :analog_input do
  services(intrinsic: true)

  field(:description, String.t()) # Optional property
  field(:device_type, String.t()) # Optional property
  field(:out_of_service, boolean(), required: true) # Required property, has an implicit default value
  field(:present_value, boolean(), required: true, default: false) # Required property, has a default value
end
```

For convenience, the `fetch/2` function will be implemented for use with the `Access` behaviour.
All other `Access` behaviour callbacks/functions will not be implemented.

### Code Generation, Properties and Relationships

The following functions for working with objects get generated:
- `add_property/3`
- `create/4`
- `cov_reporting?/1`
- `get_object_identifier/1`
- `get_properties/1`
- `has_property?/2`
- `intrinsic_reporting?/1`
- `property_writable?/2`
- `remove_property/2`
- `update_property/3`

The `property_writable/2` function should be overridden by modules to set certain
properties writable only during certain conditions, if this is required by the object.

The following functions get generated based on the available properties (priority_array):
- `get_priority_value/1`
- `set_priority/3`

The following helper functions get generated:
- `get_all_properties/0`
- `get_cov_properties/0`
- `get_intrinsic_properties/0`
- `get_optional_properties/0`
- `get_properties_type_map/0`
- `get_protected_properties/0`
- `get_readonly_properties/0`
- `get_required_properties/0`
- `supports_intrinsic/0`

The following types get generated:
- `common_object_opts/0` (for basic BACnet object options)
- `property_name/0`
- `property_update_error/0`
- `t/0`

The following properties have an implicit default value:
- event_state (`:normal`)
- out_of_service (`false`)
- status_flags (all bits `false`)

The following implicit relationships exist and do not need to be manually defined:
- priority_array <-> relinquish_default

The following properties are implicitely protected:
- object_identifier (does not exist on the struct)
- object_type (does not exist on the struct)
- properties_list (does not exist as property on the struct - properties are tracked in metadata)

Both properties which do not exist are inherited from the module. Properties list is tracked internally
and thus protected from mutation through the functions. These properties need to be dynamically
inherited through the device server for the BACnet side to conform to the BACnet standard.

For input objects, the device server needs to implement the present value write protection for when
the object is not out of service. The object itself does not provide such a mechanism as it does
not know from where the write is happening (locally from the device or through BACnet).

The following properties are required for all objects and are automatically defined:
- object_instance (annotated as readonly)
- object_name (annotated as readonly)

For intrinsic objects, the following properties are automatically defined (with a default value):
- acked_transitions (annotated as readonly)
- event_algorithm_inhibit
- event_algorithm_inhibit_ref
- event_detection_enable
- event_enable
- event_message_texts (annotated as readonly)
- event_message_texts_config
- event_timestamps (annotated as readonly)
- limit_enable
- notify_type
- notification_class
- time_delay
- time_delay_normal

For commandable objects (objects with a priority array), the present value property is protected,
unless out of service is active. For the duration of out of service, updates to the present value
using `update_property/3` are allowed. Once out of service is disabled, the present value is once
again protected from updates, as the present value is updated through the relinquish_default and
priority_array properties.

Implementors using this macro can "inhibit" an object and verify or mutate the object,
but also return an error. For that a private function can be overridden. The function is called
whenever `create`, `add_property`, `remove_property` (excluding unknown propertes)
and `update_property` is used.

The following private function can be overriden and used a hook:

```ex
inhibit_object_check(t()) :: {:ok, t()} | {:error, term()}
```

It receives the object struct and should return an ok or error tuple.

### Annotations

Annotations can be used for multiple things. There are some that have a special meaning inside the library.

The following annotations are used currently:
- `decoder: decoder()` - Function used to decode the ASN.1 value to an Elixir value (the typespec).
- `encoder: encoder()` - Function used to encode the Elixir value (the typespec) to an ASN.1 value.
- `only_when: required_only_when()` - See below. Allows a property to "exist" only when the condition is met.
- `required_when: required_only_when()` - See below. Marks a property as required when the condition is met.

The encoder and decoder annotations are used by the `BACnet.Protocol.ObjectsUtility` module to encode and decode properties.

Annotations with the key name `required_when` and `only_when` will be respected, if their value is supported.
`required_when` can be used to conditionally require certain properties.

The following values are supported:
  - `{:property, Constants.property_identifier()}` - The given property must be present in the object.
  - `{:property, Constants.property_identifier(), value}` - The given property must be present
    in the object and have the specified value.
  - `{:property, Constants.property_identifier(), operator, value}` - The given property must be present
    in the object and have the specified value. The value is compared using the given operator from
    the `Kernel` module (must be a function in said module).
  - `{:opts, atom()}` - The given option must be present in the object options (given in `create/4`)
    and have the value `true`.
  - `{:opts, atom(), value}` - The given option must be present in the object options
    and have the specified value.
  - `{:opts, atom(), operator, value}` - The given option must be present
    in the object options and have the specified value. The value is compared using the given
    operator from the `Kernel` module (must be a function in said module).
  - `(map() -> boolean())` - Function with arity 1, receives the currently
    accumulated properties. Returning `true` means the property is required.
  - `(map(), map() -> boolean())` - Function with arity 2, receives the currently
    accumulated properties and the metadata map. Returning `true` means the property is required.

Other values than the supported values get simply ignored - there's no error or warning.

For example, to have the following field being marked as required (than by default being optional),
it requires the option `:supports_restart` to be `true`:

```elixir
field(
  :last_restart_reason,
  Constants.restart_reason(),
  annotation: [required_when: {:opts, :supports_restart}]
)
```

When instantiating the instance and the said option is given with the value `true`,
then the property is required and must either have a default value or be explicitely given.
If the property does not have a default value or is not given, the instantiation fails with an error.
If the said option is not given (or with any value other than `true`), then the property stays optional.

To have the property only present and can only be instantiated when the property is required,
to meet BACnet requirements to have some properties only present when some condition is met,
the annotation `only_when` is supported. It supports the same values as `required_when`.

That means, the optional property can not be used unless the `only_when` test passes true.
The exception being remote objects, where all optional properties can always be used,
as these our outside of our responsibility.

### Extendibility

Object types can be extended at compile time by the user to provide additional properties.
Use the application `:bacstack` and key `:objects_additional_properties` to provide a map or keyword list,
keyed by the object type as atom, with an AST of additional properties (as if you were to provide them directly).
Make sure that the used property identifiers are already defined (either by the library or at compile time by the user).

Example (`config/config.exs`):

```elixir
config :bacstack, :additional_property_identifiers, loop_enable: 523, loop_mode: 524

config :bacstack, :objects_additional_properties,
  loop:
    (quote do
      field(:loop_enable, boolean(), encode_as: :enumerated)

      field(:loop_mode, :bacnet_loop | :plc_loop,
        bac_type: {:in_list, [:bacnet_loop, :plc_loop]},
        annotation: [
          encoder: &{:enumerated, if(&1 == :plc_loop, do: 1, else: 0)},
          decoder: &if(&1.value == 1, do: :plc_loop, else: :bacnet_loop)
        ]
      )
    end)
```

# `define_bacnet_object`

```elixir
@spec define_bacnet_object(
  BACnet.Protocol.Constants.object_type(),
  Macro.t(),
  Macro.Env.t()
) ::
  Macro.t() | no_return()
```

Defines a BACnet object. This function produces AST from the given BACnet object definition.
For a description of what it does, see the `bac_object/2` macro.

# `get_default_bacnet_datetime`

```elixir
@spec get_default_bacnet_datetime() :: BACnet.Protocol.BACnetDateTime.t()
```

Get a default BACnet DateTime with every field `:unspecified`.

# `get_default_bacnet_timestamp`

```elixir
@spec get_default_bacnet_timestamp() :: BACnet.Protocol.BACnetTimestamp.t()
```

Get a default BACnet Timestamp with a `DateTime` and every field `:unspecified`.

# `get_default_dev_object_ref`

```elixir
@spec get_default_dev_object_ref() :: BACnet.Protocol.DeviceObjectPropertyRef.t()
```

Get a default BACnet Device Object Property Reference. References a BI object with the
highest instance number, referencing the highest property identifier.

The highest instance number usually represents an uninitialized property.

# `get_default_event_message_texts`

```elixir
@spec get_default_event_message_texts() :: BACnet.Protocol.EventMessageTexts.t()
```

Get a default BACnet Event Message Texts with default English strings.

# `get_default_event_transbits`

```elixir
@spec get_default_event_transbits(boolean()) ::
  BACnet.Protocol.EventTransitionBits.t()
```

Get a default BACnet Event Transition Bits with each bit set to a specific value.

# `get_default_object_ref`

```elixir
@spec get_default_object_ref() :: BACnet.Protocol.ObjectPropertyRef.t()
```

Get a default BACnet Object Property Reference. References a BI object with the
highest instance number, referencing the highest property identifier.

The highest instance number usually represents an uninitialized property
(such as in the case for `event_algorithm_inhibit_ref`).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
