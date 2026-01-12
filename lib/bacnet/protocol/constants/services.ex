defmodule BACnet.Protocol.Constants.Services do
  @moduledoc false
  # Can be extended through env :bacstack, :additional_confirmed_service_choice + :additional_unconfirmed_service_choice

  use ConstEnum, exception: BACnet.Protocol.Constants.ConstantError

  defconst(:confirmed_service_choice, :acknowledge_alarm, 0x00)
  defconst(:confirmed_service_choice, :confirmed_cov_notification, 0x01)
  defconst(:confirmed_service_choice, :confirmed_event_notification, 0x02)
  defconst(:confirmed_service_choice, :get_alarm_summary, 0x03)
  defconst(:confirmed_service_choice, :get_enrollment_summary, 0x04)
  defconst(:confirmed_service_choice, :subscribe_cov, 0x05)
  defconst(:confirmed_service_choice, :atomic_read_file, 0x06)
  defconst(:confirmed_service_choice, :atomic_write_file, 0x07)
  defconst(:confirmed_service_choice, :add_list_element, 0x08)
  defconst(:confirmed_service_choice, :remove_list_element, 0x09)
  defconst(:confirmed_service_choice, :create_object, 0x0A)
  defconst(:confirmed_service_choice, :delete_object, 0x0B)
  defconst(:confirmed_service_choice, :read_property, 0x0C)
  defconst(:confirmed_service_choice, :read_property_multiple, 0x0E)
  defconst(:confirmed_service_choice, :write_property, 0x0F)
  defconst(:confirmed_service_choice, :write_property_multiple, 0x10)
  defconst(:confirmed_service_choice, :device_communication_control, 0x11)
  defconst(:confirmed_service_choice, :confirmed_private_transfer, 0x12)
  defconst(:confirmed_service_choice, :confirmed_text_message, 0x13)
  defconst(:confirmed_service_choice, :reinitialize_device, 0x14)
  defconst(:confirmed_service_choice, :vt_open, 0x15)
  defconst(:confirmed_service_choice, :vt_close, 0x16)
  defconst(:confirmed_service_choice, :vt_data, 0x17)
  defconst(:confirmed_service_choice, :read_range, 0x1A)
  defconst(:confirmed_service_choice, :life_safety_operation, 0x1B)
  defconst(:confirmed_service_choice, :subscribe_cov_property, 0x1C)
  defconst(:confirmed_service_choice, :get_event_information, 0x1D)
  defconst(:confirmed_service_choice, :subscribe_cov_property_multiple, 0x1E)
  defconst(:confirmed_service_choice, :confirmed_cov_notification_multiple, 0x1F)

  defconst_extend_env(
    :confirmed_service_choice,
    :bacstack,
    :additional_confirmed_service_choice,
    &(is_atom(&1) and is_integer(&2) and &2 >= 0)
  )

  defconst(:unconfirmed_service_choice, :i_am, 0x00)
  defconst(:unconfirmed_service_choice, :i_have, 0x01)
  defconst(:unconfirmed_service_choice, :unconfirmed_cov_notification, 0x02)
  defconst(:unconfirmed_service_choice, :unconfirmed_event_notification, 0x03)
  defconst(:unconfirmed_service_choice, :unconfirmed_private_transfer, 0x04)
  defconst(:unconfirmed_service_choice, :unconfirmed_text_message, 0x05)
  defconst(:unconfirmed_service_choice, :time_synchronization, 0x06)
  defconst(:unconfirmed_service_choice, :who_has, 0x07)
  defconst(:unconfirmed_service_choice, :who_is, 0x08)
  defconst(:unconfirmed_service_choice, :utc_time_synchronization, 0x09)
  defconst(:unconfirmed_service_choice, :write_group, 0x0A)
  defconst(:unconfirmed_service_choice, :unconfirmed_cov_notification_multiple, 0x0B)

  defconst_extend_env(
    :unconfirmed_service_choice,
    :bacstack,
    :additional_unconfirmed_service_choice,
    &(&1 != nil and is_integer(&2) and &2 >= 0)
  )
end
