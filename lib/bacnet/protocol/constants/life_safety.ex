defmodule BACnet.Protocol.Constants.LifeSafety do
  @moduledoc false

  use BACnet.Macro, exception: BACnet.Protocol.Constants.ConstantError

  defconstant(:life_safety_mode, :off, 0x00)
  defconstant(:life_safety_mode, :on, 0x01)
  defconstant(:life_safety_mode, :test, 0x02)
  defconstant(:life_safety_mode, :manned, 0x03)
  defconstant(:life_safety_mode, :unmanned, 0x04)
  defconstant(:life_safety_mode, :armed, 0x05)
  defconstant(:life_safety_mode, :disarmed, 0x06)
  defconstant(:life_safety_mode, :prearmed, 0x07)
  defconstant(:life_safety_mode, :slow, 0x08)
  defconstant(:life_safety_mode, :fast, 0x09)
  defconstant(:life_safety_mode, :disconnected, 0x0A)
  defconstant(:life_safety_mode, :enabled, 0x0B)
  defconstant(:life_safety_mode, :disabled, 0x0C)
  defconstant(:life_safety_mode, :automatic_release_disabled, 0x0D)
  defconstant(:life_safety_mode, :default, 0x0E)

  defconstant(:life_safety_operation, :none, 0x00)
  defconstant(:life_safety_operation, :silence, 0x01)
  defconstant(:life_safety_operation, :silence_audible, 0x02)
  defconstant(:life_safety_operation, :silence_visual, 0x03)
  defconstant(:life_safety_operation, :reset, 0x04)
  defconstant(:life_safety_operation, :reset_alarm, 0x05)
  defconstant(:life_safety_operation, :reset_fault, 0x06)
  defconstant(:life_safety_operation, :unsilence, 0x07)
  defconstant(:life_safety_operation, :unsilence_audible, 0x08)
  defconstant(:life_safety_operation, :unsilence_visual, 0x09)

  defconstant(:life_safety_state, :quiet, 0x00)
  defconstant(:life_safety_state, :pre_alarm, 0x01)
  defconstant(:life_safety_state, :alarm, 0x02)
  defconstant(:life_safety_state, :fault, 0x03)
  defconstant(:life_safety_state, :fault_pre_alarm, 0x04)
  defconstant(:life_safety_state, :fault_alarm, 0x05)
  defconstant(:life_safety_state, :not_ready, 0x06)
  defconstant(:life_safety_state, :active, 0x07)
  defconstant(:life_safety_state, :tamper, 0x08)
  defconstant(:life_safety_state, :test_alarm, 0x09)
  defconstant(:life_safety_state, :test_active, 0x0A)
  defconstant(:life_safety_state, :test_fault, 0x0B)
  defconstant(:life_safety_state, :test_fault_alarm, 0x0C)
  defconstant(:life_safety_state, :holdup, 0x0D)
  defconstant(:life_safety_state, :duress, 0x0E)
  defconstant(:life_safety_state, :tamper_alarm, 0x0F)
  defconstant(:life_safety_state, :abnormal, 0x10)
  defconstant(:life_safety_state, :emergency_power, 0x11)
  defconstant(:life_safety_state, :delayed, 0x12)
  defconstant(:life_safety_state, :blocked, 0x13)
  defconstant(:life_safety_state, :local_alarm, 0x14)
  defconstant(:life_safety_state, :general_alarm, 0x15)
  defconstant(:life_safety_state, :supervisory, 0x16)
  defconstant(:life_safety_state, :test_supervisory, 0x17)
end