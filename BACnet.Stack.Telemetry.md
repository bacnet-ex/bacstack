# `BACnet.Stack.Telemetry`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/stack/telemetry.ex#L1)

Contains functions for easier interaction with telemetry.

For full functionality, `:telemetry` dependency must be installed.
If you want to disable emitting telemetry events even if telemetry is installed,
set the environment `:bacstack` key `:no_telemetry` to true and recompile.
For recompiling when bacstack is a dependency, use `mix deps.compile --force`.

All measurements contain at least `monotonic_time` (native units) and `system_time`.
The event metadata will depend on the event, but will at least contain the following keys:
- `self: GenServer.server()`
- `transport_module: module()` (only for client messages)
- `portal: TransportBehaviour.portal()` (only for client messages)
- `client: Client.server()` (only for BBMD/foreign device messages)

# `execute_bbmd_add_fd_registration`

```elixir
@spec execute_bbmd_add_fd_registration(
  GenServer.server(),
  {:inet.ip4_address(), :inet.port_number()},
  BACnet.Stack.BBMD.Registration.t(),
  BACnet.Stack.BBMD.State.t()
) :: :ok
```

Executes telemetry for new foreign device registration
as `[:bacstack, :bbmd, :foreign_device, :add]`.

The arguments `source_adress` and `registration` are part of the event metadata.

# `execute_bbmd_del_fd_registration`

```elixir
@spec execute_bbmd_del_fd_registration(
  GenServer.server(),
  {:inet.ip4_address(), :inet.port_number()} | nil,
  BACnet.Stack.BBMD.Registration.t(),
  BACnet.Stack.BBMD.State.t()
) :: :ok
```

Executes telemetry for deleting foreign device registration
as `[:bacstack, :bbmd, :foreign_device, :delete]`.

This function is only called for BACnet interactions,
not for local interactions through the `BBMD` public API.
However this function is called for expiring registrations (source_address = nil).

The arguments `source_adress` and `registration` are part of the event metadata.

# `execute_bbmd_distribute_broadcast`

```elixir
@spec execute_bbmd_distribute_broadcast(
  GenServer.server(),
  {:inet.ip4_address(), :inet.port_number()},
  BACnet.Protocol.bvlc(),
  BACnet.Protocol.apdu(),
  BACnet.Protocol.NPCI.t(),
  BACnet.Stack.BBMD.State.t()
) :: :ok
```

Executes telemetry for distributing broadcasts
as `[:bacstack, :bbmd, :broadcast_distribution, :distribute]`.

The arguments `source_adress`, `apdu` and `npci` are part of the event metadata.

# `execute_bbmd_exception`

```elixir
@spec execute_bbmd_exception(
  GenServer.server(),
  term(),
  term(),
  list(),
  map(),
  BACnet.Stack.BBMD.State.t()
) :: :ok
```

Executes telemetry for an error or exception as `[:bacstack, :bbmd, :exception]`.

The arguments `kind`, `reason` and `stacktrace` are part of the event metadata.

# `execute_bbmd_read_bdt`

```elixir
@spec execute_bbmd_read_bdt(
  GenServer.server(),
  {:inet.ip4_address(), :inet.port_number()},
  [BACnet.Protocol.BroadcastDistributionTableEntry.t()],
  BACnet.Stack.BBMD.State.t()
) :: :ok
```

Executes telemetry for reading broadcast distribution table
as `[:bacstack, :bbmd, :broadcast_distribution, :read_table]`.

This function is only called for BACnet interactions,
not for local interactions through the `BBMD` public API.

The arguments `source_adress` and `bdt` are part of the event metadata.

# `execute_bbmd_read_fd_table`

```elixir
@spec execute_bbmd_read_fd_table(
  GenServer.server(),
  {:inet.ip4_address(), :inet.port_number()},
  %{
    optional({:inet.ip_address(), :inet.port_number()}) =&gt;
      BACnet.Stack.BBMD.Registration.t()
  },
  BACnet.Stack.BBMD.State.t()
) :: :ok
```

