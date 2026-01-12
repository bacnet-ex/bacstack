defmodule BACnet.Stack.TrendLogger do
  @moduledoc """
  The Trend Logger module is responsible for handling event and trend logging
  and keeping a log buffer.

  Event logging can only occur in one mode: triggered. As per BACnet standard
  there's no defined mechanism how it gets decided which events go to which
  event log, the only way to do event logging is by explicitely triggering
  event logging with `trigger_log/3`.

  Trend logging can occur in three different modes as per BACnet standard:
  - `:triggered` - Logging has to be manually triggered through BACnet.
  - `:polled` - Logging is done periodically and for each poll, the object is read.
  - `:cov` - Logging is done through COV reporting.

  For COV reporting, COV subscription will only occur on remote object, when `cov_cb`
  is in the `opts` of `start_link/1` and if `cov_resubscription_interval` on
  the object is present and not zero.
  COV subscription does not mean the COV notifications get automatically routed
  to this module (however they can, if the given `cov_cb` callback does the routing).
  The COV callback must use confirmed COV subscriptions, as per BACnet standard.

  For COV reporting on the local device, the user has to route COV notifications
  to this module manually and invoke the `notify/2` function.

  Please note that clock-aligned logging is currently not supported by this module.

  Whenever the buffer reaches its max size, a notification can be sent to the
  specified notification receiver (an atom (registered name) or PID). Additionally,
  for Intrinsic Reporting-enabled objects, intrinsic reporting will occur and
  provide notifications once the algorithm `BUFFER_READY` triggers.

  Events occur as messages: `{:bacnet_trend_logger, nil, object(), metadata}`

  The object received is not updated when updates happen in BACnet or otherwise
  in the application. The only changes are when using `change_log_state/3` or
  when logging gets stopped due to `stop_when_full: true` (buffer is full),
  thus the object is otherwise in the same state as when it was added or updated.

  `metadata` is a map of:
  - `buffer: {module(), LogBufferBehaviour.t()}`
  - `event: :buffer_full | :intrinsic_reporting`
  - `intrinsic: NotificationParameters.BufferReady.t() | nil`

  To trigger `time_change` log data in the log buffer, these need to be manually
  triggered by the user. There's no clock time tracking in this module.
  Theoretically this can be implemented by monitoring time offsets using
  `:erlang.monitor(:time_offset, :clock_service)` and process those message.
  Upon processing these messages, one can trigger `time_change` using `trigger_log/3`.
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
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectTypes.EventLog
  alias BACnet.Protocol.ObjectTypes.TrendLog
  alias BACnet.Protocol.ObjectTypes.TrendLogMultiple
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.PropertyValue
  alias BACnet.Protocol.Services.ConfirmedEventNotification
  alias BACnet.Protocol.Services.UnconfirmedEventNotification
  alias BACnet.Protocol.Services.ConfirmedCovNotification
  alias BACnet.Protocol.Services.UnconfirmedCovNotification
  alias BACnet.Stack.LogBuffer
  alias BACnet.Stack.LogBufferBehaviour
  alias BACnet.Stack.Telemetry

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
            seq_number: non_neg_integer()
          }

    @fields [
      :enabled,
      :object,
      :mode,
      :buffer,
      :intrinsic_reporting,
      :seq_number
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
    Representative type for its purpose.
    """
    @type t :: %__MODULE__{
            log_buff_mod: module(),
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
                            {:ok, BACnet.Stack.TrendLogger.object()} | {:error, term()}),
              notification_receiver: Process.dest() | nil,
              supervisor: Supervisor.supervisor() | nil,
              timezone: Calendar.time_zone()
            }
          }

    @fields [:log_buff_mod, :logs, :opts]
    @enforce_keys @fields
    defstruct @fields
  end

  defguardp is_object_event(ref) when is_struct(ref, EventLog)
  defguardp is_object_trend(ref) when is_struct(ref, TrendLog)
  defguardp is_object_trend_multi(ref) when is_struct(ref, TrendLogMultiple)

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
  Represents valid BACnet objects. These can be handled by the trend logger.
  """
  @type object :: EventLog.t() | TrendLog.t() | TrendLogMultiple.t()

  @typedoc """
  Represents a server process of the Trend Logger module.
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
          | GenServer.option()

  @typedoc """
  List of start options.
  """
  @type start_options :: [start_option()]

  @doc """
  Starts and links the trend logger.

  Following options are available, in addition to `t:GenServer.options/0`:
  - `cov_cb: (pid(), DeviceObjectPropertyRef.t(), :sub | :unsub, non_neg_integer(), float() | nil -> :ok | {:error, term()})` - Optional.

    The given function will be used to subscribe, resubscribe and unsubscribe confirmed COV subscriptions for remote objects.
    If it is missing, no COV subscription will occur and needs to be manually handled by the user.

    The function will receive the trend logger PID, a device object property reference, the operation to subscribe or unsubscribe,
    the COV subscription lifetime and the requested client COV increment (or nil).

    The callback should automatically route COV notifications to this module's function `notify/2`. This however
    depends on the callback and the implementation details.

    For local objects, the user needs to take care of notifying the trend logger of changes (COV notifications).

  - `log_buffer_module: module()` - Optional. Set the Log Buffer implementation to use. It needs to implement the `LogBufferBehaviour`.

  - `lookup_cb: (DeviceObjectRef.t() -> {:ok, ObjectsUtility.bacnet_object()} | {:error, BACnetError.t()})` - Required.

    The given function will be used to look up objects (such as discovering the current state),
    for both local and remote objects.

    The function will receive the device object reference.

  - `notification_receiver: Process.dest()` - Optional. The recipient of notifications when either reaching
    buffer size or when Intrinsic Reporting reports an event. It may be optional, but for Intrinsic Reporting
    compliance, it is important to receive notifications and update the object state in the device server,
    including reporting events to BACnet recipients.

  - `state: State.t()` - Optional. Can be used to reinitialize the trend logger with
    pre-existing state (i.e. after restart to not lose the buffers).
    This option needs to be used with care, as a wrong value can crash the process.
    `opts` of `state` will be overwritten.

  - `supervisor: Supervisor.supervisor()` - Optional. The task supervisor to use to spawn tasks under.
    Tasks are spawned to invoke the given callback. If no supervisor is given,
    the tasks will be spawned unsupervised.

  - `timezone: Calendar.time_zone()` - Optional. The timezone to use for timestamps. Defaults to `Etc/UTC` (resp. default timezone).
  """
  @spec start_link(start_options()) :: GenServer.on_start()
  def start_link(opts) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError, "start_link/1 expected a keyword list, got: #{inspect(opts)}"
    end

    {opts2, genserver_opts} =
      Keyword.split(opts, [:cov_cb, :log_buffer_module, :lookup_cb, :state])

    validate_start_link_opts(opts2)

    GenServer.start_link(__MODULE__, Map.new(opts2), genserver_opts)
  end

  @doc """
  Adds an EventLog, TrendLog or TrendLogMultiple object to the trend logger.

  For EventLog objects, the logging must be triggered manually (as the logging is a local matter).
  """
  @spec add_object(server(), object()) :: :ok | {:error, term()}
  def add_object(server, object) when is_object(object) do
    GenServer.call(server, {:add_object, object})
  end

  @doc """
  Change the log state for a single object or globally (all) to `state`.

  A log status change record will be logged.
  """
  @spec change_log_state(server(), object() | :global, :enable | :disable) ::
          :ok | {:error, term()}
  def change_log_state(server, object, state)
      when (object == :global or is_object(object)) and state in [:enable, :disable] do
    GenServer.call(server, {:change_log_state, object, state})
  end

  @doc """
  Get the log buffer contents for the given object.
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
  Prunes the buffer for the specified object, or all buffers.

  A buffer purged record will be logged after pruning.
  """
  @spec prune_buffer(server(), object() | :global) :: :ok | {:error, term()}
  def prune_buffer(server, object) when object == :global or is_object(object) do
    GenServer.call(server, {:prune_buffer, object})
  end

  @doc """
  Submits a COV notification to the trend logger.
  Any notification for unknown object(s) will be ignored.

  The logger will handle the notification and trigger a log for
  any trendlogs, where necessary.

  For event logs, only `trigger_log/3` can be used, as there's
  no defined mechanism to decide which events go to which event log.
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
  Removes an EventLog, TrendLog or TrendLogMultiple object from the trend logger.

  This function is idempotent, meaning multiple calls for the same object will be ignored.
  """
  @spec remove_object(server(), object()) :: :ok
  def remove_object(server, object) when is_object(object) do
    GenServer.call(server, {:remove_object, object})
  end

  @doc """
  Triggers a COV re-subscription for the given object or all objects.

  This function call will invoke async trend logger processing,
  the return value does not indicate completion of operation.
  """
  @spec resubscribe_cov(server(), object() | :global) :: :ok
  def resubscribe_cov(server, object) when object == :global or is_object(object) do
    GenServer.call(server, {:resubscribe_cov, object})
  end

  @doc """
  Triggers a log for the given object. The given log will be used for the log buffer record.

  When the log is disabled, this call is ignored (returns `:ok`).

  When the function returns, it does not necessarily mean the operation was fully completed -
  for remote objects which need to be polled, the function returns before completion.
  For local objects, the function returns after completion.

  See the table below for valid argument combinations:

  | Object             | COV Notification | Event Notification | BACnet Object | List of BACnet Objects | `:interrupted` | Time Change |
  |:-------------------|:----------------:|:------------------:|:-------------:|:----------------------:|:--------------:|:-----------:|
  | Event Log          |                  |          X         |       X       |                        |        X       |      X      |
  | Trend Log          |         X        |                    |       X       |                        |        X       |      X      |
  | Trend Log Multiple |                  |                    |               |            X           |        X       |      X      |
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
  Updates the following properties of the object in the trend logger:
  - buffer_size
  - cov_resubscription_interval (trend logs only)
  - enable
  - Intrinsic Reporting (notification threshold)
  - log_interval (trend logs only)
  - logging_type (trend logs only)
  - start_time and stop_time
  - stop_when_full

  When updating `buffer_size`, the records in the buffer will transfer
  over to the new buffer, discarding any oldest records that would
  overfill the new buffer.
  """
  @spec update_object(server(), object()) :: :ok | {:error, term()}
  def update_object(server, object) when is_object(object) do
    GenServer.call(server, {:update_object, object})
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

    state =
      case opts do
        %{state: %State{} = state} ->
          # Setup timers to poll all trend logs with logging_type == :polled
          for {id, %Log{object: object, mode: mode} = log} <- state.logs do
            Telemetry.execute_trend_logger_log_start(self(), log, state)

            if mode == @const_log_type_polled do
              Process.send_after(
                self(),
                {:poll_log, id},
                make_interval(object.log_interval)
              )
            end
          end

          %{state | log_buff_mod: Map.get(opts, :log_buffer_module, LogBuffer), opts: new_opts}

        %{} ->
          %State{
            log_buff_mod: Map.get(opts, :log_buffer_module, LogBuffer),
            logs: %{},
            opts: new_opts
          }
      end

    # Check after 1s for start_time and stop_time
    # in every object
    Process.send_after(self(), :check_time, 1000)

    log_debug(fn -> "TrendLogger: Started on #{inspect(self())}" end)

    {:ok, state, :hibernate}
  end

  @doc false
  def handle_call({:add_object, object}, _dest, %State{log_buff_mod: log_buff_mod} = state)
      when is_object(object) do
    log_debug(fn -> "TrendLogger: Received add_object request for #{make_log_id(object)}" end)
    id = make_id(object)

    {reply, new_state} =
      cond do
        Map.has_key?(state.logs, id) ->
          {{:error, :already_known_object}, state}

        ObjectsUtility.get_remote_device_id(object) == :error ->
          {{:error, :remote_object_with_no_id}, state}

        true ->
          new_log = %Log{
            enabled: is_log_enabled(object, state),
            object: object,
            mode: if(is_struct(object, EventLog), do: :triggered, else: object.logging_type),
            buffer: log_buff_mod.new(if(object.buffer_size > 0, do: object.buffer_size)),
            intrinsic_reporting:
              case object do
                %{notification_threshold: val} when val != nil -> create_intrinsic(object)
                _else -> nil
              end,
            seq_number: 0
          }

          new_logs = Map.put(state.logs, id, new_log)
          apply_log_mechanism(new_log, object, id, state)

          Telemetry.execute_trend_logger_log_start(self(), new_log, state)

          {:ok, %State{state | logs: new_logs}}
      end

    {:reply, reply, new_state}
  end

  def handle_call(
        {:change_log_state, object, new_enable},
        _dest,
        %State{log_buff_mod: log_buff_mod} = state
      )
      when object == :global or is_object(object) do
    log_debug(fn ->
      "TrendLogger: Received change_log_state request for #{make_log_id(object)}"
    end)

    {reply, new_state} =
      cond do
        object == :global ->
          new_state =
            Enum.reduce(state.logs, state, fn {id, %Log{} = log}, %State{} = acc ->
              new_object = %{log.object | enable: new_enable == :enable}

              new_log = %Log{
                log
                | enabled: is_log_enabled(new_object, acc),
                  buffer:
                    log_buff_mod.checkin(log.buffer, create_record(log, new_enable, id, acc)),
                  object: new_object
              }

              new_state = %State{acc | logs: Map.put(acc.logs, id, new_log)}
              handle_change_enabled_state(new_log, id, log, new_state)

              Telemetry.execute_trend_logger_log_update(self(), new_log, :state, state)

              send(self(), {:maybe_notify_receiver, id})
              new_state
            end)

          {:ok, new_state}

        Map.has_key?(state.logs, id = make_id(object)) ->
          log = Map.fetch!(state.logs, id)
          new_object = %{log.object | enable: new_enable == :enable}

          new_log = %{
            log
            | enabled: is_log_enabled(new_object, state),
              buffer: log_buff_mod.checkin(log.buffer, create_record(log, new_enable, id, state)),
              object: new_object
          }

          new_state = %State{state | logs: Map.put(state.logs, id, new_log)}
          handle_change_enabled_state(new_log, id, log, new_state)

          Telemetry.execute_trend_logger_log_update(self(), new_log, :state, state)

          send(self(), {:maybe_notify_receiver, id})
          {:ok, new_state}

        true ->
          {{:error, :unknown_object}, state}
      end

    {:reply, reply, new_state}
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

  def handle_call({:notify, notif}, _dest, %State{log_buff_mod: log_buff_mod} = state)
      when is_struct(notif, ConfirmedCovNotification) or
             is_struct(notif, UnconfirmedCovNotification) do
    log_debug(fn -> "TrendLogger: Received notify request with #{notif.__struct__}" end)

    new_state =
      Enum.reduce(state.logs, state, fn
        {id, %Log{} = log}, %State{} = acc ->
          with {:cont, log_datum} <- find_log_datum_from_notify(log, log.object, notif, 0, acc),
               {:ok, log_encoding} <- create_encoding_for_notify(log_datum, acc) do
            new_log =
              log_encoding
              |> then(&create_record(log, &1, id, state))
              |> then(&log_buff_mod.checkin(log.buffer, &1))
              |> then(&%Log{log | buffer: &1})

            Telemetry.execute_trend_logger_log_update(self(), new_log, :buffer, state)

            send(self(), {:maybe_notify_receiver, id})
            %State{state | logs: Map.put(state.logs, id, new_log)}
          end
      end)

    {:reply, :ok, new_state}
  end

  def handle_call({:prune_buffer, object}, _dest, %State{log_buff_mod: log_buff_mod} = state)
      when object == :global or is_object(object) do
    log_debug(fn -> "TrendLogger: Received prune_buffer request for #{make_log_id(object)}" end)

    {reply, new_state} =
      cond do
        object == :global ->
          new_state =
            Enum.reduce(state.logs, state, fn {id, %Log{} = log}, %State{} = acc ->
              buffer =
                log.buffer
                |> log_buff_mod.truncate()
                |> log_buff_mod.checkin(create_record(log, :purged, id, acc))

              new_log = %Log{
                log
                | buffer: buffer,
                  seq_number: increment_seq_number(log.seq_number)
              }

              Telemetry.execute_trend_logger_log_update(self(), new_log, :buffer, state)

              send(self(), {:maybe_notify_receiver, id})

              %State{
                acc
                | logs: Map.put(acc.logs, id, new_log)
              }
            end)

          {:ok, new_state}

        Map.has_key?(state.logs, id = make_id(object)) ->
          log = Map.fetch!(state.logs, id)

          buffer =
            log.buffer
            |> log_buff_mod.truncate()
            |> log_buff_mod.checkin(create_record(log, :purged, id, state))

          new_log = %{
            log
            | buffer: buffer,
              seq_number: increment_seq_number(log.seq_number)
          }

          Telemetry.execute_trend_logger_log_update(self(), new_log, :buffer, state)

          new_state = %State{
            state
            | logs: Map.put(state.logs, id, new_log)
          }

          {:ok, new_state}

        true ->
          {{:error, :unknown_object}, state}
      end

    {:reply, reply, new_state}
  end

  def handle_call({:resubscribe_cov, :global}, _dest, %State{} = state) do
    log_debug(fn -> "TrendLogger: Received resubscribe_cov request for global" end)

    Enum.each(state.logs, fn {id, _log} ->
      send(self(), {:cov_resub, id})
    end)

    {:reply, :ok, state}
  end

  def handle_call({:resubscribe_cov, object}, _dest, %State{} = state) when is_object(object) do
    log_debug(fn ->
      "TrendLogger: Received resubscribe_cov request for #{make_log_id(object)}"
    end)

    # Whether the log exists or not is handled by :cov_resub handler
    send(self(), {:cov_resub, make_id(object)})

    {:reply, :ok, state}
  end

  def handle_call({:remove_object, object}, _dest, %State{} = state) when is_object(object) do
    log_debug(fn -> "TrendLogger: Received remove_object request for #{make_log_id(object)}" end)
    id = make_id(object)

    {reply, new_state} =
      case Map.pop(state.logs, id) do
        {%Log{} = log, new_logs} ->
          # Remove COV subscription if remote object and COV logging
          if log.mode == @const_log_type_cov and
               Map.get(log.object, :cov_resubscription_interval, 0) > 0 do
            apply_cov_unsub(state.opts.cov_cb, log.object.log_device_object_property, id, state)
          end

          Telemetry.execute_trend_logger_log_stop(self(), log, state)

          {:ok, %State{state | logs: new_logs}}

        _else ->
          {:ok, state}
      end

    {:reply, reply, new_state}
  end

  def handle_call(
        {:trigger_log, object, log_entry},
        _dest,
        %State{log_buff_mod: log_buff_mod} = state
      )
      when is_object(object) do
    log_debug(fn -> "TrendLogger: Received trigger_log request for #{make_log_id(object)}" end)
    id = make_id(object)

    {reply, new_state} =
      case Map.fetch(state.logs, id) do
        {:ok, %Log{enabled: true, object: object} = log} ->
          size =
            if is_struct(object, TrendLogMultiple) do
              BACnetArray.size(log.object.log_device_object_property)
            end

          with {:cont, log_datum} <-
                 find_log_datum_from_trigger(log, object, log_entry, size, state) do
            send(self(), {:maybe_notify_receiver, id})

            new_log =
              log_datum
              |> then(&create_record(log, &1, id, state))
              |> then(&log_buff_mod.checkin(log.buffer, &1))
              |> then(&%Log{log | buffer: &1, seq_number: increment_seq_number(log.seq_number)})

            Telemetry.execute_trend_logger_log_trigger(self(), new_log, log_entry, state)

            %State{state | logs: Map.put(state.logs, id, new_log)}
          end

        _else ->
          {:ok, state}
      end

    {:reply, reply, new_state}
  end

  def handle_call({:update_object, object}, _dest, %State{log_buff_mod: log_buff_mod} = state)
      when is_object(object) do
    log_debug(fn -> "TrendLogger: Received update_object request for #{make_log_id(object)}" end)
    id = make_id(object)

    {reply, new_state} =
      case Map.fetch(state.logs, id) do
        {:ok, %Log{} = old_log} ->
          {is_new_size, log} =
            case {old_log.object, object} do
              {%{buffer_size: size}, %{buffer_size: size}} ->
                {false, old_log}

              {_old, %{buffer_size: max_size}} ->
                new_buffer =
                  log_buff_mod.from_list(log_buff_mod.to_list(old_log.buffer), max_size)

                {true, %Log{old_log | buffer: new_buffer}}
            end

          new_log = %Log{
            log
            | enabled: is_log_enabled(object, state),
              mode: if(is_struct(object, EventLog), do: :triggered, else: object.logging_type),
              object: object
          }

          handle_change_enabled_state(new_log, id, old_log, state)

          {new_buffer, seq_number} =
            if new_log.enabled != old_log.enabled do
              new_buffer =
                log
                |> create_record(if(new_log.enabled, do: :enable, else: :disable), id, state)
                |> then(&log_buff_mod.checkin(log.buffer, &1))

              {new_buffer, increment_seq_number(log.seq_number)}
            else
              {log.buffer, log.seq_number}
            end

          if is_new_size or new_log.enabled != old_log.enabled do
            send(self(), {:maybe_notify_receiver, id})
          end

          new_log = %Log{new_log | buffer: new_buffer, seq_number: seq_number}

          Telemetry.execute_trend_logger_log_update(self(), new_log, :state, state)

          new_state = %State{state | logs: Map.put(state.logs, id, new_log)}
          {:ok, new_state}

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
  def handle_info(
        {:maybe_notify_receiver, id},
        %State{opts: %{notification_receiver: nil}} = state
      ) do
    new_state =
      case Map.fetch(state.logs, id) do
        {:ok, %Log{} = log} ->
          {overflow_action, %State{} = new_state} = handle_buffer_overflow(log, id, state)

          if overflow_action do
            Telemetry.execute_trend_logger_log_notify(self(), log, :buffer_full, state)
          end

          if log.intrinsic_reporting != nil do
            {_event, new_log, _notify} = update_intrinsic_reporting(log, state)
            %State{new_state | logs: Map.put(new_state.logs, id, new_log)}
          else
            new_state
          end

        _else ->
          state
      end

    {:noreply, new_state}
  end

  def handle_info(
        {:maybe_notify_receiver, id},
        %State{opts: %{notification_receiver: target_pid}} = state
      ) do
    new_state =
      case Map.fetch(state.logs, id) do
        {:ok, %Log{} = old_log} ->
          {overflow_action, %State{} = new_state} = handle_buffer_overflow(old_log, id, state)
          log = Map.fetch!(new_state.logs, id)

          {intrinsic_event, new_state, notify} =
            if log.intrinsic_reporting != nil do
              {event, new_log, notify} = update_intrinsic_reporting(log, state)

              new_state = %State{new_state | logs: Map.put(new_state.logs, id, new_log)}
              {event, new_state, notify}
            else
              {:no_event, new_state, nil}
            end

          metadata = %{
            buffer: {state.log_buff_mod, log.buffer},
            event: nil,
            intrinsic_reporting: nil
          }

          # We separate each event, because they can occur concurrently

          # Send :buffer_full event
          if overflow_action or match?(%Log{buffer: %LogBuffer{size: size, max_size: size}}, log) do
            Telemetry.execute_trend_logger_log_notify(self(), old_log, :buffer_full, state)

            send(
              target_pid,
              {:bacnet_trend_logger, nil, log.object, %{metadata | event: :buffer_full}}
            )
          end

          # Send :intrinsic_reporting event
          if intrinsic_event == :event do
            send(
              target_pid,
              {:bacnet_trend_logger, nil, log.object,
               %{metadata | event: :intrinsic_reporting, intrinsic_reporting: notify}}
            )
          end

          new_state

        _else ->
          state
      end

    {:noreply, new_state}
  end

  def handle_info({:poll_log, id}, %State{opts: %{lookup_cb: lookup_cb}} = state) do
    log_debug(fn -> "TrendLogger: Received poll_log message for #{inspect(id)}" end)

    # This is for :polled trendlogs, starts a task to gather the properties
    # for trendlog multiple we need some special handling ("collect" as list)

    case Map.get(state.logs, id) do
      # Ignore TrendLog reference with uninitialized IDs
      %Log{object: %{log_device_object_property: %{object_identifier: @asn1_uninitialized_id}}} ->
        :ok

      %Log{enabled: true, object: %TrendLog{} = object} ->
        server = self()

        spawn_task(
          fn ->
            result = run_lookup_cb(server, lookup_cb, object.log_device_object_property)
            send(server, {:submit_poll, id, result})

            Process.send_after(
              server,
              {:poll_log, id},
              make_interval(object.log_interval)
            )
          end,
          state
        )

      %Log{enabled: true, object: %TrendLogMultiple{} = object} ->
        server = self()

        spawn_task(
          fn ->
            object.log_device_object_property
            |> BACnetArray.to_list()
            |> Enum.reject(fn
              # Ignore references with uninitialized IDs
              %{object_identifier: @asn1_uninitialized_id} -> true
              _else -> false
            end)
            |> spawn_task_stream(
              state,
              &run_lookup_cb(server, lookup_cb, &1),
              on_timeout: :kill_task,
              ordered: true,
              timeout: :infinity
            )
            |> Enum.map(fn
              {:ok, value} -> value
              {:exit, :timeout} -> create_timeout_error()
              {:exit, _reason} -> create_internal_error_error()
            end)
            |> then(&send(server, {:submit_poll, id, &1}))

            Process.send_after(
              server,
              {:poll_log, id},
              make_interval(object.log_interval)
            )
          end,
          state
        )

      _else ->
        :ok
    end

    {:noreply, state}
  end

  def handle_info({:submit_poll, id, result}, %State{log_buff_mod: log_buff_mod} = state) do
    log_debug(fn -> "TrendLogger: Received submit_poll message for #{inspect(id)}" end)

    # This is for :polled trendlogs and submits the result of the task
    # into the trendlog itself

    new_state =
      case Map.fetch(state.logs, id) do
        {:ok, %Log{enabled: true, object: object} = log} ->
          size =
            if is_struct(object.log_device_object_property, BACnetArray) do
              BACnetArray.size(object.log_device_object_property)
            end

          with {:cont, log_datum} <- find_log_datum_from_trigger(log, object, result, size, state) do
            new_log =
              log_datum
              |> then(&create_record(log, &1, id, state))
              |> then(&log_buff_mod.checkin(log.buffer, &1))
              |> then(&%Log{log | buffer: &1, seq_number: increment_seq_number(log.seq_number)})

            Telemetry.execute_trend_logger_log_update(self(), new_log, :buffer, state)

            send(self(), {:maybe_notify_receiver, id})
            %State{state | logs: Map.put(state.logs, id, new_log)}
          else
            _term -> state
          end

        _else ->
          state
      end

    {:noreply, new_state}
  end

  def handle_info({:cov_resub, id}, %State{opts: %{cov_cb: cov_cb}} = state) do
    log_debug(fn -> "TrendLogger: Received cov_resub message for #{inspect(id)}" end)

    # This is for :cov trendlogs (remote objects), to resubscribe COV
    case Map.fetch(state.logs, id) do
      {:ok,
       %{
         enabled: true,
         object: %{logging_type: @const_log_type_cov, cov_resubscription_interval: cov} = object
       }}
      when not is_nil(cov) and cov > 0 ->
        apply_cov_sub(
          cov_cb,
          object.log_device_object_property,
          id,
          cov,
          Map.get(object, :client_cov_increment),
          state
        )

      _else ->
        :ok
    end

    {:noreply, state}
  end

  def handle_info(:check_time, %State{log_buff_mod: log_buff_mod} = state) do
    new_state =
      Enum.reduce(state.logs, state, fn
        {id,
         %Log{object: %{start_time: %BACnetDateTime{}, stop_time: %BACnetDateTime{}} = object} =
             log},
        %State{} = acc ->
          new_enabled = is_log_enabled(object, acc)

          if new_enabled != log.enabled do
            new_log = %Log{
              log
              | enabled: new_enabled,
                buffer:
                  log_buff_mod.checkin(
                    log.buffer,
                    create_record(log, if(new_enabled, do: :enable, else: :disable), id, acc)
                  ),
                seq_number: increment_seq_number(log.seq_number)
            }

            send(self(), {:maybe_notify_receiver, id})

            new_state = %State{acc | logs: Map.put(acc.logs, id, new_log)}
            handle_change_enabled_state(new_log, id, log, new_state)

            new_state
          else
            acc
          end

        _term, acc ->
          acc
      end)

    # Check after 1s for start_time and stop_time
    # in every object, again!
    Process.send_after(self(), :check_time, 1000)

    {:noreply, new_state}
  end

  def handle_info(_message, state) do
    # Catch-all - discard the message
    {:noreply, state}
  end

  defp make_id(%{object_instance: num} = object) do
    {ObjectsUtility.get_object_type(object), num}
  end

  # log_interval is in hundreds of seconds, default to 1 second on 0
  defp make_interval(log_interval)
  defp make_interval(0), do: 1000
  defp make_interval(log_interval), do: log_interval * 100

  @spec is_log_enabled(object(), State.t()) :: boolean()
  defp is_log_enabled(object, state)

  defp is_log_enabled(
         %{
           enable: true,
           start_time: %BACnetDateTime{} = start,
           stop_time: %BACnetDateTime{} = stop
         },
         %State{opts: %{timezone: tz}}
       ) do
    now = BACnetDateTime.from_datetime(DateTime.now!(tz))

    not match?(:gt, BACnetDateTime.compare(start, now)) and
      match?(:gt, BACnetDateTime.compare(now, stop))
  end

  defp is_log_enabled(%{enable: true, start_time: nil, stop_time: nil}, _state), do: true
  defp is_log_enabled(_object, _state), do: false

  defp increment_seq_number(seq_number) when seq_number >= 4_294_967_295, do: 1
  defp increment_seq_number(seq_number), do: seq_number + 1

  # Catch empty device/object/property identifiers and do nothing (they count as 'unintialized')
  # This is done in apply_cov_sub/5
  defp apply_log_mechanism(
         %{enabled: true, mode: @const_log_type_cov} = _log,
         %{cov_resubscription_interval: lifetime} = object,
         id,
         %State{opts: %{cov_cb: cov_cb}} = state
       )
       when (is_object_trend(object) or is_object_trend_multi(object)) and not is_nil(lifetime) and
              lifetime > 0 do
    apply_cov_sub(
      cov_cb,
      object.log_device_object_property,
      id,
      lifetime,
      Map.get(object, :client_cov_increment),
      state
    )

    :ok
  end

  defp apply_log_mechanism(
         %{enabled: true, mode: @const_log_type_polled} = _log,
         object,
         id,
         _state
       ) do
    Process.send_after(
      self(),
      {:poll_log, id},
      make_interval(object.log_interval)
    )

    :ok
  end

  defp apply_log_mechanism(_log, _term, _id, _state) do
    # Catch-all for EventLog, TrendLog/TrendLogMultiple (with logging_type = triggered or cov)
    :ok
  end

  @spec handle_change_enabled_state(Log.t(), term(), Log.t(), State.t()) :: :ok
  defp handle_change_enabled_state(%Log{} = log, id, %Log{} = previous_log, %State{} = state) do
    cond do
      log.enabled ->
        apply_log_mechanism(log, log.object, id, state)

      not log.enabled and previous_log.enabled ->
        # Remove COV subscription if remote object and COV logging
        if log.mode == @const_log_type_cov do
          apply_cov_unsub(state.opts.cov_cb, log.object.log_device_object_property, id, state)
        end

      true ->
        :ok
    end

    :ok
  end

  @spec handle_buffer_overflow(Log.t(), term(), State.t()) :: {action :: boolean(), State.t()}
  defp handle_buffer_overflow(_log, id, state)

  defp handle_buffer_overflow(
         %Log{
           buffer: %{max_size: max_size, size: size},
           object: %{enable: true, stop_when_full: true}
         } = log,
         id,
         %State{log_buff_mod: log_buff_mod} = state
       )
       when max_size - 1 <= size do
    new_log =
      log.object
      # BACnet Object
      |> then(&%{&1 | enable: false})
      # Log
      |> then(&%{log | enabled: false, object: &1})
      |> then(&{&1, create_record(&1, :disable, id, state)})
      |> then(&{elem(&1, 0), log_buff_mod.checkin(log.buffer, elem(&1, 1))})
      # Log
      |> then(&%{elem(&1, 0) | buffer: elem(&1, 1)})

    new_state = %State{state | logs: Map.put(state.logs, id, new_log)}
    {true, new_state}
  end

  defp handle_buffer_overflow(_log, _id, state), do: {false, state}

  @spec update_intrinsic_reporting(Log.t(), State.t()) ::
          {:event | :no_event, Log.t(), struct() | nil}
  defp update_intrinsic_reporting(%Log{intrinsic_reporting: nil} = log, _state) do
    {:no_event, log, nil}
  end

  defp update_intrinsic_reporting(%Log{intrinsic_reporting: algo} = log, %State{} = state) do
    event =
      algo
      |> BufferReady.update(monitored_value: log.seq_number)
      |> BufferReady.execute()

    {type, new_algo, notify} =
      case event do
        {:event, new_state, notify} -> {:event, new_state, notify}
        {:no_event, new_state} -> {:no_event, new_state, nil}
      end

    new_log = %Log{log | intrinsic_reporting: new_algo}
    Telemetry.execute_trend_logger_log_notify(self(), new_log, :intrinsic_reporting, state)

    {type, new_log, notify}
  end

  @spec create_record(
          Log.t(),
          :enable
          | :disable
          | :interrupted
          | :purged
          | {:time_change, float()}
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
            ],
          term(),
          State.t()
        ) :: EventLogRecord.t() | LogRecord.t() | LogMultipleRecord.t()
  defp create_record(%Log{object: %EventLog{}} = log, event, _id, state) do
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
          struct(ConfirmedEventNotification, event)

        {:time_change, _time} = _term ->
          event
      end

    %EventLogRecord{
      timestamp: BACnetDateTime.from_datetime(DateTime.now!(state.opts.timezone)),
      log_datum: log_datum
    }
  end

  defp create_record(%Log{object: %TrendLog{} = object} = log, event, _id, state) do
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
      timestamp: BACnetDateTime.from_datetime(DateTime.now!(state.opts.timezone)),
      log_datum: log_datum,
      status_flags: status_flags
    }
  end

  defp create_record(%Log{object: %TrendLogMultiple{}} = log, event, _id, state) do
    time_now = DateTime.now!(state.opts.timezone)

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

  defp create_internal_error_error() do
    %BACnetError{
      class: Constants.macro_assert_name(:error_class, :device),
      code: Constants.macro_assert_name(:error_code, :internal_error)
    }
  end

  defp create_invalid_datatype_error() do
    %BACnetError{
      class: Constants.macro_assert_name(:error_class, :property),
      code: Constants.macro_assert_name(:error_code, :invalid_datatype)
    }
  end

  defp create_timeout_error() do
    %BACnetError{
      class: Constants.macro_assert_name(:error_class, :communication),
      code: Constants.macro_assert_name(:error_code, :timeout)
    }
  end

  defp create_uninitialized_error() do
    %BACnetError{
      class: Constants.macro_assert_name(:error_class, :property),
      code: Constants.macro_assert_name(:error_code, :no_property_specified)
    }
  end

  defp find_log_datum_from_notify(log, object, notification, size, state)

  defp find_log_datum_from_notify(
         _log,
         %TrendLog{log_device_object_property: objref} = _object,
         %ConfirmedCovNotification{initiating_device: device, monitored_object: mon_object} =
           notification,
         _size,
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
         log,
         %TrendLog{} = object,
         %UnconfirmedCovNotification{} = notification,
         size,
         state
       ) do
    find_log_datum_from_notify(
      log,
      object,
      struct(ConfirmedCovNotification, notification),
      size,
      state
    )
  end

  defp find_log_datum_from_notify(
         _log,
         %TrendLogMultiple{log_device_object_property: objrefs} = object,
         %ConfirmedCovNotification{initiating_device: device, monitored_object: object} =
           notification,
         _size,
         state
       ) do
    log_data =
      objrefs
      |> BACnetArray.to_list()
      |> Enum.map(fn %DeviceObjectPropertyRef{} = objref ->
        if (objref.device_identifier == nil and match?(%{object_identifier: ^object}, objref)) or
             match?(%{device_identifier: ^device, object_identifier: ^object}, objref) do
          property = objref.property_identifier
          array_index = objref.property_array_index

          Enum.find_value(notification.property_values, fn
            %PropertyValue{
              property_identifier: ^property,
              property_array_index: ^array_index,
              property_value: value
            } ->
              value

            %{} ->
              false
          end)
        end
      end)

    if Enum.all?(log_data, &is_nil/1) do
      state
    else
      {:cont, log_data}
    end
  end

  defp find_log_datum_from_notify(
         log,
         %TrendLogMultiple{} = object,
         %UnconfirmedCovNotification{} = notification,
         size,
         state
       ) do
    find_log_datum_from_notify(
      log,
      object,
      struct(ConfirmedCovNotification, notification),
      size,
      state
    )
  end

  defp find_log_datum_from_notify(_log, _object, _notification, _size, state), do: state

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

  defp find_log_datum_from_trigger(log, object, log_entry, size, state)

  defp find_log_datum_from_trigger(_log, %EventLog{}, :interrupted = term, _size, _state),
    do: {:cont, term}

  defp find_log_datum_from_trigger(
         _log,
         %EventLog{},
         {:time_change, _term} = term,
         _size,
         _state
       ),
       do: {:cont, term}

  defp find_log_datum_from_trigger(
         _log,
         %EventLog{},
         %ConfirmedEventNotification{} = term,
         _size,
         _state
       ),
       do: {:cont, term}

  defp find_log_datum_from_trigger(
         _log,
         %EventLog{},
         %UnconfirmedEventNotification{} = term,
         _size,
         _state
       ),
       do: {:cont, struct(ConfirmedEventNotification, term)}

  defp find_log_datum_from_trigger(_log, %TrendLog{}, :interrupted = term, _size, _state),
    do: {:cont, term}

  defp find_log_datum_from_trigger(
         _log,
         %TrendLog{},
         {:time_change, _term} = term,
         _size,
         _state
       ),
       do: {:cont, term}

  defp find_log_datum_from_trigger(
         _log,
         %TrendLog{},
         %ConfirmedCovNotification{} = term,
         _size,
         _state
       ),
       do: {:cont, term}

  defp find_log_datum_from_trigger(
         _log,
         %TrendLog{},
         %UnconfirmedCovNotification{} = term,
         _size,
         _state
       ),
       do: {:cont, struct(ConfirmedCovNotification, term)}

  defp find_log_datum_from_trigger(_log, %TrendLog{}, %Encoding{} = term, _size, _state),
    do: {:cont, term}

  defp find_log_datum_from_trigger(_log, %TrendLog{} = tl, term, _size, _state)
       when ObjectsUtility.is_object(term) do
    with {:ok, log_datum} <-
           find_log_datum_from_bacnet_object(tl.log_device_object_property, term) do
      {:cont, log_datum}
    end
  end

  defp find_log_datum_from_trigger(
         _log,
         %TrendLogMultiple{},
         :interrupted = term,
         _size,
         _state
       ),
       do: {:cont, term}

  defp find_log_datum_from_trigger(
         _log,
         %TrendLogMultiple{},
         {:time_change, _term} = term,
         _size,
         _state
       ),
       do: {:cont, term}

  defp find_log_datum_from_trigger(log, %TrendLogMultiple{}, list, size, state)
       when is_list(list) do
    if size > 0 do
      result =
        BACnetArray.reduce_while(
          log.object.log_device_object_property,
          [],
          &trendlog_multi_find_bacnet_object(list, &1, &2)
        )

      case result do
        list when is_list(result) -> {:cont, Enum.reverse(list)}
        {:error, _err} = err -> {err, state}
      end
    else
      {:ok, state}
    end
  end

  defp find_log_datum_from_trigger(_log, _object, _else, _size, state),
    do: {{:error, :invalid_log}, state}

  defp find_log_datum_from_bacnet_object(objref, object)

  defp find_log_datum_from_bacnet_object(
         %DeviceObjectPropertyRef{object_identifier: @asn1_uninitialized_id},
         _object
       ) do
    create_uninitialized_error()
  end

  defp find_log_datum_from_bacnet_object(%DeviceObjectPropertyRef{} = objref, object)
       when ObjectsUtility.is_object(object) do
    case ObjectsUtility.get_property(object, objref.property_identifier) do
      {:ok, value} ->
        case objref.property_array_index do
          nil ->
            create_encoding(object, objref.property_identifier, value)

          index ->
            # credo:disable-for-lines:3 Credo.Check.Refactor.CondStatements
            result =
              cond do
                is_struct(value, BACnetArray) -> BACnetArray.get_item(value, index)
                # Don't supported lists directly right now (shut up credo cond with two branches)
                # false and is_list(value) -> Enum.at(value, index, :error)
                true -> :not_an_array
              end

            case result do
              {:ok, value} ->
                create_encoding(object, objref.property_identifier, value)

              :error ->
                %BACnetError{
                  class: Constants.macro_assert_name(:error_class, :property),
                  code: Constants.macro_assert_name(:error_code, :invalid_array_index)
                }

              :not_an_array ->
                %BACnetError{
                  class: Constants.macro_assert_name(:error_class, :property),
                  code: Constants.macro_assert_name(:error_code, :property_is_not_an_array)
                }
            end
        end

      _else ->
        %BACnetError{
          class: Constants.macro_assert_name(:error_class, :property),
          code: Constants.macro_assert_name(:error_code, :unknown_property)
        }
    end
  end

  defp create_encoding(_object, _property, nil), do: nil
  defp create_encoding(_object, _property, %Encoding{} = value), do: value

  defp create_encoding(%mod{} = object, property, value)
       when is_atom(property) and ObjectsUtility.is_object(object) do
    with :cont <-
           (case Keyword.fetch(mod.get_annotation(property), :encoder) do
              {:ok, term} -> {:ok, {:fun, term}}
              :error -> :cont
            end),
         :cont <-
           (case mod.get_properties_type_map() do
              %{^property => type} ->
                # TODO: Support for more types (i.e. literal - how?)
                case type do
                  {:constant, term} ->
                    {:ok, {:const, Constants.by_name_atom(term, value)}}

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

  defp trendlog_multi_find_bacnet_object(objects, %DeviceObjectPropertyRef{} = objref, acc) do
    ref_device =
      if objref.device_identifier == nil or
           objref.device_identifier.instance == @asn1_uninitialized_id,
         do: nil,
         else: objref.device_identifier.instance

    ref_obj = objref.object_identifier

    log_datum_item =
      case objref do
        %{object_identifier: @asn1_uninitialized_id} ->
          create_uninitialized_error()

        _else ->
          case Enum.find(objects, fn
                 %{
                   _metadata: %{remote_object: ^ref_device},
                   object_identifier: ^ref_obj
                 } ->
                   true

                 _else ->
                   false
               end) do
            nil -> nil
            %{} = scan_obj -> find_log_datum_from_bacnet_object(objref, scan_obj)
          end
      end

    {:cont, [log_datum_item | acc]}
  end

  @spec create_intrinsic(object()) :: BufferReady.t()
  defp create_intrinsic(%{} = object) when is_object(object) do
    dev_ref = %DeviceObjectPropertyRef{
      object_identifier: ObjectsUtility.get_object_identifier(object),
      property_identifier:
        Constants.macro_assert_name(:property_identifier, :log_device_object_property),
      property_array_index: nil,
      device_identifier: nil
    }

    params = %BufferReadyParams{
      threshold: object.notification_threshold,
      previous_count: object.last_notify_record
    }

    BufferReady.new(object.total_record_count, dev_ref, params)
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

  @spec apply_cov_sub(
          fun() | nil,
          BACnetArray.t() | DeviceObjectPropertyRef.t(),
          term(),
          pos_integer(),
          float() | nil,
          State.t()
        ) :: :ok
  defp apply_cov_sub(nil, _log_property, _id, _lifetime, _cov_increment, _state), do: :ok

  defp apply_cov_sub(
         cov_cb,
         %BACnetArray{} = log_device_object_property,
         id,
         lifetime,
         cov_increment,
         state
       ) do
    BACnetArray.reduce_while(log_device_object_property, nil, fn element, _acc ->
      apply_cov_sub(cov_cb, element, nil, lifetime, cov_increment, state)
    end)

    Process.send_after(self(), {:cov_resub, id}, lifetime * 1000)
    :ok
  end

  defp apply_cov_sub(
         _cov_cb,
         %{device_identifier: nil} = _log_device_object_property,
         _id,
         _lifetime,
         _cov_increment,
         _state
       ) do
    # Do not do COV subscription to local device
    :ok
  end

  defp apply_cov_sub(
         _cov_cb,
         %{device_identifier: @asn1_uninitialized_id} = _log_device_object_property,
         _id,
         _lifetime,
         _cov_increment,
         _state
       ) do
    # Do not do COV subscription to uninialized device identifier
    :ok
  end

  defp apply_cov_sub(
         _cov_cb,
         %{object_identifier: @asn1_uninitialized_id} = _log_device_object_property,
         _id,
         _lifetime,
         _cov_increment,
         _state
       ) do
    # Do not do COV subscription to uninialized object identifier
    :ok
  end

  defp apply_cov_sub(
         cov_cb,
         %DeviceObjectPropertyRef{} = log_device_object_property,
         id,
         lifetime,
         cov_increment,
         state
       ) do
    log_debug(fn ->
      "TrendLogger: Subscribing COV for #{inspect(id)} - #{make_log_id(log_device_object_property)}"
    end)

    server = self()

    spawn_task(
      fn ->
        Telemetry.execute_trend_logger_cov_sub(server, log_device_object_property)

        try do
          result =
            case cov_cb.(server, log_device_object_property, :sub, lifetime * 2, cov_increment) do
              :ok ->
                if id, do: Process.send_after(server, {:cov_resub, id}, lifetime * 1000)
                :ok

              term ->
                # Retry again
                if id, do: Process.send_after(server, {:cov_resub, id}, @cov_cb_retry_timer)

                Logger.warning(fn ->
                  "TrendLogger has detected a non-ok return from cov_cb, got: " <> inspect(term)
                end)

                term
            end

          result
        catch
          type, err ->
            Logger.warning(fn ->
              "TrendLogger has catched an error from the cov_cb, type: #{inspect(type)}, error: #{inspect(err)}"
            end)
        end
      end,
      state
    )

    :ok
  end

  @spec apply_cov_unsub(
          fun() | nil,
          BACnetArray.t() | DeviceObjectPropertyRef.t(),
          term(),
          State.t()
        ) :: :ok
  defp apply_cov_unsub(nil, _log_property, _id, _state), do: :ok

  defp apply_cov_unsub(cov_cb, %BACnetArray{} = log_device_object_property, _id, state) do
    BACnetArray.reduce_while(log_device_object_property, nil, fn element, _acc ->
      apply_cov_unsub(cov_cb, element, nil, state)
    end)

    :ok
  end

  defp apply_cov_unsub(cov_cb, %DeviceObjectPropertyRef{} = log_device_object_property, id, state) do
    log_debug(fn ->
      "TrendLogger: Unsubscribing COV for #{inspect(id)} - #{make_log_id(log_device_object_property)}"
    end)

    server = self()

    spawn_task(
      fn ->
        Telemetry.execute_trend_logger_cov_unsub(server, log_device_object_property)

        try do
          cov_cb.(server, log_device_object_property, :unsub, 0, nil)
        catch
          type, err ->
            Logger.warning(fn ->
              "TrendLogger has catched an error from the cov_cb, type: #{inspect(type)}, error: #{inspect(err)}"
            end)
        end
      end,
      state
    )

    :ok
  end

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
              "start_link/1 expected supervisor to be a supervisor identifier (process destiantion), " <>
                "got: #{inspect(term)}"
    end

    case opts[:timezone] do
      nil ->
        :ok

      term when is_binary(term) ->
        # Extreme validation by trying to use the timezone
        DateTime.now!(term)
        :ok

      term ->
        raise ArgumentError,
              "start_link/1 expected timezone to be a string, got: #{inspect(term)}"
    end
  end

  defp make_log_id(%DeviceObjectRef{device_identifier: nil} = object) do
    "(DEV)#{make_log_id(object.object_identifier)}"
  end

  defp make_log_id(%DeviceObjectRef{device_identifier: @asn1_uninitialized_id} = object) do
    make_log_id(%{object | device_identifier: nil})
  end

  defp make_log_id(%DeviceObjectRef{} = object) do
    "(DEV-#{object.device_identifier.instance})#{make_log_id(object.object_identifier)}"
  end

  defp make_log_id(%DeviceObjectPropertyRef{device_identifier: nil} = object) do
    "(DEV)#{make_log_id(object.object_identifier)}[P#{object.property_identifier}]"
  end

  defp make_log_id(%DeviceObjectPropertyRef{device_identifier: @asn1_uninitialized_id} = object) do
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

  defp spawn_task_stream(enum, %{opts: %{supervisor: nil}} = _state, fun, opts) do
    Task.async_stream(enum, fun, opts)
  end

  defp spawn_task_stream(enum, %{opts: %{supervisor: supervisor}} = _state, fun, opts) do
    Task.Supervisor.async_stream_nolink(supervisor, enum, fun, opts)
  end
end
