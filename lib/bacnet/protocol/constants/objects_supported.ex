defmodule BACnet.Protocol.Constants.ObjectsSupported do
  @moduledoc false
  # Can be extended through env :bacstack, :additional_object_types_supported

  use ConstEnum, exception: BACnet.Protocol.Constants.ConstantError

  defconst(:object_types_supported, :analog_input, 0x00)
  defconst(:object_types_supported, :analog_output, 0x01)
  defconst(:object_types_supported, :analog_value, 0x02)
  defconst(:object_types_supported, :binary_input, 0x03)
  defconst(:object_types_supported, :binary_output, 0x04)
  defconst(:object_types_supported, :binary_value, 0x05)
  defconst(:object_types_supported, :calendar, 0x06)
  defconst(:object_types_supported, :command, 0x07)
  defconst(:object_types_supported, :device, 0x08)
  defconst(:object_types_supported, :event_enrollment, 0x09)
  defconst(:object_types_supported, :file, 0x0A)
  defconst(:object_types_supported, :group, 0x0B)
  defconst(:object_types_supported, :loop, 0x0C)
  defconst(:object_types_supported, :multi_state_input, 0x0D)
  defconst(:object_types_supported, :multi_state_output, 0x0E)
  defconst(:object_types_supported, :notification_class, 0x0F)
  defconst(:object_types_supported, :program, 0x10)
  defconst(:object_types_supported, :schedule, 0x11)
  defconst(:object_types_supported, :averaging, 0x12)
  defconst(:object_types_supported, :multi_state_value, 0x13)
  defconst(:object_types_supported, :trend_log, 0x14)
  defconst(:object_types_supported, :life_safety_point, 0x15)
  defconst(:object_types_supported, :life_safety_zone, 0x16)
  defconst(:object_types_supported, :accumulator, 0x17)
  defconst(:object_types_supported, :pulse_converter, 0x18)
  defconst(:object_types_supported, :event_log, 0x19)
  defconst(:object_types_supported, :global_group, 0x1A)
  defconst(:object_types_supported, :trend_log_multiple, 0x1B)
  defconst(:object_types_supported, :load_control, 0x1C)
  defconst(:object_types_supported, :structured_view, 0x1D)
  defconst(:object_types_supported, :access_door, 0x1E)
  defconst(:object_types_supported, :timer, 0x1F)
  defconst(:object_types_supported, :access_credential, 0x20)
  defconst(:object_types_supported, :access_point, 0x21)
  defconst(:object_types_supported, :access_rights, 0x22)
  defconst(:object_types_supported, :access_user, 0x23)
  defconst(:object_types_supported, :access_zone, 0x24)
  defconst(:object_types_supported, :credential_data_input, 0x25)
  defconst(:object_types_supported, :network_security, 0x26)
  defconst(:object_types_supported, :bitstring_value, 0x27)
  defconst(:object_types_supported, :character_string_value, 0x28)
  defconst(:object_types_supported, :date_pattern_value, 0x29)
  defconst(:object_types_supported, :date_value, 0x2A)
  defconst(:object_types_supported, :datetime_pattern_value, 0x2B)
  defconst(:object_types_supported, :datetime_value, 0x2C)
  defconst(:object_types_supported, :integer_value, 0x2D)
  defconst(:object_types_supported, :large_analog_value, 0x2E)
  defconst(:object_types_supported, :octet_string_value, 0x2F)
  defconst(:object_types_supported, :positive_integer_value, 0x30)
  defconst(:object_types_supported, :time_pattern_value, 0x31)
  defconst(:object_types_supported, :time_value, 0x32)
  defconst(:object_types_supported, :notification_forwarder, 0x33)
  defconst(:object_types_supported, :alert_enrollment, 0x34)
  defconst(:object_types_supported, :channel, 0x35)
  defconst(:object_types_supported, :lighting_output, 0x36)
  defconst(:object_types_supported, :binary_lighting_output, 0x37)
  defconst(:object_types_supported, :network_port, 0x38)
  defconst(:object_types_supported, :elevator_group, 0x39)
  defconst(:object_types_supported, :escalator, 0x3A)
  defconst(:object_types_supported, :lift, 0x3B)

  defconst_extend_env(
    :object_types_supported,
    :bacstack,
    :additional_object_types_supported,
    &(&1 != nil and is_integer(&2) and &2 >= 0)
  )

  @doc false
  def get_constants() do
    @constants
  end
end
