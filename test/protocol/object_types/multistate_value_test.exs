defmodule BACnet.Test.Protocol.ObjectTypes.MultistateValueTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectsProtocol
  alias BACnet.Protocol.ObjectTypes.MultistateValue
  alias BACnet.Protocol.PriorityArray
  alias BACnet.Test.Support.Protocol.ObjectExecutionTestHost, as: Host

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_multi_state_value

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "verify create/4 enforces number_of_states for relinquish_default" do
    assert {:ok, %{present_value: 1} = _obj} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, relinquish_default: 1})

    assert {:ok, %{present_value: 2} = _obj} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, relinquish_default: 2})

    assert {:ok, %{present_value: 3} = _obj} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, relinquish_default: 3})

    assert {:ok, %{present_value: 4} = _obj} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, relinquish_default: 4})

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, relinquish_default: 5})

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, relinquish_default: 32_767})
  end

  test "verify create/4 enforces number_of_states for present_value" do
    assert {:ok, %{present_value: 1} = _obj} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, present_value: 1})

    assert {:ok, %{present_value: 2} = _obj} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, present_value: 2})

    assert {:ok, %{present_value: 3} = _obj} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, present_value: 3})

    assert {:ok, %{present_value: 4} = _obj} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, present_value: 4})

    assert {:error, {:value_failed_property_validation, :present_value}} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, present_value: 5})

    assert {:error, {:value_failed_property_validation, :present_value}} =
             MultistateValue.create(1, "TEST", %{number_of_states: 4, present_value: 32_767})
  end

  test "verify create/4 given present_value gets re-calculated for commandable objects" do
    assert {:ok, %{present_value: 1} = _obj} =
             MultistateValue.create(1, "TEST", %{
               number_of_states: 4,
               relinquish_default: 1,
               present_value: 1
             })

    assert {:ok, %{present_value: 1} = _obj} =
             MultistateValue.create(1, "TEST", %{
               number_of_states: 4,
               relinquish_default: 1,
               present_value: 2
             })

    assert {:ok, %{present_value: 1} = _obj} =
             MultistateValue.create(1, "TEST", %{
               number_of_states: 4,
               relinquish_default: 1,
               present_value: 3
             })

    assert {:ok, %{present_value: 1} = _obj} =
             MultistateValue.create(1, "TEST", %{
               number_of_states: 4,
               relinquish_default: 1,
               present_value: 4
             })

    assert {:ok, %{present_value: 1} = _obj} =
             MultistateValue.create(1, "TEST", %{
               number_of_states: 4,
               relinquish_default: 1,
               present_value: 5
             })

    assert {:ok, %{present_value: 1} = _obj} =
             MultistateValue.create(1, "TEST", %{
               number_of_states: 4,
               relinquish_default: 1,
               present_value: 32_767
             })
  end

  test "verify create/4 enforces number_of_states for state_text" do
    assert {:ok, _obj} =
             MultistateValue.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list(["1", "2", "3", "4"])
             })

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateValue.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list([])
             })

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateValue.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list(["1"])
             })

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateValue.create(1, "TEST", %{
               number_of_states: 4,
               state_text: BACnetArray.from_list(["1", "2", "3", "4", "5"])
             })
  end

  test "create/4 priority array overrides given present value" do
    assert {:ok, %MultistateValue{present_value: 4}} =
             MultistateValue.create(1, "TEST", %{
               number_of_states: 4,
               present_value: 3,
               relinquish_default: 4
             })
  end

  test "add_property/3 priority array overrides given present value" do
    {:ok, %MultistateValue{present_value: 3} = obj} =
      MultistateValue.create(1, "TEST", %{number_of_states: 4, present_value: 3})

    assert {:ok, %MultistateValue{present_value: 2}} =
             MultistateValue.add_property(obj, :relinquish_default, 2)
  end

  test "verify update_property/3 enforces number_of_states for present_value" do
    {:ok, obj} = MultistateValue.create(1, "TEST", %{number_of_states: 4})

    assert {:ok, %{present_value: 2}} = MultistateValue.update_property(obj, :present_value, 2)
    assert {:ok, %{present_value: 3}} = MultistateValue.update_property(obj, :present_value, 3)
    assert {:ok, %{present_value: 4}} = MultistateValue.update_property(obj, :present_value, 4)

    assert {:error, {:value_failed_property_validation, :present_value}} =
             MultistateValue.update_property(obj, :present_value, 5)

    assert {:error, {:value_failed_property_validation, :present_value}} =
             MultistateValue.update_property(obj, :present_value, 6)

    assert {:error, {:value_failed_property_validation, :present_value}} =
             MultistateValue.update_property(obj, :present_value, 32_767)
  end

  test "verify update_property/3 enforces number_of_states for state_text" do
    {:ok, obj} =
      MultistateValue.create(1, "TEST", %{
        number_of_states: 4,
        state_text: BACnetArray.from_list(["", "", "", ""])
      })

    arr = BACnetArray.from_list(["1", "2", "3", "4"])

    assert {:ok, %MultistateValue{state_text: ^arr}} =
             MultistateValue.update_property(obj, :state_text, arr)

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateValue.update_property(obj, :state_text, BACnetArray.from_list([]))

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateValue.update_property(obj, :state_text, BACnetArray.from_list(["1"]))

    assert {:error, {:value_failed_property_validation, :state_text}} =
             MultistateValue.update_property(
               obj,
               :state_text,
               BACnetArray.from_list(["1", "2", "3", "4", "5"])
             )
  end

  test "verify update_property/3 enforces number_of_states for relinquish_default" do
    {:ok, obj} = MultistateValue.create(1, "TEST", %{number_of_states: 4, relinquish_default: 1})

    assert {:ok, %{relinquish_default: 2}} =
             MultistateValue.update_property(obj, :relinquish_default, 2)

    assert {:ok, %{relinquish_default: 3}} =
             MultistateValue.update_property(obj, :relinquish_default, 3)

    assert {:ok, %{relinquish_default: 4}} =
             MultistateValue.update_property(obj, :relinquish_default, 4)

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             MultistateValue.update_property(obj, :relinquish_default, 5)

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             MultistateValue.update_property(obj, :relinquish_default, 6)

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             MultistateValue.update_property(obj, :relinquish_default, 32_767)
  end

  test "verify update_property/3 enforces number_of_states for priority_array" do
    {:ok, obj} = MultistateValue.create(1, "TEST", %{number_of_states: 4, relinquish_default: 1})

    assert {:ok, %{priority_array: %{priority_16: 2}}} =
             MultistateValue.update_property(obj, :priority_array, %PriorityArray{priority_16: 2})

    assert {:ok, _obj} =
             MultistateValue.update_property(obj, :priority_array, %PriorityArray{priority_16: 3})

    assert {:ok, _obj} =
             MultistateValue.update_property(obj, :priority_array, %PriorityArray{priority_16: 4})

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateValue.update_property(obj, :priority_array, %PriorityArray{priority_16: 5})

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateValue.update_property(obj, :priority_array, %PriorityArray{priority_16: 6})

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateValue.update_property(obj, :priority_array, %PriorityArray{
               priority_16: 32_767
             })
  end

  test "verify set_priority/3 enforces number_of_states" do
    {:ok, obj} = MultistateValue.create(1, "TEST", %{number_of_states: 4, relinquish_default: 1})

    assert {:ok, %{priority_array: %{priority_16: 2}}} = MultistateValue.set_priority(obj, 16, 2)
    assert {:ok, _obj} = MultistateValue.set_priority(obj, 16, 3)
    assert {:ok, _obj} = MultistateValue.set_priority(obj, 16, 4)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateValue.set_priority(obj, 16, 5)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateValue.set_priority(obj, 16, 6)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             MultistateValue.set_priority(obj, 16, 32_767)
  end

  describe "lifecycle" do
    @now ~U[2026-11-08 10:00:00Z]

    test "initialization and reads preserve the application state without I/O or wakeups" do
      stored = initialize(%{present_value: 3})
      assert stored.object.present_value == 3
      assert stored.next_execution == nil
      assert MultistateValue.property_writable?(stored.object, :present_value)
      refute MultistateValue.has_priority_array?(stored.object)

      assert {:ok, ^stored} =
               Lifecycle.prepare_read(
                 stored.object,
                 context(stored, {:property_read, :present_value, nil})
               )

      assert {:ok, changed} = write(stored, :present_value, 4, :application_write)
      assert changed.object.present_value == 4
      assert {:ok, changed} = write(changed, :present_value, 2)
      assert {:ok, 2} = MultistateValue.get_property(changed.object, :present_value)
    end

    test "OOS blocks local direct updates including same-value writes and numeric identifiers" do
      stored = initialize(%{present_value: 3, out_of_service: true})

      for property <- [:present_value, 85], value <- [3, 4] do
        {:ok, candidate} = MultistateValue.update_property(stored.object, :present_value, value)
        ctx = context(stored, {:application_write, property, nil, nil})
        assert {:error, :out_of_service} = Lifecycle.prepare_write(stored.object, candidate, ctx)
        assert {:error, :out_of_service} = Lifecycle.execute(candidate, ctx)
      end

      {:ok, simulated} = write(stored, :present_value, 4)
      assert simulated.object.present_value == 4
      assert simulated.object.status_flags.out_of_service
      {:ok, returned} = write(simulated, :out_of_service, false)
      {:ok, resumed} = write(returned, :present_value, 2, :application_write)
      assert resumed.object.present_value == 2
      assert stored.object.present_value == 3
    end

    test "preparation checks original and candidate OOS states for indirect local changes" do
      stored = initialize(%{present_value: 3})
      {:ok, candidate} = MultistateValue.update_property(stored.object, :out_of_service, true)
      {:ok, candidate} = MultistateValue.update_property(candidate, :present_value, 4)

      assert {:error, :out_of_service} =
               Lifecycle.prepare_write(
                 stored.object,
                 candidate,
                 context(stored, {:application_write, :out_of_service, nil, nil})
               )

      {:ok, isolated} = write(stored, :out_of_service, true)
      {:ok, candidate} = MultistateValue.update_property(isolated.object, :out_of_service, false)
      {:ok, candidate} = MultistateValue.update_property(candidate, :present_value, 4)

      assert {:error, :out_of_service} =
               Lifecycle.prepare_write(
                 isolated.object,
                 candidate,
                 context(isolated, {:application_write, :out_of_service, nil, nil})
               )
    end

    test "commands arbitrate, retain masked values, relinquish and use the default" do
      stored = initialize(%{relinquish_default: 1})
      {:ok, low} = write(stored, :present_value, 2)
      {:ok, high} = write(low, :present_value, 3, :property_write, 8)
      {:ok, masked} = write(high, :present_value, 4, :application_write, 16)
      assert masked.object.present_value == 3
      assert masked.object.priority_array.priority_16 == 4
      assert MultistateValue.get_priority_value(masked.object) == {8, 3}
      {:ok, revealed} = write(masked, :present_value, nil, :property_write, 8)
      assert revealed.object.present_value == 4
      {:ok, fallback} = write(revealed, :present_value, nil)
      assert fallback.object.present_value == 1
      {:ok, edited} = write(fallback, :relinquish_default, 2)
      assert edited.object.present_value == 2
      assert edited.next_execution == nil

      assert {:error, {:protected_property, :present_value}} =
               MultistateValue.update_property(edited.object, :present_value, 3)
    end

    test "all priorities except six work and priority six cannot be written or relinquished" do
      stored = initialize(%{number_of_states: 16, relinquish_default: 1})

      for priority <- [1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16] do
        {:ok, commanded} = write(stored, :present_value, priority, :property_write, priority)
        assert commanded.object.present_value == priority
      end

      for value <- [nil, 2] do
        assert {:error, :write_access_denied} =
                 MultistateValue.set_priority(stored.object, 6, value)
      end

      for property <- [:present_value, 85], source <- [:property_write, :application_write] do
        ctx = context(stored, {source, property, nil, 6})

        assert {:error, :write_access_denied} =
                 Lifecycle.prepare_write(stored.object, stored.object, ctx)

        assert {:error, :write_access_denied} = Lifecycle.execute(stored.object, ctx)
      end

      assert {:ok, _result} = write(initialize(%{}), :present_value, 2, :property_write, 6)
    end

    test "stored priority six fails preflight before execution" do
      {:ok, object} =
        MultistateValue.create(10, "Reservation", %{
          number_of_states: 4,
          priority_array: %PriorityArray{priority_6: 2}
        })

      ctx = context(nil, :initialization)

      assert {:error, {:invalid_configuration, :priority_6}} =
               MultistateValue.validate_execution(object, ctx)

      assert {:error, {:invalid_configuration, :priority_6}} = Lifecycle.execute(object, ctx)
    end

    test "OOS simulation retains arbitration while rejecting masked and same-value local commands" do
      stored = initialize(%{relinquish_default: 1, out_of_service: true})
      {:ok, high} = write(stored, :present_value, 3, :property_write, 8)

      for value <- [nil, 3, 4], property <- [:present_value, 85] do
        {:ok, candidate} = MultistateValue.set_priority(high.object, 16, value)
        ctx = context(high, {:application_write, property, nil, 16})
        assert {:error, :out_of_service} = Lifecycle.prepare_write(high.object, candidate, ctx)
        assert {:error, :out_of_service} = Lifecycle.execute(candidate, ctx)
      end

      {:ok, low} = write(high, :present_value, 4)
      assert low.object.present_value == 3
      {:ok, configured} = write(low, :relinquish_default, 2, :application_write)
      assert configured.object.present_value == 3
      {:ok, revealed} = write(configured, :present_value, nil, :property_write, 8)
      assert revealed.object.present_value == 4
      {:ok, fallback} = write(revealed, :present_value, nil)
      assert fallback.object.present_value == 2

      assert {:error, :out_of_service} =
               write(fallback, :relinquish_default, 1, :application_write)
    end

    test "commandability can be added and removed without inventing a priority array" do
      stored = initialize(%{present_value: 3})
      {:ok, candidate} = MultistateValue.add_property(stored.object, :relinquish_default, 2)

      {:ok, commanded} =
        commit(stored, candidate, {:application_write, :relinquish_default, nil, nil})

      assert commanded.object.present_value == 2
      assert MultistateValue.has_priority_array?(commanded.object)
      {:ok, candidate} = MultistateValue.remove_property(commanded.object, :priority_array)

      {:ok, direct} =
        commit(commanded, candidate, {:application_write, :priority_array, nil, nil})

      refute MultistateValue.has_priority_array?(direct.object)
      {:ok, changed} = write(direct, :present_value, 4, :application_write)
      assert changed.object.present_value == 4
    end

    test "invalid states fail without changing stored values or diagnosing a source fault" do
      for capabilities <- [%{}, %{relinquish_default: 1}] do
        stored = initialize(capabilities)

        for value <- [0, -1, 1.0, nil, 5] do
          if not (value == nil and MultistateValue.has_priority_array?(stored.object)) do
            assert {:error, _reason} = write(stored, :present_value, value)
          end
        end

        assert stored.object.present_value == 1
        assert stored.object.reliability == nil
        refute stored.object.status_flags.fault
      end
    end

    test "state-count growth and reduction synchronize labels while preserving valid values" do
      for fixed <- [false, true] do
        stored =
          initialize(%{
            number_of_states: 2,
            present_value: 2,
            state_text: BACnetArray.from_list(["Off", "On"], fixed)
          })

        {:ok, grown} = write(stored, :number_of_states, 4, :application_write)
        assert BACnetArray.size(grown.object.state_text) == 4
        assert BACnetArray.to_list(grown.object.state_text) == ["Off", "On", "", ""]
        assert BACnetArray.fixed_size?(grown.object.state_text) == fixed
        assert grown.object.present_value == 2
        {:ok, reduced} = write(grown, :number_of_states, 2, :application_write)
        assert BACnetArray.to_list(reduced.object.state_text) == ["Off", "On"]
        assert BACnetArray.size(stored.object.state_text) == 2
      end

      stored = initialize(%{number_of_states: 2})
      {:ok, grown} = write(stored, :number_of_states, 3, :application_write)
      refute MultistateValue.has_property?(grown.object, :state_text)
    end

    test "State_Text replacements never change Number_Of_States" do
      stored =
        initialize(%{number_of_states: 2, state_text: BACnetArray.from_list(["Off", "On"])})

      for labels <- [[], ["Only"], ["Off", "Low", "High"]] do
        assert {:error, {:value_failed_property_validation, :state_text}} =
                 write(stored, :state_text, BACnetArray.from_list(labels))

        assert stored.object.number_of_states == 2
        assert BACnetArray.to_list(stored.object.state_text) == ["Off", "On"]
      end

      {:ok, renamed} = write(stored, :state_text, BACnetArray.from_list(["Stopped", "Running"]))
      assert renamed.object.number_of_states == 2
      assert BACnetArray.to_list(renamed.object.state_text) == ["Stopped", "Running"]
    end

    test "count reductions reject invalid current values, masked priorities and masked defaults" do
      cases = [
        {%{present_value: 4}, :present_value},
        {%{priority_array: %PriorityArray{priority_8: 1, priority_16: 4}, relinquish_default: 1},
         :priority_array},
        {%{priority_array: %PriorityArray{priority_8: 1}, relinquish_default: 4},
         :relinquish_default}
      ]

      for {properties, property} <- cases do
        stored =
          initialize(
            Map.put(properties, :state_text, BACnetArray.from_list(["1", "2", "3", "4"]))
          )

        assert {:error, {:invalid_configuration, ^property}} =
                 write(stored, :number_of_states, 2, :application_write)

        assert {:error, {:value_failed_property_validation, :state_text}} =
                 write(stored, :state_text, BACnetArray.from_list(["1", "2"]))

        assert stored.object.number_of_states == 4
        assert BACnetArray.size(stored.object.state_text) == 4
      end
    end

    test "a caller can reconcile values before reducing the count without silent clamping" do
      stored =
        initialize(%{
          relinquish_default: 4,
          priority_array: %PriorityArray{priority_8: 3, priority_16: 4}
        })

      {:ok, stored} = write(stored, :present_value, nil)
      {:ok, stored} = write(stored, :relinquish_default, 1, :application_write)
      {:ok, stored} = write(stored, :present_value, 2, :property_write, 8)
      {:ok, resized} = write(stored, :number_of_states, 2, :application_write)
      assert resized.object.present_value == 2
      assert resized.object.relinquish_default == 1
      assert resized.object.priority_array.priority_16 == nil
    end

    test "lifecycle preflight rejects inconsistent candidates and sparse labels" do
      stored = initialize(%{state_text: BACnetArray.from_list(["1", "2", "3", "4"])})
      ctx = context(stored, {:application_write, :description, nil, nil})

      for candidate <- [
            %{stored.object | number_of_states: 3},
            %{stored.object | state_text: BACnetArray.from_list(["1", :undefined, "3", "4"])}
          ] do
        assert {:error, {:invalid_configuration, :state_text}} =
                 Lifecycle.prepare_write(stored.object, candidate, ctx)

        assert {:error, {:invalid_configuration, :state_text}} = Lifecycle.execute(candidate, ctx)
      end

      invalid = %{stored.object | present_value: 5}
      assert {:error, {:invalid_configuration, :present_value}} = Lifecycle.execute(invalid, ctx)
    end

    test "optional reliability drives fault status and inhibition retains the latest report" do
      stored = initialize(%{reliability: :process_error})
      assert stored.object.status_flags.fault
      {:ok, inhibited} = write(stored, :reliability_evaluation_inhibit, true)
      assert inhibited.object.reliability == :no_fault_detected
      refute inhibited.object.status_flags.fault

      for property <- [:reliability, 103] do
        {:ok, candidate} =
          MultistateValue.update_property(inhibited.object, :reliability, :communication_failure)

        {:ok, reported} = commit(inhibited, candidate, {:application_write, property, nil, nil})
        assert reported.object.reliability == :no_fault_detected
        {:ok, restored} = write(reported, :reliability_evaluation_inhibit, false)
        assert restored.object.reliability == :communication_failure
        assert restored.object.status_flags.fault
      end
    end

    test "OOS reliability simulation accepts both origins and is effective even while inhibited" do
      for capabilities <- [%{}, %{relinquish_default: 1}],
          source <- [:property_write, :application_write] do
        stored =
          initialize(
            Map.merge(capabilities, %{
              reliability: :process_error,
              reliability_evaluation_inhibit: true
            })
          )

        {:ok, isolated} = write(stored, :out_of_service, true)
        assert isolated.object.reliability == :no_fault_detected
        {:ok, simulated} = write(isolated, :reliability, :no_sensor, source)
        assert simulated.object.reliability == :no_sensor
        assert simulated.object.status_flags.fault

        {:ok, read} =
          Lifecycle.prepare_read(
            simulated.object,
            context(simulated, {:property_read, :reliability, nil})
          )

        assert read.object.reliability == :no_sensor
        {:ok, returned} = write(read, :out_of_service, false)
        assert returned.object.reliability == :no_fault_detected
        {:ok, restored} = write(returned, :reliability_evaluation_inhibit, false)
        assert restored.object.reliability == :no_sensor
      end
    end

    test "initial OOS reliability and restart preserve supplied properties" do
      stored =
        initialize(%{
          present_value: 3,
          out_of_service: true,
          reliability: :process_error,
          reliability_evaluation_inhibit: true
        })

      assert stored.object.reliability == :process_error
      ctx = %{context(stored, :initialization) | state: :discard_old_runtime}
      {:ok, restarted} = Lifecycle.execute(stored.object, ctx)
      assert restarted.object.present_value == 3
      assert restarted.object.reliability == :process_error
      assert restarted.next_execution == nil
    end

    test "optional reliability groups can be added removed and selected again" do
      stored = initialize(%{})
      {:ok, candidate} = MultistateValue.add_property(stored.object, :reliability, :process_error)
      {:ok, added} = commit(stored, candidate, {:application_write, :reliability, nil, nil})
      assert added.object.status_flags.fault
      {:ok, candidate} = MultistateValue.remove_property(added.object, :reliability)
      {:ok, removed} = commit(added, candidate, {:application_write, :reliability, nil, nil})
      refute removed.object.status_flags.fault

      {:ok, candidate} =
        MultistateValue.add_property(removed.object, :reliability, :no_fault_detected)

      {:ok, added} = commit(removed, candidate, {:application_write, :reliability, nil, nil})
      refute added.object.status_flags.fault
    end

    test "numeric reliability options and arbitrary clock changes preserve the value" do
      stored = initialize(%{present_value: 3, reliability: 999}, allow_numeric_constants: true)

      ctx = %{
        context(stored, :clock_change)
        | now: ~U[2020-01-01 00:00:00Z],
          monotonic_time: -999_999
      }

      assert {:ok, ^stored} = Lifecycle.execute(stored.object, ctx)
    end

    test "reports alarm states and gives a configured state fault precedence" do
      stored =
        initialize(%{relinquish_default: 1, alarm_values: [2, 3], fault_values: [3]},
          intrinsic_reporting: true
        )

      {:ok, alarm} = write(stored, :present_value, 2)

      assert %{
               event_type: :change_of_state,
               to_state: :offnormal,
               event_values: %{new_state: %{type: :unsigned_value, value: 2}}
             } = EventReporting.transition(alarm)

      {:ok, fault} = write(alarm, :present_value, 3)
      assert fault.object.present_value == 3
      assert fault.object.reliability == :multi_state_fault
      assert fault.object.status_flags.fault

      assert %{event_type: :change_of_reliability, from_state: :offnormal, to_state: :fault} =
               EventReporting.transition(fault)
    end

    test "status flags follow supplied event state OOS and reliability but retain overridden" do
      stored = initialize(%{reliability: :no_fault_detected})

      {:ok, candidate} =
        MultistateValue.update_property(stored.object, :status_flags, %{
          stored.object.status_flags
          | overridden: true
        })

      {:ok, overridden} = commit(stored, candidate, {:application_write, :status_flags, nil, nil})
      {:ok, alarmed} = write(overridden, :event_state, :offnormal, :application_write)
      assert alarmed.object.status_flags.in_alarm
      assert alarmed.object.status_flags.overridden
      {:ok, isolated} = write(alarmed, :out_of_service, true)
      assert isolated.object.status_flags.out_of_service
      assert isolated.object.status_flags.overridden
    end

    test "uninitialized malformed and other-instance runtime states are rejected" do
      stored = initialize(%{})

      for state <- [
            nil,
            :bad,
            %{},
            %{stored.state | value: 0},
            %{stored.state | out_of_service: nil}
          ] do
        assert {:error, :invalid_execution_state} =
                 Lifecycle.execute(stored.object, %{context(stored, :periodic) | state: state})
      end

      {:ok, other} = MultistateValue.create(11, "Other", %{number_of_states: 4})

      assert {:error, :invalid_execution_state} =
               Lifecycle.execute(other, context(stored, :periodic))
    end

    test "remote snapshots remain passive and reject local preparation" do
      {:ok, local} = MultistateValue.create(10, "Local", %{number_of_states: 4, present_value: 3})

      properties =
        Map.take(local, [
          :number_of_states,
          :present_value,
          :out_of_service,
          :event_state,
          :status_flags
        ])

      {:ok, remote} = MultistateValue.create(10, "Remote", properties, remote_object: 42)
      ctx = %{context(nil, :periodic) | state: :opaque_snapshot_state}
      expected = %Result{object: remote, state: :opaque_snapshot_state, next_execution: nil}
      assert {:ok, ^expected} = Lifecycle.execute(remote, ctx)
      assert {:ok, ^expected} = ObjectsProtocol.execute(remote, ctx)
      assert :ok = MultistateValue.validate_execution(remote, ctx)

      assert {:error, :operation_not_available_for_remote_objects} =
               MultistateValue.prepare_write(remote, remote, ctx)
    end

    test "a host can command and read a local value through native property conversion" do
      {:ok, object} =
        MultistateValue.create(10, "Mode", %{number_of_states: 4, relinquish_default: 1})

      host = Host.new([{object, []}], @now, 0)
      id = MultistateValue.get_object_identifier(object)
      assert :ok = Host.execute(host, id, :initialization)

      reference = %DeviceObjectPropertyRef{
        device_identifier: nil,
        object_identifier: id,
        property_identifier: :present_value,
        property_array_index: nil
      }

      assert :ok = Host.write(host, reference, Encoding.create!({:unsigned_integer, 3}), 8)
      assert {:ok, 3} = Host.read(host, reference)
      assert :ok = Host.write(host, reference, Encoding.create!({:null, nil}), 8)
      assert {:ok, 1} = Host.read(host, reference)
      assert Host.snapshot(host, id).next_execution == nil
    end

    defp initialize(properties, options \\ []) do
      {:ok, object} =
        MultistateValue.create(
          10,
          "Value",
          Map.merge(%{number_of_states: 4}, properties),
          options
        )

      {:ok, result} = Lifecycle.execute(object, context(nil, :initialization))
      result
    end

    defp context(stored, trigger) do
      Context.new(trigger,
        now: @now,
        monotonic_time: 0,
        state: if(stored, do: stored.state),
        lookup_object: fn
          %{object_identifier: %{type: :notification_class}} -> {:error, :unknown_object}
          _reference -> flunk("unexpected lookup")
        end,
        read_property: fn _ref -> flunk("unexpected read") end,
        read_property_multiple: fn _ref, _properties -> flunk("unexpected multiple read") end,
        write_property: fn _ref, _value, _priority -> flunk("unexpected write") end
      )
    end

    defp commit(stored, candidate, trigger) do
      ctx = context(stored, trigger)

      with {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx),
           do: MultistateValue.execute(prepared, ctx)
    end

    defp write(stored, property, value, source \\ :property_write, priority \\ nil) do
      candidate =
        if property == :present_value and MultistateValue.has_priority_array?(stored.object),
          do: MultistateValue.set_priority(stored.object, priority || 16, value),
          else: MultistateValue.update_property(stored.object, property, value)

      with {:ok, candidate} <- candidate,
           do: commit(stored, candidate, {source, property, nil, priority})
    end
  end
end
