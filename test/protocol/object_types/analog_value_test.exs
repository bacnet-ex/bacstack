defmodule BACnet.Test.Protocol.ObjectTypes.AnalogValueTest do
  alias BACnet.Protocol.LimitEnable
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectTypes.AnalogValue
  alias BACnet.Protocol.PriorityArray

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_analog_value

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "create/4 priority array overrides given present value" do
    assert {:ok, %AnalogValue{present_value: 1.0}} =
             AnalogValue.create(1, "TEST", %{present_value: 25.0, relinquish_default: 1.0})
  end

  test "add_property/3 priority array overrides given present value" do
    {:ok, %AnalogValue{present_value: 25.0} = obj} =
      AnalogValue.create(1, "TEST", %{present_value: 25.0})

    assert {:ok, %AnalogValue{present_value: 1.0}} =
             AnalogValue.add_property(obj, :relinquish_default, 1.0)
  end

  for property <- [:present_value, :relinquish_default] do
    test "verify update_property/3 for #{property} ignores min/max if max not present" do
      {:ok, %AnalogValue{unquote(property) => +0.0} = obj} =
        AnalogValue.create(1, "TEST", %{unquote(property) => 0.0, min_present_value: 50.0})

      assert {:ok, %AnalogValue{unquote(property) => -51.0}} =
               AnalogValue.update_property(obj, unquote(property), -51.0)

      assert {:ok, %AnalogValue{unquote(property) => -32_767.0}} =
               AnalogValue.update_property(obj, unquote(property), -32_767.0)
    end

    test "verify update_property/3 for #{property} ignores min/max if min not present" do
      {:ok, %AnalogValue{unquote(property) => +0.0} = obj} =
        AnalogValue.create(1, "TEST", %{unquote(property) => 0.0, max_present_value: 50.0})

      assert {:ok, %AnalogValue{unquote(property) => 51.0}} =
               AnalogValue.update_property(obj, unquote(property), 51.0)

      assert {:ok, %AnalogValue{unquote(property) => 32_767.0}} =
               AnalogValue.update_property(obj, unquote(property), 32_767.0)
    end

    test "verify update_property/3 for #{property} working within configured min/max" do
      {:ok, %AnalogValue{unquote(property) => +0.0} = obj} =
        AnalogValue.create(1, "TEST", %{
          unquote(property) => 0.0,
          max_present_value: 50.0,
          min_present_value: -50.0
        })

      assert {:ok, %AnalogValue{unquote(property) => -20.0}} =
               AnalogValue.update_property(obj, unquote(property), -20.0)

      assert {:ok, %AnalogValue{unquote(property) => 20.0}} =
               AnalogValue.update_property(obj, unquote(property), 20.0)

      assert {:ok, %AnalogValue{unquote(property) => -50.0}} =
               AnalogValue.update_property(obj, unquote(property), -50.0)

      assert {:ok, %AnalogValue{unquote(property) => 50.0}} =
               AnalogValue.update_property(obj, unquote(property), 50.0)

      assert {:ok, %AnalogValue{unquote(property) => -20.0} = obj} =
               AnalogValue.update_property(obj, unquote(property), -20.0)

      assert {:ok, %AnalogValue{unquote(property) => 20.0} = obj} =
               AnalogValue.update_property(obj, unquote(property), 20.0)

      assert {:ok, %AnalogValue{unquote(property) => -50.0} = obj} =
               AnalogValue.update_property(obj, unquote(property), -50.0)

      assert {:ok, %AnalogValue{unquote(property) => 50.0} = obj} =
               AnalogValue.update_property(obj, unquote(property), 50.0)

      assert {:ok, %AnalogValue{unquote(property) => +0.0}} =
               AnalogValue.update_property(obj, unquote(property), 0.0)

      assert {:ok, %AnalogValue{unquote(property) => :NaN}} =
               AnalogValue.update_property(obj, unquote(property), :NaN)

      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               AnalogValue.update_property(obj, unquote(property), :inf)

      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               AnalogValue.update_property(obj, unquote(property), :infn)
    end

    test "verify update_property/3 for #{property} working within configured infinite min/max" do
      {:ok, %AnalogValue{unquote(property) => +0.0} = obj} =
        AnalogValue.create(1, "TEST", %{
          unquote(property) => 0.0,
          max_present_value: :inf,
          min_present_value: :infn
        })

      assert {:ok, %AnalogValue{unquote(property) => 20.0}} =
               AnalogValue.update_property(obj, unquote(property), 20.0)

      assert {:ok, %AnalogValue{unquote(property) => -20.0}} =
               AnalogValue.update_property(obj, unquote(property), -20.0)

      assert {:ok, %AnalogValue{unquote(property) => :inf}} =
               AnalogValue.update_property(obj, unquote(property), :inf)

      assert {:ok, %AnalogValue{unquote(property) => :infn}} =
               AnalogValue.update_property(obj, unquote(property), :infn)

      assert {:ok, %AnalogValue{unquote(property) => :NaN}} =
               AnalogValue.update_property(obj, unquote(property), :NaN)
    end

    test "verify update_property/3 for #{property} fails on value lower than min" do
      {:ok, %AnalogValue{unquote(property) => +0.0} = obj} =
        AnalogValue.create(1, "TEST", %{
          unquote(property) => 0.0,
          max_present_value: 50.0,
          min_present_value: -50.0
        })

      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               AnalogValue.update_property(obj, unquote(property), -51.0)

      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               AnalogValue.update_property(obj, unquote(property), -32_767.0)

      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               AnalogValue.update_property(obj, unquote(property), :infn)
    end

    test "verify update_property/3 for #{property} fails on value higher than max" do
      {:ok, %AnalogValue{unquote(property) => +0.0} = obj} =
        AnalogValue.create(1, "TEST", %{
          unquote(property) => 0.0,
          max_present_value: 50.0,
          min_present_value: -50.0
        })

      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               AnalogValue.update_property(obj, unquote(property), 51.0)

      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               AnalogValue.update_property(obj, unquote(property), 32_767.0)

      assert {:error, {:value_failed_property_validation, unquote(property)}} =
               AnalogValue.update_property(obj, unquote(property), :inf)
    end
  end

  test "verify update_property/3 only checks present_value for min/max" do
    {:ok, %AnalogValue{present_value: +0.0} = obj} =
      AnalogValue.create(1, "TEST", %{max_present_value: 50.0, min_present_value: -50.0})

    assert {:ok, %AnalogValue{cov_increment: -51.0}} =
             AnalogValue.update_property(obj, :cov_increment, -51.0)

    assert {:ok, %AnalogValue{cov_increment: 51.0}} =
             AnalogValue.update_property(obj, :cov_increment, 51.0)
  end

  test "verify set_priority/3 ignores min/max if max not present" do
    {:ok, %AnalogValue{present_value: +0.0} = obj} =
      AnalogValue.create(1, "TEST", %{min_present_value: 50.0, relinquish_default: +0.0})

    assert {:ok, %AnalogValue{present_value: -51.0}} = AnalogValue.set_priority(obj, 16, -51.0)

    assert {:ok, %AnalogValue{present_value: -32_767.0}} =
             AnalogValue.set_priority(obj, 16, -32_767.0)
  end

  test "verify set_priority/3 ignores min/max if min not present" do
    {:ok, %AnalogValue{present_value: +0.0} = obj} =
      AnalogValue.create(1, "TEST", %{max_present_value: 50.0, relinquish_default: +0.0})

    assert {:ok, %AnalogValue{present_value: 51.0}} = AnalogValue.set_priority(obj, 16, 51.0)

    assert {:ok, %AnalogValue{present_value: 32_767.0}} =
             AnalogValue.set_priority(obj, 16, 32_767.0)
  end

  test "verify set_priority/3 working within configured min/max" do
    {:ok, %AnalogValue{present_value: +0.0} = obj} =
      AnalogValue.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0,
        relinquish_default: 0.0
      })

    assert {:ok, %AnalogValue{present_value: -20.0}} = AnalogValue.set_priority(obj, 16, -20.0)

    assert {:ok, %AnalogValue{present_value: 20.0}} = AnalogValue.set_priority(obj, 16, 20.0)

    assert {:ok, %AnalogValue{present_value: -50.0}} = AnalogValue.set_priority(obj, 16, -50.0)

    assert {:ok, %AnalogValue{present_value: 50.0}} = AnalogValue.set_priority(obj, 16, 50.0)

    assert {:ok, %AnalogValue{present_value: -20.0} = obj} =
             AnalogValue.set_priority(obj, 16, -20.0)

    assert {:ok, %AnalogValue{present_value: 20.0} = obj} =
             AnalogValue.set_priority(obj, 16, 20.0)

    assert {:ok, %AnalogValue{present_value: -50.0} = obj} =
             AnalogValue.set_priority(obj, 16, -50.0)

    assert {:ok, %AnalogValue{present_value: 50.0} = obj} =
             AnalogValue.set_priority(obj, 16, 50.0)

    assert {:ok, %AnalogValue{present_value: +0.0}} = AnalogValue.set_priority(obj, 16, 0.0)

    assert {:ok, %AnalogValue{present_value: :NaN}} = AnalogValue.set_priority(obj, 16, :NaN)
  end

  test "verify set_priority/3 fails on value lower than min" do
    {:ok, %AnalogValue{present_value: +0.0} = obj} =
      AnalogValue.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0,
        relinquish_default: 0.0
      })

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogValue.set_priority(obj, 16, -51.0)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogValue.set_priority(obj, 16, -32_767.0)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogValue.set_priority(obj, 16, :infn)
  end

  test "verify set_priority/3 fails on value higher than max" do
    {:ok, %AnalogValue{present_value: +0.0} = obj} =
      AnalogValue.create(1, "TEST", %{
        max_present_value: 50.0,
        min_present_value: -50.0,
        relinquish_default: 0.0
      })

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogValue.set_priority(obj, 16, 51.0)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogValue.set_priority(obj, 16, 32_767.0)

    assert {:error, {:value_failed_property_validation, :priority_array}} =
             AnalogValue.set_priority(obj, 16, :inf)
  end

  describe "lifecycle" do
    @now ~U[2026-11-08 10:00:00Z]

    test "initialization and reads retain a plain value without callbacks or wakeups" do
      stored = initialize(%{present_value: 21.5, units: :degrees_celsius})
      assert stored.object.present_value == 21.5
      assert stored.next_execution == nil
      refute AnalogValue.has_priority_array?(stored.object)

      assert {:ok, refreshed} =
               Lifecycle.prepare_read(
                 stored.object,
                 context(stored, {:property_read, :present_value, nil})
               )

      assert {:ok, 21.5} = AnalogValue.get_property(refreshed.object, :present_value)
      assert refreshed == stored
    end

    test "local and BACnet writes work in service and non-commandable priorities are ignored" do
      stored = initialize(%{})
      {:ok, local} = write(stored, :present_value, 22.0, :application_write)
      {:ok, network} = write(local, :present_value, 23.0, :property_write, 6)
      assert network.object.present_value == 23.0
      refute AnalogValue.has_priority_array?(network.object)
    end

    test "OOS rejects local value writes including same-value writes but allows BACnet simulation" do
      stored = initialize(%{present_value: 10.0, out_of_service: true})

      for value <- [10.0, 20.0] do
        assert {:error, :out_of_service} =
                 write(stored, :present_value, value, :application_write)
      end

      {:ok, simulated} = write(stored, :present_value, 20.0)
      assert simulated.object.present_value == 20.0
      assert simulated.object.status_flags.out_of_service
      assert stored.object.present_value == 10.0
      {:ok, returned} = write(simulated, :out_of_service, false)
      {:ok, resumed} = write(returned, :present_value, 30.0, :application_write)
      assert resumed.object.present_value == 30.0
    end

    test "enabling OOS cannot be bundled with a local present value change" do
      stored = initialize(%{present_value: 10.0})
      {:ok, candidate} = AnalogValue.update_property(stored.object, :out_of_service, true)
      {:ok, candidate} = AnalogValue.update_property(candidate, :present_value, 20.0)

      assert {:error, :out_of_service} =
               Lifecycle.prepare_write(
                 stored.object,
                 candidate,
                 context(stored, {:application_write, :out_of_service, nil, nil})
               )
    end

    test "commandability chooses the highest priority and falls back after NULL relinquishment" do
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
      {:ok, changed} = write(fallback, :relinquish_default, 12.0)
      assert changed.object.present_value == 12.0
      assert changed.next_execution == nil
    end

    test "all command priorities except six are usable and six cannot be commanded or relinquished" do
      stored = initialize(%{relinquish_default: 10.0})

      for priority <- [1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16] do
        assert {:ok, commanded} =
                 write(stored, :present_value, priority * 1.0, :property_write, priority)

        assert commanded.object.present_value == priority * 1.0
      end

      for value <- [nil, 20.0] do
        assert {:error, :write_access_denied} = AnalogValue.set_priority(stored.object, 6, value)
      end

      assert {:error, :write_access_denied} =
               Lifecycle.prepare_write(
                 stored.object,
                 stored.object,
                 context(stored, {:property_write, :present_value, nil, 6})
               )
    end

    test "stored priority six is rejected during initialization" do
      {:ok, object} =
        AnalogValue.create(10, "Invalid reservation", %{
          priority_array: PriorityArray.from_list([nil, nil, nil, nil, nil, 25.0])
        })

      assert {:error, {:invalid_configuration, :priority_6}} =
               Lifecycle.execute(object, context(nil, :initialization))
    end

    test "commandable OOS simulation still arbitrates and local commands are blocked" do
      stored = initialize(%{relinquish_default: 10.0, out_of_service: true})

      assert {:error, :out_of_service} =
               write(stored, :present_value, 20.0, :application_write, 8)

      {:ok, high} = write(stored, :present_value, 30.0, :property_write, 8)
      {:ok, low} = write(high, :present_value, 40.0)
      assert low.object.present_value == 30.0
      {:ok, fallback} = write(low, :relinquish_default, 15.0)
      assert fallback.object.present_value == 30.0
      {:ok, cleared} = write(fallback, :present_value, nil, :property_write, 8)
      {:ok, cleared} = write(cleared, :present_value, nil)
      assert cleared.object.present_value == 15.0
    end

    test "indirect local value changes through relinquish default are rejected while OOS" do
      stored = initialize(%{relinquish_default: 10.0, out_of_service: true})

      assert {:error, :out_of_service} =
               write(stored, :relinquish_default, 20.0, :application_write)

      assert stored.object.relinquish_default == 10.0
    end

    test "commandability may be added and removed between lifecycle operations" do
      stored = initialize(%{present_value: 25.0})
      {:ok, commandable} = AnalogValue.add_property(stored.object, :relinquish_default, 10.0)
      ctx = context(stored, {:application_write, :relinquish_default, nil, nil})
      {:ok, candidate} = Lifecycle.prepare_write(stored.object, commandable, ctx)
      {:ok, commandable} = Lifecycle.execute(candidate, ctx)
      assert commandable.object.present_value == 10.0
      {:ok, plain} = AnalogValue.remove_property(commandable.object, :priority_array)
      ctx = context(commandable, {:application_write, :priority_array, nil, nil})
      {:ok, plain} = Lifecycle.prepare_write(commandable.object, plain, ctx)
      {:ok, plain} = Lifecycle.execute(plain, ctx)
      refute AnalogValue.has_priority_array?(plain.object)
      {:ok, plain} = write(plain, :present_value, 35.0, :application_write)
      assert plain.object.present_value == 35.0
    end

    test "range checks keep rejected local and priority writes from changing stored state" do
      stored =
        initialize(%{relinquish_default: 10.0, min_present_value: 0.0, max_present_value: 100.0})

      assert {:error, {:value_failed_property_validation, :priority_array}} =
               write(stored, :present_value, 101.0)

      assert stored.object.present_value == 10.0
      assert stored.object.reliability == nil
      assert stored.next_execution == nil
    end

    test "supplied reliability drives fault status and inhibition retains the last report" do
      stored = initialize(%{reliability: :process_error})
      assert stored.object.status_flags.fault
      {:ok, inhibited} = write(stored, :reliability_evaluation_inhibit, true)
      assert inhibited.object.reliability == :no_fault_detected
      refute inhibited.object.status_flags.fault
      {:ok, reported} = write(inhibited, :reliability, :communication_failure, :application_write)
      assert reported.object.reliability == :no_fault_detected
      {:ok, restored} = write(reported, :reliability_evaluation_inhibit, false)
      assert restored.object.reliability == :communication_failure
      assert restored.object.status_flags.fault
    end

    test "inhibited OOS reliability requires an explicit alternate write and is masked on return" do
      stored = initialize(%{reliability: :process_error, reliability_evaluation_inhibit: true})
      {:ok, decoupled} = write(stored, :out_of_service, true)
      assert decoupled.object.reliability == :no_fault_detected
      {:ok, simulated} = write(decoupled, :reliability, :no_sensor, :application_write)
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
      {:ok, uninhibited} = write(returned, :reliability_evaluation_inhibit, false)
      assert uninhibited.object.reliability == :no_sensor
    end

    test "runtime state accepts the existing REAL alternatives and numeric constant option" do
      stored = initialize(%{reliability: 999}, allow_numeric_constants: true)
      assert stored.object.reliability == 999

      for value <- [22.0, :NaN, :inf, :infn] do
        {:ok, changed} = write(stored, :present_value, value, :application_write)
        assert changed.object.present_value == value
        assert {:ok, unchanged} = Lifecycle.execute(changed.object, context(changed, :periodic))
        assert unchanged.object.reliability == 999
      end
    end

    test "clock corrections do not invent timing work for a stored software value" do
      stored = initialize(%{present_value: 21.5})

      ctx = %{
        context(stored, :clock_change)
        | now: ~U[2020-01-01 00:00:00Z],
          monotonic_time: -999_999
      }

      assert {:ok, ^stored} = Lifecycle.execute(stored.object, ctx)
    end

    test "initialization preserves OOS supplied reliability and restarts from supplied properties" do
      stored =
        initialize(%{
          out_of_service: true,
          reliability: :process_error,
          reliability_evaluation_inhibit: true
        })

      assert stored.object.reliability == :process_error
      restarted = %{context(stored, :initialization) | state: :discard_old_runtime}
      assert {:ok, result} = Lifecycle.execute(stored.object, restarted)
      assert result.object.reliability == :process_error
      assert result.next_execution == nil
    end

    test "reliability groups may be added, removed and added again" do
      stored = initialize(%{})
      {:ok, object} = AnalogValue.add_property(stored.object, :reliability, :process_error)

      {:ok, reported} =
        Lifecycle.execute(object, context(stored, {:application_write, :reliability, nil, nil}))

      assert reported.object.status_flags.fault
      {:ok, object} = AnalogValue.remove_property(reported.object, :reliability)

      {:ok, removed} =
        Lifecycle.execute(object, context(reported, {:application_write, :reliability, nil, nil}))

      refute removed.object.status_flags.fault
      {:ok, object} = AnalogValue.add_property(removed.object, :reliability, :no_fault_detected)

      {:ok, added} =
        Lifecycle.execute(object, context(removed, {:application_write, :reliability, nil, nil}))

      assert added.object.reliability == :no_fault_detected
      refute added.object.status_flags.fault
    end

    test "reports a high limit without restricting commands" do
      stored =
        initialize(
          %{
            relinquish_default: 0.0,
            high_limit: 1.0,
            limit_enable: LimitEnable.from_bitstring({false, true})
          },
          intrinsic_reporting: true
        )

      {:ok, changed} = write(stored, :present_value, 100.0)
      assert changed.object.present_value == 100.0

      assert %{
               event_type: :out_of_range,
               to_state: :high_limit,
               event_values: %{exceeding_value: 100.0}
             } =
               EventReporting.transition(changed)

      assert changed.next_execution == nil
    end

    test "uninitialized, malformed and other-instance state is rejected without replacement" do
      {:ok, object} = AnalogValue.create(10, "State")

      for state <- [nil, :bad_state, %{}] do
        assert {:error, :invalid_execution_state} =
                 Lifecycle.execute(object, %{context(nil, :periodic) | state: state})
      end

      other = initialize(%{})
      {:ok, different} = AnalogValue.create(11, "Other")

      assert {:error, :invalid_execution_state} =
               Lifecycle.execute(different, context(other, :periodic))
    end

    test "remote snapshots remain passive and direct write preparation is unavailable" do
      {:ok, local} = AnalogValue.create(10, "Snapshot", %{present_value: 99.0})

      properties =
        Map.take(local, [:present_value, :units, :out_of_service, :event_state, :status_flags])

      {:ok, object} = AnalogValue.create(10, "Snapshot", properties, remote_object: 42)
      ctx = %{context(nil, :periodic) | state: :opaque_remote_state}

      assert {:ok, %Result{object: ^object, state: :opaque_remote_state, next_execution: nil}} =
               Lifecycle.execute(object, ctx)

      assert {:ok, %Result{object: ^object, state: :opaque_remote_state, next_execution: nil}} =
               AnalogValue.execute(object, ctx)

      assert :ok = AnalogValue.validate_execution(object, ctx)

      assert {:error, :operation_not_available_for_remote_objects} =
               AnalogValue.prepare_write(object, object, ctx)
    end

    test "OOS reliability simulation is available from both origins with optional commandability" do
      for capabilities <- [%{}, %{relinquish_default: 0.0}],
          source <- [:application_write, :property_write] do
        stored =
          initialize(
            Map.merge(capabilities, %{out_of_service: true, reliability: :no_fault_detected})
          )

        assert {:ok, simulated} = write(stored, :reliability, :process_error, source)
        assert simulated.object.reliability == :process_error
        assert simulated.object.status_flags.fault
        assert simulated.object.present_value == 0.0
      end
    end

    test "numeric Reliability writes are retained through the lifecycle and direct execution" do
      stored = initialize(%{reliability: :no_fault_detected})
      {:ok, candidate} = AnalogValue.update_property(stored.object, :reliability, :process_error)
      context = context(stored, {:property_write, 103, nil, nil})

      assert {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, context)

      assert {:ok, %{object: %{reliability: :process_error}}} =
               Lifecycle.execute(prepared, context)

      assert {:ok, %{object: %{reliability: :process_error}}} =
               AnalogValue.execute(prepared, context)
    end

    defp initialize(properties, options \\ []) do
      {:ok, object} = AnalogValue.create(10, "Value", properties, options)
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
        if property == :present_value and AnalogValue.has_priority_array?(stored.object),
          do: AnalogValue.set_priority(stored.object, priority || 16, value),
          else: AnalogValue.update_property(stored.object, property, value)

      with {:ok, candidate} <- candidate,
           {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
        AnalogValue.execute(prepared, ctx)
      end
    end
  end
end
