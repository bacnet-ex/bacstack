defmodule BACnet.Test.Protocol.ObjectTypes.AnalogOutputTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.LimitEnable
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectTypes.AnalogOutput
  alias BACnet.Protocol.PriorityArray
  alias BACnet.Test.Support.Protocol.ObjectExecutionTestHost, as: Host

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_analog_output

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "create/4 priority array overrides given present value" do
    assert {:ok, %AnalogOutput{present_value: +0.0}} =
             AnalogOutput.create(1, "TEST", %{present_value: 25.0})
  end

  test "verify get_property/2 with present_value respects command prioritization on out of service" do
    {:ok, %AnalogOutput{present_value: 25.0} = obj} =
      AnalogOutput.create(1, "TEST", %{relinquish_default: 25.0})

    assert {:ok, 25.0} = AnalogOutput.get_property(obj, :present_value)

    {:ok, obj} = AnalogOutput.update_property(obj, :out_of_service, true)

    assert {:ok, 25.0} = AnalogOutput.get_property(obj, :present_value)
    assert {:ok, %{present_value: 26.0} = obj} = AnalogOutput.set_priority(obj, 16, 26.0)
    assert {:ok, %{present_value: 6.0} = obj} = AnalogOutput.set_priority(obj, 1, 6.0)

    assert {:ok, %{present_value: 6.0}} =
             AnalogOutput.update_property(obj, :out_of_service, false)
  end

  test "verify update_property/3 for present_value ignores min/max if max not present" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{min_present_value: 50.0})

    assert {:ok, %AnalogOutput{present_value: -51.0}} =
             AnalogOutput.set_priority(obj, 16, -51.0)

    assert {:ok, %AnalogOutput{present_value: -32_767.0}} =
             AnalogOutput.set_priority(obj, 16, -32_767.0)
  end

  test "verify update_property/3 for present_value ignores min/max if min not present" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{max_present_value: 50.0})

    assert {:ok, %AnalogOutput{present_value: 51.0}} =
             AnalogOutput.set_priority(obj, 16, 51.0)

    assert {:ok, %AnalogOutput{present_value: 32_767.0}} =
             AnalogOutput.set_priority(obj, 16, 32_767.0)
  end

  test "verify update_property/3 for present_value working within configured min/max" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0
      })

    assert {:ok, %AnalogOutput{present_value: -20.0}} =
             AnalogOutput.set_priority(obj, 16, -20.0)

    assert {:ok, %AnalogOutput{present_value: 20.0}} =
             AnalogOutput.set_priority(obj, 16, 20.0)

    assert {:ok, %AnalogOutput{present_value: -50.0}} =
             AnalogOutput.set_priority(obj, 16, -50.0)

    assert {:ok, %AnalogOutput{present_value: 50.0}} =
             AnalogOutput.set_priority(obj, 16, 50.0)

    assert {:ok, %AnalogOutput{present_value: -20.0} = obj} =
             AnalogOutput.set_priority(obj, 16, -20.0)

    assert {:ok, %AnalogOutput{present_value: 20.0} = obj} =
             AnalogOutput.set_priority(obj, 16, 20.0)

    assert {:ok, %AnalogOutput{present_value: -50.0} = obj} =
             AnalogOutput.set_priority(obj, 16, -50.0)

    assert {:ok, %AnalogOutput{present_value: 50.0} = obj} =
             AnalogOutput.set_priority(obj, 16, 50.0)

    assert {:ok, %AnalogOutput{present_value: +0.0}} =
             AnalogOutput.set_priority(obj, 16, 0.0)

    assert {:ok, %AnalogOutput{present_value: :NaN}} =
             AnalogOutput.set_priority(obj, 16, :NaN)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, :inf)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, :infn)
  end

  test "verify update_property/3 for present_value working within configured infinite min/max" do
    {:ok, %AnalogOutput{:present_value => +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{
        max_present_value: :inf,
        min_present_value: :infn
      })

    assert {:ok, %AnalogOutput{:present_value => 20.0}} =
             AnalogOutput.set_priority(obj, 16, 20.0)

    assert {:ok, %AnalogOutput{:present_value => -20.0}} =
             AnalogOutput.set_priority(obj, 16, -20.0)

    assert {:ok, %AnalogOutput{:present_value => :inf}} =
             AnalogOutput.set_priority(obj, 16, :inf)

    assert {:ok, %AnalogOutput{:present_value => :infn}} =
             AnalogOutput.set_priority(obj, 16, :infn)

    assert {:ok, %AnalogOutput{:present_value => :NaN}} =
             AnalogOutput.set_priority(obj, 16, :NaN)
  end

  test "verify update_property/3 for present_value fails on value lower than min" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0
      })

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, -51.0)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, -32_767.0)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, :infn)
  end

  test "verify update_property/3 for present_value fails on value higher than max" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0
      })

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, 51.0)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, 32_767.0)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, :inf)
  end

  test "verify update_property/3 for relinquish_default ignores min/max if max not present" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{min_present_value: 50.0})

    assert {:ok, %AnalogOutput{present_value: -51.0}} =
             AnalogOutput.update_property(obj, :relinquish_default, -51.0)

    assert {:ok, %AnalogOutput{present_value: -32_767.0}} =
             AnalogOutput.update_property(obj, :relinquish_default, -32_767.0)
  end

  test "verify update_property/3 for relinquish_default ignores min/max if min not present" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{max_present_value: 50.0})

    assert {:ok, %AnalogOutput{present_value: 51.0}} =
             AnalogOutput.update_property(obj, :relinquish_default, 51.0)

    assert {:ok, %AnalogOutput{present_value: 32_767.0}} =
             AnalogOutput.update_property(obj, :relinquish_default, 32_767.0)
  end

  test "verify update_property/3 for relinquish_default working within configured min/max" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{max_present_value: 50.0, min_present_value: -50.0})

    assert {:ok, %AnalogOutput{present_value: -20.0}} =
             AnalogOutput.update_property(obj, :relinquish_default, -20.0)

    assert {:ok, %AnalogOutput{present_value: 20.0}} =
             AnalogOutput.update_property(obj, :relinquish_default, 20.0)

    assert {:ok, %AnalogOutput{present_value: -50.0}} =
             AnalogOutput.update_property(obj, :relinquish_default, -50.0)

    assert {:ok, %AnalogOutput{present_value: 50.0}} =
             AnalogOutput.update_property(obj, :relinquish_default, 50.0)

    assert {:ok, %AnalogOutput{present_value: -20.0} = obj} =
             AnalogOutput.update_property(obj, :relinquish_default, -20.0)

    assert {:ok, %AnalogOutput{present_value: 20.0} = obj} =
             AnalogOutput.update_property(obj, :relinquish_default, 20.0)

    assert {:ok, %AnalogOutput{present_value: -50.0} = obj} =
             AnalogOutput.update_property(obj, :relinquish_default, -50.0)

    assert {:ok, %AnalogOutput{present_value: 50.0} = obj} =
             AnalogOutput.update_property(obj, :relinquish_default, 50.0)

    assert {:ok, %AnalogOutput{present_value: +0.0}} =
             AnalogOutput.update_property(obj, :relinquish_default, 0.0)

    assert {:ok, %AnalogOutput{present_value: :NaN}} =
             AnalogOutput.update_property(obj, :relinquish_default, :NaN)
  end

  test "verify update_property/3 for relinquish_default working within configured infinite min/max" do
    {:ok, %AnalogOutput{:present_value => +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{
        max_present_value: :inf,
        min_present_value: :infn
      })

    assert {:ok, %AnalogOutput{:present_value => 20.0}} =
             AnalogOutput.update_property(obj, :relinquish_default, 20.0)

    assert {:ok, %AnalogOutput{:present_value => -20.0}} =
             AnalogOutput.update_property(obj, :relinquish_default, -20.0)

    assert {:ok, %AnalogOutput{:present_value => :inf}} =
             AnalogOutput.update_property(obj, :relinquish_default, :inf)

    assert {:ok, %AnalogOutput{:present_value => :infn}} =
             AnalogOutput.update_property(obj, :relinquish_default, :infn)

    assert {:ok, %AnalogOutput{:present_value => :NaN}} =
             AnalogOutput.update_property(obj, :relinquish_default, :NaN)
  end

  test "verify update_property/3 for relinquish_default fails on value lower than min" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{max_present_value: 50.0, min_present_value: -50.0})

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             AnalogOutput.update_property(obj, :relinquish_default, -51.0)

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             AnalogOutput.update_property(obj, :relinquish_default, -32_767.0)

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             AnalogOutput.update_property(obj, :relinquish_default, :infn)
  end

  test "verify update_property/3 for relinquish_default fails on value higher than max" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{max_present_value: 50.0, min_present_value: -50.0})

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             AnalogOutput.update_property(obj, :relinquish_default, 51.0)

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             AnalogOutput.update_property(obj, :relinquish_default, 32_767.0)

    assert {:error, {:value_failed_property_validation, :relinquish_default}} =
             AnalogOutput.update_property(obj, :relinquish_default, :inf)
  end

  test "verify update_property/3 only checks present_value/relinquish_default for min/max" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{max_present_value: 50.0, min_present_value: -50.0})

    assert {:ok, %AnalogOutput{cov_increment: -51.0}} =
             AnalogOutput.update_property(obj, :cov_increment, -51.0)

    assert {:ok, %AnalogOutput{cov_increment: 51.0}} =
             AnalogOutput.update_property(obj, :cov_increment, 51.0)
  end

  test "verify set_priority/3 ignores min/max if max not present" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{min_present_value: 50.0, relinquish_default: +0.0})

    assert {:ok, %AnalogOutput{present_value: -51.0}} = AnalogOutput.set_priority(obj, 16, -51.0)

    assert {:ok, %AnalogOutput{present_value: -32_767.0}} =
             AnalogOutput.set_priority(obj, 16, -32_767.0)
  end

  test "verify set_priority/3 ignores min/max if min not present" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{max_present_value: 50.0, relinquish_default: +0.0})

    assert {:ok, %AnalogOutput{present_value: 51.0}} = AnalogOutput.set_priority(obj, 16, 51.0)

    assert {:ok, %AnalogOutput{present_value: 32_767.0}} =
             AnalogOutput.set_priority(obj, 16, 32_767.0)
  end

  test "verify set_priority/3 working within configured min/max" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0,
        relinquish_default: 0.0
      })

    assert {:ok, %AnalogOutput{present_value: -20.0}} = AnalogOutput.set_priority(obj, 16, -20.0)

    assert {:ok, %AnalogOutput{present_value: 20.0}} = AnalogOutput.set_priority(obj, 16, 20.0)

    assert {:ok, %AnalogOutput{present_value: -50.0}} = AnalogOutput.set_priority(obj, 16, -50.0)

    assert {:ok, %AnalogOutput{present_value: 50.0}} = AnalogOutput.set_priority(obj, 16, 50.0)

    assert {:ok, %AnalogOutput{present_value: -20.0} = obj} =
             AnalogOutput.set_priority(obj, 16, -20.0)

    assert {:ok, %AnalogOutput{present_value: 20.0} = obj} =
             AnalogOutput.set_priority(obj, 16, 20.0)

    assert {:ok, %AnalogOutput{present_value: -50.0} = obj} =
             AnalogOutput.set_priority(obj, 16, -50.0)

    assert {:ok, %AnalogOutput{present_value: 50.0} = obj} =
             AnalogOutput.set_priority(obj, 16, 50.0)

    assert {:ok, %AnalogOutput{present_value: +0.0}} = AnalogOutput.set_priority(obj, 16, 0.0)

    assert {:ok, %AnalogOutput{present_value: :NaN}} = AnalogOutput.set_priority(obj, 16, :NaN)
  end

  test "verify set_priority/3 fails on value lower than min" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0,
        relinquish_default: 0.0
      })

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, -51.0)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, -32_767.0)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, :infn)
  end

  test "verify set_priority/3 fails on value higher than max" do
    {:ok, %AnalogOutput{present_value: +0.0} = obj} =
      AnalogOutput.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0,
        relinquish_default: 0.0
      })

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, 51.0)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, 32_767.0)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogOutput.set_priority(obj, 16, :inf)
  end

  test "verify get_output/2 on out of service" do
    {:ok, %AnalogOutput{present_value: 25.0} = obj} =
      AnalogOutput.create(1, "TEST", %{relinquish_default: 25.0})

    assert 25.0 == AnalogOutput.get_output(obj)
    assert {:ok, 25.0} = AnalogOutput.get_property(obj, :present_value)

    {:ok, obj} = AnalogOutput.update_property(obj, :out_of_service, true)
    assert 0.0 == AnalogOutput.get_output(obj)
    assert 100.0 == AnalogOutput.get_output(obj, 100.0)

    {:ok, obj} = AnalogOutput.update_property(obj, :relinquish_default, 50.0)
    assert {:ok, 50.0} = AnalogOutput.get_property(obj, :present_value)

    assert 0.0 == AnalogOutput.get_output(obj)
    assert 100.0 == AnalogOutput.get_output(obj, 100.0)

    {:ok, obj} = AnalogOutput.update_property(obj, :out_of_service, false)
    assert 50.0 == AnalogOutput.get_output(obj)

    {:ok, obj} = AnalogOutput.update_property(obj, :relinquish_default, 10.0)
    assert {:ok, 10.0} = AnalogOutput.get_property(obj, :present_value)
    assert 10.0 == AnalogOutput.get_output(obj)
  end

  describe "lifecycle" do
    @now ~U[2026-11-08 10:00:00Z]

    test "initialization derives the command and reads require no callbacks or wakeups" do
      stored = initialize(%{relinquish_default: 25.0, units: :percent})
      assert stored.object.present_value == 25.0
      assert is_struct(stored.object.priority_array, PriorityArray)
      assert AnalogOutput.get_output(stored.object) == 25.0
      assert stored.next_execution == nil

      assert {:ok, ^stored} =
               Lifecycle.prepare_read(
                 stored.object,
                 context(stored, {:property_read, :present_value, nil})
               )
    end

    test "competing commands retain masked values and relinquishment reveals the next command" do
      stored = initialize(%{relinquish_default: 10.0})
      {:ok, low} = write(stored, :present_value, 20.0)
      assert low.object.priority_array.priority_16 == 20.0
      {:ok, high} = write(low, :present_value, 30.0, :property_write, 8)
      {:ok, masked} = write(high, :present_value, 40.0, :application_write, 16)
      assert masked.object.present_value == 30.0
      assert masked.object.priority_array.priority_16 == 40.0
      {:ok, revealed} = write(masked, :present_value, nil, :property_write, 8)
      assert revealed.object.present_value == 40.0
      {:ok, fallback} = write(revealed, :present_value, nil)
      assert fallback.object.present_value == 10.0
      {:ok, changed} = write(fallback, :relinquish_default, 15.0)
      assert changed.object.present_value == 15.0
    end

    test "logical application and BACnet commands continue to arbitrate while OOS" do
      stored = initialize(%{out_of_service: true, relinquish_default: 10.0})
      {:ok, local} = write(stored, :present_value, 20.0, :application_write, 8)
      {:ok, network} = write(local, :present_value, 30.0)
      assert network.object.present_value == 20.0
      assert network.object.status_flags.out_of_service
      assert AnalogOutput.get_output(network.object) == 0.0
      assert AnalogOutput.get_output(network.object, 7.0) == 7.0
      {:ok, cleared} = write(network, :present_value, nil, :application_write, 8)
      assert cleared.object.present_value == 30.0
      {:ok, cleared} = write(cleared, :present_value, nil)
      {:ok, changed} = write(cleared, :relinquish_default, 15.0, :application_write)
      assert changed.object.present_value == 15.0
      {:ok, returned} = write(changed, :out_of_service, false)
      assert AnalogOutput.get_output(returned.object) == 15.0
    end

    test "every command priority except six is usable and six cannot be commanded or relinquished" do
      stored = initialize(%{})

      for priority <- [1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16] do
        assert {:ok, commanded} =
                 write(stored, :present_value, priority * 1.0, :application_write, priority)

        assert commanded.object.present_value == priority * 1.0
      end

      for value <- [nil, 20.0] do
        assert {:error, :write_access_denied} = AnalogOutput.set_priority(stored.object, 6, value)
      end

      for source <- [:application_write, :property_write] do
        assert {:error, :write_access_denied} =
                 Lifecycle.prepare_write(
                   stored.object,
                   stored.object,
                   context(stored, {source, :present_value, nil, 6})
                 )
      end
    end

    test "a stored non-nil priority six is rejected before initialization" do
      {:ok, object} =
        AnalogOutput.create(10, "Reserved slot", %{
          priority_array: PriorityArray.from_list([nil, nil, nil, nil, nil, 25.0])
        })

      assert {:error, {:invalid_configuration, :priority_6}} =
               Lifecycle.execute(object, context(nil, :initialization))
    end

    test "range rejection leaves the stored object and reliability unchanged" do
      stored =
        initialize(%{
          min_present_value: 0.0,
          max_present_value: 100.0,
          reliability: :no_fault_detected
        })

      assert {:error, {:value_failed_property_validation, :priority_array}} =
               write(stored, :present_value, 101.0)

      assert stored.object.present_value == 0.0
      assert stored.object.reliability == :no_fault_detected
      refute stored.object.status_flags.fault
    end

    test "OOS reliability simulation accepts both origins including same-value writes" do
      for source <- [:application_write, :property_write],
          value <- [:process_error, :no_fault_detected] do
        stored = initialize(%{out_of_service: true, reliability: :process_error})
        assert {:ok, simulated} = write(stored, :reliability, value, source)
        assert simulated.object.reliability == value
        assert simulated.object.status_flags.fault == (value != :no_fault_detected)
        assert stored.object.reliability == :process_error
      end
    end

    test "explicit local OOS simulation survives inhibition without overwriting hardware status" do
      stored = initialize(%{reliability: :no_output, reliability_evaluation_inhibit: true})
      {:ok, decoupled} = write(stored, :out_of_service, true)
      {:ok, simulated} = write(decoupled, :reliability, :process_error, :application_write)
      assert simulated.object.reliability == :process_error
      assert simulated.object.status_flags.fault

      {:ok, refreshed} =
        Lifecycle.prepare_read(
          simulated.object,
          context(simulated, {:property_read, :reliability, nil})
        )

      assert refreshed.object.reliability == :process_error
      {:ok, returned} = write(refreshed, :out_of_service, false)
      assert returned.object.reliability == :no_fault_detected
      {:ok, restored} = write(returned, :reliability_evaluation_inhibit, false)
      assert restored.object.reliability == :no_output
    end

    test "BACnet reliability simulation is decoupled and known physical reliability returns on resumption" do
      stored = initialize(%{reliability: :no_fault_detected})
      {:ok, physical} = write(stored, :reliability, :no_output, :application_write)
      assert physical.object.status_flags.fault
      {:ok, decoupled} = write(physical, :out_of_service, true)
      {:ok, simulated} = write(decoupled, :reliability, :no_fault_detected)
      refute simulated.object.status_flags.fault
      {:ok, returned} = write(simulated, :out_of_service, false)
      assert returned.object.reliability == :no_output
      assert returned.object.status_flags.fault
    end

    test "inhibition masks physical reports and restores the latest report when disabled" do
      stored = initialize(%{reliability: :no_output})
      {:ok, inhibited} = write(stored, :reliability_evaluation_inhibit, true)
      assert inhibited.object.reliability == :no_fault_detected
      refute inhibited.object.status_flags.fault
      {:ok, reported} = write(inhibited, :reliability, :communication_failure, :application_write)
      assert reported.object.reliability == :no_fault_detected
      {:ok, restored} = write(reported, :reliability_evaluation_inhibit, false)
      assert restored.object.reliability == :communication_failure
    end

    test "inhibited OOS simulation requires an explicit write and is masked on return to service" do
      stored = initialize(%{reliability: :no_output, reliability_evaluation_inhibit: true})
      {:ok, decoupled} = write(stored, :out_of_service, true)
      assert decoupled.object.reliability == :no_fault_detected
      {:ok, simulated} = write(decoupled, :reliability, :process_error)
      assert simulated.object.reliability == :process_error

      assert {:ok, refreshed} =
               Lifecycle.prepare_read(
                 simulated.object,
                 context(simulated, {:property_read, :reliability, nil})
               )

      assert refreshed.object.reliability == :process_error
      {:ok, returned} = write(refreshed, :out_of_service, false)
      assert returned.object.reliability == :no_fault_detected
      {:ok, uninhibited} = write(returned, :reliability_evaluation_inhibit, false)
      assert uninhibited.object.reliability == :no_output
    end

    test "initially OOS reliability remains until a fresh physical status is available" do
      stored = initialize(%{out_of_service: true, reliability: :process_error})
      {:ok, returned} = write(stored, :out_of_service, false)
      assert returned.object.reliability == :process_error
      {:ok, reported} = write(returned, :reliability, :no_fault_detected, :application_write)
      assert reported.object.reliability == :no_fault_detected
    end

    test "restart uses supplied properties and does not recover suppressed hardware reports" do
      stored = initialize(%{reliability: :no_output, reliability_evaluation_inhibit: true})
      ctx = %{context(stored, :initialization) | state: :discard_old_runtime}
      {:ok, restarted} = Lifecycle.execute(stored.object, ctx)
      {:ok, restored} = write(restarted, :reliability_evaluation_inhibit, false)
      assert restored.object.reliability == :no_fault_detected

      simulation =
        initialize(%{
          out_of_service: true,
          reliability: :process_error,
          reliability_evaluation_inhibit: true
        })

      assert simulation.object.reliability == :process_error
    end

    test "removing reliability clears fault and adding it again uses the new report" do
      stored = initialize(%{reliability: :no_output})
      {:ok, object} = AnalogOutput.remove_property(stored.object, :reliability)

      {:ok, removed} =
        Lifecycle.execute(object, context(stored, {:application_write, :reliability, nil, nil}))

      refute removed.object.status_flags.fault
      {:ok, object} = AnalogOutput.add_property(removed.object, :reliability, :process_error)

      {:ok, added} =
        Lifecycle.execute(object, context(removed, {:application_write, :reliability, nil, nil}))

      assert added.object.reliability == :process_error
      assert added.object.status_flags.fault
    end

    test "existing REAL alternatives and numeric reliability constants remain supported" do
      stored = initialize(%{reliability: 999}, allow_numeric_constants: true)

      for value <- [25.0, :NaN, :inf, :infn] do
        {:ok, changed} = write(stored, :present_value, value)
        assert AnalogOutput.get_output(changed.object) == value
        assert {:ok, repeated} = Lifecycle.execute(changed.object, context(changed, :periodic))
        assert repeated.object.reliability == 999
      end
    end

    test "clock changes do not invent elapsed-time calculations or wakeups" do
      stored = initialize(%{relinquish_default: 25.0})

      ctx = %{
        context(stored, :clock_change)
        | now: ~U[2020-01-01 00:00:00Z],
          monotonic_time: -999_999
      }

      assert {:ok, ^stored} = Lifecycle.execute(stored.object, ctx)
    end

    test "invalid and other-instance state is rejected without a replacement result" do
      {:ok, object} = AnalogOutput.create(10, "State")

      for state <- [nil, :bad_state, %{}] do
        ctx = %{context(nil, :periodic) | state: state}
        assert {:error, :invalid_execution_state} = Lifecycle.execute(object, ctx)
      end

      stored = initialize(%{})
      {:ok, different} = AnalogOutput.create(11, "Other")

      assert {:error, :invalid_execution_state} =
               Lifecycle.execute(different, context(stored, :periodic))
    end

    test "reports high-limit commands and changes in output reliability" do
      stored =
        initialize(
          %{
            high_limit: 1.0,
            reliability: :no_fault_detected,
            limit_enable: LimitEnable.from_bitstring({false, true})
          },
          intrinsic_reporting: true
        )

      {:ok, commanded} = write(stored, :present_value, 100.0)

      assert %{event_type: :out_of_range, to_state: :high_limit} =
               EventReporting.transition(commanded)

      {:ok, faulty} = write(commanded, :reliability, :no_output, :application_write)
      assert faulty.object.present_value == 100.0
      assert faulty.object.status_flags.fault

      assert %{event_type: :change_of_reliability, from_state: :high_limit, to_state: :fault} =
               EventReporting.transition(faulty)

      assert faulty.next_execution == nil
    end

    test "remote snapshots preserve supplied object and state and reject local preparation" do
      {:ok, local} = AnalogOutput.create(10, "Snapshot", %{relinquish_default: 99.0})

      properties =
        Map.take(local, [
          :present_value,
          :priority_array,
          :relinquish_default,
          :units,
          :out_of_service,
          :event_state,
          :status_flags
        ])

      {:ok, object} = AnalogOutput.create(10, "Snapshot", properties, remote_object: 42)
      ctx = %{context(nil, :periodic) | state: :remote_state}
      expected = %Result{object: object, state: :remote_state, next_execution: nil}
      assert {:ok, ^expected} = Lifecycle.execute(object, ctx)
      assert {:ok, ^expected} = AnalogOutput.execute(object, ctx)
      assert :ok = AnalogOutput.validate_execution(object, ctx)

      assert {:error, :operation_not_available_for_remote_objects} =
               AnalogOutput.prepare_write(object, object, ctx)
    end

    test "a host decodes, prepares and retains commands and NULL relinquishment" do
      {:ok, object} = AnalogOutput.create(10, "Host output", %{relinquish_default: 5.0})
      host = Host.new([{object, []}], @now, 0)
      id = AnalogOutput.get_object_identifier(object)
      assert :ok = Host.execute(host, id, :initialization)

      reference = %DeviceObjectPropertyRef{
        device_identifier: nil,
        object_identifier: id,
        property_identifier: :present_value,
        property_array_index: nil
      }

      assert :ok = Host.write(host, reference, Encoding.create!({:real, 25.0}), 8)
      assert AnalogOutput.get_output(Host.snapshot(host, id).object) == 25.0
      assert :ok = Host.write(host, reference, Encoding.create!({:null, nil}), 8)
      assert Host.snapshot(host, id).object.present_value == 5.0
      assert Host.snapshot(host, id).next_execution == nil
    end

    defp initialize(properties, options \\ []) do
      {:ok, object} = AnalogOutput.create(10, "Output", properties, options)
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
        read_property: fn _reference -> flunk("unexpected read") end,
        read_property_multiple: fn _reference, _properties ->
          flunk("unexpected multiple read")
        end,
        write_property: fn _reference, _value, _priority -> flunk("unexpected write") end
      )
    end

    defp write(stored, property, value, source \\ :property_write, priority \\ nil) do
      ctx = context(stored, {source, property, nil, priority})

      candidate =
        if property == :present_value,
          do: AnalogOutput.set_priority(stored.object, priority || 16, value),
          else: AnalogOutput.update_property(stored.object, property, value)

      with {:ok, candidate} <- candidate,
           {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
        AnalogOutput.execute(prepared, ctx)
      end
    end
  end
end
