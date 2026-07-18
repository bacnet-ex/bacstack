defmodule BACnet.Protocol.ObjectTypes.TrendLog do
  @moduledoc """
  The Trend Log object is the standard BACnet mechanism for local data logging.
  It watches a single property (any object, local or remote, referenced via
  `log_device_object_property`) and records timestamped samples into a circular or
  growing buffer. Logging can be triggered periodically (`log_interval`), on COV of
  the monitored property, or by an explicit trigger.

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

  Trend Log objects are active data loggers. A background task (driven by a timer
  or by COV notifications from the monitored property) periodically or on trigger
  reads the property referenced by `log_device_object_property` (local or remote)
  and appends a `BACnet.Protocol.LogRecord` to the internal buffer.

  The application / stack must implement the actual sampling and buffering logic
  (respecting `log_interval`, `start_time`/`stop_time`, `stop_when_full`, buffer
  size, etc.). Clients retrieve historical records with ReadRange.

  When `intrinsic_reporting: true` the log can emit a BUFFER_READY notification
  when the number of records since last notification reaches `notification_threshold`,
  telling a client that new trend data is ready to be harvested.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  - `log_device_object_property`: The property (local or remote) being logged.
    **Dev must**: Your logging engine task must read its current value (ReadProperty
    or COV sub for remote) on the schedule dictated by logging_type / log_interval /
    COV, and include the `Encoding` + status in the `LogRecord`.

  - `log_buffer`: The circular or append-only history.
    **Dev must**: The core of the engine. On each sample, build `LogRecord`,
    then `update_property/3` the buffer (append/overwrite respecting `stop_when_full`)
    or manage buffer yourself and write whole on change. The object enforces size,
    enable, start/stop windows.

  - `record_count`, `total_record_count`: Counters.
    **Dev must**: Bump `record_count` on appends; total is ever-increasing. Special
    update paths allow resetting `record_count`=0 in some cases.

  - `trigger`: Manual sample trigger (for triggered `logging_type`).
    **Dev must**: BACnet client writes `true` to force an immediate sample + log.

  - `logging_type`, `log_interval`, `cov_resubscription_interval`,
    `client_cov_increment`, `align_intervals`/`interval_offset`: Sampling config.
    **Dev must**: Your task reacts to changes. Re-schedule timers or COV subs.
    For aligned, compute sample times from midnight + offset.

  - `buffer_size`, `stop_when_full`, `enable`, `start_time`/`stop_time`: Logging
    control.
    **Dev must**: Respect in your sampler (don't log if disabled or outside time
    window).

  - `notification_threshold` + intrinsic event fields: For BUFFER_READY.
    **Dev must**: On every append, manage the "since last" counter; when it hits
    threshold, emit BUFFER_READY notification and reset.
    Tells clients "new data to harvest with ReadRange".

  - `reliability`, `status_flags`: Source or buffer problems
    (e.g. full + `stop_when_full`).
    **Dev must**: Set when referenced properties unreachable or other issues.
    Note that `in_alarm`/`fault`/`out_of_service` bits of `status_flags`
    are auto-managed by the object.

  Trend Log (and TrendLogMultiple) are the standard way to keep a local circular
  or append-only history of any property so that a workstation can later harvest
  it with ReadRange without having to poll 24/7.

  **You own the logging engine**: Nothing in the object automatically samples.
  You must have a task that:
  - wakes on a timer (for `log_interval` / polled mode) or is notified when the
    watched property changes (for COV-triggered or "on change" logging_type)
  - reads the current value of the (possibly remote) `log_device_object_property`
    and builds a `LogRecord`.
  - Update `record_count` property and run the event algorithm, if intrinsic.
  - Maintain the buffer yourself and make it available through ReadRange service.

  **Clock-aligned logging**: If the `align_intervals` flag (or equivalent) is set
  you must compute the next sample time as a multiple of the interval from
  midnight / from the `interval_offset`. This is so that logs from many devices
  line up nicely when plotted.

  **BUFFER_READY intrinsic event**: When `intrinsic_reporting: true` the object
  carries a `notification_threshold` and the normal event fields. Every time you
  append a record you (or a central event helper) must increment a "records since
  last notification" counter. When it crosses the threshold you emit a
  BUFFER_READY event (using the object's own notification_class) and reset the
  counter. This tells a historian "there is new data worth harvesting with
  ReadRange" without the historian having to poll the enable / record count
  fields.

  **Remote logging source**: When the reference points at another device you must
  perform the ReadProperty (or subscribe to COVs on the remote property) on the
  schedule the log wants. If the remote read fails you should still append a
  record with a null / error value and the appropriate status bits so that the
  gap is visible in the history.

  Trend logs are one of the heaviest users of the "active object + your engine
  drives the side effects" pattern. Treat the object as a smart configuration +
  buffer container; the real work (sampling, time keeping, buffer management,
  BUFFER_READY emission) lives in your code.

  The `BACnet.Stack.TrendLogger` module does a lot of this work.

  ### Intrinsic Reporting

  When `intrinsic_reporting: true` is passed to `create/4`, BUFFER_READY intrinsic
  reporting is enabled (notifications when the buffer reaches `notification_threshold`).

  ### Examples

  Creating a basic Trend Log (polled logging):

      iex> alias BACnet.Protocol.{DeviceObjectPropertyRef, ObjectIdentifier}
      iex> ref = %DeviceObjectPropertyRef{object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1}, property_identifier: :present_value, property_array_index: nil, device_identifier: nil}
      iex> {:ok, tl} = BACnet.Protocol.ObjectTypes.TrendLog.create(900, "TempTrend", %{log_device_object_property: ref, log_interval: 60, buffer_size: 100, logging_type: :polled}); tl.object_name
      "TempTrend"

  With clock-aligned logging and intrinsic reporting:

      iex> alias BACnet.Protocol.{DeviceObjectPropertyRef, ObjectIdentifier}
      iex> ref = %DeviceObjectPropertyRef{object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1}, property_identifier: :present_value, property_array_index: nil, device_identifier: nil}
      iex> {:ok, tl} = BACnet.Protocol.ObjectTypes.TrendLog.create(901, "AlignedTrend", %{log_device_object_property: ref, log_interval: 300, buffer_size: 50, logging_type: :polled, align_intervals: false, interval_offset: 0}, intrinsic_reporting: true, clock_aligned_logging: true); tl.object_name
      "AlignedTrend"

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
  alias BACnet.Protocol.LogStatus
  alias BACnet.Protocol.ObjectsMacro

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Trend Log object.

  In addition to the common options, Trend Log supports:
  - `clock_aligned_logging` - Enables clock-aligned logging intervals.
  - `intrinsic_reporting` - Enables BUFFER_READY intrinsic reporting (notifications when
    Notification_Threshold records have been collected).
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()}
          | common_object_opts()
          | {:clock_aligned_logging, boolean()}

  @typedoc """
  Represents a Trend Log object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.
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

    # The following two properties are required if clock-aligned logging is supported
    field(:align_intervals, boolean(),
      annotation: [required_when: {:opts, :clock_aligned_logging}]
    )

    field(:interval_offset, non_neg_integer(),
      annotation: [required_when: {:opts, :clock_aligned_logging}]
    )

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
      intrinsic: true,
      default: 0
    )

    field(:last_notify_record, ApplicationTags.unsigned32(),
      intrinsic: true,
      default: 0
    )
  end

  # Override property_writable?/2, to be able to override :buffer_size, :log_interval behaviour
  # (writable if logging_type != :triggered)
  # When writing buffer_size, it may only when trend_log is not enabled
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

  # Override update_property/3, to flip logging_type on log_interval write (pre rev. 14 compatibility)
  # When writing log_interval to 0, change logging_type to cov
  # When writing log_interval to non-0, change logging_type to polled
  def update_property(%__MODULE__{} = object, :log_interval, value) do
    with {:ok, object} <- super(object, :log_interval, value),
         do:
           update_property(
             object,
             :logging_type,
             if(value == 0,
               do: Constants.macro_assert_name(:logging_type, :cov),
               else: Constants.macro_assert_name(:logging_type, :polled)
             )
           )
  end

  # When writing to record_count, a value of 0 will truncate the buffer
  def update_property(%__MODULE__{} = object, :record_count, 0) do
    {:ok,
     %{
       object
       | log_buffer: [
           %LogRecord{
             timestamp: BACnetDateTime.utc_now(),
             log_datum: %LogStatus{
               log_disabled: false,
               buffer_purged: true,
               log_interrupted: false
             },
             status_flags: nil
           }
         ],
         record_count: 1,
         records_since_notification: if(intrinsic_reporting?(object), do: 0, else: nil)
     }}
  end

  def update_property(%__MODULE__{} = _object, :record_count, _value) do
    {:error, {:invalid_property_value, :record_count}}
  end

  def update_property(%__MODULE__{} = object, property, value) when is_atom(property) do
    super(object, property, value)
  end

  # Patch invalid log_interval values for the logging_type
  defp inhibit_object_check(%{logging_type: :polled, log_interval: 0} = object),
    do: {:ok, %{object | log_interval: 1}}

  defp inhibit_object_check(%{logging_type: :cov, log_interval: log} = object) when log > 0,
    do: {:ok, %{object | log_interval: 0}}

  defp inhibit_object_check(%{logging_type: :triggered, log_interval: log} = object) when log > 0,
    do: {:ok, %{object | log_interval: 0}}

  defp inhibit_object_check(object), do: {:ok, object}
end
