defmodule BACnet.Protocol.ObjectTypes.Device do
  @moduledoc """
  The Device object type defines a standardized object whose properties represent
  the externally visible characteristics of a BACnet Device.
  There shall be exactly one Device object in each BACnet Device.
  A Device object is referenced by its Object_Identifier property,
  which is not only unique to the BACnet Device that maintains this object
  but is also unique throughout the BACnet internetwork.

  (ASHRAE 135 - Clause 12.11)
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

    # Database Revision: This property is incremented when an object is mutated (added/modified/deleted) or a restore happened
    # The creation and deletion of temporary configuration files during a backup or restore procedure does not affect this property
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
    field(:local_date, BACnetDate.t(), readonly: true, init_fun: &BACnetDate.utc_today/0)
    field(:local_time, BACnetTime.t(), readonly: true, init_fun: &BACnetTime.utc_now/0)

    # Properties for COV reporting service
    field(:active_cov_subscriptions, [CovSubscription.t()], readonly: true, default: [])

    # Properties for (Utc)TimeSynchronization service
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

    field(:max_info_frames, non_neg_integer(), readonly: true)

    # Virtual Terminal properties (not supported by this bacstack)
    # :vt_classes_supported, [BACnetVtClass.t()]
    # :active_vt_sessions, [BACnetVtSession.t()]
  end

  @external_resource BACstack.MixProject.get_vendor_ids_csv_file()
  @vendor_ids BACstack.MixProject.get_vendor_ids()

  @doc """
  Get the list of known vendor IDs to vendor names.
  """
  @spec get_vendor_ids() :: %{optional(non_neg_integer()) => String.t()}
  def get_vendor_ids() do
    @vendor_ids
  end

  @spec map_vendor_to_name(non_neg_integer) :: String.t()
  defp map_vendor_to_name(id) do
    Map.get(@vendor_ids, id, "")
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