Executes telemetry for reading foreign device table
as `[:bacstack, :bbmd, :foreign_device, :read_table]`.

This function is only called for BACnet interactions,
not for local interactions through the `BBMD` public API.

The arguments `source_adress` and `registrations` are part of the event metadata.

# `execute_bbmd_write_bdt`

```elixir
@spec execute_bbmd_write_bdt(
  GenServer.server(),
  {:inet.ip4_address(), :inet.port_number()},
  [BACnet.Protocol.BroadcastDistributionTableEntry.t()],
  BACnet.Stack.BBMD.State.t()
) :: :ok
```

Executes telemetry for writing broadcast distribution table
as `[:bacstack, :bbmd, :broadcast_distribution, :write_table]`.

This function is only called for BACnet interactions,
not for local interactions through the `BBMD` public API.

The arguments `source_adress` and `bdt` are part of the event metadata.

# `execute_client_exception`

```elixir
@spec execute_client_exception(
  GenServer.server(),
  term(),
  term(),
  list(),
  map(),
  BACnet.Stack.Client.State.t()
) :: :ok
```

Executes telemetry for an error or exception as `[:bacstack, :client, :exception]`.

The arguments `kind`, `reason` and `stacktrace` are part of the event metadata.

# `execute_client_inc_apdu`

```elixir
@spec execute_client_inc_apdu(
  GenServer.server(),
  term(),
  BACnet.Protocol.bvlc(),
  BACnet.Protocol.NPCI.t(),
  BACnet.Protocol.apdu(),
  BACnet.Stack.Client.State.t()
) :: :ok
```

Executes telemetry for incoming APDU (decoded) as `[:bacstack, :client, :incoming_apdu]`.

The arguments `source_address`, `bvlc`, `npci` and `apdu` are part of the event metadata.

# `execute_client_inc_apdu_decode_error`

```elixir
@spec execute_client_inc_apdu_decode_error(
  GenServer.server(),
  term(),
  BACnet.Protocol.bvlc(),
  BACnet.Protocol.NPCI.t(),
  binary(),
  term(),
  BACnet.Stack.Client.State.t()
) :: :ok
```

Executes telemetry for incoming APDU decode error as `[:bacstack, :client, :incoming_apdu, :error]`.

The arguments `source_address`, `bvlc`, `npci`, `raw_apdu` and `error` are part of the event metadata.

# `execute_client_inc_apdu_duplicated`

```elixir
@spec execute_client_inc_apdu_duplicated(
  GenServer.server(),
  term(),
  BACnet.Protocol.bvlc(),
  BACnet.Protocol.NPCI.t(),
  BACnet.Protocol.apdu(),
  BACnet.Stack.Client.State.t()
) :: :ok
```

Executes telemetry for incoming APDU (duplicated)
as`[:bacstack, :client, :incoming_apdu, :duplicated]`.
The APDU has been detected as being deduplicated and is not passed on to the application.

The arguments `source_address`, `bvlc`, `npci` and `apdu` are part of the event metadata.

# `execute_client_inc_apdu_handled`

```elixir
@spec execute_client_inc_apdu_handled(
  GenServer.server(),
  term(),
  BACnet.Protocol.bvlc(),
  BACnet.Protocol.NPCI.t(),
  BACnet.Protocol.apdu(),
  BACnet.Stack.Client.State.t()
) :: :ok
```

Executes telemetry for incoming APDU (handled) as `[:bacstack, :client, :incoming_apdu, :start]`.
Handled refers to the APDU not being deduplicated and passed on to the application,
if a notification receiver is registered.

The arguments `source_address`, `bvlc`, `npci` and `apdu` are part of the event metadata.

# `execute_client_inc_apdu_rejected`

```elixir
@spec execute_client_inc_apdu_rejected(
  GenServer.server(),
  term(),
  BACnet.Protocol.bvlc(),
  BACnet.Protocol.NPCI.t(),
  BACnet.Protocol.APDU.Reject.t(),
  BACnet.Protocol.apdu(),
  BACnet.Stack.Client.State.t()
) :: :ok
```

