defmodule BACnet.Test.Protocol.ObjectTypes.BitstringValueTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectTypes.BitstringValue
  alias BACnet.Protocol.PriorityArray
  alias BACnet.Test.Support.Protocol.ObjectExecutionTestHost, as: Host

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_bitstring_value

  @now ~U[2026-11-09 12:00:00Z]

  test "Bit_Text is optional and matches Present_Value when selected" do
    bits = {true, false}

    assert {:error, {:invalid_configuration, :bit_text}} =
             BitstringValue.create(10, "Flags", %{
               present_value: bits,
               bit_text: BACnetArray.from_list(["First"])
             })

    {:ok, object} = BitstringValue.create(10, "Flags", %{present_value: bits})
    refute BitstringValue.has_property?(object, :bit_text)

    assert {:error, {:invalid_configuration, :bit_text}} =
             BitstringValue.add_property(object, :bit_text, BACnetArray.from_list(["First"]))

    labels = BACnetArray.from_list(["First", "Second"], true)
    {:ok, labelled} = BitstringValue.add_property(object, :bit_text, labels)
    assert {:ok, "First"} = BACnetArray.get_item(labelled.bit_text, 1)
    assert {:ok, "Second"} = BACnetArray.get_item(labelled.bit_text, 2)

    assert {:error, {:invalid_configuration, :bit_text}} =
             BitstringValue.update_property(labelled, :present_value, {true})

    assert {:error, {:invalid_configuration, :bit_text}} =
             BitstringValue.update_property(labelled, :bit_text, BACnetArray.from_list(["Only"]))

    assert {:ok, %{present_value: {false, true}, bit_text: ^labels}} =
             BitstringValue.update_property(labelled, :present_value, {false, true})

    {:ok, unlabelled} = BitstringValue.remove_property(labelled, :bit_text)

    assert {:ok, %{present_value: {true}}} =
             BitstringValue.update_property(unlabelled, :present_value, {true})
  end

  test "a label array must contain a description at each bit index" do
    labels = BACnetArray.from_list(["First", "Second"])
    {:ok, sparse} = BACnetArray.set_item(labels, 1, :undefined)

    assert {:error, {:invalid_configuration, :bit_text}} =
             BitstringValue.create(10, "Flags", %{present_value: {true, false}, bit_text: sparse})
  end

  test "selected labels fit masked commands and the relinquish default" do
    labels = BACnetArray.from_list(["First", "Second"])

    stored =
      initialize(%{
        present_value: {false, false},
        relinquish_default: {false, false},
        bit_text: labels
      })

    {:ok, high} = write(stored, :present_value, {true, false}, :property_write, 8)

    assert {:error, {:invalid_configuration, :bit_text}} =
             write(high, :present_value, {false}, :property_write, 16)

    assert {:error, {:invalid_configuration, :bit_text}} =
             BitstringValue.set_priority(high.object, 16, {false})

    assert {:error, {:invalid_configuration, :bit_text}} =
             write(high, :relinquish_default, {false})

    assert {:error, {:invalid_configuration, :bit_text}} =
             BitstringValue.create(10, "Flags", %{
               present_value: {false, false},
               relinquish_default: {false, false},
               priority_array: %PriorityArray{priority_8: {true, false}, priority_16: {false}},
               bit_text: labels
             })
  end

  test "native BIT STRING commands arbitrate and relinquish through the host" do
    {:ok, object} =
      BitstringValue.create(10, "Flags", %{
        present_value: {false, false, false},
        relinquish_default: {false, false, false},
        bit_text: BACnetArray.from_list(["First", "Second", "Third"])
      })

    host = Host.new([{object, []}], @now, 0)
    id = BitstringValue.get_object_identifier(object)
    assert :ok = Host.execute(host, id, :initialization)

    reference = %DeviceObjectPropertyRef{
      device_identifier: nil,
      object_identifier: id,
      property_identifier: :present_value,
      property_array_index: nil
    }

    low = Encoding.create!({:bitstring, {true, false, true}})
    high = Encoding.create!({:bitstring, {false, false, false}})
    null = Encoding.create!({:null, nil})
    assert :ok = Host.write(host, reference, low)
    assert :ok = Host.write(host, reference, high, 8)
    assert {:ok, {false, false, false}} = Host.read(host, reference)
    assert :ok = Host.write(host, reference, null, 8)
    assert {:ok, {true, false, true}} = Host.read(host, reference)
    assert :ok = Host.write(host, reference, null)
    assert {:ok, {false, false, false}} = Host.read(host, reference)
    assert Host.snapshot(host, id).next_execution == nil
  end

  test "service isolation blocks application writes and preserves BACnet arbitration" do
    stored =
      initialize(%{present_value: {false}, relinquish_default: {false}, out_of_service: true})

    {:ok, high} = write(stored, :present_value, {true}, :property_write, 8)
    assert {:error, :out_of_service} = write(high, :present_value, {true}, :application_write)

    {:ok, masked} = write(high, :relinquish_default, {true}, :application_write)
    {:ok, released} = write(masked, :present_value, nil, :property_write, 8)
    assert released.object.present_value == {true}

    assert {:error, :out_of_service} =
             write(released, :relinquish_default, {false}, :application_write)

    {:ok, in_service} = write(released, :out_of_service, false, :application_write)
    {:ok, updated} = write(in_service, :present_value, {false}, :application_write)
    assert updated.object.present_value == {false}
  end

  test "an absent Out_Of_Service property is treated as in service" do
    {:ok, object} =
      BitstringValue.create(10, "Flags", %{present_value: {false}, out_of_service: true})

    {:ok, object} = BitstringValue.remove_property(object, :out_of_service)
    {:ok, stored} = Lifecycle.execute(object, context(nil, :initialization))

    assert stored.object.status_flags.out_of_service == false
    {:ok, changed} = write(stored, :present_value, {true}, :application_write)
    assert changed.object.present_value == {true}
  end

  test "priority six is reserved for local commandable objects" do
    stored = initialize(%{present_value: {false}, relinquish_default: {false}})

    for value <- [{true}, nil] do
      assert {:error, :write_access_denied} = BitstringValue.set_priority(stored.object, 6, value)
    end

    ctx = context(stored, {:property_write, 85, nil, 6})

    assert {:error, :write_access_denied} =
             Lifecycle.prepare_write(stored.object, stored.object, ctx)

    {:ok, object} =
      BitstringValue.create(10, "Flags", %{
        present_value: {false},
        relinquish_default: {false},
        priority_array: %PriorityArray{priority_6: {true}}
      })

    assert {:error, {:invalid_configuration, :priority_6}} =
             Lifecycle.execute(object, context(nil, :initialization))
  end

  test "preflight rejects persisted label mismatches and malformed state but preserves remote snapshots" do
    stored = initialize(%{present_value: {true, false}})
    labels = BACnetArray.from_list(["First"])
    stale = %{stored.object | bit_text: labels}

    assert {:error, {:invalid_configuration, :bit_text}} =
             Lifecycle.execute(stale, context(nil, :initialization))

    ctx = context(stored, {:property_write, :bit_text, nil, nil})

    assert {:error, {:invalid_configuration, :bit_text}} =
             Lifecycle.prepare_write(stored.object, stale, ctx)

    assert {:error, :invalid_execution_state} =
             Lifecycle.execute(stored.object, %{ctx | state: %{stored.state | value: {:invalid}}})

    wrong_id = %{stored.state.identifier | instance: 11}

    assert {:error, :invalid_execution_state} =
             Lifecycle.execute(stored.object, %{
               ctx
               | state: %{stored.state | identifier: wrong_id}
             })

    assert {:error, :invalid_execution_state} =
             Lifecycle.execute(stored.object, %{ctx | state: :invalid})

    properties =
      stale
      |> Map.take([:bit_text, :present_value, :out_of_service, :status_flags, :event_state])
      |> Map.merge(%{priority_array: %PriorityArray{}, relinquish_default: {false, false}})

    {:ok, remote} = BitstringValue.create(11, "Remote", properties, remote_object: 42)

    assert {:ok, %{present_value: {false, true}, bit_text: ^labels}} =
             BitstringValue.set_priority(remote, 8, {false, true})

    assert :ok = BitstringValue.validate_execution(remote, ctx)

    assert {:error, :operation_not_available_for_remote_objects} =
             BitstringValue.prepare_write(remote, remote, ctx)

    assert {:ok, %Result{object: ^remote, state: :snapshot, next_execution: nil}} =
             BitstringValue.execute(remote, %{ctx | state: :snapshot})

    assert {:ok, %Result{object: ^remote, state: :snapshot, next_execution: nil}} =
             Lifecycle.execute(remote, %{ctx | state: :snapshot})

    assert {:error, :operation_not_available_for_remote_objects} =
             Lifecycle.prepare_write(remote, remote, ctx)
  end

  test "Reliability reports survive inhibition and simulation remains available" do
    for origin <- [:property_write, :application_write] do
      stored = initialize(%{present_value: {true}, reliability: :process_error})
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

  test "reports the matching bitstring after masking" do
    stored =
      initialize(%{present_value: {false}, bit_mask: {true}, alarm_values: [{true}]},
        intrinsic_reporting: true
      )

    {:ok, changed} = write(stored, :present_value, {true})
    assert changed.object.present_value == {true}

    assert %{
             event_type: :change_of_bitstring,
             to_state: :offnormal,
             event_values: %{referenced_bitstring: {true}}
           } = EventReporting.transition(changed)

    assert changed.next_execution == nil
  end

  defp initialize(properties, options \\ []) do
    {:ok, object} = BitstringValue.create(10, "Flags", properties, options)
    {:ok, stored} = Lifecycle.execute(object, context(nil, :initialization))
    stored
  end

  defp context(stored, trigger) do
    Context.new(trigger, now: @now, monotonic_time: 0, state: if(stored, do: stored.state))
  end

  defp write(stored, property, value, origin \\ :property_write, priority \\ nil) do
    ctx = context(stored, {origin, property, nil, priority})

    candidate =
      if property == :present_value and BitstringValue.has_priority_array?(stored.object),
        do: BitstringValue.set_priority(stored.object, priority || 16, value),
        else: BitstringValue.update_property(stored.object, property, value)

    with {:ok, candidate} <- candidate,
         {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
      BitstringValue.execute(prepared, ctx)
    end
  end
end
