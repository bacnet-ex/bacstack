defmodule BACnet.Protocol.Constants.Lightning do
  @moduledoc false

  use ConstEnum, exception: BACnet.Protocol.Constants.ConstantError

  # Lighting In Progress
  defconst(:lighting_in_progress, :idle, 0x00)
  defconst(:lighting_in_progress, :fade_active, 0x01)
  defconst(:lighting_in_progress, :ramp_active, 0x02)
  defconst(:lighting_in_progress, :not_controlled, 0x03)
  defconst(:lighting_in_progress, :other, 0x04)

  # Lighting Operation
  defconst(:lighting_operation, :none, 0x00)
  defconst(:lighting_operation, :fade_to, 0x01)
  defconst(:lighting_operation, :ramp_to, 0x02)
  defconst(:lighting_operation, :step_up, 0x03)
  defconst(:lighting_operation, :step_down, 0x04)
  defconst(:lighting_operation, :step_on, 0x05)
  defconst(:lighting_operation, :step_off, 0x06)
  defconst(:lighting_operation, :warn, 0x07)
  defconst(:lighting_operation, :warn_off, 0x08)
  defconst(:lighting_operation, :warn_relinquish, 0x09)
  defconst(:lighting_operation, :stop, 0x0A)

  # Lighting Transition
  defconst(:lighting_transition, :none, 0x00)
  defconst(:lighting_transition, :fade, 0x01)
  defconst(:lighting_transition, :ramp, 0x02)
end