Executes telemetry for incoming APDU rejected as `[:bacstack, :client, :incoming_apdu, :error]`.

Rejected means there is no configured notification receiver (listener) and as such can not
respond to APDU requests expecting reply.

The arguments `source_address`, `bvlc`, `npci`, `reject_apdu` and `original_apdu` are part
of the event metadata. Additionally, key `reason` will be set to `:no_listener`.

# `execute_client_inc_apdu_reply`

```elixir
@spec execute_client_inc_apdu_reply(
  GenServer.server(),
  BACnet.Protocol.apdu(),
  Keyword.t(),
  BACnet.Stack.Client.ReplyTimer.t(),
  BACnet.Stack.Client.State.t()
) :: :ok
```

Executes telemetry for APDU application response
as `[:bacstack, :client, :incoming_apdu, :stop]`.
A `duration` key will be set in measurements using monotonic time native units.

The arguments `apdu` and `send_opts` are part of the events metadata.
Additionally, the following keys are set:
- `source_address: term()`
- `ref: reference()`

# `execute_client_inc_apdu_segmentation_completed`

```elixir
@spec execute_client_inc_apdu_segmentation_completed(
  GenServer.server(),
  term(),
  BACnet.Protocol.bvlc(),
  BACnet.Protocol.NPCI.t(),
  binary(),
  binary(),
  BACnet.Protocol.IncompleteAPDU.t(),
  BACnet.Stack.Client.State.t()
) :: :ok
```

Executes telemetry for incoming APDU segmented completed
as `[:bacstack, :client, :incoming_apdu, :segmented, :completed]`.

The arguments `source_address`, `bvlc`, `npci`, `raw_apdu`, `complete_apdu`
and `incomplete`are part of the event metadata.

# `execute_client_inc_apdu_segmentation_error`

```elixir
@spec execute_client_inc_apdu_segmentation_error(
  GenServer.server(),
  term(),
  BACnet.Protocol.bvlc(),
  BACnet.Protocol.NPCI.t(),
  binary(),
  BACnet.Protocol.IncompleteAPDU.t(),
  term(),
  boolean(),
  BACnet.Stack.Client.State.t()
) :: :ok
```

Executes telemetry for incoming APDU segmented error
as `[:bacstack, :client, :incoming_apdu, :segmented, :error]`.

The arguments `source_address`, `bvlc`, `npci`, `raw_apdu`, `incomplete`, `error` and
`cancelled` are part of the event metadata.

# `execute_client_inc_apdu_segmentation_incomplete`

```elixir
@spec execute_client_inc_apdu_segmentation_incomplete(
  GenServer.server(),
  term(),
  BACnet.Protocol.bvlc(),
  BACnet.Protocol.NPCI.t(),
  binary(),
  BACnet.Protocol.IncompleteAPDU.t(),
  BACnet.Stack.Client.State.t()
) :: :ok
```

Executes telemetry for incoming APDU segmented incomplete
as `[:bacstack, :client, :incoming_apdu, :segmented, :incomplete]`.

The arguments `source_address`, `bvlc`, `npci`, `raw_apdu` and `incomplete`
are part of the event metadata.

# `execute_client_inc_apdu_timeout`

```elixir
@spec execute_client_inc_apdu_timeout(
  GenServer.server(),
  BACnet.Stack.Client.ReplyTimer.t(),
  BACnet.Stack.Client.State.t()
) :: :ok
```

Executes telemetry for APDU application response timeout
as `[:bacstack, :client, :incoming_apdu, :stop]`.
A `duration` key will be set in measurements using monotonic time native units.

The following keys are exposed as part of the event metadata:
- `source_address: term()`
- `bvlc: Protocol.bvlc()`
- `npci: NPCI.t()`
- `apdu: Protocol.apdu()`
- `ref: reference()`
- `error: :reply_timeout`

# `execute_client_request_apdu_timer`

```elixir
@spec execute_client_request_apdu_timer(
  GenServer.server(),
  BACnet.Stack.Client.ApduTimer.t(),
  BACnet.Stack.Client.State.t()
) :: :ok
```

