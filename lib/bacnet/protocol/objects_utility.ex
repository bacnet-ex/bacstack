defmodule BACnet.Protocol.ObjectsUtility do
  @moduledoc """
  This module offers utility functions that work on all object types.

  This is mostly complementary to the object module itself and offers some
  additional generic functions for working with objects.

  Some functions will call `Code.ensure_loaded/1` on object modules to ensure the
  module is loaded and available - however only if `Mix.env/0` does not return `:prod`.
  If this library is a dependency in a project, Mix always compiles dependencies in `:prod`.
  To override this behaviour, see `mix help deps`.
  """

  alias __MODULE__.Internal.ReadPropertyAckTransformOptions, as: RPATransformOptions
  alias BACnet.BeamTypes
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectTypes
  alias BACnet.Protocol.PriorityArray
  alias BACnet.Protocol.ReadAccessResult
  alias BACnet.Protocol.Services.Ack.ReadPropertyAck
  alias BACnet.Protocol.Services.Ack.ReadPropertyMultipleAck

  require Constants

  @object_type_mappings_key {__MODULE__, :object_type_mappings}

  @types [
    ObjectTypes.Accumulator,
    ObjectTypes.AnalogInput,
    ObjectTypes.AnalogOutput,
    ObjectTypes.AnalogValue,
    ObjectTypes.Averaging,
    ObjectTypes.BinaryInput,
    ObjectTypes.BinaryOutput,
    ObjectTypes.BinaryValue,
    ObjectTypes.BitstringValue,
    ObjectTypes.Calendar,
    ObjectTypes.CharacterStringValue,
    ObjectTypes.Command,
    ObjectTypes.DatePatternValue,
    ObjectTypes.DateTimePatternValue,
    ObjectTypes.DateTimeValue,
    ObjectTypes.DateValue,
    ObjectTypes.Device,
    ObjectTypes.EventEnrollment,
    ObjectTypes.EventLog,
    ObjectTypes.File,
    ObjectTypes.Group,
    ObjectTypes.IntegerValue,
    ObjectTypes.LargeAnalogValue,
    ObjectTypes.Loop,
    ObjectTypes.MultistateInput,
    ObjectTypes.MultistateOutput,
    ObjectTypes.MultistateValue,
    ObjectTypes.NotificationClass,
    ObjectTypes.OctetStringValue,
    ObjectTypes.PositiveIntegerValue,
    ObjectTypes.Program,
    ObjectTypes.PulseConverter,
    ObjectTypes.Schedule,
    ObjectTypes.StructuredView,
    ObjectTypes.TimePatternValue,
    ObjectTypes.TimeValue,
    ObjectTypes.TrendLog,
    ObjectTypes.TrendLogMultiple
  ]

  types_spec =
    @types
    |> Enum.map(fn type ->
      quote do
        unquote(type).t()
      end
    end)
    |> Enum.sort(:desc)
    |> Enum.reduce(fn field, acc ->
      {:|, [], [field, acc]}
    end)

  defmacrop get_fa_str() do
    {fun, arity} = __CALLER__.function
    str = "#{fun}/#{arity}"

    quote do
      unquote(str)
    end
  end

  @typedoc """
  BACnet object types that this module works with.
  """
  @type bacnet_object :: unquote(types_spec)

  @typedoc """
  Valid options for `cast_property_to_value/4`.
  """
  @type cast_property_to_value_option :: {:allow_partial, boolean()}

  @typedoc """
  Valid options for `cast_properties_to_object/3`.

  `allow_unknown_properties` allows `:no_unpack` as synonym for `true`.
  """
  @type cast_properties_to_object_option ::
          {:allow_unknown_properties, boolean() | :no_unpack}
          | {:ignore_unknown_properties, boolean()}
          | {:remote_device_id, non_neg_integer()}
          | {:revision, Constants.protocol_revision()}
          | {:object_opts, Keyword.t()}

  @typedoc """
  Valid options for `cast_read_properties_ack/3`.
  """
  @type cast_read_properties_ack_option ::
          {:allow_unknown_properties, boolean() | :no_unpack}
          | {:ignore_array_indexes, boolean()}
          | {:ignore_invalid_properties, boolean()}
          | {:ignore_object_identifier_mismatch, boolean()}
          | {:ignore_unknown_properties, boolean()}

  @typedoc """
  Valid options for `cast_value_to_property/4`.
  """
  @type cast_value_to_property_option :: {:allow_nil, boolean()} | {:allow_partial, boolean()}

  @doc """
  Checks whether the given struct is a supported BACnet object (see `t:bacnet_object/0`).

  Note: This guard is not widely used by this module itself, but may be useful for others.
  """
  defguard is_object(object)
           when is_struct(object) and :erlang.map_get(:__struct__, object) in @types

  @doc """
  Checks whether the given BACnet object has Intrinsic Reporting enabled.

  This is the same functionality as `intrinsic_reporting?/1`, but as a guard.
  """
  defguard is_object_intrinsic(object)
           when is_map(object) and
                  :erlang.map_get(:intrinsic_reporting, :erlang.map_get(:_metadata, object)) ==
                    true

  @doc """
  Checks whether the given BACnet object is a local object (identified through metadata).

  A local object is a BACnet object that resides in the local BACnet device (this bacstack).
  """
  defguard is_object_local(object)
           when is_map(object) and
                  :erlang.map_get(:remote_object, :erlang.map_get(:_metadata, object)) == nil

  @doc """
  Checks whether the given BACnet object is a remote object (identified through metadata).

  A remote object is a BACnet object that resides in a remote BACnet device - as such
  some operations don't work (such as adding optional properties).
  """
  defguard is_object_remote(object)
           when is_map(object) and
                  is_integer(:erlang.map_get(:remote_object, :erlang.map_get(:_metadata, object))) and
                  :erlang.map_get(:remote_object, :erlang.map_get(:_metadata, object)) != nil

  # defmacrop is_env(env, do: code), do: if(Mix.env() == env, do: code)
  defmacrop unless_env(env, do: code), do: unless(Mix.env() == env, do: code)

  @doc """
  Get the object type to module mappings.

  This mapping is used for object properties casting (such as `cast_property_to_value/4`).
  This mapping is stored in `:persistent_term` and is automatically populated on first use
  with all object types from the `bacstack` application.
  """
  @spec get_object_type_mappings() :: %{optional(Constants.object_type()) => module()}
  def get_object_type_mappings() do
    case :persistent_term.get(@object_type_mappings_key, nil) do
      # If the key doesn't exist yet, populate it from our application
      nil ->
        case :application.get_key(:bacstack, :modules) do
          {:ok, modules} ->
            mods =
              modules
              |> Enum.filter(&String.contains?(Atom.to_string(&1), ".ObjectTypes."))
              |> Enum.flat_map(fn module ->
                case module.__info__(:attributes)[:bacnet_object] do
                  [type] -> [{type, module}]
                  _else -> []
                end
              end)
              |> Enum.into(%{})

            :persistent_term.put(@object_type_mappings_key, mods)
            mods

          _err ->
            raise "Unable to determine BACnet object types from application bacstack"
        end

      map ->
        map
    end
  end

  @doc """
  Put an object type to module relationship into the mappings.

  See also `get_object_type_mappings/0` for more information.
  """
  @spec put_object_type_mapping(Constants.object_type(), module()) :: :ok
  def put_object_type_mapping(object_type, module)
      when is_atom(object_type) and is_atom(module) do
    get_object_type_mappings()
    |> Map.put(object_type, module)
    |> then(&:persistent_term.put(@object_type_mappings_key, &1))
  end

  @doc """
  Put many object type to module relationships into the mappings at once.

  See also `get_object_type_mappings/0` for more information.
  """
  @spec put_many_object_type_mapping([{Constants.object_type(), module()}]) :: :ok
  def put_many_object_type_mapping(mappings) when is_list(mappings) do
    unless Enum.all?(mappings, fn
             {type, mod} -> is_atom(type) and is_atom(mod)
             _else -> false
           end) do
      raise ArgumentError,
            "Mappings is not a list of tuple with both elements being an atom, " <>
              "got: " <> inspect(mappings)
    end

    get_object_type_mappings()
    |> then(&Enum.reduce(mappings, &1, fn {key, val}, acc -> Map.put(acc, key, val) end))
    |> then(&:persistent_term.put(@object_type_mappings_key, &1))
  end

  @doc """
  Delete an object type to module relationship from the mappings.

  See also `get_object_type_mappings/0` for more information.
  """
  @spec delete_object_type_mapping(Constants.object_type()) :: :ok
  def delete_object_type_mapping(object_type) when is_atom(object_type) do
    get_object_type_mappings()
    |> Map.delete(object_type)
    |> then(&:persistent_term.put(@object_type_mappings_key, &1))
  end

  @doc """
  Get the object identifier for the BACnet object. The `bacnet_object` contract is enforced.
  """
  @spec get_object_identifier(bacnet_object()) :: ObjectIdentifier.t()
  def get_object_identifier(%_any{object_instance: instance} = object) when is_object(object) do
    %ObjectIdentifier{
      type: get_object_type(object),
      instance: instance
    }
  end

  @doc """
  Get the BACnet object type. The `bacnet_object` contract is enforced.
  """
  @spec get_object_type(bacnet_object()) :: Constants.object_type()
  def get_object_type(%mod{} = _object) do
    type = mod.__info__(:attributes)[:bacnet_object]

    unless is_list(type) and length(type) == 1 do
      raise ArgumentError,
            "Invalid BACnet object type module, missing or invalid persistent attribute :bacnet_object"
    end

    hd(type)
  end

  @doc """
  Get the list of properties the object has.
  """
  @spec get_properties(bacnet_object()) :: [Constants.property_identifier()]
  def get_properties(%{_metadata: %{properties_list: list}} = _object) do
    list
  end

  @doc """
  Checks if the given object has the given property.

  > #### Implementation Detail {: .info}
  > This function is O(n), as it traverses the properties list.
  > This actually represents what on the BACnet side can be seen, as only properties in the
  > properties list can be used (observable).
  """
  @spec has_property?(bacnet_object(), Constants.property_identifier()) :: boolean()
  def has_property?(%_any{_metadata: %{properties_list: list}} = _object, property)
      when is_atom(property) do
    property in list
  end

  @doc """
  Checks whether the given object has a priority array.
  This function does not verify if the property is in the properties list of the object.
  """
  @spec has_priority_array?(bacnet_object()) :: boolean()
  def has_priority_array?(%_any{priority_array: %PriorityArray{} = _array} = _object), do: true
  def has_priority_array?(%_any{} = _object), do: false

  @doc """
  Checks if the given object has Intrinsic Reporting enabled.
  """
  @spec intrinsic_reporting?(bacnet_object()) :: boolean()
  def intrinsic_reporting?(%_any{_metadata: %{intrinsic_reporting: intrin}} = _object) do
    intrin
  end

  @doc """
  Checks if the given property is writable.

  This implementation checks for arbitary properties, if the property exists
  and is not annotated as readonly. For commandable objects and the present value, it
  checks if the object is out of service. For the event algorithm inhibit property,
  it checks if ref is absent or uninitialized and event detection is enabled.

  Object-specific behaviour are not checked and should instead be directly checked
  through the object module.
  """
  @spec property_writable?(bacnet_object(), Constants.property_identifier()) :: boolean()
  def property_writable?(%bac{} = object, property) when is_atom(property) do
    if has_property?(object, property) do
      case property do
        :event_algorithm_inhibit ->
          case object do
            %{event_algorithm_inhibit_ref: ref, event_detection_enable: true}
            when not is_nil(ref) ->
              ref.object_identifier.instance ==
                Constants.macro_by_name(:asn1, :max_instance_and_property_id)

            %{event_algorithm_inhibit_ref: nil, event_detection_enable: true} ->
              true

            _term ->
              false
          end

        :present_value ->
          case object do
            %{priority_array: pa} when not is_nil(pa) -> !!Map.get(object, :out_of_service)
            _term -> true
          end

        _term ->
          if function_exported?(bac, :get_readonly_properties, 0) do
            not Enum.member?(bac.get_readonly_properties(), property)
          else
            true
          end
      end
    else
      false
    end
  end

  @doc """
  Adds an optional property to an object (see `t:bacnet_object/0`).

  Please note that properties of services can **not** be dynamically added and instead
  the object must be newly created.

  This function calls to the object module directly, as such it enforces the `t:bacnet_object/0` contract.
  """
  @spec add_property(bacnet_object(), Constants.property_identifier(), term()) ::
          {:ok, bacnet_object()} | {:error, term()}
  def add_property(%bac{} = object, property, value)
      when is_object(object) and is_atom(property) do
    bac.add_property(object, property, value)
  end

  @doc """
  Get the property of an object (see `t:bacnet_object/0`).

  This function calls to the object module directly, as such it enforces the `t:bacnet_object/0` contract.
  """
  @spec get_property(bacnet_object(), Constants.property_identifier()) ::
          {:ok, term()} | {:error, term()}
  def get_property(%bac{} = object, property)
      when is_object(object) and is_atom(property) do
    bac.get_property(object, property)
  end

  @doc """
  Removes an optional property from an object (see `t:bacnet_object/0`). This function is idempotent.

  Please note that properties of services can **not** be dynamically removed and instead
  the object must be newly created. Required properties can not be removed.

  This function calls to the object module directly, as such it enforces the `t:bacnet_object/0` contract.
  """
  @spec remove_property(bacnet_object(), Constants.property_identifier()) ::
          {:ok, bacnet_object()} | {:error, term()}
  def remove_property(%bac{} = object, property) when is_object(object) and is_atom(property) do
    bac.remove_property(object, property)
  end

  @doc """
  Updates a property of an object (see `t:bacnet_object/0`).

  This function calls to the object module directly, as such it enforces the `t:bacnet_object/0` contract.
  """
  @spec update_property(bacnet_object(), Constants.property_identifier(), term()) ::
          {:ok, bacnet_object()} | {:error, term()}
  def update_property(%bac{} = object, property, value)
      when is_object(object) and is_atom(property) do
    bac.update_property(object, property, value)
  end

  @doc """
  Get the active priority value from the priority array, or nil.
  """
  @spec get_priority_value(bacnet_object()) ::
          {priority :: 1..16, value :: term()} | nil
  def get_priority_value(%{priority_array: %PriorityArray{} = prio_array} = _object) do
    PriorityArray.get_value(prio_array)
  end

  def get_priority_value(%{} = _object) do
    nil
  end

  @doc """
  Sets the given priority in the priority array of an object (see `t:bacnet_object/0`).
  This function also updates the present value.

  This function calls to the object module directly, as such it enforces the `t:bacnet_object/0` contract,
  and additionally only objects with a priority array can be used.
  """
  @spec set_priority(bacnet_object(), 1..16, term()) ::
          {:ok, bacnet_object()} | {:error, term()}
  def set_priority(%{priority_array: nil} = _object, _priority, _value) do
    {:error, {:unknown_property, :priority_array}}
  end

  def set_priority(%bac{priority_array: %PriorityArray{} = _pa} = object, priority, value)
      when is_object(object) do
    bac.set_priority(object, priority, value)
  end

  @doc """
  Get the remote device ID for remote objects.

  For remote objects with no remote device ID attached,
  this function will return `:error`.
  For local objects, this function will return `nil`.
  """
  @spec get_remote_device_id(bacnet_object()) :: {:ok, non_neg_integer()} | :error | nil
  def get_remote_device_id(object)

  def get_remote_device_id(%{_metadata: %{remote_object: true}}) do
    :error
  end

  def get_remote_device_id(%{_metadata: %{remote_object: rem}}) when is_integer(rem) do
    {:ok, rem}
  end

  def get_remote_device_id(%{} = _object) do
    nil
  end

  @doc """
  Truncates each property, which is a float, to the given precision (float rounding).

  When giving an integer as precision, this function will behave just like `Float.round/2`.
  When giving a float as precision, this function will determine
  the precision (i.e. 1 for `0.1`, 2 for `0.01`, 0 for any value >= `1.0` or `0.0`).
  The float value itself is not relevant, only how many decimal points there are.

  Depending on the selected mode, the float will be rounded or the value is truncated.
  """
  @spec truncate_float_properties(
          bacnet_object(),
          float() | non_neg_integer(),
          :round | :truncate
        ) :: bacnet_object()
  def truncate_float_properties(object, precision, mode \\ :round)

  def truncate_float_properties(%_bac{} = object, precision, mode)
      when is_integer(precision) and precision >= 0 and mode in [:round, :truncate] do
    truncate_floats_object(object, precision, mode)
  end

  def truncate_float_properties(%_bac{} = object, -0.0, mode) when mode in [:round, :truncate] do
    truncate_floats_object(object, 0, mode)
  end

  def truncate_float_properties(%_bac{} = object, +0.0, mode) when mode in [:round, :truncate] do
    truncate_floats_object(object, 0, mode)
  end

  def truncate_float_properties(%_bac{} = object, precision, mode)
      when is_float(precision) and precision >= 1.0 and mode in [:round, :truncate] do
    truncate_floats_object(object, 0, mode)
  end

  def truncate_float_properties(%_bac{} = object, precision, mode)
      when is_float(precision) and precision < 1.0 and mode in [:round, :truncate] do
    resolution =
      precision
      |> Float.to_string()
      |> String.split(".")
      |> tl()
      |> hd()
      |> byte_size()
      |> min(15)

    truncate_floats_object(object, resolution, mode)
  end

  defp truncate_floats_object(%name{} = object, precision, mode) do
    object
    |> Map.from_struct()
    |> Enum.reduce(object, fn
      {key, %PriorityArray{} = pa}, acc ->
        Map.put(acc, key, truncate_floats_object(pa, precision, mode))

      {key, val}, acc when is_float(val) ->
        Map.put(acc, key, truncate_floats(val, precision, mode))

      _pair, acc ->
        acc
    end)
    |> then(&struct(name, &1))
  end

  defp truncate_floats(float, precision, :round), do: Float.round(float, precision)

  defp truncate_floats(float, precision, :truncate) do
    pow = Integer.pow(10, precision)
    trunc(float * pow) / pow
  end

  @doc """
  Validates that the given value is within the `min_present_value` and `max_present_value` (range).

  It verifies that the given value is within the configured `min` and `max`, which can also be
  `:NaN`, `:inf` and `:infn`.

  The given value can not be larger than the configured `max` or smaller than the configured `min`.
  In particular, `:NaN` is always allowed as value, regardless of the configured range.

  No validation is done if either `min` or `max` is missing (or `nil`).
  """
  @spec validate_float_range(ApplicationTags.ieee_float(), %{
          optional(:min_present_value) => ApplicationTags.ieee_float() | nil,
          optional(:max_present_value) => ApplicationTags.ieee_float() | nil
        }) :: boolean()
  def validate_float_range(value, object)

  def validate_float_range(value, %{min_present_value: min, max_present_value: max})
      when min not in [nil, :NaN] and max not in [nil, :NaN] and value != :NaN do
    do_validate_float_range(min, value) and do_validate_float_range(value, max)
  end

  def validate_float_range(_value, _obj) do
    true
  end

  # `value` can not be larger than `value2`
  @spec do_validate_float_range(float() | :inf | :infn, float() | :inf | :infn) :: boolean()
  defp do_validate_float_range(value, value2)

  defp do_validate_float_range(:inf, :inf), do: true
  defp do_validate_float_range(:inf, _value2), do: false
  defp do_validate_float_range(:infn, _value2), do: true
  defp do_validate_float_range(_value, :inf), do: true
  defp do_validate_float_range(_value, :infn), do: false

  defp do_validate_float_range(value, value2) when is_float(value) and is_float(value),
    do: value <= value2

  @doc """
  Casts a property from application tag `Encoding` to a more sane data type.

  To cast the property to the proper data type, the correct object module needs to be known,
  which contains that property. The object module will tell us which data type should it be.
  As such, an object identifier is required.

  Note: In prod environment, required modules are not explicitely loaded.

  The following options are available:
  - `allow_partial: boolean()` - Optional. Allows partial values of array or list properties (a single value).
  """
  @spec cast_property_to_value(
          ObjectIdentifier.t(),
          Constants.property_identifier(),
          Encoding.t() | [Encoding.t()],
          [cast_property_to_value_option()]
        ) :: {:ok, term()} | {:error, {atom(), term()}} | {:error, term()}
  def cast_property_to_value(objectid, property_identifier, value, opts \\ [])

  def cast_property_to_value(
        %ObjectIdentifier{type: type_mod} = _object_id,
        property_identifier,
        value,
        opts
      )
      when is_atom(property_identifier) and (is_struct(value, Encoding) or is_list(value)) and
             is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "cast_property_to_value/4 expected a keyword list, got: #{inspect(opts)}"
    end

    case get_object_type_mappings()[type_mod] do
      nil ->
        {:error, :unsupported_object_type}

      object_mod ->
        unless_env(:prod, do: Code.ensure_loaded!(object_mod))

        process_make_property(object_mod, property_identifier, value,
          allow_partial: get_bool_opts(opts, :allow_partial, get_fa_str(), false)
        )
    end
  end

  @doc """
  Create an object from a map of properties.
  This function is used for remote objects, not for local objects.

  This function invokes the object module's `create` function.

  Note: In prod environment, required modules are not explicitely loaded.

  The following options are available:
  - `allow_unknown_properties: boolean()` - Optional. Allows unknown property identifiers - which means we have no validation (defaults to `false`).
  - `ignore_unknown_properties: boolean()` - Optional. Ignores properties the object module doesn't support (defaults to `false`).
  - `remote_device_id: non_neg_integer()` - Optional. Adds the remote BACnet device ID to the object (ID is used for trend logging).
  - `revision: Constants.protocol_revision()` - Optional. The BACnet protocol revision to check the properties against.
  - `object_opts: Keyword.t()` - Optional. All other object creation options to pass to the `create` function.
  """
  @spec cast_properties_to_object(
          BACnet.Protocol.ObjectIdentifier.t(),
          %{optional(Constants.property_identifier() | atom() | non_neg_integer()) => term()},
          [cast_properties_to_object_option()]
        ) ::
          {:ok, bacnet_object()} | {:error, {atom(), term()}} | {:error, term()}
  def cast_properties_to_object(object_id, properties, opts)

  def cast_properties_to_object(
        %ObjectIdentifier{type: type_mod} = object_id,
        %{} = properties,
        opts
      )
      when is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "cast_properties_to_object/3 expected a keyword list, got: #{inspect(opts)}"
    end

    object_opts = Keyword.get(opts, :object_opts, [])

    unless Keyword.keyword?(object_opts) do
      raise ArgumentError,
            "cast_properties_to_object/3 expected a keyword list " <>
              "for opts[:object_opts], got: #{inspect(object_opts)}"
    end

    case get_object_type_mappings()[type_mod] do
      nil ->
        {:error, :unsupported_object_type}

      object_mod ->
        unless_env(:prod, do: Code.ensure_loaded!(object_mod))

        case Map.pop(properties, Constants.macro_assert_name(:property_identifier, :object_name)) do
          {nil, _term} ->
            {:error,
             {:missing_property, Constants.macro_assert_name(:property_identifier, :object_name)}}

          {obj_name, properties} ->
            # Make sure we remove properties we don't handle like that
            reduced_properties = Map.drop(properties, [:object_identifier, :object_type])

            object_mod.create(
              object_id.instance,
              obj_name,
              reduced_properties,
              Keyword.merge(
                object_opts,
                allow_unknown_properties: !!Keyword.get(opts, :allow_unknown_properties, false),
                ignore_unknown_properties:
                  get_bool_opts(
                    opts,
                    :ignore_unknown_properties,
                    "cast_properties_to_object/3",
                    false
                  ),
                intrinsic_reporting:
                  object_mod.supports_intrinsic() and Map.has_key?(properties, :notify_type),
                remote_object:
                  Keyword.get_lazy(opts, :remote_device_id, fn ->
                    if(object_id.type == :device, do: object_id.instance, else: true)
                  end),
                revision:
                  Keyword.get(
                    opts,
                    :revision,
                    Constants.macro_by_name(:protocol_revision, :default)
                  )
              )
            )
        end
    end
  end

  @doc """
  Casts the properties and its values from `Read-Property-(Multiple-)Ack`s into a map of properties.

  Note: In prod environment, required modules are not explicitely loaded.

  The following options are available:
  - `allow_unknown_properties: boolean() | :no_unpack` - Optional. Allows unknown property identifiers - which means we have no validation (defaults to `false`).
  - `ignore_array_indexes: boolean()` - Optional. Ignores property array indexes as they are currently not supported (defaults to `false`).
  - `ignore_invalid_properties: boolean()` - Optional. Ignores invalid properties (defaults to `false`).
  - `ignore_object_identifier_mismatch: boolean()` - Optional. Ignores mismatches between object identifiers (defaults to `false`).
  - `ignore_unknown_properties: boolean()` - Optional. Ignores unknown property identifiers (defaults to `false`).
  """
  @spec cast_read_properties_ack(
          ObjectIdentifier.t(),
          [ReadPropertyAck.t() | ReadPropertyMultipleAck.t()],
          [cast_read_properties_ack_option()]
        ) ::
          {:ok,
           %{optional(Constants.property_identifier() | atom() | non_neg_integer()) => term()}}
          | {:error, {atom(), term()}}
          | {:error, term()}
  def cast_read_properties_ack(
        %ObjectIdentifier{type: type_mod} = obj_id,
        acks,
        opts \\ []
      )
      when is_list(acks) and is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "cast_read_properties_ack/3 expected a keyword list, got: #{inspect(opts)}"
    end

    case get_object_type_mappings()[type_mod] do
      nil ->
        {:error, :unsupported_object_type}

      object_mod ->
        unless_env(:prod, do: Code.ensure_loaded!(object_mod))

        fun_name = get_fa_str()
        allow_unknown_props = Keyword.get(opts, :allow_unknown_properties, false)
        ignore_array_indexes = get_bool_opts(opts, :ignore_array_indexes, fun_name, false)
        ignore_invalid_props = get_bool_opts(opts, :ignore_invalid_properties, fun_name, false)
        ignore_obj_err = get_bool_opts(opts, :ignore_object_identifier_mismatch, fun_name, false)
        ignore_unknown_props = get_bool_opts(opts, :ignore_unknown_properties, fun_name, false)

        internal_opts = %RPATransformOptions{
          allow_unknown_properties: allow_unknown_props,
          ignore_array_indexes: ignore_array_indexes,
          ignore_invalid_properties: ignore_invalid_props,
          ignore_object_identifier_mismatch: ignore_obj_err,
          ignore_unknown_properties: ignore_unknown_props
        }

        Enum.reduce_while(
          acks,
          {:ok, %{}},
          &do_process_read_props_ack(&1, &2, obj_id, object_mod, internal_opts)
        )
    end
  end

  @doc """
  Casts a property value to application tag `Encoding`.

  To cast the property from the proper data type, the correct object module needs to be known,
  which contains that property. The object module will tell us which data type should it be.
  As such, an object identifier is required. No validation happens on the data.

  Note: In prod environment, required modules are not explicitely loaded.

  The following options are available:
  - `allow_nil: boolean()` - Optional. Allows `nil` values (only useful for present value with write priority).
  - `allow_partial: boolean()` - Optional. Allows partial values of array or list properties (a single value).
  """
  @spec cast_value_to_property(
          ObjectIdentifier.t(),
          Constants.property_identifier(),
          term() | [term()],
          [cast_value_to_property_option()]
        ) :: {:ok, Encoding.t() | [Encoding.t()]} | {:error, {atom(), term()}} | {:error, term()}
  def cast_value_to_property(objectid, property_identifier, value, opts \\ [])

  def cast_value_to_property(
        %ObjectIdentifier{type: type_mod} = _object_id,
        property_identifier,
        value,
        opts
      )
      when is_atom(property_identifier) and is_list(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "cast_value_to_property/4 expected a keyword list, got: #{inspect(opts)}"
    end

    case get_object_type_mappings()[type_mod] do
      nil ->
        {:error, :unsupported_object_type}

      object_mod ->
        unless_env(:prod, do: Code.ensure_loaded!(object_mod))

        if function_exported?(object_mod, :get_properties_type_map, 0) do
          prop_type_map = object_mod.get_properties_type_map()

          case Map.fetch(prop_type_map, property_identifier) do
            {:ok, type} ->
              do_cast_value_to_property(
                object_mod,
                property_identifier,
                type,
                value,
                %{
                  allow_partial: get_bool_opts(opts, :allow_partial, get_fa_str(), false),
                  allow_nil: get_bool_opts(opts, :allow_nil, get_fa_str(), false),
                  original_property: property_identifier,
                  properties_type_map: prop_type_map
                }
              )

            :error ->
              {:error, {:unknown_property, property_identifier}}
          end
        else
          {:error, :invalid_object_module}
        end
    end
  end

  @doc """
  Turns the given object's properties with their values into a keyword list.
  Only properties in the properties list are taken. The `bacnet_object` contract is enforced.

  The key `:object_instance` will be converted into `:object_identifier`.

  The list is sorted in ascending order by the property name.
  """
  @spec to_list(bacnet_object()) :: [{Constants.property_identifier(), term()}]
  def to_list(%_bac{} = object) when is_object(object) do
    object
    |> to_map()
    |> Map.to_list()
    |> Enum.sort_by(&elem(&1, 0), :asc)
  end

  @doc """
  Turns the given object's properties with their values into a map.
  Only properties in the properties list are taken. The `bacnet_object` contract is enforced.

  The key `:object_instance` will be converted into `:object_identifier`.
  """
  @spec to_map(bacnet_object()) :: %{optional(Constants.property_identifier()) => term()}
  def to_map(%_bac{_metadata: %{properties_list: props}} = object) when is_object(object) do
    object
    |> Map.take(props)
    |> Map.drop([:_metadata, :object_instance])
    |> Map.put(:object_identifier, get_object_identifier(object))
  end

  @spec get_bool_opts(Keyword.t(), atom(), String.t(), boolean()) :: boolean() | no_return()
  defp get_bool_opts(opts, key, function_name, default)
       when is_list(opts) and is_atom(key) and is_binary(function_name) and is_boolean(default) do
    value = Keyword.get(opts, key, default)

    unless is_boolean(value) do
      raise ArgumentError,
            "#{function_name} expected `#{key}` to be a boolean, got: #{inspect(value)}"
    end

    value
  end

  @spec do_process_read_props_ack(
          ReadPropertyAck.t() | ReadPropertyMultipleAck.t(),
          {:ok, map()},
          ObjectIdentifier.t(),
          module(),
          RPATransformOptions.t()
        ) ::
          {:cont, {:ok, map()}} | {:halt, term()}
  defp do_process_read_props_ack(
         %ReadPropertyAck{} = ack,
         {:ok, acc},
         obj_id,
         object_mod,
         internal_opts
       ) do
    case process_make_property_from_read_prop_ack(
           obj_id,
           object_mod,
           ack,
           internal_opts
         ) do
      {:ok, props} -> {:cont, {:ok, Map.merge(acc, props)}}
      {:error, _err} = err -> {:halt, err}
    end
  end

  defp do_process_read_props_ack(
         %ReadPropertyMultipleAck{} = ack,
         {:ok, acc},
         obj_id,
         object_mod,
         internal_opts
       ) do
    case process_make_property_from_read_prop_multiple_ack(
           obj_id,
           object_mod,
           ack,
           internal_opts
         ) do
      {:ok, props} -> {:cont, {:ok, Map.merge(acc, props)}}
      {:error, _err} = err -> {:halt, err}
    end
  end

  defp do_process_read_props_ack(_else, _acc, _obj_id, _object_mod, _internal_opts),
    do: {:halt, {:error, :invalid_ack}}

  @spec process_make_property_from_read_prop_ack(
          ObjectIdentifier.t(),
          module(),
          ReadPropertyAck.t(),
          RPATransformOptions.t()
        ) ::
          {:ok, map()} | {:error, term()}
  defp process_make_property_from_read_prop_ack(object_id, object_mod, ack, opts)

  defp process_make_property_from_read_prop_ack(
         %ObjectIdentifier{} = object_id,
         _object_mod,
         %ReadPropertyAck{object_identifier: object_id2} = _ack,
         %RPATransformOptions{ignore_object_identifier_mismatch: ignore}
       )
       when object_id != object_id2 do
    if ignore do
      {:ok, %{}}
    else
      {:error, :object_identifier_mismatch}
    end
  end

  # Ignore specific set of property identifiers (we don't need them)
  defp process_make_property_from_read_prop_ack(
         _object_id,
         _object_mod,
         %ReadPropertyAck{property_identifier: id} = _ack,
         _opts
       )
       when id in [:object_type] do
    {:ok, %{}}
  end

  defp process_make_property_from_read_prop_ack(
         %ObjectIdentifier{} = _object_id,
         object_mod,
         %ReadPropertyAck{property_array_index: nil} = ack,
         %RPATransformOptions{
           allow_unknown_properties: allow_unknown_properties,
           ignore_invalid_properties: ignore_invalid_properties,
           ignore_unknown_properties: ignore_unknown_properties
         } = _opts
       ) do
    case process_make_property(
           object_mod,
           ack.property_identifier,
           ack.property_value,
           allow_unknown_properties: allow_unknown_properties
         ) do
      {:ok, value} ->
        {:ok, %{ack.property_identifier => value}}

      {:error, {:invalid_property_value, _prop}} when ignore_invalid_properties ->
        {:cont, {:ok, %{}}}

      {:error, {:unknown_property, _prop}} when allow_unknown_properties != false ->
        {:cont,
         {:ok,
          %{
            ack.property_identifier =>
              unpack_unknown_properties_if_primitive(ack.property_value, allow_unknown_properties)
          }}}

      {:error, {:unknown_property, _prop}} when ignore_unknown_properties ->
        {:cont, {:ok, %{}}}

      {:error, _err} = err ->
        {:halt, err}
    end
  end

  defp process_make_property_from_read_prop_ack(
         _object_id,
         _object_mod,
         _ack,
         %RPATransformOptions{
           ignore_array_indexes: true
         }
       ),
       do: {:ok, %{}}

  defp process_make_property_from_read_prop_ack(_object_id, _object_mod, _ack, _opts),
    do: {:error, :property_array_index_not_supported}

  @spec process_make_property_from_read_prop_multiple_ack(
          ObjectIdentifier.t(),
          module(),
          ReadPropertyMultipleAck.t(),
          RPATransformOptions.t()
        ) :: {:ok, map()} | {:error, term()}
  defp process_make_property_from_read_prop_multiple_ack(object_id, object_mod, ack, opts)

  defp process_make_property_from_read_prop_multiple_ack(
         %ObjectIdentifier{} = object_id,
         object_mod,
         %ReadPropertyMultipleAck{} = ack,
         %RPATransformOptions{
           allow_unknown_properties: allow_unknown_properties,
           ignore_array_indexes: ignore_array_indexes,
           ignore_invalid_properties: ignore_invalid_properties,
           ignore_object_identifier_mismatch: ignore_object_identifier_mismatch,
           ignore_unknown_properties: ignore_unknown_properties
         } = _opts
       ) do
    Enum.reduce_while(ack.results, {:ok, %{}}, fn
      %ReadAccessResult{object_identifier: r_object_id} = results, {:ok, acc}
      when ignore_object_identifier_mismatch or r_object_id == object_id ->
        res =
          Enum.reduce_while(results.results, {:ok, acc}, fn
            # Ignore errors or nil values
            %ReadAccessResult.ReadResult{error: err, property_value: val}, acc
            when err != nil or val == nil ->
              {:cont, acc}

            %ReadAccessResult.ReadResult{property_identifier: id} = result, {:ok, acc}
            when not is_atom(id) ->
              cond do
                allow_unknown_properties != false ->
                  {:cont,
                   {:ok,
                    Map.put(
                      acc,
                      id,
                      unpack_unknown_properties_if_primitive(
                        result.property_value,
                        allow_unknown_properties
                      )
                    )}}

                ignore_unknown_properties ->
                  {:cont, {:ok, acc}}

                true ->
                  {:halt, {:error, {:unknown_property, id}}}
              end

            %ReadAccessResult.ReadResult{property_identifier: id}, acc
            when id in [:object_type] ->
              {:cont, acc}

            %ReadAccessResult.ReadResult{property_array_index: arr} = result, {:ok, acc}
            when arr == nil or ignore_array_indexes ->
              case process_make_property(
                     object_mod,
                     result.property_identifier,
                     result.property_value,
                     allow_unknown_properties: allow_unknown_properties
                   ) do
                {:ok, value} ->
                  {:cont, {:ok, Map.put(acc, result.property_identifier, value)}}

                {:error, {:invalid_property_value, _prop}} when ignore_invalid_properties ->
                  {:cont, {:ok, acc}}

                {:error, {:unknown_property, _prop}} when ignore_unknown_properties ->
                  {:cont, {:ok, acc}}

                {:error, _err} = err ->
                  {:halt, err}
              end

            _results, {:ok, _acc} ->
              {:halt, {:error, :property_array_index_not_supported_1}}
          end)

        case res do
          {:ok, _val} = val -> {:cont, val}
          term -> {:halt, term}
        end

      _results, _acc ->
        {:halt, {:error, :object_identifier_mismatch}}
    end)
  end

  @spec process_make_property(
          module(),
          Constants.property_identifier(),
          Encoding.t() | [Encoding.t()],
          Keyword.t()
        ) ::
          {:ok, term()} | {:error, term()}
  defp process_make_property(object_mod, property_identifier, value, opts)

  # Handle this property independently from the object modules as they are not declaring it (we can just return the value as-is)
  defp process_make_property(
         _object_mod,
         Constants.macro_assert_name(:property_identifier, :object_identifier),
         %Encoding{value: %ObjectIdentifier{} = value},
         _opts
       ) do
    {:ok, value}
  end

  defp process_make_property(object_mod, property_identifier, value, opts) do
    if function_exported?(object_mod, :get_properties_type_map, 0) do
      prop_type_map = object_mod.get_properties_type_map()

      case Map.fetch(prop_type_map, property_identifier) do
        {:ok, type} ->
          allow_partial = opts[:allow_partial] || false

          annotations = object_mod.get_annotation(property_identifier)
          decoder = annotations[:decoder]

          decoder_result =
            cond do
              decoder == nil ->
                try do
                  # cast_value_to_type(
                  #   type |> IO.inspect(label: "type"),
                  #   property_identifier,
                  #   value |> IO.inspect(label: "value"),
                  #   %{allow_partial: allow_partial, properties_type_map: prop_type_map}
                  # ) |> IO.inspect(label: "prop #{property_identifier}")

                  cast_value_to_type(
                    type,
                    property_identifier,
                    value,
                    %{
                      allow_partial: allow_partial,
                      object_mod: object_mod,
                      properties_type_map: prop_type_map
                    }
                  )
                rescue
                  e -> {:error, {:exception_during_casting, e, __STACKTRACE__}}
                end

              is_list(value) ->
                res =
                  Enum.reduce_while(value, {:ok, []}, fn val, {:ok, acc} ->
                    case decode_property_value(type, decoder, property_identifier, val) do
                      {:ok, val} -> {:cont, {:ok, [val | acc]}}
                      term -> {:halt, term}
                    end
                  end)

                case res do
                  {:ok, list} -> {:ok, Enum.reverse(list)}
                  term -> term
                end

              true ->
                decode_property_value(type, decoder, property_identifier, value)
            end

          with {:ok, decoder_value} <- decoder_result do
            # If partials allowed and the value is not a list, extract the subtype
            check_type =
              if allow_partial and not is_list(value) do
                case type do
                  {:array, subtype} ->
                    subtype

                  {:array, subtype, _size} ->
                    subtype

                  {:list, subtype} ->
                    subtype

                  {:struct, PriorityArray} ->
                    {:type_list, [Map.fetch!(prop_type_map, :present_value), {:literal, nil}]}

                  term ->
                    term
                end
              else
                type
              end

            if BeamTypes.check_type(check_type, decoder_value) do
              {:ok, decoder_value}
            else
              {:error, {:invalid_property_value, {property_identifier, decoder_value}}}
            end
          else
            {:error, :invalid_tags} ->
              {:error, {:invalid_tags, {property_identifier, value}}}

            {:error, _err} = err ->
              err
          end

        :error ->
          if allow = opts[:allow_unknown_properties] do
            {:ok, unpack_unknown_properties_if_primitive(value, allow)}
          else
            {:error, {:unknown_property, property_identifier}}
          end
      end
    else
      {:error, :invalid_object_module}
    end
  end

  @spec decode_property_value(
          BeamTypes.typechecker_types(),
          (any() -> any()),
          Constants.property_identifier(),
          Encoding.t() | [Encoding.t()]
        ) :: {:ok, term()} | {:error, term()}
  defp decode_property_value(
         _type,
         decoder,
         _property_identifier,
         %Encoding{} = value
       )
       when is_function(decoder, 1) do
    try do
      case decoder.(value) do
        {:ok, _val} = val -> val
        {:error, _err} = err -> err
        term -> {:ok, term}
      end
    rescue
      e -> {:error, {:exception_during_decoding, e, __STACKTRACE__}}
    end
  end

  @spec do_cast_value_to_property(
          module(),
          Constants.property_identifier(),
          BeamTypes.typechecker_types(),
          term() | [term()],
          map()
        ) :: {:ok, Encoding.t() | [Encoding.t()]} | {:error, term()}
  defp do_cast_value_to_property(object_mod, property_identifier, type, value, opts) do
    annotations = object_mod.get_annotation(property_identifier)
    encoder = annotations[:encoder]
    encode_as = annotations[:encode_as]

    encoder_result =
      cond do
        encoder == nil && encode_as ->
          try do
            cast_value_to_encoding(
              encode_as,
              property_identifier,
              value,
              opts
            )
          rescue
            e -> {:error, {:exception_during_casting, e, __STACKTRACE__}}
          end

        encoder == nil ->
          try do
            cast_value_to_encoding(
              type,
              property_identifier,
              value,
              opts
            )
          rescue
            e -> {:error, {:exception_during_casting, e, __STACKTRACE__}}
          end

        is_list(value) ->
          res =
            Enum.reduce_while(value, {:ok, []}, fn val, {:ok, acc} ->
              case encode_property_value(type, encoder, property_identifier, val) do
                {:ok, val} -> {:cont, {:ok, [val | acc]}}
                term -> {:halt, term}
              end
            end)

          case res do
            {:ok, list} -> {:ok, Enum.reverse(list)}
            term -> term
          end

        true ->
          encode_property_value(type, encoder, property_identifier, value)
      end

    # Assert the resulting item is an Encoding struct (or a list of),
    # so we do post-processing here
    with {:ok, result} <- encoder_result do
      cond do
        is_list(result) ->
          with {:ok, list} <-
                 Enum.reduce_while(result, {:ok, []}, fn
                   %Encoding{} = item, {:ok, acc} ->
                     {:cont, {:ok, [item | acc]}}

                   item, {:ok, acc} ->
                     case Encoding.create(item) do
                       {:ok, enc} -> {:cont, {:ok, [enc | acc]}}
                       term -> {:halt, term}
                     end
                 end) do
            {:ok, Enum.reverse(list)}
          end

        is_struct(result, Encoding) ->
          encoder_result

        true ->
          Encoding.create(result)
      end
    end
  end

  @spec cast_value_to_type_manual(
          BeamTypes.typechecker_types(),
          Constants.property_identifier(),
          Encoding.t() | [Encoding.t()],
          map()
        ) :: {:ok, term()} | {:error, term()}
  defp cast_value_to_type_manual(type, _property, value, _opts) when is_list(value) do
    tags = Enum.map(value, &Encoding.to_encoding!/1)

    {is_array, mod, arr_size, unwrap} =
      case type do
        {:array, {:struct, mod}} -> {true, mod, false, false}
        {:array, {:struct, mod}, size} -> {true, mod, size, false}
        {:list, {:struct, mod}} -> {false, mod, false, false}
        {:struct, mod} -> {false, mod, false, true}
      end

    res =
      Enum.reduce_while(1..1_000_000, {:ok, {[], tags}}, fn _iter, {:ok, {acc, tags}} ->
        case mod.parse(tags) do
          {:ok, {struc, []}} -> {:halt, {:ok, {[struc | acc], []}}}
          {:ok, {struc, rest}} -> {:cont, {:ok, {[struc | acc], rest}}}
          term -> {:halt, term}
        end
      end)

    case res do
      {:ok, {[item], _rest}} when unwrap ->
        {:ok, item}

      {:ok, {list, _rest}} ->
        new_list = Enum.reverse(list)

        # Do post-processing here (check if needs to be array and do validation)
        if is_array do
          cond do
            arr_size == false ->
              {:ok, BACnetArray.from_list(new_list)}

            # Force enumeration, as count_until/2 for lists uses length/1 (whole list enumeration!)
            Enum.count_until(new_list, fn _val -> true end, arr_size + 1) == arr_size ->
              {:ok, BACnetArray.from_list(new_list, true)}

            true ->
              {:error, :bacnet_array_size_mismatch}
          end
        else
          {:ok, new_list}
        end

      term ->
        term
    end
  end

  # Handle these properties in a special way, so it works
  # This is because the property_value response contains multiple entries (a list),
  # so each item gets splitted into an Encoding struct, so we need to revert this here
  #
  # The process that handles these Read-Property(-Multiple)-Ack responses has no knowledge
  # about the context, so we could also add logic to the Ack modules to handle some
  # properties in a special way
  # (i.e. chunk in three items instead - however the Encoding struct can't handle lists)
  @manual_property_struct_decoding_list [
    :active_cov_subscriptions,
    :device_address_binding,
    :exception_schedule,
    :list_of_group_members,
    :list_of_object_property_references,
    :log_buffer,
    :manual_slave_address_binding,
    :recipient_list,
    :slave_address_binding,
    :time_synchronization_recipients
  ]

  @spec cast_value_to_type(
          BeamTypes.typechecker_types(),
          Constants.property_identifier(),
          Encoding.t() | [Encoding.t()],
          map()
        ) ::
          {:ok, term()} | {:error, term()}
  defp cast_value_to_type(type, property, value, opts)

  defp cast_value_to_type(type, property, [%Encoding{} | _tl] = value, opts)
       when property in @manual_property_struct_decoding_list do
    cast_value_to_type_manual(type, property, value, opts)
  end

  # The Group object's present value is a list of ReadAccessResult structs, so we need to handle this differently, too
  defp cast_value_to_type(
         type,
         :present_value = property,
         [%Encoding{} | _tl] = value,
         %{object_mod: ObjectTypes.Group} = opts
       ) do
    cast_value_to_type_manual(type, property, value, opts)
  end

  # Handle the priority array directly (partial response)
  defp cast_value_to_type(
         {:struct, PriorityArray},
         :priority_array,
         %Encoding{} = value,
         %{allow_partial: true} = opts
       ) do
    cast_value_to_type(
      get_in(opts, [:properties_type_map, :present_value]),
      :present_value,
      value,
      opts
    )
  end

  defp cast_value_to_type(
         {:struct, PriorityArray},
         :priority_array,
         %Encoding{} = value,
         %{allow_partial: false} = _opts
       ) do
    {:error, {:invalid_property_value, {:priority_array, value}}}
  end

  # Handle the priority array directly
  # and decode enumerated values for boolean present value
  defp cast_value_to_type({:struct, PriorityArray}, :priority_array, value, opts)
       when is_list(value) do
    pv_type = get_in(opts, [:properties_type_map, :present_value])
    is_boolean = pv_type == :boolean

    raw_values =
      Enum.map(value, fn
        %Encoding{type: :enumerated, value: value} when is_boolean and value in [0, 1] ->
          value == 1

        %Encoding{} = encoding ->
          encoding.value

        term ->
          term
      end)

    # Count the elements and make sure we have 16 elements
    if Enum.count_until(raw_values, fn _val -> true end, 17) == 16 or
         Enum.all?(raw_values, &(&1 == nil or BeamTypes.check_type(pv_type, &1))) do
      {:ok, PriorityArray.from_list(raw_values)}
    else
      {:error, {:invalid_property_value, {:priority_array, value}}}
    end
  end

  # Handle partial property value here (partial as we only read a specific index of an array and not the whole array)
  defp cast_value_to_type({:array, subtype}, property, value, %{allow_partial: true} = opts)
       when not is_list(value) do
    cast_value_to_type(subtype, property, value, %{opts | allow_partial: false})
  end

  # Handle partial property value here for sized arrays
  defp cast_value_to_type(
         {:array, subtype, _size},
         property,
         value,
         %{allow_partial: true} = opts
       )
       when not is_list(value) do
    cast_value_to_type(subtype, property, value, %{opts | allow_partial: false})
  end

  # Handle array struct subtypes differently
  defp cast_value_to_type({:array, {:struct, _sub} = subtype}, property, value, opts)
       when is_list(value) do
    with {:ok, values} <-
           Enum.reduce_while(value, {:ok, []}, fn item, {:ok, acc} ->
             case cast_value_to_type(subtype, property, item, opts) do
               {:ok, value} -> {:cont, {:ok, [value | acc]}}
               term -> {:halt, term}
             end
           end) do
      {:ok, BACnetArray.from_list(Enum.reverse(values))}
    else
      {:error, _err} = err -> err
    end
  end

  defp cast_value_to_type({:array, _subtype}, _property, value, _opts) when is_list(value) do
    {:ok, BACnetArray.from_list(Enum.map(value, & &1.value))}
  end

  # Handle array struct subtypes differently
  defp cast_value_to_type({:array, {:struct, _sub} = subtype, size}, property, value, opts)
       when is_integer(size) and is_list(value) do
    if Enum.count_until(value, size + 1) == size do
      with {:ok, values} <-
             Enum.reduce_while(value, {:ok, []}, fn item, {:ok, acc} ->
               case cast_value_to_type(subtype, property, item, opts) do
                 {:ok, value} -> {:cont, {:ok, [value | acc]}}
                 term -> {:halt, term}
               end
             end) do
        {:ok, BACnetArray.from_list(Enum.reverse(values), true)}
      else
        {:error, _err} = err -> err
      end
    else
      {:error, :bacnet_array_size_mismatch}
    end
  end

  defp cast_value_to_type({:array, _subtype, size}, property, value, _opts)
       when is_integer(size) and is_list(value) do
    if Enum.count_until(value, size + 1) == size do
      {:ok, BACnetArray.from_list(Enum.map(value, & &1.value), true)}
    else
      {:error, {:bacnet_array_size_mismatch, property}}
    end
  end

  defp cast_value_to_type({:array, _subtype, _size}, _property, value, _opts)
       when is_list(value) do
    {:ok, BACnetArray.from_list(Enum.map(value, & &1.value), true)}
  end

  # Handle boolean casts if value == 0 or == 1 directly (i.e. boolean properties are ENUMERATED)
  defp cast_value_to_type(:boolean, _property, %Encoding{type: :enumerated, value: value}, _opts)
       when value in [0, 1] do
    {:ok, value == 1}
  end

  defp cast_value_to_type({:constant, subtype}, property, %Encoding{value: value}, _opts) do
    case Constants.by_value(subtype, value) do
      {:ok, _val} = val -> val
      :error -> {:error, {:invalid_property_value, {property, value}}}
    end
  end

  # Handle partial property value here (partial as we only read a specific index of an array and not the whole array)
  defp cast_value_to_type({:list, subtype}, property, value, %{allow_partial: true} = opts)
       when not is_list(value) do
    cast_value_to_type(subtype, property, value, %{opts | allow_partial: false})
  end

  defp cast_value_to_type({:list, subtype}, property, value, opts) do
    with {:ok, values} <-
           Enum.reduce_while(List.wrap(value), {:ok, []}, fn item, {:ok, acc} ->
             case cast_value_to_type(subtype, property, item, opts) do
               {:ok, val} -> {:cont, {:ok, [val | acc]}}
               term -> {:halt, term}
             end
           end) do
      {:ok, Enum.reverse(values)}
    else
      {:error, _err} = err -> err
    end
  end

  defp cast_value_to_type({:struct, mod}, _property, value, _opts) do
    unless_env(:prod, do: Code.ensure_loaded!(mod))
    cast_value_struct_to_type(mod, value)
  end

  defp cast_value_to_type({:type_list, subtypes}, property, value, opts)
       when is_list(subtypes) do
    Enum.reduce_while(subtypes, {:error, {:invalid_property_value, {property, value}}}, fn
      subtype, {:error, _term} ->
        case cast_value_to_type(subtype, property, value, opts) do
          {:ok, val} -> {:halt, {:ok, val}}
          term -> {:cont, term}
        end

      _subtype, acc ->
        {:halt, acc}
    end)
  end

  defp cast_value_to_type(_type, _property, %Encoding{value: value}, _opts), do: {:ok, value}

  @compile {:inline, cast_value_struct_to_type: 2}
  @spec cast_value_struct_to_type(module(), Encoding.t() | [Encoding.t()]) ::
          {:ok, term()} | {:error, term()}
  defp cast_value_struct_to_type(mod, raw_value)

  defp cast_value_struct_to_type(Encoding, raw_value) do
    {:ok, raw_value}
  end

  defp cast_value_struct_to_type(mod, raw_value) do
    cond do
      function_exported?(mod, :from_app_encoding, 1) ->
        mod.from_app_encoding(raw_value)

      match?(%{type: :bitstring}, raw_value) and function_exported?(mod, :from_bitstring, 1) ->
        {:ok, mod.from_bitstring(raw_value.value)}

      function_exported?(mod, :parse, 1) ->
        raw_values =
          if is_list(raw_value) do
            Enum.map(raw_value, &Encoding.to_encoding!/1)
          else
            List.wrap(Encoding.to_encoding!(raw_value))
          end

        case mod.parse(raw_values) do
          {:ok, {val, _rest}} -> {:ok, val}
          term -> term
        end

      true ->
        {:error, {:missing_parse_fun, mod}}
    end
  end

  @spec encode_property_value(
          BeamTypes.typechecker_types(),
          (any() -> any()),
          Constants.property_identifier(),
          term()
        ) :: {:ok, Encoding.t() | [Encoding.t()] | term()} | {:error, term()}
  defp encode_property_value(
         _type,
         encoder,
         _property_identifier,
         value
       )
       when is_function(encoder, 1) do
    try do
      case encoder.(value) do
        {:ok, _val} = val -> val
        {:error, _err} = err -> err
        term -> {:ok, term}
      end
    rescue
      e -> {:error, {:exception_during_encoding, e, __STACKTRACE__}}
    end
  end

  @spec cast_value_to_encoding(
          BeamTypes.typechecker_types(),
          Constants.property_identifier(),
          term(),
          map()
        ) :: {:ok, Encoding.t() | [Encoding.t()] | term()} | {:error, term()}
  defp cast_value_to_encoding(type, property, value, opts)

  # Handle the priority array directly
  # and encode enumerated values for boolean present value
  defp cast_value_to_encoding(
         {:struct, PriorityArray},
         :priority_array,
         %PriorityArray{} = value,
         opts
       ) do
    pv_type = get_in(opts, [:properties_type_map, :present_value])
    is_boolean = pv_type == :boolean
    sub_opts = %{opts | allow_nil: true}

    with {:ok, values} <-
           Enum.reduce_while(PriorityArray.to_list(value), {:ok, []}, fn
             value, {:ok, acc} when is_boolean(value) and is_boolean ->
               {:cont, {:ok, [{:enumerated, if(value, do: 1, else: 0)} | acc]}}

             value, {:ok, acc} ->
               case cast_value_to_encoding(pv_type, :present_value, value, sub_opts) do
                 {:ok, enc} -> {:cont, {:ok, [enc | acc]}}
                 term -> {:halt, term}
               end
           end) do
      {:ok, Enum.reverse(values)}
    else
      {:error, _err} = err -> err
    end
  end

  # Handle partial property value here (partial as we only read a specific index of an array and not the whole array)
  defp cast_value_to_encoding({:array, subtype}, property, value, %{allow_partial: true} = opts)
       when not is_struct(value, BACnetArray) do
    cast_value_to_encoding(subtype, property, value, %{opts | allow_partial: false})
  end

  defp cast_value_to_encoding(
         {:array, _subtype},
         property,
         value,
         %{allow_partial: false} = _opts
       )
       when not is_struct(value, BACnetArray) do
    {:error, {:invalid_property_value, {property, value}}}
  end

  # Handle partial property value here for sized arrays
  defp cast_value_to_encoding(
         {:array, subtype, _size},
         property,
         value,
         %{allow_partial: true} = opts
       )
       when not is_struct(value, BACnetArray) do
    cast_value_to_encoding(subtype, property, value, %{opts | allow_partial: false})
  end

  defp cast_value_to_encoding(
         {:array, _subtype, _size},
         property,
         value,
         %{allow_partial: false} = _opts
       )
       when not is_struct(value, BACnetArray) do
    {:error, {:invalid_property_value, {property, value}}}
  end

  defp cast_value_to_encoding({:array, subtype}, property, %BACnetArray{} = array, opts) do
    with {:ok, values} <-
           BACnetArray.reduce_while(array, {:ok, []}, fn item, {:ok, acc} ->
             case cast_value_to_encoding(subtype, property, item, opts) do
               {:ok, value} -> {:cont, {:ok, [value | acc]}}
               term -> {:halt, term}
             end
           end) do
      {:ok, Enum.reverse(values)}
    else
      {:error, _err} = err -> err
    end
  end

  defp cast_value_to_encoding({:array, _subtype}, property, value, _opts) do
    {:error, {:invalid_property_value, {property, value}}}
  end

  defp cast_value_to_encoding({:array, subtype, size}, property, %BACnetArray{} = array, opts)
       when is_integer(size) do
    if BACnetArray.size(array) == size do
      cast_value_to_encoding({:array, subtype}, property, array, opts)
    else
      {:error, {:bacnet_array_size_mismatch, property}}
    end
  end

  defp cast_value_to_encoding({:array, _subtype, _size}, property, value, _opts) do
    {:error, {:invalid_property_value, {property, value}}}
  end

  defp cast_value_to_encoding({:constant, subtype}, property, value, _opts) when is_atom(value) do
    case Constants.by_name(subtype, value) do
      {:ok, val} -> {:ok, {:enumerated, val}}
      :error -> {:error, {:invalid_property_value, {property, value}}}
    end
  end

  defp cast_value_to_encoding({:constant, _subtype}, _property, value, _opts)
       when is_integer(value) and value >= 0 do
    {:ok, {:enumerated, value}}
  end

  # Handle partial property value here (partial as we only read a specific index of an array and not the whole array)
  defp cast_value_to_encoding({:list, subtype}, property, value, %{allow_partial: true} = opts)
       when not is_list(value) do
    cast_value_to_encoding(subtype, property, value, %{opts | allow_partial: false})
  end

  defp cast_value_to_encoding({:list, _subtype}, property, value, %{allow_partial: false} = _opts)
       when not is_list(value) do
    {:error, {:invalid_property_value, {property, value}}}
  end

  defp cast_value_to_encoding({:list, subtype}, property, value, opts) do
    with {:ok, values} <-
           Enum.reduce_while(List.wrap(value), {:ok, []}, fn item, {:ok, acc} ->
             case cast_value_to_encoding(subtype, property, item, opts) do
               {:ok, val} -> {:cont, {:ok, [val | acc]}}
               term -> {:halt, term}
             end
           end) do
      new_values =
        values
        |> Enum.reverse()
        |> List.flatten()

      {:ok, new_values}
    else
      {:error, _err} = err -> err
    end
  end

  defp cast_value_to_encoding({:struct, mod}, property, value, _opts) do
    unless_env(:prod, do: Code.ensure_loaded!(mod))

    try do
      is_struct(value, mod) and (not function_exported?(mod, :valid?, 1) or mod.valid?(value))
    catch
      _kind, _err -> {:error, {:invalid_property_value, {property, value}}}
    else
      true -> cast_value_struct_to_encoding(mod, value)
      false -> {:error, {:invalid_property_value, {property, value}}}
    end
  end

  defp cast_value_to_encoding({:type_list, subtypes}, property, value, opts)
       when is_list(subtypes) do
    Enum.reduce_while(subtypes, {:error, {:invalid_property_value, {property, value}}}, fn
      subtype, {:error, _term} ->
        case cast_value_to_type(subtype, property, value, opts) do
          {:ok, val} -> {:halt, {:ok, val}}
          term -> {:cont, term}
        end

      _subtype, acc ->
        {:halt, acc}
    end)
  end

  # Handle basic types here

  defp cast_value_to_encoding({:literal, nil}, _property, nil, _opts) do
    {:ok, {:null, nil}}
  end

  defp cast_value_to_encoding(:boolean, _property, value, _opts) when is_boolean(value) do
    {:ok, {:boolean, value}}
  end

  defp cast_value_to_encoding(:enumerated, _property, value, _opts) when is_boolean(value) do
    {:ok, {:enumerated, if(value, do: 1, else: 0)}}
  end

  defp cast_value_to_encoding(:string, property, value, _opts) when is_binary(value) do
    if String.valid?(value) do
      {:ok, {:character_string, value}}
    else
      {:error, {:invalid_string_value, property}}
    end
  end

  defp cast_value_to_encoding(:octet_string, _property, value, _opts) when is_binary(value) do
    {:ok, {:octet_string, value}}
  end

  defp cast_value_to_encoding(:signed_integer, _property, value, _opts) when is_integer(value) do
    {:ok, {:signed_integer, value}}
  end

  defp cast_value_to_encoding(:unsigned_integer, _property, value, _opts)
       when is_integer(value) and value >= 0 do
    {:ok, {:unsigned_integer, value}}
  end

  defp cast_value_to_encoding(:real, _property, value, _opts) when is_float(value) do
    {:ok, {:real, value}}
  end

  defp cast_value_to_encoding(:real, _property, value, _opts) when value in [:NaN, :inf, :infn] do
    {:ok, {:real, value}}
  end

  defp cast_value_to_encoding(:real, _property, value, _opts) when is_integer(value) do
    {:ok, {:real, value * 1.0}}
  end

  defp cast_value_to_encoding(:double, _property, value, _opts) when is_float(value) do
    {:ok, {:double, value}}
  end

  defp cast_value_to_encoding(:double, _property, value, _opts)
       when value in [:NaN, :inf, :infn] do
    {:ok, {:double, value}}
  end

  defp cast_value_to_encoding(:double, _property, value, _opts) when is_integer(value) do
    {:ok, {:double, value * 1.0}}
  end

  defp cast_value_to_encoding(:bitstring, _property, value, _opts) when is_tuple(value) do
    {:ok, {:bitstring, value}}
  end

  defp cast_value_to_encoding({:in_range, x, y}, _property, value, _opts)
       when is_integer(value) and value >= x and value <= y and x < 0 do
    {:ok, {:signed_integer, value}}
  end

  defp cast_value_to_encoding({:in_range, x, y}, _property, value, _opts)
       when is_integer(value) and value >= x and value <= y do
    {:ok, {:unsigned_integer, value}}
  end

  defp cast_value_to_encoding(_type, _property, nil, %{allow_nil: true} = _opts),
    do: {:ok, {:null, nil}}

  defp cast_value_to_encoding(_type, property, value, opts),
    do: {:error, {:invalid_property_value, {opts[:original_property] || property, value}}}

  @compile {:inline, cast_value_struct_to_encoding: 2}
  @spec cast_value_struct_to_encoding(module(), term()) ::
          {:ok, Encoding.t() | [Encoding.t()] | term()} | {:error, term()}
  defp cast_value_struct_to_encoding(mod, value)

  defp cast_value_struct_to_encoding(_mod, %Encoding{} = value) do
    {:ok, value}
  end

  defp cast_value_struct_to_encoding(mod, value) do
    cond do
      function_exported?(mod, :to_app_encoding, 1) ->
        mod.to_app_encoding(value)

      function_exported?(mod, :to_bitstring, 1) ->
        {:ok, mod.to_bitstring(value)}

      function_exported?(mod, :encode, 1) ->
        mod.encode(value)

      true ->
        {:error, {:missing_encode_fun, mod}}
    end
  end

  @spec unpack_unknown_properties_if_primitive(Encoding.t() | term(), boolean() | :no_unpack) ::
          term()
  defp unpack_unknown_properties_if_primitive(value, opt)

  defp unpack_unknown_properties_if_primitive(value, :no_unpack), do: value

  defp unpack_unknown_properties_if_primitive(
         %Encoding{encoding: :primitive, type: _type, value: value} = _enc,
         _opt
       ),
       # when type not in [:real, :double],
       do: value

  defp unpack_unknown_properties_if_primitive(value, _opt), do: value
end
