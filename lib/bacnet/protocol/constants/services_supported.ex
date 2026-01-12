defmodule BACnet.Protocol.Constants.ServicesSupported do
  @moduledoc false
  # Can be extended through env :bacstack, :additional_services_supported

  use ConstEnum, exception: BACnet.Protocol.Constants.ConstantError

  defconst(:services_supported, :acknowledge_alarm, 0x00)
  defconst(:services_supported, :confirmed_cov_notification, 0x01)
  defconst(:services_supported, :confirmed_event_notification, 0x02)
  defconst(:services_supported, :get_alarm_summary, 0x03)
  defconst(:services_supported, :get_enrollment_summary, 0x04)
  defconst(:services_supported, :subscribe_cov, 0x05)
  defconst(:services_supported, :atomic_read_file, 0x06)
  defconst(:services_supported, :atomic_write_file, 0x07)
  defconst(:services_supported, :add_list_element, 0x08)
  defconst(:services_supported, :remove_list_element, 0x09)
  defconst(:services_supported, :create_object, 0x0A)
  defconst(:services_supported, :delete_object, 0x0B)
  defconst(:services_supported, :read_property, 0x0C)
  defconst(:services_supported, :read_property_conditional, 0x0D)
  defconst(:services_supported, :read_property_multiple, 0x0E)
  defconst(:services_supported, :write_property, 0x0F)
  defconst(:services_supported, :write_property_multiple, 0x10)
  defconst(:services_supported, :device_communication_control, 0x11)
  defconst(:services_supported, :confirmed_private_transfer, 0x12)
  defconst(:services_supported, :confirmed_text_message, 0x13)
  defconst(:services_supported, :reinitialize_device, 0x14)
  defconst(:services_supported, :vt_open, 0x15)
  defconst(:services_supported, :vt_close, 0x16)
  defconst(:services_supported, :vt_data, 0x17)
  defconst(:services_supported, :authenticate, 0x18)
  defconst(:services_supported, :request_key, 0x19)
  defconst(:services_supported, :i_am, 0x1A)
  defconst(:services_supported, :i_have, 0x1B)
  defconst(:services_supported, :unconfirmed_cov_notification, 0x1C)
  defconst(:services_supported, :unconfirmed_event_notification, 0x1D)
  defconst(:services_supported, :unconfirmed_private_transfer, 0x1E)
  defconst(:services_supported, :unconfirmed_text_message, 0x1F)
  defconst(:services_supported, :time_synchronization, 0x20)
  defconst(:services_supported, :who_has, 0x21)
  defconst(:services_supported, :who_is, 0x22)
  defconst(:services_supported, :read_range, 0x23)
  defconst(:services_supported, :utc_time_synchronization, 0x24)
  defconst(:services_supported, :life_safety_operation, 0x25)
  defconst(:services_supported, :subscribe_cov_property, 0x26)
  defconst(:services_supported, :get_event_information, 0x27)
  defconst(:services_supported, :write_group, 0x28)
  defconst(:services_supported, :subscribe_cov_property_multiple, 0x29)
  defconst(:services_supported, :confirmed_cov_notification_multiple, 0x2A)
  defconst(:services_supported, :unconfirmed_cov_notification_multiple, 0x2B)

  defconst_extend_env(
    :services_supported,
    :bacstack,
    :additional_services_supported,
    &(&1 != nil and is_integer(&2) and &2 >= 0)
  )

  @doc false
  def get_constants() do
    @constants
  end
end
