defmodule BACnet.Test.Protocol.ObjectTypes.CharacterStringValueTest do
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectTypes.CharacterStringValue
  alias BACnet.Protocol.PriorityArray
  alias BACnet.Test.Support.Protocol.ObjectExecutionTestHost, as: Host

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_character_string_value

  @now ~U[2026-11-09 12:00:00Z]

  test "an empty CHARACTER STRING remains active until a NULL command relinquishes it" do
    message = " Lüftung – bereit "

    {:ok, object} =
      CharacterStringValue.create(10, "Message", %{
        present_value: "Idle",
        relinquish_default: "Idle"
      })

    host = Host.new([{object, []}], @now, 0)
    id = CharacterStringValue.get_object_identifier(object)
    assert :ok = Host.execute(host, id, :initialization)

    reference = %DeviceObjectPropertyRef{
      device_identifier: nil,
      object_identifier: id,
      property_identifier: :present_value,
      property_array_index: nil
    }

    assert {:ok, wire} = ApplicationTags.encode({:character_string, message})
    assert {:ok, {:character_string, ^message}, <<>>} = ApplicationTags.decode(wire)

    empty = Encoding.create!({:character_string, ""})
    lower = Encoding.create!({:character_string, message})
    relinquish = Encoding.create!({:null, nil})

    assert :ok = Host.write(host, reference, lower)
    assert :ok = Host.write(host, reference, empty, 8)
    assert {:ok, ""} = Host.read(host, reference)
    object = Host.snapshot(host, id).object
    assert {8, ""} = CharacterStringValue.get_priority_value(object)

    assert {:ok, slots} =
             ObjectsUtility.cast_value_to_property(id, :priority_array, object.priority_array)

    assert %Encoding{type: :character_string, value: ""} = Enum.at(slots, 7)
    assert %Encoding{type: :character_string, value: ^message} = Enum.at(slots, 15)

    assert :ok = Host.write(host, reference, relinquish, 8)
    assert {:ok, ^message} = Host.read(host, reference)
    assert :ok = Host.write(host, reference, relinquish)
    assert {:ok, "Idle"} = Host.read(host, reference)
    assert Host.snapshot(host, id).next_execution == nil
  end

  test "direct writes preserve string contents and reject invalid UTF-8" do
    stored = initialize(%{present_value: "Ready"})

    assert {:error, {:invalid_property_type, :present_value}} =
             write(stored, :present_value, <<255>>, :application_write)

    message = "  e\u0301  "
    {:ok, updated} = write(stored, :present_value, message, :application_write)
    assert updated.object.present_value == message
    {:ok, cleared} = write(updated, :present_value, "", :application_write)
    assert cleared.object.present_value == ""
  end

  test "service isolation blocks application writes and preserves BACnet arbitration" do
    stored =
      initialize(%{present_value: "Idle", relinquish_default: "Idle", out_of_service: true})

    {:ok, high} = write(stored, :present_value, "Active", :property_write, 8)
    assert {:error, :out_of_service} = write(high, :present_value, "Active", :application_write)

    {:ok, masked} = write(high, :relinquish_default, "Active", :application_write)
    {:ok, released} = write(masked, :present_value, nil, :property_write, 8)
    assert released.object.present_value == "Active"

    assert {:error, :out_of_service} =
             write(released, :relinquish_default, "Idle", :application_write)

    {:ok, in_service} = write(released, :out_of_service, false, :application_write)
    {:ok, updated} = write(in_service, :present_value, "Idle", :application_write)
    assert updated.object.present_value == "Idle"
  end

  test "an absent Out_Of_Service property is treated as in service" do
    {:ok, object} =
      CharacterStringValue.create(10, "Message", %{present_value: "Idle", out_of_service: true})

    {:ok, object} = CharacterStringValue.remove_property(object, :out_of_service)
    {:ok, stored} = Lifecycle.execute(object, context(nil, :initialization))

    assert stored.object.status_flags.out_of_service == false
    {:ok, changed} = write(stored, :present_value, "Active", :application_write)
    assert changed.object.present_value == "Active"
  end

  test "priority six is reserved for local commandable objects" do
    stored = initialize(%{present_value: "Idle", relinquish_default: "Idle"})

    for value <- ["Active", nil] do
      assert {:error, :write_access_denied} =
               CharacterStringValue.set_priority(stored.object, 6, value)
    end

    ctx = context(stored, {:property_write, 85, nil, 6})

    assert {:error, :write_access_denied} =
             Lifecycle.prepare_write(stored.object, stored.object, ctx)

    {:ok, object} =
      CharacterStringValue.create(10, "Message", %{
        present_value: "Idle",
        relinquish_default: "Idle",
        priority_array: %PriorityArray{priority_6: "Active"}
      })

    assert {:error, {:invalid_configuration, :priority_6}} =
             Lifecycle.execute(object, context(nil, :initialization))
  end

  test "local instances require matching runtime state and remote snapshots are passive" do
    stored = initialize(%{present_value: "Ready"})
    ctx = context(stored, :periodic)
    wrong_id = %{stored.state.identifier | instance: 11}

    for state <- [nil, %{stored.state | value: <<255>>}, %{stored.state | identifier: wrong_id}] do
      assert {:error, :invalid_execution_state} =
               Lifecycle.execute(stored.object, %{ctx | state: state})
    end

    properties =
      Map.take(stored.object, [:present_value, :out_of_service, :status_flags, :event_state])

    {:ok, remote} = CharacterStringValue.create(11, "Remote", properties, remote_object: 42)

    assert :ok = CharacterStringValue.validate_execution(remote, ctx)

    assert {:ok, %Result{object: ^remote, state: :snapshot, next_execution: nil}} =
             CharacterStringValue.execute(remote, %{ctx | state: :snapshot})

    assert {:ok, %Result{object: ^remote, state: :snapshot, next_execution: nil}} =
             Lifecycle.execute(remote, %{ctx | state: :snapshot})

    write_context = context(stored, {:property_write, :present_value, nil, nil})

    assert {:error, :operation_not_available_for_remote_objects} =
             CharacterStringValue.prepare_write(remote, remote, write_context)

    assert {:error, :operation_not_available_for_remote_objects} =
             Lifecycle.prepare_write(remote, remote, write_context)
  end

  test "Reliability reports survive inhibition and simulation remains available" do
    for origin <- [:property_write, :application_write] do
      stored = initialize(%{present_value: "Active", reliability: :process_error})
      {:ok, inhibited} = write(stored, :reliability_evaluation_inhibit, true)
      assert inhibited.object.reliability == :no_fault_detected

      {:ok, reported} = write(inhibited, :reliability, :communication_failure, :application_write)
      refute reported.object.status_flags.fault

      {:ok, restored} = write(reported, :reliability_evaluation_inhibit, false)
      assert restored.object.reliability == :communication_failure
      assert restored.object.status_flags.fault

      {:ok, masked} = write(restored, :reliability_evaluation_inhibit, true)
      {:ok, isolated} = write(masked, :out_of_service, true)
      {:ok, simulated} = write(isolated, :reliability, :process_error, origin)
      assert simulated.object.reliability == :process_error
      assert simulated.object.status_flags.fault

      {:ok, resumed} = write(simulated, :out_of_service, false)
      assert resumed.object.reliability == :no_fault_detected
      refute resumed.object.status_flags.fault
    end
  end

  test "reports substring alarms and faults and clears a fault on a normal string" do
    alarm_values = BACnetArray.from_list(["Alarm"])
    fault_values = BACnetArray.from_list(["Fault"])

    stored =
      initialize(
        %{
          present_value: "Normal",
          reliability: :no_fault_detected,
          alarm_values: alarm_values,
          fault_values: fault_values
        },
        intrinsic_reporting: true
      )

    {:ok, alarm} = write(stored, :present_value, "Alarm at input")

    assert %{
             event_type: :change_of_characterstring,
             to_state: :offnormal,
             event_values: %{alarm_value: "Alarm"}
           } = EventReporting.transition(alarm)

    {:ok, faulty} = write(alarm, :present_value, "Fault at input")
    assert faulty.object.reliability == :multi_state_fault

    assert %{event_type: :change_of_reliability, to_state: :fault} =
             EventReporting.transition(faulty)

    {:ok, normal} = write(faulty, :present_value, "Normal")
    assert normal.object.reliability == :no_fault_detected

    assert %{event_type: :change_of_reliability, to_state: :normal} =
             EventReporting.transition(normal)
  end

  defp initialize(properties, options \\ []) do
    {:ok, object} = CharacterStringValue.create(10, "Message", properties, options)
    {:ok, stored} = Lifecycle.execute(object, context(nil, :initialization))
    stored
  end

  defp context(stored, trigger) do
    Context.new(trigger, now: @now, monotonic_time: 0, state: if(stored, do: stored.state))
  end

  defp write(stored, property, value, origin \\ :property_write, priority \\ nil) do
    ctx = context(stored, {origin, property, nil, priority})

    candidate =
      if property == :present_value and CharacterStringValue.has_priority_array?(stored.object),
        do: CharacterStringValue.set_priority(stored.object, priority || 16, value),
        else: CharacterStringValue.update_property(stored.object, property, value)

    with {:ok, candidate} <- candidate,
         {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
      CharacterStringValue.execute(prepared, ctx)
    end
  end
end
