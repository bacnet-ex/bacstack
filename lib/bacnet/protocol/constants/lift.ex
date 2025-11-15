defmodule BACnet.Protocol.Constants.Lift do
  @moduledoc false

  use ConstEnum, exception: BACnet.Protocol.Constants.ConstantError

  # Lift Car Direction
  defconst(:lift_car_direction, :unknown, 0x00)
  defconst(:lift_car_direction, :none, 0x01)
  defconst(:lift_car_direction, :stopped, 0x02)
  defconst(:lift_car_direction, :up, 0x03)
  defconst(:lift_car_direction, :down, 0x04)
  defconst(:lift_car_direction, :up_and_down, 0x05)

  # Lift Car Door Command
  defconst(:lift_car_door_command, :none, 0x00)
  defconst(:lift_car_door_command, :open, 0x01)
  defconst(:lift_car_door_command, :close, 0x02)

  # Lift Car Drive Status
  defconst(:lift_car_drive_status, :unknown, 0x00)
  defconst(:lift_car_drive_status, :stationary, 0x01)
  defconst(:lift_car_drive_status, :braking, 0x02)
  defconst(:lift_car_drive_status, :accelerate, 0x03)
  defconst(:lift_car_drive_status, :decelerate, 0x04)
  defconst(:lift_car_drive_status, :rated_speed, 0x05)
  defconst(:lift_car_drive_status, :single_floor_jump, 0x06)
  defconst(:lift_car_drive_status, :two_floor_jump, 0x07)
  defconst(:lift_car_drive_status, :three_floor_jump, 0x08)
  defconst(:lift_car_drive_status, :multi_floor_jump, 0x09)

  # Lift Car Mode
  defconst(:lift_car_mode, :unknown, 0x00)
  defconst(:lift_car_mode, :normal, 0x01)
  defconst(:lift_car_mode, :vip, 0x02)
  defconst(:lift_car_mode, :homing, 0x03)
  defconst(:lift_car_mode, :parking, 0x04)
  defconst(:lift_car_mode, :attendant_control, 0x05)
  defconst(:lift_car_mode, :firefighter_control, 0x06)
  defconst(:lift_car_mode, :emergency_power, 0x07)
  defconst(:lift_car_mode, :inspection, 0x08)
  defconst(:lift_car_mode, :cabinet_recall, 0x09)
  defconst(:lift_car_mode, :earthquake_operation, 0x0A)
  defconst(:lift_car_mode, :fire_operation, 0x0B)
  defconst(:lift_car_mode, :out_of_service, 0x0C)
  defconst(:lift_car_mode, :occupant_evacuation, 0x0D)

  # Lift Fault
  defconst(:lift_fault, :controller_fault, 0x00)
  defconst(:lift_fault, :drive_and_motor_fault, 0x01)
  defconst(:lift_fault, :governor_and_safety_gear_fault, 0x02)
  defconst(:lift_fault, :lift_shaft_device_fault, 0x03)
  defconst(:lift_fault, :power_supply_fault, 0x04)
  defconst(:lift_fault, :safety_interlock_fault, 0x05)
  defconst(:lift_fault, :door_closing_fault, 0x06)
  defconst(:lift_fault, :door_opening_fault, 0x07)
  defconst(:lift_fault, :car_stopped_outside_landing_zone, 0x08)
  defconst(:lift_fault, :call_button_stuck, 0x09)
  defconst(:lift_fault, :start_failure, 0x0A)
  defconst(:lift_fault, :controller_supply_fault, 0x0B)
  defconst(:lift_fault, :self_test_failure, 0x0C)
  defconst(:lift_fault, :runtime_limit_exceeded, 0x0D)
  defconst(:lift_fault, :position_lost, 0x0E)
  defconst(:lift_fault, :drive_temperature_exceeded, 0x0F)
  defconst(:lift_fault, :load_measurement_fault, 0x10)

  # Lift Group Mode
  defconst(:lift_group_mode, :unknown, 0x00)
  defconst(:lift_group_mode, :normal, 0x01)
  defconst(:lift_group_mode, :down_peak, 0x02)
  defconst(:lift_group_mode, :two_way, 0x03)
  defconst(:lift_group_mode, :four_way, 0x04)
  defconst(:lift_group_mode, :emergency_power, 0x05)
  defconst(:lift_group_mode, :up_peak, 0x06)

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