Executes telemetry for APDU request timeout as `[:bacstack, :client, :request, :stop]`.
A `duration` key will be set in measurements using monotonic time native units.

The arguments `destination`, `bvlc`, `npci` and `apdu` are part of the event metadata.
Additionally, the following keys are set:
- `original_apdu: Protocol.apdu()`
- `retry_count: non_neg_integer()`

# `execute_client_request_start`

```elixir
@spec execute_client_request_start(
  GenServer.server(),
  term(),
  BACnet.Protocol.apdu(),
  Keyword.t(),
  BACnet.Stack.Client.ApduTimer.t(),
  BACnet.Stack.Client.State.t()
) :: :ok
```

Executes telemetry for request start as `[:bacstack, :client, :request, :start]`.
Requests are started by sending APDU with `expect_reply: true`.
Responses will be emitted for the request through `:stop`.

The arguments `destination`, `apdu` and `send_opts` are part of the event metadata.

# `execute_client_request_stop`

```elixir
@spec execute_client_request_stop(
  GenServer.server(),
  term(),
  BACnet.Protocol.bvlc(),
  BACnet.Protocol.NPCI.t(),
  BACnet.Protocol.apdu(),
  BACnet.Stack.Client.ApduTimer.t(),
  BACnet.Stack.Client.State.t()
) :: :ok
```

Executes telemetry for request stop as `[:bacstack, :client, :request, :stop]`.
A `duration` key will be set in measurements using monotonic time native units.

BVLC, NPCI and APDU are the response and belong to the request that got started.
See also `execute_client_request_start/6`.

The arguments `destination`, `bvlc`, `npci` and `apdu` are part of the event metadata.
Additionally, the following keys are set:
- `original_apdu: Protocol.apdu()`
- `retry_count: non_neg_integer()`

# `execute_client_send`

```elixir
@spec execute_client_send(
  GenServer.server(),
  term(),
  BACnet.Protocol.apdu(),
  Keyword.t(),
  boolean(),
  BACnet.Stack.Client.State.t()
) :: :ok
```

Executes telemetry for sending APDUs as `[:bacstack, :client, :send]`.
Segmented will indicate whether segmenting and sending the APDU has been
handed off to `BACnet.Stack.Segmentator`.

The arguments `destination`, `apdu`, `send_opts` and `segmented` are part of the event metadata.

# `execute_client_send_error`

```elixir
@spec execute_client_send_error(
  GenServer.server(),
  term(),
  BACnet.Protocol.apdu(),
  Keyword.t(),
  BACnet.Protocol.apdu(),
  atom(),
  BACnet.Stack.Client.State.t()
) :: :ok
```

Executes telemetry for send error as `[:bacstack, :client, :send, :error]`.
Send errors are encountered for APDU too long (no segmentation) or
recipient device does not support segmentation.

The arguments `destination`, `original_apdu`, `send_opts`, `reply_apdu` and
`reason` are part of the event metadata.

# `execute_client_transport_message`

```elixir
@spec execute_client_transport_message(
  GenServer.server(),
  BACnet.Stack.TransportBehaviour.transport_msg(),
  BACnet.Stack.Client.State.t()
) :: :ok
```

Executes telemetry for an error or exception as `[:bacstack, :client, :transport, :message]`.

The argument `transport_msg` is part of the event metadata.

# `execute_foreign_device_add_fd_registration`

```elixir
@spec execute_foreign_device_add_fd_registration(
  GenServer.server(),
  {:inet.ip4_address(), :inet.port_number()},
  BACnet.Stack.ForeignDevice.Registration.t(),
  BACnet.Stack.ForeignDevice.State.t()
) :: :ok
```

Executes telemetry for adding the foreign device registration in the remote BBMD
as `[:bacstack, :foreign_device, :foreign_device, :add]`.

The registration is always about ourself - status may not be registered
when this metric event gets called.

The arguments `bbmd` and `registration` are part of the event metadata.

# `execute_foreign_device_del_fd_registration`

