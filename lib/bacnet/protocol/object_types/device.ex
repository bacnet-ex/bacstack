defmodule BACnet.Protocol.ObjectTypes.Device do
  @moduledoc """
  The Device object type defines a standardized object whose properties represent
  the externally visible characteristics of a BACnet Device.
  There shall be exactly one Device object in each BACnet Device.
  A Device object is referenced by its Object_Identifier property,
  which is not only unique to the BACnet Device that maintains this object
  but is also unique throughout the BACnet internetwork.

  (ASHRAE 135 - Clause 12.11)

  For the following properties the BACnet device server needs to
  take special care of when other BACnet user read or write to them:
  - `active_cov_subscriptions`
  - `apdu_timeout` (propagation on write)
  - `auto_slave_discovery`
  - `device_address_binding`
  - `manual_slave_address_binding`
  - `max_info_frames` (marked as "readonly" and "default" value should be `1`)
    Propagation to the MS/TP Transport must be done by the BACnet device server
    or user of the library, if not implemented in the device server.
  - `max_master` (marked as "readonly" and "default" value should be `127`)
    Propagation to the MS/TP Transport must be done by the BACnet device server
    or user of the library, if not implemented in the device server.
  - `number_of_apdu_retries` (propagation on write)
  - `object_list`
  - `slave_address_binding`
  - `slave_proxy_enable`
  - `structured_object_list`
  - `utc_offset` (when handling UTC Time Synchronization)
  - All properties related to Backup/Restore
  - All properties related to (UTC) Time Synchronization
  """

  # TODO: Docs

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
  alias BACnet.Protocol.Recipient

  require Constants
  use ObjectsMacro

  @typedoc """
  Available object options.
  """
  @type object_opts ::
          {:supports_backup_restore, boolean()}
          | {:supports_restart, boolean()}
          | common_object_opts()

  @typedoc """
  Represents a Device object. All keys should be treated as read-only,
  all updates should go only through `update_property/3`.
  """
  bac_object Constants.macro_assert_name(:object_type, :device) do
    services(intrinsic: false)

    field(:description, String.t())
    field(:location, String.t())
    field(:serial_number, String.t())
    field(:profile_name, String.t())

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
      required: true,
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
      init_fun: &BACnetDate.utc_today/0,
      annotation: [on_read_function: &update_property(&1, :local_date, BACnetDate.utc_today())]
    )

    field(:local_time, BACnetTime.t(),
      readonly: true,
      init_fun: &BACnetTime.utc_now/0,
      annotation: [on_read_function: &update_property(&1, :local_time, BACnetTime.utc_now())]
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
    field(:interval_offset, String.t(), default: "")

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
