defmodule BACnet.Protocol.Constants.VendorExtensions do
  @moduledoc false

  use ConstEnum,
    exception: BACnet.Protocol.Constants.ConstantError,
    ignore_duplicates: true,
    no_types: true

  @constdoc """
  Vendor extension ranges per ASHRAE 135-2016 Table 23-1 (Clause 23.1).
  Only the enumerations listed here may be extended by vendors.
  Vendor/proprietary values lie strictly outside the ASHRAE reserved range
  up to the datatype maximum.
  """
  @ctable false
  defconst(:vendor_extensions, :abort_reason, Macro.escape([64..255//1]))

  defconst(
    :vendor_extensions,
    :access_authentication_factor_disable,
    Macro.escape([64..65_535//1])
  )

  defconst(:vendor_extensions, :access_credential_disable, Macro.escape([64..65_535//1]))
  defconst(:vendor_extensions, :access_credential_disable_reason, Macro.escape([64..65_535//1]))
  defconst(:vendor_extensions, :access_event, Macro.escape([512..65_535//1]))
  defconst(:vendor_extensions, :access_user_type, Macro.escape([64..65_535//1]))
  defconst(:vendor_extensions, :access_zone_occupancy_state, Macro.escape([64..65_535//1]))
  defconst(:vendor_extensions, :authorization_exemption, Macro.escape([64..255//1]))
  defconst(:vendor_extensions, :authorization_mode, Macro.escape([64..65_535//1]))
  defconst(:vendor_extensions, :binary_lighting_present_value, Macro.escape([64..255//1]))
  defconst(:vendor_extensions, :device_status, Macro.escape([64..65_535//1]))
  defconst(:vendor_extensions, :door_alarm_state, Macro.escape([256..65_535//1]))
  defconst(:vendor_extensions, :door_status, Macro.escape([1024..65_535//1]))

  defconst(
    :vendor_extensions,
    :engineering_unit,
    Macro.escape([256..47_807//1, 50_000..65_535//1])
  )

  defconst(:vendor_extensions, :error_class, Macro.escape([64..65_535//1]))
  defconst(:vendor_extensions, :error_code, Macro.escape([256..65_535//1]))
  defconst(:vendor_extensions, :escalator_fault, Macro.escape([1024..65_535//1]))
  defconst(:vendor_extensions, :escalator_mode, Macro.escape([1024..65_535//1]))
  defconst(:vendor_extensions, :escalator_operation_direction, Macro.escape([1024..65_535//1]))
  defconst(:vendor_extensions, :event_state, Macro.escape([64..65_535//1]))
  defconst(:vendor_extensions, :event_type, Macro.escape([64..65_535//1]))
  defconst(:vendor_extensions, :life_safety_mode, Macro.escape([256..65_535//1]))
  defconst(:vendor_extensions, :life_safety_operation, Macro.escape([64..65_535//1]))
  defconst(:vendor_extensions, :life_safety_state, Macro.escape([256..65_535//1]))
  defconst(:vendor_extensions, :lift_car_direction, Macro.escape([1024..65_535//1]))
  defconst(:vendor_extensions, :lift_car_drive_status, Macro.escape([1024..65_535//1]))
  defconst(:vendor_extensions, :lift_car_mode, Macro.escape([1024..65_535//1]))
  defconst(:vendor_extensions, :lift_fault, Macro.escape([1024..65_535//1]))
  defconst(:vendor_extensions, :lighting_operation, Macro.escape([256..65_535//1]))
  defconst(:vendor_extensions, :lighting_transition, Macro.escape([64..255//1]))
  defconst(:vendor_extensions, :logging_type, Macro.escape([64..255//1]))
  defconst(:vendor_extensions, :maintenance, Macro.escape([256..65_535//1]))
  defconst(:vendor_extensions, :network_port_command, Macro.escape([128..255//1]))
  defconst(:vendor_extensions, :network_type, Macro.escape([64..255//1]))
  defconst(:vendor_extensions, :object_type, Macro.escape([128..1023//1]))
  defconst(:vendor_extensions, :program_error, Macro.escape([64..65_535//1]))
  defconst(:vendor_extensions, :property_identifier, Macro.escape([512..4_194_303//1]))
  defconst(:vendor_extensions, :property_state, Macro.escape([64..254//1]))
  defconst(:vendor_extensions, :reject_reason, Macro.escape([64..255//1]))
  defconst(:vendor_extensions, :relationship, Macro.escape([1024..65_535//1]))
  defconst(:vendor_extensions, :reliability, Macro.escape([64..65_535//1]))
  defconst(:vendor_extensions, :restart_reason, Macro.escape([64..255//1]))
  defconst(:vendor_extensions, :silenced_state, Macro.escape([64..65_535//1]))
  defconst(:vendor_extensions, :vt_class, Macro.escape([64..65_535//1]))
end
