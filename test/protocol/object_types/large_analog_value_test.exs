defmodule BACnet.Test.Protocol.ObjectTypes.LargeAnalogValueTest do
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.LimitEnable
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectTypes.LargeAnalogValue
  alias BACnet.Protocol.PriorityArray
  alias BACnet.Test.Support.Protocol.ObjectExecutionTestHost, as: Host

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_large_analog_value

  test "infinite bounds accept finite values and IEEE special values" do
    limits = %{min_present_value: :infn, max_present_value: :inf}
    {:ok, direct} = LargeAnalogValue.create(1, "Precise", limits)

    {:ok, commandable} =
      LargeAnalogValue.create(2, "Commandable", Map.put(limits, :relinquish_default, 0.0))

    for value <- [1.0000000000000002, :infn, :inf, :NaN] do
      assert {:ok, %{present_value: ^value}} =
               LargeAnalogValue.update_property(direct, :present_value, value)

      assert {:ok, %{present_value: ^value}} =
               LargeAnalogValue.set_priority(commandable, 16, value)

      assert {:ok, %{relinquish_default: ^value}} =
               LargeAnalogValue.update_property(commandable, :relinquish_default, value)
    end
  end

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  for property <- [:present_value, :relinquish_default] do
    test "verify update_property/3 for #{property} ignores min/max if max not present" do
      {:ok, %LargeAnalogValue{unquote(property) => +0.0} = obj} =
        LargeAnalogValue.create(1, "TEST", %{unquote(property) => 0.0, min_present_value: 50.0})

      assert {:ok, %LargeAnalogValue{unquote(property) => -51.0}} =
               LargeAnalogValue.update_property(obj, unquote(property), -51.0)

      assert {:ok, %LargeAnalogValue{unquote(property) => -32_767.0}} =
               LargeAnalogValue.update_property(obj, unquote(property), -32_767.0)
    end

    test "verify update_property/3 for #{property} ignores min/max if min not present" do
      {:ok, %LargeAnalogValue{unquote(property) => +0.0} = obj} =
        LargeAnalogValue.create(1, "TEST", %{unquote(property) => 0.0, max_present_value: 50.0})

      assert {:ok, %LargeAnalogValue{unquote(property) => 51.0}} =
               LargeAnalogValue.update_property(obj, unquote(property), 51.0)

      assert {:ok, %LargeAnalogValue{unquote(property) => 32_767.0}} =
               LargeAnalogValue.update_property(obj, unquote(property), 32_767.0)
    end

    test "verify update_property/3 for #{property} working within configured min/max" do
      {:ok, %LargeAnalogValue{unquote(property) => +0.0} = obj} =
        LargeAnalogValue.create(1, "TEST", %{
          unquote(property) => 0.0,
          max_present_value: 50.0,
          min_present_value: -50.0
        })

      assert {:ok, %LargeAnalogValue{unquote(property) => -20.0}} =
               LargeAnalogValue.update_property(obj, unquote(property), -20.0)

      assert {:ok, %LargeAnalogValue{unquote(property) => 20.0}} =
               LargeAnalogValue.update_property(obj, unquote(property), 20.0)

      assert {:ok, %LargeAnalogValue{unquote(property) => -50.0}} =
               LargeAnalogValue.update_property(obj, unquote(property), -50.0)

      assert {:ok, %LargeAnalogValue{unquote(property) => 50.0}} =
               LargeAnalogValue.update_property(obj, unquote(property), 50.0)

      assert {:ok, %LargeAnalogValue{unquote(property) => -20.0} = obj} =
               LargeAnalogValue.update_property(obj, unquote(property), -20.0)

      assert {:ok, %LargeAnalogValue{unquote(property) => 20.0} = obj} =
               LargeAnalogValue.update_property(obj, unquote(property), 20.0)

      assert {:ok, %LargeAnalogValue{unquote(property) => -50.0} = obj} =
               LargeAnalogValue.update_property(obj, unquote(property), -50.0)

      assert {:ok, %LargeAnalogValue{unquote(property) => 50.0} = obj} =
               LargeAnalogValue.update_property(obj, unquote(property), 50.0)

      assert {:ok, %LargeAnalogValue{unquote(property) => +0.0}} =
               LargeAnalogValue.update_property(obj, unquote(property), 0.0)
    end

    test "verify update_property/3 for #{property} fails on value lower than min" do
      {:ok, %LargeAnalogValue{unquote(property) => +0.0} = obj} =
        LargeAnalogValue.create(1, "TEST", %{
          unquote(property) => 0.0,
          max_present_value: 50.0,
          min_present_value: -50.0
        })

      assert {:error, {:property_out_of_range, unquote(property)}} =
               LargeAnalogValue.update_property(obj, unquote(property), -51.0)

      assert {:error, {:property_out_of_range, unquote(property)}} =
               LargeAnalogValue.update_property(obj, unquote(property), -32_767.0)
    end

    test "verify update_property/3 for #{property} fails on value higher than max" do
      {:ok, %LargeAnalogValue{unquote(property) => +0.0} = obj} =
        LargeAnalogValue.create(1, "TEST", %{
          unquote(property) => 0.0,
          max_present_value: 50.0,
          min_present_value: -50.0
        })

      assert {:error, {:property_out_of_range, unquote(property)}} =
               LargeAnalogValue.update_property(obj, unquote(property), 51.0)

      assert {:error, {:property_out_of_range, unquote(property)}} =
               LargeAnalogValue.update_property(obj, unquote(property), 32_767.0)
    end
  end

  test "verify update_property/3 only checks present_value for min/max" do
    {:ok, %LargeAnalogValue{present_value: +0.0} = obj} =
      LargeAnalogValue.create(1, "TEST", %{max_present_value: 50.0, min_present_value: -50.0})

    assert {:ok, %LargeAnalogValue{cov_increment: -51.0}} =
             LargeAnalogValue.update_property(obj, :cov_increment, -51.0)

    assert {:ok, %LargeAnalogValue{cov_increment: 51.0}} =
             LargeAnalogValue.update_property(obj, :cov_increment, 51.0)
  end

  test "verify set_priority/3 ignores min/max if max not present" do
    {:ok, %LargeAnalogValue{present_value: +0.0} = obj} =
      LargeAnalogValue.create(1, "TEST", %{min_present_value: 50.0, relinquish_default: +0.0})

    assert {:ok, %LargeAnalogValue{present_value: -51.0}} =
             LargeAnalogValue.set_priority(obj, 16, -51.0)

    assert {:ok, %LargeAnalogValue{present_value: -32_767.0}} =
             LargeAnalogValue.set_priority(obj, 16, -32_767.0)
  end

  test "verify set_priority/3 ignores min/max if min not present" do
    {:ok, %LargeAnalogValue{present_value: +0.0} = obj} =
      LargeAnalogValue.create(1, "TEST", %{max_present_value: 50.0, relinquish_default: +0.0})

    assert {:ok, %LargeAnalogValue{present_value: 51.0}} =
             LargeAnalogValue.set_priority(obj, 16, 51.0)

    assert {:ok, %LargeAnalogValue{present_value: 32_767.0}} =
             LargeAnalogValue.set_priority(obj, 16, 32_767.0)
  end

  test "verify set_priority/3 working within configured min/max" do
    {:ok, %LargeAnalogValue{present_value: +0.0} = obj} =
      LargeAnalogValue.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0,
        relinquish_default: 0.0
      })

    assert {:ok, %LargeAnalogValue{present_value: -20.0}} =
             LargeAnalogValue.set_priority(obj, 16, -20.0)

    assert {:ok, %LargeAnalogValue{present_value: 20.0}} =
             LargeAnalogValue.set_priority(obj, 16, 20.0)

    assert {:ok, %LargeAnalogValue{present_value: -50.0}} =
             LargeAnalogValue.set_priority(obj, 16, -50.0)

    assert {:ok, %LargeAnalogValue{present_value: 50.0}} =
             LargeAnalogValue.set_priority(obj, 16, 50.0)

    assert {:ok, %LargeAnalogValue{present_value: -20.0} = obj} =
             LargeAnalogValue.set_priority(obj, 16, -20.0)

    assert {:ok, %LargeAnalogValue{present_value: 20.0} = obj} =
             LargeAnalogValue.set_priority(obj, 16, 20.0)

    assert {:ok, %LargeAnalogValue{present_value: -50.0} = obj} =
             LargeAnalogValue.set_priority(obj, 16, -50.0)

    assert {:ok, %LargeAnalogValue{present_value: 50.0} = obj} =
             LargeAnalogValue.set_priority(obj, 16, 50.0)

    assert {:ok, %LargeAnalogValue{present_value: +0.0}} =
             LargeAnalogValue.set_priority(obj, 16, 0.0)
  end

  test "verify set_priority/3 fails on value lower than min" do
    {:ok, %LargeAnalogValue{present_value: +0.0} = obj} =
      LargeAnalogValue.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0,
        relinquish_default: 0.0
      })

    assert {:error, {:property_out_of_range, :priority_array}} =
             LargeAnalogValue.set_priority(obj, 16, -51.0)

    assert {:error, {:property_out_of_range, :priority_array}} =
             LargeAnalogValue.set_priority(obj, 16, -32_767.0)
  end

  test "verify set_priority/3 fails on value higher than max" do
    {:ok, %LargeAnalogValue{present_value: +0.0} = obj} =
      LargeAnalogValue.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0,
        relinquish_default: 0.0
      })

    assert {:error, {:property_out_of_range, :priority_array}} =
             LargeAnalogValue.set_priority(obj, 16, 51.0)

    assert {:error, {:property_out_of_range, :priority_array}} =
             LargeAnalogValue.set_priority(obj, 16, 32_767.0)
  end

  @now ~U[2026-11-09 12:00:00Z]

  describe "lifecycle" do
    test "Double commands retain their precision through arbitration, wire encoding and relinquishment" do
      precise = 1.0000000000000002
      {:ok, object} = LargeAnalogValue.create(10, "Precise", %{relinquish_default: 5.0})
      host = Host.new([{object, []}], @now, 0)
      id = LargeAnalogValue.get_object_identifier(object)
      assert :ok = Host.execute(host, id, :initialization)

      reference = %DeviceObjectPropertyRef{
        device_identifier: nil,
        object_identifier: id,
        property_identifier: :present_value,
        property_array_index: nil
      }

      assert :ok = Host.write(host, reference, Encoding.create!({:double, precise}))
      assert :ok = Host.write(host, reference, Encoding.create!({:double, 12.0}), 8)
      assert {:ok, 12.0} = Host.read(host, reference)

      assert {:ok, slots} =
               ObjectsUtility.cast_value_to_property(
                 id,
                 :priority_array,
                 Host.snapshot(host, id).object.priority_array
               )

      assert %Encoding{type: :double, value: ^precise} = List.last(slots)
      assert :ok = Host.write(host, reference, Encoding.create!({:null, nil}), 8)
      assert {:ok, ^precise} = Host.read(host, reference)

      assert {:ok, %Encoding{type: :double, value: ^precise}} =
               ObjectsUtility.cast_value_to_property(id, :present_value, precise)

      assert {:ok, wire} = ApplicationTags.encode({:double, precise})
      assert {:ok, {:double, ^precise}, <<>>} = ApplicationTags.decode(wire)

      assert :ok = Host.write(host, reference, Encoding.create!({:null, nil}))
      assert {:ok, 5.0} = Host.read(host, reference)
      assert Host.snapshot(host, id).next_execution == nil
    end

    test "an absent Out_Of_Service leaves its flag false and permits application writes" do
      {:ok, object} =
        LargeAnalogValue.create(10, "Precise", %{
          out_of_service: true,
          reliability: :process_error
        })

      {:ok, object} = LargeAnalogValue.remove_property(object, :out_of_service)
      {:ok, stored} = Lifecycle.execute(object, context(nil, :initialization))

      refute LargeAnalogValue.has_property?(stored.object, :out_of_service)
      assert stored.object.status_flags.out_of_service == false

      {:ok, produced} = write(stored, :present_value, 1.0000000000000002, :application_write)
      {:ok, updated} = write(produced, :reliability, :no_fault_detected, :application_write)
      assert updated.object.present_value == 1.0000000000000002
      refute updated.object.status_flags.fault
    end

    test "in-service values retain IEEE special values across lifecycle steps" do
      stored = initialize(%{min_present_value: :infn, max_present_value: :inf})

      for value <- [:infn, :inf, :NaN] do
        {:ok, changed} = write(stored, :present_value, value, :application_write)
        read = context(changed, {:property_read, :present_value, nil})

        assert {:ok, %Result{object: %{present_value: ^value}, state: %{value: ^value}}} =
                 Lifecycle.prepare_read(changed.object, read)
      end
    end

    test "out-of-service commands still arbitrate and local effective changes are rejected" do
      stored = initialize(%{out_of_service: true, relinquish_default: 1.0})
      {:ok, high} = write(stored, :present_value, 8.0, :property_write, 8)
      assert {:error, :out_of_service} = write(high, :present_value, 0.0, :application_write)

      {:ok, masked} = write(high, :relinquish_default, 0.0, :application_write)
      assert masked.object.present_value == 8.0
      {:ok, released} = write(masked, :present_value, nil, :property_write, 8)
      assert released.object.present_value == 0.0

      assert {:error, :out_of_service} =
               write(released, :relinquish_default, 2.0, :application_write)

      {:ok, candidate} =
        LargeAnalogValue.update_property(released.object, :out_of_service, false)

      {:ok, candidate} = LargeAnalogValue.update_property(candidate, :relinquish_default, 2.0)

      assert {:error, :out_of_service} =
               Lifecycle.prepare_write(
                 released.object,
                 candidate,
                 context(released, {:application_write, :out_of_service, nil, nil})
               )
    end

    test "priority six is reserved for Double commands and relinquishment" do
      stored =
        initialize(%{relinquish_default: 0.0, min_present_value: -10.0, max_present_value: 10.0})

      for value <- [0.0, 100.0, nil] do
        assert {:error, :write_access_denied} =
                 LargeAnalogValue.set_priority(stored.object, 6, value)
      end

      for origin <- [:property_write, :application_write], property <- [:present_value, 85] do
        ctx = context(stored, {origin, property, nil, 6})

        assert {:error, :write_access_denied} =
                 Lifecycle.prepare_write(stored.object, stored.object, ctx)

        assert {:error, :write_access_denied} = Lifecycle.execute(stored.object, ctx)
      end

      {:ok, invalid} =
        LargeAnalogValue.create(10, "Reserved slot", %{
          priority_array: %PriorityArray{priority_6: 0.0}
        })

      assert {:error, {:invalid_configuration, :priority_6}} =
               Lifecycle.execute(invalid, context(nil, :initialization))
    end

    test "range edits validate the effective value, masked slots and default before commit" do
      for {properties, property} <- [
            {%{present_value: 40.0}, :present_value},
            {%{priority_array: %PriorityArray{priority_8: 0.0, priority_16: 40.0}},
             :priority_array},
            {%{priority_array: %PriorityArray{priority_8: 0.0}, relinquish_default: 40.0},
             :relinquish_default}
          ] do
        stored =
          initialize(Map.merge(%{min_present_value: 0.0, max_present_value: 50.0}, properties))

        assert {:error, {:property_out_of_range, ^property}} =
                 write(stored, :max_present_value, 20.0, :application_write)

        assert stored.object.max_present_value == 50.0

        {:ok, candidate} =
          LargeAnalogValue.update_property(stored.object, :max_present_value, 20.0)

        assert {:error, {:property_out_of_range, ^property}} =
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

    test "reports a Double high limit" do
      stored =
        initialize(%{high_limit: 5.0, limit_enable: LimitEnable.from_bitstring({false, true})},
          intrinsic_reporting: true
        )

      {:ok, changed} = write(stored, :present_value, 6.0)
      assert changed.object.present_value == 6.0

      assert %{
               event_type: :double_out_of_range,
               to_state: :high_limit,
               event_values: %{exceeding_value: 6.0}
             } = EventReporting.transition(changed)

      assert changed.next_execution == nil
    end

    test "runtime state requires a Double value and remote snapshots remain passive" do
      stored = initialize(%{})
      ctx = context(stored, :periodic)

      assert {:error, :invalid_execution_state} =
               Lifecycle.execute(stored.object, %{ctx | state: %{stored.state | value: -1}})

      assert {:error, :invalid_execution_state} =
               Lifecycle.execute(stored.object, %{ctx | state: nil})

      properties =
        Map.take(stored.object, [
          :present_value,
          :event_state,
          :status_flags,
          :out_of_service,
          :units
        ])

      {:ok, remote} = LargeAnalogValue.create(11, "Remote", properties, remote_object: 42)
      ctx = %{ctx | state: :snapshot}

      assert {:ok, %Result{object: ^remote, state: :snapshot, next_execution: nil}} =
               Lifecycle.execute(remote, ctx)

      assert {:error, :operation_not_available_for_remote_objects} =
               LargeAnalogValue.prepare_write(remote, remote, ctx)
    end

    defp initialize(properties, options \\ []) do
      {:ok, object} = LargeAnalogValue.create(10, "Precise", properties, options)
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
        if property == :present_value and LargeAnalogValue.has_priority_array?(stored.object),
          do: LargeAnalogValue.set_priority(stored.object, priority || 16, value),
          else: LargeAnalogValue.update_property(stored.object, property, value)

      with {:ok, candidate} <- candidate,
           {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
        LargeAnalogValue.execute(prepared, ctx)
      end
    end
  end
end
