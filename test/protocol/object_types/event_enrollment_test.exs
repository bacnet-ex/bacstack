defmodule BACnet.Test.Protocol.ObjectTypes.EventEnrollmentTest do
  alias BACnet.Protocol.EventParameters
  alias BACnet.Protocol.FaultParameters
  alias BACnet.Protocol.ObjectTypes.EventEnrollment

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_event_enrollment

  test "event and fault types follow their parameters on creation and update" do
    event = %EventParameters.UnsignedRange{
      low_limit: 1,
      high_limit: 10,
      time_delay: 0,
      time_delay_normal: nil
    }

    fault = %FaultParameters.FaultCharacterString{fault_values: ["failed"]}

    assert {:ok, object} =
             EventEnrollment.create(1, "enrollment", %{
               notification_class: 1,
               event_parameters: event,
               fault_parameters: fault,
               fault_type: :none
             })

    assert object.event_type == :unsigned_range
    assert object.fault_type == :fault_characterstring

    assert {:ok, object} =
             EventEnrollment.update_property(object, :fault_parameters, %FaultParameters.None{})

    assert object.fault_type == :none

    assert {:ok, object} =
             EventEnrollment.update_property(object, :event_parameters, %EventParameters.None{})

    assert object.event_type == :none
  end
end
