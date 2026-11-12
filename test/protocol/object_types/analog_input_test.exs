defmodule BACnet.Test.Protocol.ObjectTypes.AnalogInputTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.LimitEnable
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectTypes.AnalogInput
  alias BACnet.Protocol.ObjectTypes.AnalogOutput
  alias BACnet.Protocol.Services.Ack.ReadPropertyAck
  alias BACnet.Test.Support.Protocol.ObjectExecutionTestHost, as: Host

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_analog_input

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "verify update_property/3 for present_value ignores min/max if max not present" do
    {:ok, %AnalogInput{present_value: +0.0} = obj} =
      AnalogInput.create(1, "TEST", %{min_present_value: 50.0})

    assert {:ok, %AnalogInput{present_value: -51.0}} =
             AnalogInput.update_property(obj, :present_value, -51.0)

    assert {:ok, %AnalogInput{present_value: -32_767.0}} =
             AnalogInput.update_property(obj, :present_value, -32_767.0)
  end

  test "verify update_property/3 for present_value ignores min/max if min not present" do
    {:ok, %AnalogInput{present_value: +0.0} = obj} =
      AnalogInput.create(1, "TEST", %{max_present_value: 50.0})

    assert {:ok, %AnalogInput{present_value: 51.0}} =
             AnalogInput.update_property(obj, :present_value, 51.0)

    assert {:ok, %AnalogInput{present_value: 32_767.0}} =
             AnalogInput.update_property(obj, :present_value, 32_767.0)
  end

  test "verify update_property/3 for present_value working within configured min/max" do
    {:ok, %AnalogInput{present_value: +0.0} = obj} =
      AnalogInput.create(1, "TEST", %{max_present_value: 50.0, min_present_value: -50.0})

    assert {:ok, %AnalogInput{present_value: -20.0}} =
             AnalogInput.update_property(obj, :present_value, -20.0)

    assert {:ok, %AnalogInput{present_value: 20.0}} =
             AnalogInput.update_property(obj, :present_value, 20.0)

    assert {:ok, %AnalogInput{present_value: -50.0}} =
             AnalogInput.update_property(obj, :present_value, -50.0)

    assert {:ok, %AnalogInput{present_value: 50.0}} =
             AnalogInput.update_property(obj, :present_value, 50.0)

    assert {:ok, %AnalogInput{present_value: -20.0} = obj} =
             AnalogInput.update_property(obj, :present_value, -20.0)

    assert {:ok, %AnalogInput{present_value: 20.0} = obj} =
             AnalogInput.update_property(obj, :present_value, 20.0)

    assert {:ok, %AnalogInput{present_value: -50.0} = obj} =
             AnalogInput.update_property(obj, :present_value, -50.0)

    assert {:ok, %AnalogInput{present_value: 50.0} = obj} =
             AnalogInput.update_property(obj, :present_value, 50.0)

    assert {:ok, %AnalogInput{present_value: +0.0}} =
             AnalogInput.update_property(obj, :present_value, 0.0)

    assert {:ok, %AnalogInput{present_value: :NaN}} =
             AnalogInput.update_property(obj, :present_value, :NaN)

    assert {:error, {:value_failed_property_validation, :present_value}} =
             AnalogInput.update_property(obj, :present_value, :inf)

    assert {:error, {:value_failed_property_validation, :present_value}} =
             AnalogInput.update_property(obj, :present_value, :infn)
  end

  test "verify update_property/3 for present_value working within configured infinite min/max" do
    {:ok, %AnalogInput{:present_value => +0.0} = obj} =
      AnalogInput.create(1, "TEST", %{
        :present_value => 0.0,
        max_present_value: :inf,
        min_present_value: :infn
      })

    assert {:ok, %AnalogInput{:present_value => 20.0}} =
             AnalogInput.update_property(obj, :present_value, 20.0)

    assert {:ok, %AnalogInput{:present_value => -20.0}} =
             AnalogInput.update_property(obj, :present_value, -20.0)

    assert {:ok, %AnalogInput{:present_value => :inf}} =
             AnalogInput.update_property(obj, :present_value, :inf)

    assert {:ok, %AnalogInput{:present_value => :infn}} =
             AnalogInput.update_property(obj, :present_value, :infn)

    assert {:ok, %AnalogInput{:present_value => :NaN}} =
             AnalogInput.update_property(obj, :present_value, :NaN)
  end

  test "verify update_property/3 for present_value fails on value lower than min" do
    {:ok, %AnalogInput{present_value: +0.0} = obj} =
      AnalogInput.create(1, "TEST", %{max_present_value: 50.0, min_present_value: -50.0})

    assert {:error, {:value_failed_property_validation, :present_value}} =
             AnalogInput.update_property(obj, :present_value, -51.0)

    assert {:error, {:value_failed_property_validation, :present_value}} =
             AnalogInput.update_property(obj, :present_value, -32_767.0)

    assert {:error, {:value_failed_property_validation, :present_value}} =
             AnalogInput.update_property(obj, :present_value, :infn)
  end

  test "verify update_property/3 for present_value fails on value higher than max" do
    {:ok, %AnalogInput{present_value: +0.0} = obj} =
      AnalogInput.create(1, "TEST", %{max_present_value: 50.0, min_present_value: -50.0})

    assert {:error, {:value_failed_property_validation, :present_value}} =
             AnalogInput.update_property(obj, :present_value, 51.0)

    assert {:error, {:value_failed_property_validation, :present_value}} =
             AnalogInput.update_property(obj, :present_value, 32_767.0)

    assert {:error, {:value_failed_property_validation, :present_value}} =
             AnalogInput.update_property(obj, :present_value, :inf)
  end

  test "verify update_property/3 only checks present_value for min/max" do
    {:ok, %AnalogInput{present_value: +0.0} = obj} =
      AnalogInput.create(1, "TEST", %{max_present_value: 50.0, min_present_value: -50.0})

    assert {:ok, %AnalogInput{cov_increment: -51.0}} =
             AnalogInput.update_property(obj, :cov_increment, -51.0)

    assert {:ok, %AnalogInput{cov_increment: 51.0}} =
             AnalogInput.update_property(obj, :cov_increment, 51.0)
  end

  describe "lifecycle" do
    @now ~U[2026-11-08 10:00:00Z]

    test "initialization preserves supplied readings without polling or wakeups" do
      stored = initialize(%{present_value: 21.5, units: :degrees_celsius, update_interval: 100})
      assert stored.object.present_value == 21.5
      assert stored.object.update_interval == 100
      assert stored.next_execution == nil

      assert {:ok, ^stored} =
               Lifecycle.prepare_read(
                 stored.object,
                 context(stored, {:property_read, :present_value, nil})
               )
    end

    test "application readings update while in service without command priority semantics" do
      stored = initialize(%{present_value: 21.5})
      {:ok, changed} = write(stored, :present_value, 22.0, :application_write, 6)
      assert changed.object.present_value == 22.0
      assert {:ok, 22.0} = AnalogInput.get_property(changed.object, :present_value)
      refute AnalogInput.property_writable?(changed.object, :present_value)
      refute Map.has_key?(changed.object, :priority_array)
    end

    test "BACnet present value writes require OOS including same values and numeric identifiers" do
      stored = initialize(%{present_value: 21.5})

      for value <- [21.5, 22.0], property <- [:present_value, 85] do
        {:ok, candidate} = AnalogInput.update_property(stored.object, :present_value, value)
        ctx = context(stored, {:property_write, property, nil, nil})

        assert {:error, :write_access_denied} =
                 Lifecycle.prepare_write(stored.object, candidate, ctx)

        assert {:error, :write_access_denied} = Lifecycle.execute(candidate, ctx)
      end

      assert stored.object.present_value == 21.5
    end

    test "network access checks the original and final OOS state before preparation" do
      stored = initialize(%{present_value: 21.5})
      {:ok, candidate} = AnalogInput.update_property(stored.object, :out_of_service, true)
      {:ok, candidate} = AnalogInput.update_property(candidate, :present_value, 30.0)

      assert {:error, :write_access_denied} =
               Lifecycle.prepare_write(
                 stored.object,
                 candidate,
                 context(stored, {:property_write, :present_value, nil, nil})
               )

      {:ok, isolated} = write(stored, :out_of_service, true)
      {:ok, candidate} = AnalogInput.update_property(isolated.object, :out_of_service, false)

      assert {:error, :write_access_denied} =
               Lifecycle.prepare_write(
                 isolated.object,
                 candidate,
                 context(isolated, {:property_write, :present_value, nil, nil})
               )
    end

    test "OOS present value simulation accepts either origin and same-value writes" do
      for source <- [:application_write, :property_write], value <- [21.5, 30.0] do
        stored = initialize(%{present_value: 21.5, out_of_service: true})
        assert AnalogInput.property_writable?(stored.object, :present_value)
        assert {:ok, simulated} = write(stored, :present_value, value, source, 6)
        assert simulated.object.present_value == value
        assert simulated.object.status_flags.out_of_service
        assert simulated.next_execution == nil
        assert stored.object.present_value == 21.5
      end
    end

    test "returning to service preserves the value until the host supplies a fresh reading" do
      stored = initialize(%{present_value: 21.5})
      {:ok, isolated} = write(stored, :out_of_service, true)
      {:ok, simulated} = write(isolated, :present_value, 30.0, :application_write)
      {:ok, returned} = write(simulated, :out_of_service, false)
      assert returned.object.present_value == 30.0
      refute returned.object.status_flags.out_of_service
      {:ok, refreshed} = write(returned, :present_value, 22.0, :application_write)
      assert refreshed.object.present_value == 22.0
    end

    test "OOS reliability simulation accepts either origin including repeated values" do
      for source <- [:application_write, :property_write] do
        stored = initialize(%{out_of_service: true, reliability: :no_fault_detected})
        {:ok, simulated} = write(stored, :reliability, :process_error, source)
        assert simulated.object.status_flags.fault
        {:ok, repeated} = write(simulated, :reliability, :process_error, source)
        assert repeated.object.reliability == :process_error
        {:ok, cleared} = write(repeated, :reliability, :no_fault_detected, source)
        refute cleared.object.status_flags.fault
      end
    end

    test "hardware reliability remains independent of simulation and returns when known" do
      for source <- [:application_write, :property_write] do
        stored = initialize(%{reliability: :no_fault_detected})
        {:ok, physical} = write(stored, :reliability, :no_sensor, :application_write)
        {:ok, isolated} = write(physical, :out_of_service, true)
        {:ok, simulated} = write(isolated, :reliability, :no_fault_detected, source)
        refute simulated.object.status_flags.fault
        {:ok, returned} = write(simulated, :out_of_service, false)
        assert returned.object.reliability == :no_sensor
        assert returned.object.status_flags.fault
      end
    end

    test "inhibition masks hardware reports and restores the latest retained report" do
      stored = initialize(%{reliability: :no_sensor})
      {:ok, inhibited} = write(stored, :reliability_evaluation_inhibit, true)
      assert inhibited.object.reliability == :no_fault_detected
      refute inhibited.object.status_flags.fault
      {:ok, reported} = write(inhibited, :reliability, :communication_failure, :application_write)
      assert reported.object.reliability == :no_fault_detected
      {:ok, restored} = write(reported, :reliability_evaluation_inhibit, false)
      assert restored.object.reliability == :communication_failure
      assert restored.object.status_flags.fault
    end

    test "inhibited OOS simulation accepts either origin and property identifier form" do
      for source <- [:application_write, :property_write], property <- [:reliability, 103] do
        stored = initialize(%{reliability: :no_sensor, reliability_evaluation_inhibit: true})
        {:ok, isolated} = write(stored, :out_of_service, true)
        assert isolated.object.reliability == :no_fault_detected
        ctx = context(isolated, {source, property, nil, nil})

        {:ok, candidate} =
          AnalogInput.update_property(isolated.object, :reliability, :process_error)

        assert {:ok, prepared} = Lifecycle.prepare_write(isolated.object, candidate, ctx)
        {:ok, simulated} = AnalogInput.execute(prepared, ctx)
        assert simulated.object.reliability == :process_error

        {:ok, read} =
          Lifecycle.prepare_read(
            simulated.object,
            context(simulated, {:property_read, :reliability, nil})
          )

        assert read.object.reliability == :process_error
        {:ok, returned} = write(read, :out_of_service, false)
        assert returned.object.reliability == :no_fault_detected
        {:ok, uninhibited} = write(returned, :reliability_evaluation_inhibit, false)
        assert uninhibited.object.reliability == :no_sensor
      end
    end

    test "initial OOS reliability has no invented hardware report and accepts a fresh report later" do
      stored = initialize(%{out_of_service: true, reliability: :process_error})
      {:ok, returned} = write(stored, :out_of_service, false)
      assert returned.object.reliability == :process_error
      {:ok, reported} = write(returned, :reliability, :no_fault_detected, :application_write)
      assert reported.object.reliability == :no_fault_detected
    end

    test "initially supplied OOS reliability is retained while inhibited" do
      stored =
        initialize(%{
          out_of_service: true,
          reliability: :process_error,
          reliability_evaluation_inhibit: true
        })

      assert stored.object.reliability == :process_error
      assert stored.object.status_flags.fault
    end

    test "reliability can be added, removed and added again without stale fault state" do
      stored = initialize(%{})
      {:ok, object} = AnalogInput.add_property(stored.object, :reliability, :no_sensor)

      {:ok, reported} =
        Lifecycle.execute(
          object,
          context(stored, {:application_write, :reliability, nil, nil})
        )

      assert reported.object.status_flags.fault
      {:ok, object} = AnalogInput.remove_property(reported.object, :reliability)

      {:ok, removed} =
        Lifecycle.execute(
          object,
          context(reported, {:application_write, :reliability, nil, nil})
        )

      refute removed.object.status_flags.fault
      {:ok, object} = AnalogInput.add_property(removed.object, :reliability, :no_fault_detected)

      {:ok, added} =
        Lifecycle.execute(
          object,
          context(removed, {:application_write, :reliability, nil, nil})
        )

      refute added.object.status_flags.fault
    end

    test "invalid readings leave the retained value and supplied reliability unchanged" do
      stored =
        initialize(%{
          present_value: 20.0,
          min_present_value: 0.0,
          max_present_value: 100.0,
          reliability: :no_fault_detected
        })

      assert {:error, {:value_failed_property_validation, :present_value}} =
               write(stored, :present_value, 101.0, :application_write)

      assert {:error, {:invalid_property_type, :present_value}} =
               write(stored, :present_value, nil, :application_write)

      assert stored.object.present_value == 20.0
      assert stored.object.reliability == :no_fault_detected
      refute stored.object.status_flags.fault
    end

    test "existing REAL alternatives and numeric reliability constants remain supported" do
      stored = initialize(%{reliability: 999}, allow_numeric_constants: true)

      for value <- [22.0, :NaN, :inf, :infn] do
        {:ok, reported} = write(stored, :present_value, value, :application_write)
        assert reported.object.present_value == value
        assert {:ok, repeated} = Lifecycle.execute(reported.object, context(reported, :periodic))
        assert repeated.object.reliability == 999
      end
    end

    test "update interval and clock changes do not create polling or stale-sensor faults" do
      stored =
        initialize(%{present_value: 21.5, update_interval: 100, reliability: :no_fault_detected})

      ctx = %{context(stored, :periodic) | now: ~U[2030-01-01 00:00:00Z], monotonic_time: 999_999}
      assert {:ok, ^stored} = Lifecycle.execute(stored.object, ctx)
      backwards = %{ctx | now: ~U[2020-01-01 00:00:00Z], monotonic_time: -999_999}
      assert {:ok, ^stored} = Lifecycle.execute(stored.object, backwards)
      {:ok, configured} = write(stored, :update_interval, 200, :application_write)
      assert configured.object.update_interval == 200
      assert configured.next_execution == nil
    end

    test "initialization after restart uses properties and fresh runtime state" do
      stored =
        initialize(%{
          present_value: 21.5,
          reliability: :no_sensor,
          reliability_evaluation_inhibit: true
        })

      {:ok, restarted} =
        Lifecycle.execute(
          stored.object,
          %{context(stored, :initialization) | state: :discard_old_runtime}
        )

      assert restarted.object.present_value == 21.5
      {:ok, uninhibited} = write(restarted, :reliability_evaluation_inhibit, false)
      assert uninhibited.object.reliability == :no_fault_detected
    end

    test "invalid or other-object runtime state is rejected without a replacement" do
      {:ok, object} = AnalogInput.create(10, "State")

      for state <- [nil, :invalid, %{}] do
        assert {:error, :invalid_execution_state} =
                 Lifecycle.execute(
                   object,
                   %{context(nil, :periodic) | state: state}
                 )
      end

      stored = initialize(%{})
      {:ok, different} = AnalogInput.create(11, "Other")

      assert {:error, :invalid_execution_state} =
               Lifecycle.execute(different, context(stored, :periodic))

      {:ok, output} = AnalogOutput.create(10, "Output")
      {:ok, output} = Lifecycle.execute(output, context(nil, :initialization))

      assert {:error, :invalid_execution_state} =
               Lifecycle.execute(stored.object, context(output, :periodic))
    end

    test "reports a sampled high limit before a sensor fault takes precedence" do
      stored =
        initialize(
          %{
            high_limit: 1.0,
            reliability: :no_fault_detected,
            limit_enable: LimitEnable.from_bitstring({false, true})
          },
          intrinsic_reporting: true
        )

      {:ok, sampled} = write(stored, :present_value, 100.0, :application_write)

      assert %{event_type: :out_of_range, to_state: :high_limit} =
               EventReporting.transition(sampled)

      {:ok, faulty} = write(sampled, :reliability, :no_sensor, :application_write)
      assert faulty.object.present_value == 100.0
      assert faulty.object.status_flags.fault

      assert %{event_type: :change_of_reliability, from_state: :high_limit, to_state: :fault} =
               EventReporting.transition(faulty)

      assert faulty.next_execution == nil
    end

    test "remote snapshots remain passive and reject local write preparation" do
      {:ok, local} = AnalogInput.create(10, "Snapshot", %{present_value: 21.5})

      properties =
        Map.take(local, [:present_value, :units, :out_of_service, :event_state, :status_flags])

      {:ok, object} = AnalogInput.create(10, "Snapshot", properties, remote_object: 42)
      ctx = %{context(nil, :periodic) | state: :remote_state}
      expected = %Result{object: object, state: :remote_state, next_execution: nil}
      assert {:ok, ^expected} = Lifecycle.execute(object, ctx)
      assert {:ok, ^expected} = AnalogInput.execute(object, ctx)
      assert :ok = AnalogInput.validate_execution(object, ctx)

      assert {:error, :operation_not_available_for_remote_objects} =
               AnalogInput.prepare_write(object, object, ctx)
    end

    test "a host rejects in-service BACnet writes and accepts OOS wire simulation" do
      {:ok, object} = AnalogInput.create(10, "Host input", %{present_value: 21.5})
      host = Host.new([{object, []}], @now, 0)
      id = AnalogInput.get_object_identifier(object)
      assert :ok = Host.execute(host, id, :initialization)

      reference = %DeviceObjectPropertyRef{
        device_identifier: nil,
        object_identifier: id,
        property_identifier: :present_value,
        property_array_index: nil
      }

      assert {:error, {:write_access_denied, :present_value}} =
               Host.write(host, reference, Encoding.create!({:real, 30.0}))

      assert Host.snapshot(host, id).object.present_value == 21.5
      assert :ok = Host.write(host, %{reference | property_identifier: :out_of_service}, true)
      assert :ok = Host.write(host, reference, Encoding.create!({:real, 30.0}), 6)
      assert {:ok, 30.0} = Host.read(host, reference)
      assert Host.snapshot(host, id).next_execution == nil
    end

    test "Interface_Value selection distinguishes an absent property from an unknown reading" do
      {:ok, plain} = AnalogInput.create(10, "Plain")
      refute AnalogInput.has_property?(plain, :interface_value)
      {:ok, omitted} = AnalogInput.create(11, "Omitted", %{interface_value: nil})
      refute AnalogInput.has_property?(omitted, :interface_value)
      stored = initialize(%{present_value: 21.5, interface_value: :undefined})
      assert AnalogInput.has_property?(stored.object, :interface_value)
      assert stored.object.interface_value == :undefined
      assert stored.object.present_value == 21.5
      {:ok, added} = AnalogInput.add_property(plain, :interface_value, :undefined)
      assert AnalogInput.has_property?(added, :interface_value)
      assert added.interface_value == :undefined
      assert AnalogInput.get_annotation(:interface_value)[:revision] == 16

      assert AnalogInput.get_properties_type_map()[:interface_value] ==
               {:type_list, [:real, {:literal, :undefined}]}
    end

    test "physical samples do not select an optional Interface_Value implicitly" do
      stored = initialize(%{present_value: 21.5})
      {:ok, sampled} = sample(stored, 22.0)
      assert sampled.object.present_value == 22.0
      refute AnalogInput.has_property?(sampled.object, :interface_value)
      {:ok, isolated} = write(sampled, :out_of_service, true)
      {:ok, observed} = sample(isolated, 23.0)
      assert observed.object.present_value == 22.0
      refute AnalogInput.has_property?(observed.object, :interface_value)
    end

    test "physical samples update both values in service and only the interface during simulation" do
      stored =
        initialize(%{
          present_value: 21.5,
          interface_value: :undefined,
          reliability: :no_fault_detected
        })

      {:ok, measured} = sample(stored, 22.0)
      assert measured.object.present_value == 22.0
      assert measured.object.interface_value == 22.0
      {:ok, isolated} = write(measured, :out_of_service, true)
      {:ok, simulated} = write(isolated, :present_value, 30.0, :application_write)
      assert simulated.object.interface_value == 22.0
      {:ok, observed} = sample(simulated, 23.0)
      assert observed.object.present_value == 30.0
      assert observed.object.interface_value == 23.0
      {:ok, simulated} = write(observed, :present_value, 31.0)
      assert simulated.object.interface_value == 23.0
      {:ok, returned} = write(simulated, :out_of_service, false)
      assert returned.object.present_value == 31.0
      assert returned.object.interface_value == 23.0
      {:ok, fresh} = sample(returned, 24.0)
      assert fresh.object.present_value == 24.0
      assert fresh.object.interface_value == 24.0
    end

    test "unknown physical input is NULL without inventing a logical value or reliability fault" do
      stored =
        initialize(%{present_value: 21.5, interface_value: 21.5, reliability: :no_fault_detected})

      for out_of_service <- [false, true] do
        {:ok, configured} = write(stored, :out_of_service, out_of_service)
        {:ok, unknown} = sample(configured, :undefined)
        assert unknown.object.interface_value == :undefined
        assert unknown.object.present_value == 21.5
        assert unknown.object.reliability == :no_fault_detected
        refute unknown.object.status_flags.fault
      end
    end

    test "Interface_Value remains readonly to BACnet with named or numeric identifiers" do
      stored = initialize(%{interface_value: :undefined})

      for out_of_service <- [false, true], property <- [:interface_value, 387] do
        {:ok, configured} = write(stored, :out_of_service, out_of_service)
        refute AnalogInput.property_writable?(configured.object, :interface_value)
        {:ok, candidate} = AnalogInput.update_property(configured.object, :interface_value, 25.0)
        ctx = context(configured, {:property_write, property, nil, nil})

        assert {:error, :write_access_denied} =
                 Lifecycle.prepare_write(configured.object, candidate, ctx)

        assert {:error, :write_access_denied} = Lifecycle.execute(candidate, ctx)
      end

      # Local adapters can report the property independently when they need only an observation.
      {:ok, reported} = write(stored, :interface_value, 25.0, :application_write)
      assert reported.object.interface_value == 25.0
      assert reported.object.present_value == stored.object.present_value
    end

    test "Interface_Value encodes as REAL or NULL without a shared nil-conversion option" do
      stored = initialize(%{interface_value: :undefined})
      id = AnalogInput.get_object_identifier(stored.object)

      for {value, encoding} <- [
            {0.0, {:real, 0.0}},
            {23.5, {:real, 23.5}},
            {:NaN, {:real, :NaN}},
            {:inf, {:real, :inf}},
            {:infn, {:real, :infn}},
            {:undefined, {:null, nil}}
          ] do
        assert {:ok, encoded} = ObjectsUtility.cast_value_to_property(id, :interface_value, value)
        assert encoded == Encoding.create!(encoding)

        assert {:ok, ^value} =
                 ObjectsUtility.cast_property_to_value(id, :interface_value, encoded)
      end

      for value <- [nil, true, 1, :unknown] do
        assert {:error, {:invalid_property_type, :interface_value}} =
                 AnalogInput.update_property(stored.object, :interface_value, value)

        assert {:error, {:invalid_property_value, {:interface_value, ^value}}} =
                 ObjectsUtility.cast_value_to_property(id, :interface_value, value)
      end

      for encoding <- [{:boolean, true}, {:double, 23.5}, {:unsigned_integer, 1}] do
        encoded = Encoding.create!(encoding)

        assert {:error, {:invalid_property_value, {:interface_value, ^encoded}}} =
                 ObjectsUtility.cast_property_to_value(id, :interface_value, encoded)
      end
    end

    test "physical observation updates are atomic and use existing present-value range validation" do
      stored =
        initialize(%{
          present_value: 20.0,
          interface_value: :undefined,
          min_present_value: 0.0,
          max_present_value: 100.0
        })

      assert {:error, {:value_failed_property_validation, :present_value}} =
               AnalogInput.set_input(stored.object, 101.0)

      assert stored.object.interface_value == :undefined
      assert stored.object.present_value == 20.0

      for value <- [nil, true, 1] do
        assert {:error, {:invalid_property_type, :interface_value}} =
                 AnalogInput.set_input(stored.object, value)
      end

      {:ok, isolated} = write(stored, :out_of_service, true)
      {:ok, observed} = sample(isolated, 101.0)
      assert observed.object.interface_value == 101.0
      assert observed.object.present_value == 20.0
    end

    test "removing Interface_Value does not make the next physical sample select it again" do
      stored = initialize(%{interface_value: :undefined})
      {:ok, object} = AnalogInput.remove_property(stored.object, :interface_value)

      {:ok, removed} =
        Lifecycle.execute(
          object,
          context(stored, {:application_write, :interface_value, nil, nil})
        )

      {:ok, sampled} = sample(removed, 23.0)
      refute AnalogInput.has_property?(sampled.object, :interface_value)
      assert sampled.object.present_value == 23.0
    end

    test "a remote Interface_Value is retained as a snapshot and cannot receive a physical sample" do
      {:ok, local} =
        AnalogInput.create(10, "Snapshot", %{
          present_value: 30.0,
          out_of_service: true,
          interface_value: 23.5
        })

      properties =
        Map.take(local, [
          :present_value,
          :interface_value,
          :units,
          :out_of_service,
          :event_state,
          :status_flags
        ])

      {:ok, snapshot} = AnalogInput.create(10, "Snapshot", properties, remote_object: 42)
      ctx = %{context(nil, :initialization) | state: :opaque_snapshot_state}
      {:ok, result} = Lifecycle.execute(snapshot, ctx)
      assert result.object.present_value == 30.0
      assert result.object.interface_value == 23.5
      assert result.state == :opaque_snapshot_state

      assert {:error, :operation_not_available_for_remote_objects} =
               AnalogInput.set_input(snapshot, 24.0)
    end

    test "a NULL Interface_Value survives read-ack conversion into a remote object" do
      stored = initialize(%{interface_value: :undefined})
      id = AnalogInput.get_object_identifier(stored.object)

      ack = %ReadPropertyAck{
        object_identifier: id,
        property_identifier: :interface_value,
        property_array_index: nil,
        property_value: Encoding.create!({:null, nil})
      }

      assert {:ok, %{interface_value: :undefined} = decoded} =
               ObjectsUtility.cast_read_properties_ack(id, [ack])

      properties = Map.merge(ObjectsUtility.to_map(stored.object), decoded)

      assert {:ok, snapshot} =
               ObjectsUtility.cast_properties_to_object(id, properties, remote_device_id: 42)

      assert AnalogInput.has_property?(snapshot, :interface_value)
      assert snapshot.interface_value == :undefined
      assert snapshot._metadata.remote_object == 42
    end

    defp sample(stored, value) do
      ctx = context(stored, {:application_write, :present_value, nil, nil})

      with {:ok, candidate} <- AnalogInput.set_input(stored.object, value),
           {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
        AnalogInput.execute(prepared, ctx)
      end
    end

    defp initialize(properties, options \\ []) do
      {:ok, object} = AnalogInput.create(10, "Input", properties, options)
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

      with {:ok, candidate} <- AnalogInput.update_property(stored.object, property, value),
           {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
        AnalogInput.execute(prepared, ctx)
      end
    end
  end
end
