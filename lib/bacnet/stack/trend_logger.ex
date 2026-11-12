defmodule BACnet.Stack.TrendLogger do
  @moduledoc """
  The Trend Logger module is responsible for handling event and trend logging
  and keeping a log buffer.

  Collects records for Event Log, Trend Log and Trend Log Multiple objects.
  Each registered log has its own buffer.

  For an Event Log, choose which events belong in the log and pass each one
  to `trigger_log/3`. For trend logs, the object's Logging_Type controls
  how samples arrive:
  - `:triggered` - Logging has to be manually triggered through BACnet.
    Call `sample/2` to acquire the configured references or `trigger_log/3`
    to submit data you already have.
  - `:polled` - The logger acquires the configured references on a timer.
  - `:cov` - The logger records matching change-of-value notifications for
    Trend Log objects.

  Forward local and remote COV notifications to `notify/2`. To have the
  logger manage remote subscriptions, supply a `:cov_cb` to `start_link/1`
  and configure a positive Cov_Resubscription_Interval on the log. The
  callback needs to request confirmed notifications. The application
  handles routing incoming notifications, either through that adapter or
  through its own notification handler.

  Polled Trend Log and Trend Log Multiple objects support clock-aligned logging.
  Set `align_intervals: true` on the object, and specify `log_interval` and
  `interval_offset` in hundredths of a second. The alignment properties are optional
  and occur together - `interval_offset` defaults to zero when only `align_intervals`
  is supplied.
  Intervals that divide a second, minute, hour, or day align to that boundary in
  the configured timezone. The offset is reduced modulo the interval. For example,
  `log_interval: 90_000` and `interval_offset: 3_000` acquire at :00:30, :15:30,
  :30:30, and :45:30 each hour.

  Each completed acquisition schedules the next future aligned time, so lookup
  latency does not accumulate as clock drift. Missed periods are skipped - normal
  polling waits for lookup completion. Timers are realigned after detected system-clock
  or timezone offset changes. Acquisition and record delivery may be delayed by
  process scheduling or lookup latency. Polled records use the acquisition start
  time as their timestamp. COV and triggered logging ignore alignment.
  With alignment disabled, or an interval that divides none of the four units,
  polling uses a relative interval after each acquisition and ignores the offset.
  A zero interval in polled mode uses a relative one-second default.

  The logger sends messages to the optional `:notification_receiver`. Use
  `add_object/3` to choose whether the logger evaluates BUFFER_READY itself
  or asks the application to run the object's lifecycle.

  Messages have the form `{:bacnet_trend_logger, nil, object, metadata}`.
  The object is the logger's snapshot of the registered log. An application
  that owns a lifecycle instance can use its identifier to find the latest
  object and retained state.

  - `metadata.buffer` holds the buffer module and a snapshot of the buffer.
  - `metadata.event` is `:buffer_full` or `:intrinsic_reporting`.
  - `metadata.intrinsic_reporting` contains a
    `BACnet.Protocol.NotificationParameters.BufferReady` payload for
    `:intrinsic_reporting` messages. In lifecycle mode, the payload signals
    that evaluation is due. Use the committed execution result for delivery.

  System clock changes are tracked using `:erlang.monitor(:time_offset, :clock_service)`.
  Each nonzero offset change automatically adds a `{:time_change, seconds}` record
  to every enabled log within its logging time window, including event logs.
  The adjustment is signed and includes fractional seconds - records are timestamped
  using the current time after the change. Normal buffer limits and notifications apply.

  Detection follows the Erlang runtime's time warp mode and may be delayed.
  Multi time warp mode is recommended for detecting system clock adjustments.
  Timezone and daylight saving transitions are tracked separately by comparing
  the configured timezone's total UTC offset (`utc_offset + std_offset`) during
  the existing one-second logging time check. Each observed change adds a signed
  `time_change` record through the same logging path. Changes to timezone rules
  are detected when the configured timezone database starts returning a new offset.
  Detection can take longer when the logger is busy - only the net offset change
  between checks is recorded.

  Regional timezones require a configured `Calendar.TimeZoneDatabase` implementation -
  Elixir's default database only supports `Etc/UTC`. The `timezone_database` option
  can select a database for this logger.
  Restoring state starts tracking from the current system and timezone offsets -
  changes while the logger was stopped are not reconstructed.
  """

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetError
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.DeviceObjectRef
  alias BACnet.Protocol.EventAlgorithms.BufferReady
  alias BACnet.Protocol.EventLogRecord
  alias BACnet.Protocol.EventParameters.BufferReady, as: BufferReadyParams
  alias BACnet.Protocol.LogMultipleRecord
  alias BACnet.Protocol.LogRecord
  alias BACnet.Protocol.LogStatus
  alias BACnet.Protocol.NotificationParameters
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectTypes.EventLog
  alias BACnet.Protocol.ObjectTypes.TrendLog
  alias BACnet.Protocol.ObjectTypes.TrendLogMultiple
  alias BACnet.Protocol.PriorityArray
  alias BACnet.Protocol.PropertyValue
  alias BACnet.Protocol.Services.ConfirmedCovNotification
  alias BACnet.Protocol.Services.ConfirmedEventNotification
  alias BACnet.Protocol.Services.UnconfirmedCovNotification
  alias BACnet.Protocol.Services.UnconfirmedEventNotification
  alias BACnet.Stack.LogBuffer
  alias BACnet.Stack.LogBufferBehaviour
  alias BACnet.Stack.Telemetry
  alias BACnet.Stack.TrendLogger.PollSchedule

  import BACnet.Internal, only: [log_debug: 1]

  require Constants
  require Logger
  require ObjectsUtility

  use GenServer

  # Inline simple functions that only return `BACnetError` and do nothing else
  @compile {:inline,
            [
              create_internal_error_error: 0,
              create_invalid_datatype_error: 0,
              create_timeout_error: 0,
              create_uninitialized_error: 0
            ]}

  @cov_cb_retry_timer 10_000
  @max_record_count 4_294_967_295
  @max_acquisition_timeout 60_000
  @control_properties [:enable, :stop_when_full, :start_time, :stop_time]
  @reporting_properties [
    :event_algorithm_inhibit,
    :event_detection_enable,
    :event_state,
    :notification_threshold,
    :reliability
  ]
  @acquisition_properties [
    :align_intervals,
    :buffer_size,
    :interval_offset,
    :log_device_object_property,
    :log_interval,
    :logging_type
  ]
  @cov_properties [:client_cov_increment, :cov_resubscription_interval]

  defmodule Log do
    @moduledoc """
    Internal module for `BACnet.Stack.TrendLogger`.

    It is used to keep track of logging objects,
    the log buffer, intrinsic reporting and other
    necessary information.
    """

    @typedoc """
    Representative type for its purpose.
    """
    @type t :: %__MODULE__{
            enabled: boolean(),
            object: BACnet.Stack.TrendLogger.object(),
            mode: Constants.logging_type(),
            buffer: LogBufferBehaviour.t(),
            intrinsic_reporting: BufferReady.t() | nil,
            buffer_ready_mode: :standalone | :lifecycle,
            buffer_ready_signalled: boolean(),
            records_since_notification: non_neg_integer() | nil,
            seq_number: non_neg_integer(),
            acquisition_token: reference(),
            poll_timer: reference() | nil
          }

    @fields [
      :enabled,
      :object,
      :mode,
      :buffer,
      :intrinsic_reporting,
      :buffer_ready_mode,
      :buffer_ready_signalled,
      :records_since_notification,
      :seq_number,
      :acquisition_token,
      :poll_timer
    ]
    @enforce_keys @fields
    defstruct @fields
  end

  defmodule State do
    @moduledoc """
    Internal module for `BACnet.Stack.TrendLogger`.

    It is used as `GenServer` state.
    """

    @typedoc """
    A remote COV reference, renewal interval in seconds and requested increment.
    """
    @type cov_configuration ::
            {reference :: DeviceObjectPropertyRef.t(), interval :: pos_integer(),
             increment :: float() | nil}

    @typedoc """
    Representative type for its purpose.
    """
    @type t :: %__MODULE__{
            log_buff_mod: module(),
            time_offset: integer() | nil,
            time_offset_monitor: reference() | nil,
            timezone_offset: integer() | nil,
            cov_subscriptions: %{
              optional({Constants.object_type(), instance_number :: non_neg_integer()}) => %{
                configuration: cov_configuration(),
                pending: {operation :: :sub | :unsub, request :: reference()} | nil,
                timer: reference() | nil,
                refresh: boolean()
              }
            },
            logs: %{
              optional({Constants.object_type(), instance_number :: non_neg_integer()}) =>
                %BACnet.Stack.TrendLogger.Log{}
            },
            opts: %{
              cov_cb:
                (pid(),
                 DeviceObjectPropertyRef.t(),
                 :sub
                 | :unsub,
                 non_neg_integer(),
                 float()
                 | nil ->
                   :ok | {:error, term()})
                | nil,
              lookup_cb: (DeviceObjectRef.t() ->
                            {:ok, ObjectsUtility.bacnet_object()} | {:error, BACnetError.t()}),
              notification_receiver: Process.dest() | nil,
              supervisor: Supervisor.supervisor() | nil,
              timezone: Calendar.time_zone(),
              timezone_database: module()
            }
          }

    @fields [:log_buff_mod, :logs, :opts, :cov_subscriptions]
    @enforce_keys @fields
    defstruct @fields ++ [time_offset: nil, time_offset_monitor: nil, timezone_offset: nil]
  end

  defguardp is_object_event(ref) when is_struct(ref, EventLog)
  defguardp is_object_trend(ref) when is_struct(ref, TrendLog)
  defguardp is_object_trend_multi(ref) when is_struct(ref, TrendLogMultiple)
  defguardp is_trend_log(ref) when is_object_trend(ref) or is_object_trend_multi(ref)

  defguardp is_object(ref)
            when is_object_event(ref) or is_object_trend(ref) or is_object_trend_multi(ref)

  defguardp is_time_change_tuple(log)
            when is_tuple(log) and tuple_size(log) == 2 and elem(log, 0) == :time_change and
                   is_float(elem(log, 1))

  # TrendLogMultiple is NOT throughout supported as lists can't be iterated over for validation
  defguardp is_valid_trigger_log(object, log, with_multi)
            when (is_object_event(object) and
                    (log == :interrupted or is_struct(log, ConfirmedEventNotification) or
                       is_struct(log, UnconfirmedEventNotification))) or
                   is_time_change_tuple(log) or
                   ((is_object_trend(object) and
                       (log == :interrupted or is_struct(log, ConfirmedCovNotification) or
                          is_struct(log, UnconfirmedCovNotification) or
                          ObjectsUtility.is_object(log))) or is_time_change_tuple(log)) or
                   (with_multi and is_object_trend_multi(object) and
                      (is_list(log) or is_time_change_tuple(log)))

  @const_log_type_cov Constants.macro_assert_name(:logging_type, :cov)
  @const_log_type_polled Constants.macro_assert_name(:logging_type, :polled)

  @asn1_uninitialized_id Constants.macro_by_name(:asn1, :max_instance_and_property_id)

  @typedoc """
  BACnet object types that the logger can register.
  """
  @type object :: EventLog.t() | TrendLog.t() | TrendLogMultiple.t()

  @typedoc """
  The buffer and runtime properties of a registered log captured together.

  `enable` is the current BACnet Enable property. `collecting` reflects the
  logger's collection state after its latest time-window check. `record_count`
  is the number of resident records and `total_record_count` is the latest record
  sequence number. The notification counters are `nil` when intrinsic reporting
  is absent.
  """
  @type snapshot :: %{
          buffer: {buffer_module :: module(), buffer :: LogBufferBehaviour.t()},
          enable: boolean(),
          collecting: boolean(),
          record_count: non_neg_integer(),
          total_record_count: non_neg_integer(),
          records_since_notification: non_neg_integer() | nil,
          last_notify_record: non_neg_integer() | nil
        }

  @typedoc """
  The logger's process identifier or registered server name.
  """
  @type server :: GenServer.server()

  @typedoc """
  Valid start options. For a description of each, see `start_link/1`.
  """
  @type start_option ::
          {:cov_cb,
           (pid(), DeviceObjectPropertyRef.t(), :sub | :unsub, non_neg_integer(), float() | nil ->
              :ok | {:error, term()})}
          | {:log_buffer_module, LogBufferBehaviour.mod()}
          | {:lookup_cb,
             (DeviceObjectRef.t() ->
                {:ok, ObjectsUtility.bacnet_object()} | {:error, BACnetError.t()})}
          | {:notification_receiver, Process.dest()}
          | {:state, State.t()}
          | {:supervisor, Supervisor.supervisor()}
          | {:timezone, Calendar.time_zone()}
          | {:timezone_database, module()}
          | GenServer.option()

  @typedoc """
  List of start options.
  """
  @type start_options :: [start_option()]

  @doc """
  Starts and links the trend logger.

  Following options are available, in addition to `t:GenServer.options/0`:
  - `:cov_cb` - Optional callback for managing remote confirmed COV subscriptions.
    It receives the logger PID, a `BACnet.Protocol.DeviceObjectPropertyRef`,
    `:sub` or `:unsub`, the subscription lifetime in seconds and the requested
    COV increment (or `nil`). Return `:ok` or `{:error, reason}`. Keep the
    callback bounded. The logger waits for an in-flight operation before
    replacing a subscription and unsubscribes when the last enabled log
    stops using that remote reference. You can manage subscriptions separately
    and use `notify/2` to forward notifications.

  - `:log_buffer_module` - Optional buffer implementation. It must implement
    `BACnet.Stack.LogBufferBehaviour`. The default is `BACnet.Stack.LogBuffer`.
    `BACnet.Stack.LogBufferTree` supports efficient range reads and ordered scans.

  - `:lookup_cb` - Required callback for local and remote acquisitions.
    It receives a `BACnet.Protocol.DeviceObjectRef` and returns
    `{:ok, object}`. The logger reads the configured property from that snapshot.
    Return `{:error, %BACnet.Protocol.BACnetError{}}` to record the Error Class
    and Error Code from a failed read. Callback exceptions and unexpected
    results are recorded as `DEVICE/INTERNAL_ERROR`.
    For a single Trend Log, the callback needs to enforce any read timeout.

    For Trend Log Multiple, each reference contributes one value or failure in
    array order, even if the lookups complete in a different order. An
    uninitialized object or device instance contributes
    `PROPERTY/NO_PROPERTY_SPECIFIED` without invoking the callback.
    The logger limits each read to the poll interval minus 10 milliseconds,
    clamped to 1 millisecond through 1 minute. A read that exceeds this limit
    contributes `COMMUNICATION/TIMEOUT`.

  - `notification_receiver: Process.dest()` - Optional. The recipient of buffer-full and
    BUFFER_READY messages. A host that uses lifecycle execution can use these messages to
    schedule execution when records arrive between its own executions. See `add_object/3`
    for the message handling in each registration mode.

  - `:state` - Optional state from a previous logger instance. Use it to restore
    registered logs and their buffers after a restart. Startup options replace
    the options stored in the state. Supply a compatible state from the logger.
    For older states that lack Records_Since_Notification, the logger estimates
    it from the record sequence and Last_Notify_Record. That estimate can
    include records collected before a purge.

  - `:supervisor` - Optional task supervisor for acquisition and subscription
    tasks. By default, the logger starts those tasks without a supervisor.

  - `:timezone` - Optional timezone for timestamps and clock-aligned polling.
    Defaults to the application's `:bacstack, :default_timezone` configuration,
    or `"Etc/UTC"` when unset.

  - `:timezone_database` - Optional `Calendar.TimeZoneDatabase` implementation
    for timestamps, logging windows and offset tracking. Defaults to
    `Calendar.get_time_zone_database/0` at startup. Configure a database that
    supports the zone when using a regional timezone.
  """
  @spec start_link(start_options()) :: GenServer.on_start()
  def start_link(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError, "start_link/1 expected a keyword list, got: #{inspect(opts)}"
    end

    {opts2, genserver_opts} =
      Keyword.split(opts, [
        :cov_cb,
        :log_buffer_module,
        :lookup_cb,
        :notification_receiver,
        :state,
        :supervisor,
        :timezone,
        :timezone_database
      ])

    validate_start_link_opts(opts2)

    GenServer.start_link(__MODULE__, Map.new(opts2), genserver_opts)
  end

  @doc """
  Registers a `BACnet.Protocol.ObjectTypes.EventLog`, `BACnet.Protocol.ObjectTypes.TrendLog`
  or `BACnet.Protocol.ObjectTypes.TrendLogMultiple` with the logger.

  The third argument selects who drives BUFFER_READY evaluation. Record
  collection and buffering work the same way in both modes. The application
  handles any BACnet notification delivery in either mode.

  ## `:standalone` (default)

  Use this when your application manages the log directly through TrendLogger,
  for example to collect a local history. The logger uses the reporting settings
  of the registered object. Apply later setting changes with `update_object/3`.
  When the threshold is met and reporting is eligible, the logger advances
  Last_Notify_Record and resets Records_Since_Notification. An `:intrinsic_reporting`
  message carries the BUFFER_READY payload for that completed evaluation.
  The counters are available through `get_snapshot/2`.

  For example, given an enabled Event Log configured for intrinsic reporting,
  register it and submit an event notification to it directly:

      :ok = BACnet.Stack.TrendLogger.add_object(logger, event_log, :standalone)
      :ok = BACnet.Stack.TrendLogger.trigger_log(logger, event_log, event_notification)
      {:ok, snapshot} = BACnet.Stack.TrendLogger.get_snapshot(logger, event_log)

  Omitting the third argument also selects `:standalone`.

  ## `:lifecycle`

  Use this when a host, such as a BACnet device server, runs the log through
  `BACnet.Protocol.ObjectExecution.Lifecycle`. The log's initialization callback
  calls `add_object/3` with `:lifecycle` automatically. Registering an existing log
  in this mode keeps its buffer and counters.

  With a configured notification receiver, `:intrinsic_reporting` requests an
  execution of the current log. The host uses the object identifier in the message
  to find the current object and its retained lifecycle state. Execution resolves
  the object's current reporting settings, including linked inhibition, and checks
  the latest record count. The counters advance when execution records BUFFER_READY.
  The host uses the transition from the execution result for notification delivery.

  For example, initialize a local log through its lifecycle, then run a periodic
  execution when the receiver reports `:intrinsic_reporting` for that log:

      alias BACnet.Protocol.ObjectExecution.{Context, EventReporting, Lifecycle}

      options = [trend_logger: logger]
      {:ok, initial} = Lifecycle.execute(log, Context.new(:initialization, options: options))

      # Retain initial.object and initial.state. On a receiver message, use the latest pair.
      context = Context.new(:periodic, options: options, state: initial.state)
      {:ok, result} = Lifecycle.execute(initial.object, context)
      transition = EventReporting.transition(result)

  Retain the complete result for subsequent executions, including any wakeup request.
  The transition is `nil` if reporting is inhibited or no transition is due.
  See `BACnet.Protocol.ObjectExecution.IntrinsicReporting` for the host flow.
  """
  @spec add_object(server(), object(), :standalone | :lifecycle) :: :ok | {:error, term()}
  def add_object(server, object, mode \\ :standalone)
      when is_object(object) and mode in [:standalone, :lifecycle] do
    GenServer.call(server, {:add_object, object, mode})
  end

  @doc """
  Enables or disables collection for one log, or for all registered logs with `:global`.

  Records a log status change. Enabling a log whose buffer is full with
  `Stop_When_Full` set returns `{:error, :log_buffer_full}`. A global enable
  request returns that error before changing any logs if one of them is full
  with `Stop_When_Full` set.
  """
  @spec change_log_state(server(), object() | :global, :enable | :disable) ::
          :ok | {:error, term()}
  def change_log_state(server, object, state)
      when (object == :global or is_object(object)) and state in [:enable, :disable] do
    GenServer.call(server, {:change_log_state, object, state})
  end

  @doc """
  Returns the current sequence number, buffer module and buffer for a registered log.
  """
  @spec get_buffer(server(), object()) ::
          {:ok,
           {current_sequence_number :: non_neg_integer(), buffer_module :: module(),
            buffer :: LogBufferBehaviour.t()}}
          | {:error, term()}
  def get_buffer(server, object) when is_object(object) do
    GenServer.call(server, {:get_buffer, object})
  end

  @doc """
  Returns a log's buffer, enable state and counters in a single read.

  Use the buffer module and buffer from this result together for
  `c:BACnet.Stack.LogBufferBehaviour.read_range/3`. For example,
  `buffer_module.read_range(buffer, 0, 10)` reads up to ten records from the
  start of the captured buffer. Later writes leave the returned snapshot intact.

  Notification counters reflect the logger's Buffer Ready processing. A
  transition resets `records_since_notification` and updates `last_notify_record`.
  A purge resets `records_since_notification`. The purge record can itself
  trigger a Buffer Ready transition.

  Returns `{:error, :unknown_object}` if the object is unregistered.
  """
  @spec get_snapshot(server(), object()) :: {:ok, snapshot()} | {:error, :unknown_object}
  def get_snapshot(server, object) when is_object(object) do
    GenServer.call(server, {:get_snapshot, object})
  end

  @doc """
  Evaluates BUFFER_READY for a registered lifecycle log and returns a snapshot.

  The object supplies its current detection, inhibition, event state and
  Reliability. An eligible transition updates the notification counters in the
  same server operation that captures the snapshot. The caller records the
  returned notification as the object's transition.
  """
  @spec evaluate_buffer_ready(server(), object()) ::
          {:ok, snapshot(), NotificationParameters.BufferReady.t() | nil} | {:error, term()}
  def evaluate_buffer_ready(server, object) when is_object(object) do
    GenServer.call(server, {:evaluate_buffer_ready, object})
  end

  @doc """
  Clears the specified log's buffer, or all buffers with `:global`. The logger
  appends a purge record to each cleared buffer.
  """
  @spec prune_buffer(server(), object() | :global) :: :ok | {:error, term()}
  def prune_buffer(server, object) when object == :global or is_object(object) do
    GenServer.call(server, {:prune_buffer, object})
  end

  @doc """
  Submits a COV notification to the trend logger. The logger records it for
  matching, enabled `BACnet.Protocol.ObjectTypes.TrendLog` objects in COV mode.

  For an Event Log, submit an event to the chosen log with `trigger_log/3`.
  """
  @spec notify(
          server(),
          ConfirmedCovNotification.t()
          | UnconfirmedCovNotification.t()
        ) :: :ok
  def notify(server, log)

  def notify(server, %ConfirmedCovNotification{} = log) do
    GenServer.call(server, {:notify, log})
  end

  def notify(server, %UnconfirmedCovNotification{} = log) do
    GenServer.call(server, {:notify, log})
  end

  @doc """
  Removes a registered log and its buffer. Returns `:ok` if the log is already absent.
  """
  @spec remove_object(server(), object()) :: :ok
  def remove_object(server, object) when is_object(object) do
    GenServer.call(server, {:remove_object, object})
  end

  @doc """
  Requests COV subscription renewal for one log, or all logs with `:global`.
  The logger processes the renewal asynchronously.
  """
  @spec resubscribe_cov(server(), TrendLog.t() | :global) :: :ok
  def resubscribe_cov(server, object) when object == :global or is_object_trend(object) do
    GenServer.call(server, {:resubscribe_cov, object})
  end

  @doc """
  Records a supplied event, value or status in the specified log.

  When collection is disabled, data and time changes are ignored (returns `:ok`).
  The `:interrupted` status is recorded even when collection is disabled.

  For Trend Log Multiple, supply object snapshots in any order. The logger
  reads each configured reference in array order. Uninitialized references
  produce `PROPERTY/NO_PROPERTY_SPECIFIED`. An initialized reference with no
  matching snapshot produces `OBJECT/UNKNOWN_OBJECT`.

  Use `sample/2` when the logger needs to acquire the values from its configured
  references before recording them.

  The accepted data depends on the type of log. All three types also accept
  `:interrupted` and `{:time_change, seconds}`, where `seconds` is a float.

  | Log | Data |
  | --- | --- |
  | Event Log | Confirmed or unconfirmed event notification. |
  | Trend Log | Confirmed or unconfirmed COV notification, or a source object snapshot. |
  | Trend Log Multiple | A list of source object snapshots. |
  """
  @spec trigger_log(
          server(),
          object(),
          ConfirmedEventNotification.t()
          | UnconfirmedEventNotification.t()
          | ConfirmedCovNotification.t()
          | ObjectsUtility.bacnet_object()
          | [ObjectsUtility.bacnet_object()]
          | :interrupted
          | {:time_change, float()}
        ) :: :ok | {:error, term()}
  def trigger_log(server, object, log)

  def trigger_log(server, object, log) when is_valid_trigger_log(object, log, false) do
    GenServer.call(server, {:trigger_log, object, log})
  end

  def trigger_log(server, object, log)
      when is_object_trend_multi(object) and
             (log == :interrupted or is_list(log) or is_time_change_tuple(log)) do
    if is_list(log) do
      unless Enum.all?(log, &ObjectsUtility.is_object/1) do
        raise ArgumentError,
              "Invalid log value, expected a list of BACnet objects, got: #{inspect(log)}"
      end
    end

    GenServer.call(server, {:trigger_log, object, log})
  end

  @doc """
  Acquires one sample for a registered Trend Log or Trend Log Multiple in
  triggered mode.

  For Trend Log, the logger's lookup callback runs in the calling process and
  needs to bound its read time. Trend Log Multiple uses concurrent tasks with
  a one-minute timeout per lookup. Its record preserves the order of the
  reference array and holds a value or failure for each slot.

  Collection must be enabled at the start and end of the acquisition. Results
  from a previous registration, mode or reference are discarded.
  """
  @spec sample(server(), TrendLog.t() | TrendLogMultiple.t()) :: :ok | {:error, term()}
  def sample(server, object) when is_trend_log(object) do
    case GenServer.call(server, {:prepare_sample, object}) do
      {:ok, acquisition} ->
        datum =
          acquire_sample(
            acquisition.logger,
            acquisition.lookup,
            acquisition.object,
            acquisition.supervisor
          )

        GenServer.call(
          acquisition.logger,
          {:submit_sample, object, acquisition.token, acquisition.timestamp, datum}
        )

      :skip ->
        :ok

      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Updates the following properties of the object in the trend logger:
  - buffer_size
  - cov_resubscription_interval (trend logs only)
  - enable
  - Intrinsic Reporting (notification threshold)
  - log_interval (trend logs only)
  - align_intervals and interval_offset (polled trend logs only)
  - logging_type (trend logs only)
  - start_time and stop_time
  - stop_when_full

  When updating `buffer_size`, the records in the buffer will transfer
  over to the new buffer, discarding any oldest records that would
  overfill the new buffer. Changing the monitored references of a trend log purges
  its history. Setting `Stop_When_Full` on a full buffer
  discards the oldest record and records that logging stopped. Changing
  `Enable` to true on a full buffer with `Stop_When_Full` already set returns
  `{:error, :log_buffer_full}`.
  """
  @spec update_object(server(), object()) :: :ok | {:error, term()}
  def update_object(server, object) when is_object(object) do
    GenServer.call(server, {:update_object, object, nil})
  end

  @doc """
  Applies an explicit write to a log's collection or reporting settings.

  Uses the submitted value for that property and the logger's current settings
  for the other properties. Window writes apply both bounds together. Trend Log
  and Trend Log Multiple also accept acquisition settings and Buffer_Size.
  Logging_Type and Log_Interval apply together, as do Align_Intervals and
  Interval_Offset. Changing the monitored references purges the old history.
  Notification_Threshold edits preserve the last notification count.
  Standalone logs reevaluate the threshold after reporting property edits.
  A Buffer_Size write is rejected while Enable is true.

  An explicit write of true to Stop_When_Full records a stop if the buffer is
  full, including when Stop_When_Full was already true.

  An explicit write of true to Enable returns `{:error, :log_buffer_full}`
  if the log is full with Stop_When_Full set. This check runs in the logger.
  """
  @spec update_object(server(), object(), Constants.property_identifier()) ::
          :ok | {:error, term()}
  def update_object(server, object, property)
      when (is_object(object) and
              (property in @control_properties or property in @reporting_properties)) or
             (is_trend_log(object) and property in @acquisition_properties) or
             (is_object_trend(object) and property in @cov_properties) do
    GenServer.call(server, {:update_object, object, property})
  end

  @doc false
  def init(opts) do
    new_opts =
      opts
      |> Map.drop([:log_buffer_module, :state])
      |> Map.put_new(:cov_cb, nil)
      |> Map.put_new(:notification_receiver, nil)
      |> Map.put_new(:supervisor, nil)
      |> Map.put_new(:timezone, Application.get_env(:bacstack, :default_timezone, "Etc/UTC"))
      |> Map.put_new(:timezone_database, Calendar.get_time_zone_database())

    state =
      case opts do
        %{state: %State{} = state} ->
          # Supply new fields when restoring a snapshot from an older version.
          %State{} =
            state = struct!(State, Map.put(Map.from_struct(state), :cov_subscriptions, %{}))

          state = %State{state | opts: new_opts}

          # Setup timers to poll all trend logs with logging_type == :polled
          logs =
            Map.new(state.logs, fn {id, %Log{} = log} ->
              %Log{} = log = restore_log(log)
              Telemetry.execute_trend_logger_log_start(self(), log, state)

              if log.buffer_ready_mode == :lifecycle and log.intrinsic_reporting != nil do
                send(self(), {:check_buffer_ready, id})
              end

              log = %Log{log | poll_timer: nil}

              new_log =
                if log.mode == @const_log_type_polled do
                  apply_log_mechanism(log, log.object, id, state)
                else
                  log
                end

              {id, new_log}
            end)

          %{
            state
            | logs: logs,
              log_buff_mod: Map.get(opts, :log_buffer_module, LogBuffer),
              opts: new_opts
          }

        %{} ->
          %State{
            log_buff_mod: Map.get(opts, :log_buffer_module, LogBuffer),
            logs: %{},
            cov_subscriptions: %{},
            opts: new_opts
          }
      end

    # Monitors belong to this process, so never reuse one from restored state.
    time_offset_monitor = :erlang.monitor(:time_offset, :clock_service)

    state = %State{
      state
      | time_offset_monitor: time_offset_monitor,
        time_offset: :erlang.time_offset(),
        timezone_offset: timezone_offset(local_now(state))
    }

    state = Enum.reduce(Map.keys(state.logs), state, &reconcile_cov(&2, &1))

    # Check after 1s for start_time and stop_time
    # in every object
    Process.send_after(self(), :check_time, 1000)

    log_debug(fn -> "TrendLogger: Started on #{inspect(self())}" end)

    {:ok, state, :hibernate}
  end

  @doc false
  @spec handle_call(term(), GenServer.from(), State.t()) ::
          {:reply, term(), State.t()} | {:noreply, State.t()}
  def handle_call(request, from, state)

  def handle_call({:add_object, object, mode}, _dest, %State{log_buff_mod: log_buff_mod} = state)
      when is_object(object) do
    log_debug(fn -> "TrendLogger: Received add_object request for #{make_log_id(object)}" end)
    id = make_id(object)

    {reply, new_state} =
      cond do
        mode == :lifecycle and Map.has_key?(state.logs, id) ->
          {:ok, put_in(state.logs[id].buffer_ready_mode, :lifecycle)}

        Map.has_key?(state.logs, id) ->
          {{:error, :already_known_object}, state}

        ObjectsUtility.get_remote_device_id(object) == :error ->
          {{:error, :remote_object_with_no_id}, state}

        # Invalid logging type for TL Multiple
        match?(%TrendLogMultiple{logging_type: @const_log_type_cov}, object) ->
          {{:error, :invalid_logging_type}, state}

        true ->
          intrinsic = if object.notification_threshold != nil, do: create_intrinsic(object)

          new_log = %Log{
            enabled: log_enabled?(object, state),
            object: object,
            mode: if(is_struct(object, EventLog), do: :triggered, else: object.logging_type),
            buffer: log_buff_mod.new(if(object.buffer_size > 0, do: object.buffer_size)),
            intrinsic_reporting: intrinsic,
            buffer_ready_mode: mode,
            buffer_ready_signalled: false,
            records_since_notification: if(intrinsic != nil, do: 0),
            seq_number: 0,
            acquisition_token: make_ref(),
            poll_timer: nil
          }

          new_log = apply_log_mechanism(new_log, object, id, state)
          new_logs = Map.put(state.logs, id, new_log)

          Telemetry.execute_trend_logger_log_start(self(), new_log, state)

          {:ok, reconcile_cov(%State{state | logs: new_logs}, id)}
      end

    {:reply, reply, new_state}
  end

  def handle_call({:change_log_state, object, operation}, _dest, %State{} = state)
      when object == :global or is_object(object) do
    log_debug(fn ->
      "TrendLogger: Received change_log_state request for #{make_log_id(object)}"
    end)

    logs =
      if object == :global, do: state.logs, else: Map.take(state.logs, [make_id(object)])

    cond do
      object != :global and map_size(logs) == 0 ->
        {:reply, {:error, :unknown_object}, state}

      operation == :enable and
          Enum.any?(logs, fn {_id, log} ->
            log.object.stop_when_full and buffer_reaches_capacity?(log, 0, state)
          end) ->
        {:reply, {:error, :log_buffer_full}, state}

      true ->
        new_state =
          Enum.reduce(logs, state, fn {id, log}, acc ->
            object = %{log.object | enable: operation == :enable}

            new_log = %{log | object: object, enabled: log_enabled?(object, acc)}
            new_log = append_record(new_log, operation, id, acc)
            new_log = handle_change_enabled_state(new_log, id, log, acc)

            Telemetry.execute_trend_logger_log_update(self(), new_log, :state, acc)
            reconcile_cov(put_in(acc.logs[id], new_log), id)
          end)

        {:reply, :ok, new_state}
    end
  end

  def handle_call({:get_buffer, object}, _dest, %State{} = state) when is_object(object) do
    log_debug(fn -> "TrendLogger: Received get_buffer request for #{make_log_id(object)}" end)

    reply =
      case Map.fetch(state.logs, make_id(object)) do
        {:ok, %Log{} = log} -> {:ok, {log.seq_number, state.log_buff_mod, log.buffer}}
        _else -> {:error, :unknown_object}
      end

    {:reply, reply, state}
  end

  def handle_call({:get_snapshot, object}, _dest, %State{} = state) when is_object(object) do
    reply =
      case Map.fetch(state.logs, make_id(object)) do
        {:ok, %Log{} = log} ->
          {:ok, snapshot(log, state)}

        :error ->
          {:error, :unknown_object}
      end

    {:reply, reply, state}
  end

  def handle_call({:evaluate_buffer_ready, object}, _dest, %State{} = state)
      when is_object(object) do
    id = make_id(object)

    case Map.fetch(state.logs, id) do
      {:ok, %Log{} = log} ->
        {log, notification} =
          if log.buffer_ready_mode == :lifecycle and log.intrinsic_reporting != nil and
               object._metadata.intrinsic_reporting and buffer_ready_enabled?(object) do
            {updated, notification} = update_intrinsic_reporting(log, state)
            {%{updated | buffer_ready_signalled: false}, notification}
          else
            {log, nil}
          end

        {:reply, {:ok, snapshot(log, state), notification}, put_in(state.logs[id], log)}

      :error ->
        {:reply, {:error, :unknown_object}, state}
    end
  end

  def handle_call({:notify, notif}, _dest, %State{} = state)
      when is_struct(notif, ConfirmedCovNotification) or
             is_struct(notif, UnconfirmedCovNotification) do
    log_debug(fn -> "TrendLogger: Received notify request with #{notif.__struct__}" end)

    new_state =
      Enum.reduce(state.logs, state, fn
        {id, %Log{mode: @const_log_type_cov, object: %TrendLog{} = object}}, %State{} = acc ->
          acc = refresh_log_time(acc, id)

          with %Log{enabled: true} = log <- acc.logs[id],
               {:cont, log_datum} <- find_log_datum_from_notify(object, notif, acc),
               {:ok, log_encoding} <- create_encoding_for_notify(log_datum, acc) do
            new_log = append_record(log, log_encoding, id, acc)
            Telemetry.execute_trend_logger_log_update(self(), new_log, :buffer, acc)
            store_record(acc, id, log, new_log)
          else
            _other -> acc
          end

        {_id, %Log{}}, %State{} = acc ->
          acc
      end)

    {:reply, :ok, new_state}
  end

  def handle_call({:prune_buffer, object}, _dest, %State{} = state)
      when object == :global or is_object(object) do
    log_debug(fn -> "TrendLogger: Received prune_buffer request for #{make_log_id(object)}" end)

    logs =
      if object == :global, do: state.logs, else: Map.take(state.logs, [make_id(object)])

    if object != :global and map_size(logs) == 0 do
      {:reply, {:error, :unknown_object}, state}
    else
      new_state =
        Enum.reduce(logs, state, fn {id, _log}, acc ->
          acc = refresh_log_time(acc, id)
          log = Map.fetch!(acc.logs, id)
          new_log = purge_log(log, id, acc)

          Telemetry.execute_trend_logger_log_update(self(), new_log, :buffer, acc)
          store_record(acc, id, log, new_log)
        end)

      {:reply, :ok, new_state}
    end
  end

  def handle_call({:resubscribe_cov, :global}, _dest, %State{} = state) do
    log_debug(fn -> "TrendLogger: Received resubscribe_cov request for global" end)

    new_state = Enum.reduce(Map.keys(state.logs), state, &reconcile_cov(&2, &1, true))
    {:reply, :ok, new_state}
  end

  def handle_call({:resubscribe_cov, object}, _dest, %State{} = state)
      when is_object_trend(object) do
    log_debug(fn ->
      "TrendLogger: Received resubscribe_cov request for #{make_log_id(object)}"
    end)

    {:reply, :ok, reconcile_cov(state, make_id(object), true)}
  end

  def handle_call({:remove_object, object}, _dest, %State{} = state) when is_object(object) do
    log_debug(fn -> "TrendLogger: Received remove_object request for #{make_log_id(object)}" end)
    id = make_id(object)

    {reply, new_state} =
      case Map.pop(state.logs, id) do
        {%Log{} = log, new_logs} ->
          cancel_poll_timer(log)

          Telemetry.execute_trend_logger_log_stop(self(), log, state)

          {:ok, reconcile_cov(%State{state | logs: new_logs}, id)}

        _else ->
          {:ok, state}
      end

    {:reply, reply, new_state}
  end

  def handle_call(
        {:trigger_log, object, log_entry},
        _dest,
        %State{} = state
      )
      when is_object(object) do
    log_debug(fn -> "TrendLogger: Received trigger_log request for #{make_log_id(object)}" end)
    id = make_id(object)
    state = refresh_log_time(state, id)

    {reply, new_state} =
      case Map.fetch(state.logs, id) do
        {:ok, %Log{enabled: enabled, object: object} = log}
        when enabled or log_entry == :interrupted ->
          case find_log_datum_from_trigger(object, log_entry) do
            {:ok, log_datum} ->
              {:ok, append_triggered_record(log, log_datum, log_entry, id, state)}

            :skip ->
              {:ok, state}

            {:error, _reason} = error ->
              {error, state}
          end

        _else ->
          {:ok, state}
      end

    {:reply, reply, new_state}
  end

  def handle_call({:prepare_sample, object}, _dest, %State{} = state) when is_trend_log(object) do
    id = make_id(object)
    state = refresh_log_time(state, id)

    reply =
      case state.logs[id] do
        %Log{mode: :triggered, enabled: true} = log ->
          {:ok,
           %{
             logger: self(),
             lookup: state.opts.lookup_cb,
             object: log.object,
             supervisor: state.opts.supervisor,
             token: log.acquisition_token,
             timestamp: BACnetDateTime.from_datetime(local_now(state))
           }}

        %Log{mode: :triggered} ->
          :skip

        %Log{} ->
          {:error, :not_configured_for_triggered_logging}

        nil ->
          {:error, :unknown_object}
      end

    {:reply, reply, state}
  end

  def handle_call({:submit_sample, object, token, timestamp, datum}, _dest, %State{} = state)
      when is_trend_log(object) do
    id = make_id(object)
    state = refresh_log_time(state, id)

    case state.logs[id] do
      %Log{mode: :triggered, enabled: true, acquisition_token: ^token} = log when datum != [] ->
        new_log = append_record(log, datum, id, state, timestamp)
        Telemetry.execute_trend_logger_log_update(self(), new_log, :buffer, state)
        {:reply, :ok, store_record(state, id, log, new_log)}

      _other ->
        {:reply, :ok, state}
    end
  end

  def handle_call(
        {:update_object, object, property},
        _dest,
        %State{log_buff_mod: log_buff_mod} = state
      )
      when is_object(object) do
    log_debug(fn -> "TrendLogger: Received update_object request for #{make_log_id(object)}" end)
    id = make_id(object)

    {reply, new_state} =
      case Map.fetch(state.logs, id) do
        {:ok, %Log{}}
        when is_object_trend_multi(object) and object.logging_type == @const_log_type_cov and
               (is_nil(property) or property in [:logging_type, :log_interval]) ->
          {{:error, :invalid_logging_type}, state}

        {:ok, %Log{object: %{enable: true}}} when property == :buffer_size ->
          {{:error, {:write_access_denied, :buffer_size}}, state}

        {:ok, %Log{} = old_log} ->
          object = merge_log_configuration(old_log.object, object, property)
          log = resize_log_buffer(old_log, object.buffer_size, log_buff_mod)

          new_log = %Log{
            log
            | enabled: log_enabled?(object, state),
              mode: if(is_struct(object, EventLog), do: :triggered, else: object.logging_type),
              object: object
          }

          full = object.stop_when_full and buffer_reaches_capacity?(new_log, 0, state)

          if full and object.enable and
               (property == :enable or
                  (old_log.object.stop_when_full and not old_log.object.enable)) do
            {{:error, :log_buffer_full}, state}
          else
            new_log = reconfigure_log(new_log, old_log, full, property, id, state)

            new_log = handle_change_enabled_state(new_log, id, old_log, state)
            new_log = update_buffer_ready_configuration(new_log, old_log, id)

            Telemetry.execute_trend_logger_log_update(self(), new_log, :state, state)
            {:ok, reconcile_cov(put_in(state.logs[id], new_log), id)}
          end

        _else ->
          {{:error, :unknown_object}, state}
      end

    {:reply, reply, new_state}
  end

  def handle_call(_message, _dest, state) do
    # Catch-all - discard the message
    {:noreply, state}
  end

  @doc false
  @spec handle_info(term(), State.t()) :: {:noreply, State.t()}
  def handle_info(message, state)

  def handle_info({:maybe_notify_receiver, id}, %State{} = state),
    do: {:noreply, notify_log(state, id, true)}

  def handle_info({:check_buffer_ready, id}, %State{} = state),
    do: {:noreply, notify_log(state, id, false)}

  def handle_info(
        {:timeout, timer, {:poll_log, id}},
        %State{opts: %{lookup_cb: lookup_cb}} = state
      )
      when is_reference(timer) do
    log_debug(fn -> "TrendLogger: Received poll_log message for #{inspect(id)}" end)
    state = refresh_log_time(state, id)

    case Map.get(state.logs, id) do
      # Ignore TrendLog reference with uninitialized IDs
      %Log{
        object: %{
          log_device_object_property: %{
            object_identifier: %ObjectIdentifier{instance: @asn1_uninitialized_id}
          }
        }
      } ->
        :ok

      %Log{
        enabled: true,
        mode: @const_log_type_polled,
        poll_timer: ^timer,
        object: object
      } ->
        server = self()
        timestamp = BACnetDateTime.from_datetime(local_now(state))

        spawn_task(
          fn ->
            result = acquire_log_data(server, lookup_cb, object, state.opts.supervisor)
            send(server, {:submit_poll, id, timer, result, timestamp})
          end,
          state
        )

      _else ->
        :ok
    end

    {:noreply, state}
  end

  def handle_info({:submit_poll, id, timer, result}, %State{} = state)
      when is_reference(timer) do
    timestamp = BACnetDateTime.from_datetime(local_now(state))
    handle_info({:submit_poll, id, timer, result, timestamp}, state)
  end

  def handle_info(
        {:submit_poll, id, timer, result, %BACnetDateTime{} = timestamp},
        %State{} = state
      )
      when is_reference(timer) do
    log_debug(fn -> "TrendLogger: Received submit_poll message for #{inspect(id)}" end)
    state = refresh_log_time(state, id)

    # This is for :polled trendlogs and submits the result of the task
    # into the trendlog itself

    new_state =
      case Map.fetch(state.logs, id) do
        {:ok,
         %Log{enabled: true, mode: @const_log_type_polled, poll_timer: ^timer, object: object} =
             log} ->
          log = apply_log_mechanism(log, object, id, state)

          case result do
            datum
            when (is_struct(object, TrendLog) and
                    (is_struct(datum, Encoding) or is_struct(datum, BACnetError) or is_nil(datum))) or
                   (is_struct(object, TrendLogMultiple) and is_list(datum) and datum != []) ->
              new_log = append_record(log, datum, id, state, timestamp)
              Telemetry.execute_trend_logger_log_update(self(), new_log, :buffer, state)
              store_record(state, id, log, new_log)

            _other ->
              put_in(state.logs[id], log)
          end

        _else ->
          state
      end

    {:noreply, new_state}
  end

  def handle_info({:timeout, timer, {:cov_resub, id}}, %State{} = state)
      when is_reference(timer) do
    case state.cov_subscriptions[id] do
      %{timer: ^timer} -> {:noreply, reconcile_cov(state, id, true)}
      _other -> {:noreply, state}
    end
  end

  def handle_info({:cov_complete, id, request, success}, %State{} = state) do
    case state.cov_subscriptions[id] do
      %{pending: {:sub, ^request}, configuration: {_reference, interval, _increment}} =
          subscription ->
        delay = if success, do: interval * 1000, else: @cov_cb_retry_timer
        timer = :erlang.start_timer(delay, self(), {:cov_resub, id})
        state = put_in(state.cov_subscriptions[id], %{subscription | pending: nil, timer: timer})
        {:noreply, reconcile_cov(state, id)}

      %{pending: {:unsub, ^request}} ->
        state = %{state | cov_subscriptions: Map.delete(state.cov_subscriptions, id)}
        new_state = Enum.reduce(Map.keys(state.logs), state, &reconcile_cov(&2, &1))
        {:noreply, new_state}

      _other ->
        {:noreply, state}
    end
  end

  def handle_info(
        {:CHANGE, ref, :time_offset, :clock_service, offset},
        %State{time_offset_monitor: ref, time_offset: previous_offset} = state
      )
      when is_reference(ref) and is_integer(offset) do
    new_state = %State{state | time_offset: offset}
    {timezone_change, new_state} = check_timezone_offset(new_state)

    # Include any timezone transition crossed by this system-clock adjustment.
    # Updating both baselines prevents the periodic check from logging it again.
    seconds =
      (offset - previous_offset) / System.convert_time_unit(1, :second, :native) + timezone_change

    new_state = check_log_time(new_state)

    new_state =
      if offset != previous_offset or timezone_change != 0,
        do: realign_poll_timers(new_state),
        else: new_state

    {:noreply, append_time_change(new_state, seconds)}
  end

  def handle_info(:check_time, %State{} = state) do
    {timezone_change, new_state} = check_timezone_offset(state)
    new_state = check_log_time(new_state)
    new_state = if timezone_change != 0, do: realign_poll_timers(new_state), else: new_state
    new_state = append_time_change(new_state, timezone_change)

    # Check after 1s for start_time and stop_time in every object, again!
    Process.send_after(self(), :check_time, 1000)

    {:noreply, new_state}
  end

  def handle_info(_message, state) do
    # Catch-all - discard the message
    {:noreply, state}
  end

  defp local_now(%State{opts: opts}) do
    DateTime.now!(opts.timezone, opts.timezone_database)
  end

  defp timezone_offset(%DateTime{utc_offset: utc_offset, std_offset: std_offset}) do
    utc_offset + std_offset
  end

  defp check_timezone_offset(%State{timezone_offset: previous_offset} = state) do
    offset = timezone_offset(local_now(state))
    {offset - previous_offset, %State{state | timezone_offset: offset}}
  end

  @spec append_time_change(State.t(), number()) :: State.t()
  defp append_time_change(state, seconds)

  defp append_time_change(state, seconds) when seconds == 0, do: state

  defp append_time_change(%State{} = state, seconds) do
    entry = {:time_change, seconds / 1}

    Enum.reduce(state.logs, state, fn
      {id, %Log{enabled: true} = log}, acc ->
        append_triggered_record(log, entry, entry, id, acc)

      _log, acc ->
        acc
    end)
  end

  @spec check_log_time(State.t()) :: State.t()
  defp check_log_time(%State{} = state) do
    Enum.reduce(Map.keys(state.logs), state, &refresh_log_time(&2, &1))
  end

  @spec refresh_log_time(State.t(), term()) :: State.t()
  defp refresh_log_time(state, id) do
    case state.logs[id] do
      %Log{} = log ->
        enabled = log_enabled?(log.object, state)

        if enabled != log.enabled do
          operation = if enabled, do: :enable, else: :disable
          new_log = append_record(%{log | enabled: enabled}, operation, id, state)
          new_log = handle_change_enabled_state(new_log, id, log, state)
          store_record(state, id, log, new_log)
        else
          state
        end

      nil ->
        state
    end
  end

  @spec append_triggered_record(Log.t(), log_datum(), term(), term(), State.t()) :: State.t()
  defp append_triggered_record(%Log{} = log, log_datum, log_entry, id, %State{} = state) do
    new_log = append_record(log, log_datum, id, state)
    Telemetry.execute_trend_logger_log_trigger(self(), new_log, log_entry, state)
    store_record(state, id, log, new_log)
  end

  @spec store_record(State.t(), term(), Log.t(), Log.t()) :: State.t()
  defp store_record(state, id, old_log, log) do
    new_state = put_in(state.logs[id], log)
    if log.enabled != old_log.enabled, do: reconcile_cov(new_state, id), else: new_state
  end

  defp make_id(%{object_instance: num} = object) do
    {ObjectsUtility.get_object_type(object), num}
  end

  @spec log_enabled?(object(), State.t()) :: boolean()
  defp log_enabled?(object, state)

  defp log_enabled?(%{enable: true, start_time: nil, stop_time: nil}, _state), do: true

  defp log_enabled?(%{enable: true, start_time: start, stop_time: stop}, %State{} = state) do
    now = DateTime.to_naive(local_now(state))

    bound_allows_logging?(start, now, :gt) and bound_allows_logging?(stop, now, :lt)
  end

  defp log_enabled?(_object, _state), do: false

  @spec bound_allows_logging?(BACnetDateTime.t() | nil, NaiveDateTime.t(), :gt | :lt) :: boolean()
  defp bound_allows_logging?(bound, now, comparison)

  defp bound_allows_logging?(nil, _now, _comparison), do: true

  defp bound_allows_logging?(%BACnetDateTime{} = bound, now, comparison) do
    if BACnetDateTime.specific?(bound) do
      result = NaiveDateTime.compare(now, BACnetDateTime.to_naive_datetime!(bound))
      result == comparison or (comparison == :gt and result == :eq)
    else
      true
    end
  end

  @spec increment_seq_number(non_neg_integer()) :: pos_integer()
  defp increment_seq_number(seq_number)

  defp increment_seq_number(seq_number) when seq_number >= @max_record_count, do: 1
  defp increment_seq_number(seq_number), do: seq_number + 1

  @spec restore_log(Log.t()) :: Log.t()
  defp restore_log(log) do
    fields =
      Map.put_new_lazy(Map.from_struct(log), :records_since_notification, fn ->
        if log.intrinsic_reporting do
          previous = BufferReady.previous_count(log.intrinsic_reporting)
          difference = log.seq_number - previous

          cond do
            log.seq_number == 0 -> 0
            difference >= 0 -> difference
            true -> difference + @max_record_count
          end
        end
      end)

    fields =
      fields
      |> Map.put_new(:buffer_ready_mode, :standalone)
      |> Map.put(:buffer_ready_signalled, false)
      |> Map.put(:acquisition_token, make_ref())

    struct!(Log, fields)
  end

  @spec apply_log_mechanism(Log.t(), object(), term(), State.t()) :: Log.t()
  defp apply_log_mechanism(log, object, id, state)

  defp apply_log_mechanism(
         %{enabled: true, mode: @const_log_type_polled} = log,
         object,
         id,
         state
       ) do
    # Keep this reference through the lookup to reject stale requests and results
    delay = PollSchedule.delay(object, local_now(state))
    timer = :erlang.start_timer(delay, self(), {:poll_log, id})

    %{log | poll_timer: timer}
  end

  defp apply_log_mechanism(log, _term, _id, _state) do
    # Catch-all for EventLog, TrendLog/TrendLogMultiple (with logging_type = triggered or cov)
    log
  end

  defp cancel_poll_timer(%Log{poll_timer: timer} = log) do
    if timer != nil, do: Process.cancel_timer(timer)
    %Log{log | poll_timer: nil}
  end

  defp realign_poll_timers(%State{} = state) do
    logs =
      Map.new(state.logs, fn
        {id, %Log{enabled: true, mode: @const_log_type_polled} = log} ->
          if PollSchedule.alignment(log.object) != nil do
            log = cancel_poll_timer(log)
            {id, apply_log_mechanism(log, log.object, id, state)}
          else
            {id, log}
          end

        entry ->
          entry
      end)

    %State{state | logs: logs}
  end

  @spec handle_change_enabled_state(Log.t(), term(), Log.t(), State.t()) :: Log.t()
  defp handle_change_enabled_state(log, id, previous_log, state)

  defp handle_change_enabled_state(
         %Log{
           enabled: true,
           mode: @const_log_type_polled,
           object: %{log_interval: interval, log_device_object_property: reference}
         } = log,
         id,
         %Log{
           enabled: true,
           mode: @const_log_type_polled,
           object: %{log_interval: interval, log_device_object_property: reference}
         } = previous_log,
         state
       ) do
    if PollSchedule.alignment(log.object) == PollSchedule.alignment(previous_log.object) do
      log
    else
      restart_log_mechanism(log, id, previous_log, state)
    end
  end

  defp handle_change_enabled_state(%Log{} = log, id, %Log{} = previous_log, %State{} = state) do
    restart_log_mechanism(log, id, previous_log, state)
  end

  defp restart_log_mechanism(%Log{} = log, id, %Log{} = previous_log, %State{} = state) do
    cancel_poll_timer(previous_log)
    apply_log_mechanism(%Log{log | poll_timer: nil}, log.object, id, state)
  end

  @spec merge_log_configuration(
          object(),
          object(),
          Constants.property_identifier() | nil
        ) :: object()
  defp merge_log_configuration(current, candidate, property)

  defp merge_log_configuration(_current, candidate, nil), do: candidate

  defp merge_log_configuration(current, candidate, property)
       when property in [:start_time, :stop_time] do
    %{current | start_time: candidate.start_time, stop_time: candidate.stop_time}
  end

  defp merge_log_configuration(current, candidate, property)
       when is_trend_log(current) and is_trend_log(candidate) and
              property in [:log_interval, :logging_type] do
    %{current | log_interval: candidate.log_interval, logging_type: candidate.logging_type}
  end

  defp merge_log_configuration(current, candidate, property)
       when is_trend_log(current) and is_trend_log(candidate) and
              property in [:align_intervals, :interval_offset] do
    %{
      current
      | align_intervals: candidate.align_intervals,
        interval_offset: candidate.interval_offset
    }
  end

  defp merge_log_configuration(current, candidate, property) do
    Map.replace!(current, property, Map.fetch!(candidate, property))
  end

  @spec resize_log_buffer(Log.t(), non_neg_integer(), module()) :: Log.t()
  defp resize_log_buffer(log, size, buffer_module)

  defp resize_log_buffer(%Log{object: %{buffer_size: size}} = log, size, _buffer_module), do: log

  defp resize_log_buffer(%Log{} = log, size, buffer_module) do
    buffer = buffer_module.from_list(buffer_module.to_list(log.buffer), if(size > 0, do: size))
    %{log | buffer: buffer}
  end

  @spec reconfigure_log(Log.t(), Log.t(), boolean(), atom() | nil, term(), State.t()) :: Log.t()
  defp reconfigure_log(log, old_log, full, property, id, state) do
    reference_changed = references_changed?(log.object, old_log.object)

    log =
      if reference_changed or log.mode != old_log.mode do
        %{log | acquisition_token: make_ref()}
      else
        log
      end

    if reference_changed do
      purge_log(log, id, state)
    else
      update_log_buffer(log, old_log, full, property == :stop_when_full, id, state)
    end
  end

  @spec references_changed?(object(), object()) :: boolean()
  defp references_changed?(current, previous)

  defp references_changed?(%TrendLog{} = current, %TrendLog{} = previous) do
    current.log_device_object_property != previous.log_device_object_property
  end

  defp references_changed?(%TrendLogMultiple{} = current, %TrendLogMultiple{} = previous) do
    references = current.log_device_object_property
    old_references = previous.log_device_object_property
    references != old_references and log_references(references) != log_references(old_references)
  end

  defp references_changed?(_current, _previous), do: false

  @spec purge_log(Log.t(), term(), State.t()) :: Log.t()
  defp purge_log(log, id, state) do
    empty_log = %{log | buffer: state.log_buff_mod.truncate(log.buffer)}
    purged_log = append_record(empty_log, :purged, id, state)
    %{purged_log | records_since_notification: if(log.intrinsic_reporting, do: 0)}
  end

  @spec update_log_buffer(Log.t(), Log.t(), boolean(), boolean(), term(), State.t()) :: Log.t()
  defp update_log_buffer(log, old_log, full, stop_written, id, state) do
    cond do
      full and (stop_written or log.object.enable or not old_log.object.stop_when_full) ->
        send(self(), {:maybe_notify_receiver, id})
        append_stop_record(log, :disable, state)

      log.enabled != old_log.enabled ->
        append_record(log, if(log.enabled, do: :enable, else: :disable), id, state)

      log.object.buffer_size != old_log.object.buffer_size ->
        send(self(), {:maybe_notify_receiver, id})
        log

      true ->
        log
    end
  end

  @spec buffer_reaches_capacity?(Log.t(), non_neg_integer(), State.t()) :: boolean()
  defp buffer_reaches_capacity?(log, incoming, %State{log_buff_mod: buffer_module}) do
    case buffer_module.get_max_size(log.buffer) do
      nil -> false
      capacity -> buffer_module.get_size(log.buffer) + incoming >= capacity
    end
  end

  @spec append_stop_record(Log.t(), :disable | :purged | :interrupted, State.t()) :: Log.t()
  defp append_stop_record(log, status, state) do
    stopped = cancel_poll_timer(%{log | enabled: false, object: %{log.object | enable: false}})
    new_log = insert_record(stopped, create_record(stopped, status, state), state)

    if state.opts.notification_receiver == nil do
      Telemetry.execute_trend_logger_log_notify(self(), new_log, :buffer_full, state)
    end

    new_log
  end

  @spec append_record(Log.t(), log_datum(), term(), State.t(), BACnetDateTime.t() | nil) ::
          Log.t()
  defp append_record(log, datum, id, state, timestamp \\ nil) do
    stop_when_full = log.object.enable and log.object.stop_when_full

    new_log =
      if stop_when_full and buffer_reaches_capacity?(log, 1, state) do
        # Reserve the final slot for the disabled status. A status record in
        # that slot can report both the stop and the original event.
        status = if datum in [:purged, :interrupted], do: datum, else: :disable
        append_stop_record(log, status, state)
      else
        record = create_record(log, datum, state)
        record = if timestamp, do: %{record | timestamp: timestamp}, else: record
        appended = insert_record(log, record, state)

        if stop_when_full and buffer_reaches_capacity?(appended, 1, state) do
          append_stop_record(appended, :disable, state)
        else
          appended
        end
      end

    send(self(), {:maybe_notify_receiver, id})
    new_log
  end

  @spec insert_record(
          Log.t(),
          EventLogRecord.t() | LogRecord.t() | LogMultipleRecord.t(),
          State.t()
        ) ::
          Log.t()
  defp insert_record(log, record, state) do
    count = log.records_since_notification

    %{
      log
      | buffer: state.log_buff_mod.checkin(log.buffer, record),
        records_since_notification: if(count != nil, do: min(count + 1, @max_record_count)),
        seq_number: increment_seq_number(log.seq_number)
    }
  end

  @spec snapshot(Log.t(), State.t()) :: snapshot()
  defp snapshot(log, state) do
    %{
      buffer: {state.log_buff_mod, log.buffer},
      enable: log.object.enable,
      collecting: log.enabled,
      record_count: state.log_buff_mod.get_size(log.buffer),
      total_record_count: log.seq_number,
      records_since_notification: log.records_since_notification,
      last_notify_record:
        log.intrinsic_reporting && BufferReady.previous_count(log.intrinsic_reporting)
    }
  end

  @spec buffer_ready_enabled?(object()) :: boolean()
  defp buffer_ready_enabled?(object) do
    object.event_detection_enable != false and object.event_algorithm_inhibit != true and
      object.event_state in [nil, :normal] and object.reliability in [nil, :no_fault_detected]
  end

  @spec update_buffer_ready_configuration(Log.t(), Log.t(), term()) :: Log.t()
  defp update_buffer_ready_configuration(log, previous, id) do
    threshold = log.object.notification_threshold

    log =
      if log.intrinsic_reporting != nil and threshold != previous.object.notification_threshold and
           is_integer(threshold) do
        params = %BufferReadyParams{
          threshold: threshold,
          previous_count: BufferReady.previous_count(log.intrinsic_reporting)
        }

        %{
          log
          | intrinsic_reporting: BufferReady.update(log.intrinsic_reporting, parameters: params)
        }
      else
        log
      end

    if Map.take(log.object, @reporting_properties) !=
         Map.take(previous.object, @reporting_properties) do
      send(self(), {:check_buffer_ready, id})
    end

    log
  end

  @spec notify_log(State.t(), term(), boolean()) :: State.t()
  defp notify_log(state, id, check_full?) do
    case Map.fetch(state.logs, id) do
      {:ok, log} ->
        {updated, notification} = prepare_buffer_ready(log, state)
        receiver = state.opts.notification_receiver

        if receiver != nil do
          metadata = %{
            buffer: {state.log_buff_mod, log.buffer},
            event: nil,
            intrinsic_reporting: nil
          }

          if check_full? and buffer_reaches_capacity?(log, 0, state) do
            Telemetry.execute_trend_logger_log_notify(self(), log, :buffer_full, state)

            send(
              receiver,
              {:bacnet_trend_logger, nil, log.object, %{metadata | event: :buffer_full}}
            )
          end

          if notification != nil do
            send(
              receiver,
              {:bacnet_trend_logger, nil, log.object,
               %{metadata | event: :intrinsic_reporting, intrinsic_reporting: notification}}
            )
          end
        end

        put_in(state.logs[id], updated)

      :error ->
        state
    end
  end

  @spec prepare_buffer_ready(Log.t(), State.t()) ::
          {Log.t(), NotificationParameters.BufferReady.t() | nil}
  defp prepare_buffer_ready(log, state)

  defp prepare_buffer_ready(%Log{intrinsic_reporting: nil} = log, _state), do: {log, nil}

  defp prepare_buffer_ready(%Log{buffer_ready_mode: :standalone} = log, state) do
    if buffer_ready_enabled?(log.object) do
      update_intrinsic_reporting(log, state)
    else
      {log, nil}
    end
  end

  defp prepare_buffer_ready(
         %Log{buffer_ready_signalled: false} = log,
         %State{opts: %{notification_receiver: receiver}}
       )
       when receiver != nil do
    case buffer_ready_event(log) do
      {:event, _algorithm, notification} ->
        {%{log | buffer_ready_signalled: true}, notification}

      {:no_event, _algorithm} ->
        {log, nil}
    end
  end

  defp prepare_buffer_ready(log, _state), do: {log, nil}

  @spec buffer_ready_event(Log.t()) ::
          {:event, BufferReady.t(), NotificationParameters.BufferReady.t()}
          | {:no_event, BufferReady.t()}
  defp buffer_ready_event(log) do
    event =
      log.intrinsic_reporting
      |> BufferReady.update(monitored_value: log.seq_number)
      |> BufferReady.execute()

    case event do
      {:event, algorithm, notification} ->
        # Older saved algorithms can still carry the source-property reference.
        {:event, algorithm, %{notification | buffer_property: log_buffer_reference(log.object)}}

      {:no_event, _algorithm} = outcome ->
        outcome
    end
  end

  @spec update_intrinsic_reporting(Log.t(), State.t()) ::
          {Log.t(), NotificationParameters.BufferReady.t() | nil}
  defp update_intrinsic_reporting(%Log{} = log, %State{} = state) do
    {updated, notification} =
      case buffer_ready_event(log) do
        {:event, algorithm, notification} ->
          {%{log | intrinsic_reporting: algorithm, records_since_notification: 0}, notification}

        {:no_event, algorithm} ->
          {%{log | intrinsic_reporting: algorithm}, nil}
      end

    if notification != nil or log.buffer_ready_mode == :standalone do
      Telemetry.execute_trend_logger_log_notify(self(), updated, :intrinsic_reporting, state)
    end

    {updated, notification}
  end

  @typep log_datum ::
           :enable
           | :disable
           | :interrupted
           | :purged
           | {:time_change, seconds :: float()}
           | ConfirmedEventNotification.t()
           | UnconfirmedEventNotification.t()
           | ConfirmedCovNotification.t()
           | UnconfirmedCovNotification.t()
           | Encoding.t()
           | BACnetError.t()
           | nil
           | [
               ConfirmedCovNotification.t()
               | UnconfirmedCovNotification.t()
               | Encoding.t()
               | BACnetError.t()
               | nil
             ]

  @spec create_record(Log.t(), log_datum(), State.t()) ::
          EventLogRecord.t() | LogRecord.t() | LogMultipleRecord.t()
  defp create_record(log, event, state)

  defp create_record(%Log{object: %EventLog{}} = log, event, state) do
    log_datum =
      case event do
        term when term in [:enable, :disable, :interrupted, :purged] ->
          %LogStatus{
            log_disabled: not log.enabled,
            buffer_purged: term == :purged,
            log_interrupted: term == :interrupted
          }

        %ConfirmedEventNotification{} = _term ->
          event

        %UnconfirmedEventNotification{} = _term ->
          # Convert into ConfirmedEventNotification (same struct but different name)
          struct(ConfirmedEventNotification, Map.from_struct(event))

        {:time_change, _time} = _term ->
          event
      end

    %EventLogRecord{
      timestamp: BACnetDateTime.from_datetime(local_now(state)),
      log_datum: log_datum
    }
  end

  defp create_record(%Log{object: %TrendLog{} = object} = log, event, state) do
    log_datum =
      case event do
        term when term in [:enable, :disable, :interrupted, :purged] ->
          %LogStatus{
            log_disabled: not log.enabled,
            buffer_purged: term == :purged,
            log_interrupted: term == :interrupted
          }

        term when is_list(term) ->
          nil

        %ConfirmedEventNotification{} = _term ->
          nil

        %UnconfirmedEventNotification{} = _term ->
          nil

        %{property_values: property_values} = _term ->
          property = object.log_device_object_property.property_identifier
          array_index = object.log_device_object_property.property_array_index

          Enum.find_value(property_values, nil, fn
            %PropertyValue{
              property_identifier: ^property,
              property_array_index: ^array_index
            } = prop ->
              prop.property_value

            _else ->
              false
          end)

        _else ->
          event
      end

    status_flags =
      case event do
        %{property_values: property_values} = _term ->
          Enum.find_value(property_values, nil, fn
            %PropertyValue{
              property_identifier:
                Constants.macro_assert_name(:property_identifier, :status_flags)
            } = prop ->
              prop.property_value

            _else ->
              false
          end)

        _else ->
          nil
      end

    %LogRecord{
      timestamp: BACnetDateTime.from_datetime(local_now(state)),
      log_datum: log_datum,
      status_flags: status_flags
    }
  end

  defp create_record(%Log{object: %TrendLogMultiple{}} = log, event, state) do
    time_now = local_now(state)

    log_data =
      case event do
        term when term in [:enable, :disable, :interrupted, :purged] ->
          %LogStatus{
            log_disabled: not log.enabled,
            buffer_purged: term == :purged,
            log_interrupted: term == :interrupted
          }

        {:time_change, _time} ->
          event

        term when is_list(term) ->
          event
      end

    %LogMultipleRecord{
      timestamp: BACnetDateTime.from_datetime(time_now),
      log_data: log_data
    }
  end

  @spec create_internal_error_error() :: BACnetError.t()
  defp create_internal_error_error() do
    %BACnetError{
      class: Constants.macro_assert_name(:error_class, :device),
      code: Constants.macro_assert_name(:error_code, :internal_error)
    }
  end

  @spec create_invalid_datatype_error() :: BACnetError.t()
  defp create_invalid_datatype_error() do
    %BACnetError{
      class: Constants.macro_assert_name(:error_class, :property),
      code: Constants.macro_assert_name(:error_code, :invalid_datatype)
    }
  end

  @spec create_timeout_error() :: BACnetError.t()
  defp create_timeout_error() do
    %BACnetError{
      class: Constants.macro_assert_name(:error_class, :communication),
      code: Constants.macro_assert_name(:error_code, :timeout)
    }
  end

  @spec create_uninitialized_error() :: BACnetError.t()
  defp create_uninitialized_error() do
    %BACnetError{
      class: Constants.macro_assert_name(:error_class, :property),
      code: Constants.macro_assert_name(:error_code, :no_property_specified)
    }
  end

  @spec find_log_datum_from_notify(
          TrendLog.t(),
          ConfirmedCovNotification.t() | UnconfirmedCovNotification.t(),
          State.t()
        ) :: {:cont, value :: Encoding.t() | [Encoding.t()]} | State.t()
  defp find_log_datum_from_notify(object, notification, state)

  defp find_log_datum_from_notify(
         %TrendLog{log_device_object_property: objref},
         %ConfirmedCovNotification{initiating_device: device, monitored_object: mon_object} =
           notification,
         state
       ) do
    if (objref.device_identifier == nil and match?(%{object_identifier: ^mon_object}, objref)) or
         match?(%{device_identifier: ^device, object_identifier: ^mon_object}, objref) do
      property = objref.property_identifier
      array_index = objref.property_array_index

      Enum.find_value(notification.property_values, fn
        %PropertyValue{
          property_identifier: ^property,
          property_array_index: ^array_index,
          property_value: value
        } ->
          {:cont, value}

        %{} ->
          false
      end) || state
    else
      state
    end
  end

  defp find_log_datum_from_notify(
         %TrendLog{} = object,
         %UnconfirmedCovNotification{} = notification,
         state
       ) do
    find_log_datum_from_notify(
      object,
      struct(ConfirmedCovNotification, Map.from_struct(notification)),
      state
    )
  end

  defp create_encoding_for_notify(%Encoding{} = encoding, _state) do
    case encoding do
      # We do not need to create a new encoding, because the LogRecord encoder
      # takes care of using the proper tag number and encoding for us
      %Encoding{type: :boolean} -> {:ok, encoding}
      %Encoding{type: :real} -> {:ok, encoding}
      %Encoding{type: :enumerated} -> {:ok, encoding}
      %Encoding{type: :unsigned_integer} -> {:ok, encoding}
      %Encoding{type: :signed_integer} -> {:ok, encoding}
      %Encoding{type: :bitstring} -> {:ok, encoding}
      %Encoding{type: :null} -> {:ok, encoding}
      %Encoding{} -> Encoding.create({:constructed, {10, Encoding.to_encoding!(encoding), 0}})
    end
  end

  @typep property_sample :: Encoding.t() | BACnetError.t() | nil

  @spec find_log_datum_from_trigger(object(), term()) ::
          {:ok, log_datum()} | {:error, :invalid_log} | :skip
  defp find_log_datum_from_trigger(object, entry)

  defp find_log_datum_from_trigger(_object, entry)
       when entry == :interrupted or is_time_change_tuple(entry),
       do: {:ok, entry}

  defp find_log_datum_from_trigger(%EventLog{}, %ConfirmedEventNotification{} = entry),
    do: {:ok, entry}

  defp find_log_datum_from_trigger(%EventLog{}, %UnconfirmedEventNotification{} = entry),
    do: {:ok, struct(ConfirmedEventNotification, Map.from_struct(entry))}

  defp find_log_datum_from_trigger(%TrendLog{}, %ConfirmedCovNotification{} = entry),
    do: {:ok, entry}

  defp find_log_datum_from_trigger(%TrendLog{}, %UnconfirmedCovNotification{} = entry),
    do: {:ok, struct(ConfirmedCovNotification, Map.from_struct(entry))}

  defp find_log_datum_from_trigger(%TrendLog{log_device_object_property: reference}, source)
       when ObjectsUtility.is_object(source) do
    if uninitialized_reference?(reference) do
      {:ok, create_uninitialized_error()}
    else
      {:ok, read_log_datum(reference, source)}
    end
  end

  defp find_log_datum_from_trigger(%TrendLogMultiple{} = log, sources) when is_list(sources) do
    case log_references(log.log_device_object_property) do
      [] -> :skip
      references -> {:ok, Enum.map(references, &find_triggered_sample(&1, sources))}
    end
  end

  defp find_log_datum_from_trigger(_object, _entry), do: {:error, :invalid_log}

  @spec log_references(BACnetArray.t(DeviceObjectPropertyRef.t())) ::
          [DeviceObjectPropertyRef.t() | nil]
  defp log_references(references) do
    # An unset array slot must still have a corresponding failure in the record.
    for index <- 1..BACnetArray.size(references)//1 do
      case BACnetArray.get_item(references, index) do
        {:ok, reference} -> reference
        :error -> nil
      end
    end
  end

  @spec uninitialized_reference?(DeviceObjectPropertyRef.t() | nil) :: boolean()
  defp uninitialized_reference?(reference)

  defp uninitialized_reference?(nil), do: true

  defp uninitialized_reference?(%DeviceObjectPropertyRef{} = reference) do
    reference.object_identifier.instance == @asn1_uninitialized_id or
      match?(%ObjectIdentifier{instance: @asn1_uninitialized_id}, reference.device_identifier)
  end

  @spec read_log_datum(DeviceObjectPropertyRef.t(), ObjectsUtility.bacnet_object()) ::
          property_sample()
  defp read_log_datum(reference, object) do
    property = reference.property_identifier

    with true <- is_atom(property),
         {:ok, value} <- ObjectsUtility.get_property(object, property),
         {:ok, value} <- select_log_value(value, reference.property_array_index) do
      case create_encoding(object, property, value) do
        {:ok, encoding} -> encoding
        {:error, _reason} -> create_invalid_datatype_error()
        encoding_or_error -> encoding_or_error
      end
    else
      %BACnetError{} = error -> error
      _other -> %BACnetError{class: :property, code: :unknown_property}
    end
  end

  @spec select_log_value(term(), non_neg_integer() | nil) :: {:ok, term()} | BACnetError.t()
  defp select_log_value(value, index)

  defp select_log_value(value, nil), do: {:ok, value}

  defp select_log_value(%BACnetArray{} = array, index) do
    case BACnetArray.get_item(array, index) do
      {:ok, _value} = result -> result
      :error -> %BACnetError{class: :property, code: :invalid_array_index}
    end
  end

  defp select_log_value(_value, _index),
    do: %BACnetError{class: :property, code: :property_is_not_an_array}

  @spec create_encoding(ObjectsUtility.bacnet_object(), atom(), term()) ::
          {:ok, Encoding.t()} | {:error, term()} | property_sample()
  defp create_encoding(object, property, value)

  defp create_encoding(_object, _property, nil), do: nil
  defp create_encoding(_object, _property, %Encoding{} = value), do: value

  defp create_encoding(%mod{} = object, property, value)
       when is_atom(property) and ObjectsUtility.is_object(object) do
    with :cont <-
           (case Keyword.fetch(mod.get_annotation(property), :encoder) do
              {:ok, term} -> {:ok, {:fun, term}}
              :error -> :cont
            end),
         prop_type_map = mod.get_properties_type_map(),
         :cont <-
           (case prop_type_map do
              %{^property => type} ->
                # TODO: Support for more types (i.e. literal - how?)
                case type do
                  {:constant, term} ->
                    {:ok, {:const, Constants.by_name_atom(term, value)}}

                  # Needs to be explicitely handled (according to Elixir typechecker)
                  {:struct, Encoding} ->
                    {:ok, {:fun, &Encoding.to_encoding/1}}

                  # Needs to be explicitely handled (according to Elixir typechecker)
                  {:struct, PriorityArray} ->
                    case Map.fetch(prop_type_map, :present_value) do
                      {:ok, type} -> {:ok, {:type, type}}
                      :error -> create_invalid_datatype_error()
                    end

                  {:struct, term} ->
                    {:ok, {:fun, fn value -> term.encode(value) end}}

                  term when is_atom(term) ->
                    {:ok, {:type, term}}

                  _else ->
                    create_invalid_datatype_error()
                end

              %{} ->
                :cont
            end) do
      %BACnetError{
        class: Constants.macro_assert_name(:error_class, :property),
        code: Constants.macro_assert_name(:error_code, :unknown_property)
      }
    else
      {:ok, {:const, raw_val}} ->
        Encoding.create(ApplicationTags.create_tag_encoding(2, :enumerated, raw_val),
          cast_type: :enumerated
        )

      {:ok, {:fun, encoder}} ->
        Encoding.create({:constructed, {10, value, 0}}, encoder: encoder)

      {:ok, {:type, type}} ->
        Encoding.create({type, value})

      term ->
        term
    end
  end

  @spec find_triggered_sample(
          DeviceObjectPropertyRef.t() | nil,
          [ObjectsUtility.bacnet_object()]
        ) :: property_sample()
  defp find_triggered_sample(reference, sources) do
    if uninitialized_reference?(reference) do
      create_uninitialized_error()
    else
      device = reference.device_identifier && reference.device_identifier.instance
      module = ObjectsUtility.get_object_type_mappings()[reference.object_identifier.type]
      instance = reference.object_identifier.instance

      case Enum.find(
             sources,
             &match?(
               %{
                 __struct__: ^module,
                 _metadata: %{remote_object: ^device},
                 object_instance: ^instance
               },
               &1
             )
           ) do
        nil -> %BACnetError{class: :object, code: :unknown_object}
        source -> read_log_datum(reference, source)
      end
    end
  end

  @spec acquire_sample(
          pid(),
          function(),
          TrendLog.t() | TrendLogMultiple.t(),
          Supervisor.supervisor() | nil
        ) :: property_sample() | [property_sample()]
  defp acquire_sample(server, lookup_cb, object, supervisor)

  defp acquire_sample(server, lookup_cb, %TrendLog{} = object, supervisor) do
    acquire_log_data(server, lookup_cb, object, supervisor)
  end

  defp acquire_sample(server, lookup_cb, %TrendLogMultiple{} = object, supervisor) do
    # Keep the task stream's exit handling in a separate process.
    task = Task.async(fn -> acquire_log_data(server, lookup_cb, object, supervisor) end)
    Task.await(task, :infinity)
  end

  @spec acquire_log_data(
          pid(),
          function(),
          TrendLog.t() | TrendLogMultiple.t(),
          Supervisor.supervisor() | nil
        ) ::
          property_sample() | [property_sample()]
  defp acquire_log_data(server, lookup_cb, object, supervisor)

  defp acquire_log_data(server, lookup_cb, %TrendLog{} = object, _supervisor) do
    acquire_log_datum(server, lookup_cb, object.log_device_object_property)
  end

  defp acquire_log_data(server, lookup_cb, %TrendLogMultiple{} = object, supervisor) do
    # For polled reads, leave 10 ms for processing
    timeout =
      if object.logging_type == @const_log_type_polled do
        max(1, min(@max_acquisition_timeout, PollSchedule.interval(object.log_interval) - 10))
      else
        @max_acquisition_timeout
      end

    object.log_device_object_property
    |> log_references()
    |> spawn_task_stream(
      supervisor,
      &acquire_log_datum(server, lookup_cb, &1),
      on_timeout: :kill_task,
      ordered: true,
      timeout: timeout
    )
    |> Enum.map(fn
      {:ok, value} -> value
      {:exit, :timeout} -> create_timeout_error()
      {:exit, _reason} -> create_internal_error_error()
    end)
  end

  @spec acquire_log_datum(pid(), function(), DeviceObjectPropertyRef.t() | nil) ::
          property_sample()
  defp acquire_log_datum(server, lookup_cb, reference) do
    if uninitialized_reference?(reference) do
      create_uninitialized_error()
    else
      case run_lookup_cb(server, lookup_cb, reference) do
        %BACnetError{} = error -> error
        object -> read_log_datum(reference, object)
      end
    end
  end

  @spec create_intrinsic(object()) :: BufferReady.t()
  defp create_intrinsic(%{} = object) when is_object(object) do
    params = %BufferReadyParams{
      threshold: object.notification_threshold,
      previous_count: object.last_notify_record
    }

    BufferReady.new(object.total_record_count, log_buffer_reference(object), params)
  end

  @spec log_buffer_reference(object()) :: DeviceObjectPropertyRef.t()
  defp log_buffer_reference(object) do
    %DeviceObjectPropertyRef{
      object_identifier: ObjectsUtility.get_object_identifier(object),
      property_identifier: Constants.macro_assert_name(:property_identifier, :log_buffer),
      property_array_index: nil,
      device_identifier: nil
    }
  end

  @spec run_lookup_cb(pid(), fun(), DeviceObjectPropertyRef.t()) ::
          ObjectsUtility.bacnet_object() | BACnetError.t()
  defp run_lookup_cb(
         server_pid,
         lookup_cb,
         %{device_identifier: dev, object_identifier: obj} = _objref
       ) do
    devobjref = %DeviceObjectRef{
      device_identifier: dev,
      object_identifier: obj
    }

    Telemetry.execute_trend_logger_lookup_object_start(server_pid, devobjref)

    start_time = System.monotonic_time()

    try do
      case lookup_cb.(devobjref) do
        {:ok, new_object} when ObjectsUtility.is_object(new_object) ->
          Telemetry.execute_trend_logger_lookup_object_stop(
            server_pid,
            devobjref,
            new_object,
            System.monotonic_time() - start_time
          )

          new_object

        {:ok, _term} = term ->
          Logger.warning(fn ->
            "TrendLogger detected invalid return value from lookup_cb, got: #{inspect(term)}"
          end)

          error = create_internal_error_error()

          Telemetry.execute_trend_logger_lookup_object_error(
            server_pid,
            devobjref,
            error,
            System.monotonic_time() - start_time
          )

          error

        {:error, %BACnetError{} = error} ->
          Telemetry.execute_trend_logger_lookup_object_error(
            server_pid,
            devobjref,
            error,
            System.monotonic_time() - start_time
          )

          error

        {:error, _err} = term ->
          Logger.warning(fn -> "TrendLogger got error from lookup_cb, got: #{inspect(term)}" end)
          error = create_internal_error_error()

          Telemetry.execute_trend_logger_lookup_object_error(
            server_pid,
            devobjref,
            error,
            System.monotonic_time() - start_time
          )

          error

        term ->
          Logger.warning(fn ->
            "TrendLogger detected invalid return value from lookup_cb, got: #{inspect(term)}"
          end)

          error = create_internal_error_error()

          Telemetry.execute_trend_logger_lookup_object_error(
            server_pid,
            devobjref,
            error,
            System.monotonic_time() - start_time
          )

          error
      end
    catch
      type, err ->
        Logger.warning(fn ->
          "TrendLogger has catched an error from the lookup_cb, type: #{inspect(type)}, error: #{inspect(err)}"
        end)

        error = create_internal_error_error()

        Telemetry.execute_trend_logger_lookup_object_error(
          server_pid,
          devobjref,
          error,
          System.monotonic_time() - start_time
        )

        error
    end
  end

  # An enabled COV Trend Log requests a subscription when it has an initialized
  # remote reference, a positive renewal interval, and a configured callback.
  # `cov_subscriptions` tracks the reference and settings sent to the callback
  # separately, so an old reference can still be retired after its log changes
  # or is removed.
  #
  # Each log has at most one callback in flight. Its completion reconciles
  # against the latest log configuration. A manual refresh requested while
  # the callback runs is queued in the `refresh` flag. Successful subscriptions
  # arm a renewal at the configured interval and failures arm a retry.
  # Request and timer references let the handlers ignore stale messages.
  #
  # Changes to the interval or increment renew the same reference. When a log
  # changes reference or stops using COV, retire the old reference before
  # subscribing to the new one. If another enabled log still uses the old
  # reference, release only this log's tracking. Any new subscription to a
  # reference being unsubscribed waits for that callback to finish.

  @spec reconcile_cov(State.t(), term(), boolean()) :: State.t()
  defp reconcile_cov(state, id, refresh \\ false) do
    configuration = cov_configuration(state.logs[id], state.opts.cov_cb)

    case {state.cov_subscriptions[id], configuration} do
      {%{pending: {_operation, _request}}, _configuration} ->
        if refresh, do: put_in(state.cov_subscriptions[id].refresh, true), else: state

      {%{configuration: ^configuration, refresh: false}, _configuration} when not refresh ->
        state

      {%{configuration: {reference, _old_interval, _old_increment}},
       {reference, _interval, _increment} = current} ->
        start_cov_subscription(state, id, current)

      {%{configuration: previous}, _configuration} ->
        retire_cov_subscription(state, id, previous)

      {nil, nil} ->
        state

      {nil, current} ->
        start_cov_subscription(state, id, current)
    end
  end

  @spec cov_configuration(Log.t() | nil, function() | nil) :: State.cov_configuration() | nil
  defp cov_configuration(log, callback)

  defp cov_configuration(
         %Log{
           enabled: true,
           mode: @const_log_type_cov,
           object: %TrendLog{
             cov_resubscription_interval: interval,
             client_cov_increment: increment,
             log_device_object_property:
               %DeviceObjectPropertyRef{
                 device_identifier: %ObjectIdentifier{instance: device},
                 object_identifier: %ObjectIdentifier{instance: object}
               } = reference
           }
         },
         callback
       )
       when is_function(callback, 5) and is_integer(interval) and interval > 0 and
              device != @asn1_uninitialized_id and object != @asn1_uninitialized_id do
    {reference, interval, increment}
  end

  defp cov_configuration(_log, _callback), do: nil

  @spec start_cov_subscription(State.t(), term(), State.cov_configuration()) :: State.t()
  defp start_cov_subscription(state, id, {reference, _interval, _increment} = configuration) do
    retiring =
      Enum.any?(state.cov_subscriptions, fn
        {_id,
         %{
           configuration: {^reference, _old_interval, _old_increment},
           pending: {:unsub, _request}
         }} ->
          true

        _entry ->
          false
      end)

    if retiring, do: state, else: start_cov_request(state, id, :sub, configuration)
  end

  @spec retire_cov_subscription(State.t(), term(), State.cov_configuration()) :: State.t()
  defp retire_cov_subscription(state, id, {reference, _interval, _increment} = configuration) do
    shared =
      Enum.any?(state.logs, fn
        {^id, _log} ->
          false

        {_id, log} ->
          match?(
            {^reference, _other_interval, _other_increment},
            cov_configuration(log, state.opts.cov_cb)
          )
      end)

    if shared do
      cancel_cov_timer(state, id)
      state = %{state | cov_subscriptions: Map.delete(state.cov_subscriptions, id)}
      reconcile_cov(state, id)
    else
      start_cov_request(state, id, :unsub, configuration)
    end
  end

  @spec start_cov_request(State.t(), term(), :sub | :unsub, State.cov_configuration()) ::
          State.t()
  defp start_cov_request(state, id, operation, configuration) do
    cancel_cov_timer(state, id)

    server = self()
    request = make_ref()
    callback = state.opts.cov_cb

    result =
      spawn_task(
        fn ->
          success = run_cov_callback(callback, server, operation, configuration)
          send(server, {:cov_complete, id, request, success})
        end,
        state
      )

    case result do
      {:ok, _pid} -> :ok
      {:error, _reason} -> send(server, {:cov_complete, id, request, false})
    end

    put_in(state.cov_subscriptions[id], %{
      configuration: configuration,
      pending: {operation, request},
      timer: nil,
      refresh: false
    })
  end

  @spec cancel_cov_timer(State.t(), term()) :: :ok
  defp cancel_cov_timer(state, id) do
    case state.cov_subscriptions[id] do
      %{timer: timer} when is_reference(timer) -> Process.cancel_timer(timer)
      _entry -> :ok
    end

    :ok
  end

  @spec run_cov_callback(function(), pid(), :sub | :unsub, State.cov_configuration()) :: boolean()
  defp run_cov_callback(callback, server, operation, {reference, interval, increment}) do
    {lifetime, increment} =
      case operation do
        :sub ->
          Telemetry.execute_trend_logger_cov_sub(server, reference)
          {interval * 2, increment}

        :unsub ->
          Telemetry.execute_trend_logger_cov_unsub(server, reference)
          {0, nil}
      end

    case callback.(server, reference, operation, lifetime, increment) do
      :ok ->
        true

      term ->
        Logger.warning(fn ->
          "TrendLogger COV callback returned #{inspect(term)} for #{operation}"
        end)

        false
    end
  catch
    type, reason ->
      Logger.warning(fn ->
        "TrendLogger COV callback failed during #{operation}, #{type}: #{inspect(reason)}"
      end)

      false
  end

  # credo:disable-for-lines:50 Credo.Check.Refactor.CyclomaticComplexity
  defp validate_start_link_opts(opts) do
    case opts[:cov_cb] do
      nil ->
        :ok

      term when is_function(term, 5) ->
        :ok

      term ->
        raise ArgumentError,
              "start_link/1 expected cov_cb to be a function with arity 5, " <>
                "got: #{inspect(term)}"
    end

    case opts[:log_buffer_module] do
      nil ->
        :ok

      term ->
        unless is_atom(term) and Code.ensure_loaded?(term) do
          raise "start_link/1 expected log_buffer_module to be a module, " <>
                  "got: #{inspect(term)}"
        end
    end

    case opts[:lookup_cb] do
      nil ->
        raise ArgumentError,
              "start_link/1 expected lookup_cb to be in opts, it is missing"

      term when is_function(term, 1) ->
        :ok

      term ->
        raise ArgumentError,
              "start_link/1 expected lookup_cb to be a function with arity 1, " <>
                "got: #{inspect(term)}"
    end

    case opts[:notification_receiver] do
      nil ->
        :ok

      term when is_atom(term) ->
        :ok

      term when is_pid(term) ->
        :ok

      term when is_port(term) ->
        :ok

      term when is_tuple(term) and tuple_size(term) == 2 ->
        :ok

      term ->
        raise ArgumentError,
              "start_link/1 expected notification_receiver to be a Process destination, " <>
                "got: #{inspect(term)}"
    end

    case opts[:state] do
      nil ->
        :ok

      %State{} ->
        :ok

      term ->
        raise ArgumentError,
              "start_link/1 expected state to be a State struct, got: #{inspect(term)}"
    end

    case opts[:supervisor] do
      nil ->
        :ok

      term when is_atom(term) ->
        :ok

      term when is_pid(term) ->
        :ok

      term when is_port(term) ->
        :ok

      term when is_tuple(term) and tuple_size(term) == 2 ->
        :ok

      term ->
        raise ArgumentError,
              "start_link/1 expected supervisor to be a supervisor identifier (process destination), " <>
                "got: #{inspect(term)}"
    end

    database = Keyword.get(opts, :timezone_database, Calendar.get_time_zone_database())

    unless is_atom(database) and Code.ensure_loaded?(database) and
             function_exported?(database, :time_zone_period_from_utc_iso_days, 2) and
             function_exported?(database, :time_zone_periods_from_wall_datetime, 2) do
      raise ArgumentError,
            "start_link/1 expected timezone_database to implement Calendar.TimeZoneDatabase, " <>
              "got: #{inspect(database)}"
    end

    case opts[:timezone] do
      nil ->
        :ok

      term when is_binary(term) ->
        # Extreme validation by trying to use the timezone
        DateTime.now!(term, database)
        :ok

      term ->
        raise ArgumentError,
              "start_link/1 expected timezone to be a string, got: #{inspect(term)}"
    end
  end

  defp make_log_id(%DeviceObjectRef{device_identifier: nil} = object) do
    "(DEV)#{make_log_id(object.object_identifier)}"
  end

  defp make_log_id(
         %DeviceObjectRef{device_identifier: %ObjectIdentifier{instance: @asn1_uninitialized_id}} =
           object
       ) do
    make_log_id(%{object | device_identifier: nil})
  end

  defp make_log_id(%DeviceObjectRef{} = object) do
    "(DEV-#{object.device_identifier.instance})#{make_log_id(object.object_identifier)}"
  end

  defp make_log_id(%DeviceObjectPropertyRef{device_identifier: nil} = object) do
    "(DEV)#{make_log_id(object.object_identifier)}[P#{object.property_identifier}]"
  end

  defp make_log_id(
         %DeviceObjectPropertyRef{
           device_identifier: %ObjectIdentifier{instance: @asn1_uninitialized_id}
         } = object
       ) do
    make_log_id(%{object | device_identifier: nil})
  end

  defp make_log_id(%DeviceObjectPropertyRef{} = object) do
    "(DEV-#{object.device_identifier.instance})#{make_log_id(object.object_identifier)}[#{object.property_identifier}]"
  end

  defp make_log_id(%ObjectIdentifier{} = object) do
    "#{object.type}:#{object.instance}"
  end

  defp make_log_id(object) when is_object(object) do
    make_log_id(ObjectsUtility.get_object_identifier(object))
  end

  defp make_log_id(object), do: inspect(object)

  defp spawn_task(fun, %{opts: %{supervisor: nil}} = _state) do
    Task.start_link(fun)
  end

  defp spawn_task(fun, %{opts: %{supervisor: supervisor}} = _state) do
    Task.Supervisor.start_child(supervisor, fun)
  end

  @spec spawn_task_stream(
          Enumerable.t(),
          Supervisor.supervisor() | nil,
          (term() -> term()),
          keyword()
        ) :: Enumerable.t()
  defp spawn_task_stream(enum, supervisor, fun, opts)

  defp spawn_task_stream(enum, nil, fun, opts) do
    # The acquisition worker needs failed tasks to return an exit for their slot
    Process.flag(:trap_exit, true)
    Task.async_stream(enum, fun, opts)
  end

  defp spawn_task_stream(enum, supervisor, fun, opts) do
    Task.Supervisor.async_stream_nolink(supervisor, enum, fun, opts)
  end
end
