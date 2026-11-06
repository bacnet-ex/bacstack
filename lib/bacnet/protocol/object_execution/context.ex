defmodule BACnet.Protocol.ObjectExecution.Context do
  @moduledoc """
  Inputs and host operations for one BACnet object execution step.

  The caller supplies a fresh context for each call to
  `BACnet.Protocol.ObjectsProtocol.execute/2`:

  - `now` is the current wall time in the device's configured time zone. Use it
    for calendar and schedule calculations. Execution never reads the clock
    implicitly.
  - `monotonic_time` is the current monotonic time in milliseconds. Use it for
    elapsed durations and delays, which must not be affected by wall-clock
    adjustments. Its origin is arbitrary and its value may be negative.
  - `trigger` identifies why execution was requested: `:periodic`,
    `:initialization`, `:clock_change`, or
    `{:property_write, property_identifier, array_index, priority}`. A property
    write trigger is supplied after a successful write, with the updated object,
    even if the written value equals the previous value. Index and priority are
    `nil` when omitted. Invoke execution for each write before applying the next
    one, so the object contains the value for that trigger. The host delivers
    triggers; object property functions do not invoke `execute/2` themselves.
  - `state` is opaque runtime state owned by the object module. Supply `nil` for
    the first execution and the previous result's state on subsequent calls.
    Keep this state separately for each object instance; it is not a BACnet
    property and is not stored in the object's metadata. Monotonic timestamps
    in state are only meaningful within the same VM lifetime.
  - `lookup_object`, `read_property`, and `write_property` are optional host
    callbacks. They provide access to local or remote objects; they do not
    replace the executing object's behaviour. The helper functions in this
    module report `{:error, {:unsupported_operation, operation}}` when a
    callback is absent.
  - `options` holds object-specific configuration, documented by the object
    module. Common inputs above must use their named fields.

  References retain their device identifier and property array index. A missing
  device identifier denotes the executing object's local device. The host
  resolves references, checks access, handles transport and converts values
  to/from the Elixir property representations used by object modules. A write
  with priority `nil` has no explicit priority; it does not mean relinquish.

  Callbacks run synchronously in the executing process and return their results
  directly. They must bound any network waits. Exceptions and malformed callback
  results are programming errors and are not converted into operational errors.
  Writes take effect when the callback runs; execution offers no rollback.
  Callbacks must avoid calling back into a server that is blocked executing the
  object (for example, calling the same GenServer synchronously).
  """

  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.DeviceObjectRef

  @typedoc """
  Reason for this execution step. Property write metadata describes the write
  already applied to the executing object, rather than an instruction to write it.
  """
  @type trigger ::
          :periodic
          | :initialization
          | :clock_change
          | {:property_write, Constants.property_identifier() | non_neg_integer(),
             non_neg_integer() | nil, 1..16 | nil}

  @typedoc """
  Looks up a local or remote object.
  """
  @type lookup_object :: (DeviceObjectRef.t() -> {:ok, struct()} | {:error, term()})

  @typedoc """
  Reads a property, including its optional array index.
  """
  @type read_property :: (DeviceObjectPropertyRef.t() -> {:ok, term()} | {:error, term()})

  @typedoc """
  Writes a property value, with an optional explicit command priority.
  """
  @type write_property ::
          (DeviceObjectPropertyRef.t(), term(), 1..16 | nil -> :ok | {:error, term()})

  @typedoc """
  Caller-supplied inputs for one execution step.
  """
  @type t :: %__MODULE__{
          now: DateTime.t(),
          monotonic_time: integer(),
          trigger: trigger(),
          state: term(),
          lookup_object: lookup_object() | nil,
          read_property: read_property() | nil,
          write_property: write_property() | nil,
          options: Keyword.t()
        }

  @fields [
    :now,
    :monotonic_time,
    :trigger,
    :state,
    :lookup_object,
    :read_property,
    :write_property,
    :options
  ]
  @enforce_keys @fields
  defstruct @fields

  @doc """
  Looks up an object through the host callback, or reports the missing operation.
  """
  @spec lookup_object(t(), DeviceObjectRef.t()) :: {:ok, struct()} | {:error, term()}
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
  def read_property(%__MODULE__{read_property: callback}, %DeviceObjectPropertyRef{} = reference)
      when is_function(callback, 1) do
    callback.(reference)
  end

  def read_property(%__MODULE__{read_property: nil}, %DeviceObjectPropertyRef{}) do
    {:error, {:unsupported_operation, :read_property}}
  end

  @doc """
  Writes a property through the host callback, or reports the missing operation.

  Priority is `nil` (omitted) or an explicit slot from 1 to 16. A successful write
  returns `:ok`. The host is responsible for retaining updates to target objects.
  """
  @spec write_property(t(), DeviceObjectPropertyRef.t(), term(), 1..16 | nil) ::
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
end
