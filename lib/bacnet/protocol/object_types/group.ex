defmodule BACnet.Protocol.ObjectTypes.Group do
  @moduledoc """
  A Group gathers properties from local objects so a client can read them
  together. For example, a room's Group could expose the temperature, setpoint
  and occupancy from three different objects. A read of `present_value`
  returns a value or access error for each selected property.

  `list_of_group_members` contains `BACnet.Protocol.AccessSpecification` values. Each names
  one object and one or more properties, optionally with array indices. `present_value`
  contains one `BACnet.Protocol.ReadAccessResult` per specification, with individual values
  or access errors in `BACnet.Protocol.ReadAccessResult.ReadResult` entries.

  ### Object Description (ASHRAE 135)

  > The Group object type defines a standardized object whose properties
  > represent a collection of other objects and one or more of their properties.

  ## Configuration and membership

  Supply a nonempty `list_of_group_members` when creating a local instance. There is no
  implicit empty membership default. Each specification needs a nonempty property list.
  Membership is writable through lifecycle preparation, although the standard does not
  require support for writing that property. A member property entry is a read reference -
  its `property_value` must be nil. Selectors cannot carry an array index.

  Members reside in the same device as the Group. Access specifications have no device field,
  and the module passes local references to the host. The host needs to resolve them in that
  device, without rerouting an unresolved member to a remote device. An unavailable object or
  property produces an access error when read - configuration does not perform I/O to check
  whether members are currently accessible.

  A Group may refer to another Group's metadata, but cannot refer to `present_value` of a
  Group or Global Group. `ALL` and `REQUIRED` selectors on those object types are also
  rejected because they include that required property. `OPTIONAL` and explicit metadata
  references remain permitted. Named and numeric identifiers use the same checks.

  ## Fresh reads through the lifecycle

  Every read of `present_value` needs
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` with the matching property-read
  trigger. It fetches the member properties and reconstructs the entire result. Retain the
  returned result and obtain its value with `get_property/2` before the next operation.
  An aggregate `ALL` or `REQUIRED` read trigger also refreshes the value, because those
  selections include it. `present_value` is a BACnet list, so indexed reads are rejected.

  The returned object holds the values for that read. Prepare a new result
  for each subsequent request, even if the clocks and source values are the
  same. Initialization and membership writes clear the old result. Group
  acquires members only for reads that include Present_Value, so it requests
  no timer and preserves the supplied runtime state.

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  owns instance storage, operation ordering and property-service access. It needs to retain
  object/state/request together and supply a bounded read callback in
  `BACnet.Protocol.ObjectExecution.Context`. When a member has computed properties, the callback
  needs to refresh that member through its lifecycle, retain it and finish immediate
  continuations before returning the requested value. Detect cyclic reads and avoid
  synchronously calling an owner already blocked executing the Group. Reads are sequential
  and preserve request order - they do not form an atomic transaction across member objects.

  ## Read callback values and property selectors

  Ordinary member reads use `BACnet.Protocol.ObjectExecution.Context.read_property/2` with
  a local `BACnet.Protocol.DeviceObjectPropertyRef`, including the requested array index.
  The callback returns `{:ok, value}` with the source property's native representation,
  or `{:error, reason}`. Group converts values through
  `BACnet.Protocol.ObjectsUtility.cast_value_to_property/4` and constructs its own
  `BACnet.Protocol.ReadAccessResult.ReadResult` entries. NULL, array-length reads, priority
  slots and virtual identity/property-list values are handled at the conversion boundary.

  `BACnet.Protocol.ApplicationTags.Encoding` values and lists of encodings can also be
  returned and are preserved. These are useful for proprietary properties or object types
  whose datatype the library cannot infer. Empty lists are valid encoded values. A native
  value that cannot be encoded becomes PROPERTY / INVALID_DATATYPE for that property,
  and following reads still proceed. There is no lookup callback requirement.

  `ALL`, `REQUIRED` and `OPTIONAL` use the separate
  `BACnet.Protocol.ObjectExecution.Context.read_property_multiple/3` operation. The callback
  receives a local `BACnet.Protocol.DeviceObjectRef` and a one-element selector list. It
  returns `{:ok, properties}` with a **map of property identifiers to native values**, analogous
  to the map returned by `BACnet.Stack.ClientHelper.read_property_multiple/5`:

      %{object_name: "Source", present_value: 21.5,
        description: {:error, :read_access_denied}}

  For indexed entries, use `{property_identifier, array_index}` as the key.
  Put `{:error, reason}` in the map when an individual property fails.
  Return `{:error, reason}` directly when the whole operation fails. Group
  builds the BACnet result from those values and errors. An empty map adds
  no entries to the result.

  The host's property-service layer needs to select from the member's actual property catalog:

  - `ALL` includes all implemented properties, including proprietary ones.
  - `REQUIRED` includes standard properties with conformance code R or W.
  - `OPTIONAL` includes present standard properties with conformance code O.
  - `Property_List` is excluded from `ALL` and `REQUIRED`. The module also removes it from
    those maps if supplied by the callback. It remains readable when requested explicitly.

  The map needs to retain failures of selected properties as error entries. Helpers that
  discard failed properties need an adapter preserving those errors for Group. In particular,
  the transformed map from `BACnet.Stack.ClientHelper.read_property_multiple/5` omits property
  access errors - its return shape is the model for this API, while a faithful Group read
  also needs those error entries.

  Group cannot infer a complete service catalog from a struct's fields alone - a host may
  expose virtual, proprietary and conditionally present properties. The callback supplies the
  property I/O results; Group owns member traversal, value conversion and result construction.
  Explicit member/property order and duplicates are preserved. Since maps have no request
  order, selector expansions use ascending numeric property identifier, followed by array
  index. A map must not introduce a forbidden nested Group value or an unexpanded selector.

  ## Errors, writes and restart

  Operational failures produce per-property BACnet errors in a successful lifecycle result.
  Following properties and members are still attempted, even if every acquisition fails.
  `BACnet.Protocol.BACnetError` values are preserved, including proprietary class/code values.
  The following library errors have convenience mappings:

  | Callback reason | Error class/code |
  | --- | --- |
  | `:unknown_object` | OBJECT / UNKNOWN_OBJECT |
  | `:unknown_property`, `:unknown_property_identifier` | PROPERTY / UNKNOWN_PROPERTY |
  | `:read_access_denied`, `:invalid_array_index`, `:property_is_not_an_array`, `:invalid_datatype`, `:value_out_of_range` | PROPERTY / corresponding code |
  | Other reasons, including timeouts and cyclic execution | DEVICE / OPERATIONAL_PROBLEM |

  The known object/property errors also accept the library's `{reason, detail}` form. A host
  that needs a more specific mapping should return a `BACnet.Protocol.BACnetError` directly.
  Exceptions, malformed callback results and invalid selector expansions remain programming
  errors. Configuration errors and missing required callbacks are rejected before acquisition.
  The Group object has no Reliability property or intrinsic reporting implementation.

  Client writes to `present_value` are denied. For membership changes, build a candidate through
  `update_property/3`, prepare it with `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3`,
  commit the returned candidate and execute the same write trigger. Preparation clears the old
  value without acquiring replacements. Low-level property updates alone do not run the lifecycle.

  After restart, initialize with fresh clocks and state, then refresh before reading the value.
  A remote Group snapshot stays passive, preserves its supplied state and rejects local write
  preparation. Remote snapshots do not acquire the remote device's member properties.

  ## Examples

  Create a Group and read a single member through the lifecycle:

      iex> alias BACnet.Protocol.AccessSpecification
      iex> alias BACnet.Protocol.AccessSpecification.Property
      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> alias BACnet.Protocol.ObjectIdentifier
      iex> alias BACnet.Protocol.ObjectTypes.Group
      iex> member = %AccessSpecification{
      ...>   object_identifier: %ObjectIdentifier{type: :analog_value, instance: 2},
      ...>   properties: [%Property{property_identifier: :present_value,
      ...>     property_array_index: nil, property_value: nil}]}
      iex> {:ok, group} = Group.create(1600, "ZoneGroup", %{list_of_group_members: [member]})
      iex> context = Context.new({:property_read, :present_value, nil},
      ...>   now: ~U[2026-11-09 08:00:00Z], monotonic_time: 0,
      ...>   read_property: fn _reference -> {:ok, 21.5} end)
      iex> {:ok, stored} = Lifecycle.prepare_read(group, context)
      iex> [member_result] = stored.object.present_value
      iex> [property_result] = member_result.results
      iex> {stored.object.object_name, property_result.property_value.value, stored.next_execution}
      {"ZoneGroup", 21.5, nil}

  Retain `stored` before serving the result. Each subsequent present-value read needs another
  lifecycle read even when its clocks are unchanged. A complete walkthrough of fresh reads,
  selectors, partial failures and membership writes is available at
  `examples/objects_lifecycle/group_lifecycle.exs` in the repository.

  ### See Also

  - `BACnet.Protocol.AccessSpecification`
  - `BACnet.Protocol.ReadAccessResult`
  - `BACnet.Protocol.ObjectExecution.Lifecycle`
  """

  alias BACnet.Protocol.AccessSpecification
  alias BACnet.Protocol.AccessSpecification.Property
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.DeviceObjectRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ReadAccessResult
  alias BACnet.Protocol.ReadAccessResult.ReadResult

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Group object.
  """
  @type object_opts :: common_object_opts()

  @typedoc """
  Represents a Group object. Update properties through `update_property/3`.

  The returned `present_value` belongs to one lifecycle read and needs to be refreshed
  before every subsequent read. Group members are local to the containing device.
  """
  bac_object Constants.macro_assert_name(:object_type, :group) do
    services(intrinsic: false)

    field(:description, String.t())

    field(:list_of_group_members, [AccessSpecification.t()],
      required: true,
      validator_fun: &valid_members?/2
    )

    field(:present_value, [ReadAccessResult.t()], required: true, readonly: true, default: [])
  end

  @selectors [:all, :required, :optional]
  @property_errors [
    :read_access_denied,
    :invalid_array_index,
    :property_is_not_an_array,
    :invalid_datatype,
    :value_out_of_range
  ]

  @doc """
  Checks local member configuration, read index and required callbacks without I/O.

  Reads that include `present_value` require only the single- or multiple-property
  callbacks selected by their member references. Initialization, unrelated
  reads and other triggers perform no acquisition. Remote snapshots remain passive.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec validate_execution(t(), Context.t()) :: :ok | {:error, term()}
  def validate_execution(object, context)

  def validate_execution(%__MODULE__{_metadata: %{remote_object: remote}}, %Context{})
      when not is_nil(remote), do: :ok

  def validate_execution(%__MODULE__{} = object, %Context{} = context) do
    cond do
      not valid_members?(object.list_of_group_members, object) ->
        {:error, {:invalid_configuration, :list_of_group_members}}

      read_request?(context) ->
        with :ok <- validate_read_index(context) do
          Context.require_operations(context, required_operations(object))
        end

      true ->
        :ok
    end
  end

  @doc """
  Rejects writes to the calculated value and clears it when membership is reconfigured.

  A prepared membership write performs no reads. The next present-value read reconstructs
  the results from the new membership. Client writes still need lifecycle preparation and
  execution, including same-value writes.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec prepare_write(t(), t(), Context.t()) :: {:ok, t()} | {:error, term()}
  def prepare_write(original, candidate, context)

  def prepare_write(%__MODULE__{_metadata: %{remote_object: remote}}, _candidate, %Context{})
      when not is_nil(remote), do: {:error, :operation_not_available_for_remote_objects}

  def prepare_write(%__MODULE__{} = original, %__MODULE__{} = candidate, %Context{} = context) do
    case Context.written_property(context, :property_write) do
      :present_value -> {:error, {:write_access_denied, :present_value}}
      :list_of_group_members -> update_property(candidate, :present_value, [])
      _other -> super(original, candidate, context)
    end
  end

  @doc """
  Reconstructs `present_value` for each read that includes it, without scheduling work.

  Member failures become per-property BACnet errors in a successful result. Retain that result
  and read its value before servicing the next operation. Other triggers perform no member I/O
  and preserve runtime state. The module documentation defines the read callback contract.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec execute(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  def execute(object, context)

  def execute(%__MODULE__{_metadata: %{remote_object: remote}} = object, %Context{} = context)
      when not is_nil(remote), do: super(object, context)

  def execute(%__MODULE__{} = object, %Context{} = context) do
    with :ok <- validate_execution(object, context) do
      cond do
        read_request?(context) ->
          results = Enum.map(object.list_of_group_members, &read_member(&1, context))
          {:ok, object} = update_property(object, :present_value, results)
          result(object, context)

        context.trigger == :initialization or
            Context.written_property(context, :property_write) == :list_of_group_members ->
          {:ok, object} = update_property(object, :present_value, [])
          result(object, context)

        true ->
          result(object, context)
      end
    end
  end

  @spec required_operations(t()) :: [:read_property | :read_property_multiple]
  defp required_operations(object) do
    properties = Enum.flat_map(object.list_of_group_members, & &1.properties)

    operations =
      Enum.map(properties, fn property ->
        name = if is_struct(property, Property), do: property.property_identifier, else: property
        if identifier(name) in @selectors, do: :read_property_multiple, else: :read_property
      end)

    Enum.uniq(operations)
  end

  @spec valid_members?(term(), map()) :: boolean()
  defp valid_members?(members, object)

  defp valid_members?(_members, %{_metadata: %{remote_object: remote}})
       when not is_nil(remote), do: true

  defp valid_members?([_first | _rest] = members, _object),
    do: Enum.all?(members, &valid_member?/1)

  defp valid_members?(_members, _object), do: false

  @spec valid_member?(term()) :: boolean()
  defp valid_member?(member)

  defp valid_member?(%AccessSpecification{} = member) do
    AccessSpecification.valid?(member) and
      Enum.all?(member.properties, fn property ->
        valid_read_property?(property) and not nested_value?(member.object_identifier, property)
      end)
  end

  defp valid_member?(_member), do: false

  @spec valid_read_property?(term()) :: boolean()
  defp valid_read_property?(property)

  defp valid_read_property?(property) when property in @selectors, do: true

  defp valid_read_property?(%Property{property_value: nil} = property) do
    Property.valid?(property) and
      (identifier(property.property_identifier) not in @selectors or
         is_nil(property.property_array_index))
  end

  defp valid_read_property?(_property), do: false

  @spec nested_value?(ObjectIdentifier.t(), Property.t() | atom()) :: boolean()
  defp nested_value?(object, property) do
    type =
      if is_integer(object.type),
        do: Constants.by_value(:object_type, object.type, object.type),
        else: object.type

    property = if is_struct(property, Property), do: property.property_identifier, else: property
    type in [:group, :global_group] and identifier(property) in [:present_value, :all, :required]
  end

  @spec identifier(atom() | non_neg_integer()) :: atom() | non_neg_integer()
  defp identifier(property)

  defp identifier(property) when is_integer(property),
    do: Constants.by_value(:property_identifier, property, property)

  defp identifier(property), do: property

  @spec read_request?(Context.t()) :: boolean()
  defp read_request?(context)

  defp read_request?(%Context{trigger: {:property_read, property, _index}}),
    do: identifier(property) in [:present_value, :all, :required]

  defp read_request?(%Context{}), do: false

  @spec validate_read_index(Context.t()) :: :ok | {:error, :property_is_not_an_array}
  defp validate_read_index(%Context{trigger: {:property_read, _property, index}}),
    do: if(is_nil(index), do: :ok, else: {:error, :property_is_not_an_array})

  @spec read_member(AccessSpecification.t(), Context.t()) :: ReadAccessResult.t()
  defp read_member(member, context) do
    results =
      Enum.flat_map(member.properties, fn property ->
        read_property(member.object_identifier, property, context)
      end)

    %ReadAccessResult{object_identifier: member.object_identifier, results: results}
  end

  @spec read_property(ObjectIdentifier.t(), Property.t() | atom(), Context.t()) :: [
          ReadResult.t()
        ]
  defp read_property(object, property, context) do
    {name, index} =
      case property do
        %Property{} = property -> {property.property_identifier, property.property_array_index}
        selector -> {selector, nil}
      end

    reference = %DeviceObjectPropertyRef{
      device_identifier: nil,
      object_identifier: object,
      property_identifier: name,
      property_array_index: index
    }

    if identifier(name) in @selectors do
      read_selection(reference, context)
    else
      [property_result(reference, Context.read_property(context, reference))]
    end
  end

  @spec read_selection(DeviceObjectPropertyRef.t(), Context.t()) :: [ReadResult.t()]
  defp read_selection(reference, context) do
    object = %DeviceObjectRef{
      device_identifier: nil,
      object_identifier: reference.object_identifier
    }

    selector = identifier(reference.property_identifier)

    case Context.read_property_multiple(context, object, [selector]) do
      {:ok, values} when is_map(values) and not is_struct(values) ->
        values
        |> Enum.map(fn {key, value} -> {expanded_reference(reference, key), value} end)
        |> Enum.reject(fn {ref, _value} ->
          selector in [:all, :required] and
            identifier(ref.property_identifier) == :property_list
        end)
        |> Enum.sort_by(fn {ref, _value} ->
          {property_number(ref.property_identifier), ref.property_array_index || -1}
        end)
        |> Enum.map(fn {ref, value} ->
          response =
            case value do
              {:error, _reason} = error -> error
              value -> {:ok, value}
            end

          property_result(ref, response)
        end)

      {:error, reason} ->
        [property_result(reference, {:error, reason})]

      _other ->
        raise ArgumentError, "Group multiple-property reads must return a property-value map"
    end
  end

  @spec expanded_reference(DeviceObjectPropertyRef.t(), Context.property_result_key()) ::
          DeviceObjectPropertyRef.t()
  defp expanded_reference(reference, key) do
    {name, index} =
      case key do
        {property, index} when is_integer(index) and index >= 0 ->
          {property, index}

        property when is_atom(property) or (is_integer(property) and property >= 0) ->
          {property, nil}

        _other ->
          raise ArgumentError, "Group multiple-property map has an invalid property key"
      end

    property = %Property{
      property_identifier: name,
      property_array_index: index,
      property_value: nil
    }

    if not Property.valid?(property) or identifier(name) in @selectors or
         nested_value?(reference.object_identifier, property) do
      raise ArgumentError,
            "Group multiple-property map has an invalid or nested property reference"
    end

    %{reference | property_identifier: name, property_array_index: index}
  end

  @spec property_number(atom() | non_neg_integer()) :: non_neg_integer()
  defp property_number(property)
  defp property_number(property) when is_integer(property), do: property
  defp property_number(property), do: Constants.by_name!(:property_identifier, property)

  @spec property_result(DeviceObjectPropertyRef.t(), {:ok, term()} | {:error, term()}) ::
          ReadResult.t()
  defp property_result(reference, response) do
    {value, error} =
      case response do
        {:ok, native} ->
          case encode_value(reference, native) do
            {:ok, encoded} -> {encoded, nil}
            {:error, _reason} -> {nil, %BACnetError{class: :property, code: :invalid_datatype}}
          end

        {:error, reason} ->
          {nil, access_error(reason)}
      end

    %ReadResult{
      property_identifier: reference.property_identifier,
      property_array_index: reference.property_array_index,
      property_value: value,
      error: error
    }
  end

  @spec encode_value(DeviceObjectPropertyRef.t(), term()) ::
          {:ok, Encoding.t() | [Encoding.t()]} | {:error, term()}
  defp encode_value(reference, value)
  defp encode_value(_reference, %Encoding{} = value), do: {:ok, value}
  defp encode_value(_reference, nil), do: {:ok, Encoding.create!({:null, nil})}

  defp encode_value(%DeviceObjectPropertyRef{property_array_index: 0}, value)
       when is_integer(value) and value >= 0,
       do: {:ok, Encoding.create!({:unsigned_integer, value})}

  defp encode_value(reference, values) when is_list(values) do
    if Enum.all?(values, &is_struct(&1, Encoding)),
      do: {:ok, values},
      else: encode_native(reference, values)
  end

  defp encode_value(reference, value), do: encode_native(reference, value)

  @spec encode_native(DeviceObjectPropertyRef.t(), term()) ::
          {:ok, Encoding.t() | [Encoding.t()]} | {:error, term()}
  defp encode_native(reference, value) do
    case {identifier(reference.property_identifier), reference.property_array_index} do
      {:object_identifier, nil} ->
        Encoding.create({:object_identifier, value})

      {:object_type, nil} ->
        encode_enumeration(:object_type, value)

      {:property_list, index} ->
        encode_property_list(value, index)

      {:priority_array, index} when is_integer(index) and index > 0 ->
        ObjectsUtility.cast_value_to_property(reference.object_identifier, :present_value, value)

      {property, index} when is_atom(property) ->
        ObjectsUtility.cast_value_to_property(reference.object_identifier, property, value,
          allow_partial: not is_nil(index)
        )

      _other ->
        {:error, :unknown_property}
    end
  end

  @spec encode_enumeration(atom(), atom() | non_neg_integer()) ::
          {:ok, Encoding.t()} | {:error, term()}
  defp encode_enumeration(group, value) do
    case value do
      value when is_integer(value) and value >= 0 ->
        Encoding.create({:enumerated, value})

      value when is_atom(value) ->
        case Constants.by_name(group, value) do
          {:ok, numeric} -> Encoding.create({:enumerated, numeric})
          :error -> {:error, :unknown_enumeration}
        end

      _other ->
        {:error, :invalid_enumeration}
    end
  end

  @spec encode_property_list(term(), non_neg_integer() | nil) ::
          {:ok, Encoding.t() | [Encoding.t()]} | {:error, term()}
  defp encode_property_list(value, index)

  defp encode_property_list(%BACnetArray{} = array, nil),
    do: encode_property_list(BACnetArray.to_list(array), nil)

  defp encode_property_list(values, nil) when is_list(values) do
    result =
      Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
        case encode_enumeration(:property_identifier, value) do
          {:ok, value} -> {:cont, {:ok, [value | acc]}}
          {:error, _reason} = error -> {:halt, error}
        end
      end)

    case result do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      {:error, _reason} = error -> error
    end
  end

  defp encode_property_list(value, index) when is_integer(index) and index > 0,
    do: encode_enumeration(:property_identifier, value)

  defp encode_property_list(_value, _index), do: {:error, :invalid_property_list}

  @spec access_error(term()) :: BACnetError.t()
  defp access_error(reason)

  defp access_error(%BACnetError{} = error) do
    if BACnetError.valid?(error),
      do: error,
      else: raise(ArgumentError, "Group read returned an invalid BACnetError")
  end

  defp access_error({reason, _detail})
       when reason in [:unknown_object, :unknown_property, :unknown_property_identifier] or
              reason in @property_errors,
       do: access_error(reason)

  defp access_error(:unknown_object), do: %BACnetError{class: :object, code: :unknown_object}

  defp access_error(reason) when reason in [:unknown_property, :unknown_property_identifier],
    do: %BACnetError{class: :property, code: :unknown_property}

  defp access_error(reason) when reason in @property_errors,
    do: %BACnetError{class: :property, code: reason}

  defp access_error(_reason), do: %BACnetError{class: :device, code: :operational_problem}

  @spec result(t(), Context.t()) :: {:ok, Result.t(t())}
  defp result(object, context),
    do: {:ok, %Result{object: object, state: context.state, next_execution: nil}}
end
