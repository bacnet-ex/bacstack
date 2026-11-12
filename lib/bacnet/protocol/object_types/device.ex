defmodule BACnet.Protocol.ObjectTypes.Device do
  @moduledoc """
  A Device object identifies a BACnet device and exposes its capabilities and
  operating state. Its object identifier distinguishes the device from other
  devices on the BACnet internetwork.

  The object advertises protocol conformance (`protocol_services_supported`,
  `protocol_object_types_supported`, `segmentation_support`, etc.), vendor and model
  information, firmware version, and many operational parameters (`max_apdu_length`,
  `apdu_timeout`, `database_revision`, `last_restart_reason`, backup/restore status,
  active COV subscriptions, time synchronisation settings, object list, etc.).
  Several properties need special server-side handling.

  ### Object Description (ASHRAE 135)

  > The Device object type defines a standardized object whose properties represent
  > the externally visible characteristics of a BACnet Device. There shall be exactly
  > one Device object in each BACnet Device. A Device object is referenced by its
  > Object_Identifier property, which is not only unique to the BACnet Device that
  > maintains this object but is also unique throughout the BACnet internetwork.

  ### Behaviour and Operation

  The Device object describes a BACnet device's identity, capabilities, object database,
  and operating state. Remote Device objects are snapshots, such as those returned by
  `BACnet.Stack.ClientHelper.read_object/4`.

  #### Lifecycle

  The [object execution host](BACnet.Protocol.ObjectExecution.Lifecycle.html#module-object-execution-host)
  supplies the device's current local time in the `now` field of
  `BACnet.Protocol.ObjectExecution.Context`.

  `local_date`, `local_time`, `utc_offset` and `daylight_savings_status` are sampled
  on demand. The offset uses standard time in minutes west of UTC. The daylight
  savings status reflects the separate daylight saving adjustment.
  For each requested property, the host can call
  `BACnet.Protocol.ObjectExecution.Lifecycle.prepare_read/2` with its
  `:property_read` trigger and use `get_property/2` on the returned object. The host
  can reuse the same `now` sample when reading several clock properties together.
  Hosts that read without lifecycle execution can invoke the existing
  `:on_read_function` callbacks for `local_date` and `local_time`. Those callbacks
  sample the system clock using the stored `utc_offset`.

  To record a database change, restore or restart, the host needs to execute with
  `:periodic` and pass a `t:device_event/0` as the `:device_event` context option.
  The host supplies each event once, after the corresponding operation succeeds.
  Database events and completed restores increment `database_revision`.
  Creating or deleting temporary configuration files during backup or restore leaves
  the revision unchanged. Ordinary property writes also leave it unchanged.
  A completed restore updates `last_restore_time` when selected.

  A completed restart updates `last_restart_reason` and `time_of_device_restart`
  when selected. With `supports_restart: true`, the recipient list defaults to a
  local broadcast. An empty list suppresses the notification. The host needs to
  supply the final `system_status` before calling
  `restart_notification/1` on the updated object. It can then send the returned
  notification to the listed recipients. MS/TP slave devices cannot send this
  notification.

  #### Periodic time synchronization

  A positive `time_synchronization_interval` and at least one nonempty recipient
  list enable periodic synchronization. The interval is measured in minutes. With
  `align_intervals` enabled, intervals that divide an hour or a day align to local
  clock boundaries, shifted by `interval_offset` modulo the interval. Other intervals
  use elapsed time.

  The host needs to retain each execution result's state and use its wakeup for
  timer delivery. It needs to provide the device's timezone database and deliver
  `:clock_change` when changing the local clock or timezone. At each due `:timer`
  or `:periodic` execution, `time_synchronization_requests/1` returns the requests
  prepared for that step. The host needs to send them once after committing that
  result. It resolves the recipient addresses and handles any delivery failures.

  #### Device-wide responsibilities

  The host owns the device clock, including initialization when no clock is available,
  and applies incoming `BACnet.Protocol.Services.TimeSynchronization` and
  `BACnet.Protocol.Services.UtcTimeSynchronization` requests to it. It also owns
  the object registry, address bindings and COV subscriptions. It needs to keep
  `object_list`, `structured_object_list` and `active_cov_subscriptions` current
  and commit database events with the corresponding registry changes.

  The host carries out reinitialization and the backup and restore procedures, including
  authentication and persistence. It also needs to apply changes to live settings such
  as APDU timeouts, retry counts and MS/TP parameters to the corresponding stack or transport
  components. For MS/TP, it needs to mirror `max_master` and `max_info_frames`
  from the enabled MS/TP Network Port with the lowest instance number.

  Slave proxy properties are available on local objects created with a revision below 19.
  A host supporting them needs to implement the proxy functionality.

  ### Examples

  Creating a basic local Device object.

      iex> {:ok, dev} = BACnet.Protocol.ObjectTypes.Device.create(123, "My BACnet Device", %{
      ...>   vendor_name: "Example Inc.",
      ...>   vendor_identifier: 999,
      ...>   model_name: "Demo Controller",
      ...>   segmentation_supported: :no_segmentation
      ...> })
      iex> dev.object_name
      "My BACnet Device"

  Sampling the clock before serving a read, then recording a committed object creation.

      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> alias BACnet.Protocol.ObjectTypes.Device
      iex> {:ok, device} = Device.create(1, "Controller", %{
      ...>   vendor_identifier: 999,
      ...>   segmentation_supported: :no_segmentation
      ...> })
      iex> now = ~U[2026-06-01 12:15:00Z]
      iex> read = Context.new({:property_read, :local_time, nil}, now: now)
      iex> {:ok, refreshed} = Lifecycle.prepare_read(device, read)
      iex> {:ok, time} = Device.get_property(refreshed.object, :local_time)
      iex> time.hour
      12
      iex> created = Context.new(:periodic,
      ...>   now: now, state: refreshed.state,
      ...>   options: [device_event: {:database_change, :object_created}]
      ...> )
      iex> {:ok, changed} = Lifecycle.execute(refreshed.object, created)
      iex> changed.object.database_revision == device.database_revision + 1
      true

  Recording a completed restart when notifications are disabled.

      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> alias BACnet.Protocol.ObjectTypes.Device
      iex> {:ok, device} = Device.create(1, "Controller", %{
      ...>   vendor_identifier: 999,
      ...>   restart_notification_recipients: [],
      ...>   segmentation_supported: :no_segmentation
      ...> }, supports_restart: true)
      iex> restart = Context.new(:periodic,
      ...>   now: ~U[2026-06-01 12:15:00Z],
      ...>   options: [device_event: {:restart_completed, :warmstart}]
      ...> )
      iex> {:ok, restarted} = Lifecycle.execute(device, restart)
      iex> Device.get_property(restarted.object, :last_restart_reason)
      {:ok, :warmstart}
      iex> Device.restart_notification(restarted.object)
      {:ok, nil}

  Driving periodic synchronization from a monotonic deadline. The second context
  represents timer delivery after the host has committed the initialization result.
  See `BACnet.Protocol.ObjectExecution.Lifecycle` for timer management examples.

      iex> alias BACnet.Protocol.{ObjectIdentifier, Recipient}
      iex> alias BACnet.Protocol.ObjectExecution.{Context, Lifecycle}
      iex> alias BACnet.Protocol.ObjectTypes.Device
      iex> recipient = %Recipient{
      ...>   type: :device, device: %ObjectIdentifier{type: :device, instance: 42}, address: nil
      ...> }
      iex> {:ok, device} = Device.create(1, "Controller", %{
      ...>   vendor_identifier: 999,
      ...>   segmentation_supported: :no_segmentation,
      ...>   time_synchronization_interval: 5,
      ...>   time_synchronization_recipients: [recipient]
      ...> })
      iex> start = Context.new(:initialization,
      ...>   now: ~U[2026-06-01 12:00:00Z], monotonic_time: 0
      ...> )
      iex> {:ok, initialized} = Lifecycle.execute(device, start)
      iex> initialized.next_execution.monotonic_time
      300000
      iex> timer = Context.new(:timer,
      ...>   now: ~U[2026-06-01 12:05:00Z], monotonic_time: 300_000, state: initialized.state
      ...> )
      iex> {:ok, due} = Lifecycle.execute(initialized.object, timer)
      iex> [{^recipient, %BACnet.Protocol.Services.TimeSynchronization{time: time}}] =
      ...>   Device.time_synchronization_requests(due)
      iex> time.minute
      5

  ### See Also
  - `BACnet.Protocol.Services.ReinitializeDevice`
  - `BACnet.Protocol.Services.TimeSynchronization`
  - `BACnet.Protocol.Services.UtcTimeSynchronization`
  - `BACnet.Stack.Client`
  - `BACnet.Stack.Segmentator`
  - `BACnet.Stack.SegmentsStore`
  - `BACnet.Stack.Transport.MstpTransport`
  """

  alias BACnet.Protocol.AddressBinding
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.BACnetTimestamp
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.CovSubscription
  alias BACnet.Protocol.Device.ObjectTypesSupported
  alias BACnet.Protocol.Device.ServicesSupported
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectsUtility.Internal
  alias BACnet.Protocol.PropertyValue
  alias BACnet.Protocol.Recipient
  alias BACnet.Protocol.RecipientAddress
  alias BACnet.Protocol.Services.TimeSynchronization
  alias BACnet.Protocol.Services.UnconfirmedCovNotification
  alias BACnet.Protocol.Services.UtcTimeSynchronization

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Device object.

  In addition to the common options, Device supports:
  - `supports_backup_restore` - Enables the full set of backup/restore properties.
  - `supports_restart` - Selects the restart reason, timestamp, and recipient properties.
  """
  @type object_opts ::
          {:supports_backup_restore, boolean()}
          | {:supports_restart, boolean()}
          | common_object_opts()

  @typedoc """
  A change reported by the host after the corresponding operation completes.
  """
  @type device_event ::
          {:database_change,
           :object_created
           | :object_deleted
           | :object_name_changed
           | :object_identifier_changed
           | :temporary_configuration_file_created
           | :temporary_configuration_file_deleted}
          | :restore_completed
          | {:restart_completed, Constants.restart_reason()}

  @typedoc """
  A recipient and the time synchronization service request to send to it.
  """
  @type time_sync_request ::
          {recipient :: Recipient.t(),
           request :: TimeSynchronization.t() | UtcTimeSynchronization.t()}

  @typep time_sync_schedule ::
           {interval_ms :: pos_integer(), offset_minutes :: non_neg_integer() | nil}

  @typep time_sync_state :: %{
           schedule: time_sync_schedule(),
           wakeup: Wakeup.t(),
           requests: [time_sync_request()]
         }

  @typedoc """
  Represents a Device object. Treat struct fields as read-only. Use the object module's
  property functions to build updates.

  UTC Offset is positive for western hemisphere and negative for eastern hemisphere in minutes,
  i.e. UTC+2 is -120.

  Many properties have implicit relationships (e.g. `last_restart_reason` implies
  `time_of_device_restart`). Some properties that participate in such relationships
  do not carry a default value and must be explicitly set when creating the object.
  """
  bac_object Constants.macro_assert_name(:object_type, :device) do
    services(intrinsic: false)

    field(:description, String.t())
    field(:location, String.t())
    field(:serial_number, String.t(), readonly: true)

    field(:vendor_name, String.t(), required: true, readonly: true, default: "")
    field(:vendor_identifier, ApplicationTags.unsigned16(), required: true, readonly: true)
    field(:model_name, String.t(), required: true, readonly: true, default: "bacstack-ex")

    field(:firmware_revision, String.t(),
      required: true,
      readonly: true,
      default: "bacstack-ex v#{BACstack.MixProject.project()[:version]}"
    )

    field(:application_software_version, String.t(),
      required: true,
      readonly: true,
      default: "bacstack-ex v#{BACstack.MixProject.project()[:version]}"
    )

    field(:system_status, Constants.device_status(),
      required: true,
      readonly: true,
      default: :operational
    )

    # Database Revision: This property is incremented when an object is mutated (added/modified/deleted)
    # or a restore happened
    # The creation and deletion of temporary configuration files during a backup or
    # restore procedure does not affect this property
    field(:database_revision, non_neg_integer(), required: true, readonly: true, default: 1)

    # Protocol Version: 1
    field(:protocol_version, non_neg_integer(), required: true, readonly: true, default: 1)

    # Protocol Revision: 0 = Property is absent (implementation prior to the first protocol revision!)
    field(:protocol_revision, non_neg_integer(), required: true, readonly: true, default: 0)

    field(:protocol_services_supported, ServicesSupported.t(),
      required: true,
      readonly: true,
      default: %ServicesSupported{}
    )

    field(:protocol_object_types_supported, ObjectTypesSupported.t(),
      required: true,
      readonly: true,
      default: %ObjectTypesSupported{}
    )

    field(:object_list, BACnetArray.t(ObjectIdentifier.t()),
      required: true,
      readonly: true,
      default: BACnetArray.new()
    )

    # Structured Object List: Only object identifiers for Structured View and Life Safety Zone objects
    field(:structured_object_list, BACnetArray.t(ObjectIdentifier.t()),
      readonly: true,
      default: BACnetArray.new()
    )

    field(:device_address_binding, [AddressBinding.t()], required: true, default: [])

    field(:apdu_timeout, non_neg_integer(), required: true, readonly: true, default: 3000)
    field(:number_of_apdu_retries, non_neg_integer(), required: true, readonly: true, default: 3)

    field(:max_apdu_length_accepted, 50..1476,
      required: true,
      readonly: true,
      default: Constants.macro_by_name(:max_apdu_length_accepted_value, :octets_1476)
    )

    field(:segmentation_supported, Constants.segmentation(),
      required: true,
      readonly: true
    )

    # Properties for when segmentation is supported in any way
    field(:apdu_segment_timeout, non_neg_integer(),
      readonly: true,
      annotation: [required_when: {:property, :segmentation_supported, :!=, :no_segmentation}]
    )

    field(:max_segments_accepted, non_neg_integer(),
      readonly: true,
      annotation: [required_when: {:property, :segmentation_supported, :!=, :no_segmentation}]
    )

    # Properties for when the device is capable of tracking date and time
    field(:local_date, BACnetDate.t(),
      readonly: true,
      init_fun: &Internal.init_fun_local_date/0,
      annotation: [on_read_function: &update_local_date/1]
    )

    field(:local_time, BACnetTime.t(),
      readonly: true,
      init_fun: &Internal.init_fun_local_time/0,
      annotation: [on_read_function: &update_local_time/1]
    )

    # Properties for COV reporting service
    field(:active_cov_subscriptions, [CovSubscription.t()], readonly: true, default: [])

    # Properties for (Utc)TimeSynchronization service
    field(:time_synchronization_interval, non_neg_integer(),
      default: 0,
      implicit_relationship: :interval_offset
    )

    field(:time_synchronization_recipients, [Recipient.t()],
      default: [],
      implicit_relationship: :interval_offset
    )

    field(:utc_time_synchronization_recipients, [Recipient.t()],
      default: [],
      implicit_relationship: :interval_offset
    )

    field(:align_intervals, boolean(), default: false, implicit_relationship: :interval_offset)
    field(:interval_offset, non_neg_integer(), default: 0)

    field(:utc_offset, integer(), readonly: true, default: 0)
    field(:daylight_savings_status, boolean(), readonly: true, default: false)

    # Properties for execution of restart procedure (Clause 19.3)
    field(:last_restart_reason, Constants.restart_reason(),
      readonly: true,
      default: :unknown,
      implicit_relationship: :time_of_device_restart,
      annotation: [required_when: &restart_properties_required?/2]
    )

    field(:time_of_device_restart, BACnetTimestamp.t(),
      readonly: true,
      default: ObjectsMacro.get_default_bacnet_timestamp(),
      annotation: [required_when: &restart_properties_required?/2]
    )

    field(:restart_notification_recipients, [Recipient.t()],
      default: fn ->
        [
          %Recipient{
            type: :address,
            device: nil,
            address: %RecipientAddress{network: 0, address: :broadcast}
          }
        ]
      end,
      annotation: [required_when: {:opts, :supports_restart}]
    )

    # Properties for execution of backup and restore procedure (Clause 19.1)
    field(:configuration_files, BACnetArray.t(ObjectIdentifier.t()),
      readonly: true,
      implicit_relationship: :last_restore_time,
      annotation: [required_when: {:opts, :supports_backup_restore}]
    )

    field(:last_restore_time, BACnetTimestamp.t(),
      readonly: true,
      implicit_relationship: :backup_failure_timeout,
      annotation: [required_when: {:opts, :supports_backup_restore}]
    )

    field(:backup_failure_timeout, ApplicationTags.unsigned16(),
      readonly: true,
      implicit_relationship: :backup_preparation_time,
      annotation: [required_when: {:opts, :supports_backup_restore}]
    )

    field(:backup_preparation_time, ApplicationTags.unsigned16(),
      readonly: true,
      implicit_relationship: :restore_preparation_time,
      annotation: [required_when: {:opts, :supports_backup_restore}]
    )

    field(:restore_preparation_time, ApplicationTags.unsigned16(),
      readonly: true,
      implicit_relationship: :restore_completion_time,
      annotation: [required_when: {:opts, :supports_backup_restore}]
    )

    field(:restore_completion_time, ApplicationTags.unsigned16(),
      readonly: true,
      implicit_relationship: :backup_and_restore_state,
      annotation: [required_when: {:opts, :supports_backup_restore}]
    )

    field(:backup_and_restore_state, Constants.backup_state(),
      readonly: true,
      annotation: [required_when: {:opts, :supports_backup_restore}]
    )

    # Properties for slave proxy functionality (per-se not provided by this bacstack)
    # Slave proxy functionality was removed in ASHRAE 135-2016 (protocol revision 19)
    field(:slave_proxy_enable, BACnetArray.t(boolean()),
      implicit_relationship: :auto_slave_discovery,
      annotation: [forbidden_when: {:opts, :revision, :>=, 19}]
    )

    field(:auto_slave_discovery, BACnetArray.t(boolean()),
      implicit_relationship: :slave_address_binding,
      annotation: [forbidden_when: {:opts, :revision, :>=, 19}]
    )

    field(:slave_address_binding, [AddressBinding.t()],
      default: [],
      implicit_relationship: :manual_slave_address_binding,
      annotation: [forbidden_when: {:opts, :revision, :>=, 19}]
    )

    field(:manual_slave_address_binding, [AddressBinding.t()],
      default: [],
      annotation: [forbidden_when: {:opts, :revision, :>=, 19}]
    )

    # Properties for BACnet MS/TP master nodes
    field(:max_master, 1..127,
      readonly: true,
      implicit_relationship: :max_info_frames,
      bac_type: {:with_validator, :unsigned_integer, &(&1 >= 1 and &1 <= 127)}
    )

    field(:max_info_frames, pos_integer(),
      readonly: true,
      bac_type: {:with_validator, :unsigned_integer, &(&1 >= 1)}
    )

    # Virtual Terminal properties (not supported by this bacstack)
    # :vt_classes_supported, [BACnetVtClass.t()]
    # :active_vt_sessions, [BACnetVtSession.t()]
  end

  @database_changes [
    :object_created,
    :object_deleted,
    :object_name_changed,
    :object_identifier_changed
  ]

  @temporary_file_changes [
    :temporary_configuration_file_created,
    :temporary_configuration_file_deleted
  ]

  @impl BACnet.Protocol.ObjectsBehaviour
  @spec validate_execution(t(), Context.t()) :: :ok | {:error, term()}
  def validate_execution(object, context)

  def validate_execution(%__MODULE__{_metadata: %{remote_object: remote}}, %Context{})
      when not is_nil(remote), do: :ok

  def validate_execution(%__MODULE__{} = object, %Context{} = context) do
    with {:ok, event} <- execution_event(context) do
      validate_clock(object, context, event)
    end
  end

  @impl BACnet.Protocol.ObjectsBehaviour
  @spec execute(t(), Context.t()) :: {:ok, Result.t(t())} | {:error, term()}
  def execute(object, context)

  def execute(%__MODULE__{_metadata: %{remote_object: remote}} = object, %Context{} = context)
      when not is_nil(remote), do: super(object, context)

  def execute(%__MODULE__{} = object, %Context{} = context) do
    with {:ok, event} <- execution_event(context),
         :ok <- validate_clock(object, context, event),
         {:ok, state} <- time_sync_step(object, context, time_sync_schedule(object)) do
      updated =
        object
        |> refresh_clock(context)
        |> apply_device_event(event, context.now)

      {:ok, %Result{object: updated, state: state, next_execution: state && state.wakeup}}
    end
  end

  @doc """
  Builds the Clause 19.3 notification and recipient list from the completed restart state.

  Returns `{:ok, nil}` if the recipient property is absent or empty. The host needs
  to call this after the restart and final system status update, and send the request
  to each returned recipient. Calling this function performs no network I/O.
  """
  @spec restart_notification(t()) ::
          {:ok, {recipients :: [Recipient.t()], notification :: UnconfirmedCovNotification.t()}}
          | {:ok, nil}
          | {:error, term()}
  def restart_notification(object)

  def restart_notification(%__MODULE__{_metadata: %{remote_object: remote}})
      when not is_nil(remote),
      do: {:error, :operation_not_available_for_remote_objects}

  def restart_notification(%__MODULE__{restart_notification_recipients: recipients})
      when recipients in [nil, []], do: {:ok, nil}

  def restart_notification(%__MODULE__{} = object) do
    identifier = get_object_identifier(object)

    with {:ok, status} <- notification_value(object, identifier, :system_status),
         {:ok, time} <- notification_value(object, identifier, :time_of_device_restart),
         {:ok, reason} <- notification_value(object, identifier, :last_restart_reason) do
      {:ok,
       {object.restart_notification_recipients,
        %UnconfirmedCovNotification{
          process_identifier: 0,
          initiating_device: identifier,
          monitored_object: identifier,
          time_remaining: 0,
          property_values: [status, time, reason]
        }}}
    end
  end

  @doc """
  Returns the time synchronization requests produced by a single execution result.

  Only a due timer or periodic step produces requests. The returned service
  structures contain the local or UTC date and time sampled for that step.
  """
  @spec time_synchronization_requests(Result.t(t())) :: [time_sync_request()]
  def time_synchronization_requests(result)

  def time_synchronization_requests(%Result{
        object: %__MODULE__{_metadata: %{remote_object: nil}},
        state: %{requests: requests}
      }),
      do: requests

  def time_synchronization_requests(%Result{object: %__MODULE__{}}), do: []

  @spec time_sync_schedule(t()) :: time_sync_schedule() | nil
  defp time_sync_schedule(object) do
    interval = object[:time_synchronization_interval]

    if is_integer(interval) and interval > 0 and
         (object[:time_synchronization_recipients] not in [nil, []] or
            object[:utc_time_synchronization_recipients] not in [nil, []]) do
      offset =
        if object[:align_intervals] == true and rem(1440, interval) == 0,
          do: rem(object[:interval_offset] || 0, interval)

      {interval * 60_000, offset}
    end
  end

  @spec time_sync_step(t(), Context.t(), time_sync_schedule() | nil) ::
          {:ok, time_sync_state() | nil} | {:error, term()}
  defp time_sync_step(object, context, schedule)

  defp time_sync_step(_object, _context, nil), do: {:ok, nil}

  defp time_sync_step(
         object,
         %Context{state: %{schedule: schedule, wakeup: %Wakeup{} = wakeup}} = context,
         schedule
       )
       when context.trigger != :initialization do
    cond do
      context.trigger == :clock_change and wakeup.wall_time != nil ->
        schedule_time_sync(context, schedule, [])

      context.trigger in [:timer, :periodic] and Wakeup.due?(wakeup, context) ->
        with {:ok, requests} <- build_time_sync_requests(object, context.now) do
          schedule_time_sync(context, schedule, requests)
        end

      true ->
        {:ok, %{schedule: schedule, wakeup: wakeup, requests: []}}
    end
  end

  defp time_sync_step(_object, context, schedule), do: schedule_time_sync(context, schedule, [])

  @spec schedule_time_sync(Context.t(), time_sync_schedule(), [time_sync_request()]) ::
          {:ok, time_sync_state()} | {:error, term()}
  defp schedule_time_sync(context, schedule, requests)

  defp schedule_time_sync(context, {interval_ms, nil} = schedule, requests) do
    wakeup = %Wakeup{wall_time: nil, monotonic_time: context.monotonic_time + interval_ms}
    {:ok, %{schedule: schedule, wakeup: wakeup, requests: requests}}
  end

  defp schedule_time_sync(context, {interval_ms, offset_minutes} = schedule, requests) do
    period_us = interval_ms * 1_000
    offset_us = offset_minutes * 60_000_000

    with {:ok, wall_time} <-
           next_aligned_time(context.now, context.timezone_database, period_us, offset_us) do
      wakeup = %Wakeup{wall_time: wall_time, monotonic_time: nil}
      {:ok, %{schedule: schedule, wakeup: wakeup, requests: requests}}
    end
  end

  @spec next_aligned_time(DateTime.t(), module(), pos_integer(), non_neg_integer()) ::
          {:ok, DateTime.t()} | {:error, term()}
  defp next_aligned_time(now, database, period_us, offset_us) do
    delay_us = period_us - Integer.mod(time_of_day_us(now) - offset_us, period_us)
    target = NaiveDateTime.add(DateTime.to_naive(now), delay_us, :microsecond)

    case DateTime.from_naive(target, now.time_zone, database) do
      {:ok, time} ->
        {:ok, time}

      {:ambiguous, first, second} ->
        {:ok, if(DateTime.compare(first, now) == :gt, do: first, else: second)}

      {:gap, _before_gap, after_gap} ->
        # The target is in a skipped part of local time. Include the first
        # representable instant after the gap if it is itself a boundary.
        if Integer.mod(time_of_day_us(after_gap) - offset_us, period_us) == 0 do
          {:ok, after_gap}
        else
          next_aligned_time(after_gap, database, period_us, offset_us)
        end

      {:error, reason} ->
        {:error, {:invalid_device_clock, reason}}
    end
  end

  @spec time_of_day_us(DateTime.t()) :: non_neg_integer()
  defp time_of_day_us(now) do
    (now.hour * 3600 + now.minute * 60 + now.second) * 1_000_000 + elem(now.microsecond, 0)
  end

  @spec build_time_sync_requests(t(), DateTime.t()) ::
          {:ok, [time_sync_request()]} | {:error, term()}
  defp build_time_sync_requests(object, now) do
    local = object[:time_synchronization_recipients] || []
    utc = object[:utc_time_synchronization_recipients] || []
    utc_now = DateTime.from_unix!(DateTime.to_unix(now, :microsecond), :microsecond)

    cond do
      local != [] and now.year not in 1900..2154 ->
        {:error, {:invalid_device_clock, :local_date}}

      utc != [] and utc_now.year not in 1900..2154 ->
        {:error, {:invalid_device_clock, :utc_date}}

      true ->
        {:ok,
         synchronization_requests(local, now, TimeSynchronization) ++
           synchronization_requests(utc, utc_now, UtcTimeSynchronization)}
    end
  end

  @spec synchronization_requests([Recipient.t()], DateTime.t(), module()) :: [time_sync_request()]
  defp synchronization_requests(recipients, now, service)

  defp synchronization_requests([], _now, _service), do: []

  defp synchronization_requests(recipients, now, service) do
    request =
      struct!(service,
        date: BACnetDate.from_date(DateTime.to_date(now)),
        time: BACnetTime.from_time(DateTime.to_time(now))
      )

    Enum.map(recipients, &{&1, request})
  end

  @spec restart_properties_required?(map(), map()) :: boolean()
  defp restart_properties_required?(properties, metadata) do
    metadata.other[:supports_restart] == true or
      Map.get(properties, :restart_notification_recipients) != nil
  end

  @spec notification_value(t(), ObjectIdentifier.t(), Constants.property_identifier()) ::
          {:ok, PropertyValue.t()} | {:error, term()}
  defp notification_value(object, identifier, property) do
    with {:ok, value} <- get_property(object, property),
         {:ok, encoding} <- ObjectsUtility.cast_value_to_property(identifier, property, value) do
      {:ok,
       %PropertyValue{
         property_identifier: property,
         property_array_index: nil,
         property_value: encoding,
         priority: nil
       }}
    end
  end

  @spec execution_event(Context.t()) ::
          {:ok, device_event() | nil} | {:error, :invalid_device_event}
  defp execution_event(context)

  defp execution_event(%Context{trigger: :periodic, options: options}) do
    case Keyword.get(options, :device_event) do
      nil ->
        {:ok, nil}

      {:database_change, change} = event
      when change in @database_changes or change in @temporary_file_changes ->
        {:ok, event}

      :restore_completed ->
        {:ok, :restore_completed}

      {:restart_completed, reason} = event when is_atom(reason) ->
        if match?({:ok, _code}, Constants.by_name(:restart_reason, reason)),
          do: {:ok, event},
          else: {:error, :invalid_device_event}

      _event ->
        {:error, :invalid_device_event}
    end
  end

  defp execution_event(%Context{}), do: {:ok, nil}

  @spec validate_clock(t(), Context.t(), device_event() | nil) :: :ok | {:error, term()}
  defp validate_clock(object, %Context{now: now, trigger: trigger}, event) do
    needs_date =
      (trigger == {:property_read, :local_date, nil} and has_property?(object, :local_date)) or
        (event == :restore_completed and has_property?(object, :last_restore_time)) or
        (match?({:restart_completed, _reason}, event) and
           has_property?(object, :time_of_device_restart))

    cond do
      needs_date and now.year not in 1900..2154 ->
        {:error, {:invalid_device_clock, :local_date}}

      trigger == {:property_read, :utc_offset, nil} and has_property?(object, :utc_offset) and
          (now.utc_offset not in -86_400..86_400 or rem(now.utc_offset, 60) != 0) ->
        {:error, {:invalid_device_clock, :utc_offset}}

      true ->
        :ok
    end
  end

  @spec refresh_clock(t(), Context.t()) :: t()
  defp refresh_clock(object, %Context{now: now, trigger: trigger}) do
    case trigger do
      {:property_read, :local_date, nil} ->
        refresh_timestamp_property(
          object,
          :local_date,
          now,
          &BACnetDate.from_date(DateTime.to_date(&1))
        )

      {:property_read, :local_time, nil} ->
        refresh_timestamp_property(
          object,
          :local_time,
          now,
          &BACnetTime.from_time(DateTime.to_time(&1))
        )

      {:property_read, :utc_offset, nil} ->
        put_selected(object, :utc_offset, -div(now.utc_offset, 60))

      {:property_read, :daylight_savings_status, nil} ->
        put_selected(object, :daylight_savings_status, now.std_offset != 0)

      _other ->
        object
    end
  end

  @spec apply_device_event(t(), device_event() | nil, DateTime.t()) :: t()
  defp apply_device_event(object, event, now)

  defp apply_device_event(object, {:database_change, change}, _now)
       when change in @database_changes do
    %{object | database_revision: object.database_revision + 1}
  end

  defp apply_device_event(object, :restore_completed, now) do
    revised = %{object | database_revision: object.database_revision + 1}
    refresh_timestamp_property(revised, :last_restore_time, now, &timestamp/1)
  end

  defp apply_device_event(object, {:restart_completed, reason}, now) do
    object
    |> put_selected(:last_restart_reason, reason)
    |> refresh_timestamp_property(:time_of_device_restart, now, &timestamp/1)
  end

  defp apply_device_event(object, _event, _now), do: object

  @spec refresh_timestamp_property(
          t(),
          Constants.property_identifier(),
          DateTime.t(),
          (DateTime.t() -> BACnetDate.t() | BACnetTime.t() | BACnetTimestamp.t())
        ) :: t()
  defp refresh_timestamp_property(object, property, now, convert) do
    if has_property?(object, property), do: %{object | property => convert.(now)}, else: object
  end

  @spec put_selected(t(), Constants.property_identifier(), term()) :: t()
  defp put_selected(object, property, value) do
    if has_property?(object, property), do: %{object | property => value}, else: object
  end

  @spec timestamp(DateTime.t()) :: BACnetTimestamp.t()
  defp timestamp(now) do
    %BACnetTimestamp{
      type: :datetime,
      time: nil,
      sequence_number: nil,
      datetime: BACnetDateTime.from_datetime(now)
    }
  end

  @external_resource BACstack.MixProject.get_vendor_ids_csv_file()
  @vendor_ids BACstack.MixProject.get_vendor_ids()

  # Dialyzer is so hecking stupid - go love yourself with your stupid opaqueness contracts
  @dialyzer {:nowarn_function, get_vendor_ids: 0, get_vendor_ids_arr: 0, map_vendor_to_name: 1}

  @spec get_vendor_ids_arr() :: :array.array(String.t())
  defp get_vendor_ids_arr(), do: @vendor_ids

  @doc """
  Get the list of known vendor IDs to vendor names.

  > #### Implementation Detail {: .info}
  > Internally the vendor IDs mapping is represented as an erlang array
  > and will be converted to a map. If you use this map multiple times in a row,
  > consider storing it in a variable as the conversion can be computational heavy.
  """
  @spec get_vendor_ids() :: %{optional(non_neg_integer()) => String.t()}
  def get_vendor_ids() do
    get_vendor_ids_arr()
    |> :array.sparse_to_orddict()
    |> Map.new()
  end

  @spec map_vendor_to_name(non_neg_integer()) :: String.t()
  defp map_vendor_to_name(id)

  defp map_vendor_to_name(id) when is_integer(id) and id >= 0 do
    :array.get(id, get_vendor_ids_arr())
  end

  defp map_vendor_to_name(_id), do: ""

  @spec update_local_date(t()) :: {:ok, t()} | {:error, term()}
  defp update_local_date(%__MODULE__{} = obj) do
    # Maybe we want to use DateTime.now/1 with the correct TimeZone? (the configured default)
    # We use DateTime instead of Date so when shifting the time, we get the correct date
    update_property(
      obj,
      :local_date,
      BACnetDate.from_date(
        DateTime.to_date(DateTime.add(DateTime.utc_now(), -(obj[:utc_offset] || 0), :minute))
      )
    )
  end

  @spec update_local_time(t()) :: {:ok, t()} | {:error, term()}
  defp update_local_time(%__MODULE__{} = obj) do
    # Maybe we want to use DateTime.now/1 with the correct TimeZone? (the configured default)
    update_property(
      obj,
      :local_time,
      BACnetTime.from_time(Time.add(Time.utc_now(), -(obj[:utc_offset] || 0), :minute))
    )
  end

  @spec inhibit_object_check(
          t(),
          t() | nil,
          ObjectOperations.property_operation(),
          ObjectOperations.property_operation_args()
        ) :: {:ok, t()}
  defp inhibit_object_check(obj, _original, _operation, _args) do
    # Only patch vendor name if empty
    if obj.vendor_name == "" do
      new_obj = %{obj | vendor_name: map_vendor_to_name(obj.vendor_identifier)}
      {:ok, new_obj}
    else
      {:ok, obj}
    end
  end
end
