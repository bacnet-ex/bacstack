defmodule BACnet.Protocol.ObjectTypes.EventLog do
  @moduledoc """
  An Event Log stores timestamped
  `BACnet.Protocol.Services.ConfirmedEventNotification` and
  `BACnet.Protocol.Services.UnconfirmedEventNotification` records. Use
  `BACnet.Protocol.Services.ReadRange` to retrieve the alarm and event history.

  Records contain the full event information (source object, event type, message text,
  priority, etc.). The log can be configured as a fixed-size circular buffer or a
  growing one (until stopped or full). It supports a time window (`start_time` / `stop_time`),
  enable/disable, and can itself generate a BUFFER_READY intrinsic event (when
  `intrinsic_reporting: true`) when the log has new data worth harvesting.

  ### Object Description (ASHRAE 135)

  > An Event Log object records event notifications with timestamps and other
  > pertinent data in an internal buffer for subsequent retrieval.

  ### Behaviour and Operation

  The host selects which sent or received notifications go to each Event Log.
  Submit selected notifications with `BACnet.Stack.TrendLogger.trigger_log/3`.
  The logger timestamps each record in its configured timezone and applies
  Enable, Start_Time and Stop_Time before collecting an event. The buffer
  overwrites its oldest records or stops logging according to Stop_When_Full.

  ### Lifecycle

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  needs to supply a running `t:BACnet.Stack.TrendLogger.server/0` as
  `:trend_logger` in `BACnet.Protocol.ObjectExecution.Context` options. Execute
  with `:initialization` to register the local object. If that log is already
  registered, initialization reads its existing runtime state. Use the same
  logger throughout the lifetime of the object, and call
  `BACnet.Stack.TrendLogger.remove_object/2` when removing the object.

  Execution reads Enable and the record counters together from the logger.
  Refresh before serving live properties and before preparing a write that
  depends on the buffer state. Use
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_write/3` and then execute
  each committed write, including repeated writes of the same value. A zero
  write to Record_Count purges the log and adds a buffer-purged status record.
  An Enable write that would start a full stop-when-full log returns
  `{:error, :log_buffer_full}`. The logger also checks this condition when
  applying the write. The host needs to return `OBJECT/LOG_BUFFER_FULL` at the
  service boundary and refresh the object if the logger rejected the commit.

  The logger owns the history and the time checks. The local object's
  `log_buffer` list stays empty during execution. To serve
  `BACnet.Protocol.Services.ReadRange` for Log_Buffer, use
  `BACnet.Stack.TrendLogger.get_snapshot/2` and take the records and sequence
  information from that same snapshot. The object requests no wakeups.
  Remote snapshots execute passively.

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

  Creating an Event Log:

      iex> {:ok, el} = BACnet.Protocol.ObjectTypes.EventLog.create(800, "EventHistory", %{buffer_size: 100}); el.object_name
      "EventHistory"

  Registering an Event Log and obtaining the snapshot used for ReadRange:

      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> alias BACnet.Protocol.ObjectTypes.EventLog
      iex> alias BACnet.Stack.TrendLogger
      iex> {:ok, logger} = TrendLogger.start_link(lookup_cb: fn _reference ->
      ...>   {:error, %BACnet.Protocol.BACnetError{class: :object, code: :unknown_object}}
      ...> end)
      iex> {:ok, object} = EventLog.create(800, "Event history", %{buffer_size: 100})
      iex> context = Context.new(:initialization, options: [trend_logger: logger])
      iex> {:ok, stored} = Lifecycle.execute(object, context)
      iex> {:ok, snapshot} = TrendLogger.get_snapshot(logger, stored.object)
      iex> {stored.object.record_count, snapshot.total_record_count, stored.next_execution}
      {0, 0, nil}
      iex> {buffer_module, buffer} = snapshot.buffer
      iex> buffer_module.read_range(buffer, 0, 10)
      []
      iex> GenServer.stop(logger)
      :ok

  With intrinsic reporting:

      iex> {:ok, el} = BACnet.Protocol.ObjectTypes.EventLog.create(801, "Logged", %{buffer_size: 50}, intrinsic_reporting: true); el.object_name
      "Logged"

  ### See Also
  - `BACnet.Protocol.EventAlgorithms.BufferReady`
  - `BACnet.Stack.TrendLogger`
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EventLogRecord
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.LogLifecycle
  alias BACnet.Protocol.ObjectExecution.Result

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @logger_properties [:enable, :stop_when_full, :start_time, :stop_time, :notification_threshold]
  @readonly_log_properties [
    :buffer_size,
    :log_buffer,
    :total_record_count,
    :records_since_notification,
    :last_notify_record
  ]

  @typedoc """
  Options accepted when creating or configuring an Event Log object.

  In addition to the common options, Event Log supports:
  - `intrinsic_reporting` - Enables intrinsic event reporting properties for the log.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()}
          | common_object_opts()

  @typedoc """
  Represents an Event Log object. Treat struct fields as read-only. Use the object module's
  property functions to build updates.

  Create the object with `intrinsic_reporting: true` to select its intrinsic
  reporting properties. The fields for those properties are `nil` when omitted.
  """
  bac_object Constants.macro_assert_name(:object_type, :event_log) do
    services(intrinsic: true)

    field(:description, String.t())
    field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
    field(:enable, boolean(), required: true, default: true)

    field(:start_time, BACnetDateTime.t(), implicit_relationship: :stop_time)
    field(:stop_time, BACnetDateTime.t())

    field(:stop_when_full, boolean(), required: true, default: false)

    field(:buffer_size, ApplicationTags.unsigned32(),
      required: true,
      readonly: true,
      validator_fun: &(&1 >= 1 and &1 <= 4_294_967_295)
    )

    # Log_Buffer property can only be read through Read-Range service
    field(:log_buffer, [EventLogRecord.t()],
      readonly: true,
      required: true,
      default: [],
      remote_default: true,
      validator_fun:
        &(Enum.count_until(&1, fn _any -> true end, &2[:buffer_size] + 1) <= &2[:buffer_size])
    )

    # When writing to record_count, a value of 0 will truncate the buffer
    field(:record_count, ApplicationTags.unsigned32(),
      required: true,
      default: 0
    )

    field(:total_record_count, ApplicationTags.unsigned32(),
      required: true,
      readonly: true,
      default: 0
    )

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

  @doc """
  Checks the shape of the local log's `:trend_logger` execution option.
  Remote snapshots pass preflight without a logger.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec validate_execution(t(), Context.t()) :: :ok | {:error, term()}
  def validate_execution(object, context)

  def validate_execution(%__MODULE__{_metadata: %{remote_object: remote}}, %Context{})
      when not is_nil(remote),
      do: :ok

  def validate_execution(%__MODULE__{}, %Context{} = context) do
    with {:ok, _logger} <- LogLifecycle.get_logger(context), do: :ok
  end

  @doc """
  Checks access to logger-owned properties, zero-only Record_Count writes,
  and Enable writes against a full stop-when-full buffer.
  The logger applies the accepted write during execution.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec prepare_write(t(), t(), Context.t()) :: {:ok, t()} | {:error, term()}
  def prepare_write(original, candidate, context)

  def prepare_write(%__MODULE__{_metadata: %{remote_object: remote}}, _candidate, %Context{})
      when not is_nil(remote),
      do: {:error, :operation_not_available_for_remote_objects}

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
  The result contains the latest counters and any recorded reporting transition.
  """
  @impl BACnet.Protocol.ObjectsBehaviour
  @spec execute(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  def execute(object, context)

  def execute(%__MODULE__{_metadata: %{remote_object: remote}} = object, %Context{} = context)
      when not is_nil(remote),
      do: {:ok, %Result{object: object, state: context.state, next_execution: nil}}

  def execute(%__MODULE__{} = object, %Context{} = context) do
    LogLifecycle.execute(object, context, @logger_properties)
  end
end
