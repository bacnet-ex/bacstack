defmodule BACnet.Protocol.ObjectExecution.ScheduleTargets do
  @moduledoc """
  Internal reference validation and target planning for Schedule execution.

  `BACnet.Protocol.ObjectTypes.Schedule` uses this module to prepare an ordered list of target
  writes. Applications driving objects should use `BACnet.Protocol.ObjectExecution.Lifecycle`.
  Schedule uses these helpers to validate references and prepare writes before issuing commands.

  ## Planning and execution phases

  `validate_references/2` checks reference representation without host I/O.
  `required_operations/2` determines which callbacks the selected references require, also without
  invoking them. Both support the Schedule's execution preflight.

  `prepare/5` is an execution-time operation. It may invoke
  `BACnet.Protocol.ObjectExecution.Context.lookup_object/2` to inspect local targets, cast values
  through `BACnet.Protocol.ObjectsUtility.cast_property_to_value/4`, and validate hypothetical
  property or priority updates. It does not commit those candidates or invoke
  `BACnet.Protocol.ObjectExecution.Context.write_property/4`. Each result is a `t:plan/0`.

  This planning step is separate from `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3`,
  which validates a proposed write to the Schedule itself without host I/O. During Schedule
  execution, the object module publishes its computed value and plans in an immediate result.
  After the host retains the result, the continuation sends the commands through the host's write callback.

  ## References, values and failures

  A reference without a device identifier is local. An explicit identifier equal to the context's
  local `device_identifier` is normalized to `nil`. Other qualified references remain remote -
  without a local identity, every device-qualified reference is forwarded as remote.

  Local target plans check object identity, property access, array indices and compatibility of
  the selected value and configured output values. Casting uses the identifier from the target
  module's object-identifier getter and the existing object-type mapping. NULL command
  relinquishment and array length handling stay in the local planning/write paths. Array elements
  use the caster's `allow_partial: true` option. The host still needs to enforce service permissions,
  reserved-priority rules and property-specific resizing when applying a write.

  Remote targets require no lookup or local object model. Their plans preserve the original
  encoding and qualified reference. The write callback needs to resolve the device's destination
  and report the remote service result. Property array indices and the supplied command priority
  need to be preserved when forwarding to `BACnet.Stack.ClientHelper.write_property/6`.

  Plans retain target order, including failed plans. Schedule decides how those errors affect its
  Reliability property and continues with other valid targets. Host callback exceptions and
  malformed lookup results are programming errors and may raise rather than become failed plans.

  ## Example

  This example plans one local, one explicit self-device and one remote write. Its write callback
  raises if called, demonstrating that planning does not perform the writes.

      iex> alias BACnet.Protocol.ApplicationTags.Encoding
      iex> alias BACnet.Protocol.{DeviceObjectPropertyRef, DeviceObjectRef, ObjectIdentifier}
      iex> alias BACnet.Protocol.ObjectExecution.{Context, ScheduleTargets}
      iex> alias BACnet.Protocol.ObjectTypes.BinaryOutput
      iex> {:ok, target} = BinaryOutput.create(700, "Lighting")
      iex> identifier = BinaryOutput.get_object_identifier(target)
      iex> device = %ObjectIdentifier{type: :device, instance: 42}
      iex> remote_device = %ObjectIdentifier{type: :device, instance: 43}
      iex> reference = %DeviceObjectPropertyRef{device_identifier: nil,
      ...>   object_identifier: identifier, property_identifier: :present_value, property_array_index: nil}
      iex> references = [reference, %{reference | device_identifier: device},
      ...>   %{reference | device_identifier: remote_device}]
      iex> context = Context.new(:initialization, now: ~U[2026-11-09 08:00:00Z],
      ...>   monotonic_time: 0, device_identifier: device,
      ...>   lookup_object: fn %DeviceObjectRef{object_identifier: ^identifier, device_identifier: nil} ->
      ...>     {:ok, target}
      ...>   end,
      ...>   write_property: fn _reference, _value, _priority -> raise "planning must not write" end)
      iex> ScheduleTargets.validate_references(references, context)
      :ok
      iex> ScheduleTargets.required_operations(references, context)
      [:lookup_object, :write_property]
      iex> on = Encoding.create!({:enumerated, 1})
      iex> null = Encoding.create!({:null, nil})
      iex> [{local, {:ok, ^on}}, {self_reference, {:ok, ^on}}, {remote, {:ok, ^on}}] =
      ...>   ScheduleTargets.prepare(references, on, [null, on], 8, context)
      iex> {local.device_identifier, self_reference.device_identifier, remote.device_identifier}
      {nil, nil, %ObjectIdentifier{type: :device, instance: 43}}
  """

  alias BACnet.BeamTypes
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.DeviceObjectRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsUtility

  @typedoc """
  One normalized target reference paired with the selected encoding or a preparation error.

  Success retains the original selected `BACnet.Protocol.ApplicationTags.Encoding`, including
  NULL - the value is not replaced by its local Elixir representation. Local casting is used
  only for compatibility checks. A failed plan contains the lookup, access, index, casting or
  candidate-validation error. An explicit self-device identifier is normalized to `nil` in either
  case. Remote references retain their device identifier.

  A successful remote plan means it is ready to pass to the host callback - remote property
  compatibility has not been inspected. The priority passed to `prepare/5` is used for local
  validation but is not stored in this tuple. Schedule retains its command priority separately.
  """
  @type plan ::
          {DeviceObjectPropertyRef.t(),
           preparation_result :: {:ok, Encoding.t()} | {:error, term()}}

  @doc """
  Checks the representation of a Schedule target-reference list without host I/O.

  Each entry must be a valid `BACnet.Protocol.DeviceObjectPropertyRef`. Local, explicit self-device
  and remote references are accepted. The context supplies the local identity used for routing,
  but no callback is invoked and the input list is not modified.

  Returns `:ok` for a valid list, including an empty one. Invalid entries or a non-list input return
  `{:error, {:invalid_configuration, :list_of_object_property_references}}`. This does not check
  object existence, property access, target datatypes or callback availability.

  ## Example

      iex> alias BACnet.Protocol.ObjectExecution.{Context, ScheduleTargets}
      iex> context = Context.new(:initialization, now: ~U[2026-11-09 08:00:00Z], monotonic_time: 0)
      iex> ScheduleTargets.validate_references([], context)
      :ok
      iex> ScheduleTargets.validate_references([:invalid], context)
      {:error, {:invalid_configuration, :list_of_object_property_references}}
  """
  @spec validate_references(term(), Context.t()) :: :ok | {:error, term()}
  def validate_references(references, context)

  def validate_references(references, %Context{} = context) when is_list(references) do
    Enum.reduce_while(references, :ok, fn reference, :ok ->
      case normalize_reference(reference, context) do
        {:ok, _reference} -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  def validate_references(_references, _context),
    do: {:error, {:invalid_configuration, :list_of_object_property_references}}

  @doc """
  Builds ordered target plans without performing target writes.

  References must have passed `validate_references/2`. The selected `value` and `configured_values`
  must be valid primitive encodings, and `priority` must be in `1..16`. For automatic execution,
  the configured output values come from
  `BACnet.Protocol.ObjectExecution.ScheduleEvaluator.target_values/1`. Out-of-service manual
  execution supplies only the selected value. The selected value is always checked, even if absent
  from the configured list. Duplicate tag/payload pairs are checked once per local target.

  For each local reference, invokes the context's lookup callback with a local
  `BACnet.Protocol.DeviceObjectRef`. It then checks identity, locality, access, index and all
  supplied output values against the resolved target. Primitive casts use
  `BACnet.Protocol.ObjectsUtility.cast_property_to_value/4` with the target's object identifier.
  Candidate property/priority operations validate the native values without committing them.
  NULL relinquishment bypasses ordinary casting for commandable `present_value` writes. Array
  elements use partial casting - index zero validates a variable array's Unsigned length, while
  actual resizing/default initialization remains the host's responsibility.

  Returns one `t:plan/0` per input reference, preserving order and duplicates. Local operational
  errors become failed plans and do not stop planning later targets. Remote plans retain the
  selected encoding without lookup or conversion - remote service errors occur during the later
  write callback. This function invokes no write callback and makes no Reliability update.

  Invalid references violate the precondition and can raise `MatchError`. Malformed lookup objects
  raise `ArgumentError`, while host callback exceptions propagate. See the module example for
  local, explicit self-device and remote plans with NULL relinquishment among the checked values.

  ## Example

      iex> alias BACnet.Protocol.ApplicationTags.Encoding
      iex> alias BACnet.Protocol.ObjectExecution.{Context, ScheduleTargets}
      iex> context = Context.new(:initialization, now: ~U[2026-11-09 08:00:00Z], monotonic_time: 0)
      iex> ScheduleTargets.prepare([], Encoding.create!({:null, nil}), [], 16, context)
      []
  """
  @spec prepare([DeviceObjectPropertyRef.t()], Encoding.t(), [Encoding.t()], 1..16, Context.t()) ::
          [
            plan()
          ]
  def prepare(references, value, configured_values, priority, context) do
    checked_values = Enum.uniq_by([value | configured_values], &{&1.type, &1.value})

    Enum.map(references, fn original ->
      {:ok, reference} = normalize_reference(original, context)

      prepared =
        if is_nil(reference.device_identifier) do
          prepare_local(reference, value, checked_values, priority, context)
        else
          {:ok, value}
        end

      {reference, prepared}
    end)
  end

  @doc """
  Lists the host operations needed by validated target references.

  Call `validate_references/2` first. Returns `[]` for no targets, `[:write_property]` for remote-only
  targets, or `[:lookup_object, :write_property]` if any normalized target is local. Explicit
  self-device references count as local when the context supplies the matching device identifier.
  The function neither checks callback availability nor invokes callbacks - availability can be
  checked through `BACnet.Protocol.ObjectExecution.Context.require_operations/2`.

  Invalid references violate the precondition and can raise `MatchError`.

  ## Example

      iex> alias BACnet.Protocol.{DeviceObjectPropertyRef, ObjectIdentifier}
      iex> alias BACnet.Protocol.ObjectExecution.{Context, ScheduleTargets}
      iex> reference = %DeviceObjectPropertyRef{
      ...>   device_identifier: %ObjectIdentifier{type: :device, instance: 42},
      ...>   object_identifier: %ObjectIdentifier{type: :binary_output, instance: 700},
      ...>   property_identifier: :present_value, property_array_index: nil}
      iex> context = Context.new(:initialization, now: ~U[2026-11-09 08:00:00Z], monotonic_time: 0)
      iex> ScheduleTargets.validate_references([reference], context)
      :ok
      iex> ScheduleTargets.required_operations([reference], context)
      [:write_property]
      iex> ScheduleTargets.required_operations([%{reference | device_identifier: nil}], context)
      [:lookup_object, :write_property]
      iex> ScheduleTargets.required_operations([], context)
      []
  """
  @spec required_operations([DeviceObjectPropertyRef.t()], Context.t()) :: [atom()]
  def required_operations(references, context) do
    cond do
      references == [] ->
        []

      Enum.any?(references, fn reference ->
        {:ok, normalized} = normalize_reference(reference, context)
        is_nil(normalized.device_identifier)
      end) ->
        [:lookup_object, :write_property]

      true ->
        [:write_property]
    end
  end

  @spec prepare_local(
          DeviceObjectPropertyRef.t(),
          Encoding.t(),
          [Encoding.t()],
          1..16,
          Context.t()
        ) ::
          {:ok, Encoding.t()} | {:error, term()}
  defp prepare_local(reference, value, checked_values, priority, context) do
    with {:ok, object} <-
           Context.lookup_object(context, %DeviceObjectRef{
             object_identifier: reference.object_identifier,
             device_identifier: nil
           }),
         :ok <- validate_object(object, reference),
         {:ok, property} <- property_name(reference.property_identifier),
         :ok <- writable(object, property),
         {:ok, type} <- property_type(object, property, reference.property_array_index),
         annotations =
           if(reference.property_array_index == 0,
             do: [],
             else: object.__struct__.get_annotation(property)
           ),
         :ok <-
           validate_values(
             object,
             property,
             reference.property_array_index,
             type,
             annotations,
             checked_values,
             priority
           ) do
      {:ok, value}
    end
  end

  @spec normalize_reference(term(), Context.t()) ::
          {:ok, DeviceObjectPropertyRef.t()} | {:error, term()}
  defp normalize_reference(reference, context)

  defp normalize_reference(%DeviceObjectPropertyRef{} = reference, context) do
    cond do
      not DeviceObjectPropertyRef.valid?(reference) ->
        {:error, {:invalid_configuration, :list_of_object_property_references}}

      is_nil(reference.device_identifier) ->
        {:ok, reference}

      reference.device_identifier == context.device_identifier ->
        {:ok, %{reference | device_identifier: nil}}

      true ->
        {:ok, reference}
    end
  end

  defp normalize_reference(_reference, _context),
    do: {:error, {:invalid_configuration, :list_of_object_property_references}}

  @spec validate_object(term(), DeviceObjectPropertyRef.t()) :: :ok | {:error, term()}
  defp validate_object(object, reference)

  defp validate_object(%module{_metadata: %{remote_object: nil}} = object, reference) do
    if module.get_object_identifier(object) == reference.object_identifier,
      do: :ok,
      else: {:error, :object_identity_mismatch}
  end

  defp validate_object(%_module{_metadata: %{remote_object: remote}}, _reference)
       when not is_nil(remote),
       do: {:error, :object_not_local}

  defp validate_object(_object, _reference),
    do: raise(ArgumentError, "lookup_object must return a BACnet object with execution metadata")

  @spec property_name(atom() | non_neg_integer()) :: {:ok, atom()} | {:error, term()}
  defp property_name(property)

  defp property_name(property) when is_atom(property), do: {:ok, property}

  defp property_name(property) do
    case Constants.by_value(:property_identifier, property) do
      {:ok, name} -> {:ok, name}
      :error -> {:error, {:unknown_property, property}}
    end
  end

  @spec writable(struct(), atom()) :: :ok | {:error, term()}
  defp writable(%module{} = object, property) do
    command = property == :present_value and not is_nil(Map.get(object, :priority_array))
    annotation = module.get_annotation(property)[:readonly_when]

    conditional =
      case annotation do
        {key, value} -> Map.get(object, key) == value
        _other -> false
      end

    cond do
      not module.has_property?(object, property) ->
        {:error, {:unknown_property, property}}

      property in module.get_readonly_properties() or
          property in module.get_protected_properties() ->
        {:error, {:write_access_denied, property}}

      command ->
        :ok

      conditional or not module.property_writable?(object, property) ->
        {:error, {:write_access_denied, property}}

      true ->
        :ok
    end
  end

  @spec property_type(struct(), atom(), non_neg_integer() | nil) ::
          {:ok, term()} | {:error, term()}
  defp property_type(%module{} = object, property, index) do
    type = Map.fetch!(module.get_properties_type_map(), property)

    case {type, index} do
      {{:array, subtype}, index} -> array_type(object, property, subtype, index)
      {{:array, subtype, _size}, index} -> array_type(object, property, subtype, index)
      {_type, nil} -> {:ok, type}
      _other -> {:error, :property_is_not_an_array}
    end
  end

  @spec array_type(struct(), atom(), term(), non_neg_integer() | nil) ::
          {:ok, term()} | {:error, term()}
  defp array_type(%module{} = object, property, subtype, index) do
    with {:ok, %BACnetArray{} = array} <- module.get_property(object, property) do
      cond do
        index == 0 and is_nil(array.fixed_size) -> {:ok, :unsigned_integer}
        is_integer(index) and index > 0 and index <= array.size -> {:ok, subtype}
        true -> {:error, :invalid_array_index}
      end
    end
  end

  @spec validate_values(
          struct(),
          atom(),
          non_neg_integer() | nil,
          term(),
          keyword(),
          [Encoding.t()],
          1..16
        ) :: :ok | {:error, term()}
  defp validate_values(object, property, index, type, annotations, values, priority) do
    Enum.reduce_while(values, :ok, fn value, :ok ->
      with {:ok, converted} <- cast_value(object, property, index, type, value, annotations),
           {:ok, _candidate} <- validate_candidate(object, property, index, converted, priority) do
        {:cont, :ok}
      else
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  @spec validate_candidate(struct(), atom(), non_neg_integer() | nil, term(), 1..16) ::
          {:ok, struct()} | {:error, term()}
  defp validate_candidate(object, property, index, value, priority)

  # Length writes require property-specific default initialization by the host.
  defp validate_candidate(object, _property, 0, value, _priority)
       when is_integer(value) and value >= 0,
       do: {:ok, object}

  defp validate_candidate(_object, _property, 0, _value, _priority),
    do: {:error, :invalid_property_value}

  defp validate_candidate(%module{} = object, property, nil, value, priority) do
    if property == :present_value and not is_nil(Map.get(object, :priority_array)),
      do: module.set_priority(object, priority, value),
      else: module.update_property(object, property, value)
  end

  defp validate_candidate(%module{} = object, property, index, value, _priority) do
    with {:ok, array} <- module.get_property(object, property),
         {:ok, array} <- BACnetArray.set_item(array, index, value) do
      module.update_property(object, property, array)
    end
  end

  @spec cast_value(struct(), atom(), non_neg_integer() | nil, term(), Encoding.t(), keyword()) ::
          {:ok, term()} | {:error, term()}
  defp cast_value(object, property, index, type, encoding, annotations)

  defp cast_value(
         object,
         :present_value,
         nil,
         _type,
         %Encoding{type: :null} = encoding,
         _annotations
       ) do
    if ObjectsUtility.has_priority_array?(object),
      do: {:ok, nil},
      else:
        ObjectsUtility.cast_property_to_value(
          object.__struct__.get_object_identifier(object),
          :present_value,
          encoding
        )
  end

  # Index zero writes the array length. Conversion of array elements does not apply here.
  defp cast_value(
         _object,
         _property,
         0,
         :unsigned_integer,
         %Encoding{type: :unsigned_integer, value: length},
         _annotations
       )
       when is_integer(length) and length >= 0,
       do: {:ok, length}

  defp cast_value(_object, _property, 0, _type, _encoding, _annotations),
    do: {:error, :invalid_property_value}

  defp cast_value(object, property, index, type, encoding, annotations) do
    with {:ok, value} <-
           ObjectsUtility.cast_property_to_value(
             object.__struct__.get_object_identifier(object),
             property,
             encoding,
             allow_partial: not is_nil(index),
             allow_numeric_constants: true
           ),
         :ok <- validate_wire_type(type, value, encoding, annotations) do
      {:ok, value}
    end
  end

  @spec validate_wire_type(term(), term(), Encoding.t(), keyword()) :: :ok | {:error, term()}
  defp validate_wire_type(type, value, encoding, annotations)

  defp validate_wire_type(_type, _value, %Encoding{type: :null}, _annotations), do: :ok

  defp validate_wire_type({:type_list, types}, value, encoding, annotations) do
    if Enum.any?(types, fn type ->
         BeamTypes.check_type(type, value) == true and
           validate_wire_type(type, value, encoding, annotations) == :ok
       end),
       do: :ok,
       else: {:error, :datatype_not_supported}
  end

  defp validate_wire_type(type, value, encoding, annotations) do
    check_encoder(
      annotations[:encoder],
      value,
      encoding.type,
      expected_wire_type(type, value, annotations)
    )
  end

  @spec expected_wire_type(term(), term(), keyword()) :: atom() | nil
  defp expected_wire_type(type, value, annotations)

  defp expected_wire_type(
         {:struct, Encoding},
         %Encoding{encoding: :primitive} = value,
         _annotations
       ) do
    if Keyword.has_key?(value.extras, :encoder), do: nil, else: value.type
  end

  defp expected_wire_type({:struct, Encoding}, _value, _annotations), do: nil

  defp expected_wire_type(type, _value, annotations),
    do: annotations[:encode_as] || wire_type(type)

  @spec codec_result(term()) :: {:ok, term()} | {:error, term()}
  defp codec_result(result)

  defp codec_result({:ok, _value} = result), do: result
  defp codec_result({:error, _reason} = result), do: result
  defp codec_result(value), do: {:ok, value}

  @spec check_encoder((term() -> term()) | nil, term(), atom(), atom() | nil) ::
          :ok | {:error, term()}
  defp check_encoder(encoder, value, type, expected)

  defp check_encoder(nil, _value, type, expected)
       when expected == type,
       do: :ok

  defp check_encoder(nil, _value, _type, _expected), do: {:error, :datatype_not_supported}

  defp check_encoder(encoder, value, type, _expected) do
    case invoke_codec(encoder, value) do
      {:ok, %Encoding{encoding: :primitive, type: ^type}} -> :ok
      {:ok, {^type, _value}} -> :ok
      {:error, _reason} = error -> error
      _other -> {:error, :datatype_not_supported}
    end
  end

  @spec invoke_codec((term() -> term()), term()) :: {:ok, term()} | {:error, term()}
  defp invoke_codec(codec, value) do
    codec_result(codec.(value))
  rescue
    error in [FunctionClauseError, ArgumentError, MatchError, CaseClauseError] ->
      {:error, {:invalid_target_encoding, error.__struct__}}
  end

  @spec wire_type(term()) :: atom() | nil
  defp wire_type(type)

  defp wire_type(:string), do: :character_string
  defp wire_type({:constant, _category}), do: :enumerated
  defp wire_type({:in_range, low, _high}) when low < 0, do: :signed_integer
  defp wire_type({:in_range, _low, _high}), do: :unsigned_integer
  defp wire_type({:struct, BACnetDate}), do: :date
  defp wire_type({:struct, BACnetTime}), do: :time
  defp wire_type({:struct, ObjectIdentifier}), do: :object_identifier

  defp wire_type({:struct, module}) do
    if function_exported?(module, :from_bitstring, 1) and
         function_exported?(module, :to_bitstring, 1), do: :bitstring, else: nil
  end

  defp wire_type(type) when is_atom(type), do: type
  defp wire_type(_type), do: nil
end
