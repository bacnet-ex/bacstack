defmodule BACnet.Protocol.ObjectTypes.TrendLogMultiple do
  @moduledoc """
  A Trend Log Multiple captures related readings in one record. For example,
  sample supply temperature, return temperature, valve position and airflow
  together. Each record has one timestamp and a value or failure for each
  configured reference.

  The object supports clock alignment, a collection window, a bounded buffer and
  optional BUFFER_READY intrinsic reporting. Clients retrieve history using
  `BACnet.Protocol.Services.ReadRange`.

  ### Object Description (ASHRAE 135)

  > A Trend Log Multiple object monitors one or more properties of one or more
  > referenced objects, either in the same device as the Trend Log Multiple object
  > or in an external device. When predefined conditions are met,
  > the object saves ("logs") the value of the properties and a timestamp into
  > an internal buffer for subsequent retrieval.
  >
  > Trend Log Multiple objects that support intrinsic reporting shall
  > apply the BUFFER_READY event algorithm.

  ### Behaviour and Operation

  `log_device_object_property` is a `BACnet.Protocol.BACnetArray` of references
  to local or remote properties. A sample holds the values and errors in the
  same order as the references. An uninitialized slot produces
  `PROPERTY/NO_PROPERTY_SPECIFIED` in that position.

  `logging_type` selects periodic collection (`:polled`) or collection on a
  false-to-true write to the optional `trigger` property (`:triggered`).
  For a write of `:cov`, return `PROPERTY/VALUE_OUT_OF_RANGE` to the client.
  In polled mode, `log_interval` is in hundredths of a second. The optional `align_intervals`
  and `interval_offset` properties configure local clock alignment. The offset
  is also in hundredths of a second. Supplying either property adds its
  partner with a default of `align_intervals: false` or `interval_offset: 0`.

  Collection requires `enable` and local time at or after `start_time` and
  before `stop_time`. An unspecified bound leaves that side of the window
  open. With `stop_when_full` false, new records overwrite the oldest when the
  buffer reaches `buffer_size`. With `stop_when_full` true, the final slot
  records that collection stopped and `enable` becomes false.

  `record_count` is the number of records in the buffer. `total_record_count` is
  the latest sequence number and wraps from the maximum unsigned 32-bit value
  to 1. See `BACnet.Stack.TrendLogger` for acquisition and scheduling details.

  ### Lifecycle

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  supplies a running `t:BACnet.Stack.TrendLogger.server/0` as `:trend_logger`
  in `BACnet.Protocol.ObjectExecution.Context` options. Execute with
  `:initialization` to register or refresh a local log. Use the same logger for
  subsequent steps and call `BACnet.Stack.TrendLogger.remove_object/2` when
  removing the object. Remote snapshots execute passively.

  Refresh the object before serving live properties or preparing a write that
  depends on the buffer state. Prepare writes through
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3` and execute each
  committed write. Buffer_Size is writable while Enable is false. Enabling a
  full stop-when-full log returns `{:error, :log_buffer_full}`, which the host
  maps to `OBJECT/LOG_BUFFER_FULL`.

  Write zero to Record_Count to clear the history. Changing the ordered
  reference array also clears it. The logger starts the cleared buffer with
  a purge record, advances Total_Record_Count and resets
  Records_Since_Notification when present.

  A true Trigger write in triggered mode returns Trigger true and requests an
  immediate continuation. Commit that result before running the continuation.
  The continuation requests one sample if collection is enabled. It clears
  Trigger after the acquisition settles or is skipped. See
  `BACnet.Stack.TrendLogger.sample/2` for the acquisition contract.
  A true Trigger write in polled mode returns
  `{:error, :not_configured_for_triggered_logging}`, which the host maps to
  `PROPERTY/NOT_CONFIGURED_FOR_TRIGGERED_LOGGING`.

  The local object's `log_buffer` stays empty. To serve
  `BACnet.Protocol.Services.ReadRange`, capture the sequence number and buffer
  together with `get_log_buffer/2`.

  ### Intrinsic Reporting

  With `intrinsic_reporting: true`, the log's lifecycle evaluates BUFFER_READY
  against the current counters and reporting settings. Configure the
  `notification_receiver` described by `BACnet.Stack.TrendLogger.start_link/1`
  and schedule a `:periodic` execution of the current log when the receiver
  gets an `:intrinsic_reporting` message. The execution consumes the threshold
  when it records a NORMAL transition for Log_Buffer. Collection continues
  during reporting inhibition, with the threshold pending for reevaluation.
  The host retrieves the transition after commit with
  `BACnet.Protocol.ObjectExecution.EventReporting.transition/1`.

  ### Examples

  Creating a Trend Log Multiple:

      iex> alias BACnet.Protocol.{DeviceObjectPropertyRef, ObjectIdentifier, BACnetArray}
      iex> ref = %DeviceObjectPropertyRef{object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1}, property_identifier: :present_value, property_array_index: nil, device_identifier: nil}
      iex> {:ok, tlm} = BACnet.Protocol.ObjectTypes.TrendLogMultiple.create(1000, "MultiTrend", %{log_device_object_property: BACnetArray.from_list([ref]), buffer_size: 100, logging_type: :polled, log_interval: 60}); tlm.object_name
      "MultiTrend"

  With special options:

      iex> alias BACnet.Protocol.{DeviceObjectPropertyRef, ObjectIdentifier, BACnetArray}
      iex> ref = %DeviceObjectPropertyRef{object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1}, property_identifier: :present_value, property_array_index: nil, device_identifier: nil}
      iex> {:ok, tlm} = BACnet.Protocol.ObjectTypes.TrendLogMultiple.create(1001, "AlignedMulti", %{log_device_object_property: BACnetArray.from_list([ref]), buffer_size: 50, logging_type: :polled, log_interval: 90_000, align_intervals: true, interval_offset: 3_000}, intrinsic_reporting: true); tlm.object_name
      "AlignedMulti"

  Acquiring a triggered sample:

      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> alias BACnet.Protocol.ObjectTypes.TrendLogMultiple
      iex> alias BACnet.Protocol.{BACnetArray, ObjectsMacro}
      iex> alias BACnet.Stack.TrendLogger
      iex> ref = ObjectsMacro.get_default_dev_object_ref()
      iex> {:ok, logger} = TrendLogger.start_link(lookup_cb: fn _reference ->
      ...>   {:error, %BACnet.Protocol.BACnetError{class: :object, code: :unknown_object}}
      ...> end)
      iex> {:ok, object} = TrendLogMultiple.create(1002, "Manual", %{
      ...>   log_device_object_property: BACnetArray.from_list([ref]), buffer_size: 8,
      ...>   logging_type: :triggered, log_interval: 0, trigger: false
      ...> })
      iex> context = Context.new(:initialization, options: [trend_logger: logger])
      iex> {:ok, stored} = Lifecycle.execute(object, context)
      iex> write = %{context | trigger: {:property_write, :trigger, nil, nil}, state: stored.state}
      iex> {:ok, candidate} = TrendLogMultiple.update_property(stored.object, :trigger, true)
      iex> {:ok, candidate} = Lifecycle.prepare_write(stored.object, candidate, write)
      iex> {:ok, acquiring} = Lifecycle.execute(candidate, write)
      iex> {acquiring.object.trigger, acquiring.next_execution}
      {true, :immediate}
      iex> continuation = %{context | trigger: :continuation, state: acquiring.state}
      iex> {:ok, completed} = Lifecycle.execute(acquiring.object, continuation)
      iex> {completed.object.trigger, completed.object.record_count}
      {false, 1}
      iex> {:ok, {1, module, buffer}} = TrendLogMultiple.get_log_buffer(completed.object, context)
      iex> [record] = module.read_range(buffer, 0, 1)
      iex> Enum.map(record.log_data, & &1.code)
      [:no_property_specified]
      iex> GenServer.stop(logger)
      :ok

  ### See Also
  - `BACnet.Protocol.LogMultipleRecord`
  - `BACnet.Protocol.EventAlgorithms.BufferReady`
  - `BACnet.Protocol.Services.ReadRange`
  - `BACnet.Stack.TrendLogger`
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.LogMultipleRecord
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.LogLifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Stack.LogBufferBehaviour
  alias BACnet.Stack.TrendLogger

  require Constants
  use ObjectsMacro

  @logger_properties [
    :align_intervals,
    :buffer_size,
    :enable,
    :interval_offset,
    :log_device_object_property,
    :log_interval,
    :logging_type,
    :notification_threshold,
    :start_time,
    :stop_time,
    :stop_when_full
  ]
  @readonly_log_properties [
    :log_buffer,
    :total_record_count,
    :records_since_notification,
    :last_notify_record
  ]

  @typedoc """
  Options accepted when creating or configuring a Trend Log Multiple object.

  In addition to the common options, Trend Log Multiple supports:
  - `intrinsic_reporting` - Enables BUFFER_READY intrinsic reporting.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()}
          | common_object_opts()

  @typedoc """
  Represents a Trend Log Multiple object. Treat struct fields as read-only. Use the object module's
  property functions to build updates.

  Create the object with `intrinsic_reporting: true` to select its intrinsic
  reporting properties. The fields for those properties are `nil` when omitted.
  """
  bac_object Constants.macro_assert_name(:object_type, :trend_log_multiple) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:enable, boolean(), required: true, default: true)

    # These properties are required if the monitored property is a BACnet property
    # I'd say it's always required since we always monitor a BACnet property?
    field(:start_time, BACnetDateTime.t(),
      required: true,
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    field(:stop_time, BACnetDateTime.t(),
      required: true,
      default: ObjectsMacro.get_default_bacnet_datetime()
    )

    field(:log_device_object_property, BACnetArray.t(DeviceObjectPropertyRef.t()), required: true)
    field(:log_interval, non_neg_integer(), required: true)

    field(:cov_resubscription_interval, pos_integer())
    field(:client_cov_increment, float() | nil)

    field(:stop_when_full, boolean(), required: true, default: false)

    field(:buffer_size, ApplicationTags.unsigned32(),
      required: true,
      readonly: true,
      validator_fun: &(&1 >= 1 and &1 <= 4_294_967_295)
    )

    # Log_Buffer property can only be read through Read-Range service
    field(:log_buffer, [LogMultipleRecord.t()],
      readonly: true,
      required: true,
      default: [],
      remote_default: true,
      validator_fun:
        &(Enum.count_until(&1, fn _any -> true end, &2[:buffer_size] + 1) <= &2[:buffer_size])
    )

    field(:record_count, ApplicationTags.unsigned32(),
      required: true,
      default: 0
    )

    field(:total_record_count, ApplicationTags.unsigned32(),
      required: true,
      readonly: true,
      default: 0
    )

    # Logging Type MUST NOT be COV for Trend Log Multiple
    field(:logging_type, Constants.logging_type(), required: true, validator_fun: &(&1 != :cov))

    # The following two properties are required if clock-aligned logging is supported (we do)
    field(:align_intervals, boolean(),
      default: false,
      implicit_relationship: :interval_offset
    )

    field(:interval_offset, non_neg_integer(), default: 0)

    field(:trigger, boolean())

    field(:reliability, Constants.reliability(),
      implicit_relationship: :reliability_evaluation_inhibit
    )

    field(:reliability_evaluation_inhibit, boolean())

    field(:event_state, Constants.event_state(), required: true, default: :normal)

    # Intrinsic Reporting
    field(:notification_threshold, ApplicationTags.unsigned32(),
      intrinsic: true,
      default: 0
    )

    field(:records_since_notification, ApplicationTags.unsigned32(),
      readonly: true,
      intrinsic: true,
      default: 0
    )

    field(:last_notify_record, ApplicationTags.unsigned32(),
      readonly: true,
      intrinsic: true,
      default: 0
    )
  end

  # Override property_writable?/2, to be able to override :buffer_size, :log_interval behaviour
  # (writable if logging_type != :triggered)
  # When writing buffer_size, it may only when trend_log is not enabled
  @spec property_writable?(t(), Constants.property_identifier()) :: boolean()
  def property_writable?(%__MODULE__{} = object, property) when is_atom(property) do
    case property do
      :buffer_size ->
        not object.enable

      :log_interval ->
        object.logging_type != Constants.macro_assert_name(:logging_type, :triggered)

      _term ->
        super(object, property)
    end
  end

  @spec update_property(t(), Constants.property_identifier(), term()) ::
          {:ok, t()} | {:error, term()}
  def update_property(object, property, value)

  # Preserve the mode selection for direct Log_Interval writes.
  def update_property(%__MODULE__{} = object, :log_interval, value)
      when is_integer(value) and value >= 0 do
    mode = if value == 0, do: :triggered, else: :polled

    with {:ok, configured} <- super(object, :logging_type, mode) do
      super(configured, :log_interval, value)
    end
  end

  def update_property(%__MODULE__{}, :record_count, value) when value != 0 do
    {:error, {:invalid_property_value, :record_count}}
  end

  def update_property(%__MODULE__{} = object, property, value) when is_atom(property) do
    super(object, property, value)
  end

  @doc """
  Returns the logger's buffer for a registered local Trend Log Multiple.

  Uses the `:trend_logger` option in the execution context and returns
  `{:ok, {sequence_number, buffer_module, buffer}}`. Use the captured buffer
  with its module's `c:BACnet.Stack.LogBufferBehaviour.read_range/3` callback.
  The sequence number belongs to that same capture.

  An unregistered log returns `{:error, :unknown_object}`. Remote snapshots
  return `{:error, :operation_not_available_for_remote_objects}`.
  """
  @doc group: "Functions Operational"
  @spec get_log_buffer(t(), Context.t()) ::
          {:ok,
           {sequence_number :: non_neg_integer(), buffer_module :: module(),
            buffer :: LogBufferBehaviour.t()}}
          | {:error, term()}
  def get_log_buffer(object, context)

  def get_log_buffer(%__MODULE__{_metadata: %{remote_object: remote}}, %Context{})
      when not is_nil(remote),
      do: {:error, :operation_not_available_for_remote_objects}

  def get_log_buffer(%__MODULE__{} = object, %Context{} = context) do
    with {:ok, logger} <- LogLifecycle.get_logger(context) do
      TrendLogger.get_buffer(logger, object)
    end
  end

  @doc """
  Checks the shape of the local log's `:trend_logger` execution option.
  Local Trend Log Multiple objects reject COV logging.
  Remote snapshots pass preflight without a logger.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec validate_execution(t(), Context.t()) :: :ok | {:error, term()}
  def validate_execution(object, context)

  def validate_execution(%__MODULE__{_metadata: %{remote_object: remote}}, %Context{})
      when not is_nil(remote), do: :ok

  def validate_execution(%__MODULE__{logging_type: :cov}, %Context{}),
    do: {:error, :invalid_logging_type}

  def validate_execution(%__MODULE__{}, %Context{} = context) do
    with {:ok, _logger} <- LogLifecycle.get_logger(context), do: :ok
  end

  @doc """
  Checks access to logger-owned properties, zero-only Record_Count writes,
  and Enable writes against a full stop-when-full buffer.
  Also checks Buffer_Size and Log_Interval access and whether a triggered sample can start.
  The logger applies the accepted write during execution.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec prepare_write(t(), t(), Context.t()) :: {:ok, t()} | {:error, term()}
  def prepare_write(original, candidate, context)

  def prepare_write(%__MODULE__{_metadata: %{remote_object: remote}}, _candidate, %Context{})
      when not is_nil(remote), do: {:error, :operation_not_available_for_remote_objects}

  def prepare_write(
        %__MODULE__{} = original,
        %__MODULE__{} = candidate,
        %Context{trigger: {source, _property, _index, _priority}} = context
      )
      when source in [:property_write, :application_write] do
    LogLifecycle.prepare_write(original, candidate, context, @readonly_log_properties)
  end

  @doc """
  Runs one log lifecycle step against the configured logger.

  Initialization registers the log. Committed logger-property writes update
  the logger, and a zero Record_Count write purges the buffer.
  An accepted Trigger write requests an immediate sampling continuation.
  The result contains the latest counters and any recorded reporting transition.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec execute(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  def execute(object, context)

  def execute(%__MODULE__{_metadata: %{remote_object: remote}} = object, %Context{} = context)
      when not is_nil(remote), do: super(object, context)

  def execute(%__MODULE__{} = object, %Context{} = context) do
    LogLifecycle.execute(object, context, @logger_properties)
  end

  # Patch invalid log_interval values for the logging_type
  @spec inhibit_object_check(
          t(),
          t() | nil,
          ObjectOperations.property_operation(),
          ObjectOperations.property_operation_args()
        ) :: {:ok, t()}
  defp inhibit_object_check(object, original, operation, args)

  defp inhibit_object_check(
         %{logging_type: :polled, log_interval: 0} = object,
         _original,
         _operation,
         _args
       ),
       do: {:ok, %{object | log_interval: 1}}

  defp inhibit_object_check(
         %{logging_type: :triggered, log_interval: log} = object,
         _original,
         _operation,
         _args
       )
       when log > 0,
       do: {:ok, %{object | log_interval: 0}}

  defp inhibit_object_check(object, _original, _operation, _args), do: {:ok, object}
end
