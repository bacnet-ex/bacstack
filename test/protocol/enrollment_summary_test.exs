defmodule BACnet.Protocol.EnrollmentSummaryTest do
  alias BACnet.Protocol.EnrollmentSummary
  alias BACnet.Protocol.ObjectIdentifier

  use ExUnit.Case, async: true

  @moduletag :protocol_data_structures

  doctest EnrollmentSummary

  test "decode summary" do
    assert {:ok,
            {%EnrollmentSummary{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 3
               },
               event_type: :out_of_range,
               event_state: :normal,
               priority: 8,
               notification_class: nil
             },
             []}} =
             EnrollmentSummary.parse(
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 3
               },
               enumerated: 5,
               enumerated: 0,
               unsigned_integer: 8
             )
  end

  test "decode summary with notification class" do
    assert {:ok,
            {%EnrollmentSummary{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 3
               },
               event_type: :out_of_range,
               event_state: :normal,
               priority: 8,
               notification_class: 4
             },
             []}} =
             EnrollmentSummary.parse(
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 3
               },
               enumerated: 5,
               enumerated: 0,
               unsigned_integer: 8,
               unsigned_integer: 4
             )
  end

  test "decode invalid summary" do
    assert {:error, :invalid_tags} =
             EnrollmentSummary.parse(
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 3
               },
               enumerated: 5
             )
  end

  test "decode invalid summary unknown type" do
    assert {:error, {:unknown_type, 255}} =
             EnrollmentSummary.parse(
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 3
               },
               enumerated: 255,
               enumerated: 0,
               unsigned_integer: 8,
               unsigned_integer: 4
             )
  end

  test "decode invalid summary unknown state" do
    assert {:error, {:unknown_state, 255}} =
             EnrollmentSummary.parse(
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 3
               },
               enumerated: 5,
               enumerated: 255,
               unsigned_integer: 8,
               unsigned_integer: 4
             )
  end

  test "decode summary invalid priority" do
    assert {:error, :invalid_priority_value} =
             EnrollmentSummary.parse(
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 3
               },
               enumerated: 5,
               enumerated: 0,
               unsigned_integer: 256
             )
  end

  test "encode summary" do
    assert {:ok,
            [
              object_identifier: %ObjectIdentifier{
                type: :analog_input,
                instance: 3
              },
              enumerated: 5,
              enumerated: 0,
              unsigned_integer: 8
            ]} =
             EnrollmentSummary.encode(%EnrollmentSummary{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 3
               },
               event_type: :out_of_range,
               event_state: :normal,
               priority: 8,
               notification_class: nil
             })
  end

  test "encode summary with notification class" do
    assert {:ok,
            [
              object_identifier: %ObjectIdentifier{
                type: :analog_input,
                instance: 3
              },
              enumerated: 5,
              enumerated: 0,
              unsigned_integer: 8,
              unsigned_integer: 4
            ]} =
             EnrollmentSummary.encode(%EnrollmentSummary{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 3
               },
               event_type: :out_of_range,
               event_state: :normal,
               priority: 8,
               notification_class: 4
             })
  end

  test "encode summary invalid event type" do
    assert {:error, {:unknown_type, :hello_there}} =
             EnrollmentSummary.encode(%EnrollmentSummary{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 3
               },
               event_type: :hello_there,
               event_state: :normal,
               priority: 8,
               notification_class: nil
             })
  end

  test "encode summary invalid event state" do
    assert {:error, {:unknown_state, :hello_there}} =
             EnrollmentSummary.encode(%EnrollmentSummary{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 3
               },
               event_type: :out_of_range,
               event_state: :hello_there,
               priority: 8,
               notification_class: nil
             })
  end

  test "encode summary invalid priority" do
    assert {:error, :invalid_priority_value} =
             EnrollmentSummary.encode(%EnrollmentSummary{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 3
               },
               event_type: :out_of_range,
               event_state: :normal,
               priority: 512,
               notification_class: nil
             })
  end

  test "valid summary" do
    assert true ==
             EnrollmentSummary.valid?(%EnrollmentSummary{
               object_identifier: %ObjectIdentifier{
                 type: :analog_input,
                 instance: 3
               },
               event_type: :out_of_range,
               event_state: :normal,
               priority: 8,
               notification_class: 4
             })

    assert true ==
             EnrollmentSummary.valid?(%EnrollmentSummary{
               object_identifier: %ObjectIdentifier{
                 type: :device,
                 instance: 5
               },
               event_type: :out_of_range,
               event_state: :normal,
               priority: 8,
               notification_class: nil
             })
  end

  test "invalid summary" do
    assert false ==
             EnrollmentSummary.valid?(%EnrollmentSummary{
               object_identifier: :hello,
               event_type: :out_of_range,
               event_state: :normal,
               priority: 8,
               notification_class: 4
             })

    assert false ==
             EnrollmentSummary.valid?(%EnrollmentSummary{
               object_identifier: %ObjectIdentifier{
                 type: :hello,
                 instance: 5
               },
               event_type: :out_of_range,
               event_state: :normal,
               priority: 8,
               notification_class: 4
             })

    assert false ==
             EnrollmentSummary.valid?(%EnrollmentSummary{
               object_identifier: %ObjectIdentifier{
                 type: :device,
                 instance: 5
               },
               event_type: :hello,
               event_state: :normal,
               priority: 8,
               notification_class: nil
             })

    assert false ==
             EnrollmentSummary.valid?(%EnrollmentSummary{
               object_identifier: %ObjectIdentifier{
                 type: :device,
                 instance: 5
               },
               event_type: :out_of_range,
               event_state: :hello,
               priority: 8,
               notification_class: nil
             })

    assert false ==
             EnrollmentSummary.valid?(%EnrollmentSummary{
               object_identifier: %ObjectIdentifier{
                 type: :device,
                 instance: 5
               },
               event_type: :out_of_range,
               event_state: :normal,
               priority: :hello,
               notification_class: nil
             })

    assert false ==
             EnrollmentSummary.valid?(%EnrollmentSummary{
               object_identifier: %ObjectIdentifier{
                 type: :device,
                 instance: 5
               },
               event_type: :out_of_range,
               event_state: :normal,
               priority: -1,
               notification_class: nil
             })

    assert false ==
             EnrollmentSummary.valid?(%EnrollmentSummary{
               object_identifier: %ObjectIdentifier{
                 type: :device,
                 instance: 5
               },
               event_type: :out_of_range,
               event_state: :normal,
               priority: 256,
               notification_class: nil
             })

    assert false ==
             EnrollmentSummary.valid?(%EnrollmentSummary{
               object_identifier: %ObjectIdentifier{
                 type: :device,
                 instance: 5
               },
               event_type: :out_of_range,
               event_state: :normal,
               priority: 8,
               notification_class: :hello
             })

    assert false ==
             EnrollmentSummary.valid?(%EnrollmentSummary{
               object_identifier: %ObjectIdentifier{
                 type: :device,
                 instance: 5
               },
               event_type: :out_of_range,
               event_state: :normal,
               priority: 8,
               notification_class: -1
             })

    assert false ==
             EnrollmentSummary.valid?(%EnrollmentSummary{
               object_identifier: %ObjectIdentifier{
                 type: :device,
                 instance: 5
               },
               event_type: :out_of_range,
               event_state: :normal,
               priority: 8,
               notification_class: 4_294_967_300
             })
  end
end
