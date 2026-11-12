defmodule BACnet.Test.Protocol.ObjectTypes.IntegerValueTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.LimitEnable
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectTypes.IntegerValue
  alias BACnet.Protocol.PriorityArray
  alias BACnet.Test.Support.Protocol.ObjectExecutionTestHost, as: Host

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_integer_value

  @now ~U[2026-11-09 10:00:00Z]

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  for property <- [:present_value, :relinquish_default] do
    test "verify update_property/3 for #{property} ignores min/max if max not present" do
      {:ok, %IntegerValue{unquote(property) => 0} = obj} =
        IntegerValue.create(1, "TEST", %{unquote(property) => 0, min_present_value: 50})

      assert {:ok, %IntegerValue{unquote(property) => -51}} =
               IntegerValue.update_property(obj, unquote(property), -51)

      assert {:ok, %IntegerValue{unquote(property) => -32_767}} =
               IntegerValue.update_property(obj, unquote(property), -32_767)
    end

    test "verify update_property/3 for #{property} ignores min/max if min not present" do
      {:ok, %IntegerValue{unquote(property) => 0} = obj} =
        IntegerValue.create(1, "TEST", %{unquote(property) => 0, max_present_value: 50})

      assert {:ok, %IntegerValue{unquote(property) => 51}} =
               IntegerValue.update_property(obj, unquote(property), 51)

      assert {:ok, %IntegerValue{unquote(property) => 32_767}} =
               IntegerValue.update_property(obj, unquote(property), 32_767)
    end

    test "verify update_property/3 for #{property} working within configured min/max" do
      {:ok, %IntegerValue{unquote(property) => 0} = obj} =
        IntegerValue.create(1, "TEST", %{
          unquote(property) => 0,
          max_present_value: 50,
          min_present_value: -50
        })

      assert {:ok, %IntegerValue{unquote(property) => -20}} =
               IntegerValue.update_property(obj, unquote(property), -20)

      assert {:ok, %IntegerValue{unquote(property) => 20}} =
               IntegerValue.update_property(obj, unquote(property), 20)

      assert {:ok, %IntegerValue{unquote(property) => -50}} =
               IntegerValue.update_property(obj, unquote(property), -50)

      assert {:ok, %IntegerValue{unquote(property) => 50}} =
               IntegerValue.update_property(obj, unquote(property), 50)

      assert {:ok, %IntegerValue{unquote(property) => -20} = obj} =
               IntegerValue.update_property(obj, unquote(property), -20)

      assert {:ok, %IntegerValue{unquote(property) => 20} = obj} =
               IntegerValue.update_property(obj, unquote(property), 20)

      assert {:ok, %IntegerValue{unquote(property) => -50} = obj} =
               IntegerValue.update_property(obj, unquote(property), -50)

      assert {:ok, %IntegerValue{unquote(property) => 50} = obj} =
               IntegerValue.update_property(obj, unquote(property), 50)

      assert {:ok, %IntegerValue{unquote(property) => 0}} =
               IntegerValue.update_property(obj, unquote(property), 0)
    end

    test "verify update_property/3 for #{property} fails on value lower than min" do
      {:ok, %IntegerValue{unquote(property) => 0} = obj} =
        IntegerValue.create(1, "TEST", %{
          unquote(property) => 0,
          max_present_value: 50,
          min_present_value: -50
        })

      assert {:error, {:property_out_of_range, unquote(property)}} =
               IntegerValue.update_property(obj, unquote(property), -51)

      assert {:error, {:property_out_of_range, unquote(property)}} =
               IntegerValue.update_property(obj, unquote(property), -32_767)
    end

    test "verify update_property/3 for #{property} fails on value higher than max" do
      {:ok, %IntegerValue{unquote(property) => 0} = obj} =
        IntegerValue.create(1, "TEST", %{
          unquote(property) => 0,
          max_present_value: 50,
          min_present_value: -50
        })

      assert {:error, {:property_out_of_range, unquote(property)}} =
               IntegerValue.update_property(obj, unquote(property), 51)

      assert {:error, {:property_out_of_range, unquote(property)}} =
               IntegerValue.update_property(obj, unquote(property), 32_767)
    end
  end

  test "verify update_property/3 only checks present_value for min/max" do
    {:ok, %IntegerValue{present_value: 0} = obj} =
      IntegerValue.create(1, "TEST", %{max_present_value: 50, min_present_value: -50})

    assert {:ok, %IntegerValue{cov_increment: 0}} =
             IntegerValue.update_property(obj, :cov_increment, 0)

    assert {:ok, %IntegerValue{cov_increment: 51}} =
             IntegerValue.update_property(obj, :cov_increment, 51)

    assert {:error, {:invalid_property_type, :cov_increment}} =
             IntegerValue.update_property(obj, :cov_increment, -1)
  end

  test "verify set_priority/3 ignores min/max if max not present" do
    {:ok, %IntegerValue{present_value: 0} = obj} =
      IntegerValue.create(1, "TEST", %{min_present_value: 50, relinquish_default: 0})

    assert {:ok, %IntegerValue{present_value: -51}} = IntegerValue.set_priority(obj, 16, -51)

    assert {:ok, %IntegerValue{present_value: -32_767}} =
             IntegerValue.set_priority(obj, 16, -32_767)
  end

  test "verify set_priority/3 ignores min/max if min not present" do
    {:ok, %IntegerValue{present_value: 0} = obj} =
      IntegerValue.create(1, "TEST", %{max_present_value: 50, relinquish_default: 0})

    assert {:ok, %IntegerValue{present_value: 51}} = IntegerValue.set_priority(obj, 16, 51)

    assert {:ok, %IntegerValue{present_value: 32_767}} =
             IntegerValue.set_priority(obj, 16, 32_767)
  end

  test "verify set_priority/3 working within configured min/max" do
    {:ok, %IntegerValue{present_value: 0} = obj} =
      IntegerValue.create(1, "TEST", %{
        max_present_value: 50,
        min_present_value: -50,
        relinquish_default: 0
      })

    assert {:ok, %IntegerValue{present_value: -20}} = IntegerValue.set_priority(obj, 16, -20)

    assert {:ok, %IntegerValue{present_value: 20}} = IntegerValue.set_priority(obj, 16, 20)

    assert {:ok, %IntegerValue{present_value: -50}} = IntegerValue.set_priority(obj, 16, -50)

    assert {:ok, %IntegerValue{present_value: 50}} = IntegerValue.set_priority(obj, 16, 50)

    assert {:ok, %IntegerValue{present_value: -20} = obj} =
             IntegerValue.set_priority(obj, 16, -20)

    assert {:ok, %IntegerValue{present_value: 20} = obj} = IntegerValue.set_priority(obj, 16, 20)

    assert {:ok, %IntegerValue{present_value: -50} = obj} =
             IntegerValue.set_priority(obj, 16, -50)

    assert {:ok, %IntegerValue{present_value: 50} = obj} = IntegerValue.set_priority(obj, 16, 50)

    assert {:ok, %IntegerValue{present_value: 0}} = IntegerValue.set_priority(obj, 16, 0)
  end

  test "verify set_priority/3 fails on value lower than min" do
    {:ok, %IntegerValue{present_value: 0} = obj} =
      IntegerValue.create(1, "TEST", %{
        max_present_value: 50,
        min_present_value: -50,
        relinquish_default: 0
      })

    assert {:error, {:property_out_of_range, :priority_array}} =
             IntegerValue.set_priority(obj, 16, -51)

    assert {:error, {:property_out_of_range, :priority_array}} =
             IntegerValue.set_priority(obj, 16, -32_767)
  end

  test "verify set_priority/3 fails on value higher than max" do
    {:ok, %IntegerValue{present_value: 0} = obj} =
      IntegerValue.create(1, "TEST", %{
        max_present_value: 50,
        min_present_value: -50,
        relinquish_default: 0
      })

    assert {:error, {:property_out_of_range, :priority_array}} =
             IntegerValue.set_priority(obj, 16, 51)

    assert {:error, {:property_out_of_range, :priority_array}} =
             IntegerValue.set_priority(obj, 16, 32_767)
  end

  describe "lifecycle" do
    test "native signed commands arbitrate and relinquish through the host" do
      {:ok, object} = IntegerValue.create(10, "Offset", %{relinquish_default: -5})
      host = Host.new([{object, []}], @now, 0)
      id = IntegerValue.get_object_identifier(object)
      assert :ok = Host.execute(host, id, :initialization)

      reference = %DeviceObjectPropertyRef{
        device_identifier: nil,
        object_identifier: id,
        property_identifier: :present_value,
        property_array_index: nil
      }

      assert :ok = Host.write(host, reference, Encoding.create!({:signed_integer, -20}))
      assert :ok = Host.write(host, reference, Encoding.create!({:signed_integer, -40}), 8)
      assert {:ok, -40} = Host.read(host, reference)
      assert :ok = Host.write(host, reference, Encoding.create!({:null, nil}), 8)
      assert {:ok, -20} = Host.read(host, reference)
      assert :ok = Host.write(host, reference, Encoding.create!({:null, nil}))
      assert {:ok, -5} = Host.read(host, reference)
      assert Host.snapshot(host, id).next_execution == nil
    end

    test "direct signed values accept local production in service and BACnet simulation while isolated" do
      stored = initialize(%{present_value: -2})
      {:ok, reported} = write(stored, :present_value, -4, :application_write)
      {:ok, isolated} = write(reported, :out_of_service, true)
      assert isolated.object.status_flags.out_of_service

      for property <- [:present_value, 85] do
        ctx = context(isolated, {:application_write, property, nil, nil})

        assert {:error, :out_of_service} =
                 Lifecycle.prepare_write(isolated.object, isolated.object, ctx)

        assert {:error, :out_of_service} = Lifecycle.execute(isolated.object, ctx)
      end

      {:ok, simulated} = write(isolated, :present_value, -9)
      assert simulated.object.present_value == -9
      {:ok, resumed} = write(simulated, :out_of_service, false, :application_write)
      assert resumed.object.present_value == -9
      {:ok, fresh} = write(resumed, :present_value, -1, :application_write)
      assert fresh.object.present_value == -1
    end

    test "isolation rejects masked local commands and indirect effective value changes" do
      stored = initialize(%{out_of_service: true, relinquish_default: -1})
      {:ok, high} = write(stored, :present_value, -10, :property_write, 8)
      assert {:error, :out_of_service} = write(high, :present_value, -20, :application_write)

      {:ok, masked} = write(high, :relinquish_default, -3, :application_write)
      assert masked.object.present_value == -10
      {:ok, released} = write(masked, :present_value, nil, :property_write, 8)
      assert released.object.present_value == -3

      assert {:error, :out_of_service} =
               write(released, :relinquish_default, -4, :application_write)

      {:ok, candidate} = IntegerValue.update_property(released.object, :out_of_service, false)
      {:ok, candidate} = IntegerValue.update_property(candidate, :relinquish_default, -4)

      assert {:error, :out_of_service} =
               Lifecycle.prepare_write(
                 released.object,
                 candidate,
                 context(released, {:application_write, :out_of_service, nil, nil})
               )
    end

    test "priority six is reserved for commandable instances" do
      stored = initialize(%{relinquish_default: 0, min_present_value: -10, max_present_value: 10})

      for value <- [-2, 100, nil] do
        assert {:error, :write_access_denied} = IntegerValue.set_priority(stored.object, 6, value)
      end

      for property <- [:present_value, 85], origin <- [:property_write, :application_write] do
        ctx = context(stored, {origin, property, nil, 6})

        assert {:error, :write_access_denied} =
                 Lifecycle.prepare_write(stored.object, stored.object, ctx)

        assert {:error, :write_access_denied} = Lifecycle.execute(stored.object, ctx)
      end

      {:ok, object} =
        IntegerValue.create(10, "Reserved slot", %{priority_array: %PriorityArray{priority_6: -2}})

      assert {:error, {:invalid_configuration, :priority_6}} =
               Lifecycle.execute(object, context(nil, :initialization))

      assert {:ok, result} = write(initialize(%{}), :present_value, -2, :property_write, 6)
      assert result.object.present_value == -2
    end

    test "limit edits validate the effective value, masked commands and relinquish default" do
      for {properties, property} <- [
            {%{present_value: -40}, :present_value},
            {%{
               priority_array: %PriorityArray{priority_8: 0, priority_16: -40},
               relinquish_default: 0
             }, :priority_array},
            {%{priority_array: %PriorityArray{priority_8: 0}, relinquish_default: -40},
             :relinquish_default}
          ] do
        stored =
          initialize(Map.merge(%{min_present_value: -50, max_present_value: 10}, properties))

        assert {:error, {:property_out_of_range, ^property}} =
                 write(stored, :min_present_value, -20, :application_write)

        assert stored.object.min_present_value == -50
      end
    end

    test "initialization and preparation reject masked commands outside the configured range" do
      {:ok, invalid} =
        IntegerValue.create(10, "Offset", %{
          min_present_value: -10,
          max_present_value: 10,
          priority_array: %PriorityArray{priority_8: 0, priority_16: -20}
        })

      assert {:error, {:property_out_of_range, :priority_array}} =
               Lifecycle.execute(invalid, context(nil, :initialization))

      stored = initialize(%{min_present_value: -10, max_present_value: 10, relinquish_default: 0})

      assert {:error, {:property_out_of_range, :priority_array}} =
               write(stored, :priority_array, invalid.priority_array, :application_write)
    end

    test "reliability inhibition preserves reports and allows explicit simulation from either origin" do
      for origin <- [:property_write, :application_write] do
        stored = initialize(%{reliability: :process_error})
        assert stored.object.status_flags.fault
        {:ok, inhibited} = write(stored, :reliability_evaluation_inhibit, true)
        assert inhibited.object.reliability == :no_fault_detected
        refute inhibited.object.status_flags.fault

        {:ok, reported} =
          write(inhibited, :reliability, :communication_failure, :application_write)

        assert reported.object.reliability == :no_fault_detected
        {:ok, visible} = write(reported, :reliability_evaluation_inhibit, false)
        assert visible.object.reliability == :communication_failure

        {:ok, masked} = write(visible, :reliability_evaluation_inhibit, true)
        {:ok, isolated} = write(masked, :out_of_service, true)
        assert isolated.object.reliability == :no_fault_detected
        {:ok, simulated} = write(isolated, :reliability, :no_sensor, origin)
        assert simulated.object.reliability == :no_sensor
        assert simulated.object.status_flags.fault
        {:ok, resumed} = write(simulated, :out_of_service, false)
        assert resumed.object.reliability == :no_fault_detected
        refute resumed.object.status_flags.fault
      end
    end

    test "reports the signed low limit" do
      stored =
        initialize(
          %{
            high_limit: 3,
            low_limit: -3,
            limit_enable: LimitEnable.from_bitstring({true, false})
          },
          intrinsic_reporting: true
        )

      {:ok, changed} = write(stored, :present_value, -4)
      assert changed.object.present_value == -4

      assert %{
               event_type: :signed_out_of_range,
               to_state: :low_limit,
               event_values: %{exceeding_value: -4}
             } = EventReporting.transition(changed)

      assert changed.next_execution == nil
    end

    test "local instances require matching runtime state and remote snapshots remain passive" do
      stored = initialize(%{present_value: -3})

      assert {:error, :invalid_execution_state} =
               Lifecycle.execute(stored.object, context(nil, :periodic))

      {:ok, another} = IntegerValue.create(11, "Another")

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

      {:ok, remote} = IntegerValue.create(11, "Remote", properties, remote_object: 42)
      ctx = %{context(nil, :periodic) | state: :snapshot}

      assert {:ok, %Result{object: ^remote, state: :snapshot, next_execution: nil}} =
               Lifecycle.execute(remote, ctx)

      assert {:error, :operation_not_available_for_remote_objects} =
               IntegerValue.prepare_write(remote, remote, ctx)
    end

    defp initialize(properties, options \\ []) do
      {:ok, object} = IntegerValue.create(10, "Offset", properties, options)
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
        if property == :present_value and IntegerValue.has_priority_array?(stored.object),
          do: IntegerValue.set_priority(stored.object, priority || 16, value),
          else: IntegerValue.update_property(stored.object, property, value)

      with {:ok, candidate} <- candidate,
           {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
        IntegerValue.execute(prepared, ctx)
      end
    end
  end
end
