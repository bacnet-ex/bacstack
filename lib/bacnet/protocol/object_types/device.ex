defmodule BACnet.Protocol.ObjectTypes.Device do
  @moduledoc """
  The Device object is the single, mandatory root object that represents an entire
  BACnet device on the network. Every BACnet device contains exactly one Device
  object whose `object_identifier` is also used as the device's unique address within
  the BACnet internetwork.

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

  The Device object is the single source of truth for everything a remote BACnet
  client needs to know about this device and is the only object that must exist in
  every BACnet device. It is the target of Who-Is/I-Am, the source of the object
  list(s), protocol capability flags, and many operational parameters.

  Most properties are maintained by a combination of:
  - static configuration (vendor name, model, protocol revision, etc.)
  - dynamic state maintained by the stack (`database_revision`, `last_restart_reason`,
    active COV subscriptions, etc.)
  - time-keeping and OS services (local time, `utc_offset`, daylight savings status)
  - the application / device server (`object_list`, `structured_object_list`, backup/restore
    state, many configuration properties).

  Several properties have side effects or must be kept in sync with lower layers
  (APDU timeouts, MS/TP token parameters, time synchronisation settings, etc.).
  Many of its properties are writable and changes must be acted upon by the device server.

  ### Developer Implementation Notes (geared to device server / application authors)

  The generated code handles storage + basic mechanics (validation, implicit_relationships,
  readonly annotations as hints to your server, etc.). **You must drive "special" live
  properties and side effects yourself** via `update_property/3` (never direct mutation).
  Read notes below + generated tables for details.

  **Special / live properties and expected developer behaviour**

  The Device has many "global live" properties that must be kept in sync with the
  running stack, OS, config, etc. (more than any other object).

  - `local_time`, `local_date`:
    **Dev must**: Ensure your read path call the annotation functions, which return
    current wall time (respect utc_offset, DST).

  - `utc_offset`, `daylight_savings_status`:
    Writes to `utc_offset` / `daylight_savings_status` must be pushed
    to OS or time sync layer.

  - `database_revision`: Bumped on object db changes.
    **Dev must**: Every time you add/remove object, change an object's name,
    change an object's identifier, or a restore is performed, increment this.
    The creation and deletion of temporary configuration files during a restore,
    does not change this property.

  - `active_cov_subscriptions`: Live subscription state.
    **Dev must**: Your COV subscription manager (on SubscribeCOV success/expire,
    resub etc.) must add/remove entries here via `update_property/3`.

  - `apdu_timeout`, `number_of_apdu_retries`, MS/TP properties (`max_info_frames`, etc.),
    time sync properties, backup/restore state machine properties, `object_list`, etc.:
    Many are readonly or have side effects.
    **Dev must**: On writes (where allowed), propagate to the APDU layer, MS/TP
    driver, time sync engine, flash/backup routines.

  - `last_restart_reason`, `time_of_device_restart`, `restart_notification_*`:
    **Dev must**: Set by reinitialize/powerup code. Can emit notifications.

  - Vendor/model, protocol version/revision, max APDU etc.: Mostly static, set at
    startup from your build/config.

  - `time_synchronization_interval` etc. + recipients: For periodic time sync.
    **Dev must**: Your time sync task uses these.

  See the "You are the 'god object'" section and specific bullets below (backup/restore,
  object_list, special write propagation, COV subs, restart, on_read for time, etc).

  The Device object is special: it is both a normal BACnet object *and* the
  container for a huge amount of device-wide state and configuration that the
  rest of the stack (APDU timers, BVLL, MS/TP token passing, time, backup/restore,
  COV subscription database, etc.) needs.

  **You are the "god object" for the device**: Almost every interesting piece of
  global state eventually appears as a property on the Device object (or is
  reachable from its `object_list` / `structured_object_list`). Your device server
  must keep these properties in sync with the lower layers:

  - `apdu_timeout`, `number_of_apdu_retries` - changes must be propagated to the
    `BACnet.Stack.Client` and `BACnet.Stack.Segmentator` and partially to
    `BACnet.Stack.SegmentsStore`.
  - `max_info_frames`, `max_master` (for MS/TP) - changes must be propagated to the
    `BACnet.Stack.Transport.MstpTransport`. Properties must not be present if no
    MS/TP transport is used.
  - `auto_slave_discovery`, `slave_proxy_enable`, `manual_slave_address_binding`,
    `slave_address_binding` - used for a slave proxy (must be implemented by the user.
  - All the time-related properties (`utc_offset`, `daylight_savings_status`) -
    Writes to `utc_offset` or DST status usually have to be pushed into
    the OS or into the time-sync state machine.
  - `active_cov_subscriptions` - this is a live list that the COV manager
    appends to / removes from when SubscribeCOV / SubscribeCOVProperty
    operations succeed or subscriptions expire.
  - `database_revision` - you must bump it every time the set of objects or
    their configuration changes.
  - Backup/restore properties (see Clause 19.1) - the whole state machine
    (backup_state, backup_preparation_time, restore_preparation_time,
    backup_and_restore_state, last_restore_time, …) must be driven by your
    backup/restore service implementation.
  - `object_list` and `structured_object_list` - Must be kept up to date with
    all "live" objects in the device.

  **Special write propagation**: When a client writes certain Device properties
  your write handler must not only store the new value in the object but also
  push the value into the running system.

  **last_restart_reason, time_of_device_restart, restart_notification**: These
  are written by the reinitialize / power-up code. A cold boot or a
  ReinitializeDevice "warmstart" / "coldstart" must update them and emits an
  unconfirmed COV notification on the Device object, if the property list
  `restart_notification_recipients` is not empty. See Clause 19.3.

  **COV subscriptions on the Device object itself**: Because so many global
  things (database_revision, active_cov_subscriptions, time, etc.) live here,
  clients often subscribe to COVs on the Device object to be told when
  "something interesting about the whole device changed".

  **Remote Device objects**: When you discover another device you can create a
  "shadow" Device object (done by `BACnet.Stack.ClientHelper.read_object/4`)
  that reflects what you last read from it.

  **The `object_list` / `structured_object_list` are special**: When a new object
  is created or deleted, you must make sure that any cached view is invalidated
  and that `database_revision` is bumped.

  **ReinitializeDevice service**: This service is the official way to ask a
  device to reboot. Your handler for it will typically:
  1. Validate the password, if one is configured on the Device object.
  2. Set the appropriate `last_restart_reason`.
  3. Persist any "about to restart" state.
  4. Actually restart the Erlang VM / the device itself / etc.

  The long list under "Special Considerations for Device Server Implementors"
  in this moduledoc (and the corresponding tables in the generated part) is
  deliberately there to remind you of all the places where a write to the
  Device object has to do something outside the object store.

  See also the various service modules (TimeSynchronization,
  DeviceCommunicationControl, ReinitializeDevice, Backup/Restore support, …) -
  they all ultimately read or write properties that live on the Device object.

  ### Special Considerations for Device Server Implementors

  Several Device properties require special handling by the BACnet device server
  (or the application using this library) on write:

  - `active_cov_subscriptions`
  - `apdu_timeout` (propagation on write)
  - `auto_slave_discovery`
  - `daylight_savings_status` (auto update on DST and propagation to `utc_offset`)
  - `device_address_binding`
  - `manual_slave_address_binding`
  - `max_info_frames` (marked readonly; recommended default `1` for MS/TP)
  - `max_master` (marked readonly; recommended default `127` for MS/TP)
  - `number_of_apdu_retries` (propagation on write)
  - `object_list`
  - `slave_address_binding`
  - `slave_proxy_enable`
  - `structured_object_list`
  - `utc_offset` (when handling UTC time synchronisation)
  - All Backup/Restore related properties (Clause 19.1)
  - All (UTC) Time Synchronisation related properties

  Propagation of certain values (e.g. MS/TP parameters to the transport layer)
  is the responsibility of the device server or application code.

  ### Examples

  Creating a basic local Device object:

      iex> {:ok, dev} = BACnet.Protocol.ObjectTypes.Device.create(123, "My BACnet Device", %{
      ...>   vendor_name: "Example Inc.",
      ...>   vendor_identifier: 999,
      ...>   model_name: "Demo Controller",
      ...>   segmentation_supported: :no_segmentation
      ...> }); dev.object_name
      "My BACnet Device"

  Enabling restart support (the option makes additional properties required/available):

      iex> {:ok, dev} = BACnet.Protocol.ObjectTypes.Device.create(1, "Dev1", %{
      ...>   vendor_identifier: 999,
      ...>   restart_notification_recipients: [],
      ...>   segmentation_supported: :no_segmentation
      ...> }, supports_restart: true)
      iex> is_list(dev.restart_notification_recipients)
      true

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
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.BACnetTimestamp
  alias BACnet.Protocol.Constants
  alias BACnet.Protocol.CovSubscription
  alias BACnet.Protocol.Device.ObjectTypesSupported
  alias BACnet.Protocol.Device.ServicesSupported
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.ObjectsUtility.Internal
  alias BACnet.Protocol.Recipient

  require Constants
  use ObjectsMacro

  @typedoc """
  Options accepted when creating or configuring a Device object.

  In addition to the common options, Device supports:
  - `supports_backup_restore` - Enables the full set of backup/restore properties.
  - `supports_restart` - Enables restart notification recipient properties.
  """
  @type object_opts ::
          {:supports_backup_restore, boolean()}
          | {:supports_restart, boolean()}
          | common_object_opts()

  @typedoc """
  Represents a Device object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.

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
      implicit_relationship: :time_of_device_restart
    )

    field(:time_of_device_restart, BACnetTimestamp.t(),
      readonly: true,
      default: ObjectsMacro.get_default_bacnet_timestamp(),
      implicit_relationship: :restart_notification_recipients
    )

    field(:restart_notification_recipients, [Recipient.t()],
      default: [],
      annotation: [required_when: &(is_map(&1) and &2[:supports_restart] == true)]
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
    field(:slave_proxy_enable, BACnetArray.t(boolean()),
      implicit_relationship: :auto_slave_discovery
    )

    field(:auto_slave_discovery, BACnetArray.t(boolean()),
      implicit_relationship: :slave_address_binding
    )

    field(:slave_address_binding, [AddressBinding.t()],
      default: [],
      implicit_relationship: :manual_slave_address_binding
    )

    field(:manual_slave_address_binding, [AddressBinding.t()], default: [])

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

  @spec inhibit_object_check(t()) :: {:ok, t()}
  defp inhibit_object_check(obj) do
    # Only patch vendor name if empty
    if obj.vendor_name == "" do
      new_obj = %{obj | vendor_name: map_vendor_to_name(obj.vendor_identifier)}
      {:ok, new_obj}
    else
      {:ok, obj}
    end
  end
end
