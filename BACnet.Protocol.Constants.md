# `BACnet.Protocol.Constants`
[🔗](https://github.com/bacnet-ex/bacstack/blob/master/lib/bacnet/protocol/constants.ex#L1)

BACnet Protocol constants.

Additional property identifiers can be added at compile time using
application `:bacstack` and key `:additional_property_identifiers`.
It must be an Enumerable with key as atom (the property identifier) and
value as unsigned integer (protocol value).
For example `config :bacstack, :additional_property_identifiers, %{loop_mode: 523}` in your `config.exs`.
Make sure to recompile the dependency after changing your config file.

### Constants: Abort Reason 

Type: `:abort_reason`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| apdu_too_long | 11 | `0b1011` | `0xB` |
| application_exceeded_reply_time | 8 | `0b1000` | `0x8` |
| buffer_overflow | 1 | `0b1` | `0x1` |
| insufficient_security | 6 | `0b110` | `0x6` |
| invalid_apdu_in_this_state | 2 | `0b10` | `0x2` |
| other | 0 | `0b0` | `0x0` |
| out_of_resources | 9 | `0b1001` | `0x9` |
| preempted_by_higher_priority_task | 3 | `0b11` | `0x3` |
| security_error | 5 | `0b101` | `0x5` |
| segmentation_not_supported | 4 | `0b100` | `0x4` |
| tsm_timeout | 10 | `0b1010` | `0xA` |
| window_size_out_of_range | 7 | `0b111` | `0x7` |

### Constants: Accumulator Scale 

Type: `:accumulator_scale`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| float_scale | 0 | `0b0` | `0x0` |
| integer_scale | 1 | `0b1` | `0x1` |

### Constants: Accumulator Status 

Type: `:accumulator_status`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| abnormal | 3 | `0b11` | `0x3` |
| failed | 4 | `0b100` | `0x4` |
| normal | 0 | `0b0` | `0x0` |
| recovered | 2 | `0b10` | `0x2` |
| starting | 1 | `0b1` | `0x1` |

### Constants: Action 

Type: `:action`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| direct | 0 | `0b0` | `0x0` |
| reverse | 1 | `0b1` | `0x1` |

### Constants: Application Tag 

Application Tags (ASHRAE 135 - 20.2.1.4 Application Tags)

Type: `:application_tag`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| bitstring | 8 | `0b1000` | `0x8` |
| boolean | 1 | `0b1` | `0x1` |
| character_string | 7 | `0b111` | `0x7` |
| date | 10 | `0b1010` | `0xA` |
| double | 5 | `0b101` | `0x5` |
| enumerated | 9 | `0b1001` | `0x9` |
| null | 0 | `0b0` | `0x0` |
| object_identifier | 12 | `0b1100` | `0xC` |
| octet_string | 6 | `0b110` | `0x6` |
| real | 4 | `0b100` | `0x4` |
| signed_integer | 3 | `0b11` | `0x3` |
| time | 11 | `0b1011` | `0xB` |
| unsigned_integer | 2 | `0b10` | `0x2` |

### Constants: Backup State 

Type: `:backup_state`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| backup_failure | 5 | `0b101` | `0x5` |
| idle | 0 | `0b0` | `0x0` |
| performing_a_backup | 3 | `0b11` | `0x3` |
| performing_a_restore | 4 | `0b100` | `0x4` |
| preparing_for_backup | 1 | `0b1` | `0x1` |
| preparing_for_restore | 2 | `0b10` | `0x2` |
| restore_failure | 6 | `0b110` | `0x6` |

### Constants: Binary Lighting Present Value 

Type: `:binary_lighting_present_value`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| off | 0 | `0b0` | `0x0` |
| on | 1 | `0b1` | `0x1` |
| stop | 5 | `0b101` | `0x5` |
| warn | 2 | `0b10` | `0x2` |
| warn_off | 3 | `0b11` | `0x3` |
| warn_relinquish | 4 | `0b100` | `0x4` |

### Constants: Binary Present Value 

Type: `:binary_present_value`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| active | 1 | `0b1` | `0x1` |
| inactive | 0 | `0b0` | `0x0` |

### Constants: Bvlc Result Format 

BACnet Virtual Link Control (BVLC)

Type: `:bvlc_result_format`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| delete_foreign_device_table_entry_nak | 80 | `0b1010000` | `0x50` |
| distribute_broadcast_to_network_nak | 96 | `0b1100000` | `0x60` |
| read_broadcast_distribution_table_nak | 32 | `0b100000` | `0x20` |
| read_foreign_device_table_nak | 64 | `0b1000000` | `0x40` |
| register_foreign_device_nak | 48 | `0b110000` | `0x30` |
| successful_completion | 0 | `0b0` | `0x0` |
| write_broadcast_distribution_table_nak | 16 | `0b10000` | `0x10` |

### Constants: Bvlc Result Purpose 

BACnet Virtual Link Control (BVLC)

Type: `:bvlc_result_purpose`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| bvlc_delete_foreign_device_table_entry | 8 | `0b1000` | `0x8` |
| bvlc_distribute_broadcast_to_network | 9 | `0b1001` | `0x9` |
| bvlc_forwarded_npdu | 4 | `0b100` | `0x4` |
| bvlc_original_broadcast_npdu | 11 | `0b1011` | `0xB` |
| bvlc_original_unicast_npdu | 10 | `0b1010` | `0xA` |
| bvlc_read_broadcast_distribution_table | 2 | `0b10` | `0x2` |
| bvlc_read_broadcast_distribution_table_ack | 3 | `0b11` | `0x3` |
| bvlc_read_foreign_device_table | 6 | `0b110` | `0x6` |
| bvlc_read_foreign_device_table_ack | 7 | `0b111` | `0x7` |
| bvlc_register_foreign_device | 5 | `0b101` | `0x5` |
| bvlc_result | 0 | `0b0` | `0x0` |
| bvlc_secure_bvll | 12 | `0b1100` | `0xC` |
| bvlc_write_broadcast_distribution_table | 1 | `0b1` | `0x1` |

### Constants: Bvll 

BACnet Virtual Link Layer (BVLL) for BACnet/IP

Type: `:bvll`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| default_port_bacnet_ip | 47808 | `0b1011101011000000` | `0xBAC0` |
| type_bacnet_ipv4 | 129 | `0b10000001` | `0x81` |
| type_bacnet_ipv6 | 130 | `0b10000010` | `0x82` |

### Constants: Character String Encoding 

Character String Encoding (ASHRAE 135 - 20.2.9 Encoding of a Character String Value)

Type: `:character_string_encoding`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| iso_8859_1 | 5 | `0b101` | `0x5` |
| jis_x_0208 | 2 | `0b10` | `0x2` |
| microsoft_dbcs | 1 | `0b1` | `0x1` |
| ucs_2 | 4 | `0b100` | `0x4` |
| ucs_4 | 3 | `0b11` | `0x3` |
| utf8 | 0 | `0b0` | `0x0` |

### Constants: Confirmed Service Choice 

Type: `:confirmed_service_choice`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| acknowledge_alarm | 0 | `0b0` | `0x0` |
| add_list_element | 8 | `0b1000` | `0x8` |
| atomic_read_file | 6 | `0b110` | `0x6` |
| atomic_write_file | 7 | `0b111` | `0x7` |
| confirmed_cov_notification | 1 | `0b1` | `0x1` |
| confirmed_cov_notification_multiple | 31 | `0b11111` | `0x1F` |
| confirmed_event_notification | 2 | `0b10` | `0x2` |
| confirmed_private_transfer | 18 | `0b10010` | `0x12` |
| confirmed_text_message | 19 | `0b10011` | `0x13` |
| create_object | 10 | `0b1010` | `0xA` |
| delete_object | 11 | `0b1011` | `0xB` |
| device_communication_control | 17 | `0b10001` | `0x11` |
| get_alarm_summary | 3 | `0b11` | `0x3` |
| get_enrollment_summary | 4 | `0b100` | `0x4` |
| get_event_information | 29 | `0b11101` | `0x1D` |
| life_safety_operation | 27 | `0b11011` | `0x1B` |
| read_property | 12 | `0b1100` | `0xC` |
| read_property_multiple | 14 | `0b1110` | `0xE` |
| read_range | 26 | `0b11010` | `0x1A` |
| reinitialize_device | 20 | `0b10100` | `0x14` |
| remove_list_element | 9 | `0b1001` | `0x9` |
| subscribe_cov | 5 | `0b101` | `0x5` |
| subscribe_cov_property | 28 | `0b11100` | `0x1C` |
| subscribe_cov_property_multiple | 30 | `0b11110` | `0x1E` |
| vt_close | 22 | `0b10110` | `0x16` |
| vt_data | 23 | `0b10111` | `0x17` |
| vt_open | 21 | `0b10101` | `0x15` |
| write_property | 15 | `0b1111` | `0xF` |
| write_property_multiple | 16 | `0b10000` | `0x10` |

### Constants: Days Of Week 

Days Of Week (ASHRAE 135 - 21 FORMAL DESCRIPTION OF APPLICATION PROTOCOL DATA UNITS)

Type: `:days_of_week`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| friday | 4 | `0b100` | `0x4` |
| monday | 0 | `0b0` | `0x0` |
| saturday | 5 | `0b101` | `0x5` |
| sunday | 6 | `0b110` | `0x6` |
| thursday | 3 | `0b11` | `0x3` |
| tuesday | 1 | `0b1` | `0x1` |
| wednesday | 2 | `0b10` | `0x2` |

### Constants: Device Status 

Type: `:device_status`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| backup_in_progress | 5 | `0b101` | `0x5` |
| download_in_progress | 3 | `0b11` | `0x3` |
| download_required | 2 | `0b10` | `0x2` |
| non_operational | 4 | `0b100` | `0x4` |
| operational | 0 | `0b0` | `0x0` |
| operational_read_only | 1 | `0b1` | `0x1` |

### Constants: Door Alarm State 

Type: `:door_alarm_state`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| alarm | 1 | `0b1` | `0x1` |
| door_fault | 5 | `0b101` | `0x5` |
| door_open_too_long | 2 | `0b10` | `0x2` |
| egress_open | 8 | `0b1000` | `0x8` |
| forced_open | 3 | `0b11` | `0x3` |
| free_access | 7 | `0b111` | `0x7` |
| lock_down | 6 | `0b110` | `0x6` |
| normal | 0 | `0b0` | `0x0` |
| tamper | 4 | `0b100` | `0x4` |

### Constants: Door Secured Status 

Type: `:door_secured_status`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| secured | 0 | `0b0` | `0x0` |
| unknown | 2 | `0b10` | `0x2` |
| unsecured | 1 | `0b1` | `0x1` |

### Constants: Door Status 

Type: `:door_status`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| closed | 0 | `0b0` | `0x0` |
| closing | 6 | `0b110` | `0x6` |
| door_fault | 3 | `0b11` | `0x3` |
| limited_opened | 9 | `0b1001` | `0x9` |
| none | 5 | `0b101` | `0x5` |
| opened | 1 | `0b1` | `0x1` |
| opening | 7 | `0b111` | `0x7` |
| safety_locked | 8 | `0b1000` | `0x8` |
| unknown | 2 | `0b10` | `0x2` |
| unused | 4 | `0b100` | `0x4` |

### Constants: Door Value 

Type: `:door_value`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| extended_pulse_unlock | 3 | `0b11` | `0x3` |
| lock | 0 | `0b0` | `0x0` |
| pulse_unlock | 2 | `0b10` | `0x2` |
| unlock | 1 | `0b1` | `0x1` |

### Constants: Enable Disable 

Enable Disable (ASHRAE 135 - 16.1.1.1.2 Enable/Disable)

Type: `:enable_disable`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| disable | 1 | `0b1` | `0x1` |
| disable_initiation | 2 | `0b10` | `0x2` |
| enable | 0 | `0b0` | `0x0` |

### Constants: Engineering Unit 

Type: `:engineering_unit`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| ampere_seconds | 238 | `0b11101110` | `0xEE` |
| ampere_square_hours | 246 | `0b11110110` | `0xF6` |
| ampere_square_meters | 169 | `0b10101001` | `0xA9` |
| amperes | 3 | `0b11` | `0x3` |
| amperes_per_meter | 167 | `0b10100111` | `0xA7` |
| amperes_per_square_meter | 168 | `0b10101000` | `0xA8` |
| bars | 55 | `0b110111` | `0x37` |
| becquerels | 222 | `0b11011110` | `0xDE` |
| btus | 20 | `0b10100` | `0x14` |
| btus_per_hour | 50 | `0b110010` | `0x32` |
| btus_per_pound | 117 | `0b1110101` | `0x75` |
| btus_per_pound_dry_air | 24 | `0b11000` | `0x18` |
| candelas | 179 | `0b10110011` | `0xB3` |
| candelas_per_square_meter | 180 | `0b10110100` | `0xB4` |
| centimeters | 118 | `0b1110110` | `0x76` |
| centimeters_of_mercury | 60 | `0b111100` | `0x3C` |
| centimeters_of_water | 57 | `0b111001` | `0x39` |
| cubic_feet | 79 | `0b1001111` | `0x4F` |
| cubic_feet_per_day | 248 | `0b11111000` | `0xF8` |
| cubic_feet_per_hour | 191 | `0b10111111` | `0xBF` |
| cubic_feet_per_minute | 84 | `0b1010100` | `0x54` |
| cubic_feet_per_second | 142 | `0b10001110` | `0x8E` |
| cubic_meters | 80 | `0b1010000` | `0x50` |
| cubic_meters_per_day | 249 | `0b11111001` | `0xF9` |
| cubic_meters_per_hour | 135 | `0b10000111` | `0x87` |
| cubic_meters_per_minute | 165 | `0b10100101` | `0xA5` |
| cubic_meters_per_second | 85 | `0b1010101` | `0x55` |
| currency1 | 105 | `0b1101001` | `0x69` |
| currency10 | 114 | `0b1110010` | `0x72` |
| currency2 | 106 | `0b1101010` | `0x6A` |
| currency3 | 107 | `0b1101011` | `0x6B` |
| currency4 | 108 | `0b1101100` | `0x6C` |
| currency5 | 109 | `0b1101101` | `0x6D` |
| currency6 | 110 | `0b1101110` | `0x6E` |
| currency7 | 111 | `0b1101111` | `0x6F` |
| currency8 | 112 | `0b1110000` | `0x70` |
| currency9 | 113 | `0b1110001` | `0x71` |
| cycles_per_hour | 25 | `0b11001` | `0x19` |
| cycles_per_minute | 26 | `0b11010` | `0x1A` |
| days | 70 | `0b1000110` | `0x46` |
| decibels | 199 | `0b11000111` | `0xC7` |
| decibels_a | 232 | `0b11101000` | `0xE8` |
| decibels_millivolt | 200 | `0b11001000` | `0xC8` |
| decibels_volt | 201 | `0b11001001` | `0xC9` |
| degree_days_celsius | 65 | `0b1000001` | `0x41` |
| degree_days_fahrenheit | 66 | `0b1000010` | `0x42` |
| degrees_angular | 90 | `0b1011010` | `0x5A` |
| degrees_celsius | 62 | `0b111110` | `0x3E` |
| degrees_celsius_per_hour | 91 | `0b1011011` | `0x5B` |
| degrees_celsius_per_minute | 92 | `0b1011100` | `0x5C` |
| degrees_fahrenheit | 64 | `0b1000000` | `0x40` |
| degrees_fahrenheit_per_hour | 93 | `0b1011101` | `0x5D` |
| degrees_fahrenheit_per_minute | 94 | `0b1011110` | `0x5E` |
| degrees_kelvin | 63 | `0b111111` | `0x3F` |
| degrees_kelvin_per_hour | 181 | `0b10110101` | `0xB5` |
| degrees_kelvin_per_minute | 182 | `0b10110110` | `0xB6` |
| degrees_phase | 14 | `0b1110` | `0xE` |
| delta_degrees_fahrenheit | 120 | `0b1111000` | `0x78` |
| delta_degrees_kelvin | 121 | `0b1111001` | `0x79` |
| farads | 170 | `0b10101010` | `0xAA` |
| feet | 33 | `0b100001` | `0x21` |
| feet_per_minute | 77 | `0b1001101` | `0x4D` |
| feet_per_second | 76 | `0b1001100` | `0x4C` |
| foot_candles | 38 | `0b100110` | `0x26` |
| grams | 195 | `0b11000011` | `0xC3` |
| grams_of_water_per_kilogram_dry_air | 28 | `0b11100` | `0x1C` |
| grams_per_cubic_centimeter | 221 | `0b11011101` | `0xDD` |
| grams_per_cubic_meter | 217 | `0b11011001` | `0xD9` |
| grams_per_gram | 208 | `0b11010000` | `0xD0` |
| grams_per_kilogram | 210 | `0b11010010` | `0xD2` |
| grams_per_liter | 214 | `0b11010110` | `0xD6` |
| grams_per_milliliter | 213 | `0b11010101` | `0xD5` |
| grams_per_minute | 155 | `0b10011011` | `0x9B` |
| grams_per_second | 154 | `0b10011010` | `0x9A` |
| grams_per_square_meter | 235 | `0b11101011` | `0xEB` |
| gray | 225 | `0b11100001` | `0xE1` |
| hectopascals | 133 | `0b10000101` | `0x85` |
| henrys | 171 | `0b10101011` | `0xAB` |
| hertz | 27 | `0b11011` | `0x1B` |
| horsepower | 51 | `0b110011` | `0x33` |
| hours | 71 | `0b1000111` | `0x47` |
| hundredths_seconds | 158 | `0b10011110` | `0x9E` |
| imperial_gallons | 81 | `0b1010001` | `0x51` |
| imperial_gallons_per_minute | 86 | `0b1010110` | `0x56` |
| inches | 32 | `0b100000` | `0x20` |
| inches_of_mercury | 61 | `0b111101` | `0x3D` |
| inches_of_water | 58 | `0b111010` | `0x3A` |
| joule_per_hours | 247 | `0b11110111` | `0xF7` |
| joule_seconds | 183 | `0b10110111` | `0xB7` |
| joules | 16 | `0b10000` | `0x10` |
| joules_per_cubic_meter | 251 | `0b11111011` | `0xFB` |
| joules_per_degree_kelvin | 127 | `0b1111111` | `0x7F` |
| joules_per_kilogram_degree_kelvin | 128 | `0b10000000` | `0x80` |
| joules_per_kilogram_dry_air | 23 | `0b10111` | `0x17` |
| kilo_btus | 147 | `0b10010011` | `0x93` |
| kilo_btus_per_hour | 157 | `0b10011101` | `0x9D` |
| kilobecquerels | 223 | `0b11011111` | `0xDF` |
| kilograms | 39 | `0b100111` | `0x27` |
| kilograms_per_cubic_meter | 186 | `0b10111010` | `0xBA` |
| kilograms_per_hour | 44 | `0b101100` | `0x2C` |
| kilograms_per_kilogram | 209 | `0b11010001` | `0xD1` |
| kilograms_per_minute | 43 | `0b101011` | `0x2B` |
| kilograms_per_second | 42 | `0b101010` | `0x2A` |
| kilohertz | 129 | `0b10000001` | `0x81` |
| kilohms | 122 | `0b1111010` | `0x7A` |
| kilojoules | 17 | `0b10001` | `0x11` |
| kilojoules_per_degree_kelvin | 151 | `0b10010111` | `0x97` |
| kilojoules_per_kilogram | 125 | `0b1111101` | `0x7D` |
| kilojoules_per_kilogram_dry_air | 149 | `0b10010101` | `0x95` |
| kilometers | 193 | `0b11000001` | `0xC1` |
| kilometers_per_hour | 75 | `0b1001011` | `0x4B` |
| kilopascals | 54 | `0b110110` | `0x36` |
| kilovolt_ampere_hours | 240 | `0b11110000` | `0xF0` |
| kilovolt_ampere_hours_reactive | 243 | `0b11110011` | `0xF3` |
| kilovolt_amperes | 9 | `0b1001` | `0x9` |
| kilovolt_amperes_reactive | 12 | `0b1100` | `0xC` |
| kilovolts | 6 | `0b110` | `0x6` |
| kilowatt_hours | 19 | `0b10011` | `0x13` |
| kilowatt_hours_per_square_foot | 138 | `0b10001010` | `0x8A` |
| kilowatt_hours_per_square_meter | 137 | `0b10001001` | `0x89` |
| kilowatt_hours_reactive | 204 | `0b11001100` | `0xCC` |
| kilowatts | 48 | `0b110000` | `0x30` |
| liters | 82 | `0b1010010` | `0x52` |
| liters_per_hour | 136 | `0b10001000` | `0x88` |
| liters_per_minute | 88 | `0b1011000` | `0x58` |
| liters_per_second | 87 | `0b1010111` | `0x57` |
| lumens | 36 | `0b100100` | `0x24` |
| luxes | 37 | `0b100101` | `0x25` |
| mega_btus | 148 | `0b10010100` | `0x94` |
| megabecquerels | 224 | `0b11100000` | `0xE0` |
| megahertz | 130 | `0b10000010` | `0x82` |
| megajoules | 126 | `0b1111110` | `0x7E` |
| megajoules_per_degree_kelvin | 152 | `0b10011000` | `0x98` |
| megajoules_per_kilogram_dry_air | 150 | `0b10010110` | `0x96` |
| megajoules_per_square_foot | 140 | `0b10001100` | `0x8C` |
| megajoules_per_square_meter | 139 | `0b10001011` | `0x8B` |
| megavolt_ampere_hours | 241 | `0b11110001` | `0xF1` |
| megavolt_ampere_hours_reactive | 244 | `0b11110100` | `0xF4` |
| megavolt_amperes | 10 | `0b1010` | `0xA` |
| megavolt_amperes_reactive | 13 | `0b1101` | `0xD` |
| megavolts | 7 | `0b111` | `0x7` |
| megawatt_hours | 146 | `0b10010010` | `0x92` |
| megawatt_hours_reactive | 205 | `0b11001101` | `0xCD` |
| megawatts | 49 | `0b110001` | `0x31` |
| megohms | 123 | `0b1111011` | `0x7B` |
| meters | 31 | `0b11111` | `0x1F` |
| meters_per_hour | 164 | `0b10100100` | `0xA4` |
| meters_per_minute | 163 | `0b10100011` | `0xA3` |
| meters_per_second | 74 | `0b1001010` | `0x4A` |
| meters_per_second_per_second | 166 | `0b10100110` | `0xA6` |
| micrograms_per_cubic_meter | 219 | `0b11011011` | `0xDB` |
| micrograms_per_liter | 216 | `0b11011000` | `0xD8` |
| microgray | 227 | `0b11100011` | `0xE3` |
| micrometers | 194 | `0b11000010` | `0xC2` |
| microsiemens | 190 | `0b10111110` | `0xBE` |
| microsieverts | 230 | `0b11100110` | `0xE6` |
| microsieverts_per_hour | 231 | `0b11100111` | `0xE7` |
| miles_per_hour | 78 | `0b1001110` | `0x4E` |
| milliamperes | 2 | `0b10` | `0x2` |
| millibars | 134 | `0b10000110` | `0x86` |
| milligrams | 196 | `0b11000100` | `0xC4` |
| milligrams_per_cubic_meter | 218 | `0b11011010` | `0xDA` |
| milligrams_per_gram | 211 | `0b11010011` | `0xD3` |
| milligrams_per_kilogram | 212 | `0b11010100` | `0xD4` |
| milligrams_per_liter | 215 | `0b11010111` | `0xD7` |
| milligray | 226 | `0b11100010` | `0xE2` |
| milliliters | 197 | `0b11000101` | `0xC5` |
| milliliters_per_second | 198 | `0b11000110` | `0xC6` |
| millimeters | 30 | `0b11110` | `0x1E` |
| millimeters_of_mercury | 59 | `0b111011` | `0x3B` |
| millimeters_of_water | 206 | `0b11001110` | `0xCE` |
| millimeters_per_minute | 162 | `0b10100010` | `0xA2` |
| millimeters_per_second | 161 | `0b10100001` | `0xA1` |
| milliohms | 145 | `0b10010001` | `0x91` |
| million_standard_cubic_feet_per_day | 47809 | `0b1011101011000001` | `0xBAC1` |
| million_standard_cubic_feet_per_minute | 254 | `0b11111110` | `0xFE` |
| millirems | 47814 | `0b1011101011000110` | `0xBAC6` |
| millirems_per_hour | 47815 | `0b1011101011000111` | `0xBAC7` |
| milliseconds | 159 | `0b10011111` | `0x9F` |
| millisiemens | 202 | `0b11001010` | `0xCA` |
| millisieverts | 229 | `0b11100101` | `0xE5` |
| millivolts | 124 | `0b1111100` | `0x7C` |
| milliwatts | 132 | `0b10000100` | `0x84` |
| minutes | 72 | `0b1001000` | `0x48` |
| minutes_per_degree_kelvin | 236 | `0b11101100` | `0xEC` |
| mole_percent | 252 | `0b11111100` | `0xFC` |
| months | 68 | `0b1000100` | `0x44` |
| nanograms_per_cubic_meter | 220 | `0b11011100` | `0xDC` |
| nephelometric_turbidity_unit | 233 | `0b11101001` | `0xE9` |
| newton | 153 | `0b10011001` | `0x99` |
| newton_meters | 160 | `0b10100000` | `0xA0` |
| newton_seconds | 187 | `0b10111011` | `0xBB` |
| newtons_per_meter | 188 | `0b10111100` | `0xBC` |
| no_units | 95 | `0b1011111` | `0x5F` |
| ohm_meter_squared_per_meter | 237 | `0b11101101` | `0xED` |
| ohm_meters | 172 | `0b10101100` | `0xAC` |
| ohms | 4 | `0b100` | `0x4` |
| parts_per_billion | 97 | `0b1100001` | `0x61` |
| parts_per_million | 96 | `0b1100000` | `0x60` |
| pascal_seconds | 253 | `0b11111101` | `0xFD` |
| pascals | 53 | `0b110101` | `0x35` |
| per_hour | 131 | `0b10000011` | `0x83` |
| per_mille | 207 | `0b11001111` | `0xCF` |
| per_minute | 100 | `0b1100100` | `0x64` |
| per_second | 101 | `0b1100101` | `0x65` |
| percent | 98 | `0b1100010` | `0x62` |
| percent_obscuration_per_foot | 143 | `0b10001111` | `0x8F` |
| percent_obscuration_per_meter | 144 | `0b10010000` | `0x90` |
| percent_per_second | 99 | `0b1100011` | `0x63` |
| percent_relative_humidity | 29 | `0b11101` | `0x1D` |
| ph | 234 | `0b11101010` | `0xEA` |
| pounds_force_per_square_inch | 56 | `0b111000` | `0x38` |
| pounds_mass | 40 | `0b101000` | `0x28` |
| pounds_mass_per_day | 47812 | `0b1011101011000100` | `0xBAC4` |
| pounds_mass_per_hour | 46 | `0b101110` | `0x2E` |
| pounds_mass_per_minute | 45 | `0b101101` | `0x2D` |
| pounds_mass_per_second | 119 | `0b1110111` | `0x77` |
| power_factor | 15 | `0b1111` | `0xF` |
| psi_per_degree_fahrenheit | 102 | `0b1100110` | `0x66` |
| radians | 103 | `0b1100111` | `0x67` |
| radians_per_second | 184 | `0b10111000` | `0xB8` |
| revolutions_per_minute | 104 | `0b1101000` | `0x68` |
| seconds | 73 | `0b1001001` | `0x49` |
| siemens | 173 | `0b10101101` | `0xAD` |
| siemens_per_meter | 174 | `0b10101110` | `0xAE` |
| sieverts | 228 | `0b11100100` | `0xE4` |
| square_centimeters | 116 | `0b1110100` | `0x74` |
| square_feet | 1 | `0b1` | `0x1` |
| square_inches | 115 | `0b1110011` | `0x73` |
| square_meters | 0 | `0b0` | `0x0` |
| square_meters_per_newton | 185 | `0b10111001` | `0xB9` |
| standard_cubic_feet_per_day | 47808 | `0b1011101011000000` | `0xBAC0` |
| teslas | 175 | `0b10101111` | `0xAF` |
| therms | 21 | `0b10101` | `0x15` |
| thousand_cubic_feet_per_day | 47810 | `0b1011101011000010` | `0xBAC2` |
| thousand_standard_cubic_feet_per_day | 47811 | `0b1011101011000011` | `0xBAC3` |
| ton_hours | 22 | `0b10110` | `0x16` |
| tons | 41 | `0b101001` | `0x29` |
| tons_per_hour | 156 | `0b10011100` | `0x9C` |
| tons_refrigeration | 52 | `0b110100` | `0x34` |
| us_gallons | 83 | `0b1010011` | `0x53` |
| us_gallons_per_hour | 192 | `0b11000000` | `0xC0` |
| us_gallons_per_minute | 89 | `0b1011001` | `0x59` |
| volt_ampere_hours | 239 | `0b11101111` | `0xEF` |
| volt_ampere_hours_reactive | 242 | `0b11110010` | `0xF2` |
| volt_amperes | 8 | `0b1000` | `0x8` |
| volt_amperes_reactive | 11 | `0b1011` | `0xB` |
| volt_square_hours | 245 | `0b11110101` | `0xF5` |
| volts | 5 | `0b101` | `0x5` |
| volts_per_degree_kelvin | 176 | `0b10110000` | `0xB0` |
| volts_per_meter | 177 | `0b10110001` | `0xB1` |
| watt_hours | 18 | `0b10010` | `0x12` |
| watt_hours_per_cubic_meter | 250 | `0b11111010` | `0xFA` |
| watt_hours_reactive | 203 | `0b11001011` | `0xCB` |
| watts | 47 | `0b101111` | `0x2F` |
| watts_per_meter_per_degree_kelvin | 189 | `0b10111101` | `0xBD` |
| watts_per_square_foot | 34 | `0b100010` | `0x22` |
| watts_per_square_meter | 35 | `0b100011` | `0x23` |
| watts_per_square_meter_degree_kelvin | 141 | `0b10001101` | `0x8D` |
| webers | 178 | `0b10110010` | `0xB2` |
| weeks | 69 | `0b1000101` | `0x45` |
| years | 67 | `0b1000011` | `0x43` |

### Constants: Error Class 

Type: `:error_class`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| communication | 7 | `0b111` | `0x7` |
| device | 0 | `0b0` | `0x0` |
| object | 1 | `0b1` | `0x1` |
| property | 2 | `0b10` | `0x2` |
| resources | 3 | `0b11` | `0x3` |
| security | 4 | `0b100` | `0x4` |
| services | 5 | `0b101` | `0x5` |
| vt | 6 | `0b110` | `0x6` |

### Constants: Error Code 

Type: `:error_code`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| abort_apdu_too_long | 123 | `0b1111011` | `0x7B` |
| abort_application_exceeded_reply_time | 124 | `0b1111100` | `0x7C` |
| abort_buffer_overflow | 51 | `0b110011` | `0x33` |
| abort_insufficient_security | 135 | `0b10000111` | `0x87` |
| abort_invalid_apdu_in_this_state | 52 | `0b110100` | `0x34` |
| abort_other | 56 | `0b111000` | `0x38` |
| abort_out_of_resources | 125 | `0b1111101` | `0x7D` |
| abort_preempted_by_higher_priority_task | 53 | `0b110101` | `0x35` |
| abort_proprietary | 55 | `0b110111` | `0x37` |
| abort_security_error | 136 | `0b10001000` | `0x88` |
| abort_segmentation_not_supported | 54 | `0b110110` | `0x36` |
| abort_tsm_timeout | 126 | `0b1111110` | `0x7E` |
| abort_window_size_out_of_range | 127 | `0b1111111` | `0x7F` |
| access_denied | 85 | `0b1010101` | `0x55` |
| addressing_error | 115 | `0b1110011` | `0x73` |
| bad_destination_address | 86 | `0b1010110` | `0x56` |
| bad_destination_device_id | 87 | `0b1010111` | `0x57` |
| bad_signature | 88 | `0b1011000` | `0x58` |
| bad_source_address | 89 | `0b1011001` | `0x59` |
| bad_timestamp | 90 | `0b1011010` | `0x5A` |
| busy | 82 | `0b1010010` | `0x52` |
| cannot_use_key | 91 | `0b1011011` | `0x5B` |
| cannot_verify_message_id | 92 | `0b1011100` | `0x5C` |
| character_set_not_supported | 41 | `0b101001` | `0x29` |
| communication_disabled | 83 | `0b1010011` | `0x53` |
| configuration_in_progress | 2 | `0b10` | `0x2` |
| correct_key_revision | 93 | `0b1011101` | `0x5D` |
| cov_subscription_failed | 43 | `0b101011` | `0x2B` |
| datatype_not_supported | 47 | `0b101111` | `0x2F` |
| delete_fdt_entry_failed | 120 | `0b1111000` | `0x78` |
| destination_device_id_required | 94 | `0b1011110` | `0x5E` |
| device_busy | 3 | `0b11` | `0x3` |
| distribute_broadcast_failed | 121 | `0b1111001` | `0x79` |
| duplicate_entry | 137 | `0b10001001` | `0x89` |
| duplicate_message | 95 | `0b1011111` | `0x5F` |
| duplicate_name | 48 | `0b110000` | `0x30` |
| duplicate_object_id | 49 | `0b110001` | `0x31` |
| dynamic_creation_not_supported | 4 | `0b100` | `0x4` |
| encryption_not_configured | 96 | `0b1100000` | `0x60` |
| encryption_required | 97 | `0b1100001` | `0x61` |
| file_access_denied | 5 | `0b101` | `0x5` |
| file_full | 128 | `0b10000000` | `0x80` |
| inconsistent_configuration | 129 | `0b10000001` | `0x81` |
| inconsistent_object_type | 130 | `0b10000010` | `0x82` |
| inconsistent_parameters | 7 | `0b111` | `0x7` |
| inconsistent_selection_criterion | 8 | `0b1000` | `0x8` |
| incorrect_key | 98 | `0b1100010` | `0x62` |
| internal_error | 131 | `0b10000011` | `0x83` |
| invalid_array_index | 42 | `0b101010` | `0x2A` |
| invalid_configuration_data | 46 | `0b101110` | `0x2E` |
| invalid_datatype | 9 | `0b1001` | `0x9` |
| invalid_event_state | 73 | `0b1001001` | `0x49` |
| invalid_file_access_method | 10 | `0b1010` | `0xA` |
| invalid_file_start_position | 11 | `0b1011` | `0xB` |
| invalid_key_data | 99 | `0b1100011` | `0x63` |
| invalid_parameter_data_type | 13 | `0b1101` | `0xD` |
| invalid_tag | 57 | `0b111001` | `0x39` |
| invalid_timestamp | 14 | `0b1110` | `0xE` |
| invalid_value_in_this_state | 138 | `0b10001010` | `0x8A` |
| key_update_in_progress | 100 | `0b1100100` | `0x64` |
| list_element_not_found | 81 | `0b1010001` | `0x51` |
| log_buffer_full | 75 | `0b1001011` | `0x4B` |
| logged_value_purged | 76 | `0b1001100` | `0x4C` |
| malformed_message | 101 | `0b1100101` | `0x65` |
| message_too_long | 113 | `0b1110001` | `0x71` |
| missing_required_parameter | 16 | `0b10000` | `0x10` |
| network_down | 58 | `0b111010` | `0x3A` |
| no_alarm_configured | 74 | `0b1001010` | `0x4A` |
| no_objects_of_specified_type | 17 | `0b10001` | `0x11` |
| no_property_specified | 77 | `0b1001101` | `0x4D` |
| no_space_for_object | 18 | `0b10010` | `0x12` |
| no_space_to_add_list_element | 19 | `0b10011` | `0x13` |
| no_space_to_write_property | 20 | `0b10100` | `0x14` |
| no_vt_sessions_available | 21 | `0b10101` | `0x15` |
| not_configured | 132 | `0b10000100` | `0x84` |
| not_configured_for_triggered_logging | 78 | `0b1001110` | `0x4E` |
| not_cov_property | 44 | `0b101100` | `0x2C` |
| not_key_server | 102 | `0b1100110` | `0x66` |
| not_router_to_dnet | 110 | `0b1101110` | `0x6E` |
| object_deletion_not_permitted | 23 | `0b10111` | `0x17` |
| object_identifier_already_exists | 24 | `0b11000` | `0x18` |
| operational_problem | 25 | `0b11001` | `0x19` |
| optional_functionality_not_supported | 45 | `0b101101` | `0x2D` |
| other | 0 | `0b0` | `0x0` |
| out_of_memory | 133 | `0b10000101` | `0x85` |
| parameter_out_of_range | 80 | `0b1010000` | `0x50` |
| password_failure | 26 | `0b11010` | `0x1A` |
| property_is_not_a_list | 22 | `0b10110` | `0x16` |
| property_is_not_an_array | 50 | `0b110010` | `0x32` |
| read_access_denied | 27 | `0b11011` | `0x1B` |
| read_bdt_failed | 117 | `0b1110101` | `0x75` |
| read_fdt_failed | 119 | `0b1110111` | `0x77` |
| register_foreign_device_failed | 118 | `0b1110110` | `0x76` |
| reject_buffer_overflow | 59 | `0b111011` | `0x3B` |
| reject_inconsistent_parameters | 60 | `0b111100` | `0x3C` |
| reject_invalid_parameter_data_type | 61 | `0b111101` | `0x3D` |
| reject_invalid_tag | 62 | `0b111110` | `0x3E` |
| reject_missing_required_parameter | 63 | `0b111111` | `0x3F` |
| reject_other | 69 | `0b1000101` | `0x45` |
| reject_parameter_out_of_range | 64 | `0b1000000` | `0x40` |
| reject_proprietary | 68 | `0b1000100` | `0x44` |
| reject_too_many_arguments | 65 | `0b1000001` | `0x41` |
| reject_undefined_enumeration | 66 | `0b1000010` | `0x42` |
| reject_unrecognized_service | 67 | `0b1000011` | `0x43` |
| router_busy | 111 | `0b1101111` | `0x6F` |
| security_error | 114 | `0b1110010` | `0x72` |
| security_not_configured | 103 | `0b1100111` | `0x67` |
| service_request_denied | 29 | `0b11101` | `0x1D` |
| source_security_required | 104 | `0b1101000` | `0x68` |
| success | 84 | `0b1010100` | `0x54` |
| timeout | 30 | `0b11110` | `0x1E` |
| too_many_keys | 105 | `0b1101001` | `0x69` |
| unknown_authentication_type | 106 | `0b1101010` | `0x6A` |
| unknown_device | 70 | `0b1000110` | `0x46` |
| unknown_file_size | 122 | `0b1111010` | `0x7A` |
| unknown_key | 107 | `0b1101011` | `0x6B` |
| unknown_key_revision | 108 | `0b1101100` | `0x6C` |
| unknown_network_message | 112 | `0b1110000` | `0x70` |
| unknown_object | 31 | `0b11111` | `0x1F` |
| unknown_property | 32 | `0b100000` | `0x20` |
| unknown_route | 71 | `0b1000111` | `0x47` |
| unknown_source_message | 109 | `0b1101101` | `0x6D` |
| unknown_subscription | 79 | `0b1001111` | `0x4F` |
| unknown_vt_class | 34 | `0b100010` | `0x22` |
| unknown_vt_session | 35 | `0b100011` | `0x23` |
| unsupported_object_type | 36 | `0b100100` | `0x24` |
| value_not_initialized | 72 | `0b1001000` | `0x48` |
| value_out_of_range | 37 | `0b100101` | `0x25` |
| value_too_long | 134 | `0b10000110` | `0x86` |
| vt_session_already_closed | 38 | `0b100110` | `0x26` |
| vt_session_termination_failure | 39 | `0b100111` | `0x27` |
| write_access_denied | 40 | `0b101000` | `0x28` |
| write_bdt_failed | 116 | `0b1110100` | `0x74` |

### Constants: Event State 

Type: `:event_state`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| fault | 1 | `0b1` | `0x1` |
| high_limit | 3 | `0b11` | `0x3` |
| life_safety_alarm | 5 | `0b101` | `0x5` |
| low_limit | 4 | `0b100` | `0x4` |
| normal | 0 | `0b0` | `0x0` |
| offnormal | 2 | `0b10` | `0x2` |

### Constants: Event Transition Bit 

Type: `:event_transition_bit`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| to_fault | 1 | `0b1` | `0x1` |
| to_normal | 2 | `0b10` | `0x2` |
| to_offnormal | 0 | `0b0` | `0x0` |

### Constants: Event Type 

Type: `:event_type`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| access_event | 13 | `0b1101` | `0xD` |
| buffer_ready | 10 | `0b1010` | `0xA` |
| change_of_bitstring | 0 | `0b0` | `0x0` |
| change_of_characterstring | 17 | `0b10001` | `0x11` |
| change_of_discrete_value | 21 | `0b10101` | `0x15` |
| change_of_life_safety | 8 | `0b1000` | `0x8` |
| change_of_reliability | 19 | `0b10011` | `0x13` |
| change_of_state | 1 | `0b1` | `0x1` |
| change_of_status_flags | 18 | `0b10010` | `0x12` |
| change_of_timer | 22 | `0b10110` | `0x16` |
| change_of_value | 2 | `0b10` | `0x2` |
| command_failure | 3 | `0b11` | `0x3` |
| complex_event_type | 6 | `0b110` | `0x6` |
| double_out_of_range | 14 | `0b1110` | `0xE` |
| extended | 9 | `0b1001` | `0x9` |
| floating_limit | 4 | `0b100` | `0x4` |
| none | 20 | `0b10100` | `0x14` |
| out_of_range | 5 | `0b101` | `0x5` |
| signed_out_of_range | 15 | `0b1111` | `0xF` |
| unsigned_out_of_range | 16 | `0b10000` | `0x10` |
| unsigned_range | 11 | `0b1011` | `0xB` |

### Constants: Fault Type 

Type: `:fault_type`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| fault_characterstring | 1 | `0b1` | `0x1` |
| fault_extended | 2 | `0b10` | `0x2` |
| fault_life_safety | 3 | `0b11` | `0x3` |
| fault_listed | 7 | `0b111` | `0x7` |
| fault_out_of_range | 6 | `0b110` | `0x6` |
| fault_state | 4 | `0b100` | `0x4` |
| fault_status_flags | 5 | `0b101` | `0x5` |
| none | 0 | `0b0` | `0x0` |

### Constants: File Access Method 

Type: `:file_access_method`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| record_access | 0 | `0b0` | `0x0` |
| stream_access | 1 | `0b1` | `0x1` |

### Constants: Ip Mode 

Type: `:ip_mode`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| bbmd | 2 | `0b10` | `0x2` |
| foreign | 1 | `0b1` | `0x1` |
| normal | 0 | `0b0` | `0x0` |

### Constants: Life Safety Mode 

Type: `:life_safety_mode`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| armed | 5 | `0b101` | `0x5` |
| automatic_release_disabled | 13 | `0b1101` | `0xD` |
| default | 14 | `0b1110` | `0xE` |
| disabled | 12 | `0b1100` | `0xC` |
| disarmed | 6 | `0b110` | `0x6` |
| disconnected | 10 | `0b1010` | `0xA` |
| enabled | 11 | `0b1011` | `0xB` |
| fast | 9 | `0b1001` | `0x9` |
| manned | 3 | `0b11` | `0x3` |
| off | 0 | `0b0` | `0x0` |
| on | 1 | `0b1` | `0x1` |
| prearmed | 7 | `0b111` | `0x7` |
| slow | 8 | `0b1000` | `0x8` |
| test | 2 | `0b10` | `0x2` |
| unmanned | 4 | `0b100` | `0x4` |

### Constants: Life Safety Operation 

Type: `:life_safety_operation`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| none | 0 | `0b0` | `0x0` |
| reset | 4 | `0b100` | `0x4` |
| reset_alarm | 5 | `0b101` | `0x5` |
| reset_fault | 6 | `0b110` | `0x6` |
| silence | 1 | `0b1` | `0x1` |
| silence_audible | 2 | `0b10` | `0x2` |
| silence_visual | 3 | `0b11` | `0x3` |
| unsilence | 7 | `0b111` | `0x7` |
| unsilence_audible | 8 | `0b1000` | `0x8` |
| unsilence_visual | 9 | `0b1001` | `0x9` |

### Constants: Life Safety State 

Type: `:life_safety_state`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| abnormal | 16 | `0b10000` | `0x10` |
| active | 7 | `0b111` | `0x7` |
| alarm | 2 | `0b10` | `0x2` |
| blocked | 19 | `0b10011` | `0x13` |
| delayed | 18 | `0b10010` | `0x12` |
| duress | 14 | `0b1110` | `0xE` |
| emergency_power | 17 | `0b10001` | `0x11` |
| fault | 3 | `0b11` | `0x3` |
| fault_alarm | 5 | `0b101` | `0x5` |
| fault_pre_alarm | 4 | `0b100` | `0x4` |
| general_alarm | 21 | `0b10101` | `0x15` |
| holdup | 13 | `0b1101` | `0xD` |
| local_alarm | 20 | `0b10100` | `0x14` |
| not_ready | 6 | `0b110` | `0x6` |
| pre_alarm | 1 | `0b1` | `0x1` |
| quiet | 0 | `0b0` | `0x0` |
| supervisory | 22 | `0b10110` | `0x16` |
| tamper | 8 | `0b1000` | `0x8` |
| tamper_alarm | 15 | `0b1111` | `0xF` |
| test_active | 10 | `0b1010` | `0xA` |
| test_alarm | 9 | `0b1001` | `0x9` |
| test_fault | 11 | `0b1011` | `0xB` |
| test_fault_alarm | 12 | `0b1100` | `0xC` |
| test_supervisory | 23 | `0b10111` | `0x17` |

### Constants: Lighting In Progress 

Type: `:lighting_in_progress`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| fade_active | 1 | `0b1` | `0x1` |
| idle | 0 | `0b0` | `0x0` |
| not_controlled | 3 | `0b11` | `0x3` |
| other | 4 | `0b100` | `0x4` |
| ramp_active | 2 | `0b10` | `0x2` |

### Constants: Lighting Operation 

Type: `:lighting_operation`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| fade_to | 1 | `0b1` | `0x1` |
| none | 0 | `0b0` | `0x0` |
| ramp_to | 2 | `0b10` | `0x2` |
| step_down | 4 | `0b100` | `0x4` |
| step_off | 6 | `0b110` | `0x6` |
| step_on | 5 | `0b101` | `0x5` |
| step_up | 3 | `0b11` | `0x3` |
| stop | 10 | `0b1010` | `0xA` |
| warn | 7 | `0b111` | `0x7` |
| warn_off | 8 | `0b1000` | `0x8` |
| warn_relinquish | 9 | `0b1001` | `0x9` |

### Constants: Lighting Transition 

Type: `:lighting_transition`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| fade | 1 | `0b1` | `0x1` |
| none | 0 | `0b0` | `0x0` |
| ramp | 2 | `0b10` | `0x2` |

### Constants: Limit Enable 

Type: `:limit_enable`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| high_limit_enable | 1 | `0b1` | `0x1` |
| low_limit_enable | 0 | `0b0` | `0x0` |

### Constants: Lock Status 

Type: `:lock_status`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| lock_fault | 2 | `0b10` | `0x2` |
| locked | 0 | `0b0` | `0x0` |
| unknown | 4 | `0b100` | `0x4` |
| unlocked | 1 | `0b1` | `0x1` |
| unused | 3 | `0b11` | `0x3` |

### Constants: Log Status 

Type: `:log_status`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| buffer_purged | 1 | `0b1` | `0x1` |
| log_disabled | 0 | `0b0` | `0x0` |
| log_interrupted | 2 | `0b10` | `0x2` |

### Constants: Logging Type 

Type: `:logging_type`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| cov | 1 | `0b1` | `0x1` |
| polled | 0 | `0b0` | `0x0` |
| triggered | 2 | `0b10` | `0x2` |

### Constants: Maintenance 

Type: `:maintenance`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| need_service_inoperative | 3 | `0b11` | `0x3` |
| need_service_operational | 2 | `0b10` | `0x2` |
| none | 0 | `0b0` | `0x0` |
| periodic_test | 1 | `0b1` | `0x1` |

### Constants: Max Apdu Length Accepted 

Max APDU Length Accepted (ASHRAE 135 - 20.1.2.5 max-apdu-length-accepted)

Type: `:max_apdu_length_accepted`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| octets_1024 | 4 | `0b100` | `0x4` |
| octets_128 | 1 | `0b1` | `0x1` |
| octets_1476 | 5 | `0b101` | `0x5` |
| octets_206 | 2 | `0b10` | `0x2` |
| octets_480 | 3 | `0b11` | `0x3` |
| octets_50 | 0 | `0b0` | `0x0` |

### Constants: Max Apdu Length Accepted Value 

Max APDU Length Accepted (ASHRAE 135 - 20.1.2.5 max-apdu-length-accepted) - Values are the real APDU max size

Type: `:max_apdu_length_accepted_value`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| octets_1024 | 1024 | `0b10000000000` | `0x400` |
| octets_128 | 128 | `0b10000000` | `0x80` |
| octets_1476 | 1476 | `0b10111000100` | `0x5C4` |
| octets_206 | 206 | `0b11001110` | `0xCE` |
| octets_480 | 480 | `0b111100000` | `0x1E0` |
| octets_50 | 50 | `0b110010` | `0x32` |

### Constants: Max Segments Accepted 

Max Segments Accepted (ASHRAE 135 - 20.1.2.4 max-segments-accepted)

Type: `:max_segments_accepted`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| segments_0 | 0 | `0b0` | `0x0` |
| segments_16 | 4 | `0b100` | `0x4` |
| segments_2 | 1 | `0b1` | `0x1` |
| segments_32 | 5 | `0b101` | `0x5` |
| segments_4 | 2 | `0b10` | `0x2` |
| segments_64 | 6 | `0b110` | `0x6` |
| segments_65 | 7 | `0b111` | `0x7` |
| segments_8 | 3 | `0b11` | `0x3` |

### Constants: Network Layer Message Type 

Network Layer Message Type (ASHRAE 135 - 6.2.4 Network Layer Message Type)

Type: `:network_layer_message_type`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| challenge_request | 10 | `0b1010` | `0xA` |
| disconnect_connection_to_network | 9 | `0b1001` | `0x9` |
| establish_connection_to_network | 8 | `0b1000` | `0x8` |
| i_am_router_to_network | 1 | `0b1` | `0x1` |
| i_could_be_router_to_network | 2 | `0b10` | `0x2` |
| initialize_routing_table | 6 | `0b110` | `0x6` |
| initialize_routing_table_ack | 7 | `0b111` | `0x7` |
| network_number_is | 19 | `0b10011` | `0x13` |
| reject_message_to_network | 3 | `0b11` | `0x3` |
| request_key_update | 13 | `0b1101` | `0xD` |
| request_master_key | 16 | `0b10000` | `0x10` |
| reserved_area_start | 20 | `0b10100` | `0x14` |
| router_available_to_network | 5 | `0b101` | `0x5` |
| router_busy_to_network | 4 | `0b100` | `0x4` |
| security_payload | 11 | `0b1011` | `0xB` |
| security_response | 12 | `0b1100` | `0xC` |
| set_master_key | 17 | `0b10001` | `0x11` |
| update_distribution_key | 15 | `0b1111` | `0xF` |
| update_key_set | 14 | `0b1110` | `0xE` |
| vendor_proprietary_area_start | 128 | `0b10000000` | `0x80` |
| what_is_network_number | 18 | `0b10010` | `0x12` |
| who_is_router_to_network | 0 | `0b0` | `0x0` |

### Constants: Network Number Quality 

Type: `:network_number_quality`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| configured | 3 | `0b11` | `0x3` |
| learned | 1 | `0b1` | `0x1` |
| learned_configured | 2 | `0b10` | `0x2` |
| unknown | 0 | `0b0` | `0x0` |

### Constants: Network Port Command 

Type: `:network_port_command`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| discard_changes | 1 | `0b1` | `0x1` |
| disconnect | 6 | `0b110` | `0x6` |
| idle | 0 | `0b0` | `0x0` |
| renew_dhcp | 4 | `0b100` | `0x4` |
| renew_fd_registration | 2 | `0b10` | `0x2` |
| restart_autonegotiation | 5 | `0b101` | `0x5` |
| restart_port | 7 | `0b111` | `0x7` |
| restart_slave_discovery | 3 | `0b11` | `0x3` |

### Constants: Network Type 

Type: `:network_type`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| arcnet | 1 | `0b1` | `0x1` |
| ethernet | 0 | `0b0` | `0x0` |
| ipv4 | 5 | `0b101` | `0x5` |
| ipv6 | 9 | `0b1001` | `0x9` |
| lontalk | 4 | `0b100` | `0x4` |
| mstp | 2 | `0b10` | `0x2` |
| ptp | 3 | `0b11` | `0x3` |
| serial | 10 | `0b1010` | `0xA` |
| virtual | 7 | `0b111` | `0x7` |
| zigbee | 6 | `0b110` | `0x6` |

### Constants: Node Type 

Type: `:node_type`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| area | 5 | `0b101` | `0x5` |
| building | 13 | `0b1101` | `0xD` |
| collection | 8 | `0b1000` | `0x8` |
| device | 3 | `0b11` | `0x3` |
| equipment | 6 | `0b110` | `0x6` |
| floor | 14 | `0b1110` | `0xE` |
| functional | 10 | `0b1010` | `0xA` |
| member | 18 | `0b10010` | `0x12` |
| module | 16 | `0b10000` | `0x10` |
| network | 2 | `0b10` | `0x2` |
| organizational | 4 | `0b100` | `0x4` |
| other | 11 | `0b1011` | `0xB` |
| point | 7 | `0b111` | `0x7` |
| property | 9 | `0b1001` | `0x9` |
| protocol | 19 | `0b10011` | `0x13` |
| room | 20 | `0b10100` | `0x14` |
| section | 15 | `0b1111` | `0xF` |
| subsystem | 12 | `0b1100` | `0xC` |
| system | 1 | `0b1` | `0x1` |
| tree | 17 | `0b10001` | `0x11` |
| unknown | 0 | `0b0` | `0x0` |
| zone | 21 | `0b10101` | `0x15` |

### Constants: Notify Type 

Type: `:notify_type`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| ack_notification | 2 | `0b10` | `0x2` |
| alarm | 0 | `0b0` | `0x0` |
| event | 1 | `0b1` | `0x1` |

### Constants: Npdu Control Bit 

NPDU Control Bits (ASHRAE 135 - 6.2.2 Network Layer Protocol Control Information)

Type: `:npdu_control_bit`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| destination_specified | 32 | `0b100000` | `0x20` |
| expecting_reply | 4 | `0b100` | `0x4` |
| network_layer_message | 128 | `0b10000000` | `0x80` |
| source_specified | 8 | `0b1000` | `0x8` |

### Constants: Npdu Control Priority 

NPDU Control Priority (ASHRAE 135 - 6.2.2 Network Layer Protocol Control Information)

Type: `:npdu_control_priority`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| critical_equipment_message | 2 | `0b10` | `0x2` |
| life_safety_message | 3 | `0b11` | `0x3` |
| normal | 0 | `0b0` | `0x0` |
| urgent | 1 | `0b1` | `0x1` |

### Constants: Object Type 

Type: `:object_type`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| access_credential | 32 | `0b100000` | `0x20` |
| access_door | 30 | `0b11110` | `0x1E` |
| access_point | 33 | `0b100001` | `0x21` |
| access_rights | 34 | `0b100010` | `0x22` |
| access_user | 35 | `0b100011` | `0x23` |
| access_zone | 36 | `0b100100` | `0x24` |
| accumulator | 23 | `0b10111` | `0x17` |
| alert_enrollment | 52 | `0b110100` | `0x34` |
| analog_input | 0 | `0b0` | `0x0` |
| analog_output | 1 | `0b1` | `0x1` |
| analog_value | 2 | `0b10` | `0x2` |
| averaging | 18 | `0b10010` | `0x12` |
| binary_input | 3 | `0b11` | `0x3` |
| binary_lighting_output | 55 | `0b110111` | `0x37` |
| binary_output | 4 | `0b100` | `0x4` |
| binary_value | 5 | `0b101` | `0x5` |
| bitstring_value | 39 | `0b100111` | `0x27` |
| calendar | 6 | `0b110` | `0x6` |
| channel | 53 | `0b110101` | `0x35` |
| character_string_value | 40 | `0b101000` | `0x28` |
| command | 7 | `0b111` | `0x7` |
| credential_data_input | 37 | `0b100101` | `0x25` |
| date_pattern_value | 41 | `0b101001` | `0x29` |
| date_value | 42 | `0b101010` | `0x2A` |
| datetime_pattern_value | 43 | `0b101011` | `0x2B` |
| datetime_value | 44 | `0b101100` | `0x2C` |
| device | 8 | `0b1000` | `0x8` |
| elevator_group | 57 | `0b111001` | `0x39` |
| escalator | 58 | `0b111010` | `0x3A` |
| event_enrollment | 9 | `0b1001` | `0x9` |
| event_log | 25 | `0b11001` | `0x19` |
| file | 10 | `0b1010` | `0xA` |
| global_group | 26 | `0b11010` | `0x1A` |
| group | 11 | `0b1011` | `0xB` |
| integer_value | 45 | `0b101101` | `0x2D` |
| large_analog_value | 46 | `0b101110` | `0x2E` |
| life_safety_point | 21 | `0b10101` | `0x15` |
| life_safety_zone | 22 | `0b10110` | `0x16` |
| lift | 59 | `0b111011` | `0x3B` |
| lighting_output | 54 | `0b110110` | `0x36` |
| load_control | 28 | `0b11100` | `0x1C` |
| loop | 12 | `0b1100` | `0xC` |
| multi_state_input | 13 | `0b1101` | `0xD` |
| multi_state_output | 14 | `0b1110` | `0xE` |
| multi_state_value | 19 | `0b10011` | `0x13` |
| network_port | 56 | `0b111000` | `0x38` |
| network_security | 38 | `0b100110` | `0x26` |
| notification_class | 15 | `0b1111` | `0xF` |
| notification_forwarder | 51 | `0b110011` | `0x33` |
| octet_string_value | 47 | `0b101111` | `0x2F` |
| positive_integer_value | 48 | `0b110000` | `0x30` |
| program | 16 | `0b10000` | `0x10` |
| pulse_converter | 24 | `0b11000` | `0x18` |
| schedule | 17 | `0b10001` | `0x11` |
| structured_view | 29 | `0b11101` | `0x1D` |
| time_pattern_value | 49 | `0b110001` | `0x31` |
| time_value | 50 | `0b110010` | `0x32` |
| timer | 31 | `0b11111` | `0x1F` |
| trend_log | 20 | `0b10100` | `0x14` |
| trend_log_multiple | 27 | `0b11011` | `0x1B` |

### Constants: Object Types Supported 

Type: `:object_types_supported`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| access_credential | 32 | `0b100000` | `0x20` |
| access_door | 30 | `0b11110` | `0x1E` |
| access_point | 33 | `0b100001` | `0x21` |
| access_rights | 34 | `0b100010` | `0x22` |
| access_user | 35 | `0b100011` | `0x23` |
| access_zone | 36 | `0b100100` | `0x24` |
| accumulator | 23 | `0b10111` | `0x17` |
| alert_enrollment | 52 | `0b110100` | `0x34` |
| analog_input | 0 | `0b0` | `0x0` |
| analog_output | 1 | `0b1` | `0x1` |
| analog_value | 2 | `0b10` | `0x2` |
| averaging | 18 | `0b10010` | `0x12` |
| binary_input | 3 | `0b11` | `0x3` |
| binary_lighting_output | 55 | `0b110111` | `0x37` |
| binary_output | 4 | `0b100` | `0x4` |
| binary_value | 5 | `0b101` | `0x5` |
| bitstring_value | 39 | `0b100111` | `0x27` |
| calendar | 6 | `0b110` | `0x6` |
| channel | 53 | `0b110101` | `0x35` |
| character_string_value | 40 | `0b101000` | `0x28` |
| command | 7 | `0b111` | `0x7` |
| credential_data_input | 37 | `0b100101` | `0x25` |
| date_pattern_value | 41 | `0b101001` | `0x29` |
| date_value | 42 | `0b101010` | `0x2A` |
| datetime_pattern_value | 43 | `0b101011` | `0x2B` |
| datetime_value | 44 | `0b101100` | `0x2C` |
| device | 8 | `0b1000` | `0x8` |
| elevator_group | 57 | `0b111001` | `0x39` |
| escalator | 58 | `0b111010` | `0x3A` |
| event_enrollment | 9 | `0b1001` | `0x9` |
| event_log | 25 | `0b11001` | `0x19` |
| file | 10 | `0b1010` | `0xA` |
| global_group | 26 | `0b11010` | `0x1A` |
| group | 11 | `0b1011` | `0xB` |
| integer_value | 45 | `0b101101` | `0x2D` |
| large_analog_value | 46 | `0b101110` | `0x2E` |
| life_safety_point | 21 | `0b10101` | `0x15` |
| life_safety_zone | 22 | `0b10110` | `0x16` |
| lift | 59 | `0b111011` | `0x3B` |
| lighting_output | 54 | `0b110110` | `0x36` |
| load_control | 28 | `0b11100` | `0x1C` |
| loop | 12 | `0b1100` | `0xC` |
| multi_state_input | 13 | `0b1101` | `0xD` |
| multi_state_output | 14 | `0b1110` | `0xE` |
| multi_state_value | 19 | `0b10011` | `0x13` |
| network_port | 56 | `0b111000` | `0x38` |
| network_security | 38 | `0b100110` | `0x26` |
| notification_class | 15 | `0b1111` | `0xF` |
| notification_forwarder | 51 | `0b110011` | `0x33` |
| octet_string_value | 47 | `0b101111` | `0x2F` |
| positive_integer_value | 48 | `0b110000` | `0x30` |
| program | 16 | `0b10000` | `0x10` |
| pulse_converter | 24 | `0b11000` | `0x18` |
| schedule | 17 | `0b10001` | `0x11` |
| structured_view | 29 | `0b11101` | `0x1D` |
| time_pattern_value | 49 | `0b110001` | `0x31` |
| time_value | 50 | `0b110010` | `0x32` |
| timer | 31 | `0b11111` | `0x1F` |
| trend_log | 20 | `0b10100` | `0x14` |
| trend_log_multiple | 27 | `0b11011` | `0x1B` |

### Constants: Pdu Confirmed Request Bit 

PDU Confirmed Request PDU Bits (ASHRAE 135 - 20.1.2.11 Format of the BACnet-Confirmed-Request-PDU)

Type: `:pdu_confirmed_request_bit`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| more_follows | 4 | `0b100` | `0x4` |
| segmented_message | 8 | `0b1000` | `0x8` |
| segmented_response_accepted | 2 | `0b10` | `0x2` |

### Constants: Pdu Segment Ack Bit 

PDU Segment ACK Bits (ASHRAE 135 - 20.1.6.6 Format of the BACnet-SegmentACK-PDU)

Type: `:pdu_segment_ack_bit`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| negative_ack | 2 | `0b10` | `0x2` |
| server | 1 | `0b1` | `0x1` |

### Constants: Pdu Type 

PDU Types (ASHRAE 135 - 21 FORMAL DESCRIPTION OF APPLICATION PROTOCOL DATA UNITS)

Type: `:pdu_type`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| abort | 7 | `0b111` | `0x7` |
| complex_ack | 3 | `0b11` | `0x3` |
| confirmed_request | 0 | `0b0` | `0x0` |
| error | 5 | `0b101` | `0x5` |
| reject | 6 | `0b110` | `0x6` |
| segment_ack | 4 | `0b100` | `0x4` |
| simple_ack | 2 | `0b10` | `0x2` |
| unconfirmed_request | 1 | `0b1` | `0x1` |

### Constants: Polarity 

Type: `:polarity`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| normal | 0 | `0b0` | `0x0` |
| reverse | 1 | `0b1` | `0x1` |

### Constants: Program Error 

Type: `:program_error`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| internal | 2 | `0b10` | `0x2` |
| load_failed | 1 | `0b1` | `0x1` |
| normal | 0 | `0b0` | `0x0` |
| other | 4 | `0b100` | `0x4` |
| program | 3 | `0b11` | `0x3` |

### Constants: Program Request 

Type: `:program_request`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| halt | 3 | `0b11` | `0x3` |
| load | 1 | `0b1` | `0x1` |
| ready | 0 | `0b0` | `0x0` |
| restart | 4 | `0b100` | `0x4` |
| run | 2 | `0b10` | `0x2` |
| unload | 5 | `0b101` | `0x5` |

### Constants: Program State 

Type: `:program_state`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| halted | 4 | `0b100` | `0x4` |
| idle | 0 | `0b0` | `0x0` |
| loading | 1 | `0b1` | `0x1` |
| running | 2 | `0b10` | `0x2` |
| unloading | 5 | `0b101` | `0x5` |
| waiting | 3 | `0b11` | `0x3` |

### Constants: Property Identifier 

Type: `:property_identifier`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| absentee_limit | 244 | `0b11110100` | `0xF4` |
| accepted_modes | 175 | `0b10101111` | `0xAF` |
| access_alarm_events | 245 | `0b11110101` | `0xF5` |
| access_doors | 246 | `0b11110110` | `0xF6` |
| access_event | 247 | `0b11110111` | `0xF7` |
| access_event_authentication_factor | 248 | `0b11111000` | `0xF8` |
| access_event_credential | 249 | `0b11111001` | `0xF9` |
| access_event_tag | 322 | `0b101000010` | `0x142` |
| access_event_time | 250 | `0b11111010` | `0xFA` |
| access_transaction_events | 251 | `0b11111011` | `0xFB` |
| accompaniment | 252 | `0b11111100` | `0xFC` |
| accompaniment_time | 253 | `0b11111101` | `0xFD` |
| ack_required | 1 | `0b1` | `0x1` |
| acked_transitions | 0 | `0b0` | `0x0` |
| action | 2 | `0b10` | `0x2` |
| action_text | 3 | `0b11` | `0x3` |
| activation_time | 254 | `0b11111110` | `0xFE` |
| active_authentication_policy | 255 | `0b11111111` | `0xFF` |
| active_cov_multiple_subscriptions | 481 | `0b111100001` | `0x1E1` |
| active_cov_subscriptions | 152 | `0b10011000` | `0x98` |
| active_text | 4 | `0b100` | `0x4` |
| active_vt_sessions | 5 | `0b101` | `0x5` |
| actual_shed_level | 212 | `0b11010100` | `0xD4` |
| adjust_value | 176 | `0b10110000` | `0xB0` |
| alarm_value | 6 | `0b110` | `0x6` |
| alarm_values | 7 | `0b111` | `0x7` |
| align_intervals | 193 | `0b11000001` | `0xC1` |
| all | 8 | `0b1000` | `0x8` |
| all_writes_successful | 9 | `0b1001` | `0x9` |
| allow_group_delay_inhibit | 365 | `0b101101101` | `0x16D` |
| apdu_length | 399 | `0b110001111` | `0x18F` |
| apdu_segment_timeout | 10 | `0b1010` | `0xA` |
| apdu_timeout | 11 | `0b1011` | `0xB` |
| application_software_version | 12 | `0b1100` | `0xC` |
| archive | 13 | `0b1101` | `0xD` |
| assigned_access_rights | 256 | `0b100000000` | `0x100` |
| assigned_landing_calls | 447 | `0b110111111` | `0x1BF` |
| attempted_samples | 124 | `0b1111100` | `0x7C` |
| authentication_factors | 257 | `0b100000001` | `0x101` |
| authentication_policy_list | 258 | `0b100000010` | `0x102` |
| authentication_policy_names | 259 | `0b100000011` | `0x103` |
| authentication_status | 260 | `0b100000100` | `0x104` |
| authorization_exemptions | 364 | `0b101101100` | `0x16C` |
| authorization_mode | 261 | `0b100000101` | `0x105` |
| auto_slave_discovery | 169 | `0b10101001` | `0xA9` |
| average_value | 125 | `0b1111101` | `0x7D` |
| backup_and_restore_state | 338 | `0b101010010` | `0x152` |
| backup_failure_timeout | 153 | `0b10011001` | `0x99` |
| backup_preparation_time | 339 | `0b101010011` | `0x153` |
| bacnet_ip_global_address | 407 | `0b110010111` | `0x197` |
| bacnet_ip_mode | 408 | `0b110011000` | `0x198` |
| bacnet_ip_multicast_address | 409 | `0b110011001` | `0x199` |
| bacnet_ip_nat_traversal | 410 | `0b110011010` | `0x19A` |
| bacnet_ip_udp_port | 412 | `0b110011100` | `0x19C` |
| bacnet_ipv6_mode | 435 | `0b110110011` | `0x1B3` |
| bacnet_ipv6_multicast_address | 440 | `0b110111000` | `0x1B8` |
| bacnet_ipv6_udp_port | 438 | `0b110110110` | `0x1B6` |
| bbmd_accept_fd_registrations | 413 | `0b110011101` | `0x19D` |
| bbmd_broadcast_distribution_table | 414 | `0b110011110` | `0x19E` |
| bbmd_foreign_device_table | 415 | `0b110011111` | `0x19F` |
| belongs_to | 262 | `0b100000110` | `0x106` |
| bias | 14 | `0b1110` | `0xE` |
| bit_mask | 342 | `0b101010110` | `0x156` |
| bit_text | 343 | `0b101010111` | `0x157` |
| blink_warn_enable | 373 | `0b101110101` | `0x175` |
| buffer_size | 126 | `0b1111110` | `0x7E` |
| car_assigned_direction | 448 | `0b111000000` | `0x1C0` |
| car_door_command | 449 | `0b111000001` | `0x1C1` |
| car_door_status | 450 | `0b111000010` | `0x1C2` |
| car_door_text | 451 | `0b111000011` | `0x1C3` |
| car_door_zone | 452 | `0b111000100` | `0x1C4` |
| car_drive_status | 453 | `0b111000101` | `0x1C5` |
| car_load | 454 | `0b111000110` | `0x1C6` |
| car_load_units | 455 | `0b111000111` | `0x1C7` |
| car_mode | 456 | `0b111001000` | `0x1C8` |
| car_moving_direction | 457 | `0b111001001` | `0x1C9` |
| car_position | 458 | `0b111001010` | `0x1CA` |
| change_of_state_count | 15 | `0b1111` | `0xF` |
| change_of_state_time | 16 | `0b10000` | `0x10` |
| changes_pending | 416 | `0b110100000` | `0x1A0` |
| channel_number | 366 | `0b101101110` | `0x16E` |
| client_cov_increment | 127 | `0b1111111` | `0x7F` |
| command | 417 | `0b110100001` | `0x1A1` |
| command_time_array | 430 | `0b110101110` | `0x1AE` |
| configuration_files | 154 | `0b10011010` | `0x9A` |
| control_groups | 367 | `0b101101111` | `0x16F` |
| controlled_variable_reference | 19 | `0b10011` | `0x13` |
| controlled_variable_units | 20 | `0b10100` | `0x14` |
| controlled_variable_value | 21 | `0b10101` | `0x15` |
| count | 177 | `0b10110001` | `0xB1` |
| count_before_change | 178 | `0b10110010` | `0xB2` |
| count_change_time | 179 | `0b10110011` | `0xB3` |
| cov_increment | 22 | `0b10110` | `0x16` |
| cov_period | 180 | `0b10110100` | `0xB4` |
| cov_resubscription_interval | 128 | `0b10000000` | `0x80` |
| covu_period | 349 | `0b101011101` | `0x15D` |
| covu_recipients | 350 | `0b101011110` | `0x15E` |
| credential_disable | 263 | `0b100000111` | `0x107` |
| credential_status | 264 | `0b100001000` | `0x108` |
| credentials | 265 | `0b100001001` | `0x109` |
| credentials_in_zone | 266 | `0b100001010` | `0x10A` |
| current_command_priority | 431 | `0b110101111` | `0x1AF` |
| database_revision | 155 | `0b10011011` | `0x9B` |
| date_list | 23 | `0b10111` | `0x17` |
| daylight_savings_status | 24 | `0b11000` | `0x18` |
| days_remaining | 267 | `0b100001011` | `0x10B` |
| deadband | 25 | `0b11001` | `0x19` |
| default_fade_time | 374 | `0b101110110` | `0x176` |
| default_ramp_rate | 375 | `0b101110111` | `0x177` |
| default_step_increment | 376 | `0b101111000` | `0x178` |
| default_subordinate_relationship | 490 | `0b111101010` | `0x1EA` |
| default_timeout | 393 | `0b110001001` | `0x189` |
| deployed_profile_location | 484 | `0b111100100` | `0x1E4` |
| derivative_constant | 26 | `0b11010` | `0x1A` |
| derivative_constant_units | 27 | `0b11011` | `0x1B` |
| description | 28 | `0b11100` | `0x1C` |
| description_of_halt | 29 | `0b11101` | `0x1D` |
| device_address_binding | 30 | `0b11110` | `0x1E` |
| device_type | 31 | `0b11111` | `0x1F` |
| direct_reading | 156 | `0b10011100` | `0x9C` |
| distribution_key_revision | 328 | `0b101001000` | `0x148` |
| do_not_hide | 329 | `0b101001001` | `0x149` |
| door_alarm_state | 226 | `0b11100010` | `0xE2` |
| door_extended_pulse_time | 227 | `0b11100011` | `0xE3` |
| door_members | 228 | `0b11100100` | `0xE4` |
| door_open_too_long_time | 229 | `0b11100101` | `0xE5` |
| door_pulse_time | 230 | `0b11100110` | `0xE6` |
| door_status | 231 | `0b11100111` | `0xE7` |
| door_unlock_delay_time | 232 | `0b11101000` | `0xE8` |
| duty_window | 213 | `0b11010101` | `0xD5` |
| effective_period | 32 | `0b100000` | `0x20` |
| egress_active | 386 | `0b110000010` | `0x182` |
| egress_time | 377 | `0b101111001` | `0x179` |
| elapsed_active_time | 33 | `0b100001` | `0x21` |
| elevator_group | 459 | `0b111001011` | `0x1CB` |
| enable | 133 | `0b10000101` | `0x85` |
| energy_meter | 460 | `0b111001100` | `0x1CC` |
| energy_meter_ref | 461 | `0b111001101` | `0x1CD` |
| entry_points | 268 | `0b100001100` | `0x10C` |
| error_limit | 34 | `0b100010` | `0x22` |
| escalator_mode | 462 | `0b111001110` | `0x1CE` |
| event_algorithm_inhibit | 354 | `0b101100010` | `0x162` |
| event_algorithm_inhibit_ref | 355 | `0b101100011` | `0x163` |
| event_detection_enable | 353 | `0b101100001` | `0x161` |
| event_enable | 35 | `0b100011` | `0x23` |
| event_message_texts | 351 | `0b101011111` | `0x15F` |
| event_message_texts_config | 352 | `0b101100000` | `0x160` |
| event_parameters | 83 | `0b1010011` | `0x53` |
| event_state | 36 | `0b100100` | `0x24` |
| event_timestamps | 130 | `0b10000010` | `0x82` |
| event_type | 37 | `0b100101` | `0x25` |
| exception_schedule | 38 | `0b100110` | `0x26` |
| execution_delay | 368 | `0b101110000` | `0x170` |
| exit_points | 269 | `0b100001101` | `0x10D` |
| expected_shed_level | 214 | `0b11010110` | `0xD6` |
| expiration_time | 270 | `0b100001110` | `0x10E` |
| extended_time_enable | 271 | `0b100001111` | `0x10F` |
| failed_attempt_events | 272 | `0b100010000` | `0x110` |
| failed_attempts | 273 | `0b100010001` | `0x111` |
| failed_attempts_time | 274 | `0b100010010` | `0x112` |
| fault_high_limit | 388 | `0b110000100` | `0x184` |
| fault_low_limit | 389 | `0b110000101` | `0x185` |
| fault_parameters | 358 | `0b101100110` | `0x166` |
| fault_signals | 463 | `0b111001111` | `0x1CF` |
| fault_type | 359 | `0b101100111` | `0x167` |
| fault_values | 39 | `0b100111` | `0x27` |
| fd_bbmd_address | 418 | `0b110100010` | `0x1A2` |
| fd_subscription_lifetime | 419 | `0b110100011` | `0x1A3` |
| feedback_value | 40 | `0b101000` | `0x28` |
| file_access_method | 41 | `0b101001` | `0x29` |
| file_size | 42 | `0b101010` | `0x2A` |
| file_type | 43 | `0b101011` | `0x2B` |
| firmware_revision | 44 | `0b101100` | `0x2C` |
| floor_text | 464 | `0b111010000` | `0x1D0` |
| full_duty_baseline | 215 | `0b11010111` | `0xD7` |
| global_identifier | 323 | `0b101000011` | `0x143` |
| group_id | 465 | `0b111010001` | `0x1D1` |
| group_member_names | 346 | `0b101011010` | `0x15A` |
| group_members | 345 | `0b101011001` | `0x159` |
| group_mode | 467 | `0b111010011` | `0x1D3` |
| high_limit | 45 | `0b101101` | `0x2D` |
| higher_deck | 468 | `0b111010100` | `0x1D4` |
| in_process | 47 | `0b101111` | `0x2F` |
| in_progress | 378 | `0b101111010` | `0x17A` |
| inactive_text | 46 | `0b101110` | `0x2E` |
| initial_timeout | 394 | `0b110001010` | `0x18A` |
| input_reference | 181 | `0b10110101` | `0xB5` |
| installation_id | 469 | `0b111010101` | `0x1D5` |
| instance_of | 48 | `0b110000` | `0x30` |
| instantaneous_power | 379 | `0b101111011` | `0x17B` |
| integral_constant | 49 | `0b110001` | `0x31` |
| integral_constant_units | 50 | `0b110010` | `0x32` |
| interface_value | 387 | `0b110000011` | `0x183` |
| interval_offset | 195 | `0b11000011` | `0xC3` |
| ip_address | 400 | `0b110010000` | `0x190` |
| ip_default_gateway | 401 | `0b110010001` | `0x191` |
| ip_dhcp_enable | 402 | `0b110010010` | `0x192` |
| ip_dhcp_lease_time | 403 | `0b110010011` | `0x193` |
| ip_dhcp_lease_time_remaining | 404 | `0b110010100` | `0x194` |
| ip_dhcp_server | 405 | `0b110010101` | `0x195` |
| ip_dns_server | 406 | `0b110010110` | `0x196` |
| ip_subnet_mask | 411 | `0b110011011` | `0x19B` |
| ipv6_address | 436 | `0b110110100` | `0x1B4` |
| ipv6_auto_addressing_enable | 442 | `0b110111010` | `0x1BA` |
| ipv6_default_gateway | 439 | `0b110110111` | `0x1B7` |
| ipv6_dhcp_lease_time | 443 | `0b110111011` | `0x1BB` |
| ipv6_dhcp_lease_time_remaining | 444 | `0b110111100` | `0x1BC` |
| ipv6_dhcp_server | 445 | `0b110111101` | `0x1BD` |
| ipv6_dns_server | 441 | `0b110111001` | `0x1B9` |
| ipv6_prefix_length | 437 | `0b110110101` | `0x1B5` |
| ipv6_zone_index | 446 | `0b110111110` | `0x1BE` |
| is_utc | 344 | `0b101011000` | `0x158` |
| key_sets | 330 | `0b101001010` | `0x14A` |
| landing_call_control | 471 | `0b111010111` | `0x1D7` |
| landing_calls | 470 | `0b111010110` | `0x1D6` |
| landing_door_status | 472 | `0b111011000` | `0x1D8` |
| last_access_event | 275 | `0b100010011` | `0x113` |
| last_access_point | 276 | `0b100010100` | `0x114` |
| last_command_time | 432 | `0b110110000` | `0x1B0` |
| last_credential_added | 277 | `0b100010101` | `0x115` |
| last_credential_added_time | 278 | `0b100010110` | `0x116` |
| last_credential_removed | 279 | `0b100010111` | `0x117` |
| last_credential_removed_time | 280 | `0b100011000` | `0x118` |
| last_key_server | 331 | `0b101001011` | `0x14B` |
| last_notify_record | 173 | `0b10101101` | `0xAD` |
| last_priority | 369 | `0b101110001` | `0x171` |
| last_restart_reason | 196 | `0b11000100` | `0xC4` |
| last_restore_time | 157 | `0b10011101` | `0x9D` |
| last_state_change | 395 | `0b110001011` | `0x18B` |
| last_use_time | 281 | `0b100011001` | `0x119` |
| life_safety_alarm_values | 166 | `0b10100110` | `0xA6` |
| lighting_command | 380 | `0b101111100` | `0x17C` |
| lighting_command_default_priority | 381 | `0b101111101` | `0x17D` |
| limit_enable | 52 | `0b110100` | `0x34` |
| limit_monitoring_interval | 182 | `0b10110110` | `0xB6` |
| link_speed | 420 | `0b110100100` | `0x1A4` |
| link_speed_autonegotiate | 422 | `0b110100110` | `0x1A6` |
| link_speeds | 421 | `0b110100101` | `0x1A5` |
| list_of_group_members | 53 | `0b110101` | `0x35` |
| list_of_object_property_references | 54 | `0b110110` | `0x36` |
| local_date | 56 | `0b111000` | `0x38` |
| local_forwarding_only | 360 | `0b101101000` | `0x168` |
| local_time | 57 | `0b111001` | `0x39` |
| location | 58 | `0b111010` | `0x3A` |
| lock_status | 233 | `0b11101001` | `0xE9` |
| lockout | 282 | `0b100011010` | `0x11A` |
| lockout_relinquish_time | 283 | `0b100011011` | `0x11B` |
| log_buffer | 131 | `0b10000011` | `0x83` |
| log_device_object_property | 132 | `0b10000100` | `0x84` |
| log_interval | 134 | `0b10000110` | `0x86` |
| logging_object | 183 | `0b10110111` | `0xB7` |
| logging_record | 184 | `0b10111000` | `0xB8` |
| logging_type | 197 | `0b11000101` | `0xC5` |
| low_diff_limit | 390 | `0b110000110` | `0x186` |
| low_limit | 59 | `0b111011` | `0x3B` |
| lower_deck | 473 | `0b111011001` | `0x1D9` |
| mac_address | 423 | `0b110100111` | `0x1A7` |
| machine_room_id | 474 | `0b111011010` | `0x1DA` |
| maintenance_required | 158 | `0b10011110` | `0x9E` |
| making_car_call | 475 | `0b111011011` | `0x1DB` |
| manipulated_variable_reference | 60 | `0b111100` | `0x3C` |
| manual_slave_address_binding | 170 | `0b10101010` | `0xAA` |
| masked_alarm_values | 234 | `0b11101010` | `0xEA` |
| max_actual_value | 382 | `0b101111110` | `0x17E` |
| max_apdu_length_accepted | 62 | `0b111110` | `0x3E` |
| max_failed_attempts | 285 | `0b100011101` | `0x11D` |
| max_info_frames | 63 | `0b111111` | `0x3F` |
| max_master | 64 | `0b1000000` | `0x40` |
| max_output | 61 | `0b111101` | `0x3D` |
| max_present_value | 65 | `0b1000001` | `0x41` |
| max_segments_accepted | 167 | `0b10100111` | `0xA7` |
| max_value | 135 | `0b10000111` | `0x87` |
| max_value_timestamp | 149 | `0b10010101` | `0x95` |
| member_of | 159 | `0b10011111` | `0x9F` |
| member_status_flags | 347 | `0b101011011` | `0x15B` |
| members | 286 | `0b100011110` | `0x11E` |
| min_actual_value | 383 | `0b101111111` | `0x17F` |
| min_off_time | 66 | `0b1000010` | `0x42` |
| min_on_time | 67 | `0b1000011` | `0x43` |
| min_output | 68 | `0b1000100` | `0x44` |
| min_present_value | 69 | `0b1000101` | `0x45` |
| min_value | 136 | `0b10001000` | `0x88` |
| min_value_timestamp | 150 | `0b10010110` | `0x96` |
| mode | 160 | `0b10100000` | `0xA0` |
| model_name | 70 | `0b1000110` | `0x46` |
| modification_date | 71 | `0b1000111` | `0x47` |
| muster_point | 287 | `0b100011111` | `0x11F` |
| negative_access_rules | 288 | `0b100100000` | `0x120` |
| network_access_security_policies | 332 | `0b101001100` | `0x14C` |
| network_interface_name | 424 | `0b110101000` | `0x1A8` |
| network_number | 425 | `0b110101001` | `0x1A9` |
| network_number_quality | 426 | `0b110101010` | `0x1AA` |
| network_type | 427 | `0b110101011` | `0x1AB` |
| next_stopping_floor | 476 | `0b111011100` | `0x1DC` |
| node_subtype | 207 | `0b11001111` | `0xCF` |
| node_type | 208 | `0b11010000` | `0xD0` |
| notification_class | 17 | `0b10001` | `0x11` |
| notification_threshold | 137 | `0b10001001` | `0x89` |
| notify_type | 72 | `0b1001000` | `0x48` |
| number_of_apdu_retries | 73 | `0b1001001` | `0x49` |
| number_of_authentication_policies | 289 | `0b100100001` | `0x121` |
| number_of_states | 74 | `0b1001010` | `0x4A` |
| object_identifier | 75 | `0b1001011` | `0x4B` |
| object_list | 76 | `0b1001100` | `0x4C` |
| object_name | 77 | `0b1001101` | `0x4D` |
| object_property_reference | 78 | `0b1001110` | `0x4E` |
| object_type | 79 | `0b1001111` | `0x4F` |
| occupancy_count | 290 | `0b100100010` | `0x122` |
| occupancy_count_adjust | 291 | `0b100100011` | `0x123` |
| occupancy_count_enable | 292 | `0b100100100` | `0x124` |
| occupancy_lower_limit | 294 | `0b100100110` | `0x126` |
| occupancy_lower_limit_enforced | 295 | `0b100100111` | `0x127` |
| occupancy_state | 296 | `0b100101000` | `0x128` |
| occupancy_upper_limit | 297 | `0b100101001` | `0x129` |
| occupancy_upper_limit_enforced | 298 | `0b100101010` | `0x12A` |
| operation_direction | 477 | `0b111011101` | `0x1DD` |
| operation_expected | 161 | `0b10100001` | `0xA1` |
| optional | 80 | `0b1010000` | `0x50` |
| out_of_service | 81 | `0b1010001` | `0x51` |
| output_units | 82 | `0b1010010` | `0x52` |
| packet_reorder_time | 333 | `0b101001101` | `0x14D` |
| passback_mode | 300 | `0b100101100` | `0x12C` |
| passback_timeout | 301 | `0b100101101` | `0x12D` |
| passenger_alarm | 478 | `0b111011110` | `0x1DE` |
| polarity | 84 | `0b1010100` | `0x54` |
| port_filter | 363 | `0b101101011` | `0x16B` |
| positive_access_rules | 302 | `0b100101110` | `0x12E` |
| power | 384 | `0b110000000` | `0x180` |
| power_mode | 479 | `0b111011111` | `0x1DF` |
| prescale | 185 | `0b10111001` | `0xB9` |
| present_value | 85 | `0b1010101` | `0x55` |
| priority | 86 | `0b1010110` | `0x56` |
| priority_array | 87 | `0b1010111` | `0x57` |
| priority_for_writing | 88 | `0b1011000` | `0x58` |
| process_identifier | 89 | `0b1011001` | `0x59` |
| process_identifier_filter | 361 | `0b101101001` | `0x169` |
| profile_location | 485 | `0b111100101` | `0x1E5` |
| profile_name | 168 | `0b10101000` | `0xA8` |
| program_change | 90 | `0b1011010` | `0x5A` |
| program_location | 91 | `0b1011011` | `0x5B` |
| program_state | 92 | `0b1011100` | `0x5C` |
| property_list | 371 | `0b101110011` | `0x173` |
| proportional_constant | 93 | `0b1011101` | `0x5D` |
| proportional_constant_units | 94 | `0b1011110` | `0x5E` |
| protocol_level | 482 | `0b111100010` | `0x1E2` |
| protocol_object_types_supported | 96 | `0b1100000` | `0x60` |
| protocol_revision | 139 | `0b10001011` | `0x8B` |
| protocol_services_supported | 97 | `0b1100001` | `0x61` |
| protocol_version | 98 | `0b1100010` | `0x62` |
| pulse_rate | 186 | `0b10111010` | `0xBA` |
| read_only | 99 | `0b1100011` | `0x63` |
| reason_for_disable | 303 | `0b100101111` | `0x12F` |
| reason_for_halt | 100 | `0b1100100` | `0x64` |
| recipient_list | 102 | `0b1100110` | `0x66` |
| record_count | 141 | `0b10001101` | `0x8D` |
| records_since_notification | 140 | `0b10001100` | `0x8C` |
| reference_port | 483 | `0b111100011` | `0x1E3` |
| registered_car_call | 480 | `0b111100000` | `0x1E0` |
| reliability | 103 | `0b1100111` | `0x67` |
| reliability_evaluation_inhibit | 357 | `0b101100101` | `0x165` |
| relinquish_default | 104 | `0b1101000` | `0x68` |
| represents | 491 | `0b111101011` | `0x1EB` |
| requested_shed_level | 218 | `0b11011010` | `0xDA` |
| requested_update_interval | 348 | `0b101011100` | `0x15C` |
| required | 105 | `0b1101001` | `0x69` |
| resolution | 106 | `0b1101010` | `0x6A` |
| restart_notification_recipients | 202 | `0b11001010` | `0xCA` |
| restore_completion_time | 340 | `0b101010100` | `0x154` |
| restore_preparation_time | 341 | `0b101010101` | `0x155` |
| routing_table | 428 | `0b110101100` | `0x1AC` |
| scale | 187 | `0b10111011` | `0xBB` |
| scale_factor | 188 | `0b10111100` | `0xBC` |
| schedule_default | 174 | `0b10101110` | `0xAE` |
| secured_status | 235 | `0b11101011` | `0xEB` |
| security_pdu_timeout | 334 | `0b101001110` | `0x14E` |
| security_time_window | 335 | `0b101001111` | `0x14F` |
| segmentation_supported | 107 | `0b1101011` | `0x6B` |
| serial_number | 372 | `0b101110100` | `0x174` |
| setpoint | 108 | `0b1101100` | `0x6C` |
| setpoint_reference | 109 | `0b1101101` | `0x6D` |
| setting | 162 | `0b10100010` | `0xA2` |
| shed_duration | 219 | `0b11011011` | `0xDB` |
| shed_level_descriptions | 220 | `0b11011100` | `0xDC` |
| shed_levels | 221 | `0b11011101` | `0xDD` |
| silenced | 163 | `0b10100011` | `0xA3` |
| slave_address_binding | 171 | `0b10101011` | `0xAB` |
| slave_proxy_enable | 172 | `0b10101100` | `0xAC` |
| start_time | 142 | `0b10001110` | `0x8E` |
| state_change_values | 396 | `0b110001100` | `0x18C` |
| state_description | 222 | `0b11011110` | `0xDE` |
| state_text | 110 | `0b1101110` | `0x6E` |
| status_flags | 111 | `0b1101111` | `0x6F` |
| stop_time | 143 | `0b10001111` | `0x8F` |
| stop_when_full | 144 | `0b10010000` | `0x90` |
| strike_count | 391 | `0b110000111` | `0x187` |
| structured_object_list | 209 | `0b11010001` | `0xD1` |
| subordinate_annotations | 210 | `0b11010010` | `0xD2` |
| subordinate_list | 211 | `0b11010011` | `0xD3` |
| subordinate_node_types | 487 | `0b111100111` | `0x1E7` |
| subordinate_relationships | 489 | `0b111101001` | `0x1E9` |
| subordinate_tags | 488 | `0b111101000` | `0x1E8` |
| subscribed_recipients | 362 | `0b101101010` | `0x16A` |
| supported_format_classes | 305 | `0b100110001` | `0x131` |
| supported_formats | 304 | `0b100110000` | `0x130` |
| supported_security_algorithms | 336 | `0b101010000` | `0x150` |
| system_status | 112 | `0b1110000` | `0x70` |
| tags | 486 | `0b111100110` | `0x1E6` |
| threat_authority | 306 | `0b100110010` | `0x132` |
| threat_level | 307 | `0b100110011` | `0x133` |
| time_delay | 113 | `0b1110001` | `0x71` |
| time_delay_normal | 356 | `0b101100100` | `0x164` |
| time_of_active_time_reset | 114 | `0b1110010` | `0x72` |
| time_of_device_restart | 203 | `0b11001011` | `0xCB` |
| time_of_state_count_reset | 115 | `0b1110011` | `0x73` |
| time_of_strike_count_reset | 392 | `0b110001000` | `0x188` |
| time_synchronization_interval | 204 | `0b11001100` | `0xCC` |
| time_synchronization_recipients | 116 | `0b1110100` | `0x74` |
| timer_running | 397 | `0b110001101` | `0x18D` |
| timer_state | 398 | `0b110001110` | `0x18E` |
| total_record_count | 145 | `0b10010001` | `0x91` |
| trace_flag | 308 | `0b100110100` | `0x134` |
| tracking_value | 164 | `0b10100100` | `0xA4` |
| transaction_notification_class | 309 | `0b100110101` | `0x135` |
| transition | 385 | `0b110000001` | `0x181` |
| trigger | 205 | `0b11001101` | `0xCD` |
| units | 117 | `0b1110101` | `0x75` |
| update_interval | 118 | `0b1110110` | `0x76` |
| update_key_set_timeout | 337 | `0b101010001` | `0x151` |
| update_time | 189 | `0b10111101` | `0xBD` |
| user_external_identifier | 310 | `0b100110110` | `0x136` |
| user_information_reference | 311 | `0b100110111` | `0x137` |
| user_name | 317 | `0b100111101` | `0x13D` |
| user_type | 318 | `0b100111110` | `0x13E` |
| uses_remaining | 319 | `0b100111111` | `0x13F` |
| utc_offset | 119 | `0b1110111` | `0x77` |
| utc_time_synchronization_recipients | 206 | `0b11001110` | `0xCE` |
| valid_samples | 146 | `0b10010010` | `0x92` |
| value_before_change | 190 | `0b10111110` | `0xBE` |
| value_change_time | 192 | `0b11000000` | `0xC0` |
| value_set | 191 | `0b10111111` | `0xBF` |
| value_source | 433 | `0b110110001` | `0x1B1` |
| value_source_array | 434 | `0b110110010` | `0x1B2` |
| variance_value | 151 | `0b10010111` | `0x97` |
| vendor_identifier | 120 | `0b1111000` | `0x78` |
| vendor_name | 121 | `0b1111001` | `0x79` |
| verification_time | 326 | `0b101000110` | `0x146` |
| virtual_mac_address_table | 429 | `0b110101101` | `0x1AD` |
| vt_classes_supported | 122 | `0b1111010` | `0x7A` |
| weekly_schedule | 123 | `0b1111011` | `0x7B` |
| window_interval | 147 | `0b10010011` | `0x93` |
| window_samples | 148 | `0b10010100` | `0x94` |
| write_status | 370 | `0b101110010` | `0x172` |
| zone_from | 320 | `0b101000000` | `0x140` |
| zone_members | 165 | `0b10100101` | `0xA5` |
| zone_to | 321 | `0b101000001` | `0x141` |

### Constants: Property State 

Property State (ASHRAE 135 - 21 FORMAL DESCRIPTION OF APPLICATION PROTOCOL DATA UNITS)

Type: `:property_state`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| access_credential_disable | 33 | `0b100001` | `0x21` |
| access_credential_disable_reason | 32 | `0b100000` | `0x20` |
| access_event | 30 | `0b11110` | `0x1E` |
| action | 16 | `0b10000` | `0x10` |
| authentication_status | 34 | `0b100010` | `0x22` |
| backup_state | 36 | `0b100100` | `0x24` |
| bacnet_ip_mode | 45 | `0b101101` | `0x2D` |
| binary_lighting_value | 42 | `0b101010` | `0x2A` |
| binary_value | 1 | `0b1` | `0x1` |
| boolean_value | 0 | `0b0` | `0x0` |
| door_alarm_state | 15 | `0b1111` | `0xF` |
| door_secured_status | 17 | `0b10001` | `0x11` |
| door_status | 18 | `0b10010` | `0x12` |
| door_value | 19 | `0b10011` | `0x13` |
| escalator_fault | 50 | `0b110010` | `0x32` |
| escalator_mode | 51 | `0b110011` | `0x33` |
| escalator_operation_direction | 49 | `0b110001` | `0x31` |
| event_type | 2 | `0b10` | `0x2` |
| extended_value | 63 | `0b111111` | `0x3F` |
| file_access_method | 20 | `0b10100` | `0x14` |
| integer_value | 41 | `0b101001` | `0x29` |
| life_safety_mode | 12 | `0b1100` | `0xC` |
| life_safety_operation | 22 | `0b10110` | `0x16` |
| life_safety_state | 13 | `0b1101` | `0xD` |
| lift_car_direction | 52 | `0b110100` | `0x34` |
| lift_car_door_command | 53 | `0b110101` | `0x35` |
| lift_car_drive_status | 54 | `0b110110` | `0x36` |
| lift_car_mode | 55 | `0b110111` | `0x37` |
| lift_fault | 57 | `0b111001` | `0x39` |
| lift_group_mode | 56 | `0b111000` | `0x38` |
| lighting_in_progress | 38 | `0b100110` | `0x26` |
| lighting_operation | 39 | `0b100111` | `0x27` |
| lighting_transition | 40 | `0b101000` | `0x28` |
| lock_status | 21 | `0b10101` | `0x15` |
| maintenance | 23 | `0b10111` | `0x17` |
| network_number_quality | 48 | `0b110000` | `0x30` |
| network_port_command | 46 | `0b101110` | `0x2E` |
| network_type | 47 | `0b101111` | `0x2F` |
| node_type | 24 | `0b11000` | `0x18` |
| notify_type | 25 | `0b11001` | `0x19` |
| polarity | 3 | `0b11` | `0x3` |
| program_change | 4 | `0b100` | `0x4` |
| program_state | 5 | `0b101` | `0x5` |
| protocol_level | 58 | `0b111010` | `0x3A` |
| reason_for_halt | 6 | `0b110` | `0x6` |
| reliability | 7 | `0b111` | `0x7` |
| restart_reason | 14 | `0b1110` | `0xE` |
| security_level | 26 | `0b11010` | `0x1A` |
| shed_state | 27 | `0b11011` | `0x1B` |
| silenced_state | 28 | `0b11100` | `0x1C` |
| state | 8 | `0b1000` | `0x8` |
| system_status | 9 | `0b1001` | `0x9` |
| timer_state | 43 | `0b101011` | `0x2B` |
| timer_transition | 44 | `0b101100` | `0x2C` |
| units | 10 | `0b1010` | `0xA` |
| unsigned_value | 11 | `0b1011` | `0xB` |
| write_status | 37 | `0b100101` | `0x25` |
| zone_occupancy_state | 31 | `0b11111` | `0x1F` |

### Constants: Protocol Level 

Type: `:protocol_level`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| bacnet_application | 2 | `0b10` | `0x2` |
| non_bacnet_application | 3 | `0b11` | `0x3` |
| physical | 0 | `0b0` | `0x0` |
| protocol | 1 | `0b1` | `0x1` |

### Constants: Protocol Revision 

When creating BACnet objects, the designated revision can
be chosen from the constants. The designated revision decides
which properties are required. Optional properties are regardless
of the revision available.

The following revisions are supported (to be):
- Revision 14 (135-2012)
- Revision 19 (135-2016)
- Revision 22 (135-2022)

The default BACnet Revision is 14 (2012).

Type: `:protocol_revision`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| default | revision_14 | - | - |
| revision_14 | 14 | `0b1110` | `0xE` |

### Constants: Reinitialized State 

Reinitialized State (ASHRAE 135 - 16.4.1.1.1 Reinitialized State of Device)

Type: `:reinitialized_state`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| abortrestore | 6 | `0b110` | `0x6` |
| activate_changes | 7 | `0b111` | `0x7` |
| coldstart | 0 | `0b0` | `0x0` |
| endbackup | 3 | `0b11` | `0x3` |
| endrestore | 5 | `0b101` | `0x5` |
| startbackup | 2 | `0b10` | `0x2` |
| startrestore | 4 | `0b100` | `0x4` |
| warmstart | 1 | `0b1` | `0x1` |

### Constants: Reject Reason 

Type: `:reject_reason`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| buffer_overflow | 1 | `0b1` | `0x1` |
| inconsistent_parameters | 2 | `0b10` | `0x2` |
| invalid_parameter_data_type | 3 | `0b11` | `0x3` |
| invalid_tag | 4 | `0b100` | `0x4` |
| missing_required_parameter | 5 | `0b101` | `0x5` |
| other | 0 | `0b0` | `0x0` |
| parameter_out_of_range | 6 | `0b110` | `0x6` |
| too_many_arguments | 7 | `0b111` | `0x7` |
| undefined_enumeration | 8 | `0b1000` | `0x8` |
| unrecognized_service | 9 | `0b1001` | `0x9` |

### Constants: Relationship 

Type: `:relationship`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| adjusted_by | 9 | `0b1001` | `0x9` |
| adjusts | 8 | `0b1000` | `0x8` |
| commanded_by | 7 | `0b111` | `0x7` |
| commands | 6 | `0b110` | `0x6` |
| contained_by | 3 | `0b11` | `0x3` |
| contains | 2 | `0b10` | `0x2` |
| default | 1 | `0b1` | `0x1` |
| egress | 11 | `0b1011` | `0xB` |
| ingress | 10 | `0b1010` | `0xA` |
| receives_air | 13 | `0b1101` | `0xD` |
| receives_cool_air | 17 | `0b10001` | `0x11` |
| receives_cool_water | 27 | `0b11011` | `0x1B` |
| receives_gas | 21 | `0b10101` | `0x15` |
| receives_hot_air | 15 | `0b1111` | `0xF` |
| receives_hot_water | 25 | `0b11001` | `0x19` |
| receives_power | 19 | `0b10011` | `0x13` |
| receives_steam | 29 | `0b11101` | `0x1D` |
| receives_water | 23 | `0b10111` | `0x17` |
| supplies_air | 12 | `0b1100` | `0xC` |
| supplies_cool_air | 16 | `0b10000` | `0x10` |
| supplies_cool_water | 26 | `0b11010` | `0x1A` |
| supplies_gas | 20 | `0b10100` | `0x14` |
| supplies_hot_air | 14 | `0b1110` | `0xE` |
| supplies_hot_water | 24 | `0b11000` | `0x18` |
| supplies_power | 18 | `0b10010` | `0x12` |
| supplies_steam | 28 | `0b11100` | `0x1C` |
| supplies_water | 22 | `0b10110` | `0x16` |
| unknown | 0 | `0b0` | `0x0` |
| used_by | 5 | `0b101` | `0x5` |
| uses | 4 | `0b100` | `0x4` |

### Constants: Reliability 

Type: `:reliability`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| activation_failure | 17 | `0b10001` | `0x11` |
| communication_failure | 12 | `0b1100` | `0xC` |
| configuration_error | 10 | `0b1010` | `0xA` |
| faults_listed | 23 | `0b10111` | `0x17` |
| lamp_failure | 16 | `0b10000` | `0x10` |
| member_fault | 13 | `0b1101` | `0xD` |
| monitored_object_fault | 14 | `0b1110` | `0xE` |
| multi_state_fault | 9 | `0b1001` | `0x9` |
| no_fault_detected | 0 | `0b0` | `0x0` |
| no_output | 6 | `0b110` | `0x6` |
| no_sensor | 1 | `0b1` | `0x1` |
| open_loop | 4 | `0b100` | `0x4` |
| over_range | 2 | `0b10` | `0x2` |
| process_error | 8 | `0b1000` | `0x8` |
| proprietary_command_failure | 22 | `0b10110` | `0x16` |
| referenced_object_fault | 24 | `0b11000` | `0x18` |
| renew_dhcp_failure | 18 | `0b10010` | `0x12` |
| renew_fd_registration_failure | 19 | `0b10011` | `0x13` |
| restart_auto_negotiation_failure | 20 | `0b10100` | `0x14` |
| restart_failure | 21 | `0b10101` | `0x15` |
| shorted_loop | 5 | `0b101` | `0x5` |
| tripped | 15 | `0b1111` | `0xF` |
| under_range | 3 | `0b11` | `0x3` |
| unreliable_other | 7 | `0b111` | `0x7` |

### Constants: Restart Reason 

Type: `:restart_reason`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| activate_changes | 8 | `0b1000` | `0x8` |
| coldstart | 1 | `0b1` | `0x1` |
| detected_power_lost | 3 | `0b11` | `0x3` |
| detected_powered_off | 4 | `0b100` | `0x4` |
| hardware_watchdog | 5 | `0b101` | `0x5` |
| software_watchdog | 6 | `0b110` | `0x6` |
| suspended | 7 | `0b111` | `0x7` |
| unknown | 0 | `0b0` | `0x0` |
| warmstart | 2 | `0b10` | `0x2` |

### Constants: Result Flag 

Type: `:result_flag`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| first_item | 0 | `0b0` | `0x0` |
| last_item | 1 | `0b1` | `0x1` |
| more_items | 2 | `0b10` | `0x2` |

### Constants: Security Level 

Type: `:security_level`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| encrypted | 3 | `0b11` | `0x3` |
| encrypted_end_to_end | 5 | `0b101` | `0x5` |
| incapable | 0 | `0b0` | `0x0` |
| plain | 1 | `0b1` | `0x1` |
| signed | 2 | `0b10` | `0x2` |
| signed_end_to_end | 4 | `0b100` | `0x4` |

### Constants: Security Policy 

Type: `:security_policy`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| encrypted_trusted | 3 | `0b11` | `0x3` |
| plain_non_trusted | 0 | `0b0` | `0x0` |
| plain_trusted | 1 | `0b1` | `0x1` |
| signed_trusted | 2 | `0b10` | `0x2` |

### Constants: Segmentation 

Type: `:segmentation`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| no_segmentation | 3 | `0b11` | `0x3` |
| segmented_both | 0 | `0b0` | `0x0` |
| segmented_receive | 2 | `0b10` | `0x2` |
| segmented_transmit | 1 | `0b1` | `0x1` |

### Constants: Services Supported 

Type: `:services_supported`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| acknowledge_alarm | 0 | `0b0` | `0x0` |
| add_list_element | 8 | `0b1000` | `0x8` |
| atomic_read_file | 6 | `0b110` | `0x6` |
| atomic_write_file | 7 | `0b111` | `0x7` |
| authenticate | 24 | `0b11000` | `0x18` |
| confirmed_cov_notification | 1 | `0b1` | `0x1` |
| confirmed_cov_notification_multiple | 42 | `0b101010` | `0x2A` |
| confirmed_event_notification | 2 | `0b10` | `0x2` |
| confirmed_private_transfer | 18 | `0b10010` | `0x12` |
| confirmed_text_message | 19 | `0b10011` | `0x13` |
| create_object | 10 | `0b1010` | `0xA` |
| delete_object | 11 | `0b1011` | `0xB` |
| device_communication_control | 17 | `0b10001` | `0x11` |
| get_alarm_summary | 3 | `0b11` | `0x3` |
| get_enrollment_summary | 4 | `0b100` | `0x4` |
| get_event_information | 39 | `0b100111` | `0x27` |
| i_am | 26 | `0b11010` | `0x1A` |
| i_have | 27 | `0b11011` | `0x1B` |
| life_safety_operation | 37 | `0b100101` | `0x25` |
| read_property | 12 | `0b1100` | `0xC` |
| read_property_conditional | 13 | `0b1101` | `0xD` |
| read_property_multiple | 14 | `0b1110` | `0xE` |
| read_range | 35 | `0b100011` | `0x23` |
| reinitialize_device | 20 | `0b10100` | `0x14` |
| remove_list_element | 9 | `0b1001` | `0x9` |
| request_key | 25 | `0b11001` | `0x19` |
| subscribe_cov | 5 | `0b101` | `0x5` |
| subscribe_cov_property | 38 | `0b100110` | `0x26` |
| subscribe_cov_property_multiple | 41 | `0b101001` | `0x29` |
| time_synchronization | 32 | `0b100000` | `0x20` |
| unconfirmed_cov_notification | 28 | `0b11100` | `0x1C` |
| unconfirmed_cov_notification_multiple | 43 | `0b101011` | `0x2B` |
| unconfirmed_event_notification | 29 | `0b11101` | `0x1D` |
| unconfirmed_private_transfer | 30 | `0b11110` | `0x1E` |
| unconfirmed_text_message | 31 | `0b11111` | `0x1F` |
| utc_time_synchronization | 36 | `0b100100` | `0x24` |
| vt_close | 22 | `0b10110` | `0x16` |
| vt_data | 23 | `0b10111` | `0x17` |
| vt_open | 21 | `0b10101` | `0x15` |
| who_has | 33 | `0b100001` | `0x21` |
| who_is | 34 | `0b100010` | `0x22` |
| write_group | 40 | `0b101000` | `0x28` |
| write_property | 15 | `0b1111` | `0xF` |
| write_property_multiple | 16 | `0b10000` | `0x10` |

### Constants: Shed State 

Type: `:shed_state`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| shed_compliant | 2 | `0b10` | `0x2` |
| shed_inactive | 0 | `0b0` | `0x0` |
| shed_non_compliant | 3 | `0b11` | `0x3` |
| shed_request_pending | 1 | `0b1` | `0x1` |

### Constants: Silenced State 

Type: `:silenced_state`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| all_silenced | 3 | `0b11` | `0x3` |
| audible_silenced | 1 | `0b1` | `0x1` |
| unsilenced | 0 | `0b0` | `0x0` |
| visible_silenced | 2 | `0b10` | `0x2` |

### Constants: Status Flag 

Type: `:status_flag`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| fault | 1 | `0b1` | `0x1` |
| in_alarm | 0 | `0b0` | `0x0` |
| out_of_service | 3 | `0b11` | `0x3` |
| overridden | 2 | `0b10` | `0x2` |

### Constants: Timer State 

Type: `:timer_state`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| expired | 2 | `0b10` | `0x2` |
| idle | 0 | `0b0` | `0x0` |
| running | 1 | `0b1` | `0x1` |

### Constants: Timer Transition 

Type: `:timer_transition`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| expired_to_idle | 6 | `0b110` | `0x6` |
| expired_to_running | 7 | `0b111` | `0x7` |
| forced_to_expired | 5 | `0b101` | `0x5` |
| idle_to_running | 1 | `0b1` | `0x1` |
| none | 0 | `0b0` | `0x0` |
| running_to_expired | 4 | `0b100` | `0x4` |
| running_to_idle | 2 | `0b10` | `0x2` |
| running_to_running | 3 | `0b11` | `0x3` |

### Constants: Unconfirmed Service Choice 

Type: `:unconfirmed_service_choice`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| i_am | 0 | `0b0` | `0x0` |
| i_have | 1 | `0b1` | `0x1` |
| time_synchronization | 6 | `0b110` | `0x6` |
| unconfirmed_cov_notification | 2 | `0b10` | `0x2` |
| unconfirmed_cov_notification_multiple | 11 | `0b1011` | `0xB` |
| unconfirmed_event_notification | 3 | `0b11` | `0x3` |
| unconfirmed_private_transfer | 4 | `0b100` | `0x4` |
| unconfirmed_text_message | 5 | `0b101` | `0x5` |
| utc_time_synchronization | 9 | `0b1001` | `0x9` |
| who_has | 7 | `0b111` | `0x7` |
| who_is | 8 | `0b1000` | `0x8` |
| write_group | 10 | `0b1010` | `0xA` |

### Constants: Vt Class 

Type: `:vt_class`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| ansi_x3_64 | 1 | `0b1` | `0x1` |
| dec_vt100 | 3 | `0b11` | `0x3` |
| dec_vt220 | 4 | `0b100` | `0x4` |
| dec_vt52 | 2 | `0b10` | `0x2` |
| default_terminal | 0 | `0b0` | `0x0` |
| hp_700_94 | 5 | `0b101` | `0x5` |
| ibm_3130 | 6 | `0b110` | `0x6` |

### Constants: Write Status 

Type: `:write_status`

| Name                         | Value     | Value Bin | Value Hex |
|------------------------------|-----------|-----------|-----------|
| failed | 3 | `0b11` | `0x3` |
| idle | 0 | `0b0` | `0x0` |
| in_progress | 1 | `0b1` | `0x1` |
| successful | 2 | `0b10` | `0x2` |

# `abort_reason`

```elixir
@type abort_reason() ::
  :apdu_too_long
  | :application_exceeded_reply_time
  | :buffer_overflow
  | :insufficient_security
  | :invalid_apdu_in_this_state
  | :other
  | :out_of_resources
  | :preempted_by_higher_priority_task
  | :security_error
  | :segmentation_not_supported
  | :tsm_timeout
  | :window_size_out_of_range
```

# `accumulator_scale`

```elixir
@type accumulator_scale() :: :float_scale | :integer_scale
```

# `accumulator_status`

```elixir
@type accumulator_status() :: :abnormal | :failed | :normal | :recovered | :starting
```

# `action`

```elixir
@type action() :: :direct | :reverse
```

# `application_tag`

```elixir
@type application_tag() ::
  :bitstring
  | :boolean
  | :character_string
  | :date
  | :double
  | :enumerated
  | :null
  | :object_identifier
  | :octet_string
  | :real
  | :signed_integer
  | :time
  | :unsigned_integer
```

Application Tags (ASHRAE 135 - 20.2.1.4 Application Tags)

# `backup_state`

```elixir
@type backup_state() ::
  :backup_failure
  | :idle
  | :performing_a_backup
  | :performing_a_restore
  | :preparing_for_backup
  | :preparing_for_restore
  | :restore_failure
```

# `binary_lighting_present_value`

```elixir
@type binary_lighting_present_value() ::
  :off | :on | :stop | :warn | :warn_off | :warn_relinquish
```

# `binary_present_value`

```elixir
@type binary_present_value() :: :active | :inactive
```

# `bvlc_result_format`

```elixir
@type bvlc_result_format() ::
  :delete_foreign_device_table_entry_nak
  | :distribute_broadcast_to_network_nak
  | :read_broadcast_distribution_table_nak
  | :read_foreign_device_table_nak
  | :register_foreign_device_nak
  | :successful_completion
  | :write_broadcast_distribution_table_nak
```

BACnet Virtual Link Control (BVLC)

# `bvlc_result_purpose`

```elixir
@type bvlc_result_purpose() ::
  :bvlc_delete_foreign_device_table_entry
  | :bvlc_distribute_broadcast_to_network
  | :bvlc_forwarded_npdu
  | :bvlc_original_broadcast_npdu
  | :bvlc_original_unicast_npdu
  | :bvlc_read_broadcast_distribution_table
  | :bvlc_read_broadcast_distribution_table_ack
  | :bvlc_read_foreign_device_table
  | :bvlc_read_foreign_device_table_ack
  | :bvlc_register_foreign_device
  | :bvlc_result
  | :bvlc_secure_bvll
  | :bvlc_write_broadcast_distribution_table
```

BACnet Virtual Link Control (BVLC)

# `bvll`

```elixir
@type bvll() :: :default_port_bacnet_ip | :type_bacnet_ipv4 | :type_bacnet_ipv6
```

BACnet Virtual Link Layer (BVLL) for BACnet/IP

# `character_string_encoding`

```elixir
@type character_string_encoding() ::
  :iso_8859_1 | :jis_x_0208 | :microsoft_dbcs | :ucs_2 | :ucs_4 | :utf8
```

Character String Encoding (ASHRAE 135 - 20.2.9 Encoding of a Character String Value)

# `confirmed_service_choice`

```elixir
@type confirmed_service_choice() ::
  :acknowledge_alarm
  | :add_list_element
  | :atomic_read_file
  | :atomic_write_file
  | :confirmed_cov_notification
  | :confirmed_cov_notification_multiple
  | :confirmed_event_notification
  | :confirmed_private_transfer
  | :confirmed_text_message
  | :create_object
  | :delete_object
  | :device_communication_control
  | :get_alarm_summary
  | :get_enrollment_summary
  | :get_event_information
  | :life_safety_operation
  | :read_property
  | :read_property_multiple
  | :read_range
  | :reinitialize_device
  | :remove_list_element
  | :subscribe_cov
  | :subscribe_cov_property
  | :subscribe_cov_property_multiple
  | :vt_close
  | :vt_data
  | :vt_open
  | :write_property
  | :write_property_multiple
```

# `days_of_week`

```elixir
@type days_of_week() ::
  :friday | :monday | :saturday | :sunday | :thursday | :tuesday | :wednesday
```

Days Of Week (ASHRAE 135 - 21 FORMAL DESCRIPTION OF APPLICATION PROTOCOL DATA UNITS)

# `device_status`

```elixir
@type device_status() ::
  :backup_in_progress
  | :download_in_progress
  | :download_required
  | :non_operational
  | :operational
  | :operational_read_only
```

# `door_alarm_state`

```elixir
@type door_alarm_state() ::
  :alarm
  | :door_fault
  | :door_open_too_long
  | :egress_open
  | :forced_open
  | :free_access
  | :lock_down
  | :normal
  | :tamper
```

# `door_secured_status`

```elixir
@type door_secured_status() :: :secured | :unknown | :unsecured
```

# `door_status`

```elixir
@type door_status() ::
  :closed
  | :closing
  | :door_fault
  | :limited_opened
  | :none
  | :opened
  | :opening
  | :safety_locked
  | :unknown
  | :unused
```

# `door_value`

```elixir
@type door_value() :: :extended_pulse_unlock | :lock | :pulse_unlock | :unlock
```

# `enable_disable`

```elixir
@type enable_disable() :: :disable | :disable_initiation | :enable
```

Enable Disable (ASHRAE 135 - 16.1.1.1.2 Enable/Disable)

# `engineering_unit`

```elixir
@type engineering_unit() ::
  :ampere_seconds
  | :ampere_square_hours
  | :ampere_square_meters
  | :amperes
  | :amperes_per_meter
  | :amperes_per_square_meter
  | :bars
  | :becquerels
  | :btus
  | :btus_per_hour
  | :btus_per_pound
  | :btus_per_pound_dry_air
  | :candelas
  | :candelas_per_square_meter
  | :centimeters
  | :centimeters_of_mercury
  | :centimeters_of_water
  | :cubic_feet
  | :cubic_feet_per_day
  | :cubic_feet_per_hour
  | :cubic_feet_per_minute
  | :cubic_feet_per_second
  | :cubic_meters
  | :cubic_meters_per_day
  | :cubic_meters_per_hour
  | :cubic_meters_per_minute
  | :cubic_meters_per_second
  | :currency1
  | :currency10
  | :currency2
  | :currency3
  | :currency4
  | :currency5
  | :currency6
  | :currency7
  | :currency8
  | :currency9
  | :cycles_per_hour
  | :cycles_per_minute
  | :days
  | :decibels
  | :decibels_a
  | :decibels_millivolt
  | :decibels_volt
  | :degree_days_celsius
  | :degree_days_fahrenheit
  | :degrees_angular
  | :degrees_celsius
  | :degrees_celsius_per_hour
  | :degrees_celsius_per_minute
  | :degrees_fahrenheit
  | :degrees_fahrenheit_per_hour
  | :degrees_fahrenheit_per_minute
  | :degrees_kelvin
  | :degrees_kelvin_per_hour
  | :degrees_kelvin_per_minute
  | :degrees_phase
  | :delta_degrees_fahrenheit
  | :delta_degrees_kelvin
  | :farads
  | :feet
  | :feet_per_minute
  | :feet_per_second
  | :foot_candles
  | :grams
  | :grams_of_water_per_kilogram_dry_air
  | :grams_per_cubic_centimeter
  | :grams_per_cubic_meter
  | :grams_per_gram
  | :grams_per_kilogram
  | :grams_per_liter
  | :grams_per_milliliter
  | :grams_per_minute
  | :grams_per_second
  | :grams_per_square_meter
  | :gray
  | :hectopascals
  | :henrys
  | :hertz
  | :horsepower
  | :hours
  | :hundredths_seconds
  | :imperial_gallons
  | :imperial_gallons_per_minute
  | :inches
  | :inches_of_mercury
  | :inches_of_water
  | :joule_per_hours
  | :joule_seconds
  | :joules
  | :joules_per_cubic_meter
  | :joules_per_degree_kelvin
  | :joules_per_kilogram_degree_kelvin
  | :joules_per_kilogram_dry_air
  | :kilo_btus
  | :kilo_btus_per_hour
  | :kilobecquerels
  | :kilograms
  | :kilograms_per_cubic_meter
  | :kilograms_per_hour
  | :kilograms_per_kilogram
  | :kilograms_per_minute
  | :kilograms_per_second
  | :kilohertz
  | :kilohms
  | :kilojoules
  | :kilojoules_per_degree_kelvin
  | :kilojoules_per_kilogram
  | :kilojoules_per_kilogram_dry_air
  | :kilometers
  | :kilometers_per_hour
  | :kilopascals
  | :kilovolt_ampere_hours
  | :kilovolt_ampere_hours_reactive
  | :kilovolt_amperes
  | :kilovolt_amperes_reactive
  | :kilovolts
  | :kilowatt_hours
  | :kilowatt_hours_per_square_foot
  | :kilowatt_hours_per_square_meter
  | :kilowatt_hours_reactive
  | :kilowatts
  | :liters
  | :liters_per_hour
  | :liters_per_minute
  | :liters_per_second
  | :lumens
  | :luxes
  | :mega_btus
  | :megabecquerels
  | :megahertz
  | :megajoules
  | :megajoules_per_degree_kelvin
  | :megajoules_per_kilogram_dry_air
  | :megajoules_per_square_foot
  | :megajoules_per_square_meter
  | :megavolt_ampere_hours
  | :megavolt_ampere_hours_reactive
  | :megavolt_amperes
  | :megavolt_amperes_reactive
  | :megavolts
  | :megawatt_hours
  | :megawatt_hours_reactive
  | :megawatts
  | :megohms
  | :meters
  | :meters_per_hour
  | :meters_per_minute
  | :meters_per_second
  | :meters_per_second_per_second
  | :micrograms_per_cubic_meter
  | :micrograms_per_liter
  | :microgray
  | :micrometers
  | :microsiemens
  | :microsieverts
  | :microsieverts_per_hour
  | :miles_per_hour
  | :milliamperes
  | :millibars
  | :milligrams
  | :milligrams_per_cubic_meter
  | :milligrams_per_gram
  | :milligrams_per_kilogram
  | :milligrams_per_liter
  | :milligray
  | :milliliters
  | :milliliters_per_second
  | :millimeters
  | :millimeters_of_mercury
  | :millimeters_of_water
  | :millimeters_per_minute
  | :millimeters_per_second
  | :milliohms
  | :million_standard_cubic_feet_per_day
  | :million_standard_cubic_feet_per_minute
  | :millirems
  | :millirems_per_hour
  | :milliseconds
  | :millisiemens
  | :millisieverts
  | :millivolts
  | :milliwatts
  | :minutes
  | :minutes_per_degree_kelvin
  | :mole_percent
  | :months
  | :nanograms_per_cubic_meter
  | :nephelometric_turbidity_unit
  | :newton
  | :newton_meters
  | :newton_seconds
  | :newtons_per_meter
  | :no_units
  | :ohm_meter_squared_per_meter
  | :ohm_meters
  | :ohms
  | :parts_per_billion
  | :parts_per_million
  | :pascal_seconds
  | :pascals
  | :per_hour
  | :per_mille
  | :per_minute
  | :per_second
  | :percent
  | :percent_obscuration_per_foot
  | :percent_obscuration_per_meter
  | :percent_per_second
  | :percent_relative_humidity
  | :ph
  | :pounds_force_per_square_inch
  | :pounds_mass
  | :pounds_mass_per_day
  | :pounds_mass_per_hour
  | :pounds_mass_per_minute
  | :pounds_mass_per_second
  | :power_factor
  | :psi_per_degree_fahrenheit
  | :radians
  | :radians_per_second
  | :revolutions_per_minute
  | :seconds
  | :siemens
  | :siemens_per_meter
  | :sieverts
  | :square_centimeters
  | :square_feet
  | :square_inches
  | :square_meters
  | :square_meters_per_newton
  | :standard_cubic_feet_per_day
  | :teslas
  | :therms
  | :thousand_cubic_feet_per_day
  | :thousand_standard_cubic_feet_per_day
  | :ton_hours
  | :tons
  | :tons_per_hour
  | :tons_refrigeration
  | :us_gallons
  | :us_gallons_per_hour
  | :us_gallons_per_minute
  | :volt_ampere_hours
  | :volt_ampere_hours_reactive
  | :volt_amperes
  | :volt_amperes_reactive
  | :volt_square_hours
  | :volts
  | :volts_per_degree_kelvin
  | :volts_per_meter
  | :watt_hours
  | :watt_hours_per_cubic_meter
  | :watt_hours_reactive
  | :watts
  | :watts_per_meter_per_degree_kelvin
  | :watts_per_square_foot
  | :watts_per_square_meter
  | :watts_per_square_meter_degree_kelvin
  | :webers
  | :weeks
  | :years
```

# `error_class`

```elixir
@type error_class() ::
  :communication
  | :device
  | :object
  | :property
  | :resources
  | :security
  | :services
  | :vt
```

# `error_code`

```elixir
@type error_code() ::
  :abort_apdu_too_long
  | :abort_application_exceeded_reply_time
  | :abort_buffer_overflow
  | :abort_insufficient_security
  | :abort_invalid_apdu_in_this_state
  | :abort_other
  | :abort_out_of_resources
  | :abort_preempted_by_higher_priority_task
  | :abort_proprietary
  | :abort_security_error
  | :abort_segmentation_not_supported
  | :abort_tsm_timeout
  | :abort_window_size_out_of_range
  | :access_denied
  | :addressing_error
  | :bad_destination_address
  | :bad_destination_device_id
  | :bad_signature
  | :bad_source_address
  | :bad_timestamp
  | :busy
  | :cannot_use_key
  | :cannot_verify_message_id
  | :character_set_not_supported
  | :communication_disabled
  | :configuration_in_progress
  | :correct_key_revision
  | :cov_subscription_failed
  | :datatype_not_supported
  | :delete_fdt_entry_failed
  | :destination_device_id_required
  | :device_busy
  | :distribute_broadcast_failed
  | :duplicate_entry
  | :duplicate_message
  | :duplicate_name
  | :duplicate_object_id
  | :dynamic_creation_not_supported
  | :encryption_not_configured
  | :encryption_required
  | :file_access_denied
  | :file_full
  | :inconsistent_configuration
  | :inconsistent_object_type
  | :inconsistent_parameters
  | :inconsistent_selection_criterion
  | :incorrect_key
  | :internal_error
  | :invalid_array_index
  | :invalid_configuration_data
  | :invalid_datatype
  | :invalid_event_state
  | :invalid_file_access_method
  | :invalid_file_start_position
  | :invalid_key_data
  | :invalid_parameter_data_type
  | :invalid_tag
  | :invalid_timestamp
  | :invalid_value_in_this_state
  | :key_update_in_progress
  | :list_element_not_found
  | :log_buffer_full
  | :logged_value_purged
  | :malformed_message
  | :message_too_long
  | :missing_required_parameter
  | :network_down
  | :no_alarm_configured
  | :no_objects_of_specified_type
  | :no_property_specified
  | :no_space_for_object
  | :no_space_to_add_list_element
  | :no_space_to_write_property
  | :no_vt_sessions_available
  | :not_configured
  | :not_configured_for_triggered_logging
  | :not_cov_property
  | :not_key_server
  | :not_router_to_dnet
  | :object_deletion_not_permitted
  | :object_identifier_already_exists
  | :operational_problem
  | :optional_functionality_not_supported
  | :other
  | :out_of_memory
  | :parameter_out_of_range
  | :password_failure
  | :property_is_not_a_list
  | :property_is_not_an_array
  | :read_access_denied
  | :read_bdt_failed
  | :read_fdt_failed
  | :register_foreign_device_failed
  | :reject_buffer_overflow
  | :reject_inconsistent_parameters
  | :reject_invalid_parameter_data_type
  | :reject_invalid_tag
  | :reject_missing_required_parameter
  | :reject_other
  | :reject_parameter_out_of_range
  | :reject_proprietary
  | :reject_too_many_arguments
  | :reject_undefined_enumeration
  | :reject_unrecognized_service
  | :router_busy
  | :security_error
  | :security_not_configured
  | :service_request_denied
  | :source_security_required
  | :success
  | :timeout
  | :too_many_keys
  | :unknown_authentication_type
  | :unknown_device
  | :unknown_file_size
  | :unknown_key
  | :unknown_key_revision
  | :unknown_network_message
  | :unknown_object
  | :unknown_property
  | :unknown_route
  | :unknown_source_message
  | :unknown_subscription
  | :unknown_vt_class
  | :unknown_vt_session
  | :unsupported_object_type
  | :value_not_initialized
  | :value_out_of_range
  | :value_too_long
  | :vt_session_already_closed
  | :vt_session_termination_failure
  | :write_access_denied
  | :write_bdt_failed
```

# `event_state`

```elixir
@type event_state() ::
  :fault | :high_limit | :life_safety_alarm | :low_limit | :normal | :offnormal
```

# `event_transition_bit`

```elixir
@type event_transition_bit() :: :to_fault | :to_normal | :to_offnormal
```

# `event_type`

```elixir
@type event_type() ::
  :access_event
  | :buffer_ready
  | :change_of_bitstring
  | :change_of_characterstring
  | :change_of_discrete_value
  | :change_of_life_safety
  | :change_of_reliability
  | :change_of_state
  | :change_of_status_flags
  | :change_of_timer
  | :change_of_value
  | :command_failure
  | :complex_event_type
  | :double_out_of_range
  | :extended
  | :floating_limit
  | :none
  | :out_of_range
  | :signed_out_of_range
  | :unsigned_out_of_range
  | :unsigned_range
```

# `fault_type`

```elixir
@type fault_type() ::
  :fault_characterstring
  | :fault_extended
  | :fault_life_safety
  | :fault_listed
  | :fault_out_of_range
  | :fault_state
  | :fault_status_flags
  | :none
```

# `file_access_method`

```elixir
@type file_access_method() :: :record_access | :stream_access
```

# `ip_mode`

```elixir
@type ip_mode() :: :bbmd | :foreign | :normal
```

# `life_safety_mode`

```elixir
@type life_safety_mode() ::
  :armed
  | :automatic_release_disabled
  | :default
  | :disabled
  | :disarmed
  | :disconnected
  | :enabled
  | :fast
  | :manned
  | :off
  | :on
  | :prearmed
  | :slow
  | :test
  | :unmanned
```

# `life_safety_operation`

```elixir
@type life_safety_operation() ::
  :none
  | :reset
  | :reset_alarm
  | :reset_fault
  | :silence
  | :silence_audible
  | :silence_visual
  | :unsilence
  | :unsilence_audible
  | :unsilence_visual
```

# `life_safety_state`

```elixir
@type life_safety_state() ::
  :abnormal
  | :active
  | :alarm
  | :blocked
  | :delayed
  | :duress
  | :emergency_power
  | :fault
  | :fault_alarm
  | :fault_pre_alarm
  | :general_alarm
  | :holdup
  | :local_alarm
  | :not_ready
  | :pre_alarm
  | :quiet
  | :supervisory
  | :tamper
  | :tamper_alarm
  | :test_active
  | :test_alarm
  | :test_fault
  | :test_fault_alarm
  | :test_supervisory
```

# `lighting_in_progress`

```elixir
@type lighting_in_progress() ::
  :fade_active | :idle | :not_controlled | :other | :ramp_active
```

# `lighting_operation`

```elixir
@type lighting_operation() ::
  :fade_to
  | :none
  | :ramp_to
  | :step_down
  | :step_off
  | :step_on
  | :step_up
  | :stop
  | :warn
  | :warn_off
  | :warn_relinquish
```

# `lighting_transition`

```elixir
@type lighting_transition() :: :fade | :none | :ramp
```

# `limit_enable`

```elixir
@type limit_enable() :: :high_limit_enable | :low_limit_enable
```

# `lock_status`

```elixir
@type lock_status() :: :lock_fault | :locked | :unknown | :unlocked | :unused
```

# `log_status`

```elixir
@type log_status() :: :buffer_purged | :log_disabled | :log_interrupted
```

# `logging_type`

```elixir
@type logging_type() :: :cov | :polled | :triggered
```

# `maintenance`

```elixir
@type maintenance() ::
  :need_service_inoperative | :need_service_operational | :none | :periodic_test
```

# `max_apdu`

```elixir
@type max_apdu() :: 50..1467
```

The maximum APDU length supported by BACnet. Each device (respectively
transport layer) may support only the minimum or a value in between.

# `max_apdu_length_accepted`

```elixir
@type max_apdu_length_accepted() ::
  :octets_1024
  | :octets_128
  | :octets_1476
  | :octets_206
  | :octets_480
  | :octets_50
```

Max APDU Length Accepted (ASHRAE 135 - 20.1.2.5 max-apdu-length-accepted)

# `max_segments`

```elixir
@type max_segments() :: 1..64 | :more_than_64 | :unspecified
```

The maximum amount of segments for segmented requests or responses.

# `max_segments_accepted`

```elixir
@type max_segments_accepted() ::
  :segments_0
  | :segments_16
  | :segments_2
  | :segments_32
  | :segments_4
  | :segments_64
  | :segments_65
  | :segments_8
```

Max Segments Accepted (ASHRAE 135 - 20.1.2.4 max-segments-accepted)

# `network_layer_message_type`

```elixir
@type network_layer_message_type() ::
  :challenge_request
  | :disconnect_connection_to_network
  | :establish_connection_to_network
  | :i_am_router_to_network
  | :i_could_be_router_to_network
  | :initialize_routing_table
  | :initialize_routing_table_ack
  | :network_number_is
  | :reject_message_to_network
  | :request_key_update
  | :request_master_key
  | :reserved_area_start
  | :router_available_to_network
  | :router_busy_to_network
  | :security_payload
  | :security_response
  | :set_master_key
  | :update_distribution_key
  | :update_key_set
  | :vendor_proprietary_area_start
  | :what_is_network_number
  | :who_is_router_to_network
```

Network Layer Message Type (ASHRAE 135 - 6.2.4 Network Layer Message Type)

# `network_number_quality`

```elixir
@type network_number_quality() ::
  :configured | :learned | :learned_configured | :unknown
```

# `network_port_command`

```elixir
@type network_port_command() ::
  :discard_changes
  | :disconnect
  | :idle
  | :renew_dhcp
  | :renew_fd_registration
  | :restart_autonegotiation
  | :restart_port
  | :restart_slave_discovery
```

# `network_type`

```elixir
@type network_type() ::
  :arcnet
  | :ethernet
  | :ipv4
  | :ipv6
  | :lontalk
  | :mstp
  | :ptp
  | :serial
  | :virtual
  | :zigbee
```

# `node_type`

```elixir
@type node_type() ::
  :area
  | :building
  | :collection
  | :device
  | :equipment
  | :floor
  | :functional
  | :member
  | :module
  | :network
  | :organizational
  | :other
  | :point
  | :property
  | :protocol
  | :room
  | :section
  | :subsystem
  | :system
  | :tree
  | :unknown
  | :zone
```

# `notify_type`

```elixir
@type notify_type() :: :ack_notification | :alarm | :event
```

# `npdu_control_bit`

```elixir
@type npdu_control_bit() ::
  :destination_specified
  | :expecting_reply
  | :network_layer_message
  | :source_specified
```

NPDU Control Bits (ASHRAE 135 - 6.2.2 Network Layer Protocol Control Information)

# `npdu_control_priority`

```elixir
@type npdu_control_priority() ::
  :critical_equipment_message | :life_safety_message | :normal | :urgent
```

NPDU Control Priority (ASHRAE 135 - 6.2.2 Network Layer Protocol Control Information)

# `object_type`

```elixir
@type object_type() ::
  :access_credential
  | :access_door
  | :access_point
  | :access_rights
  | :access_user
  | :access_zone
  | :accumulator
  | :alert_enrollment
  | :analog_input
  | :analog_output
  | :analog_value
  | :averaging
  | :binary_input
  | :binary_lighting_output
  | :binary_output
  | :binary_value
  | :bitstring_value
  | :calendar
  | :channel
  | :character_string_value
  | :command
  | :credential_data_input
  | :date_pattern_value
  | :date_value
  | :datetime_pattern_value
  | :datetime_value
  | :device
  | :elevator_group
  | :escalator
  | :event_enrollment
  | :event_log
  | :file
  | :global_group
  | :group
  | :integer_value
  | :large_analog_value
  | :life_safety_point
  | :life_safety_zone
  | :lift
  | :lighting_output
  | :load_control
  | :loop
  | :multi_state_input
  | :multi_state_output
  | :multi_state_value
  | :network_port
  | :network_security
  | :notification_class
  | :notification_forwarder
  | :octet_string_value
  | :positive_integer_value
  | :program
  | :pulse_converter
  | :schedule
  | :structured_view
  | :time_pattern_value
  | :time_value
  | :timer
  | :trend_log
  | :trend_log_multiple
```

# `object_types_supported`

```elixir
@type object_types_supported() ::
  :access_credential
  | :access_door
  | :access_point
  | :access_rights
  | :access_user
  | :access_zone
  | :accumulator
  | :alert_enrollment
  | :analog_input
  | :analog_output
  | :analog_value
  | :averaging
  | :binary_input
  | :binary_lighting_output
  | :binary_output
  | :binary_value
  | :bitstring_value
  | :calendar
  | :channel
  | :character_string_value
  | :command
  | :credential_data_input
  | :date_pattern_value
  | :date_value
  | :datetime_pattern_value
  | :datetime_value
  | :device
  | :elevator_group
  | :escalator
  | :event_enrollment
  | :event_log
  | :file
  | :global_group
  | :group
  | :integer_value
  | :large_analog_value
  | :life_safety_point
  | :life_safety_zone
  | :lift
  | :lighting_output
  | :load_control
  | :loop
  | :multi_state_input
  | :multi_state_output
  | :multi_state_value
  | :network_port
  | :network_security
  | :notification_class
  | :notification_forwarder
  | :octet_string_value
  | :positive_integer_value
  | :program
  | :pulse_converter
  | :schedule
  | :structured_view
  | :time_pattern_value
  | :time_value
  | :timer
  | :trend_log
  | :trend_log_multiple
```

# `pdu_confirmed_request_bit`

```elixir
@type pdu_confirmed_request_bit() ::
  :more_follows | :segmented_message | :segmented_response_accepted
```

PDU Confirmed Request PDU Bits (ASHRAE 135 - 20.1.2.11 Format of the BACnet-Confirmed-Request-PDU)

# `pdu_segment_ack_bit`

```elixir
@type pdu_segment_ack_bit() :: :negative_ack | :server
```

PDU Segment ACK Bits (ASHRAE 135 - 20.1.6.6 Format of the BACnet-SegmentACK-PDU)

# `pdu_type`

```elixir
@type pdu_type() ::
  :abort
  | :complex_ack
  | :confirmed_request
  | :error
  | :reject
  | :segment_ack
  | :simple_ack
  | :unconfirmed_request
```

PDU Types (ASHRAE 135 - 21 FORMAL DESCRIPTION OF APPLICATION PROTOCOL DATA UNITS)

# `polarity`

```elixir
@type polarity() :: :normal | :reverse
```

# `program_error`

```elixir
@type program_error() :: :internal | :load_failed | :normal | :other | :program
```

# `program_request`

```elixir
@type program_request() :: :halt | :load | :ready | :restart | :run | :unload
```

# `program_state`

```elixir
@type program_state() :: :halted | :idle | :loading | :running | :unloading | :waiting
```

# `property_identifier`

```elixir
@type property_identifier() ::
  :absentee_limit
  | :accepted_modes
  | :access_alarm_events
  | :access_doors
  | :access_event
  | :access_event_authentication_factor
  | :access_event_credential
  | :access_event_tag
  | :access_event_time
  | :access_transaction_events
  | :accompaniment
  | :accompaniment_time
  | :ack_required
  | :acked_transitions
  | :action
  | :action_text
  | :activation_time
  | :active_authentication_policy
  | :active_cov_multiple_subscriptions
  | :active_cov_subscriptions
  | :active_text
  | :active_vt_sessions
  | :actual_shed_level
  | :adjust_value
  | :alarm_value
  | :alarm_values
  | :align_intervals
  | :all
  | :all_writes_successful
  | :allow_group_delay_inhibit
  | :apdu_length
  | :apdu_segment_timeout
  | :apdu_timeout
  | :application_software_version
  | :archive
  | :assigned_access_rights
  | :assigned_landing_calls
  | :attempted_samples
  | :authentication_factors
  | :authentication_policy_list
  | :authentication_policy_names
  | :authentication_status
  | :authorization_exemptions
  | :authorization_mode
  | :auto_slave_discovery
  | :average_value
  | :backup_and_restore_state
  | :backup_failure_timeout
  | :backup_preparation_time
  | :bacnet_ip_global_address
  | :bacnet_ip_mode
  | :bacnet_ip_multicast_address
  | :bacnet_ip_nat_traversal
  | :bacnet_ip_udp_port
  | :bacnet_ipv6_mode
  | :bacnet_ipv6_multicast_address
  | :bacnet_ipv6_udp_port
  | :bbmd_accept_fd_registrations
  | :bbmd_broadcast_distribution_table
  | :bbmd_foreign_device_table
  | :belongs_to
  | :bias
  | :bit_mask
  | :bit_text
  | :blink_warn_enable
  | :buffer_size
  | :car_assigned_direction
  | :car_door_command
  | :car_door_status
  | :car_door_text
  | :car_door_zone
  | :car_drive_status
  | :car_load
  | :car_load_units
  | :car_mode
  | :car_moving_direction
  | :car_position
  | :change_of_state_count
  | :change_of_state_time
  | :changes_pending
  | :channel_number
  | :client_cov_increment
  | :command
  | :command_time_array
  | :configuration_files
  | :control_groups
  | :controlled_variable_reference
  | :controlled_variable_units
  | :controlled_variable_value
  | :count
  | :count_before_change
  | :count_change_time
  | :cov_increment
  | :cov_period
  | :cov_resubscription_interval
  | :covu_period
  | :covu_recipients
  | :credential_disable
  | :credential_status
  | :credentials
  | :credentials_in_zone
  | :current_command_priority
  | :database_revision
  | :date_list
  | :daylight_savings_status
  | :days_remaining
  | :deadband
  | :default_fade_time
  | :default_ramp_rate
  | :default_step_increment
  | :default_subordinate_relationship
  | :default_timeout
  | :deployed_profile_location
  | :derivative_constant
  | :derivative_constant_units
  | :description
  | :description_of_halt
  | :device_address_binding
  | :device_type
  | :direct_reading
  | :distribution_key_revision
  | :do_not_hide
  | :door_alarm_state
  | :door_extended_pulse_time
  | :door_members
  | :door_open_too_long_time
  | :door_pulse_time
  | :door_status
  | :door_unlock_delay_time
  | :duty_window
  | :effective_period
  | :egress_active
  | :egress_time
  | :elapsed_active_time
  | :elevator_group
  | :enable
  | :energy_meter
  | :energy_meter_ref
  | :entry_points
  | :error_limit
  | :escalator_mode
  | :event_algorithm_inhibit
  | :event_algorithm_inhibit_ref
  | :event_detection_enable
  | :event_enable
  | :event_message_texts
  | :event_message_texts_config
  | :event_parameters
  | :event_state
  | :event_timestamps
  | :event_type
  | :exception_schedule
  | :execution_delay
  | :exit_points
  | :expected_shed_level
  | :expiration_time
  | :extended_time_enable
  | :failed_attempt_events
  | :failed_attempts
  | :failed_attempts_time
  | :fault_high_limit
  | :fault_low_limit
  | :fault_parameters
  | :fault_signals
  | :fault_type
  | :fault_values
  | :fd_bbmd_address
  | :fd_subscription_lifetime
  | :feedback_value
  | :file_access_method
  | :file_size
  | :file_type
  | :firmware_revision
  | :floor_text
  | :full_duty_baseline
  | :global_identifier
  | :group_id
  | :group_member_names
  | :group_members
  | :group_mode
  | :high_limit
  | :higher_deck
  | :in_process
  | :in_progress
  | :inactive_text
  | :initial_timeout
  | :input_reference
  | :installation_id
  | :instance_of
  | :instantaneous_power
  | :integral_constant
  | :integral_constant_units
  | :interface_value
  | :interval_offset
  | :ip_address
  | :ip_default_gateway
  | :ip_dhcp_enable
  | :ip_dhcp_lease_time
  | :ip_dhcp_lease_time_remaining
  | :ip_dhcp_server
  | :ip_dns_server
  | :ip_subnet_mask
  | :ipv6_address
  | :ipv6_auto_addressing_enable
  | :ipv6_default_gateway
  | :ipv6_dhcp_lease_time
  | :ipv6_dhcp_lease_time_remaining
  | :ipv6_dhcp_server
  | :ipv6_dns_server
  | :ipv6_prefix_length
  | :ipv6_zone_index
  | :is_utc
  | :key_sets
  | :landing_call_control
  | :landing_calls
  | :landing_door_status
  | :last_access_event
  | :last_access_point
  | :last_command_time
  | :last_credential_added
  | :last_credential_added_time
  | :last_credential_removed
  | :last_credential_removed_time
  | :last_key_server
  | :last_notify_record
  | :last_priority
  | :last_restart_reason
  | :last_restore_time
  | :last_state_change
  | :last_use_time
  | :life_safety_alarm_values
  | :lighting_command
  | :lighting_command_default_priority
  | :limit_enable
  | :limit_monitoring_interval
  | :link_speed
  | :link_speed_autonegotiate
  | :link_speeds
  | :list_of_group_members
  | :list_of_object_property_references
  | :local_date
  | :local_forwarding_only
  | :local_time
  | :location
  | :lock_status
  | :lockout
  | :lockout_relinquish_time
  | :log_buffer
  | :log_device_object_property
  | :log_interval
  | :logging_object
  | :logging_record
  | :logging_type
  | :low_diff_limit
  | :low_limit
  | :lower_deck
  | :mac_address
  | :machine_room_id
  | :maintenance_required
  | :making_car_call
  | :manipulated_variable_reference
  | :manual_slave_address_binding
  | :masked_alarm_values
  | :max_actual_value
  | :max_apdu_length_accepted
  | :max_failed_attempts
  | :max_info_frames
  | :max_master
  | :max_output
  | :max_present_value
  | :max_segments_accepted
  | :max_value
  | :max_value_timestamp
  | :member_of
  | :member_status_flags
  | :members
  | :min_actual_value
  | :min_off_time
  | :min_on_time
  | :min_output
  | :min_present_value
  | :min_value
  | :min_value_timestamp
  | :mode
  | :model_name
  | :modification_date
  | :muster_point
  | :negative_access_rules
  | :network_access_security_policies
  | :network_interface_name
  | :network_number
  | :network_number_quality
  | :network_type
  | :next_stopping_floor
  | :node_subtype
  | :node_type
  | :notification_class
  | :notification_threshold
  | :notify_type
  | :number_of_apdu_retries
  | :number_of_authentication_policies
  | :number_of_states
  | :object_identifier
  | :object_list
  | :object_name
  | :object_property_reference
  | :object_type
  | :occupancy_count
  | :occupancy_count_adjust
  | :occupancy_count_enable
  | :occupancy_lower_limit
  | :occupancy_lower_limit_enforced
  | :occupancy_state
  | :occupancy_upper_limit
  | :occupancy_upper_limit_enforced
  | :operation_direction
  | :operation_expected
  | :optional
  | :out_of_service
  | :output_units
  | :packet_reorder_time
  | :passback_mode
  | :passback_timeout
  | :passenger_alarm
  | :polarity
  | :port_filter
  | :positive_access_rules
  | :power
  | :power_mode
  | :prescale
  | :present_value
  | :priority
  | :priority_array
  | :priority_for_writing
  | :process_identifier
  | :process_identifier_filter
  | :profile_location
  | :profile_name
  | :program_change
  | :program_location
  | :program_state
  | :property_list
  | :proportional_constant
  | :proportional_constant_units
  | :protocol_level
  | :protocol_object_types_supported
  | :protocol_revision
  | :protocol_services_supported
  | :protocol_version
  | :pulse_rate
  | :read_only
  | :reason_for_disable
  | :reason_for_halt
  | :recipient_list
  | :record_count
  | :records_since_notification
  | :reference_port
  | :registered_car_call
  | :reliability
  | :reliability_evaluation_inhibit
  | :relinquish_default
  | :represents
  | :requested_shed_level
  | :requested_update_interval
  | :required
  | :resolution
  | :restart_notification_recipients
  | :restore_completion_time
  | :restore_preparation_time
  | :routing_table
  | :scale
  | :scale_factor
  | :schedule_default
  | :secured_status
  | :security_pdu_timeout
  | :security_time_window
  | :segmentation_supported
  | :serial_number
  | :setpoint
  | :setpoint_reference
  | :setting
  | :shed_duration
  | :shed_level_descriptions
  | :shed_levels
  | :silenced
  | :slave_address_binding
  | :slave_proxy_enable
  | :start_time
  | :state_change_values
  | :state_description
  | :state_text
  | :status_flags
  | :stop_time
  | :stop_when_full
  | :strike_count
  | :structured_object_list
  | :subordinate_annotations
  | :subordinate_list
  | :subordinate_node_types
  | :subordinate_relationships
  | :subordinate_tags
  | :subscribed_recipients
  | :supported_format_classes
  | :supported_formats
  | :supported_security_algorithms
  | :system_status
  | :tags
  | :threat_authority
  | :threat_level
  | :time_delay
  | :time_delay_normal
  | :time_of_active_time_reset
  | :time_of_device_restart
  | :time_of_state_count_reset
  | :time_of_strike_count_reset
  | :time_synchronization_interval
  | :time_synchronization_recipients
  | :timer_running
  | :timer_state
  | :total_record_count
  | :trace_flag
  | :tracking_value
  | :transaction_notification_class
  | :transition
  | :trigger
  | :units
  | :update_interval
  | :update_key_set_timeout
  | :update_time
  | :user_external_identifier
  | :user_information_reference
  | :user_name
  | :user_type
  | :uses_remaining
  | :utc_offset
  | :utc_time_synchronization_recipients
  | :valid_samples
  | :value_before_change
  | :value_change_time
  | :value_set
  | :value_source
  | :value_source_array
  | :variance_value
  | :vendor_identifier
  | :vendor_name
  | :verification_time
  | :virtual_mac_address_table
  | :vt_classes_supported
  | :weekly_schedule
  | :window_interval
  | :window_samples
  | :write_status
  | :zone_from
  | :zone_members
  | :zone_to
```

# `property_state`

```elixir
@type property_state() ::
  :access_credential_disable
  | :access_credential_disable_reason
  | :access_event
  | :action
  | :authentication_status
  | :backup_state
  | :bacnet_ip_mode
  | :binary_lighting_value
  | :binary_value
  | :boolean_value
  | :door_alarm_state
  | :door_secured_status
  | :door_status
  | :door_value
  | :escalator_fault
  | :escalator_mode
  | :escalator_operation_direction
  | :event_type
  | :extended_value
  | :file_access_method
  | :integer_value
  | :life_safety_mode
  | :life_safety_operation
  | :life_safety_state
  | :lift_car_direction
  | :lift_car_door_command
  | :lift_car_drive_status
  | :lift_car_mode
  | :lift_fault
  | :lift_group_mode
  | :lighting_in_progress
  | :lighting_operation
  | :lighting_transition
  | :lock_status
  | :maintenance
  | :network_number_quality
  | :network_port_command
  | :network_type
  | :node_type
  | :notify_type
  | :polarity
  | :program_change
  | :program_state
  | :protocol_level
  | :reason_for_halt
  | :reliability
  | :restart_reason
  | :security_level
  | :shed_state
  | :silenced_state
  | :state
  | :system_status
  | :timer_state
  | :timer_transition
  | :units
  | :unsigned_value
  | :write_status
  | :zone_occupancy_state
```

# `protocol_level`

```elixir
@type protocol_level() ::
  :bacnet_application | :non_bacnet_application | :physical | :protocol
```

# `protocol_revision`

```elixir
@type protocol_revision() :: :default | :revision_14
```

When creating BACnet objects, the designated revision can
be chosen from the constants. The designated revision decides
which properties are required. Optional properties are regardless
of the revision available.

The following revisions are supported (to be):
- Revision 14 (135-2012)
- Revision 19 (135-2016)
- Revision 22 (135-2022)

The default BACnet Revision is 14 (2012).

# `reinitialized_state`

```elixir
@type reinitialized_state() ::
  :abortrestore
  | :activate_changes
  | :coldstart
  | :endbackup
  | :endrestore
  | :startbackup
  | :startrestore
  | :warmstart
```

Reinitialized State (ASHRAE 135 - 16.4.1.1.1 Reinitialized State of Device)

# `reject_reason`

```elixir
@type reject_reason() ::
  :buffer_overflow
  | :inconsistent_parameters
  | :invalid_parameter_data_type
  | :invalid_tag
  | :missing_required_parameter
  | :other
  | :parameter_out_of_range
  | :too_many_arguments
  | :undefined_enumeration
  | :unrecognized_service
```

# `relationship`

```elixir
@type relationship() ::
  :adjusted_by
  | :adjusts
  | :commanded_by
  | :commands
  | :contained_by
  | :contains
  | :default
  | :egress
  | :ingress
  | :receives_air
  | :receives_cool_air
  | :receives_cool_water
  | :receives_gas
  | :receives_hot_air
  | :receives_hot_water
  | :receives_power
  | :receives_steam
  | :receives_water
  | :supplies_air
  | :supplies_cool_air
  | :supplies_cool_water
  | :supplies_gas
  | :supplies_hot_air
  | :supplies_hot_water
  | :supplies_power
  | :supplies_steam
  | :supplies_water
  | :unknown
  | :used_by
  | :uses
```

# `reliability`

```elixir
@type reliability() ::
  :activation_failure
  | :communication_failure
  | :configuration_error
  | :faults_listed
  | :lamp_failure
  | :member_fault
  | :monitored_object_fault
  | :multi_state_fault
  | :no_fault_detected
  | :no_output
  | :no_sensor
  | :open_loop
  | :over_range
  | :process_error
  | :proprietary_command_failure
  | :referenced_object_fault
  | :renew_dhcp_failure
  | :renew_fd_registration_failure
  | :restart_auto_negotiation_failure
  | :restart_failure
  | :shorted_loop
  | :tripped
  | :under_range
  | :unreliable_other
```

# `restart_reason`

```elixir
@type restart_reason() ::
  :activate_changes
  | :coldstart
  | :detected_power_lost
  | :detected_powered_off
  | :hardware_watchdog
  | :software_watchdog
  | :suspended
  | :unknown
  | :warmstart
```

# `result_flag`

```elixir
@type result_flag() :: :first_item | :last_item | :more_items
```

# `security_level`

```elixir
@type security_level() ::
  :encrypted
  | :encrypted_end_to_end
  | :incapable
  | :plain
  | :signed
  | :signed_end_to_end
```

# `security_policy`

```elixir
@type security_policy() ::
  :encrypted_trusted | :plain_non_trusted | :plain_trusted | :signed_trusted
```

# `segmentation`

```elixir
@type segmentation() ::
  :no_segmentation | :segmented_both | :segmented_receive | :segmented_transmit
```

# `services_supported`

```elixir
@type services_supported() ::
  :acknowledge_alarm
  | :add_list_element
  | :atomic_read_file
  | :atomic_write_file
  | :authenticate
  | :confirmed_cov_notification
  | :confirmed_cov_notification_multiple
  | :confirmed_event_notification
  | :confirmed_private_transfer
  | :confirmed_text_message
  | :create_object
  | :delete_object
  | :device_communication_control
  | :get_alarm_summary
  | :get_enrollment_summary
  | :get_event_information
  | :i_am
  | :i_have
  | :life_safety_operation
  | :read_property
  | :read_property_conditional
  | :read_property_multiple
  | :read_range
  | :reinitialize_device
  | :remove_list_element
  | :request_key
  | :subscribe_cov
  | :subscribe_cov_property
  | :subscribe_cov_property_multiple
  | :time_synchronization
  | :unconfirmed_cov_notification
  | :unconfirmed_cov_notification_multiple
  | :unconfirmed_event_notification
  | :unconfirmed_private_transfer
  | :unconfirmed_text_message
  | :utc_time_synchronization
  | :vt_close
  | :vt_data
  | :vt_open
  | :who_has
  | :who_is
  | :write_group
  | :write_property
  | :write_property_multiple
```

# `shed_state`

```elixir
@type shed_state() ::
  :shed_compliant | :shed_inactive | :shed_non_compliant | :shed_request_pending
```

# `silenced_state`

```elixir
@type silenced_state() ::
  :all_silenced | :audible_silenced | :unsilenced | :visible_silenced
```

# `status_flag`

```elixir
@type status_flag() :: :fault | :in_alarm | :out_of_service | :overridden
```

# `timer_state`

```elixir
@type timer_state() :: :expired | :idle | :running
```

# `timer_transition`

```elixir
@type timer_transition() ::
  :expired_to_idle
  | :expired_to_running
  | :forced_to_expired
  | :idle_to_running
  | :none
  | :running_to_expired
  | :running_to_idle
  | :running_to_running
```

# `unconfirmed_service_choice`

```elixir
@type unconfirmed_service_choice() ::
  :i_am
  | :i_have
  | :time_synchronization
  | :unconfirmed_cov_notification
  | :unconfirmed_cov_notification_multiple
  | :unconfirmed_event_notification
  | :unconfirmed_private_transfer
  | :unconfirmed_text_message
  | :utc_time_synchronization
  | :who_has
  | :who_is
  | :write_group
```

# `vt_class`

```elixir
@type vt_class() ::
  :ansi_x3_64
  | :dec_vt100
  | :dec_vt220
  | :dec_vt52
  | :default_terminal
  | :hp_700_94
  | :ibm_3130
```

# `write_status`

```elixir
@type write_status() :: :failed | :idle | :in_progress | :successful
```

# `assert_name`

```elixir
@spec assert_name(atom(), atom()) :: {:ok, atom()} | :error
```

Assert that the given constant is defined. This function returns the name of the constant.

# `assert_name!`

```elixir
@spec assert_name!(atom(), atom()) :: atom()
```

Assert that the given constant is defined. This function returns the name of the constant.
If the constant does not exist, the call will raise.

# `by_name`

```elixir
@spec by_name(atom(), atom()) :: {:ok, term()} | :error
```

Retrieve the value of a constant, identified by `type` and `name`.

# `by_name`

```elixir
@spec by_name(atom(), atom(), term()) :: term()
```

Retrieve the value of a constant, identified by `type` and `name`. If found,
the value will be returned, otherwise the default will be returned.

# `by_name!`

```elixir
@spec by_name!(atom(), atom()) :: term()
```

Retrieve the value of a constant, identified by `type` and `name`.
If the constant does not exist, the call will raise.

# `by_name_atom`

```elixir
@spec by_name_atom(atom(), atom() | term()) :: term() | no_return()
```

Equivalent to `by_name/3`, however it uses `by_name!/2`
when the name is an atom. If the name is not an atom, it is returned as-is.

# `by_name_with_reason`

```elixir
@spec by_name_with_reason(atom(), term(), term()) ::
  {:ok, term()} | {:error, reason :: term()}
```

Equivalent to `by_name/2`, however instead of returning plain `:error`,
it returns `{:error, reason}`, where `reason` is user-supplied.

# `by_value`

```elixir
@spec by_value(atom(), term()) :: {:ok, atom()} | :error
```

Retrieve the name of a constant, identified by `type` and `value`.

# `by_value`

```elixir
@spec by_value(atom(), term(), term()) :: term()
```

Retrieve the value of a constant, identified by `type` and `value`. If found,
the name will be returned, otherwise the default will be returned.

# `by_value!`

```elixir
@spec by_value!(atom(), term()) :: atom()
```

Retrieve the name of a constant, identified by `type` and `value`.
If the constant does not exist, the call will raise.

# `by_value_with_reason`

```elixir
@spec by_value_with_reason(atom(), term(), term()) ::
  {:ok, term()} | {:error, reason :: term()}
```

Equivalent to `by_value/2`, however instead of returning plain `:error`,
it returns `{:error, reason}`, where `reason` is user-supplied.

# `has_by_name`

```elixir
@spec has_by_name(atom(), atom()) :: bool()
```

Checks if the constant exists, identified by `type` and `name`.

# `has_by_value`

```elixir
@spec has_by_value(atom(), term()) :: bool()
```

Checks if the constant exists, identified by `type` and `value`.

# `macro_assert_name`
*macro* 

Same as `assert_name!/2`, but as compile-time macro.

As this is a macro, this can be used to compile the constant name into the resulting BEAM,
asserting the constant exists.

# `macro_by_name`
*macro* 

Same as `by_name!/2`, but as compile-time macro.

As this is a macro, this can be used to compile the constant value into the resulting BEAM.

# `macro_by_value`
*macro* 

Same as `by_value!/2`, but as compile-time macro.

As this is a macro, this can be used to compile the constant name into the resulting BEAM.

# `macro_list_all`
*macro* 

```elixir
@spec macro_list_all(atom()) :: Macro.t()
```

Get a list of all valid constant names values for the given type (in keyword list form).

# `macro_list_names`
*macro* 

```elixir
@spec macro_list_names(atom()) :: Macro.t()
```

Get a list of all valid constant names for the given type.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
