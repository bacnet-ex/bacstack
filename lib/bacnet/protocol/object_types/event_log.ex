defmodule BACnet.Protocol.ObjectTypes.EventLog do
  @moduledoc """
  The Event Log object captures `BACnet.Protocol.Services.ConfirmedEventNotification`
  and `BACnet.Protocol.Services.UnconfirmedEventNotification` into a timestamped buffer,
  so that alarm and event history can be retrieved later with the
  `BACnet.Protocol.Services.ReadRange` service. It is the BACnet-native replacement
  for a local alarm printer or syslog for events.

  Records contain the full event information (source object, event type, message text,
  priority, etc.). The log can be configured as a fixed-size circular buffer or a
  growing one (until stopped or full). It supports a time window (`start_time` / `stop_time`),
  enable/disable, and can itself generate a BUFFER_READY intrinsic event (when
  `intrinsic_reporting: true`) when the log has new data worth harvesting.

  ### Object Description (ASHRAE 135)

  > An Event Log object records event notifications with timestamps and other
  > pertinent data in an internal buffer for subsequent retrieval.

  ### Behaviour and Operation

  Event Log objects are buffers that receive copies of event notifications
  (both confirmed and unconfirmed). The conditions by which events are forwarded
  to a particular Event Log is not specified and is a local matter.
  The local application is responsible for appending a record (containing
  timestamp, source, event type, message text, etc.) to the log buffer whenever an
  event notification is sent or received that matches the log's configuration.

  Records are retrieved by clients using the `ReadRange` service. The log can be
  circular or append-only until full/stopped. `start_time` / `stop_time` and the
  enable flag control when logging is active. When intrinsic reporting is enabled
  the log itself can emit a BUFFER_READY event to notify a workstation that new
  records are available for collection.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, via `update_property/3` (never direct mutation).
  Read notes below + generated tables for details.

  **Special / live properties and expected developer behaviour**

  Similar to TrendLog but for event notifications (ConfirmedEventNotification etc).

  - `log_buffer`: History of event notifications.
    **Dev must**: Your event notification handler (when you emit or receive
    notifications that should be logged) must construct EventLogRecord (with
    timestamp, the notification params, status) and append via update on the
    buffer (respect buffer_size, stop_when_full, enable, start/stop times).

  - `record_count`, `total_record_count`:
    **Dev must**: Manage counts on appends; for BUFFER_READY when intrinsic, track
    records since last notify and emit when threshold crossed.

  - `start_time`/`stop_time`, `enable`, `stop_when_full`, `buffer_size`:
    Config for logging window.
    **Dev must**: Your logger respects the times/enable when deciding to log a
    notification. `buffer_size` writes restricted when enabled.

  - `status_flags`, `reliability`.
    **Dev must**: Update on problems logging or with event sources. Note `in_alarm`/
    `fault`/`out_of_service` bits of `status_flags` are automatically managed by the
    object.

  The object is passive storage + config; you drive the logging of events into it.

  ### Intrinsic Reporting

  When `intrinsic_reporting: true` is passed to `create/4`, additional event
  reporting properties become active for the log itself.

  ### Examples

  Creating an Event Log:

      iex> {:ok, el} = BACnet.Protocol.ObjectTypes.EventLog.create(800, "EventHistory", %{buffer_size: 100}); el.object_name
      "EventHistory"

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

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring an Event Log object.

  In addition to the common options, Event Log supports:
  - `intrinsic_reporting` - Enables intrinsic event reporting properties for the log.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()}
          | common_object_opts()

  @typedoc """
  Represents a Event Log object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.
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

    field(:log_buffer, [EventLogRecord.t()],
      required: true,
      default: [],
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
    field(:profile_name, String.t())

    # Intrinsic Reporting
    field(:notification_threshold, ApplicationTags.unsigned32(),
      intrinsic: true,
      default: 0
    )

    field(:records_since_notification, ApplicationTags.unsigned32(),
      intrinsic: true,
      default: 0
    )

    field(:last_notify_record, ApplicationTags.unsigned32(),
      intrinsic: true,
      default: 0
    )
  end
end