```elixir
@spec execute_foreign_device_del_fd_registration(
  GenServer.server(),
  {:inet.ip4_address(), :inet.port_number()},
  BACnet.Stack.ForeignDevice.Registration.t(),
  BACnet.Stack.ForeignDevice.State.t()
) :: :ok
```

Executes telemetry for deleting the foreign device registration in the remote BBMD
as `[:bacstack, :foreign_device, :foreign_device, :delete]`.

The arguments `bbmd` and `registration` are part of the event metadata.

# `execute_foreign_device_distribute_broadcast`

```elixir
@spec execute_foreign_device_distribute_broadcast(
  GenServer.server(),
  {:inet.ip4_address(), :inet.port_number()},
  BACnet.Protocol.APDU.UnconfirmedServiceRequest.t(),
  Keyword.t(),
  BACnet.Stack.Client.server()
) :: :ok
```

Executes telemetry for distributing broadcast through the remote BBMD
as `[:bacstack, :foreign_device, :broadcast_distribution, :distribute]`.

The arguments `bbmd`, `apdu` and `send_opts` are part of the event metadata.

# `execute_foreign_device_exception`

```elixir
@spec execute_foreign_device_exception(
  GenServer.server(),
  term(),
  term(),
  list(),
  map(),
  BACnet.Stack.ForeignDevice.State.t()
) :: :ok
```

Executes telemetry for an error or exception as `[:bacstack, :foreign_device, :exception]`.

The arguments `kind`, `reason` and `stacktrace` are part of the event metadata.

# `execute_foreign_device_read_bdt`

```elixir
@spec execute_foreign_device_read_bdt(
  GenServer.server(),
  {:inet.ip4_address(), :inet.port_number()},
  [BACnet.Protocol.BroadcastDistributionTableEntry.t()],
  BACnet.Stack.Client.server()
) :: :ok
```

Executes telemetry for reading the broadcast distribution table from the remote BBMD
as `[:bacstack, :foreign_device, :broadcast_distribution, :read_table]`.

The arguments `bbmd` and `bdt` are part of the event metadata.

# `execute_foreign_device_read_fd_table`

```elixir
@spec execute_foreign_device_read_fd_table(
  GenServer.server(),
  {:inet.ip4_address(), :inet.port_number()},
  [BACnet.Protocol.ForeignDeviceTableEntry.t()],
  BACnet.Stack.Client.server()
) :: :ok
```

Executes telemetry for reading the foreign device table from the remote BBMD
as `[:bacstack, :foreign_device, :foreign_device, :read_table]`.

The arguments `bbmd` and `registrations` are part of the event metadata.

# `execute_foreign_device_write_bdt`

```elixir
@spec execute_foreign_device_write_bdt(
  GenServer.server(),
  {:inet.ip4_address(), :inet.port_number()},
  [BACnet.Protocol.BroadcastDistributionTableEntry.t()],
  BACnet.Stack.Client.server()
) :: :ok
```

Executes telemetry for writing the broadcast distribution table to the remote BBMD
as `[:bacstack, :foreign_device, :broadcast_distribution, :write_table]`.

The arguments `bbmd` and `bdt` are part of the event metadata.

# `execute_segmentator_exception`

```elixir
@spec execute_segmentator_exception(
  GenServer.server(),
  term(),
  term(),
  list(),
  map(),
  BACnet.Stack.Segmentator.State.t()
) :: :ok
```

Executes telemetry for an error or exception as `[:bacstack, :segmentator, :exception]`.

The arguments `kind`, `reason` and `stacktrace` are part of the event metadata.

# `execute_segmentator_sequence_ack`

```elixir
@spec execute_segmentator_sequence_ack(
  GenServer.server(),
  BACnet.Stack.Segmentator.Sequence.t(),
  BACnet.Protocol.APDU.SegmentACK.t(),
  BACnet.Stack.Segmentator.State.t()
) :: :ok
```

Executes telemetry for sequence ack as `[:bacstack, :segmentator, :sequence, :ack]`.
A segment ACK has been sent from the remote BACnet client.

The arguments `sequence` and `ack` is part of the event metadata.

