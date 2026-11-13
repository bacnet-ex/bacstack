defmodule BACnet.Test.Protocol.ObjectTypes.MultistateOutputTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectTypes.MultistateOutput
  alias BACnet.Protocol.PriorityArray

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_multi_state_output

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "create/4 priority array overrides given present value" do
    assert {:ok, %MultistateOutput{present_value: 1}} =
             MultistateOutput.create(1, "TEST", %{number_of_states: 4, present_value: 3})
  end

  test "get_output follows present value until the output is out of service" do
    {:ok, object} = MultistateOutput.create(1, "output", %{number_of_states: 4})
    {:ok, object} = MultistateOutput.set_priority(object, 8, 3)

    assert MultistateOutput.get_output(object) == 3
    assert MultistateOutput.get_output(object, 2) == 3

    {:ok, object} = MultistateOutput.update_property(object, :out_of_service, true)
    assert MultistateOutput.get_output(object) == 1
    assert MultistateOutput.get_output(object, 2) == 2
  end

  test "verify create/4 enforces number_of_states for relinquish_default" do
    assert {:ok, %{present_value: 1} = _obj} =
             MultistateOutput.create(1, "TEST", %{number_of_states: 4, relinquish_default: 1})

    assert {:ok, %{present_value: 2} = _obj} =
             MultistateOutput.create(1, "TEST", %{number_of_states: 4, relinquish_default: 2})

    assert {:ok, %{present_value: 3} = _obj} =
             MultistateOutput.create(1, "TEST", %{number_of_states: 4, relinquish_default: 3})

    assert {:ok, %{present_value: 4} = _obj} =
             MultistateOutput.create(1, "TEST", %{number_of_states: 4, relinquish_default: 4})

    assert {:error, {:value_failed_property_validation, _key}} =
             MultistateOutput.create(1, "TEST", %{number_of_states: 4, relinquish_default: 5})

    assert {:error, {:value_failed_property_validation, _key}} =
             MultistateOutput.create(1, "TEST", %{number_of_states: 4, relinquish_default: 32_767})
  end

  test "verify create/4 given present_value gets re-calculated" do
    assert {:ok, %{present_value: 1} = _obj} =
             MultistateOutput.create(1, "TEST", %{number_of_states: 4, present_value: 1})

    assert {:ok, %{present_value: 1} = _obj} =
             MultistateOutput.create(1, "TEST", %{number_of_states: 4, present_value: 2})

    assert {:ok, %{present_value: 1} = _obj} =
             MultistateOutput.create(1, "TEST", %{number_of_states: 4, present_value: 3})

    assert {:ok, %{present_value: 1} = _obj} =
             MultistateOutput.create(1, "TEST", %{number_of_states: 4, present_value: 4})
  end

  test "verify create/4 enforces number_of_states for state_text" do
    assert {:ok, _obj} =
             MultistateOutput.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list(["1", "2", "3", "4"])
             })

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateOutput.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list([])
             })

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateOutput.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list(["1"])
             })

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateOutput.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list(["1", "2", "3", "4", "5"])
             })
  end

  test "verify update_property/3 enforces number_of_states for state_text" do
    {:ok, obj} =
      MultistateOutput.create(1, "TEST", %{
        number_of_states: 4,
        state_text: BACnetArray.from_list(["", "", "", ""])
      })

    arr = BACnetArray.from_list(["1", "2", "3", "4"])

    assert {:ok, %MultistateOutput{state_text: ^arr}} =
             MultistateOutput.update_property(obj, :state_text, arr)

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateOutput.update_property(obj, :state_text, BACnetArray.from_list([]))

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateOutput.update_property(obj, :state_text, BACnetArray.from_list(["1"]))

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateOutput.update_property(
               obj,
               :state_text,
               BACnetArray.from_list(["1", "2", "3", "4", "5"])
             )
  end

  test "verify update_property/3 enforces number_of_states for relinquish_default" do
    {:ok, obj} = MultistateOutput.create(1, "TEST", %{number_of_states: 4, relinquish_default: 1})

    assert {:ok, %{relinquish_default: 2}} =
             MultistateOutput.update_property(obj, :relinquish_default, 2)

    assert {:ok, %{relinquish_default: 3}} =
             MultistateOutput.update_property(obj, :relinquish_default, 3)

    assert {:ok, %{relinquish_default: 4}} =
             MultistateOutput.update_property(obj, :relinquish_default, 4)

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             MultistateOutput.update_property(obj, :relinquish_default, 5)

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             MultistateOutput.update_property(obj, :relinquish_default, 6)

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             MultistateOutput.update_property(obj, :relinquish_default, 32_767)
  end

  test "verify update_property/3 enforces number_of_states for priority_array" do
    {:ok, obj} = MultistateOutput.create(1, "TEST", %{number_of_states: 4, relinquish_default: 1})

    assert {:ok, %{priority_array: %{priority_16: 2}}} =
             MultistateOutput.update_property(obj, :priority_array, %PriorityArray{priority_16: 2})

    assert {:ok, _obj} =
             MultistateOutput.update_property(obj, :priority_array, %PriorityArray{priority_16: 3})

    assert {:ok, _obj} =
             MultistateOutput.update_property(obj, :priority_array, %PriorityArray{priority_16: 4})

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateOutput.update_property(obj, :priority_array, %PriorityArray{priority_16: 5})

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateOutput.update_property(obj, :priority_array, %PriorityArray{priority_16: 6})

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateOutput.update_property(obj, :priority_array, %PriorityArray{
               priority_16: 32_767
             })
  end

  test "verify get_property/2 with present_value respects command prioritization on out of service" do
    {:ok, %MultistateOutput{present_value: 1} = obj} =
      MultistateOutput.create(1, "TEST", %{number_of_states: 4, relinquish_default: 1})

    assert {:ok, 1} = MultistateOutput.get_property(obj, :present_value)

    {:ok, obj} = MultistateOutput.update_property(obj, :out_of_service, true)

    assert {:ok, 1} = MultistateOutput.get_property(obj, :present_value)
    assert {:ok, %{present_value: 3} = obj} = MultistateOutput.set_priority(obj, 16, 3)
    assert {:ok, %{present_value: 2} = obj} = MultistateOutput.set_priority(obj, 1, 2)

    assert {:ok, %{present_value: 2}} =
             MultistateOutput.update_property(obj, :out_of_service, false)
  end

  test "verify set_priority/3 enforces number_of_states" do
    {:ok, obj} = MultistateOutput.create(1, "TEST", %{number_of_states: 4, relinquish_default: 1})

    assert {:ok, %{priority_array: %{priority_16: 2}}} = MultistateOutput.set_priority(obj, 16, 2)
    assert {:ok, _obj} = MultistateOutput.set_priority(obj, 16, 3)
    assert {:ok, _obj} = MultistateOutput.set_priority(obj, 16, 4)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateOutput.set_priority(obj, 16, 5)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateOutput.set_priority(obj, 16, 6)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateOutput.set_priority(obj, 16, 32_767)
  end

  describe "lifecycle" do
    test "commands and relinquishments from both origins arbitrate while the driver is isolated" do
      stored = initialize(%{out_of_service: true, relinquish_default: 2})
      {:ok, low} = write(stored, :present_value, 4, :application_write)
      {:ok, high} = write(low, :present_value, 3, :property_write, 8)
      assert high.object.present_value == 3
      assert MultistateOutput.get_output(high.object, 2) == 2
      {:ok, revealed} = write(high, :present_value, nil, :property_write, 8)
      assert revealed.object.present_value == 4
      {:ok, fallback} = write(revealed, :present_value, nil, :application_write)
      assert fallback.object.present_value == 2
      {:ok, returned} = write(revealed, :out_of_service, false)
      assert MultistateOutput.get_output(returned.object) == 4
      assert returned.next_execution == nil
    end

    test "reserved priority six is rejected by property and lifecycle operations" do
      stored = initialize(%{})

      for value <- [nil, 2] do
        assert {:error, :write_access_denied} =
                 MultistateOutput.set_priority(stored.object, 6, value)
      end

      for property <- [:present_value, 85], source <- [:property_write, :application_write] do
        ctx = context(stored, {source, property, nil, 6})

        assert {:error, :write_access_denied} =
                 Lifecycle.prepare_write(stored.object, stored.object, ctx)

        assert {:error, :write_access_denied} = Lifecycle.execute(stored.object, ctx)
      end

      {:ok, invalid} =
        MultistateOutput.create(10, "Reserved slot", %{
          number_of_states: 4,
          priority_array: %PriorityArray{priority_6: 2}
        })

      assert {:error, {:invalid_configuration, :priority_6}} =
               Lifecycle.execute(invalid, context(nil, :initialization))
    end

    test "physical reliability is retained separately from inhibited simulation" do
      for source <- [:property_write, :application_write] do
        stored = initialize(%{reliability: :no_sensor})
        {:ok, inhibited} = write(stored, :reliability_evaluation_inhibit, true)

        {:ok, reported} =
          write(inhibited, :reliability, :communication_failure, :application_write)

        assert reported.object.reliability == :no_fault_detected
        refute reported.object.status_flags.fault
        {:ok, isolated} = write(reported, :out_of_service, true)
        assert isolated.object.reliability == :no_fault_detected

        {:ok, candidate} =
          MultistateOutput.update_property(isolated.object, :reliability, :process_error)

        ctx = context(isolated, {source, 103, nil, nil})
        {:ok, prepared} = Lifecycle.prepare_write(isolated.object, candidate, ctx)
        {:ok, simulated} = MultistateOutput.execute(prepared, ctx)
        assert simulated.object.reliability == :process_error
        assert simulated.object.status_flags.fault
        {:ok, returned} = write(simulated, :out_of_service, false)
        assert returned.object.reliability == :no_fault_detected
        {:ok, restored} = write(returned, :reliability_evaluation_inhibit, false)
        assert restored.object.reliability == :communication_failure
        assert restored.object.status_flags.fault
      end
    end

    test "actual feedback stays independent of commands and application feedback is isolated" do
      stored = initialize(%{feedback_value: 1})
      {:ok, commanded} = write(stored, :present_value, 3)
      assert commanded.object.feedback_value == 1
      {:ok, reported} = write(commanded, :feedback_value, 2, :application_write)
      assert reported.object.present_value == 3
      assert reported.object.feedback_value == 2
      {:ok, isolated} = write(reported, :out_of_service, true)
      assert {:error, :out_of_service} = write(isolated, :feedback_value, 2, :application_write)
      {:ok, simulated} = write(isolated, :feedback_value, 4)
      assert simulated.object.feedback_value == 4
      assert simulated.object.present_value == 3
    end

    test "reports a command failure only when feedback differs" do
      for opts <- [
            [auto_write_feedback: true],
            [auto_write_feedback: true, intrinsic_reporting: true]
          ] do
        stored = initialize(%{out_of_service: true}, opts)
        assert MultistateOutput.has_property?(stored.object, :feedback_value)
        {:ok, commanded} = write(stored, :present_value, 4)
        assert commanded.object.feedback_value == 4
        assert commanded.object.event_state == stored.object.event_state
        assert commanded.next_execution == nil
        assert {:error, :feedback_managed_automatically} = write(commanded, :feedback_value, 2)
        {:ok, relinquished} = write(commanded, :present_value, nil)
        assert relinquished.object.feedback_value == 1
      end

      stored = initialize(%{}, intrinsic_reporting: true)
      assert MultistateOutput.has_property?(stored.object, :feedback_value)
      {:ok, commanded} = write(stored, :present_value, 3)
      assert commanded.object.feedback_value == 1

      assert %{
               event_type: :command_failure,
               to_state: :offnormal,
               event_values: %{
                 command_value: %{type: :unsigned_integer, value: 3},
                 feedback_value: %{type: :unsigned_integer, value: 1}
               }
             } = EventReporting.transition(commanded)
    end

    test "Interface_Value can track physical state independently during simulation" do
      plain = initialize(%{})
      refute MultistateOutput.has_property?(plain.object, :interface_value)
      stored = initialize(%{interface_value: :undefined, feedback_value: 1})
      assert MultistateOutput.get_annotation(:interface_value)[:revision] == 16
      refute MultistateOutput.property_writable?(stored.object, :interface_value)
      {:ok, isolated} = write(stored, :out_of_service, true)
      {:ok, commanded} = write(isolated, :present_value, 4)
      {:ok, observed} = write(commanded, :interface_value, 2, :application_write)
      assert observed.object.present_value == 4
      assert observed.object.interface_value == 2
      assert observed.object.feedback_value == 1

      for value <- [0, 5] do
        assert {:error, {:value_failed_property_validation, :interface_value}} =
                 write(observed, :interface_value, value, :application_write)
      end

      for property <- [:interface_value, 387], source <- [stored, observed] do
        ctx = context(source, {:property_write, property, nil, nil})

        assert {:error, :write_access_denied} =
                 Lifecycle.prepare_write(source.object, source.object, ctx)

        assert {:error, :write_access_denied} = Lifecycle.execute(source.object, ctx)
      end
    end

    test "Interface_Value casts unsigned observations and preserves unknown as NULL" do
      id = MultistateOutput.get_object_identifier(initialize(%{}).object)

      for {value, tags} <- [{2, {:unsigned_integer, 2}}, {:undefined, {:null, nil}}] do
        encoded = Encoding.create!(tags)

        assert {:ok, ^encoded} =
                 ObjectsUtility.cast_value_to_property(id, :interface_value, value)

        assert {:ok, ^value} =
                 ObjectsUtility.cast_property_to_value(id, :interface_value, encoded)
      end

      for tags <- [{:unsigned_integer, 0}, {:signed_integer, 2}] do
        encoded = Encoding.create!(tags)

        assert {:error, {:invalid_property_value, {:interface_value, ^encoded}}} =
                 ObjectsUtility.cast_property_to_value(id, :interface_value, encoded)
      end

      for invalid <- [0, :unknown] do
        assert {:error, {:invalid_property_value, {:interface_value, ^invalid}}} =
                 ObjectsUtility.cast_value_to_property(id, :interface_value, invalid)
      end
    end

    test "count changes resize labels while label updates cannot resize the state set" do
      for fixed <- [false, true] do
        stored =
          initialize(%{
            number_of_states: 2,
            state_text: BACnetArray.from_list(["Off", "On"], fixed)
          })

        {:ok, grown} = write(stored, :number_of_states, 4, :application_write)
        assert BACnetArray.to_list(grown.object.state_text) == ["Off", "On", "", ""]
        assert BACnetArray.fixed_size?(grown.object.state_text) == fixed

        assert {:error, {:value_failed_property_validation, :state_text}} =
                 write(grown, :state_text, BACnetArray.from_list(["Off", "On"]))

        {:ok, reduced} = write(grown, :number_of_states, 2, :application_write)
        assert BACnetArray.to_list(reduced.object.state_text) == ["Off", "On"]
        assert reduced.object.number_of_states == 2
      end
    end

    test "count reductions preserve masked commands, default and observed state" do
      for {props, property} <- [
            {%{priority_array: %PriorityArray{priority_8: 1, priority_16: 4}}, :priority_array},
            {%{priority_array: %PriorityArray{priority_8: 1}, relinquish_default: 4},
             :relinquish_default},
            {%{interface_value: 4}, :interface_value}
          ] do
        stored = initialize(props)

        assert {:error, {:invalid_configuration, ^property}} =
                 write(stored, :number_of_states, 2, :application_write)

        assert stored.object.number_of_states == 4
      end
    end

    test "local runtime state is required and remote snapshots are passive" do
      stored = initialize(%{})

      assert {:error, :invalid_execution_state} =
               Lifecycle.execute(stored.object, context(nil, :periodic))

      assert {:error, :invalid_execution_state} =
               Lifecycle.execute(stored.object, %{
                 context(stored, :periodic)
                 | state: %{stored.state | identifier: nil}
               })

      {:ok, another} = MultistateOutput.create(11, "Another", %{number_of_states: 4})

      assert {:error, :invalid_execution_state} =
               Lifecycle.execute(another, context(stored, :periodic))

      properties =
        Map.take(stored.object, [
          :present_value,
          :priority_array,
          :relinquish_default,
          :number_of_states,
          :out_of_service,
          :event_state,
          :status_flags
        ])

      {:ok, remote} = MultistateOutput.create(11, "Remote", properties, remote_object: 42)
      ctx = %{context(nil, :periodic) | state: :snapshot}

      assert {:ok, %Result{object: ^remote, state: :snapshot, next_execution: nil}} =
               Lifecycle.execute(remote, ctx)

      assert {:error, :operation_not_available_for_remote_objects} =
               MultistateOutput.prepare_write(remote, remote, ctx)

      assert :ok = MultistateOutput.validate_execution(remote, ctx)

      assert {:ok, %Result{object: ^remote, state: :snapshot, next_execution: nil}} =
               MultistateOutput.execute(remote, ctx)
    end

    test "sparse state text is rejected when an index is missing" do
      stored = initialize(%{number_of_states: 4})
      sparse = %{stored.object | state_text: BACnetArray.from_list(["1", :undefined, "3", "4"])}

      assert {:error, {:invalid_configuration, :state_text}} =
               Lifecycle.execute(sparse, context(stored, :periodic))
    end

    test "out-of-service initialization has no physical sample and later edits keep manual reliability" do
      stored =
        initialize(%{
          out_of_service: true,
          reliability: :process_error,
          description: "Fan"
        })

      assert stored.object.out_of_service
      assert stored.object.reliability == :process_error
      assert stored.state.physical_reliability == nil
      assert stored.state.manual_reliability == :process_error

      {:ok, renamed} = write(stored, :description, "Supply fan")
      assert renamed.object.description == "Supply fan"
      assert renamed.object.reliability == :process_error
      assert renamed.state.manual_reliability == :process_error

      {:ok, inhibited} = write(renamed, :reliability_evaluation_inhibit, true)
      assert inhibited.object.reliability == :process_error
      assert inhibited.object.status_flags.fault
      assert inhibited.state.manual_reliability == :process_error
    end

    defp initialize(properties, opts \\ []) do
      {:ok, object} =
        MultistateOutput.create(10, "Fan", Map.put_new(properties, :number_of_states, 4), opts)

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
        read_property: fn _ref -> flunk("unexpected read") end,
        write_property: fn _ref, _value, _priority -> flunk("unexpected write") end
      )
    end

    defp write(stored, property, value, source \\ :property_write, priority \\ nil) do
      ctx = context(stored, {source, property, nil, priority})

      candidate =
        if property == :present_value,
          do: MultistateOutput.set_priority(stored.object, priority || 16, value),
          else: MultistateOutput.update_property(stored.object, property, value)

      with {:ok, candidate} <- candidate,
           {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
        MultistateOutput.execute(prepared, ctx)
      end
    end
  end
end
