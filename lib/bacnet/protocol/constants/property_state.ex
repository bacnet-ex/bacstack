defmodule BACnet.Protocol.Constants.PropertyState do
  @moduledoc false

  use BACnet.Macro, exception: BACnet.Protocol.Constants.ConstantError

  @constdoc "Property State (ASHRAE 135 - 21 FORMAL DESCRIPTION OF APPLICATION PROTOCOL DATA UNITS)"
  defconstant(:property_state, :boolean_value, 0x00)
  defconstant(:property_state, :binary_value, 0x01)
  defconstant(:property_state, :event_type, 0x02)
  defconstant(:property_state, :polarity, 0x03)
  defconstant(:property_state, :program_change, 0x04)
  defconstant(:property_state, :program_state, 0x05)
  defconstant(:property_state, :reason_for_halt, 0x06)
  defconstant(:property_state, :reliability, 0x07)
  defconstant(:property_state, :state, 0x08)
  defconstant(:property_state, :system_status, 0x09)
  defconstant(:property_state, :units, 0x0A)
  defconstant(:property_state, :unsigned_value, 0x0B)
  defconstant(:property_state, :life_safety_mode, 0x0C)
  defconstant(:property_state, :life_safety_state, 0x0D)
  defconstant(:property_state, :restart_reason, 0x0E)
  defconstant(:property_state, :door_alarm_state, 0x0F)
  defconstant(:property_state, :action, 0x10)
  defconstant(:property_state, :door_secured_status, 0x11)
  defconstant(:property_state, :door_status, 0x12)
  defconstant(:property_state, :door_value, 0x13)
  defconstant(:property_state, :file_access_method, 0x14)
  defconstant(:property_state, :lock_status, 0x15)
  defconstant(:property_state, :life_safety_operation, 0x16)
  defconstant(:property_state, :maintenance, 0x17)
  defconstant(:property_state, :node_type, 0x18)
  defconstant(:property_state, :notify_type, 0x19)
  defconstant(:property_state, :security_level, 0x1A)
  defconstant(:property_state, :shed_state, 0x1B)
  defconstant(:property_state, :silenced_state, 0x1C)
  defconstant(:property_state, :access_event, 0x1E)
  defconstant(:property_state, :zone_occupancy_state, 0x1F)
  defconstant(:property_state, :access_credential_disable_reason, 0x20)
  defconstant(:property_state, :access_credential_disable, 0x21)
  defconstant(:property_state, :authentication_status, 0x22)
  defconstant(:property_state, :backup_state, 0x24)
  defconstant(:property_state, :write_status, 0x25)
  defconstant(:property_state, :lighting_in_progress, 0x26)
  defconstant(:property_state, :lighting_operation, 0x27)
  defconstant(:property_state, :lighting_transition, 0x28)
  defconstant(:property_state, :integer_value, 0x29)
  defconstant(:property_state, :binary_lighting_value, 0x2A)
  defconstant(:property_state, :timer_state, 0x2B)
  defconstant(:property_state, :timer_transition, 0x2C)
  defconstant(:property_state, :bacnet_ip_mode, 0x2D)
  defconstant(:property_state, :network_port_command, 0x2E)
  defconstant(:property_state, :network_type, 0x2F)
  defconstant(:property_state, :network_number_quality, 0x30)
  defconstant(:property_state, :escalator_operation_direction, 0x31)
  defconstant(:property_state, :escalator_fault, 0x32)
  defconstant(:property_state, :escalator_mode, 0x33)
  defconstant(:property_state, :lift_car_direction, 0x34)
  defconstant(:property_state, :lift_car_door_command, 0x35)
  defconstant(:property_state, :lift_car_drive_status, 0x36)
  defconstant(:property_state, :lift_car_mode, 0x37)
  defconstant(:property_state, :lift_group_mode, 0x38)
  defconstant(:property_state, :lift_fault, 0x39)
  defconstant(:property_state, :protocol_level, 0x3A)
  defconstant(:property_state, :extended_value, 0x3F)
end