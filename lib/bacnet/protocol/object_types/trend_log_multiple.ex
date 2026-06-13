defmodule BACnet.Protocol.ObjectTypes.TrendLogMultiple do
  @moduledoc """
  The Trend Log Multiple object extends Trend Log to record several properties at
  once into each log entry. All monitored properties (listed in
  `log_device_object_property`) are sampled on the same trigger
  (periodic or explicit), producing a single record that contains the values
  of every member at that instant. This makes it ideal for capturing correlated
  data (e.g. supply/return temp + valve position + airflow at the same moment).

  The object offers the same rich configuration as a regular Trend Log: clock-aligned
  logging, time windows, buffer management, enable/disable, and optional
  BUFFER_READY intrinsic reporting when `intrinsic_reporting: true`.
  Buffer Retrieval is performed with the `BACnet.Protocol.Services.ReadRange` service.

  ### Object Description (ASHRAE 135)

  > A Trend Log Multiple object monitors one or more properties of one or more
  > referenced objects, either in the same device as the Trend Log Multiple object
  > or in an external device. When predefined conditions are met,
  > the object saves ("logs") the value of the properties and a timestamp into
  > an internal buffer for subsequent retrieval.
  >
  > Trend Log Multiple objects that support intrinsic reporting shall
  > apply the BUFFER_READY event algorithm.

  ### Behaviour and Operation

  Trend Log Multiple objects are like Trend Log but log a multiple of properties on
  each sample (all properties in `log_device_object_property` are captured).
  This produces correlated snapshots useful for analyzing cause-effect relationships.

  The local logging engine must sample all referenced properties (local or remote)
  at the same trigger instant (periodic or explicit trigger) and store a single
  `BACnet.Protocol.LogMultipleRecord` containing the values.

  Retrieval, buffer management, clock alignment, start/stop windows, and
  BUFFER_READY intrinsic reporting (when enabled) work the same as for a regular
  Trend Log.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself**, analogous to maintaining `present_value` on
  inputs via `update_property/3` (never direct mutation). Read notes below + generated
  tables for details.

  **Special / live properties and expected developer behaviour**

  (Very similar to TrendLog; see its notes for the full engine description.)

  - `log_device_object_property` (now a BACnetArray of refs for multiple): The
    properties being trended (can be on local or remote devices).
    **Dev must**: Your logging task(s) must periodically (polled) or on change (COV)
    read all the referenced properties (issuing ReadProperty or using COV subs for
    remotes) and produce LogMultipleRecord entries containing the array of values.

  - `log_buffer` ([LogMultipleRecord.t()]): The history.
    **Dev must**: Own the sampler: on timer or notification, read current values (with
    status), build record with timestamp + the array of values + status, append or
    overwrite per stop_when_full using update_property on the buffer (or manage
    internally and write whole). Enforce buffer_size.

  - `record_count`, `total_record_count` (some readonly): Counters.
    **Dev must**: Increment record_count on appends; total is cumulative (never
    resets). Special update overrides allow reset of record_count to 0 under
    conditions.

  - `trigger`: For logging_type :triggered.
    **Dev must**: Your code writes true to trigger a sample on demand.

  - `logging_type`, `log_interval`, `cov_resubscription_interval`, `client_cov_increment`:
    Control sampling mode.
    **Dev must**: Your engine reacts to changes (the object has overrides that e.g.
    flip logging_type on log_interval 0/non0 for compat). Re-schedule your task or
    COV subs accordingly. property_writable? prevents some changes while enabled.

  - `buffer_size`, `stop_when_full`, `enable`, `start_time`/`stop_time`, `align_intervals` etc:
    Config.
    **Dev must**: Your writer must respect enable/stop/start windows, and for
    aligned use proper next sample time calculation. buffer_size writes only
    allowed when !enable (enforced by override).

  - `notification_threshold` + intrinsic event fields (when enabled): BUFFER_READY.
    **Dev must**: On appends, manage records_since_notification, emit when crosses
    threshold.

  - `reliability` etc: Source or buffer full issues.
    **Dev must**: Set when a referenced prop can't be read, or buffer issues.

  Your logging engine is responsible for all sampling and buffer management; the
  object is the config + storage + enforcement container. See TrendLog notes for
  more on clock aligned, remote sources, performance, etc.

  The `BACnet.Stack.TrendLogger` module does a lot of this work.

  ### Intrinsic Reporting

  When `intrinsic_reporting: true` is passed to `create/4`,
  BUFFER_READY intrinsic reporting is enabled.

  ### Examples

  Creating a Trend Log Multiple:

      iex> alias BACnet.Protocol.{DeviceObjectPropertyRef, ObjectIdentifier, BACnetArray}
      iex> ref = %DeviceObjectPropertyRef{object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1}, property_identifier: :present_value, property_array_index: nil, device_identifier: nil}
      iex> {:ok, tlm} = BACnet.Protocol.ObjectTypes.TrendLogMultiple.create(1000, "MultiTrend", %{log_device_object_property: BACnetArray.from_list([ref]), buffer_size: 100, logging_type: :polled, log_interval: 60}); tlm.object_name
      "MultiTrend"

  With special options:

      iex> alias BACnet.Protocol.{DeviceObjectPropertyRef, ObjectIdentifier, BACnetArray}
      iex> ref = %DeviceObjectPropertyRef{object_identifier: %ObjectIdentifier{type: :analog_input, instance: 1}, property_identifier: :present_value, property_array_index: nil, device_identifier: nil}
      iex> {:ok, tlm} = BACnet.Protocol.ObjectTypes.TrendLogMultiple.create(1001, "AlignedMulti", %{log_device_object_property: BACnetArray.from_list([ref]), buffer_size: 50, logging_type: :polled, log_interval: 300, align_intervals: false, interval_offset: 0}, intrinsic_reporting: true, clock_aligned_logging: true); tlm.object_name
      "AlignedMulti"

  ### See Also
  - `BACnet.Protocol.LogMultipleRecord`
  - `BACnet.Protocol.EventAlgorithms.BufferReady`
  - `BACnet.Protocol.Services.ReadRange`
  - `BACnet.Stack.TrendLogger`
  """

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
  Options accepted when creating or configuring a Trend Log Multiple object.

  In addition to the common options, Trend Log Multiple supports:
  - `clock_aligned_logging` - Enables clock-aligned logging intervals.
  - `intrinsic_reporting` - Enables BUFFER_READY intrinsic reporting.
  """
  @type object_opts ::
          {:clock_aligned_logging, boolean()}
          | {:intrinsic_reporting, boolean()}
          | common_object_opts()

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

    # Logging Type MUST NOT be COV for Trend Log Multiple
    field(:logging_type, Constants.logging_type(), required: true, validator_fun: &(&1 != :cov))

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
  # When writing log_interval to 0, change logging_type to triggered
  # When writing log_interval to non-0, change logging_type to polled
  def update_property(%__MODULE__{} = object, :log_interval, value) do
    with {:ok, object} <- super(object, :log_interval, value),
         do:
           update_property(
             object,
             :logging_type,
             if(value == 0,
               do: Constants.macro_assert_name(:logging_type, :triggered),
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

  # Patch invalid log_interval values for the logging_type
  defp inhibit_object_check(%{logging_type: :polled, log_interval: 0} = object),
    do: {:ok, %{object | log_interval: 1}}

  defp inhibit_object_check(%{logging_type: :triggered, log_interval: log} = object) when log > 0,
    do: {:ok, %{object | log_interval: 0}}

  defp inhibit_object_check(object), do: {:ok, object}
end