# `execute_segmentator_sequence_error`

```elixir
@spec execute_segmentator_sequence_error(
  GenServer.server(),
  module(),
  BACnet.Stack.TransportBehaviour.transport(),
  BACnet.Stack.TransportBehaviour.portal(),
  term(),
  BACnet.Protocol.apdu() | nil,
  Keyword.t() | nil,
  BACnet.Protocol.apdu() | nil,
  atom(),
  BACnet.Stack.Segmentator.State.t()
) :: :ok
```

Executes telemetry for sequence error as `[:bacstack, :segmentator, :sequence, :error]`.

The arguments `transport_module`, `transport`, `portal`, `destination`, `original_apdu`,
`send_opts`, `reply_apdu` and `reason` is part of the event metadata.

# `execute_segmentator_sequence_segment`

```elixir
@spec execute_segmentator_sequence_segment(
  GenServer.server(),
  BACnet.Stack.Segmentator.Sequence.t(),
  non_neg_integer(),
  BACnet.Stack.Segmentator.State.t()
) :: :ok
```

Executes telemetry for sequence segment as `[:bacstack, :segmentator, :sequence, :segment]`.
An individual segment has been sent to the remote BACnet client.

The arguments `sequence` and `segment_number` is part of the event metadata.

# `execute_segmentator_sequence_start`

```elixir
@spec execute_segmentator_sequence_start(
  GenServer.server(),
  BACnet.Stack.Segmentator.Sequence.t(),
  BACnet.Stack.Segmentator.State.t()
) :: :ok
```

Executes telemetry for sequence start as `[:bacstack, :segmentator, :sequence, :start]`.

The argument `sequence` is part of the event metadata.

# `execute_segmentator_sequence_stop`

```elixir
@spec execute_segmentator_sequence_stop(
  GenServer.server(),
  BACnet.Stack.Segmentator.Sequence.t(),
  atom(),
  BACnet.Stack.Segmentator.State.t()
) :: :ok
```

Executes telemetry for sequence stop as `[:bacstack, :segmentator, :sequence, :stop]`.
A `duration` key will be set in measurements using monotonic time native units.

The arguments `sequence` and `reason` are part of the event metadata.

# `execute_segments_store_exception`

```elixir
@spec execute_segments_store_exception(
  GenServer.server(),
  term(),
  term(),
  list(),
  map(),
  BACnet.Stack.SegmentsStore.State.t()
) :: :ok
```

Executes telemetry for an error or exception as `[:bacstack, :segments_store, :exception]`.

The arguments `kind`, `reason` and `stacktrace` are part of the event metadata.

# `execute_segments_store_sequence_ack`

```elixir
@spec execute_segments_store_sequence_ack(
  GenServer.server(),
  BACnet.Stack.SegmentsStore.Sequence.t(),
  BACnet.Protocol.APDU.SegmentACK.t(),
  BACnet.Stack.SegmentsStore.State.t()
) :: :ok
```

Executes telemetry for sequence ack as `[:bacstack, :segments_store, :sequence, :ack]`.
A segment ACK has been sent to the remote BACnet client.

The arguments `sequence` and `ack` is part of the event metadata.

# `execute_segments_store_sequence_error`

```elixir
@spec execute_segments_store_sequence_error(
  GenServer.server(),
  module(),
  BACnet.Stack.TransportBehaviour.portal(),
  term(),
  BACnet.Protocol.IncompleteAPDU.t() | nil,
  Keyword.t() | nil,
  BACnet.Protocol.apdu() | nil,
  atom(),
  BACnet.Stack.SegmentsStore.State.t()
) :: :ok
```

Executes telemetry for sequence error as `[:bacstack, :segments_store, :sequence, :error]`.

The arguments `transport_module`, `portal`, `destination`, `incomplete_apdu`,
`send_opts`, `reply_apdu` and `reason` is part of the event metadata.

# `execute_segments_store_sequence_segment`

