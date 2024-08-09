defmodule BACnet.Protocol.Constants do
  @moduledoc """
  BACnet Protocol constants.
  """

  use BACnet.Macro,
    exception: BACnet.Protocol.Constants.ConstantError,
    generate_docs: true,
    copy_doc_to_type: true

  @doc """
  Equivalent to `by_name_safe/3`, however it uses `by_name!/2`
  when the name is an atom. If the name is not an atom, it is returned as-is.
  """
  @spec by_name_atom(atom(), atom() | term()) :: term() | no_return()
  def by_name_atom(type, name)

  def by_name_atom(type, name) when is_atom(type) and is_atom(name) do
    by_name!(type, name)
  end

  def by_name_atom(_type, name), do: name

  @doc """
  Equivalent to `by_name/2`, however instead of returning plain `:error`,
  it returns `{:error, reason}`, where `reason` is user-supplied.
  """
  @spec by_name_with_reason(atom(), term(), term()) :: {:ok, term()} | {:error, reason :: term()}
  def by_name_with_reason(type, name, reason) when is_atom(type) do
    case by_name(type, name) do
      {:ok, _val} = value -> value
      :error -> {:error, reason}
    end
  end

  @doc """
  Equivalent to `by_value/2`, however instead of returning plain `:error`,
  it returns `{:error, reason}`, where `reason` is user-supplied.
  """
  @spec by_value_with_reason(atom(), term(), term()) :: {:ok, term()} | {:error, reason :: term()}
  def by_value_with_reason(type, value, reason) when is_atom(type) do
    case by_value(type, value) do
      {:ok, _val} = name -> name
      :error -> {:error, reason}
    end
  end

  # BACnet ASN.1
  @constdoc false
  defconstant(:asn1, :max_object, 0x3FF)
  defconstant(:asn1, :max_instance_and_property_id, 0x3FFFFF)
  defconstant(:asn1, :instance_bits, 22)
  defconstant(:asn1, :max_bitstring_bytes, 15)
  defconstant(:asn1, :array_all, 0xFFFFFFFF)
  defconstant(:asn1, :max_application_tag, 16)
  defconstant(:asn1, :max_object_type, 1024)

  @constdoc """
  When creating BACnet objects, the designated revision can
  be chosen from the constants. The designated revision decides
  which properties are required. Optional properties are regardless
  of the revision available.

  The following revisions are supported (to be):
  - Revision 14 (135-2012)
  - Revision 19 (135-2016)
  - Revision 22 (135-2022)

  The default BACnet Revision is 14 (2012).
  """
  defconstant(:protocol_revision, :default, :revision_14)
  defconstant(:protocol_revision, :revision_14, 14)
  # TODO: Support Protocol Revision 19 and 22
  # defconstant(:protocol_revision, :revision_19, 19)
  # defconstant(:protocol_revision, :revision_22, 22)

  @typedoc """
  The maximum APDU length supported by BACnet. Each device (respectively
  transport layer) may support only the minimum or a value in between.
  """
  @type max_apdu :: 50..1467

  @typedoc """
  The maximum amount of segments for segmented requests or responses.
  """
  @type max_segments :: 1..64 | :more_than_64 | :unspecified

  ###############################

  @constdoc "BACnet Virtual Link Layer (BVLL) for BACnet/IP"
  defconstant(:bvll, :default_port_bacnet_ip, 0xBAC0)
  defconstant(:bvll, :type_bacnet_ipv4, 0x81)
  defconstant(:bvll, :type_bacnet_ipv6, 0x82)

  ###############################

  @constdoc "BACnet Virtual Link Control (BVLC)"
  defconstant(:bvlc_result_format, :successful_completion, 0x00)
  defconstant(:bvlc_result_format, :write_broadcast_distribution_table_nak, 0x10)
  defconstant(:bvlc_result_format, :read_broadcast_distribution_table_nak, 0x20)
  defconstant(:bvlc_result_format, :register_foreign_device_nak, 0x30)
  defconstant(:bvlc_result_format, :read_foreign_device_table_nak, 0x40)
  defconstant(:bvlc_result_format, :delete_foreign_device_table_entry_nak, 0x50)
  defconstant(:bvlc_result_format, :distribute_broadcast_to_network_nak, 0x60)

  @constdoc "BACnet Virtual Link Control (BVLC)"
  defconstant(:bvlc_result_purpose, :bvlc_result, 0x00)
  defconstant(:bvlc_result_purpose, :bvlc_write_broadcast_distribution_table, 0x01)
  defconstant(:bvlc_result_purpose, :bvlc_read_broadcast_distribution_table, 0x02)
  defconstant(:bvlc_result_purpose, :bvlc_read_broadcast_distribution_table_ack, 0x03)
  defconstant(:bvlc_result_purpose, :bvlc_forwarded_npdu, 0x04)
  defconstant(:bvlc_result_purpose, :bvlc_register_foreign_device, 0x05)
  defconstant(:bvlc_result_purpose, :bvlc_read_foreign_device_table, 0x06)
  defconstant(:bvlc_result_purpose, :bvlc_read_foreign_device_table_ack, 0x07)
  defconstant(:bvlc_result_purpose, :bvlc_delete_foreign_device_table_entry, 0x08)
  defconstant(:bvlc_result_purpose, :bvlc_distribute_broadcast_to_network, 0x09)
  defconstant(:bvlc_result_purpose, :bvlc_original_unicast_npdu, 0x0A)
  defconstant(:bvlc_result_purpose, :bvlc_original_broadcast_npdu, 0x0B)
  defconstant(:bvlc_result_purpose, :bvlc_secure_bvll, 0x0C)

  ###############################

  @constdoc "Character String Encoding (ASHRAE 135 - 20.2.9 Encoding of a Character String Value)"
  defconstant(:character_string_encoding, :utf8, 0x00)
  defconstant(:character_string_encoding, :microsoft_dbcs, 0x01)
  defconstant(:character_string_encoding, :jis_x_0208, 0x02)
  defconstant(:character_string_encoding, :ucs_4, 0x03)
  defconstant(:character_string_encoding, :ucs_2, 0x04)
  defconstant(:character_string_encoding, :iso_8859_1, 0x05)

  ###############################

  @constdoc "Enable Disable (ASHRAE 135 - 16.1.1.1.2 Enable/Disable)"
  defconstant(:enable_disable, :enable, 0x00)
  defconstant(:enable_disable, :disable, 0x01)
  defconstant(:enable_disable, :disable_initiation, 0x02)

  ###############################

  @constdoc "Max APDU Length Accepted (ASHRAE 135 - 20.1.2.5 max-apdu-length-accepted)"
  defconstant(:max_apdu_length_accepted, :octets_50, 0b0000)
  defconstant(:max_apdu_length_accepted, :octets_128, 0b0001)
  defconstant(:max_apdu_length_accepted, :octets_206, 0b0010)
  defconstant(:max_apdu_length_accepted, :octets_480, 0b0011)
  defconstant(:max_apdu_length_accepted, :octets_1024, 0b0100)
  defconstant(:max_apdu_length_accepted, :octets_1476, 0b0101)

  @constdoc "Max APDU Length Accepted (ASHRAE 135 - 20.1.2.5 max-apdu-length-accepted) - Values are the real APDU max size"
  @ctypedoc false
  defconstant(:max_apdu_length_accepted_value, :octets_50, 50)
  defconstant(:max_apdu_length_accepted_value, :octets_128, 128)
  defconstant(:max_apdu_length_accepted_value, :octets_206, 206)
  defconstant(:max_apdu_length_accepted_value, :octets_480, 480)
  defconstant(:max_apdu_length_accepted_value, :octets_1024, 1024)
  defconstant(:max_apdu_length_accepted_value, :octets_1476, 1476)

  ###############################

  @constdoc "Max Segments Accepted (ASHRAE 135 - 20.1.2.4 max-segments-accepted)"
  defconstant(:max_segments_accepted, :segments_0, 0b000)
  defconstant(:max_segments_accepted, :segments_2, 0b001)
  defconstant(:max_segments_accepted, :segments_4, 0b010)
  defconstant(:max_segments_accepted, :segments_8, 0b011)
  defconstant(:max_segments_accepted, :segments_16, 0b100)
  defconstant(:max_segments_accepted, :segments_32, 0b101)
  defconstant(:max_segments_accepted, :segments_64, 0b110)
  defconstant(:max_segments_accepted, :segments_65, 0b111)

  ###############################

  # Confirmed Service Choice
  defconstforward(Services, :confirmed_service_choice)

  ###############################

  # Unconfirmed Service Choice
  defconstforward(Services, :unconfirmed_service_choice)

  ###############################

  # Abort Reason
  defconstforward(AbortRejectError, :abort_reason)

  ###############################

  # Reject Reason
  defconstforward(AbortRejectError, :reject_reason)

  ###############################

  # Error Class
  defconstforward(AbortRejectError, :error_class)

  ###############################

  # Error Code
  defconstforward(AbortRejectError, :error_code)

  ###############################

  # Accumulator Scale
  defconstant(:accumulator_scale, :float_scale, 0)
  defconstant(:accumulator_scale, :integer_scale, 1)

  ###############################

  # Accumulator Status
  defconstant(:accumulator_status, :normal, 0)
  defconstant(:accumulator_status, :starting, 1)
  defconstant(:accumulator_status, :recovered, 2)
  defconstant(:accumulator_status, :abnormal, 3)
  defconstant(:accumulator_status, :failed, 4)

  ###############################

  # Access Authentication Factor Disable
  # defconstant(:access_authentication_factor_disable, :none, 0x00)
  # defconstant(:access_authentication_factor_disable, :disabled, 0x01)
  # defconstant(:access_authentication_factor_disable, :disabled_lost, 0x02)
  # defconstant(:access_authentication_factor_disable, :disabled_stolen, 0x03)
  # defconstant(:access_authentication_factor_disable, :disabled_damaged, 0x04)
  # defconstant(:access_authentication_factor_disable, :disabled_destroyed, 0x05)

  ###############################

  # Access Credential Disable
  # defconstant(:access_credential_disable, :none, 0x00)
  # defconstant(:access_credential_disable, :disable, 0x01)
  # defconstant(:access_credential_disable, :disable_manual, 0x02)
  # defconstant(:access_credential_disable, :disable_lockout, 0x03)

  ###############################

  # Access Credential Disable Reason
  # defconstant(:access_credential_disable_reason, :disabled, 0x00)
  # defconstant(:access_credential_disable_reason, :disabled_needs_provisioning, 0x01)
  # defconstant(:access_credential_disable_reason, :disabled_unassigned, 0x02)
  # defconstant(:access_credential_disable_reason, :disabled_not_yet_active, 0x03)
  # defconstant(:access_credential_disable_reason, :disabled_expired, 0x04)
  # defconstant(:access_credential_disable_reason, :disabled_lockout, 0x05)
  # defconstant(:access_credential_disable_reason, :disabled_max_days, 0x06)
  # defconstant(:access_credential_disable_reason, :disabled_max_uses, 0x07)
  # defconstant(:access_credential_disable_reason, :disabled_inactivity, 0x08)
  # defconstant(:access_credential_disable_reason, :disabled_manual, 0x09)

  ###############################

  # Access Event
  # defconstant(:access_event, :none, 0x00)
  # defconstant(:access_event, :granted, 0x01)
  # defconstant(:access_event, :muster, 0x02)
  # defconstant(:access_event, :passback_detected, 0x03)
  # defconstant(:access_event, :duress, 0x04)
  # defconstant(:access_event, :trace, 0x05)
  # defconstant(:access_event, :lockout_max_attempts, 0x06)
  # defconstant(:access_event, :lockout_other, 0x07)
  # defconstant(:access_event, :lockout_relinquished, 0x08)
  # defconstant(:access_event, :locked_by_higher_priority, 0x09)
  # defconstant(:access_event, :out_of_service, 0x0A)
  # defconstant(:access_event, :out_of_service_relinquished, 0x0B)
  # defconstant(:access_event, :accompaniment_by, 0x0C)
  # defconstant(:access_event, :authentication_factor_read, 0x0D)
  # defconstant(:access_event, :authorization_delayed, 0x0E)
  # defconstant(:access_event, :verification_required, 0x0F)
  # defconstant(:access_event, :no_entry_after_granted, 0x10)
  # defconstant(:access_event, :denied_deny_all, 0x80)
  # defconstant(:access_event, :denied_unknown_credential, 0x81)
  # defconstant(:access_event, :denied_authentication_unavailable, 0x82)
  # defconstant(:access_event, :denied_authentication_factor_timeout, 0x83)
  # defconstant(:access_event, :denied_incorrect_authentication_factor, 0x84)
  # defconstant(:access_event, :denied_zone_no_access_rights, 0x85)
  # defconstant(:access_event, :denied_point_no_access_rights, 0x86)
  # defconstant(:access_event, :denied_no_access_rights, 0x87)
  # defconstant(:access_event, :denied_out_of_time_range, 0x88)
  # defconstant(:access_event, :denied_threat_level, 0x89)
  # defconstant(:access_event, :denied_passback, 0x8A)
  # defconstant(:access_event, :denied_unexpected_location_usage, 0x8B)
  # defconstant(:access_event, :denied_max_attempts, 0x8C)
  # defconstant(:access_event, :denied_lower_occupancy_limit, 0x8D)
  # defconstant(:access_event, :denied_upper_occupancy_limit, 0x8E)
  # defconstant(:access_event, :denied_authentication_factor_lost, 0x8F)
  # defconstant(:access_event, :denied_authentication_factor_stolen, 0x90)
  # defconstant(:access_event, :denied_authentication_factor_damaged, 0x91)
  # defconstant(:access_event, :denied_authentication_factor_destroyed, 0x92)
  # defconstant(:access_event, :denied_authentication_factor_disabled, 0x93)
  # defconstant(:access_event, :denied_authentication_factor_error, 0x94)
  # defconstant(:access_event, :denied_credential_unassigned, 0x95)
  # defconstant(:access_event, :denied_credential_not_provisioned, 0x96)
  # defconstant(:access_event, :denied_credential_not_yet_active, 0x97)
  # defconstant(:access_event, :denied_credential_expired, 0x98)
  # defconstant(:access_event, :denied_credential_manual_disable, 0x99)
  # defconstant(:access_event, :denied_credential_lockout, 0x9A)
  # defconstant(:access_event, :denied_credential_max_days, 0x9B)
  # defconstant(:access_event, :denied_credential_max_uses, 0x9C)
  # defconstant(:access_event, :denied_credential_inactivity, 0x9D)
  # defconstant(:access_event, :denied_credential_disabled, 0x9E)
  # defconstant(:access_event, :denied_no_accompaniment, 0x9F)
  # defconstant(:access_event, :denied_incorrect_accompaniment, 0xA0)
  # defconstant(:access_event, :denied_lockout, 0xA1)
  # defconstant(:access_event, :denied_verification_failed, 0xA2)
  # defconstant(:access_event, :denied_verification_timeout, 0xA3)
  # defconstant(:access_event, :denied_other, 0xA4)

  ###############################

  # Access Passback Mode
  # defconstant(:access_passback_mode, :passback_off, 0x00)
  # defconstant(:access_passback_mode, :hard_passback, 0x01)
  # defconstant(:access_passback_mode, :soft_passback, 0x02)

  ###############################

  # Access User Type
  # defconstant(:access_user_type, :asset, 0x00)
  # defconstant(:access_user_type, :group, 0x01)
  # defconstant(:access_user_type, :person, 0x02)

  ###############################

  # Access Zone Occupancy State
  # defconstant(:access_zone_occupancy_state, :normal, 0x00)
  # defconstant(:access_zone_occupancy_state, :below_lower_limit, 0x01)
  # defconstant(:access_zone_occupancy_state, :at_lower_limit, 0x02)
  # defconstant(:access_zone_occupancy_state, :at_upper_limit, 0x03)
  # defconstant(:access_zone_occupancy_state, :above_upper_limit, 0x04)
  # defconstant(:access_zone_occupancy_state, :disabled, 0x05)
  # defconstant(:access_zone_occupancy_state, :not_supported, 0x06)

  ###############################

  # Authentication Factor Type
  # defconstant(:authentication_factor_type, :undefined, 0x00)
  # defconstant(:authentication_factor_type, :error, 0x01)
  # defconstant(:authentication_factor_type, :custom, 0x02)
  # defconstant(:authentication_factor_type, :simple_number16, 0x03)
  # defconstant(:authentication_factor_type, :simple_number32, 0x04)
  # defconstant(:authentication_factor_type, :simple_number56, 0x05)
  # defconstant(:authentication_factor_type, :simple_alpha_numeric, 0x06)
  # defconstant(:authentication_factor_type, :aba_track2, 0x07)
  # defconstant(:authentication_factor_type, :wiegand26, 0x08)
  # defconstant(:authentication_factor_type, :wiegand37, 0x09)
  # defconstant(:authentication_factor_type, :wiegand37_facility, 0x0A)
  # defconstant(:authentication_factor_type, :facility16_card32, 0x0B)
  # defconstant(:authentication_factor_type, :facility32_card32, 0x0C)
  # defconstant(:authentication_factor_type, :fasc_n, 0x0D)
  # defconstant(:authentication_factor_type, :fasc_n_bcd, 0x0E)
  # defconstant(:authentication_factor_type, :fasc_n_large, 0x0F)
  # defconstant(:authentication_factor_type, :fasc_n_large_bcd, 0x10)
  # defconstant(:authentication_factor_type, :gsa75, 0x11)
  # defconstant(:authentication_factor_type, :chuid, 0x12)
  # defconstant(:authentication_factor_type, :chuid_full, 0x13)
  # defconstant(:authentication_factor_type, :guid, 0x14)
  # defconstant(:authentication_factor_type, :cbeff_a, 0x15)
  # defconstant(:authentication_factor_type, :cbeff_b, 0x16)
  # defconstant(:authentication_factor_type, :cbeff_c, 0x17)
  # defconstant(:authentication_factor_type, :user_password, 0x18)

  ###############################

  # Authentication Status
  # defconstant(:authentication_status, :not_ready, 0x00)
  # defconstant(:authentication_status, :ready, 0x01)
  # defconstant(:authentication_status, :disabled, 0x02)
  # defconstant(:authentication_status, :waiting_for_authentication_factor, 0x03)
  # defconstant(:authentication_status, :waiting_for_accompaniment, 0x04)
  # defconstant(:authentication_status, :waiting_for_verification, 0x05)
  # defconstant(:authentication_status, :in_progress, 0x06)

  ###############################

  # Authorization Exemption
  # defconstant(:authorization_exemption, :passback, 0x00)
  # defconstant(:authorization_exemption, :occupancy_check, 0x01)
  # defconstant(:authorization_exemption, :access_rights, 0x02)
  # defconstant(:authorization_exemption, :lockout, 0x03)
  # defconstant(:authorization_exemption, :deny, 0x04)
  # defconstant(:authorization_exemption, :verification, 0x05)
  # defconstant(:authorization_exemption, :authorization_delay, 0x06)

  ###############################

  # Authorization Mode
  # defconstant(:authorization_mode, :authorize, 0x00)
  # defconstant(:authorization_mode, :grant_active, 0x01)
  # defconstant(:authorization_mode, :deny_all, 0x02)
  # defconstant(:authorization_mode, :verification_required, 0x03)
  # defconstant(:authorization_mode, :authorization_delayed, 0x04)
  # defconstant(:authorization_mode, :none, 0x05)

  ###############################

  # Backup State
  defconstant(:backup_state, :idle, 0x00)
  defconstant(:backup_state, :preparing_for_backup, 0x01)
  defconstant(:backup_state, :preparing_for_restore, 0x02)
  defconstant(:backup_state, :performing_a_backup, 0x03)
  defconstant(:backup_state, :performing_a_restore, 0x04)
  defconstant(:backup_state, :backup_failure, 0x05)
  defconstant(:backup_state, :restore_failure, 0x06)

  ###############################

  # Action (used in Loop BACnet objects)
  defconstant(:action, :direct, 0x00)
  defconstant(:action, :reverse, 0x01)

  ###############################

  # Binary Lighting Present Value
  defconstant(:binary_lighting_present_value, :off, 0x00)
  defconstant(:binary_lighting_present_value, :on, 0x01)
  defconstant(:binary_lighting_present_value, :warn, 0x02)
  defconstant(:binary_lighting_present_value, :warn_off, 0x03)
  defconstant(:binary_lighting_present_value, :warn_relinquish, 0x04)
  defconstant(:binary_lighting_present_value, :stop, 0x05)

  ###############################

  # Binary Present Value
  defconstant(:binary_present_value, :inactive, 0x00)
  defconstant(:binary_present_value, :active, 0x01)

  ###############################

  # Device Status
  defconstant(:device_status, :operational, 0x00)
  defconstant(:device_status, :operational_read_only, 0x01)
  defconstant(:device_status, :download_required, 0x02)
  defconstant(:device_status, :download_in_progress, 0x03)
  defconstant(:device_status, :non_operational, 0x04)
  defconstant(:device_status, :backup_in_progress, 0x05)

  ###############################

  # Door Alarm State
  defconstant(:door_alarm_state, :normal, 0x00)
  defconstant(:door_alarm_state, :alarm, 0x01)
  defconstant(:door_alarm_state, :door_open_too_long, 0x02)
  defconstant(:door_alarm_state, :forced_open, 0x03)
  defconstant(:door_alarm_state, :tamper, 0x04)
  defconstant(:door_alarm_state, :door_fault, 0x05)
  defconstant(:door_alarm_state, :lock_down, 0x06)
  defconstant(:door_alarm_state, :free_access, 0x07)
  defconstant(:door_alarm_state, :egress_open, 0x08)

  ###############################

  # Door Secured Status
  defconstant(:door_secured_status, :secured, 0x00)
  defconstant(:door_secured_status, :unsecured, 0x01)
  defconstant(:door_secured_status, :unknown, 0x02)

  ###############################

  # Door Status
  defconstant(:door_status, :closed, 0x00)
  defconstant(:door_status, :opened, 0x01)
  defconstant(:door_status, :unknown, 0x02)
  defconstant(:door_status, :door_fault, 0x03)
  defconstant(:door_status, :unused, 0x04)
  defconstant(:door_status, :none, 0x05)
  defconstant(:door_status, :closing, 0x06)
  defconstant(:door_status, :opening, 0x07)
  defconstant(:door_status, :safety_locked, 0x08)
  defconstant(:door_status, :limited_opened, 0x09)

  ###############################

  # Door Value
  defconstant(:door_value, :lock, 0x00)
  defconstant(:door_value, :unlock, 0x01)
  defconstant(:door_value, :pulse_unlock, 0x02)
  defconstant(:door_value, :extended_pulse_unlock, 0x03)

  ###############################

  # Escalator Fault
  # defconstant(:escalator_fault, :controller_fault, 0x00)
  # defconstant(:escalator_fault, :drive_and_motor_fault, 0x01)
  # defconstant(:escalator_fault, :mechanical_component_fault, 0x02)
  # defconstant(:escalator_fault, :overspeed_fault, 0x03)
  # defconstant(:escalator_fault, :power_supply_fault, 0x04)
  # defconstant(:escalator_fault, :safety_device_fault, 0x05)
  # defconstant(:escalator_fault, :controller_supply_fault, 0x06)
  # defconstant(:escalator_fault, :drive_temperature_exceeded, 0x07)
  # defconstant(:escalator_fault, :comb_plate_fault, 0x08)

  ###############################

  # Escalator Mode
  # defconstant(:escalator_mode, :unknown, 0x00)
  # defconstant(:escalator_mode, :stop, 0x01)
  # defconstant(:escalator_mode, :up, 0x02)
  # defconstant(:escalator_mode, :down, 0x03)
  # defconstant(:escalator_mode, :inspection, 0x04)
  # defconstant(:escalator_mode, :out_of_service, 0x05)

  ###############################

  # Escalator Operation Direction
  # defconstant(:escalator_operation_direction, :unknown, 0x00)
  # defconstant(:escalator_operation_direction, :stopped, 0x01)
  # defconstant(:escalator_operation_direction, :up_rated_speed, 0x02)
  # defconstant(:escalator_operation_direction, :up_reduced_speed, 0x03)
  # defconstant(:escalator_operation_direction, :down_rated_speed, 0x04)
  # defconstant(:escalator_operation_direction, :down_reduced_speed, 0x05)

  ###############################

  # Event State
  defconstant(:event_state, :normal, 0x00)
  defconstant(:event_state, :fault, 0x01)
  defconstant(:event_state, :offnormal, 0x02)
  defconstant(:event_state, :high_limit, 0x03)
  defconstant(:event_state, :low_limit, 0x04)
  defconstant(:event_state, :life_safety_alarm, 0x05)

  ###############################

  # Event Type
  defconstant(:event_type, :change_of_bitstring, 0x00)
  defconstant(:event_type, :change_of_state, 0x01)
  defconstant(:event_type, :change_of_value, 0x02)
  defconstant(:event_type, :command_failure, 0x03)
  defconstant(:event_type, :floating_limit, 0x04)
  defconstant(:event_type, :out_of_range, 0x05)
  defconstant(:event_type, :complex_event_type, 0x06)
  defconstant(:event_type, :change_of_life_safety, 0x08)
  defconstant(:event_type, :extended, 0x09)
  defconstant(:event_type, :buffer_ready, 0x0A)
  defconstant(:event_type, :unsigned_range, 0x0B)
  defconstant(:event_type, :access_event, 0x0D)
  defconstant(:event_type, :double_out_of_range, 0x0E)
  defconstant(:event_type, :signed_out_of_range, 0x0F)
  defconstant(:event_type, :unsigned_out_of_range, 0x10)
  defconstant(:event_type, :change_of_characterstring, 0x11)
  defconstant(:event_type, :change_of_status_flags, 0x12)
  defconstant(:event_type, :change_of_reliability, 0x13)
  defconstant(:event_type, :none, 0x14)
  defconstant(:event_type, :change_of_discrete_value, 0x15)
  defconstant(:event_type, :change_of_timer, 0x16)

  ###############################

  # Fault Type
  defconstant(:fault_type, :none, 0x00)
  defconstant(:fault_type, :fault_characterstring, 0x01)
  defconstant(:fault_type, :fault_extended, 0x02)
  defconstant(:fault_type, :fault_life_safety, 0x03)
  defconstant(:fault_type, :fault_state, 0x04)
  defconstant(:fault_type, :fault_status_flags, 0x05)
  defconstant(:fault_type, :fault_out_of_range, 0x06)
  defconstant(:fault_type, :fault_listed, 0x07)

  ###############################

  # File Access Method
  defconstant(:file_access_method, :record_access, 0x00)
  defconstant(:file_access_method, :stream_access, 0x01)

  ###############################

  # IP Mode
  defconstant(:ip_mode, :normal, 0x00)
  defconstant(:ip_mode, :foreign, 0x01)
  defconstant(:ip_mode, :bbmd, 0x02)

  ###############################

  # Life Safety Mode
  defconstforward(LifeSafety, :life_safety_mode)

  ###############################

  # Life Safety Operation
  defconstforward(LifeSafety, :life_safety_operation)

  ###############################

  # Life Safety State
  defconstforward(LifeSafety, :life_safety_state)

  ###############################

  # Lift Car Direction
  # defconstforward(Lift, :lift_car_direction)

  ###############################

  # Lift Car Door Command
  # defconstforward(Lift, :lift_car_door_command)

  ###############################

  # Lift Car Drive Status
  # defconstforward(Lift, :lift_car_drive_status)

  ###############################

  # Lift Car Mode
  # defconstforward(Lift, :lift_car_mode)

  ###############################

  # Lift Fault
  # defconstforward(Lift, :lift_fault)

  ###############################

  # Lift Group Mode
  # defconstforward(Lift, :lift_group_mode)

  ###############################

  # Lighting In Progress
  defconstforward(Lightning, :lighting_in_progress)

  ###############################

  # Lighting Operation
  defconstforward(Lightning, :lighting_operation)

  ###############################

  # Lighting Transition
  defconstforward(Lightning, :lighting_transition)

  ###############################

  # Lock Status
  defconstant(:lock_status, :locked, 0x00)
  defconstant(:lock_status, :unlocked, 0x01)
  defconstant(:lock_status, :lock_fault, 0x02)
  defconstant(:lock_status, :unused, 0x03)
  defconstant(:lock_status, :unknown, 0x04)

  ###############################

  # Logging Type (used for Trend Log objects)
  defconstant(:logging_type, :polled, 0x00)
  defconstant(:logging_type, :cov, 0x01)
  defconstant(:logging_type, :triggered, 0x02)

  ###############################

  # Maintenance
  defconstant(:maintenance, :none, 0x00)
  defconstant(:maintenance, :periodic_test, 0x01)
  defconstant(:maintenance, :need_service_operational, 0x02)
  defconstant(:maintenance, :need_service_inoperative, 0x03)

  ###############################

  # Network Number Quality
  defconstant(:network_number_quality, :unknown, 0x00)
  defconstant(:network_number_quality, :learned, 0x01)
  defconstant(:network_number_quality, :learned_configured, 0x02)
  defconstant(:network_number_quality, :configured, 0x03)

  ###############################

  # Network Port Command
  defconstant(:network_port_command, :idle, 0x00)
  defconstant(:network_port_command, :discard_changes, 0x01)
  defconstant(:network_port_command, :renew_fd_registration, 0x02)
  defconstant(:network_port_command, :restart_slave_discovery, 0x03)
  defconstant(:network_port_command, :renew_dhcp, 0x04)
  defconstant(:network_port_command, :restart_autonegotiation, 0x05)
  defconstant(:network_port_command, :disconnect, 0x06)
  defconstant(:network_port_command, :restart_port, 0x07)

  ###############################

  # Network Type
  defconstant(:network_type, :ethernet, 0x00)
  defconstant(:network_type, :arcnet, 0x01)
  defconstant(:network_type, :mstp, 0x02)
  defconstant(:network_type, :ptp, 0x03)
  defconstant(:network_type, :lontalk, 0x04)
  defconstant(:network_type, :ipv4, 0x05)
  defconstant(:network_type, :zigbee, 0x06)
  defconstant(:network_type, :virtual, 0x07)
  defconstant(:network_type, :ipv6, 0x09)
  defconstant(:network_type, :serial, 0x0A)

  ###############################

  # Node Type
  defconstant(:node_type, :unknown, 0x00)
  defconstant(:node_type, :system, 0x01)
  defconstant(:node_type, :network, 0x02)
  defconstant(:node_type, :device, 0x03)
  defconstant(:node_type, :organizational, 0x04)
  defconstant(:node_type, :area, 0x05)
  defconstant(:node_type, :equipment, 0x06)
  defconstant(:node_type, :point, 0x07)
  defconstant(:node_type, :collection, 0x08)
  defconstant(:node_type, :property, 0x09)
  defconstant(:node_type, :functional, 0x0A)
  defconstant(:node_type, :other, 0x0B)
  defconstant(:node_type, :subsystem, 0x0C)
  defconstant(:node_type, :building, 0x0D)
  defconstant(:node_type, :floor, 0x0E)
  defconstant(:node_type, :section, 0x0F)
  defconstant(:node_type, :module, 0x10)
  defconstant(:node_type, :tree, 0x11)
  defconstant(:node_type, :member, 0x12)
  defconstant(:node_type, :protocol, 0x13)
  defconstant(:node_type, :room, 0x14)
  defconstant(:node_type, :zone, 0x15)

  ###############################

  # Notify Type (used for notifications for objects, such as alarms, trend logs)
  defconstant(:notify_type, :alarm, 0x00)
  defconstant(:notify_type, :event, 0x01)
  defconstant(:notify_type, :ack_notification, 0x02)

  ###############################

  # Object Type
  defconstforward(Object, :object_type)

  ###############################

  # Polarity (used in Binary Input and Output objects)
  defconstant(:polarity, :normal, 0x00)
  defconstant(:polarity, :reverse, 0x01)

  ###############################

  # Program Error
  defconstant(:program_error, :normal, 0x00)
  defconstant(:program_error, :load_failed, 0x01)
  defconstant(:program_error, :internal, 0x02)
  defconstant(:program_error, :program, 0x03)
  defconstant(:program_error, :other, 0x04)

  ###############################

  # Program Request
  defconstant(:program_request, :ready, 0x00)
  defconstant(:program_request, :load, 0x01)
  defconstant(:program_request, :run, 0x02)
  defconstant(:program_request, :halt, 0x03)
  defconstant(:program_request, :restart, 0x04)
  defconstant(:program_request, :unload, 0x05)

  ###############################

  # Program State
  defconstant(:program_state, :idle, 0x00)
  defconstant(:program_state, :loading, 0x01)
  defconstant(:program_state, :running, 0x02)
  defconstant(:program_state, :waiting, 0x03)
  defconstant(:program_state, :halted, 0x04)
  defconstant(:program_state, :unloading, 0x05)

  ###############################

  # Property Identifier
  defconstforward(PropertyIdentifier, :property_identifier)

  ###############################

  # Protocol Level
  defconstant(:protocol_level, :physical, 0x00)
  defconstant(:protocol_level, :protocol, 0x01)
  defconstant(:protocol_level, :bacnet_application, 0x02)
  defconstant(:protocol_level, :non_bacnet_application, 0x03)

  ###############################

  # Relationship
  defconstant(:relationship, :unknown, 0x00)
  defconstant(:relationship, :default, 0x01)
  defconstant(:relationship, :contains, 0x02)
  defconstant(:relationship, :contained_by, 0x03)
  defconstant(:relationship, :uses, 0x04)
  defconstant(:relationship, :used_by, 0x05)
  defconstant(:relationship, :commands, 0x06)
  defconstant(:relationship, :commanded_by, 0x07)
  defconstant(:relationship, :adjusts, 0x08)
  defconstant(:relationship, :adjusted_by, 0x09)
  defconstant(:relationship, :ingress, 0x0A)
  defconstant(:relationship, :egress, 0x0B)
  defconstant(:relationship, :supplies_air, 0x0C)
  defconstant(:relationship, :receives_air, 0x0D)
  defconstant(:relationship, :supplies_hot_air, 0x0E)
  defconstant(:relationship, :receives_hot_air, 0x0F)
  defconstant(:relationship, :supplies_cool_air, 0x10)
  defconstant(:relationship, :receives_cool_air, 0x11)
  defconstant(:relationship, :supplies_power, 0x12)
  defconstant(:relationship, :receives_power, 0x13)
  defconstant(:relationship, :supplies_gas, 0x14)
  defconstant(:relationship, :receives_gas, 0x15)
  defconstant(:relationship, :supplies_water, 0x16)
  defconstant(:relationship, :receives_water, 0x17)
  defconstant(:relationship, :supplies_hot_water, 0x18)
  defconstant(:relationship, :receives_hot_water, 0x19)
  defconstant(:relationship, :supplies_cool_water, 0x1A)
  defconstant(:relationship, :receives_cool_water, 0x1B)
  defconstant(:relationship, :supplies_steam, 0x1C)
  defconstant(:relationship, :receives_steam, 0x1D)

  ###############################

  # Reliability
  defconstant(:reliability, :no_fault_detected, 0x00)
  defconstant(:reliability, :no_sensor, 0x01)
  defconstant(:reliability, :over_range, 0x02)
  defconstant(:reliability, :under_range, 0x03)
  defconstant(:reliability, :open_loop, 0x04)
  defconstant(:reliability, :shorted_loop, 0x05)
  defconstant(:reliability, :no_output, 0x06)
  defconstant(:reliability, :unreliable_other, 0x07)
  defconstant(:reliability, :process_error, 0x08)
  defconstant(:reliability, :multi_state_fault, 0x09)
  defconstant(:reliability, :configuration_error, 0x0A)
  defconstant(:reliability, :communication_failure, 0x0C)
  defconstant(:reliability, :member_fault, 0x0D)
  defconstant(:reliability, :monitored_object_fault, 0x0E)
  defconstant(:reliability, :tripped, 0x0F)
  defconstant(:reliability, :lamp_failure, 0x10)
  defconstant(:reliability, :activation_failure, 0x11)
  defconstant(:reliability, :renew_dhcp_failure, 0x12)
  defconstant(:reliability, :renew_fd_registration_failure, 0x13)
  defconstant(:reliability, :restart_auto_negotiation_failure, 0x14)
  defconstant(:reliability, :restart_failure, 0x15)
  defconstant(:reliability, :proprietary_command_failure, 0x16)
  defconstant(:reliability, :faults_listed, 0x17)
  defconstant(:reliability, :referenced_object_fault, 0x18)

  ###############################

  # Restart Reason
  defconstant(:restart_reason, :unknown, 0x00)
  defconstant(:restart_reason, :coldstart, 0x01)
  defconstant(:restart_reason, :warmstart, 0x02)
  defconstant(:restart_reason, :detected_power_lost, 0x03)
  defconstant(:restart_reason, :detected_powered_off, 0x04)
  defconstant(:restart_reason, :hardware_watchdog, 0x05)
  defconstant(:restart_reason, :software_watchdog, 0x06)
  defconstant(:restart_reason, :suspended, 0x07)
  defconstant(:restart_reason, :activate_changes, 0x08)

  ###############################

  # Security Level
  defconstant(:security_level, :incapable, 0x00)
  defconstant(:security_level, :plain, 0x01)
  defconstant(:security_level, :signed, 0x02)
  defconstant(:security_level, :encrypted, 0x03)
  defconstant(:security_level, :signed_end_to_end, 0x04)
  defconstant(:security_level, :encrypted_end_to_end, 0x05)

  ###############################

  # Security Policy
  defconstant(:security_policy, :plain_non_trusted, 0x00)
  defconstant(:security_policy, :plain_trusted, 0x01)
  defconstant(:security_policy, :signed_trusted, 0x02)
  defconstant(:security_policy, :encrypted_trusted, 0x03)

  ###############################

  # Segmentation
  defconstant(:segmentation, :segmented_both, 0x00)
  defconstant(:segmentation, :segmented_transmit, 0x01)
  defconstant(:segmentation, :segmented_receive, 0x02)
  defconstant(:segmentation, :no_segmentation, 0x03)

  ###############################

  # Shed State
  defconstant(:shed_state, :shed_inactive, 0x00)
  defconstant(:shed_state, :shed_request_pending, 0x01)
  defconstant(:shed_state, :shed_compliant, 0x02)
  defconstant(:shed_state, :shed_non_compliant, 0x03)

  ###############################

  # Silenced State
  defconstant(:silenced_state, :unsilenced, 0x00)
  defconstant(:silenced_state, :audible_silenced, 0x01)
  defconstant(:silenced_state, :visible_silenced, 0x02)
  defconstant(:silenced_state, :all_silenced, 0x03)

  ###############################

  # Timer State
  defconstant(:timer_state, :idle, 0x00)
  defconstant(:timer_state, :running, 0x01)
  defconstant(:timer_state, :expired, 0x02)

  ###############################

  # Timer Transition
  defconstant(:timer_transition, :none, 0x00)
  defconstant(:timer_transition, :idle_to_running, 0x01)
  defconstant(:timer_transition, :running_to_idle, 0x02)
  defconstant(:timer_transition, :running_to_running, 0x03)
  defconstant(:timer_transition, :running_to_expired, 0x04)
  defconstant(:timer_transition, :forced_to_expired, 0x05)
  defconstant(:timer_transition, :expired_to_idle, 0x06)
  defconstant(:timer_transition, :expired_to_running, 0x07)

  ###############################

  # VT Class
  defconstant(:vt_class, :default_terminal, 0x00)
  defconstant(:vt_class, :ansi_x3_64, 0x01)
  defconstant(:vt_class, :dec_vt52, 0x02)
  defconstant(:vt_class, :dec_vt100, 0x03)
  defconstant(:vt_class, :dec_vt220, 0x04)
  defconstant(:vt_class, :hp_700_94, 0x05)
  defconstant(:vt_class, :ibm_3130, 0x06)

  ###############################

  # Write Status
  defconstant(:write_status, :idle, 0x00)
  defconstant(:write_status, :in_progress, 0x01)
  defconstant(:write_status, :successful, 0x02)
  defconstant(:write_status, :failed, 0x03)

  ###############################

  @constdoc "Days Of Week (ASHRAE 135 - 21 FORMAL DESCRIPTION OF APPLICATION PROTOCOL DATA UNITS)"
  defconstant(:days_of_week, :monday, 0x00)
  defconstant(:days_of_week, :tuesday, 0x01)
  defconstant(:days_of_week, :wednesday, 0x02)
  defconstant(:days_of_week, :thursday, 0x03)
  defconstant(:days_of_week, :friday, 0x04)
  defconstant(:days_of_week, :saturday, 0x05)
  defconstant(:days_of_week, :sunday, 0x06)

  ###############################

  # Event Transition Bits
  defconstant(:event_transition_bit, :to_offnormal, 0x00)
  defconstant(:event_transition_bit, :to_fault, 0x01)
  defconstant(:event_transition_bit, :to_normal, 0x02)

  ###############################

  # Limit Enable
  defconstant(:limit_enable, :low_limit_enable, 0x00)
  defconstant(:limit_enable, :high_limit_enable, 0x01)

  ###############################

  # Log Status
  defconstant(:log_status, :log_disabled, 0x00)
  defconstant(:log_status, :buffer_purged, 0x01)
  defconstant(:log_status, :log_interrupted, 0x02)

  ###############################

  # Object Types Supported
  defconstforward(ObjectsSupported, :object_types_supported)

  ###############################

  # Result Flags
  defconstant(:result_flag, :first_item, 0x00)
  defconstant(:result_flag, :last_item, 0x01)
  defconstant(:result_flag, :more_items, 0x02)

  ###############################

  # Services Supported
  defconstforward(ServicesSupported, :services_supported)

  ###############################

  # Status Flags
  defconstant(:status_flag, :in_alarm, 0x00)
  defconstant(:status_flag, :fault, 0x01)
  defconstant(:status_flag, :overridden, 0x02)
  defconstant(:status_flag, :out_of_service, 0x03)

  ###############################

  @constdoc "Application Tags (ASHRAE 135 - 20.2.1.4 Application Tags)"
  defconstant(:application_tag, :null, 0x00)
  defconstant(:application_tag, :boolean, 0x01)
  defconstant(:application_tag, :unsigned_integer, 0x02)
  defconstant(:application_tag, :signed_integer, 0x03)
  defconstant(:application_tag, :real, 0x04)
  defconstant(:application_tag, :double, 0x05)
  defconstant(:application_tag, :octet_string, 0x06)
  defconstant(:application_tag, :character_string, 0x07)
  defconstant(:application_tag, :bitstring, 0x08)
  defconstant(:application_tag, :enumerated, 0x09)
  defconstant(:application_tag, :date, 0x0A)
  defconstant(:application_tag, :time, 0x0B)
  defconstant(:application_tag, :object_identifier, 0x0C)

  ###############################

  @constdoc "Network Layer Message Type (ASHRAE 135 - 6.2.4 Network Layer Message Type)"
  defconstant(:network_layer_message_type, :who_is_router_to_network, 0x00)
  defconstant(:network_layer_message_type, :i_am_router_to_network, 0x01)
  defconstant(:network_layer_message_type, :i_could_be_router_to_network, 0x02)
  defconstant(:network_layer_message_type, :reject_message_to_network, 0x03)
  defconstant(:network_layer_message_type, :router_busy_to_network, 0x04)
  defconstant(:network_layer_message_type, :router_available_to_network, 0x05)
  defconstant(:network_layer_message_type, :initialize_routing_table, 0x06)
  defconstant(:network_layer_message_type, :initialize_routing_table_ack, 0x07)
  defconstant(:network_layer_message_type, :establish_connection_to_network, 0x08)
  defconstant(:network_layer_message_type, :disconnect_connection_to_network, 0x09)
  defconstant(:network_layer_message_type, :challenge_request, 0x0A)
  defconstant(:network_layer_message_type, :security_payload, 0x0B)
  defconstant(:network_layer_message_type, :security_response, 0x0C)
  defconstant(:network_layer_message_type, :request_key_update, 0x0D)
  defconstant(:network_layer_message_type, :update_key_set, 0x0E)
  defconstant(:network_layer_message_type, :update_distribution_key, 0x0F)
  defconstant(:network_layer_message_type, :request_master_key, 0x10)
  defconstant(:network_layer_message_type, :set_master_key, 0x11)
  defconstant(:network_layer_message_type, :what_is_network_number, 0x12)
  defconstant(:network_layer_message_type, :network_number_is, 0x13)

  defconstant(:network_layer_message_type, :reserved_area_start, 0x14)
  defconstant(:network_layer_message_type, :vendor_proprietary_area_start, 0x80)

  ###############################

  @constdoc "NPDU Control Bits (ASHRAE 135 - 6.2.2 Network Layer Protocol Control Information)"
  defconstant(:npdu_control_bit, :expecting_reply, 0x04)
  defconstant(:npdu_control_bit, :source_specified, 0x08)
  defconstant(:npdu_control_bit, :destination_specified, 0x20)
  defconstant(:npdu_control_bit, :network_layer_message, 0x80)

  ###############################

  @constdoc "NPDU Control Priority (ASHRAE 135 - 6.2.2 Network Layer Protocol Control Information)"
  defconstant(:npdu_control_priority, :normal, 0x00)
  defconstant(:npdu_control_priority, :urgent, 0x01)
  defconstant(:npdu_control_priority, :critical_equipment_message, 0x02)
  defconstant(:npdu_control_priority, :life_safety_message, 0x03)

  ###############################

  @constdoc "PDU Confirmed Request PDU Bits (ASHRAE 135 - 20.1.2.11 Format of the BACnet-Confirmed-Request-PDU)"
  defconstant(:pdu_confirmed_request_bit, :segmented_response_accepted, 0x02)
  defconstant(:pdu_confirmed_request_bit, :more_follows, 0x04)
  defconstant(:pdu_confirmed_request_bit, :segmented_message, 0x08)

  ###############################

  @constdoc "PDU Segment ACK Bits (ASHRAE 135 - 20.1.6.6 Format of the BACnet-SegmentACK-PDU)"
  defconstant(:pdu_segment_ack_bit, :server, 0x01)
  defconstant(:pdu_segment_ack_bit, :negative_ack, 0x02)

  ###############################

  @constdoc "PDU Types (ASHRAE 135 - 21 FORMAL DESCRIPTION OF APPLICATION PROTOCOL DATA UNITS)"
  defconstant(:pdu_type, :confirmed_request, 0x00)
  defconstant(:pdu_type, :unconfirmed_request, 0x01)
  defconstant(:pdu_type, :simple_ack, 0x02)
  defconstant(:pdu_type, :complex_ack, 0x03)
  defconstant(:pdu_type, :segment_ack, 0x04)
  defconstant(:pdu_type, :error, 0x05)
  defconstant(:pdu_type, :reject, 0x06)
  defconstant(:pdu_type, :abort, 0x07)

  ###############################

  # Property State (ASHRAE 135 - 21 FORMAL DESCRIPTION OF APPLICATION PROTOCOL DATA UNITS)
  defconstforward(PropertyState, :property_state)

  ###############################

  @constdoc "Reinitialized State (ASHRAE 135 - 16.4.1.1.1 Reinitialized State of Device)"
  defconstant(:reinitialized_state, :coldstart, 0x00)
  defconstant(:reinitialized_state, :warmstart, 0x01)
  defconstant(:reinitialized_state, :startbackup, 0x02)
  defconstant(:reinitialized_state, :endbackup, 0x03)
  defconstant(:reinitialized_state, :startrestore, 0x04)
  defconstant(:reinitialized_state, :endrestore, 0x05)
  defconstant(:reinitialized_state, :abortrestore, 0x06)
  defconstant(:reinitialized_state, :activate_changes, 0x07)

  ###############################

  # Engineering Units
  defconstforward(EngineeringUnit, :engineering_unit)

  ###############################

  # The below macros need to be at the end because of the @constant attribute

  @doc """
  Get a list of all valid constant names values for the given type (in keyword list form).
  """
  @spec macro_list_all(atom()) :: Macro.t()
  defmacro macro_list_all(type) when is_atom(type) do
    consts =
      Enum.flat_map(@constants, fn
        {^type, name, value, _docs, _cdocs} -> [{name, value}]
        _else -> []
      end)

    quote do
      unquote(consts)
    end
  end

  @doc """
  Get a list of all valid constant names for the given type.
  """
  @spec macro_list_names(atom()) :: Macro.t()
  defmacro macro_list_names(type) when is_atom(type) do
    names =
      Enum.flat_map(@constants, fn
        {^type, name, _value, _docs, _cdocs} -> [name]
        _else -> []
      end)

    quote do
      unquote(names)
    end
  end
end
