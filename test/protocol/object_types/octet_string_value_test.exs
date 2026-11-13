defmodule BACnet.Test.Protocol.ObjectTypes.OctetStringValueTest do
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectTypes.OctetStringValue
  alias BACnet.Protocol.PriorityArray
  alias BACnet.Test.Support.Protocol.ObjectExecutionTestHost, as: Host

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_octet_string_value

  @now ~U[2026-11-09 12:00:00Z]

  test "an empty OCTET STRING remains active until a NULL command relinquishes it" do
    payload = <<0, 255, 128, 0, 195, 40, 255>>

    {:ok, object} =
      OctetStringValue.create(10, "Payload", %{
        present_value: <<1, 0>>,
        relinquish_default: <<1, 0>>
      })

    host = Host.new([{object, []}], @now, 0)
    id = OctetStringValue.get_object_identifier(object)
    assert :ok = Host.execute(host, id, :initialization)

    reference = %DeviceObjectPropertyRef{
      device_identifier: nil,
      object_identifier: id,
      property_identifier: :present_value,
      property_array_index: nil
    }

    for value <- [payload, <<>>] do
      assert {:ok, wire} = ApplicationTags.encode({:octet_string, value})
      assert {:ok, {:octet_string, ^value}, <<>>} = ApplicationTags.decode(wire)
    end

    empty = Encoding.create!({:octet_string, <<>>})
    lower = Encoding.create!({:octet_string, payload})
    relinquish = Encoding.create!({:null, nil})

    assert :ok = Host.write(host, reference, lower)
    assert :ok = Host.write(host, reference, empty, 8)
    assert {:ok, <<>>} = Host.read(host, reference)
    object = Host.snapshot(host, id).object
    assert {8, <<>>} = OctetStringValue.get_priority_value(object)

    assert {:ok, slots} =
             ObjectsUtility.cast_value_to_property(id, :priority_array, object.priority_array)

    assert %Encoding{type: :octet_string, value: <<>>} = Enum.at(slots, 7)
    assert %Encoding{type: :octet_string, value: ^payload} = Enum.at(slots, 15)

    assert :ok = Host.write(host, reference, relinquish, 8)
    assert {:ok, ^payload} = Host.read(host, reference)
    assert :ok = Host.write(host, reference, relinquish)
    assert {:ok, <<1, 0>>} = Host.read(host, reference)
    assert Host.snapshot(host, id).next_execution == nil
  end

  test "direct writes preserve arbitrary bytes and reject partial octets" do
    stored = initialize(%{present_value: <<0>>})

    assert {:error, {:invalid_property_type, :present_value}} =
             write(stored, :present_value, <<1::size(1)>>, :application_write)

    payload = <<0, 255, 0, 254, 0>>
    {:ok, updated} = write(stored, :present_value, payload, :application_write)
    assert updated.object.present_value == payload
    {:ok, cleared} = write(updated, :present_value, <<>>, :application_write)
    assert cleared.object.present_value == <<>>
  end

  test "service isolation blocks application writes and preserves BACnet arbitration" do
    stored =
      initialize(%{present_value: <<1, 0>>, relinquish_default: <<1, 0>>, out_of_service: true})

    {:ok, high} = write(stored, :present_value, <<0, 255>>, :property_write, 8)
    assert {:error, :out_of_service} = write(high, :present_value, <<0, 255>>, :application_write)

    {:ok, masked} = write(high, :relinquish_default, <<0, 255>>, :application_write)
    {:ok, released} = write(masked, :present_value, nil, :property_write, 8)
    assert released.object.present_value == <<0, 255>>

    assert {:error, :out_of_service} =
             write(released, :relinquish_default, <<1, 0>>, :application_write)

    {:ok, in_service} = write(released, :out_of_service, false, :application_write)
    {:ok, updated} = write(in_service, :present_value, <<1, 0>>, :application_write)
    assert updated.object.present_value == <<1, 0>>
  end

  test "an absent Out_Of_Service property is treated as in service" do
    {:ok, object} =
      OctetStringValue.create(10, "Payload", %{present_value: <<1, 0>>, out_of_service: true})

    {:ok, object} = OctetStringValue.remove_property(object, :out_of_service)
    {:ok, stored} = Lifecycle.execute(object, context(nil, :initialization))

    assert stored.object.status_flags.out_of_service == false
    {:ok, changed} = write(stored, :present_value, <<0, 255>>, :application_write)
    assert changed.object.present_value == <<0, 255>>
  end

  test "priority six is reserved for local commandable objects" do
    stored = initialize(%{present_value: <<1, 0>>, relinquish_default: <<1, 0>>})

    for value <- [<<0, 255>>, nil] do
      assert {:error, :write_access_denied} =
               OctetStringValue.set_priority(stored.object, 6, value)
    end

    ctx = context(stored, {:property_write, 85, nil, 6})

    assert {:error, :write_access_denied} =
             Lifecycle.prepare_write(stored.object, stored.object, ctx)

    {:ok, object} =
      OctetStringValue.create(10, "Payload", %{
        present_value: <<1, 0>>,
        relinquish_default: <<1, 0>>,
        priority_array: %PriorityArray{priority_6: <<0, 255>>}
      })

    assert {:error, {:invalid_configuration, :priority_6}} =
             Lifecycle.execute(object, context(nil, :initialization))
  end

  test "local instances require matching runtime state and remote snapshots are passive" do
    stored = initialize(%{present_value: <<0>>})
    ctx = context(stored, :periodic)
    wrong_id = %{stored.state.identifier | instance: 11}

    for state <- [
          nil,
          %{stored.state | value: <<1::size(1)>>},
          %{stored.state | identifier: wrong_id}
        ] do
      assert {:error, :invalid_execution_state} =
               Lifecycle.execute(stored.object, %{ctx | state: state})
    end

    properties =
      Map.take(stored.object, [:present_value, :out_of_service, :status_flags, :event_state])

    {:ok, remote} = OctetStringValue.create(11, "Remote", properties, remote_object: 42)

    assert {:ok, %Result{object: ^remote, state: :snapshot, next_execution: nil}} =
             Lifecycle.execute(remote, %{ctx | state: :snapshot})

    write_context = context(stored, {:property_write, :present_value, nil, nil})

    assert {:error, :operation_not_available_for_remote_objects} =
             Lifecycle.prepare_write(remote, remote, write_context)
  end

  test "Reliability reports survive inhibition and simulation remains available" do
    for origin <- [:property_write, :application_write] do
      stored = initialize(%{present_value: <<0, 255>>, reliability: :process_error})
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

  test "clears the alarm flag when the optional Event_State is removed" do
    stored = initialize(%{present_value: <<0>>, event_state: :offnormal})
    assert stored.object.status_flags.in_alarm

    {:ok, object} = OctetStringValue.remove_property(stored.object, :event_state)
    read = context(stored, {:property_read, :present_value, nil})
    {:ok, updated} = Lifecycle.prepare_read(object, read)

    refute OctetStringValue.has_property?(updated.object, :event_state)
    refute updated.object.status_flags.in_alarm
    assert updated.object.present_value == <<0>>
    assert updated.next_execution == nil
  end

  defp initialize(properties) do
    {:ok, object} = OctetStringValue.create(10, "Payload", properties)
    {:ok, stored} = Lifecycle.execute(object, context(nil, :initialization))
    stored
  end

  defp context(stored, trigger) do
    Context.new(trigger, now: @now, monotonic_time: 0, state: if(stored, do: stored.state))
  end

  defp write(stored, property, value, origin \\ :property_write, priority \\ nil) do
    ctx = context(stored, {origin, property, nil, priority})

    candidate =
      if property == :present_value and OctetStringValue.has_priority_array?(stored.object),
        do: OctetStringValue.set_priority(stored.object, priority || 16, value),
        else: OctetStringValue.update_property(stored.object, property, value)

    with {:ok, candidate} <- candidate,
         {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
      Lifecycle.execute(prepared, ctx)
    end
  end
end
