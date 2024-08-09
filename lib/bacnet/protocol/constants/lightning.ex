defmodule BACnet.Protocol.Constants.Lightning do
  @moduledoc false

  use BACnet.Macro, exception: BACnet.Protocol.Constants.ConstantError

  # Lighting In Progress
  defconstant(:lighting_in_progress, :idle, 0x00)
  defconstant(:lighting_in_progress, :fade_active, 0x01)
  defconstant(:lighting_in_progress, :ramp_active, 0x02)
  defconstant(:lighting_in_progress, :not_controlled, 0x03)
  defconstant(:lighting_in_progress, :other, 0x04)

  # Lighting Operation
  defconstant(:lighting_operation, :none, 0x00)
  defconstant(:lighting_operation, :fade_to, 0x01)
  defconstant(:lighting_operation, :ramp_to, 0x02)
  defconstant(:lighting_operation, :step_up, 0x03)
  defconstant(:lighting_operation, :step_down, 0x04)
  defconstant(:lighting_operation, :step_on, 0x05)
  defconstant(:lighting_operation, :step_off, 0x06)
  defconstant(:lighting_operation, :warn, 0x07)
  defconstant(:lighting_operation, :warn_off, 0x08)
  defconstant(:lighting_operation, :warn_relinquish, 0x09)
  defconstant(:lighting_operation, :stop, 0x0A)

  # Lighting Transition
  defconstant(:lighting_transition, :none, 0x00)
  defconstant(:lighting_transition, :fade, 0x01)
  defconstant(:lighting_transition, :ramp, 0x02)
end
