defmodule BACnet.Protocol.ObjectTypes.TrendLogMultiple do
  @moduledoc """
  A Trend Log Multiple object monitors one or more properties of one or more
  referenced objects, either in the same device as the Trend Log Multiple object
  or in an external device. When predefined conditions are met,
  the object saves ("logs") the value of the properties and a timestamp into
  an internal buffer for subsequent retrieval. The data may be logged periodically
  or when "triggered" by a write to the Trigger property. Errors that prevent the
  acquisition of the data, as well as changes in the status or operation of the
  logging process itself, are also recorded. Each timestamped buffer entry is
  called a "log record". The Log_DeviceObjectProperty array holds the list of
  properties to be monitored and logged. If an element of the
  Log_DeviceObjectProperty array has an object or device instance number equal to 4194303,
  this indicates that the element is 'empty' or 'uninitialized'.
  For empty or uninitialized elements, an indication that no property was specified
  shall be written to the corresponding entry in each log record.

  Each Trend Log Multiple object maintains an internal, optionally fixed-size,
  buffer in its Log_Buffer property. This buffer fills or grows as log records are added.
  If the buffer becomes full, the least recent log record is overwritten when a new log
  record is added, or collection may be set to stop. Trend Log Multiple buffers are
  transferred as a list of BACnetLogMultipleRecord using the ReadRange service.
  The buffer may be cleared by writing a zero to the Record_Count property.
  Each log record in the buffer has an implied SequenceNumber that is equal to
  the value of the Total_Record_Count property immediately after the log record is added.

  Logging may be enabled and disabled through the Enable property and at dates and times
  specified by the Start_Time and Stop_Time properties. The enabling and disabling of
  record collection is recorded in the Log_Buffer.
  Event reporting (notification) may be provided to facilitate automatic fetching of
  log records by processes on other devices such as fileservers.
  Mechanisms for both algorithmic and intrinsic reporting are provided.
  Trend Log Multiple objects that support intrinsic reporting shall apply the BUFFER_READY event algorithm.

  In intrinsic reporting, when the number of records specified by the
  Notification_Threshold property has been collected since the previous notification (or startup),
  a new notification is sent to all subscribed devices. In response to a notification,
  subscribers may fetch all of the new log records. If a subscriber needs to fetch all
  of the new log records, it should use the 'By Sequence Number' form of the
  ReadRange service request. A missed notification may be detected by a subscriber
  if the 'Current Notification' parameter received in the previous BUFFER_READY notification
  is different than the 'Previous Notification' parameter of the current BUFFER_READY
  notification. If the ReadRange-ACK response to the ReadRange request issued under these conditions
  has the FIRST_ITEM bit of the 'Result Flags' parameter set to TRUE, Trend Log Multiple log records
  have probably been missed by this subscriber.
  The acquisition of log records by remote devices has no effect upon the state of the
  Trend Log Multiple object itself. This allows completely independent, but properly sequential,
  access to its log records by all remote devices. Any remote device can independently
  update its records at any time.

  (ASHRAE 135 - Clause 12.30)
  """

  # TODO: Docs

  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.LogMultipleRecord
  alias BACnet.Protocol.LogStatus
  alias BACnet.Protocol.ObjectsMacro

  require Constants
  use ObjectsMacro

  @typedoc """
  Available object options.
  """
  @type object_opts ::
          {:intrinsic_reporting, boolean()}
          | common_object_opts()
          | {:clock_aligned_logging, boolean()}

  @typedoc """
  Represents a Trend Log Multiple object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

  Properties which are for Intrinsic Reporting are nil, if disabled. If Intrinsic Reporting is enabled on the object,
  then the properties can not be nil.
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

    field(:log_buffer, [LogMultipleRecord.t()],
      required: true,
      default: [],
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

    field(:logging_type, Constants.logging_type(), required: true)

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
           %LogMultipleRecord{
             timestamp: BACnetDateTime.utc_now(),
             log_data: %LogStatus{
               log_disabled: false,
               buffer_purged: true,
               log_interrupted: false
             }
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

  # Override check_implicit_relationships/2 to be able to override behaviour for
  # logging_type and log_interval (error if not plausible)
  defp check_implicit_relationships(object, operation) do
    with {:ok, object} <- super(object, operation) do
      case object do
        %{logging_type: :cov, log_interval: log} when log > 0 ->
          {:error, {:invalid_property_value_for_logging_type, :log_interval}}

        %{logging_type: :polled, log_interval: 0} ->
          {:error, {:invalid_property_value_for_logging_type, :log_interval}}

        _else ->
          {:ok, object}
      end
    end
  end
end
