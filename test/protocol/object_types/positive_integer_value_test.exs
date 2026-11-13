defmodule BACnet.Test.Protocol.ObjectTypes.PositiveIntegerValueTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.LimitEnable
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectTypes.PositiveIntegerValue
  alias BACnet.Protocol.PriorityArray
  alias BACnet.Test.Support.Protocol.ObjectExecutionTestHost, as: Host

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_positive_integer_value

  @now ~U[2026-11-09 10:00:00Z]

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "verify create/4 for priority_array fails on value lower than min" do
    assert {:error, {:value_failed_property_validation, :priority_array}} =
             PositiveIntegerValue.create(1, "TEST", %{
               priority_array: %PriorityArray{priority_16: 1},
               max_present_value: 50,
               min_present_value: 5
             })
  end

  test "verify create/4 for priority_array fails on value higher than max" do
    assert {:error, {:value_failed_property_validation, :priority_array}} =
             PositiveIntegerValue.create(1, "TEST", %{
               priority_array: %PriorityArray{priority_16: 55},
               max_present_value: 50,
               min_present_value: 5
             })
  end

  for property <- [:present_value, :relinquish_default] do
    test "verify create/4 for #{property} fails on value lower than min" do
      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               PositiveIntegerValue.create(1, "TEST", %{
                 unquote(property) => 1,
                 max_present_value: 50,
                 min_present_value: 5
               })
    end

    test "verify create/4 for #{property} fails on value higher than max" do
      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               PositiveIntegerValue.create(1, "TEST", %{
                 unquote(property) => 55,
                 max_present_value: 50,
                 min_present_value: 5
               })
    end

    test "verify update_property/3 for #{property} ignores min/max if max not present" do
      {:ok, %PositiveIntegerValue{unquote(property) => 0} = obj} =
        PositiveIntegerValue.create(1, "TEST", %{unquote(property) => 0, min_present_value: 5})

      assert {:ok, %PositiveIntegerValue{unquote(property) => 1}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 1)

      assert {:ok, %PositiveIntegerValue{unquote(property) => 32_767}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 32_767)
    end

    test "verify update_property/3 for #{property} ignores min/max if min not present" do
      {:ok, %PositiveIntegerValue{unquote(property) => 0} = obj} =
        PositiveIntegerValue.create(1, "TEST", %{unquote(property) => 0, max_present_value: 50})

      assert {:ok, %PositiveIntegerValue{unquote(property) => 51}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 51)

      assert {:ok, %PositiveIntegerValue{unquote(property) => 32_767}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 32_767)
    end

    test "verify update_property/3 for #{property} working within configured min/max" do
      {:ok, %PositiveIntegerValue{unquote(property) => 5} = obj} =
        PositiveIntegerValue.create(1, "TEST", %{
          unquote(property) => 5,
          max_present_value: 50,
          min_present_value: 5
        })

      assert {:ok, %PositiveIntegerValue{unquote(property) => 20}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 20)

      assert {:ok, %PositiveIntegerValue{unquote(property) => 20}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 20)

      assert {:ok, %PositiveIntegerValue{unquote(property) => 50}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 50)

      assert {:ok, %PositiveIntegerValue{unquote(property) => 50}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 50)

      assert {:ok, %PositiveIntegerValue{unquote(property) => 20} = obj} =
               PositiveIntegerValue.update_property(obj, unquote(property), 20)

      assert {:ok, %PositiveIntegerValue{unquote(property) => 20} = obj} =
               PositiveIntegerValue.update_property(obj, unquote(property), 20)

      assert {:ok, %PositiveIntegerValue{unquote(property) => 50} = obj} =
               PositiveIntegerValue.update_property(obj, unquote(property), 50)

      assert {:ok, %PositiveIntegerValue{unquote(property) => 50} = obj} =
               PositiveIntegerValue.update_property(obj, unquote(property), 50)

      assert {:ok, %PositiveIntegerValue{unquote(property) => 5}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 5)
    end

    test "verify update_property/3 for #{property} fails on value lower than min" do
      {:ok, %PositiveIntegerValue{unquote(property) => 5} = obj} =
        PositiveIntegerValue.create(1, "TEST", %{
          unquote(property) => 5,
          max_present_value: 50,
          min_present_value: 5
        })

      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 4)

      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 0)
    end

    test "verify update_property/3 for #{property} fails on value higher than max" do
      {:ok, %PositiveIntegerValue{unquote(property) => 5} = obj} =
        PositiveIntegerValue.create(1, "TEST", %{
          unquote(property) => 5,
          max_present_value: 50,
          min_present_value: 5
        })

      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 51)

      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               PositiveIntegerValue.update_property(obj, unquote(property), 32_767)
    end
  end

  test "verify update_property/3 only checks present_value for min/max" do
    {:ok, %PositiveIntegerValue{present_value: 0} = obj} =
      PositiveIntegerValue.create(1, "TEST", %{max_present_value: 50, min_present_value: 0})

    assert {:ok, %PositiveIntegerValue{cov_increment: 0}} =
             PositiveIntegerValue.update_property(obj, :cov_increment, 0)

    assert {:ok, %PositiveIntegerValue{cov_increment: 51}} =
             PositiveIntegerValue.update_property(obj, :cov_increment, 51)

    assert {:error, {:invalid_property_type, :cov_increment}} =
             PositiveIntegerValue.update_property(obj, :cov_increment, -1)
  end

  test "verify set_priority/3 ignores min/max if max not present" do
    {:ok, %PositiveIntegerValue{present_value: 5} = obj} =
      PositiveIntegerValue.create(1, "TEST", %{min_present_value: 50, relinquish_default: 5})

    assert {:ok, %PositiveIntegerValue{present_value: 51}} =
             PositiveIntegerValue.set_priority(obj, 16, 51)

    assert {:ok, %PositiveIntegerValue{present_value: 32_767}} =
             PositiveIntegerValue.set_priority(obj, 16, 32_767)
  end

  test "verify set_priority/3 ignores min/max if min not present" do
    {:ok, %PositiveIntegerValue{present_value: 5} = obj} =
      PositiveIntegerValue.create(1, "TEST", %{max_present_value: 50, relinquish_default: 5})

    assert {:ok, %PositiveIntegerValue{present_value: 51}} =
             PositiveIntegerValue.set_priority(obj, 16, 51)

    assert {:ok, %PositiveIntegerValue{present_value: 32_767}} =
             PositiveIntegerValue.set_priority(obj, 16, 32_767)
  end

  test "verify set_priority/3 working within configured min/max" do
    {:ok, %PositiveIntegerValue{present_value: 5} = obj} =
      PositiveIntegerValue.create(1, "TEST", %{
        max_present_value: 50,
        min_present_value: 5,
        relinquish_default: 5
      })

    assert {:ok, %PositiveIntegerValue{present_value: 20}} =
             PositiveIntegerValue.set_priority(obj, 16, 20)

    assert {:ok, %PositiveIntegerValue{present_value: 20}} =
             PositiveIntegerValue.set_priority(obj, 16, 20)

    assert {:ok, %PositiveIntegerValue{present_value: 50}} =
             PositiveIntegerValue.set_priority(obj, 16, 50)

    assert {:ok, %PositiveIntegerValue{present_value: 50}} =
             PositiveIntegerValue.set_priority(obj, 16, 50)

    assert {:ok, %PositiveIntegerValue{present_value: 20} = obj} =
             PositiveIntegerValue.set_priority(obj, 16, 20)

    assert {:ok, %PositiveIntegerValue{present_value: 20} = obj} =
             PositiveIntegerValue.set_priority(obj, 16, 20)

    assert {:ok, %PositiveIntegerValue{present_value: 50} = obj} =
             PositiveIntegerValue.set_priority(obj, 16, 50)

    assert {:ok, %PositiveIntegerValue{present_value: 50} = obj} =
             PositiveIntegerValue.set_priority(obj, 16, 50)

    assert {:ok, %PositiveIntegerValue{present_value: 5}} =
             PositiveIntegerValue.set_priority(obj, 16, 5)
  end

  test "verify set_priority/3 fails on value lower than min" do
    {:ok, %PositiveIntegerValue{present_value: 5} = obj} =
      PositiveIntegerValue.create(1, "TEST", %{
        max_present_value: 50,
        min_present_value: 5,
        relinquish_default: 5
      })

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             PositiveIntegerValue.set_priority(obj, 16, 4)
  end

  test "verify set_priority/3 fails on value higher than max" do
    {:ok, %PositiveIntegerValue{present_value: 5} = obj} =
      PositiveIntegerValue.create(1, "TEST", %{
        max_present_value: 50,
        min_present_value: 5,
        relinquish_default: 5
      })

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             PositiveIntegerValue.set_priority(obj, 16, 51)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             PositiveIntegerValue.set_priority(obj, 16, 32_767)
  end

  describe "lifecycle" do
    test "zero is an active unsigned command through the host until relinquished" do
      {:ok, object} = PositiveIntegerValue.create(10, "Count", %{relinquish_default: 5})
      host = Host.new([{object, []}], @now, 0)
      id = PositiveIntegerValue.get_object_identifier(object)
      assert :ok = Host.execute(host, id, :initialization)

      reference = %DeviceObjectPropertyRef{
        device_identifier: nil,
        object_identifier: id,
        property_identifier: :present_value,
        property_array_index: nil
      }

      assert :ok = Host.write(host, reference, Encoding.create!({:unsigned_integer, 0}))
      assert :ok = Host.write(host, reference, Encoding.create!({:unsigned_integer, 12}), 8)
      assert {:ok, 12} = Host.read(host, reference)
      assert :ok = Host.write(host, reference, Encoding.create!({:null, nil}), 8)
      assert {:ok, 0} = Host.read(host, reference)
      assert :ok = Host.write(host, reference, Encoding.create!({:null, nil}))
      assert {:ok, 5} = Host.read(host, reference)
      assert Host.snapshot(host, id).next_execution == nil

      assert {:error, {:invalid_property_type, :priority_array}} =
               PositiveIntegerValue.set_priority(object, 16, -1)
    end

    test "direct writes preserve unsigned typing and isolate normal software while out of service" do
      stored = initialize(%{present_value: 5})

      assert {:error, {:invalid_property_type, :present_value}} =
               write(stored, :present_value, -1, :application_write)

      {:ok, produced} = write(stored, :present_value, 0, :application_write)
      {:ok, isolated} = write(produced, :out_of_service, true)

      for property <- [:present_value, 85] do
        ctx = context(isolated, {:application_write, property, nil, nil})

        assert {:error, :out_of_service} =
                 Lifecycle.prepare_write(isolated.object, isolated.object, ctx)

        assert {:error, :out_of_service} = Lifecycle.execute(isolated.object, ctx)
      end

      {:ok, simulated} = write(isolated, :present_value, 8)
      assert simulated.object.present_value == 8
      {:ok, resumed} = write(simulated, :out_of_service, false, :application_write)
      assert resumed.object.present_value == 8
      {:ok, updated} = write(resumed, :present_value, 0, :application_write)
      assert updated.object.present_value == 0
    end

    test "out-of-service commands still arbitrate and local effective changes are rejected" do
      stored = initialize(%{out_of_service: true, relinquish_default: 1})
      {:ok, high} = write(stored, :present_value, 8, :property_write, 8)
      assert {:error, :out_of_service} = write(high, :present_value, 0, :application_write)

      {:ok, masked} = write(high, :relinquish_default, 0, :application_write)
      assert masked.object.present_value == 8
      {:ok, released} = write(masked, :present_value, nil, :property_write, 8)
      assert released.object.present_value == 0

      assert {:error, :out_of_service} =
               write(released, :relinquish_default, 2, :application_write)

      {:ok, candidate} =
        PositiveIntegerValue.update_property(released.object, :out_of_service, false)

      {:ok, candidate} = PositiveIntegerValue.update_property(candidate, :relinquish_default, 2)

      assert {:error, :out_of_service} =
               Lifecycle.prepare_write(
                 released.object,
                 candidate,
                 context(released, {:application_write, :out_of_service, nil, nil})
               )
    end

    test "priority six is reserved even when its value is zero" do
      stored = initialize(%{relinquish_default: 0})

      for value <- [0, nil] do
        assert {:error, :write_access_denied} =
                 PositiveIntegerValue.set_priority(stored.object, 6, value)
      end

      for origin <- [:property_write, :application_write], property <- [:present_value, 85] do
        ctx = context(stored, {origin, property, nil, 6})

        assert {:error, :write_access_denied} =
                 Lifecycle.prepare_write(stored.object, stored.object, ctx)

        assert {:error, :write_access_denied} = Lifecycle.execute(stored.object, ctx)
      end

      {:ok, invalid} =
        PositiveIntegerValue.create(10, "Reserved slot", %{
          priority_array: %PriorityArray{priority_6: 0}
        })

      assert {:error, {:invalid_configuration, :priority_6}} =
               Lifecycle.execute(invalid, context(nil, :initialization))
    end

    test "range edits validate the effective value, masked slots and default before commit" do
      for {properties, property} <- [
            {%{present_value: 40}, :present_value},
            {%{priority_array: %PriorityArray{priority_8: 0, priority_16: 40}}, :priority_array},
            {%{priority_array: %PriorityArray{priority_8: 0}, relinquish_default: 40},
             :relinquish_default}
          ] do
        stored =
          initialize(Map.merge(%{min_present_value: 0, max_present_value: 50}, properties))

        assert {:error, {:value_failed_property_validation, ^property}} =
                 write(stored, :max_present_value, 20, :application_write)

        assert stored.object.max_present_value == 50

        {:ok, candidate} =
          PositiveIntegerValue.update_property(stored.object, :max_present_value, 20)

        assert {:error, {:value_failed_property_validation, ^property}} =
                 Lifecycle.execute(candidate, context(nil, :initialization))
      end
    end

    test "reliability inhibition retains the last report and permits simulation from both origins" do
      for origin <- [:property_write, :application_write] do
        stored = initialize(%{reliability: :process_error})
        {:ok, inhibited} = write(stored, :reliability_evaluation_inhibit, true)

        {:ok, reported} =
          write(inhibited, :reliability, :communication_failure, :application_write)

        assert reported.object.reliability == :no_fault_detected
        refute reported.object.status_flags.fault

        {:ok, restored} = write(reported, :reliability_evaluation_inhibit, false)
        assert restored.object.reliability == :communication_failure
        assert restored.object.status_flags.fault

        {:ok, masked} = write(restored, :reliability_evaluation_inhibit, true)
        {:ok, isolated} = write(masked, :out_of_service, true)
        assert isolated.object.reliability == :no_fault_detected
        {:ok, simulated} = write(isolated, :reliability, :process_error, origin)
        assert simulated.object.reliability == :process_error
        assert simulated.object.status_flags.fault
        {:ok, resumed} = write(simulated, :out_of_service, false)
        assert resumed.object.reliability == :no_fault_detected
        refute resumed.object.status_flags.fault
      end
    end

    test "reports an unsigned high limit" do
      stored =
        initialize(%{high_limit: 5, limit_enable: LimitEnable.from_bitstring({false, true})},
          intrinsic_reporting: true
        )

      {:ok, changed} = write(stored, :present_value, 6)
      assert changed.object.present_value == 6

      assert %{
               event_type: :unsigned_out_of_range,
               to_state: :high_limit,
               event_values: %{exceeding_value: 6}
             } = EventReporting.transition(changed)

      assert changed.next_execution == nil
    end

    test "runtime state requires an unsigned value and remote snapshots remain passive" do
      stored = initialize(%{})
      ctx = context(stored, :periodic)

      assert {:error, :invalid_execution_state} =
               Lifecycle.execute(stored.object, %{ctx | state: %{stored.state | value: -1}})

      assert {:error, :invalid_execution_state} =
               Lifecycle.execute(stored.object, %{ctx | state: nil})

      {:ok, another} = PositiveIntegerValue.create(11, "Another")

      assert {:error, :invalid_execution_state} =
               Lifecycle.execute(another, context(stored, :periodic))

      properties =
        Map.take(stored.object, [
          :present_value,
          :event_state,
          :status_flags,
          :out_of_service,
          :units
        ])

      {:ok, remote} = PositiveIntegerValue.create(11, "Remote", properties, remote_object: 42)
      ctx = %{ctx | state: :snapshot}

      assert {:ok, %Result{object: ^remote, state: :snapshot, next_execution: nil}} =
               Lifecycle.execute(remote, ctx)

      assert {:error, :operation_not_available_for_remote_objects} =
               PositiveIntegerValue.prepare_write(remote, remote, ctx)

      assert :ok = PositiveIntegerValue.validate_execution(remote, ctx)

      assert {:ok, %Result{object: ^remote, state: :snapshot, next_execution: nil}} =
               PositiveIntegerValue.execute(remote, ctx)
    end

    test "out-of-service edits keep the previously stored manual reliability" do
      stored =
        initialize(%{
          out_of_service: true,
          reliability: :process_error,
          description: "Count"
        })

      assert stored.object.reliability == :process_error
      assert stored.state.manual_reliability == :process_error

      {:ok, renamed} = write(stored, :description, "Simulated count")
      assert renamed.object.description == "Simulated count"
      assert renamed.object.reliability == :process_error
      assert renamed.state.manual_reliability == :process_error

      {:ok, inhibited} = write(renamed, :reliability_evaluation_inhibit, true)
      assert inhibited.object.reliability == :process_error
      assert inhibited.object.status_flags.fault
      assert inhibited.state.manual_reliability == :process_error
    end

    defp initialize(properties, options \\ []) do
      {:ok, object} = PositiveIntegerValue.create(10, "Count", properties, options)
      {:ok, stored} = Lifecycle.execute(object, context(nil, :initialization))
      stored
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
        write_property: fn _ref, _value, _priority -> flunk("unexpected write") end
      )
    end

    defp write(stored, property, value, origin \\ :property_write, priority \\ nil) do
      ctx = context(stored, {origin, property, nil, priority})

      candidate =
        if property == :present_value and PositiveIntegerValue.has_priority_array?(stored.object),
          do: PositiveIntegerValue.set_priority(stored.object, priority || 16, value),
          else: PositiveIntegerValue.update_property(stored.object, property, value)

      with {:ok, candidate} <- candidate,
           {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
        PositiveIntegerValue.execute(prepared, ctx)
      end
    end
  end
end
