defmodule BACnet.Test.Protocol.ObjectTypes.MultistateInputTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectTypes.MultistateInput

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_multi_state_input

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "verify create/4 enforces number_of_states for present_value" do
    assert {:ok, _obj} =
             MultistateInput.create(1, "TEST", %{number_of_states: 4, present_value: 1})

    assert {:ok, _obj} =
             MultistateInput.create(1, "TEST", %{number_of_states: 4, present_value: 2})

    assert {:ok, _obj} =
             MultistateInput.create(1, "TEST", %{number_of_states: 4, present_value: 3})

    assert {:ok, _obj} =
             MultistateInput.create(1, "TEST", %{number_of_states: 4, present_value: 4})

    assert {:error, {:value_failed_property_validation, :present_value}} =
             MultistateInput.create(1, "TEST", %{number_of_states: 4, present_value: 5})

    assert {:error, {:value_failed_property_validation, :present_value}} =
             MultistateInput.create(1, "TEST", %{number_of_states: 4, present_value: 32_767})
  end

  test "verify create/4 enforces number_of_states for state_text" do
    assert {:ok, _obj} =
             MultistateInput.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list(["1", "2", "3", "4"])
             })

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateInput.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list([])
             })

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateInput.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list(["1"])
             })

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateInput.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list(["1", "2", "3", "4", "5"])
             })
  end

  test "verify update_property/3 enforces number_of_states for present_value" do
    {:ok, obj} = MultistateInput.create(1, "TEST", %{number_of_states: 4})

    assert {:ok, %{present_value: 2}} = MultistateInput.update_property(obj, :present_value, 2)
    assert {:ok, %{present_value: 3}} = MultistateInput.update_property(obj, :present_value, 3)
    assert {:ok, %{present_value: 4}} = MultistateInput.update_property(obj, :present_value, 4)

    assert {:error, {:value_failed_property_validation, :present_value}} =
             MultistateInput.update_property(obj, :present_value, 5)

    assert {:error, {:value_failed_property_validation, :present_value}} =
             MultistateInput.update_property(obj, :present_value, 6)

    assert {:error, {:value_failed_property_validation, :present_value}} =
             MultistateInput.update_property(obj, :present_value, 32_767)
  end

  test "verify update_property/3 enforces number_of_states for state_text" do
    {:ok, obj} =
      MultistateInput.create(1, "TEST", %{
        number_of_states: 4,
        state_text: BACnetArray.from_list(["", "", "", ""])
      })

    arr = BACnetArray.from_list(["1", "2", "3", "4"])

    assert {:ok, %MultistateInput{state_text: ^arr}} =
             MultistateInput.update_property(obj, :state_text, arr)

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateInput.update_property(obj, :state_text, BACnetArray.from_list([]))

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateInput.update_property(obj, :state_text, BACnetArray.from_list(["1"]))

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateInput.update_property(
               obj,
               :state_text,
               BACnetArray.from_list(["1", "2", "3", "4", "5"])
             )
  end

  describe "lifecycle" do
    test "samples never select Interface_Value and validate even when it is absent" do
      stored = initialize(%{present_value: 1})
      refute MultistateInput.has_property?(stored.object, :interface_value)
      {:ok, sampled} = sample(stored, 2)
      assert sampled.object.present_value == 2
      refute MultistateInput.has_property?(sampled.object, :interface_value)

      {:ok, isolated} = write(sampled, :out_of_service, true)
      assert {:ok, ^isolated} = sample(isolated, 3)

      for value <- [0, 5] do
        assert {:error, {:value_failed_property_validation, :interface_value}} =
                 MultistateInput.set_input(isolated.object, value)
      end

      assert {:error, {:invalid_property_type, :interface_value}} =
               MultistateInput.set_input(isolated.object, nil)
    end

    test "physical observations and simulated values stay independent across resumption" do
      stored = initialize(%{present_value: 1, interface_value: :undefined})
      assert MultistateInput.has_property?(stored.object, :interface_value)
      {:ok, sampled} = sample(stored, 2)
      assert sampled.object.present_value == 2
      assert sampled.object.interface_value == 2

      {:ok, isolated} = write(sampled, :out_of_service, true)

      for origin <- [:property_write, :application_write] do
        {:ok, simulated} = write(isolated, :present_value, 4, origin)
        assert simulated.object.interface_value == 2
        {:ok, observed} = sample(simulated, 3)
        assert observed.object.present_value == 4
        assert observed.object.interface_value == 3
        {:ok, resumed} = write(observed, :out_of_service, false)
        assert resumed.object.present_value == 4
        {:ok, fresh} = sample(resumed, 2)
        assert fresh.object.present_value == 2
        assert fresh.object.interface_value == 2
        assert fresh.next_execution == nil
      end
    end

    test "unknown samples clear the physical observation without inferring a fault" do
      for isolated? <- [false, true] do
        stored =
          initialize(%{
            present_value: 3,
            interface_value: 2,
            out_of_service: isolated?,
            reliability: :no_fault_detected
          })

        {:ok, unknown} = sample(stored, :undefined)
        assert unknown.object.interface_value == :undefined
        assert unknown.object.present_value == 3
        assert unknown.object.reliability == :no_fault_detected
        refute unknown.object.status_flags.fault
      end
    end

    test "BACnet value writes require both original and candidate out of service" do
      stored = initialize(%{present_value: 1})
      refute MultistateInput.property_writable?(stored.object, :present_value)
      {:ok, isolated} = write(stored, :out_of_service, true)
      assert MultistateInput.property_writable?(isolated.object, :present_value)

      for property <- [:present_value, 85] do
        ctx = context(stored, {:property_write, property, nil, nil})
        assert {:error, :write_access_denied} = Lifecycle.execute(stored.object, ctx)

        assert {:error, :write_access_denied} =
                 Lifecycle.prepare_write(stored.object, stored.object, ctx)

        assert {:error, :write_access_denied} =
                 Lifecycle.prepare_write(stored.object, isolated.object, ctx)

        ctx = context(isolated, {:property_write, property, nil, nil})

        assert {:error, :write_access_denied} =
                 Lifecycle.prepare_write(isolated.object, stored.object, ctx)
      end
    end

    test "Interface_Value is writable to the driver and read-only to BACnet" do
      stored = initialize(%{interface_value: :undefined})
      assert MultistateInput.get_annotation(:interface_value)[:revision] == 16
      refute MultistateInput.property_writable?(stored.object, :interface_value)
      {:ok, isolated} = write(stored, :out_of_service, true)

      for instance <- [stored, isolated], property <- [:interface_value, 387] do
        {:ok, candidate} = MultistateInput.update_property(instance.object, :interface_value, 2)
        ctx = context(instance, {:property_write, property, nil, nil})

        assert {:error, :write_access_denied} =
                 Lifecycle.prepare_write(instance.object, candidate, ctx)

        assert {:error, :write_access_denied} = Lifecycle.execute(candidate, ctx)
      end

      {:ok, observed} = write(isolated, :interface_value, 2, :application_write)
      assert observed.object.interface_value == 2
      assert observed.object.present_value == isolated.object.present_value
    end

    test "inhibition preserves physical reliability independently of either simulation origin" do
      for origin <- [:property_write, :application_write] do
        stored = initialize(%{reliability: :no_sensor})
        {:ok, inhibited} = write(stored, :reliability_evaluation_inhibit, true)
        {:ok, report} = write(inhibited, :reliability, :communication_failure, :application_write)
        assert report.object.reliability == :no_fault_detected
        {:ok, isolated} = write(report, :out_of_service, true)
        assert isolated.object.reliability == :no_fault_detected
        {:ok, simulated} = write(isolated, :reliability, :process_error, origin)
        assert simulated.object.reliability == :process_error
        assert simulated.object.status_flags.fault
        {:ok, resumed} = write(simulated, :out_of_service, false)
        assert resumed.object.reliability == :no_fault_detected
        refute resumed.object.status_flags.fault
        {:ok, restored} = write(resumed, :reliability_evaluation_inhibit, false)
        assert restored.object.reliability == :communication_failure
        assert restored.object.status_flags.fault
      end
    end

    test "count edits resize selected labels and reject invalidating reductions" do
      for fixed? <- [false, true] do
        stored =
          initialize(%{
            number_of_states: 2,
            state_text: BACnetArray.from_list(["Off", "Low"], fixed?)
          })

        {:ok, grown} = write(stored, :number_of_states, 4, :application_write)
        assert BACnetArray.to_list(grown.object.state_text) == ["Off", "Low", "", ""]
        assert BACnetArray.fixed_size?(grown.object.state_text) == fixed?

        assert {:error, {:value_failed_property_validation, :state_text}} =
                 write(grown, :state_text, BACnetArray.from_list(["Off", "Low"]))

        for property <- [:present_value, :interface_value] do
          invalid = initialize(%{property => 4, state_text: grown.object.state_text})

          assert {:error, {:invalid_configuration, ^property}} =
                   write(invalid, :number_of_states, 2, :application_write)
        end

        {:ok, reduced} = write(grown, :number_of_states, 2, :application_write)
        assert reduced.object.number_of_states == 2
        assert BACnetArray.to_list(reduced.object.state_text) == ["Off", "Low"]
      end
    end

    test "reports a configured state fault before an alarm for the same state" do
      stored = initialize(%{alarm_values: [2], fault_values: [2]}, intrinsic_reporting: true)
      {:ok, sampled} = sample(stored, 2)
      assert sampled.object.present_value == 2
      assert sampled.object.reliability == :multi_state_fault

      assert %{event_type: :change_of_reliability, to_state: :fault} =
               EventReporting.transition(sampled)

      {:ok, recovered} = sample(sampled, 1)
      assert recovered.object.reliability == :no_fault_detected

      assert %{event_type: :change_of_reliability, to_state: :normal} =
               EventReporting.transition(recovered)

      assert recovered.next_execution == nil
    end

    test "clears a configured state fault when the simulated input returns to normal" do
      fault =
        initialize(
          %{out_of_service: true, present_value: 2, fault_values: [2]},
          intrinsic_reporting: true
        )

      assert fault.object.reliability == :multi_state_fault
      assert fault.object.status_flags.fault

      assert {:ok, recovered} = write(fault, :present_value, 1)
      assert recovered.object.reliability == :no_fault_detected
      refute recovered.object.status_flags.fault

      assert %{event_type: :change_of_reliability, from_state: :fault, to_state: :normal} =
               EventReporting.transition(recovered)
    end

    test "a BACnet reliability write persists only while fault evaluation is inhibited" do
      fault =
        initialize(
          %{
            out_of_service: true,
            present_value: 2,
            fault_values: [2],
            reliability_evaluation_inhibit: false
          },
          intrinsic_reporting: true
        )

      assert fault.object.reliability == :multi_state_fault
      assert {:ok, evaluated} = write(fault, :reliability, :no_sensor)
      assert evaluated.object.reliability == :multi_state_fault
      assert EventReporting.transition(evaluated) == nil
      assert %{current_reliability: :multi_state_fault} = evaluated.state.reporting.fault_state

      assert {:ok, inhibited} = write(evaluated, :reliability_evaluation_inhibit, true)
      assert inhibited.state.reporting.fault_state == nil
      assert {:ok, simulated} = write(inhibited, :reliability, :no_sensor)
      assert simulated.object.reliability == :no_sensor
      assert simulated.object.status_flags.fault

      assert {:ok, healthy_input} = write(simulated, :present_value, 1)
      assert healthy_input.object.reliability == :no_sensor

      assert {:ok, resumed} = write(healthy_input, :reliability_evaluation_inhibit, false)
      assert resumed.object.reliability == :no_fault_detected

      assert %{current_reliability: :no_fault_detected, last_value: nil} =
               resumed.state.reporting.fault_state

      refute resumed.object.status_flags.fault

      assert %{event_type: :change_of_reliability, to_state: :normal} =
               EventReporting.transition(resumed)

      assert {:ok, evaluated} = write(resumed, :reliability, :no_sensor)
      assert evaluated.object.reliability == :no_fault_detected
      refute evaluated.object.status_flags.fault
    end

    test "remote snapshots retain NULL observations and reject local sampling" do
      stored = initialize(%{})

      assert {:error, :invalid_execution_state} =
               Lifecycle.execute(stored.object, context(nil, :periodic))

      id = MultistateInput.get_object_identifier(stored.object)
      null = Encoding.create!({:null, nil})
      assert {:ok, :undefined} = ObjectsUtility.cast_property_to_value(id, :interface_value, null)

      assert {:ok, ^null} =
               ObjectsUtility.cast_value_to_property(id, :interface_value, :undefined)

      properties =
        stored.object
        |> Map.take([
          :present_value,
          :number_of_states,
          :out_of_service,
          :event_state,
          :status_flags
        ])
        |> Map.put(:interface_value, :undefined)

      {:ok, remote} = MultistateInput.create(11, "Snapshot", properties, remote_object: 42)
      assert MultistateInput.has_property?(remote, :interface_value)
      ctx = %{context(nil, :periodic) | state: :snapshot}

      assert {:ok, %Result{object: ^remote, state: :snapshot, next_execution: nil}} =
               Lifecycle.execute(remote, ctx)

      assert {:error, :operation_not_available_for_remote_objects} =
               MultistateInput.set_input(remote, 2)

      assert {:error, :operation_not_available_for_remote_objects} =
               MultistateInput.prepare_write(remote, remote, ctx)
    end

    defp initialize(properties, opts \\ []) do
      {:ok, object} =
        MultistateInput.create(10, "Mode", Map.put_new(properties, :number_of_states, 4), opts)

      {:ok, stored} = Lifecycle.execute(object, context(nil, :initialization))
      stored
    end

    defp context(stored, trigger) do
      Context.new(trigger,
        now: ~U[2026-11-09 10:00:00Z],
        monotonic_time: 0,
        state: if(stored, do: stored.state),
        lookup_object: fn
          %{object_identifier: %{type: :notification_class}} -> {:error, :unknown_object}
          _reference -> flunk("unexpected lookup")
        end,
        read_property: fn _reference -> flunk("unexpected read") end,
        write_property: fn _reference, _value, _priority -> flunk("unexpected write") end
      )
    end

    defp sample(stored, value) do
      with {:ok, candidate} <- MultistateInput.set_input(stored.object, value) do
        commit(stored, candidate, {:application_write, :present_value, nil, nil})
      end
    end

    defp write(stored, property, value, origin \\ :property_write) do
      with {:ok, candidate} <- MultistateInput.update_property(stored.object, property, value) do
        commit(stored, candidate, {origin, property, nil, nil})
      end
    end

    defp commit(stored, candidate, trigger) do
      ctx = context(stored, trigger)

      with {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
        MultistateInput.execute(prepared, ctx)
      end
    end
  end
end
