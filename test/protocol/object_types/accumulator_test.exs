defmodule BACnet.Test.Protocol.ObjectTypes.AccumulatorTest do
  alias BACnet.Protocol.AccumulatorRecord
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectTypes.Accumulator
  alias BACnet.Protocol.Prescale

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_accumulator

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "verify accumulator scale real decoding" do
    assert {:ok, 10.0} =
             ObjectsUtility.cast_property_to_value(
               %ObjectIdentifier{type: :accumulator, instance: 0},
               :scale,
               %Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 0],
                 type: nil,
                 value: <<65, 32, 0, 0>>
               }
             )
  end

  test "verify accumulator scale int decoding" do
    assert {:ok, 10} =
             ObjectsUtility.cast_property_to_value(
               %ObjectIdentifier{type: :accumulator, instance: 0},
               :scale,
               %Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 1],
                 type: nil,
                 value: "\n"
               }
             )
  end

  test "verify accumulator scale decoding failing" do
    assert {:error, {:invalid_tags, {:scale, %Encoding{}}}} =
             ObjectsUtility.cast_property_to_value(
               %ObjectIdentifier{type: :accumulator, instance: 0},
               :scale,
               %Encoding{
                 encoding: :tagged,
                 extras: [tag_number: 2],
                 type: nil,
                 value: "\n"
               }
             )
  end

  test "verify accumulator scale real encoding" do
    assert {:ok,
            %Encoding{
              encoding: :tagged,
              extras: [tag_number: 0],
              type: nil,
              value: <<65, 32, 0, 0>>
            }} =
             ObjectsUtility.cast_value_to_property(
               %ObjectIdentifier{type: :accumulator, instance: 0},
               :scale,
               10.0
             )
  end

  test "verify accumulator scale int encoding" do
    assert {:ok,
            %Encoding{
              encoding: :tagged,
              extras: [tag_number: 1],
              type: nil,
              value: "\n"
            }} =
             ObjectsUtility.cast_value_to_property(
               %ObjectIdentifier{type: :accumulator, instance: 0},
               :scale,
               10
             )
  end

  test "verify accumulator scale encoding failing" do
    assert {:error, {:invalid_property_value, {:scale, :hello}}} =
             ObjectsUtility.cast_value_to_property(
               %ObjectIdentifier{type: :accumulator, instance: 0},
               :scale,
               :hello
             )
  end

  describe "lifecycle" do
    test "retains fractional pulses across batches and wraps at Max_Pres_Value plus one" do
      stored = initialize(%{present_value: 3, max_present_value: 4})

      {:ok, first} = record(stored, 2, 100)
      assert first.object.present_value == 4
      assert first.next_execution == nil

      {:ok, second} = record(first, 2, 200)
      assert second.object.present_value == 0

      {:ok, third} = record(second, 10, 300)
      assert third.object.present_value == 2
      assert third.object.scale == 100.0

      assert {:error, :invalid_pulse_count} = record(third, -1, 300)
      assert {:error, :monotonic_time_went_backwards} = record(third, 1, 299)
    end

    test "measures raw pulses in fixed monotonic windows even when the count is prescaled" do
      stored = initialize(%{limit_monitoring_interval: 1})
      assert stored.object.pulse_rate == 0
      assert stored.next_execution == %Wakeup{wall_time: nil, monotonic_time: 1000}

      {:ok, first} = record(stored, 2, 100)
      {:ok, second} = record(first, 3, 900)
      {:ok, boundary} = record(second, 1, 1000)
      assert boundary.object.present_value == 4
      assert boundary.object.pulse_rate == 5
      assert boundary.next_execution.monotonic_time == 2000

      {:ok, next} = run(boundary, :timer, 2000)
      assert next.object.pulse_rate == 1
      {:ok, late} = run(next, :timer, 4500)
      assert late.object.pulse_rate == 0
      assert late.next_execution.monotonic_time == 5000

      assert {:error, {:invalid_configuration, :limit_monitoring_interval}} =
               write(late, :limit_monitoring_interval, 0, 4500)

      {:ok, reconfigured} = write(late, :limit_monitoring_interval, 2, 4500)
      assert reconfigured.next_execution.monotonic_time == 6500
    end

    test "out of service freezes input and restores the retained count on resumption" do
      stored = initialize(%{present_value: 4, pulse_rate: 0})
      refute :present_value in Accumulator.get_readonly_properties()
      refute Accumulator.property_writable?(stored.object, :present_value)
      refute Accumulator.property_writable?(stored.object, :pulse_rate)
      assert Accumulator.property_writable?(stored.object, :units)
      assert {:error, :write_access_denied} = write(stored, :present_value, 17)
      assert {:error, :write_access_denied} = write(stored, :pulse_rate, 17)

      {:ok, first} = record(stored, 1, 100)
      {:ok, isolated} = write(first, :out_of_service, true, 100)
      assert isolated.next_execution == nil
      assert Accumulator.property_writable?(isolated.object, :present_value)
      assert Accumulator.property_writable?(isolated.object, :pulse_rate)

      {:ok, simulated} = write(isolated, :present_value, 17, 100)
      {:ok, simulated} = write(simulated, :pulse_rate, 99, 100)
      {:ok, ignored} = record(simulated, 90, 150)
      assert ignored.object.present_value == 17
      assert ignored.object.pulse_rate == 99
      assert ignored.next_execution == nil

      {:ok, resumed} = write(ignored, :out_of_service, false, 200)
      assert resumed.object.present_value == 4
      assert resumed.object.pulse_rate == 0
      assert resumed.next_execution.monotonic_time == 1200
      {:ok, counted} = record(resumed, 1, 201)
      assert counted.object.present_value == 5
    end

    test "Value_Set snapshots the previous count and stamps even a repeated preset" do
      stored = initialize(%{present_value: 4, value_set: 0, max_present_value: 8})
      assert stored.object.value_change_time == ObjectsMacro.get_default_bacnet_datetime()

      {:ok, counted} = record(stored, 1, 100)
      {:ok, candidate} = Accumulator.update_property(counted.object, :value_set, 7)
      context = context(counted, {:property_write, :value_set, nil, nil}, 101)

      assert {:ok, prepared} = Lifecycle.prepare_write(counted.object, candidate, context)
      assert prepared.present_value == 7
      assert prepared.value_before_change == 4
      assert prepared.value_change_time == BACnetDateTime.from_datetime(context.now)
      assert {:ok, preset} = Lifecycle.execute(prepared, context)

      {:ok, single_pulse} = record(preset, 1, 102)
      assert single_pulse.object.present_value == 7

      {:ok, repeated} = write(single_pulse, :value_set, 7, 110)
      assert repeated.object.value_before_change == 7
      assert repeated.object.value_change_time == BACnetDateTime.from_datetime(wall_time(110))

      assert {:error, {:property_out_of_range, :value_set}} =
               write(repeated, :value_set, 9, 120)

      assert {:error, {:property_not_allowed, :value_before_change}} =
               Accumulator.remove_property(repeated.object, :value_before_change)

      {:ok, isolated} = write(repeated, :out_of_service, true, 130)
      {:ok, preset} = write(isolated, :value_set, 5, 131)
      {:ok, simulated} = write(preset, :present_value, 4, 132)
      {:ok, resumed} = write(simulated, :out_of_service, false, 133)
      assert resumed.object.present_value == 5
    end

    test "reports the measured pulse rate independently of the accumulated value" do
      stored = initialize(%{}, intrinsic_reporting: true)
      assert stored.object.pulse_rate == 0
      assert stored.object.limit_monitoring_interval == 1
      {:ok, counted} = record(stored, 3, 100)
      {:ok, measured} = Accumulator.execute(counted.object, context(counted, :timer, 1000))
      assert measured.object.present_value == 2
      assert measured.object.pulse_rate == 3

      assert %{
               event_type: :unsigned_range,
               to_state: :high_limit,
               event_values: %{exceeding_value: 3}
             } = EventReporting.transition(measured)
    end

    test "only the configured reader refreshes the record and presets do not count as pulses" do
      reader = %ObjectIdentifier{type: :trend_log, instance: 2}
      other = %ObjectIdentifier{type: :trend_log, instance: 3}

      stored =
        initialize(%{
          present_value: 8,
          max_present_value: 9,
          prescale: %Prescale{multiplier: 1, modulo_divide: 1},
          value_set: 0,
          logging_object: reader
        })

      assert [starting] = stored.object.logging_record
      assert starting.timestamp == ObjectsMacro.get_default_bacnet_datetime()
      assert starting.present_value == 0
      assert starting.accumulated_value == 0
      assert starting.status == :starting

      {:ok, unread} = read_log(stored, 100, other)
      assert unread.object.logging_record == [starting]

      {:ok, acquired} = read_log(unread, 200, reader)

      assert [
               %AccumulatorRecord{status: :starting, present_value: 8, accumulated_value: 0} =
                 first
             ] =
               acquired.object.logging_record

      {:ok, wrapped} = record(acquired, 3, 300)
      assert wrapped.object.present_value == 1
      {:ok, preset} = write(wrapped, :value_set, 6, 310)
      {:ok, counted} = record(preset, 2, 320)
      {:ok, preset} = write(counted, :value_set, 3, 330)
      {:ok, counted} = record(preset, 1, 340)

      {:ok, unqualified} = read_log(counted, 350)
      assert unqualified.object.logging_record == [first]

      {:ok, acquired} = read_log(unqualified, 400, reader, 0xB8)

      assert [
               %AccumulatorRecord{
                 timestamp: timestamp,
                 status: :recovered,
                 present_value: 4,
                 accumulated_value: 6
               }
             ] = acquired.object.logging_record

      assert timestamp == BACnetDateTime.from_datetime(wall_time(400))
      id = Accumulator.get_object_identifier(acquired.object)

      assert {:ok, encodings} =
               ObjectsUtility.cast_value_to_property(
                 id,
                 :logging_record,
                 acquired.object.logging_record
               )

      assert {:ok, records} =
               ObjectsUtility.cast_property_to_value(id, :logging_record, encodings)

      assert records == acquired.object.logging_record

      {:ok, counted} = record(acquired, 2, 500)
      {:ok, normal} = read_log(counted, 600, reader)

      assert [%AccumulatorRecord{status: :normal, present_value: 6, accumulated_value: 2}] =
               normal.object.logging_record

      assert {:error, :write_access_denied} =
               write(normal, :logging_record, [first], 650)

      {:ok, reassigned} = write(normal, :logging_object, other, 700)
      {:ok, unqualified} = read_log(reassigned, 800, reader)
      assert unqualified.object.logging_record == [starting]

      {:ok, acquired} = read_log(unqualified, 900, other)

      assert [%AccumulatorRecord{status: :starting, present_value: 6, accumulated_value: 0}] =
               acquired.object.logging_record
    end

    test "unrestricted record reads report clock changes and unreliable accumulation" do
      stored = initialize(%{logging_record: [], reliability: :no_fault_detected})
      {:ok, acquired} = read_log(stored, 10)
      {:ok, counted} = record(acquired, 3, 20)
      {:ok, clock_changed} = run(counted, :clock_change, 30)
      assert clock_changed.object.logging_record == acquired.object.logging_record

      {:ok, abnormal} = read_log(clock_changed, 40)

      assert [%AccumulatorRecord{status: :abnormal, accumulated_value: 2}] =
               abnormal.object.logging_record

      {:ok, unreliable} = write(abnormal, :reliability, :process_error, 50)
      {:ok, reliable} = write(unreliable, :reliability, :no_fault_detected, 60)
      {:ok, failed} = read_log(reliable, 70)

      assert [%AccumulatorRecord{status: :failed, accumulated_value: 0}] =
               failed.object.logging_record
    end

    test "retains the physical reliability report through inhibition and simulation" do
      stored = initialize(%{reliability: :process_error})
      {:ok, inhibited} = write(stored, :reliability_evaluation_inhibit, true)
      assert inhibited.object.reliability == :no_fault_detected
      refute inhibited.object.status_flags.fault

      {:ok, isolated} = write(inhibited, :out_of_service, true)
      {:ok, simulated} = write(isolated, :reliability, :communication_failure)
      assert simulated.object.reliability == :communication_failure
      assert simulated.object.status_flags.fault

      {:ok, resumed} = write(simulated, :out_of_service, false)
      assert resumed.object.reliability == :no_fault_detected
      {:ok, restored} = write(resumed, :reliability_evaluation_inhibit, false)
      assert restored.object.reliability == :process_error
      assert restored.object.status_flags.fault
    end

    test "rejects invalid local configuration and leaves remote snapshots passive" do
      properties = %{
        scale: 1.0,
        prescale: %Prescale{multiplier: 1, modulo_divide: 0},
        present_value: 0
      }

      {:ok, invalid} = Accumulator.create(1, "Meter", properties)

      assert {:error, {:invalid_configuration, :prescale}} =
               Lifecycle.execute(invalid, context(nil, :initialization, 0))

      {:ok, remote} =
        Accumulator.create(
          2,
          "Remote meter",
          Map.merge(properties, %{
            event_state: :normal,
            status_flags: %BACnet.Protocol.StatusFlags{
              in_alarm: false,
              fault: false,
              overridden: false,
              out_of_service: false
            },
            out_of_service: false,
            units: :no_units,
            max_present_value: 10
          }),
          remote_object: 42
        )

      assert {:ok, %Result{object: ^remote, state: :snapshot, next_execution: nil}} =
               Lifecycle.execute(remote, %{context(nil, :periodic, 0) | state: :snapshot})

      assert {:error, :operation_not_available_for_remote_objects} =
               Accumulator.record_pulses(remote, 1, context(nil, :periodic, 0))

      remote_context = context(nil, :periodic, 0)
      assert :ok = Accumulator.validate_execution(remote, remote_context)

      assert {:error, :operation_not_available_for_remote_objects} =
               Accumulator.prepare_write(remote, remote, %{
                 remote_context
                 | trigger: {:property_write, :present_value, nil, nil}
               })

      assert {:ok, %Result{object: ^remote, state: :snapshot, next_execution: nil}} =
               Accumulator.execute(remote, %{remote_context | state: :snapshot})
    end

    test "rejects execution state that is not a retained accumulator snapshot" do
      stored = initialize(%{})

      for state <- [
            nil,
            :bad,
            %{stored.state | present_value: -1},
            %{stored.state | remainder: 99},
            %{stored.state | identifier: :meter}
          ] do
        assert {:error, :invalid_execution_state} =
                 Accumulator.validate_execution(stored.object, %{
                   context(stored, :periodic, 1)
                   | state: state
                 })
      end
    end

    test "rejects a rate window or logging snapshot that does not match the retained shape" do
      stored = initialize(%{})

      for window <- [
            :open,
            %{period: 0, deadline: 1, pulses: 1},
            %{period: 1, deadline: 1, pulses: -1}
          ] do
        assert {:error, :invalid_execution_state} =
                 Accumulator.validate_execution(stored.object, %{
                   context(stored, :periodic, 1)
                   | state: %{stored.state | rate_window: window}
                 })
      end

      for logging <- [
            :record,
            %{reader: :trend_log, acquired: false, accumulated: 0, status: :normal},
            %{reader: nil, acquired: true, accumulated: -1, status: :normal},
            %{reader: nil, acquired: true, accumulated: 0, status: :bogus}
          ] do
        assert {:error, :invalid_execution_state} =
                 Accumulator.validate_execution(stored.object, %{
                   context(stored, :periodic, 1)
                   | state: %{stored.state | logging: logging}
                 })
      end
    end

    test "a preset creates Value_Change_Time when that property is absent" do
      stored = initialize(%{present_value: 4, max_present_value: 8})
      {:ok, stripped} = Accumulator.remove_property(stored.object, :value_change_time)
      refute Accumulator.has_property?(stripped, :value_change_time)
      {:ok, with_set} = Accumulator.add_property(stripped, :value_set, 0)
      refute Accumulator.has_property?(with_set, :value_change_time)

      {:ok, preset} = write(%{stored | object: with_set}, :value_set, 7, 100)
      assert preset.object.present_value == 7
      assert preset.object.value_before_change == 4
      assert preset.object.value_change_time == BACnetDateTime.from_datetime(wall_time(100))
    end

    test "selecting Logging_Object creates Logging_Record and resumption uses the retained count" do
      reader = %ObjectIdentifier{type: :trend_log, instance: 2}
      stored = initialize(%{present_value: 4})
      refute Accumulator.has_property?(stored.object, :logging_record)
      {:ok, object} = Accumulator.add_property(stored.object, :logging_object, reader)
      refute Accumulator.has_property?(object, :logging_record)

      {:ok, counted} = record(%{stored | object: object}, 0, 100)

      assert [%AccumulatorRecord{status: :starting, present_value: 0}] =
               counted.object.logging_record

      {:ok, acquired} = read_log(counted, 150, reader)
      {:ok, isolated} = write(acquired, :out_of_service, true, 160)
      {:ok, simulated} = write(isolated, :present_value, 20, 170)
      {:ok, resumed} = write(simulated, :out_of_service, false, 180)
      assert resumed.object.out_of_service == false
      assert resumed.object.present_value == acquired.object.present_value

      {:ok, counted} = record(resumed, 3, 190)
      {:ok, logged} = read_log(counted, 200, reader)

      assert [%AccumulatorRecord{status: :normal, accumulated_value: accumulated}] =
               logged.object.logging_record

      assert accumulated >= 0
      assert logged.object.present_value >= resumed.object.present_value
    end

    test "initialization out of service has no physical reliability report" do
      {:ok, object} =
        Accumulator.create(
          1,
          "Meter",
          %{
            scale: 1.0,
            prescale: %Prescale{multiplier: 1, modulo_divide: 1},
            out_of_service: true,
            reliability: :process_error
          }
        )

      {:ok, stored} = Lifecycle.execute(object, context(nil, :initialization, 0))
      assert stored.object.out_of_service
      assert stored.object.reliability == :process_error
      assert stored.state.physical_reliability == nil
      assert stored.state.manual_reliability == :process_error
    end

    test "an out-of-service write other than reliability keeps the simulated report" do
      stored = initialize(%{reliability: :process_error})
      {:ok, isolated} = write(stored, :out_of_service, true, 10)
      {:ok, simulated} = write(isolated, :reliability, :communication_failure, 20)
      {:ok, renamed} = write(simulated, :units, :kilowatt_hours, 30)
      assert renamed.object.units == :kilowatt_hours
      assert renamed.object.reliability == :communication_failure
      assert renamed.state.manual_reliability == :communication_failure
    end

    defp initialize(properties, opts \\ []) do
      properties =
        Map.merge(
          %{scale: 100.0, prescale: %Prescale{multiplier: 2, modulo_divide: 3}},
          properties
        )

      {:ok, object} = Accumulator.create(1, "Meter", properties, opts)
      {:ok, stored} = Lifecycle.execute(object, context(nil, :initialization, 0))
      stored
    end

    defp record(stored, pulses, monotonic_time) do
      Accumulator.record_pulses(stored.object, pulses, context(stored, :periodic, monotonic_time))
    end

    defp run(stored, trigger, monotonic_time) do
      Lifecycle.execute(stored.object, context(stored, trigger, monotonic_time))
    end

    defp write(stored, property, value, monotonic_time \\ 0) do
      with {:ok, candidate} <- Accumulator.update_property(stored.object, property, value) do
        context = context(stored, {:property_write, property, nil, nil}, monotonic_time)

        with {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, context) do
          Lifecycle.execute(prepared, context)
        end
      end
    end

    defp read_log(stored, monotonic_time, reader \\ nil, property \\ :logging_record) do
      context = context(stored, {:property_read, property, nil}, monotonic_time)
      Lifecycle.prepare_read(stored.object, %{context | options: [reader_identifier: reader]})
    end

    defp context(stored, trigger, monotonic_time) do
      Context.new(trigger,
        now: wall_time(monotonic_time),
        monotonic_time: monotonic_time,
        state: if(stored, do: stored.state)
      )
    end

    defp wall_time(monotonic_time) do
      DateTime.add(~U[2026-11-09 12:00:00Z], monotonic_time, :millisecond)
    end
  end
end
