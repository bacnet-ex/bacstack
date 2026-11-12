defmodule BACnet.Protocol.ObjectTypes.TrendLog do
  @moduledoc """
  A Trend Log records timestamped samples of one local or remote property.
  Configure the source in `log_device_object_property` and choose how to
  sample it - on a timer, on change of value, or on demand.

  The log supports clock-aligned start times, a logging window (start/stop time),
  enable/disable, and a `buffer_size` that determines how many records are kept
  before old ones are overwritten. Records are retrieved with the
  `BACnet.Protocol.Services.ReadRange` service.
  When `intrinsic_reporting: true` the object can emit a BUFFER_READY event so that
  a workstation knows new trend data is available for harvesting.

  ### Object Description (ASHRAE 135)

  > A Trend Log object monitors a property of a referenced object and,
  > when predefined conditions are met, saves ("logs") the value of the property
  > and a timestamp in an internal buffer for subsequent retrieval.
  >
  > Trend Log objects that support intrinsic reporting shall apply the
  > BUFFER_READY event algorithm.

  ### Behaviour and Operation

  `log_device_object_property` identifies the monitored property, including its
  array index and device identifier when supplied. `logging_type` determines
  when the object collects a sample.

  - `:polled` collects at the cadence set by `log_interval`, in hundredths of a
    second. The optional `align_intervals` and `interval_offset` properties
    configure local clock alignment. The offset is also in hundredths of a second.
    Supplying either property adds its partner with a default of
    `align_intervals: false` or `interval_offset: 0`.
  - `:cov` collects on change-of-value notifications for the monitored property.
    For remote subscriptions, `cov_resubscription_interval` sets the renewal
    interval in seconds and `client_cov_increment` sets the requested COV increment.
  - `:triggered` collects when a write changes the optional `trigger` property
    from false to true.

  Collection requires `enable` to be true and local time to be at or after
  `start_time` and before `stop_time`. An unspecified bound leaves that side
  of the window open. With `stop_when_full` false, new records overwrite the
  oldest when the buffer reaches `buffer_size`. With `stop_when_full` true,
  the log uses the final slot for a disabling status record and clears
  `enable`.

  A `BACnet.Protocol.LogRecord` pairs a timestamp with a sampled value, an
  acquisition error, a status change or a clock change. `record_count` is the
  number of records in the buffer. `total_record_count` tracks the latest record's
  sequence number, wrapping from the maximum unsigned 32-bit value to 1.

  See `BACnet.Stack.TrendLogger` for acquisition, clock alignment and COV
  subscription mechanics.

  ### Lifecycle

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  supplies a running `t:BACnet.Stack.TrendLogger.server/0` as `:trend_logger`
  in `BACnet.Protocol.ObjectExecution.Context` options. Execute with
  `:initialization` to register or refresh a local log. Use the same logger
  for later executions and call `BACnet.Stack.TrendLogger.remove_object/2`
  when the object is removed. Remote object snapshots execute passively.

  Refresh the object before serving its live properties and before preparing
  a write that depends on logger state. Prepare writes with
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3` and execute each
  committed write. A zero write to Record_Count purges the buffer. Changing
  Log_DeviceObjectProperty also purges it, so later reads start with a purge
  status record followed by samples of the new reference. A full buffer with
  Stop_When_Full set rejects a true Enable write with
  `{:error, :log_buffer_full}`. The host maps that error to
  `OBJECT/LOG_BUFFER_FULL`. Buffer_Size is writable while Enable is false.

  When the optional Trigger property is present, a true write in triggered
  mode returns Trigger true and requests an immediate continuation. Commit
  that result before calling the continuation. The continuation asks the logger
  for one sample and returns Trigger false, including when a lookup failure was
  recorded or collection was disabled. For a true write in polled or COV mode,
  return `PROPERTY/NOT_CONFIGURED_FOR_TRIGGERED_LOGGING` at the service
  boundary. See `BACnet.Stack.TrendLogger.sample/2` for the lookup callback
  contract. The callback must avoid synchronously calling back into a blocked
  host.

  The logger owns the history, time window and poll scheduling. The local
  object's `log_buffer` stays empty. To serve
  `BACnet.Protocol.Services.ReadRange`, capture the buffer and sequence number
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

  Creating a basic Trend Log (polled logging):

      iex> alias BACnet.Protocol.{DeviceObjectPropertyRef, ObjectIdentifier}
      iex> ref = %DeviceObjectPropertyRef{object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1}, property_identifier: :present_value, property_array_index: nil, device_identifier: nil}
      iex> {:ok, tl} = BACnet.Protocol.ObjectTypes.TrendLog.create(900, "TempTrend", %{log_device_object_property: ref, log_interval: 60, buffer_size: 100, logging_type: :polled}); tl.object_name
      "TempTrend"

  With clock-aligned logging and intrinsic reporting:

      iex> alias BACnet.Protocol.{DeviceObjectPropertyRef, ObjectIdentifier}
      iex> ref = %DeviceObjectPropertyRef{object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1}, property_identifier: :present_value, property_array_index: nil, device_identifier: nil}
      iex> {:ok, tl} = BACnet.Protocol.ObjectTypes.TrendLog.create(901, "AlignedTrend", %{log_device_object_property: ref, log_interval: 90_000, buffer_size: 50, logging_type: :polled, align_intervals: true, interval_offset: 3_000}, intrinsic_reporting: true); tl.object_name
      "AlignedTrend"

  Registering a triggered log and performing a manual sample:

      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> alias BACnet.Protocol.ObjectTypes.TrendLog
      iex> alias BACnet.Stack.TrendLogger
      iex> error = %BACnet.Protocol.BACnetError{class: :object, code: :unknown_object}
      iex> {:ok, logger} = TrendLogger.start_link(lookup_cb: fn _reference -> {:error, error} end)
      iex> ref = %BACnet.Protocol.DeviceObjectPropertyRef{
      ...>   object_identifier: %BACnet.Protocol.ObjectIdentifier{type: :analog_input, instance: 1},
      ...>   property_identifier: :present_value, property_array_index: nil, device_identifier: nil
      ...> }
      iex> {:ok, object} = TrendLog.create(902, "Manual", %{
      ...>   log_device_object_property: ref, buffer_size: 8, logging_type: :triggered,
      ...>   log_interval: 0, trigger: false
      ...> })
      iex> context = Context.new(:initialization, options: [trend_logger: logger])
      iex> {:ok, stored} = Lifecycle.execute(object, context)
      iex> write = %{context | trigger: {:property_write, :trigger, nil, nil}, state: stored.state}
      iex> {:ok, candidate} = TrendLog.update_property(stored.object, :trigger, true)
      iex> {:ok, candidate} = Lifecycle.prepare_write(stored.object, candidate, write)
      iex> {:ok, acquiring} = Lifecycle.execute(candidate, write)
      iex> {acquiring.object.trigger, acquiring.next_execution}
      {true, :immediate}
      iex> next = %{context | trigger: :continuation, state: acquiring.state}
      iex> {:ok, stored} = Lifecycle.execute(acquiring.object, next)
      iex> {stored.object.trigger, stored.object.record_count, stored.object.log_buffer}
      {false, 1, []}
      iex> GenServer.stop(logger)
      :ok

  ### See Also
  - `BACnet.Protocol.LogRecord`
  - `BACnet.Protocol.EventAlgorithms.BufferReady`
  - `BACnet.Protocol.Services.ReadRange`
  - `BACnet.Stack.TrendLogger`
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.LogRecord
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
    :client_cov_increment,
    :cov_resubscription_interval,
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
  Options accepted when creating or configuring a Trend Log object.

  In addition to the common options, Trend Log supports:
  - `intrinsic_reporting` - Enables BUFFER_READY intrinsic reporting (notifications when
    Notification_Threshold records have been collected).
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()}
          | common_object_opts()

  @typedoc """
  Represents a Trend Log object. Treat struct fields as read-only. Use the object module's
  property functions to build updates.

  Create the object with `intrinsic_reporting: true` to select its intrinsic
  reporting properties. The fields for those properties are `nil` when omitted.
  """
  bac_object Constants.macro_assert_name(:object_type, :trend_log) do
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

    field(:log_device_object_property, DeviceObjectPropertyRef.t(), required: true)
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
    field(:log_buffer, [LogRecord.t()],
      readonly: true,
      required: true,
      default: [],
      remote_default: true,
      validator_fun:
        &(Enum.count_until(&1, fn _any -> true end, &2[:buffer_size] + 1) <= &2[:buffer_size])
    )

    field(:record_count, ApplicationTags.unsigned32(), required: true, default: 0)

    field(:total_record_count, ApplicationTags.unsigned32(),
      required: true,
      readonly: true,
      default: 0
    )

    field(:logging_type, Constants.logging_type(), required: true, default: :cov)

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

  # A Log_Interval write selects the corresponding mode for pre-revision-14 clients.
  def update_property(%__MODULE__{} = object, :log_interval, value)
      when is_integer(value) and value >= 0 do
    mode = if value == 0, do: :cov, else: :polled

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
  Returns the logger's buffer for a registered local Trend Log.

  Uses the `:trend_logger` option in the execution context and returns
  `{:ok, {sequence_number, buffer_module, buffer}}`. Use the captured buffer
  with its module's `c:BACnet.Stack.LogBufferBehaviour.read_range/3` callback.
  The sequence number belongs to that same capture.

  An unregistered log returns `{:error, :unknown_object}`. Remote snapshots
  return `{:error, :operation_not_available_for_remote_objects}`.
  """
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
  Remote snapshots pass preflight without a logger.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec validate_execution(t(), Context.t()) :: :ok | {:error, term()}
  def validate_execution(object, context)

  def validate_execution(%__MODULE__{_metadata: %{remote_object: remote}}, %Context{})
      when not is_nil(remote), do: :ok

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
         %{logging_type: :cov, log_interval: log} = object,
         _original,
         _operation,
         _args
       )
       when log > 0,
       do: {:ok, %{object | log_interval: 0}}

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
