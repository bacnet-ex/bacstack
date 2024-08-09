defmodule BACnet.Protocol.Constants.ServicesSupported do
  @moduledoc false

  use BACnet.Macro, exception: BACnet.Protocol.Constants.ConstantError

  defconstant(:services_supported, :acknowledge_alarm, 0x00)
  defconstant(:services_supported, :confirmed_cov_notification, 0x01)
  defconstant(:services_supported, :confirmed_event_notification, 0x02)
  defconstant(:services_supported, :get_alarm_summary, 0x03)
  defconstant(:services_supported, :get_enrollment_summary, 0x04)
  defconstant(:services_supported, :subscribe_cov, 0x05)
  defconstant(:services_supported, :atomic_read_file, 0x06)
  defconstant(:services_supported, :atomic_write_file, 0x07)
  defconstant(:services_supported, :add_list_element, 0x08)
  defconstant(:services_supported, :remove_list_element, 0x09)
  defconstant(:services_supported, :create_object, 0x0A)
  defconstant(:services_supported, :delete_object, 0x0B)
  defconstant(:services_supported, :read_property, 0x0C)
  defconstant(:services_supported, :read_property_conditional, 0x0D)
  defconstant(:services_supported, :read_property_multiple, 0x0E)
  defconstant(:services_supported, :write_property, 0x0F)
  defconstant(:services_supported, :write_property_multiple, 0x10)
  defconstant(:services_supported, :device_communication_control, 0x11)
  defconstant(:services_supported, :confirmed_private_transfer, 0x12)
  defconstant(:services_supported, :confirmed_text_message, 0x13)
  defconstant(:services_supported, :reinitialize_device, 0x14)
  defconstant(:services_supported, :vt_open, 0x15)
  defconstant(:services_supported, :vt_close, 0x16)
  defconstant(:services_supported, :vt_data, 0x17)
  defconstant(:services_supported, :authenticate, 0x18)
  defconstant(:services_supported, :request_key, 0x19)
  defconstant(:services_supported, :i_am, 0x1A)
  defconstant(:services_supported, :i_have, 0x1B)
  defconstant(:services_supported, :unconfirmed_cov_notification, 0x1C)
  defconstant(:services_supported, :unconfirmed_event_notification, 0x1D)
  defconstant(:services_supported, :unconfirmed_private_transfer, 0x1E)
  defconstant(:services_supported, :unconfirmed_text_message, 0x1F)
  defconstant(:services_supported, :time_synchronization, 0x20)
  defconstant(:services_supported, :who_has, 0x21)
  defconstant(:services_supported, :who_is, 0x22)
  defconstant(:services_supported, :read_range, 0x23)
  defconstant(:services_supported, :utc_time_synchronization, 0x24)
  defconstant(:services_supported, :life_safety_operation, 0x25)
  defconstant(:services_supported, :subscribe_cov_property, 0x26)
  defconstant(:services_supported, :get_event_information, 0x27)
  defconstant(:services_supported, :write_group, 0x28)
  defconstant(:services_supported, :subscribe_cov_property_multiple, 0x29)
  defconstant(:services_supported, :confirmed_cov_notification_multiple, 0x2A)
  defconstant(:services_supported, :unconfirmed_cov_notification_multiple, 0x2B)

  @doc false
  def get_constants() do
    @constants
  end
end