```elixir
@spec execute_segments_store_sequence_segment(
  GenServer.server(),
  BACnet.Stack.SegmentsStore.Sequence.t(),
  non_neg_integer(),
  BACnet.Stack.SegmentsStore.State.t()
) :: :ok
```

Executes telemetry for sequence segment as `[:bacstack, :segments_store, :sequence, :segment]`.
An individual segment has been received from the remote BACnet client.

The arguments `sequence` and `segment_number` is part of the event metadata.

# `execute_segments_store_sequence_start`

```elixir
@spec execute_segments_store_sequence_start(
  GenServer.server(),
  BACnet.Stack.SegmentsStore.Sequence.t(),
  BACnet.Stack.SegmentsStore.State.t()
) :: :ok
```

Executes telemetry for sequence start as `[:bacstack, :segments_store, :sequence, :start]`.

The argument `sequence` is part of the event metadata.

# `execute_segments_store_sequence_stop`

```elixir
@spec execute_segments_store_sequence_stop(
  GenServer.server(),
  BACnet.Stack.SegmentsStore.Sequence.t(),
  atom(),
  BACnet.Stack.SegmentsStore.State.t()
) :: :ok
```

Executes telemetry for sequence stop as `[:bacstack, :segments_store, :sequence, :stop]`.
A `duration` key will be set in measurements using monotonic time native units.

The arguments `sequence` and `reason` are part of the event metadata.

# `execute_trend_logger_cov_sub`

```elixir
@spec execute_trend_logger_cov_sub(
  GenServer.server(),
  BACnet.Protocol.DeviceObjectPropertyRef.t()
) :: :ok
```

Executes telemetry for subscribing COV
as `[:bacstack, :trend_logger, :lookup_object, :cov_sub]`.
This function is called when subscribing for COV
in the Trend Logger. Most notably for COV logs.

The argument `object_ref` is part of the event metadata.

# `execute_trend_logger_cov_unsub`

```elixir
@spec execute_trend_logger_cov_unsub(
  GenServer.server(),
  BACnet.Protocol.DeviceObjectPropertyRef.t()
) :: :ok
```

Executes telemetry for unsubscribing COV
as `[:bacstack, :trend_logger, :lookup_object, :cov_unsub]`.
This function is called when unsubscribing for COV
in the Trend Logger. Most notably for COV logs.

The argument `object_ref` is part of the event metadata.

# `execute_trend_logger_exception`

```elixir
@spec execute_trend_logger_exception(
  GenServer.server(),
  term(),
  term(),
  list(),
  map(),
  BACnet.Stack.TrendLogger.State.t()
) :: :ok
```

Executes telemetry for an error or exception as `[:bacstack, :trend_logger, :exception]`.

The arguments `kind`, `reason` and `stacktrace` are part of the event metadata.

# `execute_trend_logger_log_notify`

```elixir
@spec execute_trend_logger_log_notify(
  GenServer.server(),
  BACnet.Stack.TrendLogger.Log.t(),
  :buffer_full | :intrinsic_reporting,
  BACnet.Stack.TrendLogger.State.t()
) :: :ok
```

Executes telemetry for notifications of the log object
as `[:bacstack, :trend_logger, :log_object, :notify]`.
This function is called when a log object produces
notifications in the Trend Logger.
Notify types can happen concurrently, so be prepared.

The arguments `log` and `notify_type` are part of the event metadata.

# `execute_trend_logger_log_start`

```elixir
@spec execute_trend_logger_log_start(
  GenServer.server(),
  BACnet.Stack.TrendLogger.Log.t(),
  BACnet.Stack.TrendLogger.State.t()
) :: :ok
```

Executes telemetry for log object start as `[:bacstack, :trend_logger, :log_object, :start]`.
This function is called when a log object gets added to the Trend Logger.

The argument `log` is part of the event metadata.

# `execute_trend_logger_log_stop`

```elixir
@spec execute_trend_logger_log_stop(
  GenServer.server(),
  BACnet.Stack.TrendLogger.Log.t(),
  BACnet.Stack.TrendLogger.State.t()
) :: :ok
```

Executes telemetry for log object stop as `[:bacstack, :trend_logger, :log_object, :stop]`.
This function is called when a log object gets removed from the Trend Logger.

