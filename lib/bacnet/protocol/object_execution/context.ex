defmodule BACnet.Protocol.ObjectExecution.Context do
  @moduledoc """
  Inputs and host operations for one BACnet object execution step.
  Clock samples, prior state and host callbacks for a lifecycle operation.

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  is the integrating application or higher-level BACnet stack that owns object instances and drives
  their lifecycle. That central contract defines the host responsibilities referred to here.

  Use `new/2` to build a context from a trigger and keyword options. For an existing instance,
  pass the last `BACnet.Protocol.ObjectExecution.Result`'s state as `state:`. Use the same
  clock samples for write preparation, execution and nested reads in one operation. For the
  next operation or an immediate continuation, build a new context with fresh samples and
  carry forward any host callbacks and options the instance needs.

    - `now` is the current wall time in the device's configured timezone. Lifecycle
    calculations use this sample. Backends such as `BACnet.Stack.TrendLogger`
    sample their configured clocks for record timestamps and collection windows.
  - `timezone_database` is the `Calendar.TimeZoneDatabase` module used to resolve future local
    deadlines, including timezone transitions. `new/2` uses `Calendar.get_time_zone_database/0`
    unless overridden. Regional zones need a database that supports them. Execution uses the
    database retained in the context.
  - `monotonic_time` is the current monotonic time in milliseconds. Use it for
    elapsed durations and delays, which must not be affected by wall-clock adjustments. Its origin
    is arbitrary and its value may be negative.
  - `trigger` identifies why the host called the lifecycle. See
    [entry points and triggers](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-entry-points-and-triggers)
    for when to use each `t:trigger/0`. In a write trigger, the array index and priority are `nil`
    when omitted. Preserve the write's origin - a local callback handling a BACnet command
    still uses `:property_write`. The object module documents how it handles application
    writes, including physical input, feedback and out-of-service simulation.
  - `state` is opaque runtime state owned by the object module. Supply `nil` for
    the first execution and the previous result's state on subsequent calls. Keep this state
    separately for each object instance - it is not a BACnet property and is not stored in the
    object's metadata. Monotonic timestamps in state are only meaningful within the same VM
    lifetime.
  - `lookup_object`, `read_property`, `read_property_multiple` and `write_property` are optional host
    callbacks. They provide access to local or remote objects - they do not replace the executing
    object's behaviour. The helper functions in this module report `{:error,
    {:unsupported_operation, operation}}` when a callback is absent.
  - `options` holds object-specific inputs, documented by the object module.
    For a qualified Logging_Record read on `BACnet.Protocol.ObjectTypes.Accumulator`,
    the host supplies the local reading object's identifier as `:reader_identifier`.
    Common inputs above must use their named fields.

  `device_identifier` is the local Device ObjectIdentifier, or `nil` when not needed.
  Supply the identifier when an object needs to distinguish an explicitly addressed self-device reference
  from a remote reference. Schedule normalizes recognized self references to local host operations
  and forwards other device-qualified references unchanged. Without a local identity, qualified
  references are forwarded as remote references.
  All struct fields must be supplied explicitly, including those set to `nil`. Use `new/2` to
  initialize every field from an explicit trigger and keyword fields, with fresh clock samples
  and common initial values for omitted fields.

  References retain their device identifier and property array index. A missing device identifier
  denotes the executing object's local device. The host needs to resolve references, check access,
  handle transport and apply writes. Write callbacks may receive an
  `BACnet.Protocol.ApplicationTags.Encoding`, a list of encodings, or an object's Elixir value,
  as documented by the executing object module. Schedule supplies encodings. Local adapters can
  decode them through `BACnet.Protocol.ObjectsUtility.cast_property_to_value/4` using the target
  object identifier and `allow_partial: true` for array elements. NULL command relinquishment and
  array length writes need to be handled by the local write path before ordinary property casting.
  Remote adapters can forward encodings directly to `BACnet.Stack.ClientHelper.write_property/6`.
  A write with priority `nil` has no explicit priority - it does not mean relinquish.

  `read_property_multiple` accepts a device/object reference and a list of properties or
  selectors, and returns a map of property identifiers to native values. Indexed results use
  `{property_identifier, array_index}` keys. Per-property failures use `{:error, reason}` values.
  Selectors follow ReadPropertyMultiple rules - see `BACnet.Protocol.ObjectTypes.Group`.
  Group converts these native values and builds its own `BACnet.Protocol.ReadAccessResult` values.

  Callbacks run synchronously in the executing process and return their results directly. They must
  bound any network waits. Exceptions and malformed callback results are programming errors and are
  not converted into operational errors. Writes take effect when the callback runs - execution offers
  no rollback. Callbacks must avoid calling back into a server that is blocked executing the object
  (for example, calling the same GenServer synchronously).
  """

  alias BACnet.Protocol.AccessSpecification
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.DeviceObjectRef
  alias BACnet.Protocol.ObjectIdentifier

  @typedoc "Origin of a proposed or committed property write."
  @type write_origin :: :property_write | :application_write

  @typedoc """
  Metadata for a proposed write during preparation or a committed write during execution.
  The property identifier may be a name or a numeric identifier.
  """
  @type write_trigger ::
          {write_origin(),
           property_identifier :: Constants.property_identifier() | non_neg_integer(),
           array_index :: non_neg_integer() | nil, priority :: 1..16 | nil}

  @typedoc "Reason for this lifecycle step."
  @type trigger ::
          :periodic
          | :initialization
          | :clock_change
          | :timer
          | :continuation
          | {:property_read, Constants.property_identifier() | non_neg_integer(),
             array_index :: non_neg_integer() | nil}
          | {:object_changed, DeviceObjectRef.t()}
          | write_trigger()

  @typedoc """
  Looks up a local or remote object.
  """
  @type lookup_object :: (DeviceObjectRef.t() -> {:ok, struct()} | {:error, term()})

  @typedoc """
  Reads a property, including its optional array index.

  Values follow the source property's native representation. Encodings can be retained when
  an adapter needs to preserve an arbitrary BACnet datatype.
  """
  @type read_property :: (DeviceObjectPropertyRef.t() ->
                            {:ok, value :: term()} | {:error, term()})

  @typedoc """
  A property result key. Unindexed results use the property identifier directly.

  Indexed results use `{property_identifier, array_index}`. The first element identifies
  the property by name or numeric identifier. The second is its BACnet array index:
  zero requests the array length, and positive indices select elements using one-based indexing.
  For example, `{:priority_array, 0}` identifies the length and `{:state_text, 1}` the first element.
  """
  @type property_result_key ::
          Constants.property_identifier()
          | non_neg_integer()
          | {property_identifier :: Constants.property_identifier() | non_neg_integer(),
             array_index :: non_neg_integer()}

  @typedoc """
  Reads properties or selectors of one object and returns native property values in a map.

  Indexed results use tuple keys. Per-property failures use `{:error, reason}` values, while
  a failure of the whole operation is returned as `{:error, reason}` instead of a map.
  Returned values use the source property's native representation. See `BACnet.Protocol.ObjectTypes.Group`.
  """
  @type read_property_multiple :: (DeviceObjectRef.t(),
                                   [
                                     AccessSpecification.Property.t()
                                     | Constants.property_identifier()
                                     | non_neg_integer()
                                   ] ->
                                     {:ok, %{optional(property_result_key()) => term()}}
                                     | {:error, term()})

  @typedoc """
  Writes a property value, with an optional explicit command priority.
  """
  @type write_property ::
          (DeviceObjectPropertyRef.t(),
           value :: Encoding.t() | [Encoding.t()] | term(),
           1..16
           | nil ->
             :ok | {:error, term()})

  @typedoc """
  Caller-supplied inputs for one execution step.
  """
  @type t :: %__MODULE__{
          now: DateTime.t(),
          timezone_database: module(),
          monotonic_time: integer(),
          trigger: trigger(),
          state: term(),
          lookup_object: lookup_object() | nil,
          read_property: read_property() | nil,
          read_property_multiple: read_property_multiple() | nil,
          write_property: write_property() | nil,
          options: Keyword.t(),
          device_identifier: ObjectIdentifier.t() | nil
        }

  @fields [
    :device_identifier,
    :now,
    :timezone_database,
    :monotonic_time,
    :trigger,
    :state,
    :lookup_object,
    :read_property,
    :read_property_multiple,
    :write_property,
    :options
  ]
  @enforce_keys @fields
  defstruct @fields

  @typedoc """
  Keyword fields accepted by `new/2`. The trigger is supplied separately.

  The `options` field holds object-specific options, separately from these constructor fields.
  """
  @type init_option ::
          {:device_identifier, ObjectIdentifier.t() | nil}
          | {:now, DateTime.t()}
          | {:timezone_database, module()}
          | {:monotonic_time, integer()}
          | {:state, term()}
          | {:lookup_object, lookup_object() | nil}
          | {:read_property, read_property() | nil}
          | {:read_property_multiple, read_property_multiple() | nil}
          | {:write_property, write_property() | nil}
          | {:options, Keyword.t()}

  @doc """
  Builds a context from a trigger and keyword options.

  When `now` is absent, `DateTime.now!/2` samples the wall clock using
  `config :bacstack, :default_timezone`, falling back to `"Etc/UTC"` when unconfigured. The timezone
  database defaults to `Calendar.get_time_zone_database/0` and can be overridden through the
  `timezone_database` field. Regional zones need a configured database that supports them.

  An omitted `monotonic_time` is sampled through `System.monotonic_time/1` in milliseconds.
  Explicit clock values are preserved - supplying `now` bypasses the configured timezone lookup.
  The `options` field defaults to `[]`. Runtime state, device identifier and host callbacks default
  to `nil`.

  Supply the previous result's `state` when executing an existing instance. Preparation, execution
  and nested reads within one operation need to share the same clock samples - create one context
  for that operation. The constructor's `options` field contains object-specific options - the
  outer keyword list configures the context itself.

  Raises `ArgumentError` for an invalid trigger, unknown field, invalid field value or a timezone
  that the selected database cannot resolve when sampling `now`.

  ## Examples

      iex> alias BACnet.Protocol.ObjectExecution.Context
      iex> context = Context.new(:initialization)
      iex> {context.trigger, context.device_identifier, context.state}
      {:initialization, nil, nil}
      iex> context.now.time_zone == Application.get_env(:bacstack, :default_timezone, "Etc/UTC")
      true
      iex> {context.lookup_object, context.read_property, context.write_property, context.options}
      {nil, nil, nil, []}

      iex> alias BACnet.Protocol.ObjectExecution.Context
      iex> context = Context.new(:timer, state: %{count: 3},
      ...>   now: ~U[2026-11-09 08:00:00Z], monotonic_time: -1000,
      ...>   options: [mode: :automatic])
      iex> {context.now, context.monotonic_time, context.state, context.options}
      {~U[2026-11-09 08:00:00Z], -1000, %{count: 3}, [mode: :automatic]}
  """
  @spec new(trigger(), [init_option()]) :: t()
  def new(trigger, fields \\ []) when is_list(fields) do
    if not valid_trigger?(trigger) do
      raise ArgumentError, "Invalid execution trigger, got: #{inspect(trigger)}"
    end

    if not Keyword.keyword?(fields) do
      raise ArgumentError, "Expected context fields as a keyword list, got: #{inspect(fields)}"
    end

    fields = Keyword.new(fields)

    timezone_database =
      Keyword.get_lazy(fields, :timezone_database, &Calendar.get_time_zone_database/0)

    Enum.reduce(
      fields,
      %__MODULE__{
        device_identifier: nil,
        now:
          Keyword.get_lazy(fields, :now, fn ->
            DateTime.now!(
              Application.get_env(:bacstack, :default_timezone, "Etc/UTC"),
              timezone_database
            )
          end),
        timezone_database: timezone_database,
        monotonic_time:
          Keyword.get_lazy(fields, :monotonic_time, fn -> System.monotonic_time(:millisecond) end),
        trigger: trigger,
        state: nil,
        lookup_object: nil,
        read_property: nil,
        read_property_multiple: nil,
        write_property: nil,
        options: []
      },
      &put_init_field/2
    )
  end

  @doc """
  Returns write metadata with a normalized property identifier, or nil for another trigger.

  Known numeric identifiers become their property names. Unknown identifiers
  stay numeric. The origin, index and priority are preserved.
  """
  @spec write_trigger(t()) :: write_trigger() | nil
  def write_trigger(context)

  def write_trigger(%__MODULE__{trigger: {origin, property, index, priority}})
      when origin in [:property_write, :application_write] do
    property =
      if is_integer(property),
        do: Constants.by_value(:property_identifier, property, property),
        else: property

    {origin, property, index, priority}
  end

  def write_trigger(%__MODULE__{}), do: nil

  @doc """
  Normalizes the property identifier in a write context.

  `BACnet.Protocol.ObjectExecution.Lifecycle` calls this before dispatching
  local writes to object callbacks.
  """
  @spec normalize_write(t()) :: t()
  def normalize_write(%__MODULE__{} = context) do
    case write_trigger(context) do
      nil -> context
      trigger -> %{context | trigger: trigger}
    end
  end

  @doc """
  Returns the normalized property identifier for a write, or nil.

  Pass an origin to select writes from that origin.
  """
  @spec written_property(t(), write_origin() | :any) ::
          Constants.property_identifier() | non_neg_integer() | nil
  def written_property(context, origin \\ :any) do
    case write_trigger(context) do
      {source, property, _index, _priority} when origin in [:any, source] -> property
      _other -> nil
    end
  end

  @doc """
  Returns the retained state for the step. Initialization starts with nil.
  """
  @spec previous_state(t()) :: term()
  def previous_state(%__MODULE__{} = context) do
    if context.trigger == :initialization, do: nil, else: context.state
  end

  @doc """
  Checks required host operations without invoking callbacks.

  Returns the first absent operation in the supplied order. Requirements belong to the object module
  and selected configuration: an empty target list, for example, need not require a write callback.
  Presence alone does not advertise support for remote targets or other optional capabilities.
  """
  @spec require_operations(t(), [
          :lookup_object | :read_property | :read_property_multiple | :write_property
        ]) ::
          :ok | {:error, {:unsupported_operation, atom()}}
  def require_operations(%__MODULE__{} = context, operations) when is_list(operations) do
    Enum.reduce_while(operations, :ok, fn operation, :ok ->
      if operation_available?(context, operation) do
        {:cont, :ok}
      else
        {:halt, {:error, {:unsupported_operation, operation}}}
      end
    end)
  end

  @spec operation_available?(t(), atom()) :: boolean()
  defp operation_available?(context, operation)

  defp operation_available?(context, :lookup_object), do: is_function(context.lookup_object, 1)
  defp operation_available?(context, :read_property), do: is_function(context.read_property, 1)

  defp operation_available?(context, :read_property_multiple),
    do: is_function(context.read_property_multiple, 2)

  defp operation_available?(context, :write_property), do: is_function(context.write_property, 3)

  @doc """
  Looks up an object through the host callback, or reports the missing operation.
  """
  @spec lookup_object(t(), DeviceObjectRef.t()) :: {:ok, struct()} | {:error, term()}
  def lookup_object(context, reference)

  def lookup_object(%__MODULE__{lookup_object: callback}, %DeviceObjectRef{} = reference)
      when is_function(callback, 1) do
    callback.(reference)
  end

  def lookup_object(%__MODULE__{lookup_object: nil}, %DeviceObjectRef{}) do
    {:error, {:unsupported_operation, :lookup_object}}
  end

  @doc """
  Reads a property through the host callback, or reports the missing operation.
  """
  @spec read_property(t(), DeviceObjectPropertyRef.t()) :: {:ok, term()} | {:error, term()}
  def read_property(context, reference)

  def read_property(%__MODULE__{read_property: callback}, %DeviceObjectPropertyRef{} = reference)
      when is_function(callback, 1) do
    callback.(reference)
  end

  def read_property(%__MODULE__{read_property: nil}, %DeviceObjectPropertyRef{}) do
    {:error, {:unsupported_operation, :read_property}}
  end

  @doc """
  Reads properties or selectors through the host callback and returns a native-value map.

  Property selectors are separate from ordinary single-property reads. The object module
  defines which operations it requires. See `t:read_property_multiple/0` for the map contract.
  """
  @spec read_property_multiple(t(), DeviceObjectRef.t(), [
          AccessSpecification.Property.t() | Constants.property_identifier() | non_neg_integer()
        ]) ::
          {:ok, %{optional(property_result_key()) => term()}} | {:error, term()}
  def read_property_multiple(context, reference, properties)

  def read_property_multiple(
        %__MODULE__{read_property_multiple: callback},
        %DeviceObjectRef{} = reference,
        properties
      )
      when is_function(callback, 2) and is_list(properties),
      do: callback.(reference, properties)

  def read_property_multiple(
        %__MODULE__{read_property_multiple: nil},
        %DeviceObjectRef{},
        properties
      )
      when is_list(properties), do: {:error, {:unsupported_operation, :read_property_multiple}}

  @doc """
  Writes a property through the host callback, or reports the missing operation.

  Priority is `nil` (omitted) or an explicit slot from 1 to 16. A successful write returns `:ok`.
  The value is forwarded unchanged, including a `BACnet.Protocol.ApplicationTags.Encoding` or
  list of encodings. The host needs to decode encodings for local writes or forward them to a
  remote write service, and retain updates to local target objects.
  """
  @spec write_property(
          t(),
          DeviceObjectPropertyRef.t(),
          Encoding.t() | [Encoding.t()] | term(),
          1..16 | nil
        ) ::
          :ok | {:error, term()}
  def write_property(context, reference, value, priority \\ nil)

  def write_property(
        %__MODULE__{write_property: callback},
        %DeviceObjectPropertyRef{} = reference,
        value,
        priority
      )
      when is_function(callback, 3) and (is_nil(priority) or priority in 1..16) do
    callback.(reference, value, priority)
  end

  def write_property(
        %__MODULE__{write_property: nil},
        %DeviceObjectPropertyRef{},
        _value,
        priority
      )
      when is_nil(priority) or priority in 1..16 do
    {:error, {:unsupported_operation, :write_property}}
  end

  @spec put_init_field(term(), t()) :: t()
  defp put_init_field(field, context)

  defp put_init_field({:device_identifier, nil}, context),
    do: %{context | device_identifier: nil}

  defp put_init_field({:device_identifier, %ObjectIdentifier{type: :device} = value}, context) do
    if ObjectIdentifier.valid?(value) do
      %{context | device_identifier: value}
    else
      raise ArgumentError, "Invalid value for field device_identifier, got: #{inspect(value)}"
    end
  end

  defp put_init_field({:now, %DateTime{} = value}, context), do: %{context | now: value}

  defp put_init_field({:timezone_database, value}, context)
       when is_atom(value) and not is_nil(value),
       do: %{context | timezone_database: value}

  defp put_init_field({:monotonic_time, value}, context) when is_integer(value),
    do: %{context | monotonic_time: value}

  defp put_init_field({:state, value}, context), do: %{context | state: value}

  defp put_init_field({:lookup_object, value}, context)
       when is_nil(value) or is_function(value, 1),
       do: %{context | lookup_object: value}

  defp put_init_field({:read_property, value}, context)
       when is_nil(value) or is_function(value, 1),
       do: %{context | read_property: value}

  defp put_init_field({:read_property_multiple, value}, context)
       when is_nil(value) or is_function(value, 2),
       do: %{context | read_property_multiple: value}

  defp put_init_field({:write_property, value}, context)
       when is_nil(value) or is_function(value, 3),
       do: %{context | write_property: value}

  defp put_init_field({:options, value}, context) when is_list(value) do
    if Keyword.keyword?(value) do
      %{context | options: value}
    else
      raise ArgumentError, "Invalid value for field options, got: #{inspect(value)}"
    end
  end

  defp put_init_field({field, value}, _context) when field in @fields do
    raise ArgumentError, "Invalid value for field #{field}, got: #{inspect(value)}"
  end

  defp put_init_field(field, _context) do
    raise ArgumentError, "Unknown context field, got: #{inspect(field)}"
  end

  @spec valid_trigger?(term()) :: boolean()
  defp valid_trigger?(trigger)

  defp valid_trigger?(trigger)
       when trigger in [:periodic, :initialization, :clock_change, :timer, :continuation],
       do: true

  defp valid_trigger?({:property_read, property, index})
       when ((is_atom(property) and property not in [nil, false, true]) or
               (is_integer(property) and property >= 0)) and
              (is_nil(index) or (is_integer(index) and index >= 0)),
       do: true

  defp valid_trigger?({source, property, index, priority})
       when source in [:property_write, :application_write] and
              ((is_atom(property) and property not in [nil, false, true]) or
                 (is_integer(property) and property >= 0)) and
              (is_nil(index) or (is_integer(index) and index >= 0)) and
              (is_nil(priority) or priority in 1..16),
       do: true

  defp valid_trigger?({:object_changed, %DeviceObjectRef{}}), do: true

  defp valid_trigger?(_trigger), do: false
end
