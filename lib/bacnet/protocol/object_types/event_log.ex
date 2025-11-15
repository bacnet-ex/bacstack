defmodule BACnet.Protocol.ObjectTypes.EventLog do
  @moduledoc """
  An Event Log object records event notifications with timestamps and other
  pertinent data in an internal buffer for subsequent retrieval.
  Each timestamped buffer entry is called an event log "record".

  Each Event Log object maintains an internal, optionally fixed-size buffer.
  This buffer fills or grows as event log records are added.
  If the buffer becomes full, the least recent records are overwritten when
  new records are added, or collection may be set to stop.
  Event log records are transferred as BACnetEventLogRecords using
  the ReadRange service. The buffer may be cleared by writing a zero to
  the Record_Count property. The determination of which notifications are
  placed into the log is a local matter. Each record in the buffer has an
  implied SequenceNumber that is equal to the value of the Total_Record_Count
  property immediately after the record is added.

  Logging may be enabled and disabled through the Enable property and
  at dates and times specified by the Start_Time and Stop_Time properties.
  Event Log enabling and disabling is recorded in the event log buffer.
  Event reporting (notification) may be provided to facilitate automatic
  fetching of event log records by processes on other devices such as fileservers.
  Support is provided for algorithmic reporting; optionally, intrinsic reporting may be provided.
  Event Log objects that support intrinsic reporting shall apply the BUFFER_READY event algorithm.

  In intrinsic reporting, when the number of records specified by
  the Notification_Threshold property has been collected since the previous
  notification (or startup), a new notification is sent to all subscribed devices.
  In response to a notification, subscribers may fetch all of the new records.
  If a subscriber needs to fetch all of the new records, it should use
  the 'By Sequence Number' form of the ReadRange service request.
  A missed notification may be detected by a subscriber if the 'Current Notification'
  parameter received in the previous BUFFER_READY notification is different than
  the 'Previous Notification' parameter of the current BUFFER_READY notification.
  If the ReadRange-ACK response to the ReadRange request issued under these conditions
  has the FIRST_ITEM bit of the 'Result Flags' parameter set to TRUE, event log records
  have probably been missed by this subscriber. The acquisition of log records by
  remote devices has no effect upon the state of the Event Log object itself.
  This allows completely independent, but properly sequential, access to its log records
  by all remote devices. Any remote device can independently update its records at any time.

  (ASHRAE 135 - Clause 12.27)
  """

  # TODO: Docs

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.EventLogRecord

  require Constants
  use BACnet.Protocol.ObjectsMacro

  @typedoc """
  Available object options.
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
