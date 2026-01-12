defmodule BACnet.Protocol.ObjectsMacro do
  @moduledoc """
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
  """

  alias BACnet.BeamTypes
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.BACnetTimestamp
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.EventMessageTexts
  alias BACnet.Protocol.EventTransitionBits
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectPropertyRef
  alias BACnet.Protocol.PriorityArray

  require Constants

  # Allow to store the BACnet object definition AST using the application env
  @bacobj_store_ast Application.compile_env(:bacstack, :store_bacobj_ast, false)

  @required_struct_ast (quote do
                          field(:object_instance, non_neg_integer(),
                            required: true,
                            readonly: true
                          )

                          field(:object_name, String.t(), required: true, readonly: true)
                        end)

  @intrinsic_struct_ast (quote do
                           field(:acked_transitions, EventTransitionBits.t(),
                             intrinsic: true,
                             readonly: true
                           )

                           field(:event_algorithm_inhibit, boolean(), intrinsic: true)

                           field(
                             :event_algorithm_inhibit_ref,
                             ObjectPropertyRef.t(),
                             intrinsic: true,
                             implicit_relationship: :event_algorithm_inhibit
                           )

                           field(:event_detection_enable, boolean(), intrinsic: true)

                           field(:event_enable, EventTransitionBits.t(), intrinsic: true)

                           field(:event_message_texts, BACnet.Protocol.EventMessageTexts.t(),
                             intrinsic: true,
                             readonly: true
                           )

                           field(
                             :event_message_texts_config,
                             BACnet.Protocol.EventMessageTexts.t(),
                             intrinsic: true
                           )

                           field(:event_timestamps, BACnet.Protocol.EventTimestamps.t(),
                             intrinsic: true,
                             readonly: true
                           )

                           field(:limit_enable, BACnet.Protocol.LimitEnable.t(), intrinsic: true)

                           field(:notify_type, Constants.notify_type(), intrinsic: true)
                           field(:notification_class, non_neg_integer(), intrinsic: true)
                           field(:time_delay, non_neg_integer(), intrinsic: true)
                           field(:time_delay_normal, non_neg_integer(), intrinsic: true)
                         end)

  @basic_properties_to_type_map %{
    object_name: :string,
    description: :string,
    event_state: {:constant, :event_state},
    status_flags: {:struct, BACnet.Protocol.StatusFlags},
    out_of_service: :boolean,
    priority_array: {:struct, PriorityArray},
    profile_name: :string,
    reliability: {:constant, :reliability},
    reliability_evaluation_inhibit: :boolean,
    update_interval: :unsigned_integer,
    units: {:constant, :engineering_unit},

    # Intrinsic Reporting (implicitely nil if object not intrinsic)
    acked_transitions: {:struct, BACnet.Protocol.EventTransitionBits},
    event_algorithm_inhibit: :boolean,
    event_algorithm_inhibit_ref: {:struct, ObjectPropertyRef},
    event_detection_enable: :boolean,
    event_enable: {:struct, BACnet.Protocol.EventTransitionBits},
    event_timestamps: {:struct, BACnet.Protocol.EventTimestamps},
    event_message_texts: {:struct, BACnet.Protocol.EventMessageTexts},
    event_message_texts_config: {:struct, BACnet.Protocol.EventMessageTexts},
    limit_enable: {:struct, BACnet.Protocol.LimitEnable},
    notification_class: :unsigned_integer,
    notify_type: {:constant, :notify_type},
    time_delay: :unsigned_integer,
    time_delay_normal: :unsigned_integer
  }

  @protected_properties [
    # Internal keys
    :_metadata,
    :_writable_properties,
    :_unknown_properties,

    # General properties
    :object_identifier,
    # :object_instance,
    :object_type

    # Intrinsic Reporting
    # :event_message_texts
  ]

  #### Helpers START ####

  @default_bacnet_timestamp %BACnetTimestamp{
    type: :datetime,
    time: nil,
    sequence_number: nil,
    datetime: %BACnetDateTime{
      date: %BACnetDate{
        year: :unspecified,
        month: :unspecified,
        day: :unspecified,
        weekday: :unspecified
      },
      time: %BACnetTime{
        hour: :unspecified,
        minute: :unspecified,
        second: :unspecified,
        hundredth: :unspecified
      }
    }
  }

  @typedoc """
  BACnet object property decoder function for annotation `decoder`.

  Used by `BACnet.Protocol.ObjectsUtility.cast_property_to_value/4`.

  `term()` as return is the same as `{:ok, term()}`.
  """
  @type decoder :: (Encoding.t() | [Encoding.t()] -> {:ok, term()} | {:error, term()} | term())

  @typedoc """
  BACnet object property encoder function for annotation `encoder`.

  Used by `BACnet.Protocol.ObjectsUtility.cast_value_to_property/4`.
  """
  @type encoder :: (term() -> {:ok, Encoding.t() | [Encoding.t()] | term()} | {:error, term()})

  @typedoc """
  Supported values for annotation `required_when` and `only_when`.

  `operator` must be a function from the module `Kernel`.
  """
  @type required_only_when ::
          {:property, name :: Constants.property_identifier()}
          | {:property, name :: Constants.property_identifier(), value :: term()}
          | {:property, name :: Constants.property_identifier(), operator :: atom(),
             value :: term()}
          | {:opts, name :: atom()}
          | {:opts, name :: atom(), value :: term()}
          | {:opts, name :: atom(), operator :: atom(), value :: term()}
          | (properties_so_far :: map() -> boolean())
          | (properties_so_far :: map(), metadata :: map() -> boolean())

  @doc """
  Get a default BACnet DateTime with every field `:unspecified`.
  """
  @spec get_default_bacnet_datetime() :: BACnetDateTime.t()
  def get_default_bacnet_datetime() do
    %BACnetDateTime{
      date: %BACnetDate{
        year: :unspecified,
        month: :unspecified,
        day: :unspecified,
        weekday: :unspecified
      },
      time: %BACnetTime{
        hour: :unspecified,
        minute: :unspecified,
        second: :unspecified,
        hundredth: :unspecified
      }
    }
  end

  @doc """
  Get a default BACnet Timestamp with a `DateTime` and every field `:unspecified`.
  """
  @spec get_default_bacnet_timestamp() :: BACnetTimestamp.t()
  def get_default_bacnet_timestamp() do
    @default_bacnet_timestamp
  end

  @doc """
  Get a default BACnet Event Message Texts with default English strings.
  """
  @spec get_default_event_message_texts() :: EventMessageTexts.t()
  def get_default_event_message_texts() do
    %EventMessageTexts{
      to_offnormal: "To-OffNormal",
      to_fault: "To-Fault",
      to_normal: "To-Normal"
    }
  end

  @doc """
  Get a default BACnet Event Transition Bits with each bit set to a specific value.
  """
  @spec get_default_event_transbits(boolean()) :: EventTransitionBits.t()
  def get_default_event_transbits(default_value \\ true) do
    %EventTransitionBits{
      to_offnormal: default_value,
      to_fault: default_value,
      to_normal: default_value
    }
  end

  @doc """
  Get a default BACnet Device Object Property Reference. References a BI object with the
  highest instance number, referencing the highest property identifier.

  The highest instance number usually represents an uninitialized property.
  """
  @spec get_default_dev_object_ref() :: DeviceObjectPropertyRef.t()
  def get_default_dev_object_ref() do
    %DeviceObjectPropertyRef{
      object_identifier: %ObjectIdentifier{
        type: Constants.macro_assert_name(:object_type, :binary_input),
        instance: Constants.macro_by_name(:asn1, :max_instance_and_property_id)
      },
      property_identifier: Constants.macro_by_name(:asn1, :max_instance_and_property_id),
      property_array_index: nil,
      device_identifier: nil
    }
  end

  @doc """
  Get a default BACnet Object Property Reference. References a BI object with the
  highest instance number, referencing the highest property identifier.

  The highest instance number usually represents an uninitialized property
  (such as in the case for `event_algorithm_inhibit_ref`).
  """
  @spec get_default_object_ref() :: ObjectPropertyRef.t()
  def get_default_object_ref() do
    %ObjectPropertyRef{
      object_identifier: %ObjectIdentifier{
        type: Constants.macro_assert_name(:object_type, :binary_input),
        instance: Constants.macro_by_name(:asn1, :max_instance_and_property_id)
      },
      property_identifier: Constants.macro_by_name(:asn1, :max_instance_and_property_id),
      property_array_index: nil
    }
  end

  #### Helpers END ####

  @doc """
  Inserts an `import` for the `bac_object/2` macro.
  """
  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__), only: [bac_object: 2]
      require BACnet.Protocol.Constants
    end
  end

  @doc """
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
  """
  defmacro bac_object(object_type, definition)

  defmacro bac_object(object_type, do: ast) do
    object_type = Macro.expand(object_type, __CALLER__)
    define_bacnet_object(object_type, ast, __CALLER__)
  end

  # credo:disable-for-lines:100 Credo.Check.Refactor.CyclomaticComplexity
  @doc """
  Defines a BACnet object. This function produces AST from the given BACnet object definition.
  For a description of what it does, see the `bac_object/2` macro.
  """
  @spec define_bacnet_object(Constants.object_type(), Macro.t(), Macro.Env.t()) ::
          Macro.t() | no_return()
  def define_bacnet_object(object_type, ast, %Macro.Env{} = env) when is_atom(object_type) do
    unless Constants.has_by_name(:object_type, object_type) do
      raise ArgumentError, "Invalid object type, got: #{inspect(object_type)}"
    end

    default_revision =
      Constants.by_name!(:protocol_revision, Constants.by_name!(:protocol_revision, :default))

    additional_fields =
      :bacstack
      |> Application.get_env(:objects_additional_properties)
      |> Access.get(object_type, [])
      |> case do
        {:__block__, _meta, fields} -> fields
        [] -> []
        field -> [field]
      end

    fields_ast =
      case ast do
        {:__block__, _meta, fields} -> fields ++ additional_fields
        field -> [field | additional_fields]
      end

    req_struct_ast =
      case @required_struct_ast do
        {:__block__, _meta, fields} -> fields
      end

    intrins_struct_ast =
      case @intrinsic_struct_ast do
        {:__block__, _meta, fields} -> fields
      end

    # Traverse the AST for the first time to find the supported services
    supported_services =
      fields_ast
      |> Enum.find_value(%{}, fn ast ->
        case ast do
          {:services, _line, _ast} -> get_services_data(ast, env)
          _else -> nil
        end
      end)
      |> then(&Map.merge(%{intrinsic: false}, &1))

    # Only add the intrinsic fields, if the object supports intrinsic reporting
    intrins_fields_ast =
      if supported_services.intrinsic do
        intrins_struct_ast
      else
        []
      end

    fields_ast = req_struct_ast ++ intrins_fields_ast ++ fields_ast

    fields_data =
      fields_ast
      |> Enum.reduce([], fn ast, acc ->
        case ast do
          {:field, _line, _ast} -> [get_field_data(ast, env) | acc]
          _else -> acc
        end
      end)
      |> Enum.uniq_by(fn %{name: name} -> name end)

    struct_fields =
      for %{name: name} <- fields_data do
        name
      end

    # Create the t() typespecs
    struct_typespecs =
      Enum.map(
        [
          %{name: :_metadata, required: true, typespec: quote(do: internal_metadata())},
          %{
            name: :_unknown_properties,
            required: true,
            typespec:
              quote(
                do: %{
                  optional(atom() | non_neg_integer()) =>
                    term()
                    | BACnet.Protocol.ApplicationTags.Encoding.t()
                    | [BACnet.Protocol.ApplicationTags.Encoding.t()]
                }
              )
          }
          | fields_data
        ],
        fn
          %{name: name, typespec: typespec, required: true} ->
            {name, typespec}

          %{name: name, typespec: typespec} ->
            {
              name,
              {:|, [], [typespec, nil]}
            }
        end
      )

    # Create the list for defstruct
    struct_deffields =
      for %{name: name} <- fields_data do
        name
      end

    # Remove all fields with leading underscore (or fields with a default value)
    cleaned_fields =
      Enum.reject(struct_fields, &(is_tuple(&1) or String.starts_with?(Atom.to_string(&1), "_")))

    # Create typespec for the type property_name
    fields =
      cleaned_fields
      |> Enum.sort(:desc)
      |> Enum.reduce(fn field, acc ->
        {:|, [], [field, acc]}
      end)

    # Generate Elixir type for the Present Value property
    {pv_ex_type, pv_typespec} =
      if :present_value in struct_deffields do
        # We do not need to check whether the return value is not nil,
        # because we are bound to have the data since the field is present
        Enum.find_value(fields_data, nil, fn
          %{name: :present_value, bac_type: bac_type, typespec: typespec} ->
            {bac_type, typespec}

          _term ->
            nil
        end)
      else
        {nil, {:term, [], []}}
      end

    # Create map of property_name to their type
    properties_type_map =
      @basic_properties_to_type_map
      |> Map.merge(Map.new(fields_data, fn %{name: name, bac_type: type} -> {name, type} end))
      |> Enum.reject(&String.starts_with?(Atom.to_string(elem(&1, 0)), "_"))
      |> Map.new()

    # Compile a few information for use in the quote block
    protected_properties =
      @protected_properties ++
        for field <- fields_data, field.protected do
          field.name
        end

    required_properties =
      for field <- fields_data, field.required do
        field.name
      end

    # Map of property_name to revision (required properties)
    properties_revision_map =
      Map.new(
        for field <- fields_data, field.required do
          {field.name, field.annotations[:revision] || default_revision}
        end
      )

    readonly_properties =
      for field <- fields_data, field.readonly do
        field.name
      end

    intrinsic_properties =
      fields_data
      |> Enum.filter(& &1.intrinsic)
      |> Enum.map(& &1.name)

    cov_properties =
      fields_data
      |> Enum.filter(& &1.cov)
      |> Enum.map(& &1.name)

    implicit_relationships =
      Map.new(
        get_default_implicit_relationships() ++
          (fields_data
           |> Enum.reject(&(&1.implicit_relationship == nil))
           |> Enum.map(&{&1.name, &1.implicit_relationship}))
      )

    # Default values for required properties (only fields with default value)
    default_properties =
      get_default_required_properties() ++
        (fields_data
         |> Enum.filter(&(&1.required and &1.default != nil))
         |> Enum.map(&{&1.name, &1.default}))

    # Now add those optional properties that are required for this object type
    default_properties =
      Enum.reduce(get_default_optional_properties(), default_properties, fn {name, value}, acc ->
        if name in required_properties and not Keyword.has_key?(acc, name) do
          [{name, value} | acc]
        else
          acc
        end
      end)

    # Assert now the default_properties does not have any fields with default value == nil
    Enum.each(default_properties, fn
      {key, nil} -> raise "Invalid default value for struct key \"#{key}\": Value is nil"
      {_key, _value} -> :ok
    end)

    default_properties_all =
      Map.new(
        Enum.reject(
          default_properties ++
            get_default_optional_properties() ++
            (fields_data
             |> Enum.filter(&(not &1.intrinsic and &1.default != nil))
             |> Enum.map(&{&1.name, &1.default})),
          fn {key, value} -> key not in struct_deffields or is_nil(value) end
        )
      )

    default_intrinsic_properties =
      get_default_intrinsic_properties() ++
        (fields_data
         |> Enum.filter(&(&1.intrinsic and &1.default != nil))
         |> Enum.map(&{&1.name, &1.default}))

    default_cov_increment =
      Enum.find_value(fields_data, nil, fn
        %{name: :cov_increment, default: value} -> value
        _term -> nil
      end)

    supports_intrinsic = supported_services.intrinsic

    call_intrinsic_on_object_check =
      if supports_intrinsic do
        quote do
          intrinsic_reporting?(object)
        end
      else
        quote do
          false
        end
      end

    properties_validators =
      Enum.map(fields_data, fn %{name: name, type_validator: fun, validator_fun: val} ->
        {name, {fun, val}}
      end)

    init_fun_map =
      fields_data
      |> Map.new(fn
        %{init_fun: nil} -> {:__drop__, nil}
        %{name: name, init_fun: val} -> {name, val}
      end)
      |> Map.delete(:__drop__)

    annotations =
      Enum.map(fields_data, fn %{name: name, annotations: anno} ->
        {name, anno}
      end)

    moduledoc = generate_moduledoc(object_type, fields_data)

    # credo:disable-for-lines:100 Credo.Check.Refactor.LongQuoteBlocks
    quote generated: true, location: :keep do
      @moduledoc (case @moduledoc do
                    nil -> unquote(moduledoc)
                    false -> false
                    doc -> doc <> "\n\n" <> unquote(moduledoc)
                  end)

      @type t :: %__MODULE__{unquote_splicing(struct_typespecs)}
      defstruct unquote(struct_deffields) ++
                  [
                    _metadata: %{
                      properties_list: [],
                      revision: Constants.macro_by_name(:protocol_revision, :default),
                      intrinsic_reporting: false,
                      remote_object: nil,
                      physical_input: nil,
                      other: %{}
                    },
                    _unknown_properties: %{}
                  ]

      @supported_services unquote(Macro.escape(supported_services))

      Module.register_attribute(__MODULE__, :bacnet_object, persist: true)
      Module.put_attribute(__MODULE__, :bacnet_object, unquote(object_type))

      unquote(
        if @bacobj_store_ast do
          quote do
            Module.register_attribute(__MODULE__, :bacobj_ast, persist: true)
            Module.put_attribute(__MODULE__, :bacobj_ast, unquote(Macro.escape(ast)))
          end
        end
      )

      alias BACnet.Protocol.Constants
      require Constants

      # Implement Access Behaviour function fetch/2 for convenience
      @doc false
      defdelegate fetch(object, key), to: Map

      # unquote(pv_mapper_ast)

      defguardp is_remote(object) when object._metadata.remote_object != nil

      defmacrop get_full_property_type_map() do
        full = unquote(Macro.escape(properties_type_map))

        quote do
          unquote(Macro.escape(full))
        end
      end

      #### Public API START ####

      @doc """
      Auto generated function to get the annotations for the given property name.
      """
      @spec get_annotation(property_name()) :: [term()]
      def get_annotation(name) when is_atom(name) do
        Keyword.get(unquote(annotations), name, [])
      end

      @doc """
      Auto generated function to get the list of annotations for each property.
      """
      @spec get_annotations() :: [{name :: property_name(), values :: [term()]}]
      def get_annotations() do
        unquote(annotations)
      end

      if unquote(supports_intrinsic) do
        @doc """
        Checks if the given object has Intrinsic Reporting enabled.
        """
        @spec intrinsic_reporting?(t()) :: boolean()
        def intrinsic_reporting?(%__MODULE__{} = object) do
          object._metadata.intrinsic_reporting
        end
      end

      @doc """
      Get the BACnet object identifier.
      """
      @spec get_object_identifier(t()) :: BACnet.Protocol.ObjectIdentifier.t()
      def get_object_identifier(%__MODULE__{} = object) do
        %BACnet.Protocol.ObjectIdentifier{
          type: unquote(object_type),
          instance: object.object_instance
        }
      end

      @doc """
      Get the list of properties the object has.
      """
      @spec get_properties(t()) :: [Constants.property_identifier()]
      def get_properties(%__MODULE__{} = object) do
        object._metadata.properties_list
      end

      @doc """
      Checks if the given object has the given property.

      See `BACnet.Protocol.ObjectsUtility.has_property?/2` for implementation details.
      """
      @spec has_property?(t(), Constants.property_identifier()) :: boolean()
      def has_property?(%__MODULE__{} = object, property) when is_atom(property) do
        case check_property_exists(object, property) do
          :ok -> true
          _term -> false
        end
      end

      @doc """
      Checks if the given property is writable.

      Check `BACnet.Protocol.ObjectsUtility.property_writable?/2` for a basic run-down.
      """
      @spec property_writable?(t(), Constants.property_identifier()) :: boolean()
      def property_writable?(%__MODULE__{} = object, property) when is_atom(property) do
        BACnet.Protocol.ObjectsUtility.property_writable?(object, property)
      end

      @doc """
      Creates a new object struct with the defined properties. Optional properties are not
      created when not given, only required, given and dependency properties are created.
      Properties with a value of `nil` are ignored.

      Only properties that are required for specific services (i.e. Intrinsic Reporting)
      are automatically created.#{if unquote(default_cov_increment) != nil do
        """


        By default,  a default `cov_increment` of `#{unquote(default_cov_increment)}` is used.
        It is strongly advised to change this to something reasonable for the application.
        """
      else
        ""
      end}
      """
      @spec create(
              non_neg_integer(),
              String.t(),
              %{optional(property_name() | atom() | non_neg_integer()) => term()},
              [
                object_opts() | internal_metadata()
              ]
            ) :: {:ok, t()} | property_update_error()
      def create(instance_number, object_name, properties \\ %{}, opts \\ [])
          when is_integer(instance_number) and
                 is_binary(object_name) and
                 is_map(properties) and
                 instance_number >= 0 and
                 instance_number < Constants.macro_by_name(:asn1, :max_instance_and_property_id) do
        with :ok <- check_printable_object_name(object_name),
             {:ok, {props, unknown_props, needs_recheck}} <-
               Enum.reduce_while(
                 properties,
                 {:ok, {%{}, %{}, false}},
                 &process_properties_from_create(&1, &2, opts)
               ),
             metadata = create_metadata_from_opts(opts),
             props when is_map(props) <- add_defaults(props, metadata),
             props = Map.put(props, :object_name, object_name),
             props = Map.put(props, :object_instance, instance_number),
             new_metadata = %{metadata | properties_list: Map.keys(props)},
             props = Map.put(props, :_metadata, new_metadata),
             props = Map.put(props, :_unknown_properties, unknown_props),
             {:ok, obj} <- check_implicit_relationships(struct(__MODULE__, props), :add),
             # For objects with a priority_array, re-calculate the present value
             obj =
               (if match?(%{priority_array: %PriorityArray{}}, obj) do
                  pv =
                    case PriorityArray.get_value(obj.priority_array) do
                      nil -> obj.relinquish_default
                      {_prio, value} -> value
                    end

                  %{obj | present_value: pv}
                else
                  obj
                end),
             # For now we'll always do the recheck, because property validators may be false negative
             # due to how only partially the properties are present at check
             :ok <-
               (if needs_recheck or true do
                  # A recheck my be needed if a property depends on another but
                  # the other property has not been added yet to the accumulator map
                  # due to how map key ordering works, so we will run the property
                  # value check afterwards again, if the property-specific validation
                  # failed in the accumulator run (Enum.reduce_while/3)
                  Enum.reduce_while(props, :ok, fn
                    {:_metadata, _value}, _acc ->
                      {:cont, :ok}

                    {:_unknown_properties, _value}, _acc ->
                      {:cont, :ok}

                    # Do not check present_value if relinquish_default present (and set)
                    {:present_value, _value}, _acc
                    when :erlang.is_map_key(:relinquish_default, props) and
                           :erlang.map_get(:relinquish_default, props) != nil ->
                      {:cont, :ok}

                    {property, value}, _acc ->
                      # Protected properties do not need to be checked anymore,
                      # because the property may have been updated from the module code
                      # which would cause this error too -
                      # however if the user would've tried to set a protected property,
                      # this would've been caught error, so it's safe to not check
                      case check_property_value(props, property, value, false) do
                        :ok -> {:cont, :ok}
                        term -> {:halt, term}
                      end
                  end)
                else
                  :ok
                end),
             {:ok, obj} <- verify_properties(obj, new_metadata) do
          inhibit_object_check(obj)
        else
          {:ok, _val} = val ->
            raise "Invalid return value from add_defaults/2, we got an ok-tuple"

          term ->
            term
        end
      end

      @doc """
      Adds an optional property to an object.
      Remote objects can not be mutated using this operation.

      Please note that properties of services can **not** be dynamically added and instead
      the object must be newly created using `create/4`.
      """
      @spec add_property(t(), Constants.property_identifier(), term()) ::
              {:ok, t()} | property_update_error()
      def add_property(object, property, value)

      def add_property(%__MODULE__{} = object, _property, _value) when is_remote(object) do
        {:error, :operation_not_available_for_remote_objects}
      end

      def add_property(%__MODULE__{} = object, property, value) when is_atom(property) do
        with :ok <-
               (if property in unquote(cleaned_fields) do
                  :ok
                else
                  {:error, {:unknown_property, property}}
                end),
             :ok <-
               (case check_property_exists(object, property) do
                  :ok -> {:error, {:property_already_exists, property}}
                  _term -> :ok
                end),
             :ok <-
               (if property in unquote(intrinsic_properties) do
                  {:error, {:intrinsic_property_not_allowed, property}}
                else
                  :ok
                end),
             :ok <- check_property_value(object, property, value, true) do
          new_object = %{
            object
            | _metadata: %{
                object._metadata
                | properties_list: [property | object._metadata.properties_list]
              }
          }

          new_object_result =
            new_object
            |> Map.put(property, value)
            |> check_implicit_relationships(:add)

          # If has priority_array and out_of_service is false,
          # update the present_value with the correct value
          # (priority_array may have been added (implicitely) and we need to sync the present_value)
          unquote(
            if :priority_array in struct_deffields do
              quote do
                new_object_result =
                  case new_object_result do
                    {:ok, new_object} ->
                      new_object2 =
                        if Map.get(new_object, :out_of_service) do
                          new_object
                        else
                          case new_object do
                            # The guard is needed so Dialyzer doesn't complain about unreachable patterns
                            %{priority_array: %PriorityArray{} = pa, relinquish_default: default}
                            when not is_nil(default) ->
                              present_value =
                                case PriorityArray.get_value(pa) do
                                  {_prio, value} -> value
                                  nil -> default
                                end

                              %{new_object | present_value: present_value}

                            _term ->
                              new_object
                          end
                        end

                      {:ok, new_object2}

                    other ->
                      other
                  end
              end
            end
          )

          case new_object_result do
            {:ok, obj} -> inhibit_object_check(obj)
            other -> other
          end
        end
      end

      @doc """
      Get a property's value from an object.
      """
      @spec get_property(t(), Constants.property_identifier() | non_neg_integer()) ::
              {:ok, term()} | property_update_error()
      def get_property(%__MODULE__{} = object, property) when is_atom(property) do
        with :ok <- check_property_exists(object, property),
             {:ok, value} <- Map.fetch(object, property) do
          {:ok, value}
        else
          :error ->
            {:error, {:unknown_property_identifier, property}}

          # Allow to read unknown properties with atoms as key
          {:error, {:unknown_property_identifier, _prop}} = err ->
            case Map.fetch(object._unknown_properties, property) do
              {:ok, _val} = val -> val
              :error -> err
            end

          term ->
            term
        end
      end

      def get_property(%__MODULE__{} = object, property)
          when is_integer(property) and property >= 0 do
        case Map.fetch(object._unknown_properties, property) do
          {:ok, _val} = val -> val
          :error -> {:error, {:unknown_property_identifier, property}}
        end
      end

      @doc """
      Removes an optional property from an object. This function is idempotent.
      Remote objects can not be mutated using this operation.

      Please note that properties of services can **not** be dynamically removed and instead
      the object must be newly created using `create/4`. Required properties can not be removed.
      """
      @spec remove_property(t(), Constants.property_identifier() | non_neg_integer()) ::
              {:ok, t()} | property_update_error()
      def remove_property(object, property)

      def remove_property(%__MODULE__{} = object, property) when is_remote(object) do
        {:error, :operation_not_available_for_remote_objects}
      end

      def remove_property(%__MODULE__{} = object, property) when is_atom(property) do
        with :ok <- check_property_exists(object, property),
             :ok <- check_property_allowed_remove(object, property) do
          new_object = %{
            object
            | _metadata: %{
                object._metadata
                | properties_list: List.delete(object._metadata.properties_list, property)
              }
          }

          new_object
          |> Map.put(property, nil)
          |> check_implicit_relationships(:remove)
          |> case do
            {:ok, obj} -> inhibit_object_check(obj)
            other -> other
          end
        else
          {:error, {:unknown_property, _property}} -> {:ok, object}
          term -> term
        end
      end

      def remove_property(%__MODULE__{} = object, property)
          when is_integer(property) and property >= 0 do
        {:ok, %{object | _unknown_properties: Map.delete(object._unknown_properties, property)}}
      end

      @doc """
      Updates a property of an object.#{if :priority_array in unquote(struct_deffields) do
        " To update the priority array, use `set_priority/3` instead."
      end}
      """
      @spec update_property(t(), Constants.property_identifier(), term()) ::
              {:ok, t()} | property_update_error()
      def update_property(%__MODULE__{} = object, property, value) when is_atom(property) do
        with :ok <- check_property_exists(object, property),
             :ok <- prevent_commandable_objects_write_pv(object, property),
             :ok <-
               (if object._metadata.remote_object do
                  # Do not check if remote object
                  :ok
                else
                  check_property_intrinsic(
                    unquote(call_intrinsic_on_object_check),
                    property,
                    value,
                    false
                  )
                end),
             :ok <- check_property_value(object, property, value, true) do
          new_object = Map.put(object, property, value)

          # If has priority_array and out_of_service is false,
          # update the present_value with the correct value
          # (priority_array may have been added (implicitely) and we need to sync the present_value)
          unquote(
            if :priority_array in struct_deffields do
              quote do
                new_object =
                  if Map.get(new_object, :out_of_service) do
                    new_object
                  else
                    case new_object do
                      # The guard is needed so Dialyzer doesn't complain about unreachable patterns
                      %{priority_array: %PriorityArray{} = pa, relinquish_default: default}
                      when not is_nil(default) ->
                        present_value =
                          case PriorityArray.get_value(pa) do
                            {_prio, value} -> value
                            nil -> default
                          end

                        %{new_object | present_value: present_value}

                      _term ->
                        new_object
                    end
                  end
              end
            end
          )

          # Update the feedback_value property with the present value
          unquote(
            if :feedback_value in struct_fields do
              quote do
                new_object =
                  if object._metadata.other[:auto_write_feedback] do
                    %{new_object | feedback_value: new_object.present_value}
                  else
                    new_object
                  end
              end
            end
          )

          inhibit_object_check(new_object)
        end
      end

      if unquote(pv_ex_type) != nil and :priority_array in unquote(struct_deffields) and
           :priority_array not in unquote(required_properties) do
        @doc """
        Checks whether the given object has a priority array.
        """
        @spec has_priority_array?(t()) :: boolean()
        def has_priority_array?(%__MODULE__{priority_array: %PriorityArray{} = _pa} = _object),
          do: true

        def has_priority_array?(%__MODULE__{} = _object), do: false
      end

      # Ignore properties with nil values
      @spec process_properties_from_create(
              {property_name(), term()},
              {:ok, {map(), map(), boolean()}},
              Keyword.t()
            ) :: {:ok, {map(), map(), boolean()}} | {:halt, {:error, term()}}
      defp process_properties_from_create({_prop, nil}, acc, _opts), do: {:cont, acc}

      defp process_properties_from_create({prop, val}, {:ok, {acc, unknown_acc, flag}}, opts) do
        allow_unknown = Keyword.get(opts, :allow_unknown_properties, false)
        skip_unknown = Keyword.get(opts, :ignore_unknown_properties, false)
        is_remote_object = !!opts[:remote_object]

        with :ok <-
               check_property_exists(
                 %{_metadata: %{properties_list: unquote(cleaned_fields)}},
                 prop
               ),
             # If property fails property validation, we shall pass it for now,
             # but we need to recheck after all properties have been added
             # This is caused by random map keys ordering introduced with OTP 26
             # but may aswell have been needed to not depend on key ordering...
             {:ok, needs_recheck} <-
               (case check_property_value(acc, prop, val, true) do
                  :ok -> {:ok, false}
                  {:error, {:value_failed_property_validation, _property}} -> {:ok, true}
                  term -> term
                end),
             :ok <-
               (if is_remote_object do
                  # Do not check if remote object
                  :ok
                else
                  check_property_intrinsic(
                    Keyword.get(opts, :intrinsic_reporting, false),
                    prop,
                    val,
                    false
                  )
                end) do
          {:cont, {:ok, {Map.put(acc, prop, val), unknown_acc, flag or needs_recheck}}}
        else
          {:error, {:unknown_property, prop}}
          when allow_unknown and
                 ((is_remote_object and is_atom(prop)) or (is_integer(prop) and prop >= 0)) ->
            {:cont, {:ok, {acc, Map.put(unknown_acc, prop, val), flag}}}

          {:error, {:unknown_property, _prop}} when skip_unknown ->
            {:cont, {:ok, {acc, unknown_acc, flag}}}

          {:error, _err} = err ->
            {:halt, err}
        end
      end

      defp add_defaults(properties, metadata) do
        props = Map.merge(unquote(Macro.escape(Map.new(default_properties))), properties)

        # If min and max present, make sure to set relinquish_default if not set
        unquote(
          if Enum.all?(
               [:relinquish_default, :min_present_value, :max_present_value],
               &(&1 in struct_deffields)
             ) do
            quote do
              props =
                if Map.get(props, :priority_array) && Map.get(props, :min_present_value) &&
                     Map.get(props, :max_present_value) do
                  Map.put_new_lazy(props, :relinquish_default, fn ->
                    Map.get(props, :min_present_value)
                  end)
                else
                  props
                end
            end
          end
        )

        # Insert cov_increment property if not remote object
        props =
          if unquote(default_cov_increment) != nil and metadata.remote_object == nil do
            Map.put_new(props, :cov_increment, unquote(default_cov_increment))
          else
            props
          end

        # Insert intrinsic properties if intrinsic reporting enabled
        props =
          if unquote(supports_intrinsic) and metadata.intrinsic_reporting and
               metadata.remote_object == nil do
            Map.merge(unquote(Macro.escape(Map.new(default_intrinsic_properties))), props)
          else
            props
          end

        # Insert properties which have an init_fun function for local objects
        # Properties with init_fun get automatically added (as if required properties)
        props =
          if metadata.remote_object do
            props
          else
            Enum.reduce(unquote(Macro.escape(init_fun_map)), props, fn
              {name, init_fun}, acc -> Map.put_new_lazy(acc, name, init_fun)
            end)
          end

        props
      end

      # Check implicit relationships, modify the object (add or remove), return new one
      # This is a default implementation
      @spec check_implicit_relationships(t(), :add | :remove) ::
              {:ok, t()} | property_update_error()
      defp check_implicit_relationships(%__MODULE__{} = object, operation)
           when operation in [:add, :remove] do
        relationships = unquote(Macro.escape(implicit_relationships))

        Enum.reduce_while(relationships, {:ok, object}, fn {prop, relat}, {:ok, acc} ->
          has_key1 = Enum.member?(object._metadata.properties_list, prop)
          has_key2 = Enum.member?(object._metadata.properties_list, relat)

          if has_key1 != has_key2 do
            {del_key, new_key} =
              cond do
                has_key1 -> {prop, relat}
                has_key2 -> {relat, prop}
              end

            if operation == :add do
              # Only add the key if the key exists in the struct
              if new_key in unquote(struct_deffields) do
                case Map.fetch(unquote(Macro.escape(default_properties_all)), new_key) do
                  {:ok, new_value} ->
                    acc
                    |> Map.put(
                      new_key,
                      new_value
                    )
                    |> then(
                      &update_in(&1, [Access.key(:_metadata), :properties_list], fn list ->
                        [new_key | list]
                      end)
                    )
                    |> then(&{:cont, {:ok, &1}})

                  :error ->
                    {:halt, {:error, {:missing_optional_property, new_key}}}
                end
              else
                {:cont, {:ok, acc}}
              end
            else
              acc
              |> Map.delete(del_key)
              |> then(
                &update_in(&1, [Access.key(:_metadata), :properties_list], fn list ->
                  List.delete(list, del_key)
                end)
              )
              |> then(&{:cont, {:ok, &1}})
            end
          else
            {:cont, {:ok, acc}}
          end
        end)
      end

      @spec check_property_allowed_remove(t(), Constants.property_identifier()) ::
              :ok | property_update_error()
      defp check_property_allowed_remove(object, property) do
        if property in unquote(required_properties) or
             property in unquote(intrinsic_properties) or
             property in unquote(cov_properties) or
             check_if_property_optionally_required(object, object._metadata, property) do
          {:error, {:property_not_allowed, property}}
        else
          :ok
        end
      end

      @spec get_default_properties() :: map()
      defp get_default_properties(), do: unquote(Macro.escape(default_properties_all))

      @spec verify_properties(map(), internal_metadata()) ::
              {:ok, map()} | property_update_error()
      defp verify_properties(properties, metadata) do
        # First, verify if all required properties as per object spec are present
        # and verify their revision status (require newer properties if revision reached)
        with :ok <-
               Enum.reduce_while(unquote(required_properties), :ok, fn req_prop, _acc ->
                 rev_status = Map.get(unquote(Macro.escape(properties_revision_map)), req_prop)

                 cond do
                   Map.has_key?(properties, req_prop) -> {:cont, :ok}
                   is_integer(rev_status) and metadata.revision < rev_status -> {:cont, :ok}
                   true -> {:halt, {:error, {:missing_required_property, req_prop}}}
                 end
               end),
             # Second, look through annotations and support `required_when: ...` annotations
             # If the function returns true, the property is (optionally) required,
             # thus we need to check if it is present or if it has a default value
             # If neither is the case and the property is required, error out
             {:ok, properties} <- verify_properties_with_required_when(properties, metadata) do
          # Third, look through annotations and support `only_when: ...` annotations
          # If the function returns true, the property is (optionally) required,
          # thus we need to check if it is present or if it has a default value,
          # if neither is the case and the property is required, error out
          # If the function returns false, the property MUST NOT be present,
          # thus we need to check if it is present and error out if so.
          verify_properties_with_only_when(properties, metadata)
        end
      end

      @spec check_if_property_optionally_required(
              map(),
              map(),
              Constants.property_identifier()
            ) :: boolean()
      defp check_if_property_optionally_required(properties, metadata, property) do
        annotation = get_annotation(property)

        if is_list(annotation) do
          case Keyword.fetch(annotation, :required_when) do
            {:ok, value} ->
              verify_properties_required_when(properties, metadata, value)

            :error ->
              false
          end
        else
          false
        end
      end

      @spec verify_properties_required_when(map(), map(), term()) :: boolean()
      defp verify_properties_required_when(properties, metadata, annotation)

      defp verify_properties_required_when(properties, metadata, {:property, property}) do
        check_property_exists(%{_metadata: metadata}, property) == :ok
      end

      defp verify_properties_required_when(properties, metadata, {:property, property, value}) do
        check_property_exists(%{_metadata: metadata}, property) == :ok and
          Map.get(properties, property) === value
      end

      defp verify_properties_required_when(properties, metadata, {:property, property, op, value}) do
        check_property_exists(%{_metadata: metadata}, property) == :ok and
          apply(Kernel, op, [Map.get(properties, property), value]) == true
      end

      defp verify_properties_required_when(properties, metadata, {:opts, option}) do
        with :error <- Map.fetch(metadata, option),
             :error <- Map.fetch(metadata.other, option) do
          false
        else
          {:ok, opt_val} -> opt_val == true
        end
      end

      defp verify_properties_required_when(properties, metadata, {:opts, option, value}) do
        with :error <- Map.fetch(metadata, option),
             :error <- Map.fetch(metadata.other, option) do
          false
        else
          {:ok, opt_val} -> opt_val === value
        end
      end

      defp verify_properties_required_when(properties, metadata, {:opts, option, op, value}) do
        with :error <- Map.fetch(metadata, option),
             :error <- Map.fetch(metadata.other, option) do
          false
        else
          {:ok, opt_val} -> apply(Kernel, op, [opt_val, value]) == true
        end
      end

      defp verify_properties_required_when(properties, _metadata, fun) when is_function(fun, 1) do
        fun.(properties) == true
      end

      defp verify_properties_required_when(properties, metadata, fun) when is_function(fun, 2) do
        fun.(properties, metadata) == true
      end

      defp verify_properties_required_when(properties, _metadata, _other), do: false

      @spec verify_properties_with_required_when(map(), internal_metadata()) ::
              {:ok, map()} | property_update_error()
      defp verify_properties_with_required_when(properties, metadata) do
        # We directly compute the annotations to only the ones with :required_when
        # at compile time to reduce runtime performance impact
        Enum.reduce_while(
          unquote(
            Enum.reduce(annotations, [], fn {name, key_annotations}, acc ->
              case Keyword.fetch(key_annotations, :required_when) do
                {:ok, value} -> [{name, value} | acc]
                :error -> acc
              end
            end)
          ),
          {:ok, properties},
          fn {name, annotation}, {:ok, properties} ->
            with true <- verify_properties_required_when(properties, metadata, annotation),
                 {:error, _term} <- check_property_exists(%{_metadata: metadata}, name),
                 {:ok, default_val} <-
                   Map.fetch(unquote(Macro.escape(default_properties_all)), name) do
              {:cont, {:ok, Map.put(properties, name, default_val)}}
            else
              term when term in [true, false, :ok] -> {:cont, {:ok, properties}}
              _else -> {:halt, {:error, {:missing_required_property, name}}}
            end
          end
        )
      end

      @spec verify_properties_with_only_when(map(), internal_metadata()) ::
              {:ok, map()} | property_update_error()
      defp verify_properties_with_only_when(properties, metadata) do
        # We directly compute the annotations to only the ones with :only_when
        # at compile time to reduce runtime performance impact
        Enum.reduce_while(
          unquote(
            Enum.reduce(annotations, [], fn {name, key_annotations}, acc ->
              case Keyword.fetch(key_annotations, :only_when) do
                {:ok, value} -> [{name, value} | acc]
                :error -> acc
              end
            end)
          ),
          {:ok, properties},
          fn {name, annotation}, {:ok, properties} ->
            required_state = verify_properties_required_when(properties, metadata, annotation)
            has_key = check_property_exists(%{_metadata: metadata}, name) == :ok

            cond do
              required_state and not has_key ->
                with {:ok, default_val} <-
                       Map.fetch(unquote(Macro.escape(default_properties_all)), name) do
                  {:cont, {:ok, Map.put(properties, name, default_val)}}
                else
                  _else -> {:halt, {:error, {:missing_required_property, name}}}
                end

              not required_state and has_key ->
                {:halt, {:error, {:property_not_allowed, name}}}

              true ->
                {:cont, {:ok, properties}}
            end
          end
        )
      end

      # Stuff for objects with priority_array property (and present_value property)
      if unquote(pv_ex_type) != nil and :priority_array in unquote(struct_deffields) do
        alias BACnet.Protocol.PriorityArray

        @doc """
        Get the active priority value from the priority array, or nil.
        """
        @spec get_priority_value(t()) ::
                {priority :: 1..16, value :: unquote(pv_typespec)} | nil
        def get_priority_value(%__MODULE__{priority_array: nil} = object) do
          nil
        end

        def get_priority_value(
              %__MODULE__{priority_array: %PriorityArray{} = prio_array} = object
            ) do
          PriorityArray.get_value(prio_array)
        end

        @doc """
        Sets the given priority in the priority array of an object.
        This function also updates the present value.
        """
        @spec set_priority(t(), 1..16, unquote(pv_typespec) | nil) ::
                {:ok, t()} | property_update_error()
        def set_priority(%__MODULE__{priority_array: nil} = _object, _priority, _value) do
          {:error, {:unknown_property, :priority_array}}
        end

        def set_priority(
              %__MODULE__{priority_array: %PriorityArray{} = prio_array} = object,
              priority,
              value
            )
            when priority in 1..16 do
          pv_check =
            if value == nil do
              :ok
            else
              check_property_value(object, :present_value, value, true)
            end

          case pv_check do
            :ok ->
              new_prio = Map.put(prio_array, PriorityArray.int_to_atom(priority), value)
              new_object = %{object | priority_array: new_prio}

              # If object is out of service, do not re-write present value
              new_object =
                if object.out_of_service do
                  new_object
                else
                  present_value =
                    case PriorityArray.get_value(new_prio) do
                      {_prio, value} -> value
                      nil -> new_object.relinquish_default
                    end

                  %{new_object | present_value: present_value}
                end

              # Update the feedback_value property with the present value
              unquote(
                if :feedback_value in struct_fields do
                  quote do
                    new_object =
                      if object._metadata.other[:auto_write_feedback] do
                        %{new_object | feedback_value: new_object.present_value}
                      else
                        new_object
                      end
                  end
                end
              )

              {:ok, new_object}

            {:error, {key, :present_value}} ->
              {:error, {key, :priority_array}}

            term ->
              term
          end
        end

        defoverridable set_priority: 3
      end

      @spec inhibit_object_check(t()) :: {:ok, t()} | {:error, term()}
      defp inhibit_object_check(obj), do: {:ok, obj}

      defoverridable create: 2,
                     create: 3,
                     create: 4,
                     add_property: 3,
                     remove_property: 2,
                     update_property: 3,
                     property_writable?: 2,
                     add_defaults: 2,
                     check_implicit_relationships: 2,
                     inhibit_object_check: 1

      #### Public API END ####

      @typedoc false
      @type internal_metadata :: %{
              properties_list: [Constants.property_identifier()],
              revision: non_neg_integer(),
              intrinsic_reporting: boolean(),
              remote_object: non_neg_integer() | true | nil,
              physical_input: boolean() | nil,
              other: map()
            }

      #### Public types START ####

      @typedoc """
      Common object options for creation - all are optional.

      - `allow_unknown_properties` - Properties that are unknown to the object implementation are usually rejected.
        With this option, unknown properties (numeric identifiers usually means we dont know them) are accepted
        and put into a separate map. This does mean we can not validate or write them.
        Types of the values can be anything at this point. While you can read unknown properties with atom
        or integer as property identifier, you can only remove numeric unknown property identifiers from an object.
        Property identifiers of type `atom` are only accepted, if it is a remote object (object implementation is only
        enforced if it is a local object). Numeric property identifiers are accepted regardless of remote object or not.
        For remote objects, this means you have to write "raw values" (usually `Encoding` structs).
      - `ignore_unknown_properties` - Properties that are unknown to the object implementation are usually rejected.
        With this option, unknown properties get ignored, as if they were not specified.
      - `revision` - The BACnet protocol revision to check required properties against.
        Optional properties are regardless of revision available.
        See `t:BACnet.Protocol.Constants.protocol_revision/0` for the available revisions.
      """
      @type common_object_opts ::
              {:allow_unknown_properties, boolean()}
              | {:ignore_unknown_properties, boolean()}
              | {:revision, Constants.protocol_revision()}

      @typedoc """
      Available property names for this object.
      """
      @type property_name :: unquote(fields)

      @typedoc """
      The structure for property errors.
      """
      @type property_update_error ::
              {:error, {error :: atom(), property :: Constants.property_identifier()}}

      #### Public types END ####

      #### Additional generated functions START ####

      @doc """
      Auto generated function to get the names of all properties this object supports.
      """
      @spec get_all_properties() :: [Constants.property_identifier()]
      def get_all_properties(), do: unquote(cleaned_fields)

      @doc """
      Auto generated function to get the names of properties used for COV reporting.
      """
      @spec get_cov_properties() :: [Constants.property_identifier()]
      def get_cov_properties(), do: unquote(cov_properties)

      @doc """
      Auto generated function to get the names of intrinsic properties.
      """
      @spec get_intrinsic_properties() :: [Constants.property_identifier()]
      def get_intrinsic_properties(), do: unquote(intrinsic_properties)

      @doc """
      Auto generated function to get the names of optional properties.
      """
      @spec get_optional_properties() :: [Constants.property_identifier()]
      def get_optional_properties(), do: unquote(cleaned_fields -- required_properties)

      @doc """
      Auto generated function to get the names of protected properties.

      Protected is an annotation and the object modules prevent writing to
      this property directly in code. The protected properties are either
      written on creation or updated automatically depending on other properties
      being written to. Some properties are only written once at creation and
      never updated.
      """
      @spec get_protected_properties() :: [Constants.property_identifier()]
      def get_protected_properties(), do: unquote(protected_properties)

      @doc """
      Auto generated function to get the names of readonly properties.

      Readonly is only an annotation that the property should be write protected
      on the BACnet side, there is no actual write protection in the object.
      This is a hint to the device server. If you need actual write protection, see `protected`.
      """
      @spec get_readonly_properties() :: [Constants.property_identifier()]
      def get_readonly_properties(), do: unquote(readonly_properties)

      @doc """
      Auto generated function to get the names of required properties.
      """
      @spec get_required_properties() :: [Constants.property_identifier()]
      def get_required_properties(), do: unquote(required_properties)

      @doc """
      Auto generated function to check whether the object type supports intrinsic reporting.
      """
      @spec supports_intrinsic() :: boolean()
      def supports_intrinsic(), do: unquote(supports_intrinsic)

      @doc """
      Auto generated function to get a map of property name to type.
      """
      @spec get_properties_type_map() :: map()
      def get_properties_type_map() do
        get_full_property_type_map()
      end

      #### Additional generated functions END ####

      @spec check_property_exists(map(), Constants.property_identifier()) ::
              :ok | property_update_error()
      defp check_property_exists(%{_metadata: %{properties_list: properties}} = object, property) do
        if property in properties do
          :ok
        else
          {:error, {:unknown_property, property}}
        end
      end

      @spec prevent_commandable_objects_write_pv(map(), Constants.property_identifier()) ::
              :ok | property_update_error()
      defp prevent_commandable_objects_write_pv(
             %{priority_array: %PriorityArray{} = _pa, out_of_service: false} = object,
             :present_value
           ) do
        {:error, {:protected_property, :present_value}}
      end

      defp prevent_commandable_objects_write_pv(_object, _property), do: :ok

      @spec check_property_value(t(), Constants.property_identifier(), term(), boolean()) ::
              :ok | property_update_error()
      defp check_property_value(object, property, value, check_protected)

      # The property priority_array needs some special handling
      unquote(
        if :priority_array in struct_deffields do
          quote do
            defp check_property_value(
                   object,
                   :priority_array,
                   %PriorityArray{} = value,
                   check_protected
                 ) do
              value
              |> Map.from_struct()
              |> Enum.reduce_while(:ok, fn {_key, val}, acc ->
                if val == nil do
                  {:cont, acc}
                else
                  case check_property_value(object, :present_value, val, check_protected) do
                    :ok -> {:cont, acc}
                    {:error, {term, _prop}} -> {:halt, {:error, {term, :priority_array}}}
                  end
                end
              end)
            end
          end
        end
      )

      defp check_property_value(object, property, value, check_protected) do
        case Map.fetch(get_full_property_type_map(), property) do
          :error ->
            {:error, {:unknown_type_for_property, property}}

          {:ok, type} ->
            cond do
              # Prevent writes to protected properties (they're OK to read if existing)
              check_protected and property in unquote(protected_properties) ->
                {:error, {:protected_property, property}}

              BeamTypes.check_type(type, value) ->
                case Keyword.fetch(unquote(properties_validators), property) do
                  :error ->
                    :ok

                  {:ok, {nil, nil}} ->
                    :ok

                  {:ok, {tfun, vfun}} ->
                    err = {:error, {:value_failed_property_validation, property}}

                    cond do
                      not apply_validator_fun(tfun, value, object, type) -> err
                      not apply_validator_fun(vfun, value, object, type) -> err
                      true -> :ok
                    end
                end

              true ->
                {:error, {:invalid_property_type, property}}
            end
        end
      end

      defp apply_validator_fun(val_fun, value, object, type)

      defp apply_validator_fun(val_fun, value, object, _type) do
        cond do
          is_function(val_fun, 0) -> val_fun.()
          is_function(val_fun, 1) -> val_fun.(value)
          is_function(val_fun, 2) -> val_fun.(value, object)
          true -> true
        end
      end

      @spec check_property_intrinsic(
              boolean(),
              Constants.property_identifier(),
              term(),
              boolean()
            ) :: :ok | property_update_error()
      defp check_property_intrinsic(object_is_intrinsic, property, value, allow_prop_nil)

      defp check_property_intrinsic(false, property, _value, _allow_prop_nil) do
        if property in unquote(intrinsic_properties) do
          {:error, {:intrinsic_property_not_available, property}}
        else
          :ok
        end
      end

      defp check_property_intrinsic(true, property, nil, false) do
        {:error, {:intrinsic_property_is_nil, property}}
      end

      defp check_property_intrinsic(true, property, value, _allow_prop_nil) do
        :ok
      end

      defp check_printable_object_name(name) do
        if byte_size(name) > 0 and String.valid?(name) and String.printable?(name) do
          :ok
        else
          {:error, {:invalid_non_printable_object_name, :object_name}}
        end
      end

      @default_value_phys_input (if Enum.member?(unquote(struct_deffields), :physical_input) do
                                   false
                                 else
                                   nil
                                 end)

      defp create_metadata_from_opts(opts) do
        metadata = %{
          properties_list: [],
          revision:
            Constants.by_name!(
              :protocol_revision,
              Keyword.get(
                opts,
                :revision,
                Constants.macro_by_name(:protocol_revision, :default)
              )
            ),
          intrinsic_reporting: !!Keyword.get(opts, :intrinsic_reporting, false),
          remote_object: Keyword.get(opts, :remote_object, nil),
          physical_input:
            case Keyword.get(opts, :physical_input, @default_value_phys_input) do
              nil -> nil
              term -> !!term
            end,
          other:
            Map.new(
              Keyword.drop(opts, [
                :properties_list,
                :revision,
                :ignore_unknown_properties,
                :intrinsic_reporting,
                :remote_object,
                :physical_input
              ])
            )
        }

        if not unquote(supports_intrinsic) and metadata.intrinsic_reporting do
          raise ArgumentError, "Object does not support intrinsic reporting"
        end

        metadata
      end

      defimpl Inspect do
        import Inspect.Algebra

        @name String.replace("#{@for}", "Elixir.", "")

        # This code has been taken from the Inspect.Map module and slightly adjusted
        def inspect(object, opts) do
          # If properties list is empty, this may be inside a pattern match
          # Since this is not the case usual for proper creation, expose all keys
          list =
            if object._metadata.properties_list == [] do
              # Enum.reject(object, &is_nil/1)
              object
            else
              object
              |> Map.take([:_unknown_properties | object._metadata.properties_list])
              |> Map.to_list()
              |> Enum.sort_by(fn {key, _val} ->
                str = Atom.to_string(key)

                if String.starts_with?(str, "_") do
                  binary_part(str, 1, byte_size(str) - 1)
                else
                  str
                end
              end)
            end

          fun =
            if Inspect.List.keyword?(list) do
              &Inspect.List.keyword/2
            else
              sep = color(" => ", :map, opts)
              &to_assoc(&1, &2, sep)
            end

          map_container_doc(list, @name, opts, fun)
        end

        defp to_assoc({key, value}, opts, sep) do
          concat(concat(to_doc(key, opts), sep), to_doc(value, opts))
        end

        defp map_container_doc(list, name, opts, fun) do
          open = color("#" <> name <> "<", :map, opts)
          sep = color(",", :map, opts)
          close = color(">", :map, opts)
          container_doc(open, list, close, opts, fun, separator: sep, break: :strict)
        end
      end
    end
  end

  defp get_services_data({:services, _meta, [services]}, _env) do
    %{
      intrinsic: !!Keyword.get(services, :intrinsic, false)
    }
  end

  defp get_field_data({:field, _meta, [name, typespec]}, env) do
    get_field_data({:field, [], [name, typespec, []]}, env)
  end

  defp get_field_data({:field, meta, [name, typespec, opts]}, env) do
    # Verify the property name is valid (skip "internal" properties)
    if name not in [:_metadata, :object_instance] and
         not Constants.has_by_name(:property_identifier, name) do
      raise ArgumentError, "Unknown property name \"#{inspect(name)}\""
    end

    bac_type_lazy =
      case Keyword.fetch(opts, :bac_type) do
        {:ok, ast} ->
          case ast do
            # Expand {:with_validator, type, validator_fun}
            {:{}, _line, args} ->
              List.to_tuple(args)

            # Allow types that are valid for BeamTypes.check_type/2
            {key, _term}
            when key in [
                   :array,
                   :constants,
                   :in_list,
                   :list,
                   :literal,
                   :struct,
                   :tuple,
                   :type_list
                 ] ->
              ast

            # Allow types that are valid for BeamTypes.check_type/2
            {key, _term, _term2} when key in [:array, :in_range, :with_validator] ->
              ast

            # Otherwise only types (such as :double)
            term when is_atom(term) ->
              term

            _term ->
              raise ArgumentError, "Invalid bac_type for field #{name}, got: #{inspect(ast)}"
          end

        :error ->
          BeamTypes.resolve_type(typespec, %{env | line: meta[:line] || env.line})
      end

    {bac_type, type_validator} =
      case bac_type_lazy do
        # I'm not sure how we want to test {:list, {:with_validator, ..., ..}},
        # it probably requires some work to make it work (and properly expand from AST)
        #
        # {:list, {:with_validator, bac_type, type_validator}} ->
        #   {{:list, bac_type}, type_validator}

        {:with_validator, bac_type, type_validator} ->
          {bac_type, type_validator}

        bac_type ->
          {bac_type, nil}
      end

    required = Keyword.get(opts, :required, false)
    readonly = Keyword.get(opts, :readonly, false)
    protected = Keyword.get(opts, :protected, false)
    cov = Keyword.get(opts, :cov, false)
    intrinsic = Keyword.get(opts, :intrinsic, false)
    default = Keyword.get(opts, :default, nil)
    implicit_relationship = Keyword.get(opts, :implicit_relationship, nil)
    annotations = List.flatten(Keyword.get_values(opts, :annotation))

    validator_fun =
      case Keyword.get(opts, :validator_fun, nil) do
        nil ->
          nil

        ast ->
          case Macro.expand(ast, env) do
            # Capture operator
            {:&, _meta, _args} ->
              ast

            # Anonymous function using `fn` macro
            {:fn, _meta, _args} ->
              ast

            _term ->
              raise ArgumentError,
                    "Invalid validator_fun for field #{name}, " <>
                      "not a function definition (& capture or fn), " <>
                      "got: #{inspect(ast)}"
          end
      end

    init_fun =
      case Keyword.get(opts, :init_fun, nil) do
        nil ->
          nil

        ast ->
          case Macro.expand(ast, env) do
            {:&, _meta, _args} = ast ->
              fun = elem(Code.eval_quoted(ast, [], env), 0)

              if is_function(fun, 0) do
                fun
              else
                raise ArgumentError,
                      "Invalid init_fun for field #{name} given, " <>
                        "function captures with arity > 0 are not supported"
              end

            ast ->
              raise ArgumentError,
                    "Invalid init_fun for field #{name} given, " <>
                      "expected a remote function capture with arity 0, " <>
                      "got: #{inspect(ast)}"
          end
      end

    # Expand the AST for default
    default =
      case Macro.expand(default, env) do
        # Nothing
        nil ->
          nil

        # Function call, execute it at compile time
        {{:., _meta, [{:__aliases__, _meta2, _module}, fun]}, _any, args} = ast
        when is_atom(fun) and is_list(args) ->
          elem(Code.eval_quoted(ast, [], env), 0)

        # Captured function, execute it at compile time
        # Only functions with arity 0, outside of the module, are supported
        {:&, _meta, _args} = ast ->
          fun = elem(Code.eval_quoted(ast, [], env), 0)

          if is_function(fun, 0) do
            fun.()
          else
            raise ArgumentError, "Function captures with arity > 0 are not supported"
          end

        # Function, execute it at compile time
        # Only function with arity 0
        {:fn, _meta, _args} = ast ->
          fun = elem(Code.eval_quoted(ast, [], env), 0)

          if is_function(fun, 0) do
            fun.()
          else
            raise ArgumentError, "Functions with arity > 0 are not supported"
          end

        # Map definition, execute it at compile time
        {:%, _meta, _more} = ast ->
          elem(Code.eval_quoted(ast, [], env), 0)

        # String concatenation, execute it at compile time
        {:<<>>, _meta, _more} = ast ->
          elem(Code.eval_quoted(ast, [], env), 0)

        # Variable
        {var, meta, nil} when is_atom(var) and is_list(meta) ->
          raise ArgumentError, "Variables can not be given to the default value"

        term ->
          term
      end

    if bac_type != nil and default != nil and not BeamTypes.check_type(bac_type, default) do
      raise ArgumentError,
            "Invalid default value for field #{name}, " <>
              "expected type \"#{inspect(bac_type)}\", " <>
              "got value: #{inspect(default)}"
    end

    if implicit_relationship == name do
      raise ArgumentError,
            "Invalid implicit relationship value for field #{name}, " <>
              "expected a different value than the field name (#{name})"
    end

    %{
      name: name,
      typespec: typespec,
      bac_type: bac_type,
      required: required and not intrinsic,
      readonly: readonly,
      protected: protected,
      cov: cov,
      intrinsic: intrinsic,
      default: default,
      implicit_relationship: implicit_relationship,
      type_validator: type_validator,
      validator_fun: validator_fun,
      init_fun: init_fun,
      annotations: annotations
    }
  end

  #### Internal default properties and implicit relationships helpers START ####

  @spec get_default_implicit_relationships() :: Keyword.t()
  defp get_default_implicit_relationships() do
    [
      priority_array: :relinquish_default
    ]
  end

  @spec get_default_intrinsic_properties() :: Keyword.t()
  defp get_default_intrinsic_properties() do
    [
      acked_transitions: get_default_event_transbits(true),
      event_algorithm_inhibit: false,
      event_algorithm_inhibit_ref: get_default_object_ref(),
      event_detection_enable: true,
      event_enable: get_default_event_transbits(false),
      event_message_texts: %BACnet.Protocol.EventMessageTexts{
        to_offnormal: "",
        to_fault: "",
        to_normal: ""
      },
      event_message_texts_config: get_default_event_message_texts(),
      event_timestamps: %BACnet.Protocol.EventTimestamps{
        to_offnormal: @default_bacnet_timestamp,
        to_fault: @default_bacnet_timestamp,
        to_normal: @default_bacnet_timestamp
      },
      limit_enable: %BACnet.Protocol.LimitEnable{
        low_limit_enable: false,
        high_limit_enable: false
      },
      notify_type: Constants.macro_assert_name(:notify_type, :alarm),
      notification_class: 0,
      time_delay: 0,
      time_delay_normal: 0
    ]
  end

  @spec get_default_optional_properties() :: Keyword.t()
  defp get_default_optional_properties() do
    [
      reliability: Constants.macro_assert_name(:reliability, :no_fault_detected),
      reliability_evaluation_inhibit: false,
      priority_array: %PriorityArray{}
    ]
  end

  @spec get_default_required_properties() :: Keyword.t()
  defp get_default_required_properties() do
    [
      event_state: Constants.macro_assert_name(:event_state, :normal),
      out_of_service: false,
      status_flags: %BACnet.Protocol.StatusFlags{
        in_alarm: false,
        fault: false,
        overridden: false,
        out_of_service: false
      }
    ]
  end

  #### Internal default properties and implicit relationships helpers END ####

  @spec generate_moduledoc(Constants.object_type(), [map()]) :: String.t()
  defp generate_moduledoc(object_type, fields_data) do
    properties =
      fields_data
      |> Enum.reject(fn %{name: name} -> String.starts_with?(Atom.to_string(name), "_") end)
      |> Enum.sort_by(fn %{name: name} -> name end, :asc)

    properties_table =
      Enum.map_join(properties, "\n", fn field ->
        "| #{field.name} | #{field.annotations[:revision] || ""} | #{bool_to_string(field.required)} " <>
          "| #{bool_to_string(field.readonly)} | #{bool_to_string(field.protected)} " <>
          "| #{bool_to_string(field.intrinsic)} |"
      end)

    props_info_table =
      properties
      |> Enum.filter(fn field ->
        field.default || field.init_fun || field.implicit_relationship || field.validator_fun ||
          field.type_validator || field.annotations != []
      end)
      |> Enum.map_join("\n", fn field ->
        validators =
          []
          |> then(&if field.validator_fun, do: ["Fun" | &1], else: &1)
          |> then(&if field.type_validator, do: ["Type" | &1], else: &1)
          |> Enum.reverse()
          |> Enum.join("/")

        annotations =
          case field.annotations do
            [] -> ""
            _else -> "`#{String.trim(String.trim(inspect(field.annotations), "["), "]")}`"
          end

        "| #{field.name} | #{bool_to_string(field.default != nil)} | #{bool_to_string(field.init_fun != nil)} " <>
          "| #{field.implicit_relationship} | #{validators} | #{annotations} |"
      end)

    props_defaults_table =
      properties
      |> Enum.filter(fn field ->
        field.default || field.init_fun
      end)
      |> Enum.map_join("\n", fn field ->
        default =
          case field.default do
            nil ->
              ""

            %name{} ->
              title =
                field.default
                |> inspect(pretty: false)
                |> String.replace("\"", "&quot;")

              "<a title=\"#{title}\">`%#{String.replace("#{name}", "Elixir.", "")}{...}`</a>"

            _else ->
              "`#{inspect(field.default)}`"
          end

        init_fun =
          case field.init_fun do
            nil ->
              ""

            _else ->
              "`#{String.trim_leading(String.replace(inspect(field.init_fun),
              "BACnet.Protocol.ObjectsUtility.Internal",
              "Utility.Internal"),
              "&")}`"
          end

        "| #{field.name} | #{default} | #{init_fun} |"
      end)

    """
    ---------------------------------------------------------------------------
    The following part has been automatically generated.

    <details>
    <summary>Click to expand</summary>

    This module defines a BACnet object of the type `#{object_type}`. The following properties are defined:

    | Property | Revision | Required | Readonly | Protected | Intrinsic |
    |----------|----------|----------|----------|-----------|-----------|
    #{properties_table}

    The following properties have additional semantics:

    | Property | Has Default | Has Init | Implicit Relationships | Validators | Annotations |
    |----------|-------------|----------|------------------------|------------|-------------|
    #{props_info_table}

    The following table shows the default values and/or init functions:

    | Property | Default Value | Init Function |
    |----------|---------------|---------------|
    #{props_defaults_table}
    </details>
    """
  end

  defp bool_to_string(true), do: "X"
  defp bool_to_string(false), do: ""
end
