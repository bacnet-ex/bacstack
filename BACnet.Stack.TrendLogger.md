# `BACnet.Stack.TrendLogger`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/trend_logger.ex#L1)

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

# `object`

```elixir
@type object() ::
  BACnet.Protocol.ObjectTypes.EventLog.t()
  | BACnet.Protocol.ObjectTypes.TrendLog.t()
  | BACnet.Protocol.ObjectTypes.TrendLogMultiple.t()
```

Represents valid BACnet objects. These can be handled by the trend logger.

# `server`

```elixir
@type server() :: GenServer.server()
```

Represents a server process of the Trend Logger module.

# `start_option`

```elixir
@type start_option() ::
  {:cov_cb,
   (pid(),
    BACnet.Protocol.DeviceObjectPropertyRef.t(),
    :sub
    | :unsub,
    non_neg_integer(),
    float()
    | nil -&gt;
      :ok | {:error, term()})}
  | {:log_buffer_module, BACnet.Stack.LogBufferBehaviour.mod()}
  | {:lookup_cb,
     (BACnet.Protocol.DeviceObjectRef.t() -&gt;
        {:ok, BACnet.Protocol.ObjectsUtility.bacnet_object()}
        | {:error, BACnet.Protocol.BACnetError.t()})}
  | {:notification_receiver, Process.dest()}
  | {:state, BACnet.Stack.TrendLogger.State.t()}
  | {:supervisor, Supervisor.supervisor()}
  | {:timezone, Calendar.time_zone()}
  | GenServer.option()
```

Valid start options. For a description of each, see `start_link/1`.

# `start_options`

```elixir
@type start_options() :: [start_option()]
```

List of start options.

# `add_object`

```elixir
@spec add_object(server(), object()) :: :ok | {:error, term()}
```

Adds an EventLog, TrendLog or TrendLogMultiple object to the trend logger.

For EventLog objects, the logging must be triggered manually (as the logging is a local matter).

# `change_log_state`

```elixir
@spec change_log_state(server(), object() | :global, :enable | :disable) ::
  :ok | {:error, term()}
```

Change the log state for a single object or globally (all) to `state`.

A log status change record will be logged.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `get_buffer`

```elixir
@spec get_buffer(server(), object()) ::
  {:ok,
   {current_sequence_number :: non_neg_integer(), buffer_module :: module(),
    buffer :: BACnet.Stack.LogBufferBehaviour.t()}}
  | {:error, term()}
```

Get the log buffer contents for the given object.

# `notify`

```elixir
@spec notify(
  server(),
  BACnet.Protocol.Services.ConfirmedCovNotification.t()
  | BACnet.Protocol.Services.UnconfirmedCovNotification.t()
) :: :ok
```

Submits a COV notification to the trend logger.
Any notification for unknown object(s) will be ignored.

The logger will handle the notification and trigger a log for
any trendlogs, where necessary.

For event logs, only `trigger_log/3` can be used, as there's
no defined mechanism to decide which events go to which event log.

# `prune_buffer`

```elixir
@spec prune_buffer(server(), object() | :global) :: :ok | {:error, term()}
```

Prunes the buffer for the specified object, or all buffers.

A buffer purged record will be logged after pruning.

# `remove_object`

```elixir
@spec remove_object(server(), object()) :: :ok
```

Removes an EventLog, TrendLog or TrendLogMultiple object from the trend logger.

This function is idempotent, meaning multiple calls for the same object will be ignored.

# `resubscribe_cov`

```elixir
@spec resubscribe_cov(server(), object() | :global) :: :ok
```

Triggers a COV re-subscription for the given object or all objects.

This function call will invoke async trend logger processing,
the return value does not indicate completion of operation.

# `start_link`

```elixir
@spec start_link(start_options()) :: GenServer.on_start()
```

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

# `trigger_log`

```elixir
@spec trigger_log(
  server(),
  object(),
  BACnet.Protocol.Services.ConfirmedEventNotification.t()
  | BACnet.Protocol.Services.UnconfirmedEventNotification.t()
  | BACnet.Protocol.Services.ConfirmedCovNotification.t()
  | BACnet.Protocol.ObjectsUtility.bacnet_object()
  | [BACnet.Protocol.ObjectsUtility.bacnet_object()]
  | :interrupted
  | {:time_change, float()}
) :: :ok | {:error, term()}
```

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

# `update_object`

```elixir
@spec update_object(server(), object()) :: :ok | {:error, term()}
```

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

---

*Consult [api-reference.md](api-reference.md) for complete listing*
