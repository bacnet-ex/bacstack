defmodule BACnet.Protocol.Device.ServicesSupportedTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.Device.ServicesSupported

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest ServicesSupported

  test "decode ServicesSupported" do
    assert {:ok,
            %ServicesSupported{
              acknowledge_alarm: true,
              confirmed_cov_notification: true,
              confirmed_event_notification: false,
              get_alarm_summary: true,
              get_enrollment_summary: true,
              subscribe_cov: true,
              atomic_read_file: true,
              atomic_write_file: true,
              add_list_element: true,
              remove_list_element: true,
              create_object: true,
              delete_object: true,
              read_property: true,
              read_property_conditional: false,
              read_property_multiple: true,
              write_property: true,
              write_property_multiple: true,
              device_communication_control: true,
              confirmed_private_transfer: false,
              confirmed_text_message: false,
              reinitialize_device: true,
              vt_open: false,
              vt_close: false,
              vt_data: false,
              authenticate: false,
              request_key: false,
              i_am: true,
              i_have: true,
              unconfirmed_cov_notification: true,
              unconfirmed_event_notification: false,
              unconfirmed_private_transfer: false,
              unconfirmed_text_message: false,
              time_synchronization: true,
              who_has: true,
              who_is: true,
              read_range: true,
              utc_time_synchronization: true,
              life_safety_operation: false,
              subscribe_cov_property: true,
              get_event_information: true,
              write_group: false,
              subscribe_cov_property_multiple: false,
              confirmed_cov_notification_multiple: false,
              unconfirmed_cov_notification_multiple: false
            }} =
             ServicesSupported.parse(
               bitstring:
                 {true, true, false, true, true, true, true, true, true, true, true, true, true,
                  false, true, true, true, true, false, false, true, false, false, false, false,
                  false, true, true, true, false, false, false, true, true, true, true, true,
                  false, true, true, false, false, false, false, false, false, false, false,
                  false}
             )
  end

  test "decode ServicesSupported 2" do
    assert {:ok,
            %ServicesSupported{
              acknowledge_alarm: true,
              confirmed_cov_notification: true,
              confirmed_event_notification: false,
              get_alarm_summary: true,
              get_enrollment_summary: true,
              subscribe_cov: true,
              atomic_read_file: true,
              atomic_write_file: true,
              add_list_element: true,
              remove_list_element: true,
              create_object: true,
              delete_object: true,
              read_property: true,
              read_property_conditional: false,
              read_property_multiple: true,
              write_property: true,
              write_property_multiple: true,
              device_communication_control: true,
              confirmed_private_transfer: false,
              confirmed_text_message: false,
              reinitialize_device: true,
              vt_open: false,
              vt_close: false,
              vt_data: false,
              authenticate: false,
              request_key: false,
              i_am: true,
              i_have: true,
              unconfirmed_cov_notification: true,
              unconfirmed_event_notification: false,
              unconfirmed_private_transfer: false,
              unconfirmed_text_message: false,
              time_synchronization: true,
              who_has: true,
              who_is: true,
              read_range: true,
              utc_time_synchronization: true,
              life_safety_operation: false,
              subscribe_cov_property: true,
              get_event_information: true,
              write_group: false,
              subscribe_cov_property_multiple: true,
              confirmed_cov_notification_multiple: false,
              unconfirmed_cov_notification_multiple: true
            }} =
             ServicesSupported.parse(
               bitstring:
                 {true, true, false, true, true, true, true, true, true, true, true, true, true,
                  false, true, true, true, true, false, false, true, false, false, false, false,
                  false, true, true, true, false, false, false, true, true, true, true, true,
                  false, true, true, false, true, false, true}
             )
  end

  test "decode ServicesSupported with less defaults to false" do
    assert {:ok,
            %ServicesSupported{
              acknowledge_alarm: true,
              confirmed_cov_notification: true,
              confirmed_event_notification: false,
              get_alarm_summary: true,
              get_enrollment_summary: true,
              subscribe_cov: true,
              atomic_read_file: false,
              atomic_write_file: false,
              add_list_element: false,
              remove_list_element: false,
              create_object: false,
              delete_object: false,
              read_property: false,
              read_property_conditional: false,
              read_property_multiple: false,
              write_property: false,
              write_property_multiple: false,
              device_communication_control: false,
              confirmed_private_transfer: false,
              confirmed_text_message: false,
              reinitialize_device: false,
              vt_open: false,
              vt_close: false,
              vt_data: false,
              authenticate: false,
              request_key: false,
              i_am: false,
              i_have: false,
              unconfirmed_cov_notification: false,
              unconfirmed_event_notification: false,
              unconfirmed_private_transfer: false,
              unconfirmed_text_message: false,
              time_synchronization: false,
              who_has: false,
              who_is: false,
              read_range: false,
              utc_time_synchronization: false,
              life_safety_operation: false,
              subscribe_cov_property: false,
              get_event_information: false,
              write_group: false,
              subscribe_cov_property_multiple: false,
              confirmed_cov_notification_multiple: false,
              unconfirmed_cov_notification_multiple: false
            }} = ServicesSupported.parse(bitstring: {true, true, false, true, true, true})
  end

  test "decode ServicesSupported with ApplicationTags.Encoding and less defaults to false" do
    assert {:ok,
            %ServicesSupported{
              acknowledge_alarm: true,
              confirmed_cov_notification: true,
              confirmed_event_notification: false,
              get_alarm_summary: true,
              get_enrollment_summary: true,
              subscribe_cov: true,
              atomic_read_file: false,
              atomic_write_file: false,
              add_list_element: false,
              remove_list_element: false,
              create_object: false,
              delete_object: false,
              read_property: false,
              read_property_conditional: false,
              read_property_multiple: false,
              write_property: false,
              write_property_multiple: false,
              device_communication_control: false,
              confirmed_private_transfer: false,
              confirmed_text_message: false,
              reinitialize_device: false,
              vt_open: false,
              vt_close: false,
              vt_data: false,
              authenticate: false,
              request_key: false,
              i_am: false,
              i_have: false,
              unconfirmed_cov_notification: false,
              unconfirmed_event_notification: false,
              unconfirmed_private_transfer: false,
              unconfirmed_text_message: false,
              time_synchronization: false,
              who_has: false,
              who_is: false,
              read_range: false,
              utc_time_synchronization: false,
              life_safety_operation: false,
              subscribe_cov_property: false,
              get_event_information: false,
              write_group: false,
              subscribe_cov_property_multiple: false,
              confirmed_cov_notification_multiple: false,
              unconfirmed_cov_notification_multiple: false
            }} =
             ServicesSupported.parse(
               Encoding.create!({:bitstring, {true, true, false, true, true, true}})
             )
  end

  test "decode ServicesSupported invalid tags" do
    assert {:error, :invalid_tags} = ServicesSupported.parse([])
    assert {:error, :invalid_tags} = ServicesSupported.parse(real: 0.0)
  end

  test "encode ServicesSupported" do
    assert {:ok,
            [
              bitstring:
                {true, true, false, true, true, true, true, true, true, true, true, true, true,
                 false, true, true, true, true, false, false, true, false, false, false, false,
                 false, true, true, true, false, false, false, true, true, true, true, true,
                 false, true, true, false, false, false, false}
            ]} =
             ServicesSupported.encode(%ServicesSupported{
               acknowledge_alarm: true,
               confirmed_cov_notification: true,
               confirmed_event_notification: false,
               get_alarm_summary: true,
               get_enrollment_summary: true,
               subscribe_cov: true,
               atomic_read_file: true,
               atomic_write_file: true,
               add_list_element: true,
               remove_list_element: true,
               create_object: true,
               delete_object: true,
               read_property: true,
               read_property_conditional: false,
               read_property_multiple: true,
               write_property: true,
               write_property_multiple: true,
               device_communication_control: true,
               confirmed_private_transfer: false,
               confirmed_text_message: false,
               reinitialize_device: true,
               vt_open: false,
               vt_close: false,
               vt_data: false,
               authenticate: false,
               request_key: false,
               i_am: true,
               i_have: true,
               unconfirmed_cov_notification: true,
               unconfirmed_event_notification: false,
               unconfirmed_private_transfer: false,
               unconfirmed_text_message: false,
               time_synchronization: true,
               who_has: true,
               who_is: true,
               read_range: true,
               utc_time_synchronization: true,
               life_safety_operation: false,
               subscribe_cov_property: true,
               get_event_information: true,
               write_group: false,
               subscribe_cov_property_multiple: false,
               confirmed_cov_notification_multiple: false,
               unconfirmed_cov_notification_multiple: false
             })
  end

  test "encode ServicesSupported 2" do
    assert {:ok,
            [
              bitstring:
                {true, true, false, true, true, true, true, true, true, true, true, true, true,
                 false, true, true, true, true, false, false, true, false, false, false, false,
                 false, true, true, true, false, false, false, true, true, true, true, true,
                 false, true, true, false, true, false, true}
            ]} =
             ServicesSupported.encode(%ServicesSupported{
               acknowledge_alarm: true,
               confirmed_cov_notification: true,
               confirmed_event_notification: false,
               get_alarm_summary: true,
               get_enrollment_summary: true,
               subscribe_cov: true,
               atomic_read_file: true,
               atomic_write_file: true,
               add_list_element: true,
               remove_list_element: true,
               create_object: true,
               delete_object: true,
               read_property: true,
               read_property_conditional: false,
               read_property_multiple: true,
               write_property: true,
               write_property_multiple: true,
               device_communication_control: true,
               confirmed_private_transfer: false,
               confirmed_text_message: false,
               reinitialize_device: true,
               vt_open: false,
               vt_close: false,
               vt_data: false,
               authenticate: false,
               request_key: false,
               i_am: true,
               i_have: true,
               unconfirmed_cov_notification: true,
               unconfirmed_event_notification: false,
               unconfirmed_private_transfer: false,
               unconfirmed_text_message: false,
               time_synchronization: true,
               who_has: true,
               who_is: true,
               read_range: true,
               utc_time_synchronization: true,
               life_safety_operation: false,
               subscribe_cov_property: true,
               get_event_information: true,
               write_group: false,
               subscribe_cov_property_multiple: true,
               confirmed_cov_notification_multiple: false,
               unconfirmed_cov_notification_multiple: true
             })
  end
end