The argument `log` is part of the event metadata.

# `execute_trend_logger_log_trigger`

```elixir
@spec execute_trend_logger_log_trigger(
  GenServer.server(),
  BACnet.Stack.TrendLogger.Log.t(),
  BACnet.Protocol.Services.ConfirmedEventNotification.t()
  | BACnet.Protocol.Services.UnconfirmedEventNotification.t()
  | BACnet.Protocol.Services.ConfirmedCovNotification.t()
  | BACnet.Protocol.ObjectsUtility.bacnet_object()
  | [BACnet.Protocol.ObjectsUtility.bacnet_object()]
  | :interrupted
  | {:time_change, float()},
  BACnet.Stack.TrendLogger.State.t()
) :: :ok
```

Executes telemetry for trigger of the log object
as `[:bacstack, :trend_logger, :log_object, :notify]`.
This function is called when a log object gets
triggered to log in the Trend Logger.

The argument `log` and `log_entry` are part of the event metadata.

# `execute_trend_logger_log_update`

```elixir
@spec execute_trend_logger_log_update(
  GenServer.server(),
  BACnet.Stack.TrendLogger.Log.t(),
  :buffer | :state,
  BACnet.Stack.TrendLogger.State.t()
) :: :ok
```

Executes telemetry for updates to the log object
as `[:bacstack, :trend_logger, :log_object, :update]`.
This function is called when a log object gets updated in the Trend Logger.
Updates may happen explicitely by the user (changing properties,
enabling/disabling, etc.), or by updates to the buffer
produced by the logging algorithm.

The arguments `log` and `type` is part of the event metadata.

# `execute_trend_logger_lookup_object_error`

```elixir
@spec execute_trend_logger_lookup_object_error(
  GenServer.server(),
  BACnet.Protocol.DeviceObjectRef.t(),
  BACnet.Protocol.BACnetError.t(),
  integer()
) :: :ok
```

Executes telemetry for error during look up objects
as `[:bacstack, :trend_logger, :lookup_object, :error]`.

A `duration` measurement is present in monotonic native units.
For the calculation of duration, separate monotonic time is used
and may differ a bit from both monotonic time present in start
and stop metrics.

The arguments `object_ref` and `error` are part of the event metadata.

# `execute_trend_logger_lookup_object_start`

```elixir
@spec execute_trend_logger_lookup_object_start(
  GenServer.server(),
  BACnet.Protocol.DeviceObjectRef.t()
) :: :ok
```

Executes telemetry for looking up objects
as `[:bacstack, :trend_logger, :lookup_object, :start]`.
This function is called when objects are looked up
in the Trend Logger. Most notably for poll logs.

The argument `object_ref` is part of the event metadata.

# `execute_trend_logger_lookup_object_stop`

```elixir
@spec execute_trend_logger_lookup_object_stop(
  GenServer.server(),
  BACnet.Protocol.DeviceObjectRef.t(),
  BACnet.Protocol.ObjectsUtility.bacnet_object(),
  integer()
) :: :ok
```

Executes telemetry for stop looking up objects
as `[:bacstack, :trend_logger, :lookup_object, :stop]`.

A `duration` measurement is present in monotonic native units.
For the calculation of duration, separate monotonic time is used
and may differ a bit from both monotonic time present in start
and stop metrics.

The arguments `object_ref` and `result` are part of the event metadata.

# `get_telemetry_measurements`

```elixir
@spec get_telemetry_measurements(map()) :: %{
  :monotonic_time =&gt; any(),
  :system_time =&gt; any(),
  optional(any()) =&gt; any()
}
```

Get basic telemetry measurements, such as `monotonic_time` and `system_time`.
The given map will be merged into the basic measurements map.

# `make_stacktrace_from_env`

```elixir
@spec make_stacktrace_from_env(Macro.Env.t()) :: Exception.stacktrace_entry()
```

Makes a single stacktrace entry from the environment.

Use case is calling `execute_*_exception` functions here without a real stacktrace.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
