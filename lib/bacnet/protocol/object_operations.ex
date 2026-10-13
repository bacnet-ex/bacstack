defmodule BACnet.Protocol.ObjectOperations do
  @moduledoc """
  Shared operations for BACnet object structs.

  `BACnet.Protocol.ObjectsMacro` used to copy these functions into every object
  module. Object modules now delegate here and pass an `BACnet.Protocol.ObjectsContract`
  plus hook functions for the overridable steps (`add_defaults/2`,
  `check_implicit_relationships/2`, `inhibit_object_check/1`).

  Nothing in this module runs as a process. The functions are pure aside from
  the hooks the caller supplies.

  `create/6` calls the hooks. `add_defaults/3` and `check_implicit_relationships/3`
  do not, so an object module can call them from `super` without looping.
  """

  alias BACnet.BeamTypes
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.ObjectsContract
  alias BACnet.Protocol.PriorityArray

  require Constants

  @typedoc """
  Object metadata stored under `_metadata`.
  """
  @type metadata :: %{
          properties_list: [atom()],
          revision: non_neg_integer(),
          intrinsic_reporting: boolean(),
          remote_object: non_neg_integer() | true | nil,
          physical_input: boolean() | nil,
          other: map()
        }

  @typedoc """
  Overridable steps. Object modules pass captures of their own functions.
  """
  @type operation_hooks :: %{
          add_defaults: (map(), metadata() -> map() | {:error, term()}),
          check_implicit_relationships: (struct(), :add | :remove ->
                                           {:ok, struct()} | {:error, term()}),
          inhibit_object_check: (struct() -> {:ok, struct()} | {:error, term()})
        }

  @typedoc """
  Result of a mutating object operation.
  """
  @type update_result :: {:ok, struct()} | {:error, term()}

  @doc """
  Creates an object struct from an instance number, name, properties, and options.

  `hooks.add_defaults/2` runs instead of `add_defaults/3` directly.
  For a local object, `hooks.inhibit_object_check/1` runs after property propagation.
  Remote objects skip propagation and the inhibit hook.
  """
  @spec create(
          ObjectsContract.t(),
          non_neg_integer(),
          String.t(),
          map(),
          keyword(),
          operation_hooks()
        ) :: update_result() | no_return()
  def create(%ObjectsContract{} = contract, instance_number, object_name, properties, opts, hooks)
      when is_integer(instance_number) and is_binary(object_name) and is_map(properties) and
             instance_number >= 0 and
             instance_number < Constants.macro_by_name(:asn1, :max_instance_and_property_id) and
             is_list(opts) and is_map(hooks) do
    with :ok <- check_printable_object_name(object_name),
         {:ok, {props, unknown_props, _needs_recheck}} <-
           Enum.reduce_while(properties, {:ok, {%{}, %{}, false}}, fn item, acc ->
             process_property(contract, item, acc, opts)
           end),
         metadata = create_metadata_from_opts(contract, opts),
         props when is_map(props) <- hooks.add_defaults.(props, metadata),
         props = Map.put(props, :object_name, object_name),
         props = Map.put(props, :object_instance, instance_number),
         new_metadata = %{metadata | properties_list: Map.keys(props)},
         props = Map.put(props, :_metadata, new_metadata),
         props = Map.put(props, :_unknown_properties, unknown_props),
         {:ok, obj} <-
           hooks.check_implicit_relationships.(struct(contract.object_module, props), :add),
         obj = sync_commandable_present_value(obj),
         :ok <- recheck_property_values(contract, props, opts),
         {:ok, obj} <- verify_properties(contract, obj, new_metadata) do
      case obj._metadata.remote_object do
        nil -> hooks.inhibit_object_check.(propagate_properties(contract, obj))
        _remote -> {:ok, obj}
      end
    else
      {:ok, _val} ->
        raise "Invalid return value from add_defaults/2, we got an ok-tuple"

      term ->
        term
    end
  end

  @doc """
  Adds an optional property.

  Remote objects are rejected. Intrinsic properties cannot be added.
  On success, runs implicit relationships, propagation, and the inhibit hook.
  """
  @spec add_property(ObjectsContract.t(), struct(), atom(), term(), operation_hooks()) ::
          update_result()
  def add_property(
        %ObjectsContract{} = _contract,
        %{_metadata: %{remote_object: remote}} = _object,
        _property,
        _value,
        _hooks
      )
      when is_integer(remote) or remote == true do
    {:error, :operation_not_available_for_remote_objects}
  end

  def add_property(%ObjectsContract{} = contract, object, property, value, hooks)
      when is_atom(property) and is_map(hooks) do
    with :ok <- known_property(contract, property),
         :ok <- property_absent(object, property),
         :ok <- intrinsic_property_rejected_on_add(contract, property),
         :ok <- check_property_value(contract, object, property, value, true, false) do
      new_object = %{
        object
        | _metadata: %{
            object._metadata
            | properties_list: [property | object._metadata.properties_list]
          }
      }

      case hooks.check_implicit_relationships.(Map.put(new_object, property, value), :add) do
        {:ok, obj} ->
          hooks.inhibit_object_check.(propagate_properties(contract, obj))

        other ->
          other
      end
    end
  end

  @doc """
  Removes an optional property. Removing a property that is not present succeeds.

  Remote objects are rejected. Unknown numeric keys are dropped from
  `_unknown_properties` and do not run hooks.
  """
  @spec remove_property(
          ObjectsContract.t(),
          struct(),
          atom() | non_neg_integer(),
          operation_hooks()
        ) ::
          update_result()
  def remove_property(
        %ObjectsContract{} = _contract,
        %{_metadata: %{remote_object: remote}} = _object,
        _property,
        _hooks
      )
      when is_integer(remote) or remote == true do
    {:error, :operation_not_available_for_remote_objects}
  end

  def remove_property(%ObjectsContract{} = contract, object, property, hooks)
      when is_atom(property) and is_map(hooks) do
    with :ok <- check_property_exists(object, property),
         :ok <- check_property_allowed_remove(contract, object, property) do
      new_object = %{
        object
        | _metadata: %{
            object._metadata
            | properties_list: List.delete(object._metadata.properties_list, property)
          }
      }

      new_object
      |> Map.put(property, nil)
      |> hooks.check_implicit_relationships.(:remove)
      |> case do
        {:ok, obj} -> hooks.inhibit_object_check.(obj)
        other -> other
      end
    else
      {:error, {:unknown_property, _property}} -> {:ok, object}
      term -> term
    end
  end

  def remove_property(%ObjectsContract{} = _contract, object, property, _hooks)
      when is_integer(property) and property >= 0 do
    {:ok, %{object | _unknown_properties: Map.delete(object._unknown_properties, property)}}
  end

  @doc """
  Updates a property that is already present.

  Remote objects skip the intrinsic-property check. Propagation and the inhibit
  hook still run. Commandable `present_value` writes are rejected.
  """
  @spec update_property(ObjectsContract.t(), struct(), atom(), term(), operation_hooks()) ::
          update_result()
  def update_property(%ObjectsContract{} = contract, object, property, value, hooks)
      when is_atom(property) and is_map(hooks) do
    with :ok <- check_property_exists(object, property),
         :ok <- prevent_commandable_objects_write_pv(object, property),
         :ok <- maybe_check_intrinsic(contract, object, property, value),
         :ok <- check_property_value(contract, object, property, value, true, false) do
      object
      |> Map.put(property, value)
      |> then(&propagate_properties(contract, &1))
      |> hooks.inhibit_object_check.()
    end
  end

  @doc """
  Writes one slot of the priority array and refreshes `present_value`.

  A `nil` value clears the slot and is not type-checked. Feedback is copied
  from the present value when `auto_write_feedback` is set. This does not run
  the inhibit hook.
  """
  @spec set_priority(ObjectsContract.t(), struct(), 1..16, term()) :: update_result()
  def set_priority(
        %ObjectsContract{} = _contract,
        %{priority_array: nil} = _object,
        priority,
        _value
      )
      when priority in 1..16 do
    {:error, {:unknown_property, :priority_array}}
  end

  def set_priority(
        %ObjectsContract{} = contract,
        %{priority_array: %PriorityArray{} = prio_array} = object,
        priority,
        value
      )
      when priority in 1..16 do
    pv_check =
      if value == nil do
        :ok
      else
        check_property_value(contract, object, :present_value, value, true, false)
      end

    case pv_check do
      :ok ->
        new_prio = Map.put(prio_array, PriorityArray.int_to_atom(priority), value)

        present_value =
          case PriorityArray.get_value(new_prio) do
            {_prio, slot_value} -> slot_value
            nil -> object.relinquish_default
          end

        new_object = %{object | priority_array: new_prio, present_value: present_value}
        {:ok, maybe_write_feedback(contract, object, new_object)}

      {:error, {key, :present_value}} ->
        {:error, {key, :priority_array}}

      term ->
        term
    end
  end

  @doc """
  Returns whether `property` is writable for the default object policy.

  `readonly` is the object type's readonly property list. Object-specific
  overrides stay on the object module and are not consulted here.
  """
  @spec property_writable?(struct(), atom(), [atom()]) :: boolean()
  def property_writable?(object, property, readonly)
      when is_atom(property) and is_list(readonly) do
    if property_in_list?(object, property) do
      case property do
        :event_algorithm_inhibit ->
          writable_event_algorithm_inhibit?(object)

        :present_value ->
          writable_present_value?(object)

        _term ->
          not Enum.member?(readonly, property)
      end
    else
      false
    end
  end

  @doc """
  Reads a property. Numeric keys are read from `_unknown_properties`.
  """
  @spec get_property(struct(), atom() | non_neg_integer()) :: {:ok, term()} | {:error, term()}
  def get_property(object, property) when is_atom(property) do
    with :ok <- check_property_exists(object, property),
         {:ok, value} <- Map.fetch(object, property) do
      {:ok, value}
    else
      :error ->
        {:error, {:unknown_property_identifier, property}}

      term ->
        term
    end
  end

  def get_property(object, property) when is_integer(property) and property >= 0 do
    case Map.fetch(object._unknown_properties, property) do
      {:ok, _val} = val -> val
      :error -> {:error, {:unknown_property_identifier, property}}
    end
  end

  @doc """
  Returns `:ok` when `property` is in the object's properties list.
  """
  @spec check_property_exists(map(), atom()) :: :ok | {:error, {:unknown_property, atom()}}
  def check_property_exists(%{_metadata: %{properties_list: properties}}, property) do
    if property in properties do
      :ok
    else
      {:error, {:unknown_property, property}}
    end
  end

  @doc """
  Rejects writes of `present_value` while a priority array is present.
  """
  @spec prevent_commandable_objects_write_pv(map(), atom()) ::
          :ok | {:error, {:protected_property, :present_value}}
  def prevent_commandable_objects_write_pv(
        %{priority_array: %PriorityArray{} = _pa},
        :present_value
      ) do
    {:error, {:protected_property, :present_value}}
  end

  def prevent_commandable_objects_write_pv(_object, _property), do: :ok

  @doc """
  Merges compile-time defaults into `properties`.

  Local objects receive required defaults, intrinsic defaults, `cov_increment`,
  and `init_fun` properties. Remote objects receive only `remote_defaults`.
  This function does not call hooks.
  """
  @spec add_defaults(ObjectsContract.t(), map(), metadata()) :: map()
  def add_defaults(%ObjectsContract{} = contract, properties, metadata) when is_map(properties) do
    if metadata.remote_object == nil do
      props = Map.merge(contract.default_properties, properties)
      props = maybe_put_relinquish_default(contract, props)
      props = maybe_put_cov_increment(contract, props)
      props = maybe_merge_intrinsic_defaults(contract, props, metadata)

      Enum.reduce(contract.init_funs, props, fn {name, init_fun}, acc ->
        Map.put_new_lazy(acc, name, init_fun)
      end)
    else
      Map.merge(contract.remote_defaults, properties)
    end
  end

  @doc """
  Adds or removes the partner of an implicit relationship.

  Does not call hooks.
  """
  @spec check_implicit_relationships(ObjectsContract.t(), struct(), :add | :remove) ::
          update_result()
  def check_implicit_relationships(%ObjectsContract{} = contract, object, operation)
      when operation in [:add, :remove] do
    Enum.reduce_while(contract.implicit_relationships, {:ok, object}, fn {prop, relat},
                                                                         {:ok, acc} ->
      align_relationship(contract, object, acc, prop, relat, operation)
    end)
  end

  @doc """
  Updates present value, feedback, and status flags from related properties.

  Which updates run depends on the contract's capability flags.
  """
  @spec propagate_properties(ObjectsContract.t(), struct()) :: struct()
  def propagate_properties(%ObjectsContract{} = contract, object) do
    object
    |> sync_priority_present_value(contract)
    |> sync_feedback(contract)
    |> sync_in_alarm(contract)
    |> sync_fault(contract)
    |> sync_out_of_service(contract)
  end

  @doc """
  Checks required properties, `required_when`, and `only_when`.

  Remote objects only check required properties and their protocol revision.
  """
  @spec verify_properties(ObjectsContract.t(), map(), metadata()) ::
          {:ok, map()} | {:error, term()}
  def verify_properties(%ObjectsContract{} = contract, properties, metadata) do
    with :ok <- verify_required_properties(contract, properties, metadata) do
      if metadata.remote_object do
        {:ok, properties}
      else
        with {:ok, properties} <-
               verify_properties_with_required_when(contract, properties, metadata) do
          verify_properties_with_only_when(contract, properties, metadata)
        end
      end
    end
  end

  @doc """
  Type-checks `value` for `property` and runs validators unless skipped.

  `skip_property_validator` is `true` (skip type and validators), `:value`
  (type only), or `false`.
  """
  @spec check_property_value(
          ObjectsContract.t(),
          map(),
          atom(),
          term(),
          boolean(),
          boolean() | :value
        ) :: :ok | {:error, term()}
  def check_property_value(
        %ObjectsContract{has_priority_array: true} = contract,
        object,
        :priority_array,
        %PriorityArray{} = value,
        check_protected,
        skip_property_validator
      ) do
    value
    |> Map.from_struct()
    |> Enum.reduce_while(:ok, fn {_key, val}, acc ->
      if val == nil do
        {:cont, acc}
      else
        case check_property_value(
               contract,
               object,
               :present_value,
               val,
               check_protected,
               skip_property_validator
             ) do
          :ok -> {:cont, acc}
          {:error, {term, _prop}} -> {:halt, {:error, {term, :priority_array}}}
        end
      end
    end)
  end

  def check_property_value(
        %ObjectsContract{} = contract,
        object,
        property,
        value,
        check_protected,
        skip_property_validator
      ) do
    case Map.fetch(contract.type_map, property) do
      :error ->
        {:error, {:unknown_type_for_property, property}}

      {:ok, type} ->
        cond do
          check_protected and property in contract.protected ->
            {:error, {:protected_property, property}}

          skip_property_validator == true ->
            :ok

          object._metadata.other[:allow_numeric_constants] == true and
            match?({:constant, _type}, type) and is_integer(value) and value >= 0 ->
            :ok

          BeamTypes.check_type(type, value) ->
            validate_property_value(
              contract,
              object,
              property,
              value,
              type,
              skip_property_validator
            )

          :invalid_type ->
            {:error, {:invalid_property_type, property}}
        end
    end
  end

  @doc """
  Rejects intrinsic properties when intrinsic reporting is off, and rejects
  `nil` intrinsic values when `allow_prop_nil` is false.
  """
  @spec check_property_intrinsic(ObjectsContract.t(), boolean(), atom(), term(), boolean()) ::
          :ok | {:error, term()}
  def check_property_intrinsic(
        %ObjectsContract{} = contract,
        intrinsic?,
        property,
        value,
        allow_nil
      )
      when is_boolean(intrinsic?) and is_boolean(allow_nil) do
    if not intrinsic? and property in contract.intrinsic do
      {:error, {:intrinsic_property_not_available, property}}
    else
      if intrinsic? and value == nil and not allow_nil do
        {:error, {:intrinsic_property_is_nil, property}}
      else
        :ok
      end
    end
  end

  @doc """
  Builds `_metadata` from create options.

  Raises `ArgumentError` when intrinsic reporting is requested for a type
  that does not support it.
  """
  @spec create_metadata_from_opts(ObjectsContract.t(), keyword()) :: metadata()
  def create_metadata_from_opts(%ObjectsContract{} = contract, opts) when is_list(opts) do
    default_physical = if contract.has_physical_input, do: false, else: nil

    metadata = %{
      properties_list: [],
      revision:
        Constants.by_name!(
          :protocol_revision,
          Keyword.get(opts, :revision, Constants.macro_by_name(:protocol_revision, :default))
        ),
      intrinsic_reporting: truthy?(Keyword.get(opts, :intrinsic_reporting, false)),
      remote_object: Keyword.get(opts, :remote_object, nil),
      physical_input:
        case Keyword.get(opts, :physical_input, default_physical) do
          nil -> nil
          term -> truthy?(term)
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

    if not contract.supports_intrinsic and metadata.intrinsic_reporting do
      raise ArgumentError, "Object does not support intrinsic reporting"
    end

    metadata
  end

  @doc """
  Inspects an object the way object modules do.

  An empty properties list prints the whole struct. Otherwise only the
  properties list and `_unknown_properties` are printed.
  """
  @spec inspect_object(struct(), Inspect.Opts.t()) :: Inspect.Algebra.t()
  def inspect_object(object, opts) do
    name = String.replace(Atom.to_string(object.__struct__), "Elixir.", "")

    list =
      if object._metadata.properties_list == [] do
        object
      else
        object
        |> Map.take([:_unknown_properties | object._metadata.properties_list])
        |> Map.to_list()
        |> Enum.sort_by(&inspect_sort_key/1)
      end

    fun =
      if Inspect.List.keyword?(list) do
        &Inspect.List.keyword/2
      else
        sep = Inspect.Algebra.color(" => ", :map, opts)
        &to_assoc(&1, &2, sep)
      end

    map_container_doc(list, name, opts, fun)
  end

  @spec process_property(
          ObjectsContract.t(),
          {term(), term()},
          {:ok, {map(), map(), boolean()}},
          keyword()
        ) ::
          {:cont, {:ok, {map(), map(), boolean()}}} | {:halt, {:error, term()}}
  defp process_property(_contract, {_prop, nil}, acc, _opts), do: {:cont, acc}

  defp process_property(contract, {prop, val}, {:ok, {acc, unknown_acc, flag}}, opts) do
    allow_unknown = Keyword.get(opts, :allow_unknown_properties, false)
    skip_unknown = Keyword.get(opts, :ignore_unknown_properties, false)
    is_remote_object = truthy?(opts[:remote_object])

    with :ok <-
           check_property_exists(%{_metadata: %{properties_list: contract.properties}}, prop),
         {:ok, _needs_recheck} <- aggregate_property_check(contract, acc, prop, val),
         :ok <- aggregate_intrinsic_check(contract, opts, prop, val, is_remote_object) do
      needs_recheck = true
      {:cont, {:ok, {Map.put(acc, prop, val), unknown_acc, flag or needs_recheck}}}
    else
      {:error, {:unknown_property, ^prop}}
      when allow_unknown and
             ((is_remote_object and is_atom(prop)) or (is_integer(prop) and prop >= 0)) ->
        {:cont, {:ok, {acc, Map.put(unknown_acc, prop, val), flag}}}

      {:error, {:unknown_property, _prop}} when skip_unknown ->
        {:cont, {:ok, {acc, unknown_acc, flag}}}

      {:error, _err} = err ->
        {:halt, err}
    end
  end

  @spec aggregate_property_check(ObjectsContract.t(), map(), atom(), term()) ::
          {:ok, boolean()} | {:error, term()}
  defp aggregate_property_check(contract, acc, prop, val) do
    case check_property_value(contract, acc, prop, val, true, true) do
      :ok -> {:ok, false}
      {:error, {:value_failed_property_validation, _property}} -> {:ok, true}
      term -> term
    end
  end

  @spec aggregate_intrinsic_check(ObjectsContract.t(), keyword(), atom(), term(), boolean()) ::
          :ok | {:error, term()}
  defp aggregate_intrinsic_check(contract, opts, prop, val, remote?) do
    if remote? do
      :ok
    else
      check_property_intrinsic(
        contract,
        Keyword.get(opts, :intrinsic_reporting, false) == true,
        prop,
        val,
        false
      )
    end
  end

  @spec recheck_property_values(ObjectsContract.t(), map(), keyword()) :: :ok | {:error, term()}
  defp recheck_property_values(contract, props, opts) do
    remote_skip =
      if opts[:remote_object] do
        opts[:skip_property_validation_remote_object]
      else
        false
      end

    Enum.reduce_while(props, :ok, fn
      {:_metadata, _value}, _acc ->
        {:cont, :ok}

      {:_unknown_properties, _value}, _acc ->
        {:cont, :ok}

      {:present_value, _value}, _acc
      when :erlang.is_map_key(:relinquish_default, props) and
             :erlang.map_get(:relinquish_default, props) != nil ->
        {:cont, :ok}

      {property, value}, _acc ->
        case check_property_value(contract, props, property, value, false, remote_skip) do
          :ok -> {:cont, :ok}
          term -> {:halt, term}
        end
    end)
  end

  @spec sync_commandable_present_value(struct()) :: struct()
  defp sync_commandable_present_value(obj) do
    if match?(%{priority_array: %PriorityArray{}}, obj) do
      pv =
        case PriorityArray.get_value(obj.priority_array) do
          nil -> obj.relinquish_default
          {_prio, value} -> value
        end

      %{obj | present_value: pv}
    else
      obj
    end
  end

  @spec known_property(ObjectsContract.t(), atom()) :: :ok | {:error, {:unknown_property, atom()}}
  defp known_property(contract, property) do
    if property in contract.properties do
      :ok
    else
      {:error, {:unknown_property, property}}
    end
  end

  @spec property_absent(struct(), atom()) :: :ok | {:error, {:property_already_exists, atom()}}
  defp property_absent(object, property) do
    case check_property_exists(object, property) do
      :ok -> {:error, {:property_already_exists, property}}
      _term -> :ok
    end
  end

  @spec intrinsic_property_rejected_on_add(ObjectsContract.t(), atom()) ::
          :ok | {:error, {:intrinsic_property_not_allowed, atom()}}
  defp intrinsic_property_rejected_on_add(contract, property) do
    if property in contract.intrinsic do
      {:error, {:intrinsic_property_not_allowed, property}}
    else
      :ok
    end
  end

  @spec maybe_check_intrinsic(ObjectsContract.t(), struct(), atom(), term()) ::
          :ok | {:error, term()}
  defp maybe_check_intrinsic(_contract, %{_metadata: %{remote_object: remote}}, _property, _value)
       when is_integer(remote) or remote == true do
    :ok
  end

  defp maybe_check_intrinsic(contract, object, property, value) do
    check_property_intrinsic(
      contract,
      contract.supports_intrinsic and object._metadata.intrinsic_reporting,
      property,
      value,
      false
    )
  end

  @spec maybe_put_relinquish_default(ObjectsContract.t(), map()) :: map()
  defp maybe_put_relinquish_default(%{has_min_max_present_value: true}, props) do
    if Map.get(props, :priority_array) && Map.get(props, :min_present_value) &&
         Map.get(props, :max_present_value) do
      Map.put_new_lazy(props, :relinquish_default, fn ->
        Map.get(props, :min_present_value)
      end)
    else
      props
    end
  end

  defp maybe_put_relinquish_default(_contract, props), do: props

  @spec maybe_put_cov_increment(ObjectsContract.t(), map()) :: map()
  defp maybe_put_cov_increment(%{default_cov_increment: nil}, props), do: props

  defp maybe_put_cov_increment(contract, props) do
    Map.put_new(props, :cov_increment, contract.default_cov_increment)
  end

  @spec maybe_merge_intrinsic_defaults(ObjectsContract.t(), map(), metadata()) :: map()
  defp maybe_merge_intrinsic_defaults(contract, props, metadata) do
    if contract.supports_intrinsic and metadata.intrinsic_reporting do
      Map.merge(contract.default_intrinsic, props)
    else
      props
    end
  end

  @spec align_relationship(
          ObjectsContract.t(),
          struct(),
          struct(),
          atom(),
          atom(),
          :add | :remove
        ) :: {:cont, update_result()} | {:halt, {:error, term()}}
  defp align_relationship(contract, object, acc, prop, relat, operation) do
    has_key1 = Enum.member?(object._metadata.properties_list, prop)
    has_key2 = Enum.member?(object._metadata.properties_list, relat)

    if has_key1 != has_key2 do
      {del_key, new_key} =
        cond do
          has_key1 -> {prop, relat}
          has_key2 -> {relat, prop}
        end

      if operation == :add do
        add_relationship_partner(contract, acc, new_key)
      else
        {:cont, {:ok, delete_relationship_key(acc, del_key)}}
      end
    else
      {:cont, {:ok, acc}}
    end
  end

  @spec add_relationship_partner(ObjectsContract.t(), struct(), atom()) ::
          {:cont, {:ok, struct()}} | {:halt, {:error, {:missing_optional_property, atom()}}}
  defp add_relationship_partner(contract, acc, new_key) do
    if new_key in contract.properties do
      case Map.fetch(contract.default_properties_all, new_key) do
        {:ok, new_value} ->
          acc
          |> Map.put(new_key, new_value)
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
  end

  @spec delete_relationship_key(struct(), atom()) :: struct()
  defp delete_relationship_key(acc, del_key) do
    acc
    |> Map.delete(del_key)
    |> then(
      &update_in(&1, [Access.key(:_metadata), :properties_list], fn list ->
        List.delete(list, del_key)
      end)
    )
  end

  @spec check_property_allowed_remove(ObjectsContract.t(), struct(), atom()) ::
          :ok | {:error, {:property_not_allowed, atom()}}
  defp check_property_allowed_remove(contract, object, property) do
    if property in contract.required or property in contract.intrinsic or property in contract.cov or
         check_if_property_optionally_required(contract, object, object._metadata, property) do
      {:error, {:property_not_allowed, property}}
    else
      :ok
    end
  end

  @spec verify_required_properties(ObjectsContract.t(), map(), metadata()) ::
          :ok | {:error, {:missing_required_property, atom()}}
  defp verify_required_properties(contract, properties, metadata) do
    Enum.reduce_while(contract.required, :ok, fn req_prop, _acc ->
      rev_status = Map.get(contract.revision_map, req_prop)
      present? = Map.has_key?(properties, req_prop) and req_prop in metadata.properties_list
      revision_allows_absence? = is_integer(rev_status) and metadata.revision < rev_status

      if present? or revision_allows_absence? do
        {:cont, :ok}
      else
        {:halt, {:error, {:missing_required_property, req_prop}}}
      end
    end)
  end

  @spec check_if_property_optionally_required(ObjectsContract.t(), map(), map(), atom()) ::
          boolean()
  defp check_if_property_optionally_required(contract, properties, metadata, property) do
    case Keyword.fetch(annotation_for(contract, property), :required_when) do
      {:ok, value} ->
        verify_properties_required_when(properties, metadata, value) == true

      :error ->
        false
    end
  end

  @spec verify_properties_required_when(map(), map(), term()) :: boolean() | :optional
  defp verify_properties_required_when(properties, metadata, annotation)

  defp verify_properties_required_when(_properties, metadata, {:property, property}) do
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

  defp verify_properties_required_when(_properties, metadata, {:opts, option}) do
    with :error <- Map.fetch(metadata, option),
         :error <- Map.fetch(metadata.other, option) do
      false
    else
      {:ok, opt_val} -> opt_val == true
    end
  end

  defp verify_properties_required_when(_properties, metadata, {:opts, option, value}) do
    with :error <- Map.fetch(metadata, option),
         :error <- Map.fetch(metadata.other, option) do
      false
    else
      {:ok, opt_val} -> opt_val === value
    end
  end

  defp verify_properties_required_when(_properties, metadata, {:opts, option, op, value}) do
    with :error <- Map.fetch(metadata, option),
         :error <- Map.fetch(metadata.other, option) do
      false
    else
      {:ok, opt_val} -> apply(Kernel, op, [opt_val, value]) == true
    end
  end

  defp verify_properties_required_when(properties, _metadata, fun) when is_function(fun, 1) do
    case fun.(properties) do
      val when val in [true, :optional] -> val
      _other -> false
    end
  end

  defp verify_properties_required_when(properties, metadata, fun) when is_function(fun, 2) do
    case fun.(properties, metadata) do
      val when val in [true, :optional] -> val
      _other -> false
    end
  end

  defp verify_properties_required_when(_properties, _metadata, _other), do: false

  @spec verify_properties_with_required_when(ObjectsContract.t(), map(), metadata()) ::
          {:ok, map()} | {:error, term()}
  defp verify_properties_with_required_when(contract, properties, metadata) do
    Enum.reduce_while(annotations_with(contract, :required_when), {:ok, properties}, fn
      {name, annotation}, {:ok, properties} ->
        # `:optional` is treated as required here. `only_when` is what allows absence.
        if verify_properties_required_when(properties, metadata, annotation) == false do
          {:cont, {:ok, properties}}
        else
          case check_property_exists(%{_metadata: metadata}, name) do
            :ok ->
              {:cont, {:ok, properties}}

            {:error, _absent} ->
              case Map.fetch(contract.default_properties_all, name) do
                {:ok, default_val} ->
                  {:cont, {:ok, Map.put(properties, name, default_val)}}

                :error ->
                  {:halt, {:error, {:missing_required_property, name}}}
              end
          end
        end
    end)
  end

  @spec verify_properties_with_only_when(ObjectsContract.t(), map(), metadata()) ::
          {:ok, map()} | {:error, term()}
  defp verify_properties_with_only_when(contract, properties, metadata) do
    Enum.reduce_while(annotations_with(contract, :only_when), {:ok, properties}, fn
      {name, annotation}, {:ok, properties} ->
        required_state = verify_properties_required_when(properties, metadata, annotation)
        has_key = check_property_exists(%{_metadata: metadata}, name) == :ok
        required? = required_state != false

        if required? and not has_key do
          case Map.fetch(contract.default_properties_all, name) do
            {:ok, default_val} ->
              {:cont, {:ok, Map.put(properties, name, default_val)}}

            _else ->
              if required_state == :optional do
                {:cont, {:ok, properties}}
              else
                {:halt, {:error, {:missing_required_property, name}}}
              end
          end
        else
          if not required? and has_key do
            {:halt, {:error, {:property_not_allowed, name}}}
          else
            {:cont, {:ok, properties}}
          end
        end
    end)
  end

  @spec annotations_with(ObjectsContract.t(), atom()) :: [{atom(), term()}]
  defp annotations_with(contract, key) do
    Enum.reduce(contract.annotations, [], fn {name, key_annotations}, acc ->
      case Keyword.fetch(key_annotations, key) do
        {:ok, value} -> [{name, value} | acc]
        :error -> acc
      end
    end)
  end

  @spec annotation_for(ObjectsContract.t(), atom()) :: keyword()
  defp annotation_for(contract, property) do
    Keyword.get(contract.annotations, property, [])
  end

  @spec validate_property_value(
          ObjectsContract.t(),
          map(),
          atom(),
          term(),
          term(),
          boolean() | :value
        ) :: :ok | {:error, {:value_failed_property_validation, atom()}}
  defp validate_property_value(_contract, _object, _property, _value, _type, :value), do: :ok

  defp validate_property_value(contract, object, property, value, type, _skip) do
    case Map.fetch(contract.validators, property) do
      :error ->
        :ok

      {:ok, {nil, nil}} ->
        :ok

      {:ok, {type_fun, value_fun}} ->
        err = {:error, {:value_failed_property_validation, property}}

        if apply_validator_fun(type_fun, value, object, type) do
          if apply_validator_fun(value_fun, value, object, type) do
            :ok
          else
            err
          end
        else
          err
        end
    end
  end

  @spec apply_validator_fun(function() | nil, term(), map(), term()) :: term()
  defp apply_validator_fun(val_fun, value, object, _type) do
    if is_function(val_fun, 0) do
      val_fun.()
    else
      if is_function(val_fun, 1) do
        val_fun.(value)
      else
        if is_function(val_fun, 2) do
          val_fun.(value, object)
        else
          true
        end
      end
    end
  end

  @spec sync_priority_present_value(struct(), ObjectsContract.t()) :: struct()
  defp sync_priority_present_value(
         %{priority_array: %PriorityArray{} = pa, relinquish_default: default} = object,
         %{has_priority_array: true}
       )
       when not is_nil(default) do
    present_value =
      case PriorityArray.get_value(pa) do
        {_prio, value} -> value
        nil -> default
      end

    %{object | present_value: present_value}
  end

  defp sync_priority_present_value(object, _contract), do: object

  @spec sync_feedback(struct(), ObjectsContract.t()) :: struct()
  defp sync_feedback(object, %{has_feedback_value: true}) do
    maybe_write_feedback_from_metadata(object, object)
  end

  defp sync_feedback(object, _contract), do: object

  @spec maybe_write_feedback(ObjectsContract.t(), struct(), struct()) :: struct()
  defp maybe_write_feedback(%{has_feedback_value: true}, source, updated) do
    maybe_write_feedback_from_metadata(source, updated)
  end

  defp maybe_write_feedback(_contract, _source, updated), do: updated

  @spec maybe_write_feedback_from_metadata(struct(), struct()) :: struct()
  defp maybe_write_feedback_from_metadata(source, updated) do
    if source._metadata.other[:auto_write_feedback] do
      %{updated | feedback_value: updated.present_value}
    else
      updated
    end
  end

  @spec sync_in_alarm(struct(), ObjectsContract.t()) :: struct()
  defp sync_in_alarm(%{event_state: state} = object, %{
         has_event_state: true,
         has_status_flags: true
       })
       when not is_nil(state) do
    %{
      object
      | status_flags: %{
          object.status_flags
          | in_alarm: state != Constants.macro_assert_name(:event_state, :normal)
        }
    }
  end

  defp sync_in_alarm(object, _contract), do: object

  @spec sync_fault(struct(), ObjectsContract.t()) :: struct()
  defp sync_fault(%{reliability: reliability} = object, %{
         has_reliability: true,
         has_status_flags: true
       })
       when not is_nil(reliability) do
    %{
      object
      | status_flags: %{
          object.status_flags
          | fault: reliability != Constants.macro_assert_name(:reliability, :no_fault_detected)
        }
    }
  end

  defp sync_fault(object, _contract), do: object

  @spec sync_out_of_service(struct(), ObjectsContract.t()) :: struct()
  defp sync_out_of_service(object, %{has_out_of_service: true, has_status_flags: true}) do
    %{
      object
      | status_flags: %{object.status_flags | out_of_service: object.out_of_service}
    }
  end

  defp sync_out_of_service(object, _contract), do: object

  @spec property_in_list?(map(), atom()) :: boolean()
  defp property_in_list?(%{_metadata: %{properties_list: list}}, property), do: property in list

  @spec writable_event_algorithm_inhibit?(map()) :: boolean()
  defp writable_event_algorithm_inhibit?(object) do
    case object do
      %{event_algorithm_inhibit_ref: ref, event_detection_enable: true} when not is_nil(ref) ->
        ref.object_identifier.instance ==
          Constants.macro_by_name(:asn1, :max_instance_and_property_id)

      %{event_algorithm_inhibit_ref: nil, event_detection_enable: true} ->
        true

      _term ->
        false
    end
  end

  @spec writable_present_value?(map()) :: boolean()
  defp writable_present_value?(object) do
    case object do
      %{priority_array: pa} when not is_nil(pa) -> truthy?(Map.get(object, :out_of_service))
      _term -> true
    end
  end

  @spec truthy?(term()) :: boolean()
  defp truthy?(nil), do: false
  defp truthy?(false), do: false
  defp truthy?(_other), do: true

  @spec check_printable_object_name(String.t()) ::
          :ok | {:error, {:invalid_non_printable_object_name, :object_name}}
  defp check_printable_object_name(name) do
    if byte_size(name) > 0 and String.valid?(name) and String.printable?(name) do
      :ok
    else
      {:error, {:invalid_non_printable_object_name, :object_name}}
    end
  end

  @spec inspect_sort_key({atom(), term()}) :: String.t()
  defp inspect_sort_key({key, _val}) do
    str = Atom.to_string(key)

    if String.starts_with?(str, "_") do
      binary_part(str, 1, byte_size(str) - 1)
    else
      str
    end
  end

  @spec to_assoc({term(), term()}, Inspect.Opts.t(), Inspect.Algebra.t()) :: Inspect.Algebra.t()
  defp to_assoc({key, value}, opts, sep) do
    Inspect.Algebra.concat(
      Inspect.Algebra.concat(Inspect.Algebra.to_doc(key, opts), sep),
      Inspect.Algebra.to_doc(value, opts)
    )
  end

  @spec map_container_doc(term(), String.t(), Inspect.Opts.t(), function()) ::
          Inspect.Algebra.t()
  defp map_container_doc(list, name, opts, fun) do
    open = Inspect.Algebra.color("#" <> name <> "<", :map, opts)
    sep = Inspect.Algebra.color(",", :map, opts)
    close = Inspect.Algebra.color(">", :map, opts)
    Inspect.Algebra.container_doc(open, list, close, opts, fun, separator: sep, break: :strict)
  end
end
