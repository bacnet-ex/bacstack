defmodule BACnet.Test.Protocol.ObjectTypes.BinaryInputTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.DaysOfWeek
  alias BACnet.Protocol.Destination
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.EventTransitionBits
  alias BACnet.Protocol.NotificationParameters
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectPropertyRef
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectTypes.BinaryInput
  alias BACnet.Protocol.ObjectTypes.BinaryOutput
  alias BACnet.Protocol.ObjectTypes.NotificationClass
  alias BACnet.Protocol.PropertyState
  alias BACnet.Protocol.Recipient
  alias BACnet.Protocol.Services.UnconfirmedEventNotification
  alias BACnet.Test.Support.Protocol.ObjectExecutionTestHost, as: Host

  use ExUnit.Case, async: true

  doctest BinaryInput

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_binary_input

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "verify set_input/2 for normal priority and out_of_service = false" do
    {:ok, %BinaryInput{present_value: false} = obj} =
      BinaryInput.create(1, "TEST", %{polarity: :normal})

    assert {:ok, %BinaryInput{present_value: true}} = BinaryInput.set_input(obj, true)
    assert {:ok, %BinaryInput{present_value: false}} = BinaryInput.set_input(obj, false)
    assert {:ok, %BinaryInput{present_value: true}} = BinaryInput.set_input(obj, true)

    assert {:ok, %BinaryInput{present_value: true} = obj} = BinaryInput.set_input(obj, true)
    assert {:ok, %BinaryInput{present_value: false} = obj} = BinaryInput.set_input(obj, false)
    assert {:ok, %BinaryInput{present_value: true}} = BinaryInput.set_input(obj, true)
  end

  test "verify set_input/2 for reversed priority and out_of_service = false" do
    # Starts with false, regardless of polarity
    {:ok, %BinaryInput{present_value: false} = obj} =
      BinaryInput.create(1, "TEST", %{polarity: :reverse})

    assert {:ok, %BinaryInput{present_value: false}} = BinaryInput.set_input(obj, true)
    assert {:ok, %BinaryInput{present_value: true}} = BinaryInput.set_input(obj, false)
    assert {:ok, %BinaryInput{present_value: false}} = BinaryInput.set_input(obj, true)

    assert {:ok, %BinaryInput{present_value: false} = obj} = BinaryInput.set_input(obj, true)
    assert {:ok, %BinaryInput{present_value: true} = obj} = BinaryInput.set_input(obj, false)
    assert {:ok, %BinaryInput{present_value: false}} = BinaryInput.set_input(obj, true)
  end

  test "verify set_input/2 for normal priority and out_of_service = true" do
    {:ok, %BinaryInput{present_value: false} = obj} =
      BinaryInput.create(1, "TEST", %{out_of_service: true, polarity: :normal})

    assert {:ok, %BinaryInput{present_value: false}} = BinaryInput.set_input(obj, true)
    assert {:ok, %BinaryInput{present_value: false}} = BinaryInput.set_input(obj, false)
  end

  test "verify set_input/2 for reverse priority and out_of_service = true" do
    {:ok, %BinaryInput{present_value: false} = obj} =
      BinaryInput.create(1, "TEST", %{out_of_service: true, polarity: :reverse})

    assert {:ok, %BinaryInput{present_value: false}} = BinaryInput.set_input(obj, true)
    assert {:ok, %BinaryInput{present_value: false}} = BinaryInput.set_input(obj, false)
  end

  @now ~U[2026-11-08 10:00:00Z]

  test "history members select their entire group and removal removes all partners" do
    for {property, value} <- [
          change_of_state_count: 7,
          change_of_state_time: timestamp(0),
          time_of_state_count_reset: timestamp(0)
        ] do
      created = object(%{property => value})
      assert_history(created)
      {:ok, added} = BinaryInput.add_property(object(%{}), property, value)
      assert_history(added)
      {:ok, removed} = BinaryInput.remove_property(added, property)

      for key <- [:change_of_state_count, :change_of_state_time, :time_of_state_count_reset],
          do: refute(BinaryInput.has_property?(removed, key))
    end
  end

  test "initialization maps a known sample and preserves historical totals and reset times" do
    object =
      object(
        %{
          polarity: :reverse,
          change_of_state_count: 5,
          elapsed_active_time: 8,
          interface_value: :undefined
        },
        physical_input: false
      )

    {:ok, stored} = Lifecycle.execute(object, context(nil, -2000, :initialization))
    assert stored.object.present_value
    assert stored.object.interface_value
    assert stored.object.change_of_state_count == 5
    assert stored.object.change_of_state_time == object.change_of_state_time
    assert stored.object.elapsed_active_time == 8
    assert stored.object.time_of_state_count_reset == object.time_of_state_count_reset
    assert stored.object.time_of_active_time_reset == object.time_of_active_time_reset
    assert stored.next_execution == %Wakeup{wall_time: nil, monotonic_time: -1000}
  end

  test "physical samples apply polarity and only effective changes increment history" do
    for polarity <- [:normal, :reverse] do
      stored = initialize(%{polarity: polarity, change_of_state_count: 0})
      raw = polarity == :normal
      {:ok, active} = sample(stored, raw, 100)
      assert active.object.present_value
      assert active.object.change_of_state_count == 1
      assert active.object.change_of_state_time == timestamp(100)
      {:ok, repeated} = sample(active, raw, 200)
      assert repeated.object.change_of_state_count == 1
      assert repeated.object.change_of_state_time == timestamp(100)
      {:ok, inactive} = sample(repeated, not raw, 300)
      refute inactive.object.present_value
      assert inactive.object.change_of_state_count == 2
    end
  end

  test "a polarity edit changes logical state for a steady sample and is not applied twice" do
    stored = initialize(%{change_of_state_count: 0, interface_value: :undefined})
    {:ok, active} = sample(stored, true, 100)
    {:ok, reversed} = write(active, :polarity, :reverse, 200)
    refute reversed.object.present_value
    refute reversed.object.interface_value
    assert reversed.object.change_of_state_count == 2
    assert reversed.object.change_of_state_time == timestamp(200)
    {:ok, repeated} = Lifecycle.execute(reversed.object, context(reversed, 300, :periodic))
    refute repeated.object.present_value
    assert repeated.object.change_of_state_count == 2
  end

  test "with an unknown sample a polarity edit inverts previous logical state without claiming a sample" do
    stored =
      initialize(%{present_value: true, interface_value: :undefined, change_of_state_count: 0})

    assert stored.object._metadata.physical_input == nil
    {:ok, reversed} = write(stored, :polarity, :reverse, 100)
    refute reversed.object.present_value
    assert reversed.object.interface_value == :undefined
    assert reversed.object._metadata.physical_input == nil
    assert reversed.object.change_of_state_count == 1
  end

  test "BACnet present-value writes require OOS, including same-value and numeric writes" do
    stored = initialize(%{})
    refute BinaryInput.property_writable?(stored.object, :present_value)
    assert {:error, :write_access_denied} = write(stored, :present_value, false, 100)
    assert {:error, :write_access_denied} = write(stored, :present_value, true, 100)
    {:ok, candidate} = BinaryInput.update_property(stored.object, :present_value, true)

    assert {:error, :write_access_denied} =
             Lifecycle.prepare_write(
               stored.object,
               candidate,
               context(stored, 100, {:property_write, 85, nil, 6})
             )

    {:ok, decoupled} = write(stored, :out_of_service, true, 200)
    assert BinaryInput.property_writable?(decoupled.object, :present_value)
    {:ok, simulated} = write(decoupled, :present_value, true, 300, priority: 6)
    assert simulated.object.present_value
  end

  test "OOS samples retain the raw observation and interface while preserving simulation" do
    stored =
      initialize(%{interface_value: :undefined, change_of_state_count: 0, elapsed_active_time: 0})

    {:ok, physical} = sample(stored, false, 100)
    {:ok, decoupled} = write(physical, :out_of_service, true, 200)
    {:ok, simulated} = write(decoupled, :present_value, true, 300)
    {:ok, physical} = sample(simulated, false, 400)
    assert physical.object.present_value
    refute physical.object.interface_value
    assert physical.object.change_of_state_count == 1
    {:ok, polarity} = write(physical, :polarity, :reverse, 500)
    assert polarity.object.present_value
    assert polarity.object.interface_value
    assert polarity.object.change_of_state_count == 1
    {:ok, unknown} = sample(polarity, nil, 600)
    assert unknown.object.present_value
    assert unknown.object.interface_value == :undefined
    {:ok, tick} = Lifecycle.execute(unknown.object, context(unknown, 1300, :timer))
    assert tick.object.elapsed_active_time == 1
  end

  test "return to service reconciles the latest retained sample and records the actual transition" do
    stored =
      initialize(%{
        out_of_service: true,
        present_value: true,
        change_of_state_count: 0,
        interface_value: :undefined,
        elapsed_active_time: 0
      })

    {:ok, observed} = sample(stored, false, 500)
    assert observed.object.present_value
    {:ok, returned} = write(observed, :out_of_service, false, 1500)
    refute returned.object.present_value
    assert returned.object.change_of_state_count == 1
    assert returned.object.change_of_state_time == timestamp(1500)
    assert returned.object.elapsed_active_time == 1
  end

  test "unknown input preserves the logical value without inferring a reliability fault" do
    stored = initialize(%{interface_value: :undefined, reliability: :no_fault_detected})
    {:ok, active} = sample(stored, true, 100)
    {:ok, unknown} = sample(active, nil, 200)
    assert unknown.object.present_value
    assert unknown.object.interface_value == :undefined
    assert unknown.object.reliability == :no_fault_detected
    refute unknown.object.status_flags.fault
  end

  test "local logical simulation cannot overwrite an OOS value" do
    reported = initialize(%{out_of_service: true, reliability: :communication_failure})
    assert reported.object.out_of_service
    assert reported.object.reliability == :communication_failure

    stored = initialize(%{out_of_service: true})

    assert {:error, :out_of_service} =
             write(stored, :present_value, true, 100, source: :application_write)

    {:ok, observed} = sample(stored, true, 100)
    refute observed.object.present_value
    assert observed.object._metadata.physical_input
  end

  test "interface values are optional, readonly and encoded as enumerated or NULL" do
    plain = object(%{})
    refute BinaryInput.has_property?(plain, :interface_value)
    refute BinaryInput.has_property?(object(%{interface_value: nil}), :interface_value)
    {:ok, sampled} = BinaryInput.set_input(plain, true)
    refute BinaryInput.has_property?(sampled, :interface_value)
    stored = initialize(%{interface_value: :undefined})
    identifier = BinaryInput.get_object_identifier(stored.object)

    for {native, tag} <- [{:undefined, :null}, {false, :enumerated}, {true, :enumerated}] do
      assert {:ok, %Encoding{type: ^tag} = encoded} =
               ObjectsUtility.cast_value_to_property(identifier, :interface_value, native)

      assert {:ok, ^native} =
               ObjectsUtility.cast_property_to_value(identifier, :interface_value, encoded)
    end

    for invalid <- [nil, 0, 1, :unknown] do
      assert {:error, {:invalid_property_type, :interface_value}} =
               BinaryInput.update_property(stored.object, :interface_value, invalid)

      assert {:error, {:invalid_property_value, {:interface_value, ^invalid}}} =
               ObjectsUtility.cast_value_to_property(identifier, :interface_value, invalid)
    end

    for tags <- [{:enumerated, 2}, {:unsigned_integer, 1}, {:boolean, true}] do
      encoded = Encoding.create!(tags)

      assert {:error, {:invalid_property_value, {:interface_value, ^encoded}}} =
               ObjectsUtility.cast_property_to_value(identifier, :interface_value, encoded)
    end

    refute BinaryInput.property_writable?(stored.object, :interface_value)
    assert {:error, :write_access_denied} = write(stored, :interface_value, true, 100)
  end

  test "local reliability simulation remains separate from retained physical status" do
    stored = initialize(%{reliability: :process_error})
    {:ok, decoupled} = write(stored, :out_of_service, true, 100)

    assert {:ok, local} =
             write(decoupled, :reliability, :communication_failure, 200,
               source: :application_write
             )

    assert local.object.reliability == :communication_failure
    assert local.object.status_flags.fault

    {:ok, repeated} =
      write(local, :reliability, :communication_failure, 250, source: :application_write)

    assert repeated.object.reliability == :communication_failure

    {:ok, simulated} = write(repeated, :reliability, :no_fault_detected, 300)
    refute simulated.object.status_flags.fault
    {:ok, returned} = write(simulated, :out_of_service, false, 400)
    assert returned.object.reliability == :process_error
    assert returned.object.status_flags.fault
  end

  test "reliability inhibition masks automatic status and retains physical updates for resumption" do
    stored = initialize(%{reliability: :process_error, reliability_evaluation_inhibit: true})
    assert stored.object.reliability == :no_fault_detected
    refute stored.object.status_flags.fault

    {:ok, masked} =
      write(stored, :reliability, :communication_failure, 100, source: :application_write)

    assert masked.object.reliability == :no_fault_detected
    {:ok, resumed} = write(masked, :reliability_evaluation_inhibit, false, 200)
    assert resumed.object.reliability == :communication_failure
    assert resumed.object.status_flags.fault
  end

  test "inhibited OOS preserves explicitly simulated reliability and clears it on return" do
    stored = initialize(%{reliability: :process_error, reliability_evaluation_inhibit: true})
    {:ok, decoupled} = write(stored, :out_of_service, true, 100)
    assert decoupled.object.reliability == :no_fault_detected

    {:ok, simulated} =
      write(decoupled, :reliability, :communication_failure, 200, source: :application_write)

    assert simulated.object.reliability == :communication_failure
    {:ok, tick} = Lifecycle.execute(simulated.object, context(simulated, 300, :periodic))
    assert tick.object.reliability == :communication_failure
    {:ok, returned} = write(tick, :out_of_service, false, 400)
    assert returned.object.reliability == :no_fault_detected
    {:ok, resumed} = write(returned, :reliability_evaluation_inhibit, false, 500)
    assert resumed.object.reliability == :process_error
  end

  test "active fractions survive inactive intervals and reads refresh supplied-time accounting" do
    stored = initialize(%{elapsed_active_time: 0})
    {:ok, active} = sample(stored, true, 100)
    assert active.next_execution.monotonic_time == 1100
    {:ok, inactive} = sample(active, false, 850)
    assert inactive.object.elapsed_active_time == 0
    assert inactive.next_execution == nil
    {:ok, active} = sample(inactive, true, 2100)
    assert active.next_execution.monotonic_time == 2350

    {:ok, read} =
      Lifecycle.prepare_read(
        active.object,
        context(active, 2450, {:property_read, :elapsed_active_time, nil})
      )

    assert read.object.elapsed_active_time == 1
    assert read.next_execution.monotonic_time == 3350
    {:ok, repeated} = Lifecycle.execute(read.object, context(read, 2450, :timer))
    assert repeated.object.elapsed_active_time == 1
  end

  test "wall corrections and late timers do not distort monotonic active seconds" do
    stored = initialize(%{elapsed_active_time: 8, present_value: true})
    ctx = %{context(stored, 10_750, :clock_change) | now: DateTime.add(@now, -86_400)}
    {:ok, late} = Lifecycle.execute(stored.object, ctx)
    assert late.object.elapsed_active_time == 18
    assert late.next_execution.monotonic_time == 11_000
  end

  test "zero writes stamp reset times including repeats; nonzero totals and timestamp edits do not reset" do
    stored = initialize(%{change_of_state_count: 0, elapsed_active_time: 0})

    for {property, reset} <- [
          change_of_state_count: :time_of_state_count_reset,
          elapsed_active_time: :time_of_active_time_reset
        ] do
      {:ok, first} = write(stored, property, 0, 100)
      assert Map.fetch!(first.object, reset) == timestamp(100)
      {:ok, repeated} = write(first, property, 0, 200)
      assert Map.fetch!(repeated.object, reset) == timestamp(200)
      {:ok, set} = write(repeated, property, 42, 300)
      assert Map.fetch!(set.object, property) == 42
      assert Map.fetch!(set.object, reset) == timestamp(200)
      {:ok, stamp} = write(set, reset, timestamp(-1000), 400)
      assert Map.fetch!(stamp.object, property) == 42
    end
  end

  test "active-time total replacement clears fractional accumulation" do
    stored = initialize(%{present_value: true, elapsed_active_time: 0})
    {:ok, tick} = Lifecycle.execute(stored.object, context(stored, 750, :timer))
    {:ok, reset} = write(tick, :elapsed_active_time, 0, 800)
    assert reset.next_execution.monotonic_time == 1800
    {:ok, tick} = Lifecycle.execute(reset.object, context(reset, 1799, :timer))
    assert tick.object.elapsed_active_time == 0
    {:ok, tick} = Lifecycle.execute(tick.object, context(tick, 1800, :timer))
    assert tick.object.elapsed_active_time == 1
  end

  test "state counts keep their existing range and active seconds wrap without reset stamps" do
    stored = initialize(%{change_of_state_count: 0xFFFFFFFF, elapsed_active_time: 0xFFFFFFFF})
    {:ok, active} = sample(stored, true, 100)
    assert active.object.change_of_state_count == 0x100000000
    {:ok, tick} = Lifecycle.execute(active.object, context(active, 1100, :timer))
    assert tick.object.elapsed_active_time == 0
    assert tick.object.time_of_active_time_reset == stored.object.time_of_active_time_reset
  end

  test "numeric zero-write triggers identify the correct reset" do
    stored = initialize(%{change_of_state_count: 0})
    {:ok, candidate} = BinaryInput.update_property(stored.object, :change_of_state_count, 0)
    ctx = context(stored, 100, {:property_write, 15, nil, nil})
    {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, ctx)
    {:ok, result} = Lifecycle.execute(prepared, ctx)
    assert result.object.time_of_state_count_reset == timestamp(100)
  end

  test "preparation is pure, updates related interface, and does not mutate prior state" do
    stored = initialize(%{interface_value: :undefined, change_of_state_count: 0})
    {:ok, candidate} = BinaryInput.set_input(stored.object, true)
    ctx = context(stored, 100, {:application_write, :present_value, nil, nil})
    {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, ctx)
    assert prepared.interface_value
    refute stored.object.present_value
    assert stored.object._metadata.physical_input == nil
    assert stored.state.history.value == false
    {:ok, result} = Lifecycle.execute(prepared, ctx)
    assert result.object.change_of_state_count == 1
  end

  test "adding and removing accounting groups starts and stops accounting at that operation" do
    stored = initialize(%{present_value: true})
    {:ok, candidate} = BinaryInput.add_property(stored.object, :elapsed_active_time, 5)
    {:ok, added} = Lifecycle.execute(candidate, context(stored, 5000, :periodic))
    assert added.object.elapsed_active_time == 5
    {:ok, candidate} = BinaryInput.remove_property(added.object, :elapsed_active_time)
    {:ok, removed} = Lifecycle.execute(candidate, context(added, 6500, :periodic))
    assert removed.next_execution == nil
  end

  test "restart preserves totals without credit for another VM's monotonic time" do
    stored = initialize(%{elapsed_active_time: 0, change_of_state_count: 0})
    {:ok, active} = sample(stored, true, 100)
    {:ok, tick} = Lifecycle.execute(active.object, context(active, 2100, :timer))
    {:ok, restarted} = Lifecycle.execute(tick.object, context(nil, -9000, :initialization))
    assert restarted.object.elapsed_active_time == 2
    assert restarted.object.change_of_state_count == 1
    assert restarted.next_execution.monotonic_time == -8000
  end

  test "invalid or cross-object state and backwards monotonic samples are rejected" do
    stored = initialize(%{})

    assert {:error, :invalid_execution_state} =
             Lifecycle.execute(stored.object, context(nil, 1, :timer))

    assert {:error, :invalid_execution_state} =
             Lifecycle.execute(stored.object, context(stored, -1, :clock_change))

    for state <- [
          :bad,
          %{stored.state | physical_reliability: :invalid},
          %{stored.state | physical_reliability: 1},
          %{stored.state | history: %{stored.state.history | active_remainder: 1000}},
          %{
            stored.state
            | history: %{
                stored.state.history
                | identifier: %ObjectIdentifier{type: :binary_input, instance: 99}
              }
          }
        ] do
      assert {:error, :invalid_execution_state} =
               Lifecycle.execute(
                 stored.object,
                 %{context(stored, 100, :timer) | state: state}
               )
    end

    {:ok, output} = BinaryOutput.create(10, "Output")
    {:ok, output} = Lifecycle.execute(output, context(nil, 0, :initialization))

    assert {:error, :invalid_execution_state} =
             Lifecycle.execute(
               stored.object,
               %{context(stored, 100, :timer) | state: output.state}
             )
  end

  test "intrinsic reporting records a transition alongside core history" do
    object =
      object(
        %{
          change_of_state_count: 0,
          elapsed_active_time: 0,
          alarm_value: true,
          time_delay: 0,
          event_detection_enable: true
        },
        intrinsic_reporting: true
      )

    {:ok, stored} = Lifecycle.execute(object, context(nil, 0, :initialization))
    {:ok, active} = sample(stored, true, 100)
    assert active.object.present_value
    assert active.object.change_of_state_count == 1
    assert active.object.event_state == :offnormal
    assert active.object.status_flags.in_alarm

    assert %{to_state: :offnormal, enabled: false, routing: nil} =
             EventReporting.transition(active)

    refute BinaryInput.property_writable?(object, :event_state)
    assert {:error, :write_access_denied} = write(stored, :event_state, :fault, 50)
    invalid = %{context(stored, 50, :timer) | state: %{stored.state | reporting: :invalid}}
    assert {:error, :invalid_execution_state} = BinaryInput.execute(stored.object, invalid)
    {:ok, tick} = Lifecycle.execute(active.object, context(active, 1100, :timer))
    assert tick.object.elapsed_active_time == 1
    assert EventReporting.transition(tick) == nil
  end

  test "both alarm delays restart after interruption and use monotonic time" do
    object =
      object(%{alarm_value: true, time_delay: 2, time_delay_normal: 1}, intrinsic_reporting: true)

    {:ok, initial} = BinaryInput.execute(object, context(nil, 0, :initialization))
    {:ok, pending} = sample(initial, true, 100)
    assert pending.next_execution.monotonic_time == 2100
    {:ok, cancelled} = sample(pending, false, 500)
    assert cancelled.next_execution == nil
    {:ok, pending} = sample(cancelled, true, 700)
    assert pending.next_execution.monotonic_time == 2700

    early = %{context(pending, 2100, :timer) | now: DateTime.add(@now, 100_000, :second)}
    assert {:ok, early} = BinaryInput.execute(pending.object, early)
    assert EventReporting.transition(early) == nil
    assert early.next_execution.monotonic_time == 2700
    assert {:ok, alarm} = BinaryInput.execute(early.object, context(early, 2700, :timer))

    assert %{
             event_type: :change_of_state,
             to_state: :offnormal,
             event_values: %NotificationParameters.ChangeOfState{
               new_state: %PropertyState{type: :binary_value, value: true}
             }
           } =
             EventReporting.transition(alarm)

    {:ok, pending} = sample(alarm, false, 2800)
    assert pending.next_execution.monotonic_time == 3800
    {:ok, cancelled} = sample(pending, true, 3000)
    assert cancelled.next_execution == nil
    {:ok, pending} = sample(cancelled, false, 3100)
    assert pending.next_execution.monotonic_time == 4100
    assert {:ok, normal} = BinaryInput.execute(pending.object, context(pending, 4100, :timer))
    assert %{transition: :to_normal, to_state: :normal} = EventReporting.transition(normal)
    refute normal.object.status_flags.in_alarm
  end

  test "initialization restores an offnormal input and evaluates recovery from the current reading" do
    properties = %{event_state: :offnormal, alarm_value: true, time_delay_normal: 2}
    active = object(Map.put(properties, :present_value, true), intrinsic_reporting: true)
    cleared = object(Map.put(properties, :present_value, false), intrinsic_reporting: true)

    assert {:ok, stored} = BinaryInput.execute(active, context(nil, 100, :initialization))
    assert stored.object.event_state == :offnormal
    assert EventReporting.transition(stored) == nil
    assert stored.next_execution == nil

    assert {:ok, pending} = BinaryInput.execute(cleared, context(nil, 100, :initialization))
    assert pending.object.event_state == :offnormal
    assert EventReporting.transition(pending) == nil
    assert pending.next_execution.monotonic_time == 2100

    assert {:ok, normal} =
             BinaryInput.execute(pending.object, context(pending, 2100, :timer))

    assert %{from_state: :offnormal, to_state: :normal} = EventReporting.transition(normal)
  end

  test "history ticks retain a pending alarm and request the earliest deadline" do
    object =
      object(%{alarm_value: true, elapsed_active_time: 0, time_delay: 2},
        intrinsic_reporting: true
      )

    {:ok, initial} = BinaryInput.execute(object, context(nil, 0, :initialization))
    {:ok, pending} = sample(initial, true, 100)
    assert pending.next_execution.monotonic_time == 1100
    {:ok, tick} = BinaryInput.execute(pending.object, context(pending, 1100, :timer))
    assert tick.object.elapsed_active_time == 1
    assert tick.next_execution.monotonic_time == 2100
    assert EventReporting.transition(tick) == nil
    {:ok, alarm} = BinaryInput.execute(tick.object, context(tick, 2100, :timer))
    assert alarm.object.elapsed_active_time == 2
    assert %{to_state: :offnormal} = EventReporting.transition(alarm)
    assert alarm.next_execution.monotonic_time == 3100
  end

  test "inhibition cancels delays, clears alarms and restarts timing after release" do
    object = object(%{alarm_value: true, time_delay: 1}, intrinsic_reporting: true)
    {:ok, initial} = BinaryInput.execute(object, context(nil, 0, :initialization))
    {:ok, pending} = sample(initial, true, 100)
    {:ok, inhibited} = write(pending, :event_algorithm_inhibit, true, 200)
    assert inhibited.next_execution == nil
    {:ok, released} = write(inhibited, :event_algorithm_inhibit, false, 300)
    assert released.next_execution.monotonic_time == 1300
    {:ok, alarm} = BinaryInput.execute(released.object, context(released, 1300, :timer))
    {:ok, cleared} = write(alarm, :event_algorithm_inhibit, true, 1400)
    assert %{to_state: :normal} = EventReporting.transition(cleared)

    {:ok, disabled} = write(alarm, :event_detection_enable, false, 1400)
    assert disabled.object.event_state == :normal

    assert disabled.object.event_timestamps.to_offnormal ==
             ObjectsMacro.get_default_bacnet_timestamp()

    assert disabled.object.event_message_texts.to_offnormal == ""
    assert disabled.object.acked_transitions.to_offnormal
    assert EventReporting.transition(disabled) == nil
  end

  test "linked inhibition follows a local property and holds its value if a read fails" do
    reference = %ObjectPropertyRef{
      object_identifier: %ObjectIdentifier{type: :binary_value, instance: 25},
      property_identifier: :present_value,
      property_array_index: nil
    }

    object =
      object(%{alarm_value: true, present_value: true, event_algorithm_inhibit_ref: reference},
        intrinsic_reporting: true
      )

    ctx = %{
      context(nil, 0, :initialization)
      | read_property: fn ref ->
          assert %DeviceObjectPropertyRef{object_identifier: id, device_identifier: nil} = ref
          assert id == reference.object_identifier
          {:ok, true}
        end
    }

    assert {:ok, inhibited} = BinaryInput.execute(object, ctx)
    assert inhibited.object.event_algorithm_inhibit
    assert inhibited.object.event_state == :normal
    ctx = %{context(inhibited, 100, :periodic) | read_property: fn _ref -> {:error, :timeout} end}
    assert {:ok, still_inhibited} = BinaryInput.execute(inhibited.object, ctx)
    assert still_inhibited.object.event_algorithm_inhibit
    assert EventReporting.transition(still_inhibited) == nil
    ctx = %{context(still_inhibited, 200, :periodic) | read_property: fn _ref -> {:ok, false} end}
    assert {:ok, alarm} = BinaryInput.execute(still_inhibited.object, ctx)
    assert %{to_state: :offnormal} = EventReporting.transition(alarm)
  end

  test "faults take precedence over alarms and recovery starts a new alarm delay" do
    object =
      object(
        %{alarm_value: true, present_value: true, time_delay: 2, reliability: :no_fault_detected},
        intrinsic_reporting: true
      )

    {:ok, pending} = BinaryInput.execute(object, context(nil, 0, :initialization))
    {:ok, fault} = write(pending, :reliability, :no_sensor, 100)

    assert %{
             to_state: :fault,
             event_type: :change_of_reliability,
             event_values: %NotificationParameters.ChangeOfReliability{property_values: [value]}
           } = EventReporting.transition(fault)

    assert value.property_identifier == :present_value
    assert %Encoding{type: :enumerated, value: 1} = value.property_value
    assert fault.next_execution == nil
    {:ok, repeated} = write(fault, :reliability, :no_sensor, 200)
    assert EventReporting.transition(repeated) == nil
    {:ok, changed} = write(repeated, :reliability, :open_loop, 300)
    assert %{from_state: :fault, to_state: :fault} = EventReporting.transition(changed)
    {:ok, cleared} = write(changed, :reliability, :no_fault_detected, 400)
    assert %{transition: :to_normal} = EventReporting.transition(cleared)
    assert cleared.next_execution == :immediate
    {:ok, pending} = BinaryInput.execute(cleared.object, context(cleared, 400, :continuation))
    assert pending.next_execution.monotonic_time == 2400
    assert EventReporting.transition(pending) == nil
  end

  test "a host delivers a routed alarm after commit and acknowledges its timestamp" do
    transitions = EventTransitionBits.from_bitstring({true, false, false})
    device = %ObjectIdentifier{type: :device, instance: 2}

    destination = %Destination{
      recipient: %Recipient{type: :device, device: device, address: nil},
      process_identifier: 17,
      issue_confirmed_notifications: false,
      transitions: transitions,
      valid_days: DaysOfWeek.from_bitstring({true, true, true, true, true, true, true}),
      from_time: BACnetTime.from_time(~T[00:00:00]),
      to_time: BACnetTime.from_time(~T[23:59:59])
    }

    {:ok, class} =
      NotificationClass.create(7, "Alarms", %{
        notification_class: 7,
        recipient_list: [destination],
        ack_required: transitions
      })

    object =
      object(
        %{
          alarm_value: true,
          notification_class: 7,
          event_enable: transitions,
          out_of_service: true
        },
        intrinsic_reporting: true
      )

    identifier = BinaryInput.get_object_identifier(object)

    host =
      Host.new([{object, []}, {class, []}], @now, 0,
        after_commit: fn host, id, result ->
          if id == identifier do
            assert Host.snapshot(host, id).object == result.object
            deliver_transition(result, id)
          end
        end
      )

    assert :ok = Host.execute(host, identifier, :initialization)

    reference = %DeviceObjectPropertyRef{
      device_identifier: nil,
      object_identifier: identifier,
      property_identifier: :present_value,
      property_array_index: nil
    }

    Host.advance(host, DateTime.add(@now, 1, :second), 1000)
    assert :ok = Host.write(host, reference, true)
    assert_received {:notification, ^device, notification}
    assert notification.event_object == identifier
    assert notification.process_identifier == 17
    assert notification.to_state == :offnormal
    assert notification.ack_required
    assert notification.event_values.status_flags.out_of_service
    recorded = Host.snapshot(host, identifier).object
    refute recorded.acked_transitions.to_offnormal
    assert notification.timestamp == recorded.event_timestamps.to_offnormal

    assert {:ok, acknowledged} =
             EventReporting.acknowledge(recorded, :to_offnormal, notification.timestamp)

    assert acknowledged.acked_transitions.to_offnormal

    assert {:error, {:services, :invalid_timestamp}} =
             EventReporting.acknowledge(recorded, :to_normal, notification.timestamp)

    assert {:ok, true} = Host.read(host, reference)
    assert :ok = Host.write(host, reference, true)
    refute_received {:notification, _device, _notification}
  end

  test "remote snapshots remain passive" do
    object =
      object(
        %{
          present_value: false,
          polarity: :normal,
          out_of_service: false,
          event_state: :normal,
          status_flags: %BACnet.Protocol.StatusFlags{
            in_alarm: false,
            fault: false,
            overridden: false,
            out_of_service: false
          }
        },
        remote_object: 42
      )

    ctx = %{context(nil, 0, :periodic) | state: :remote}

    assert {:ok, %Result{object: ^object, state: :remote, next_execution: nil}} =
             Lifecycle.execute(object, ctx)

    assert {:ok, %Result{object: ^object, state: :remote, next_execution: nil}} =
             BinaryInput.execute(object, ctx)

    assert :ok = BinaryInput.validate_execution(object, ctx)

    assert {:error, :operation_not_available_for_remote_objects} =
             BinaryInput.set_input(object, true)

    write_context = %{ctx | trigger: {:property_write, :present_value, nil, nil}}

    assert {:error, :operation_not_available_for_remote_objects} =
             BinaryInput.prepare_write(object, object, write_context)

    assert {:error, :operation_not_available_for_remote_objects} =
             Lifecycle.prepare_write(object, object, write_context)
  end

  test "write access is checked against the original service state" do
    stored = initialize(%{})
    {:ok, candidate} = BinaryInput.update_property(stored.object, :out_of_service, true)
    {:ok, candidate} = BinaryInput.update_property(candidate, :present_value, true)

    assert {:error, :write_access_denied} =
             Lifecycle.prepare_write(
               stored.object,
               candidate,
               context(stored, 100, {:property_write, :present_value, nil, nil})
             )
  end

  test "unknown interface selection is retained at creation and when added later" do
    created = object(%{interface_value: :undefined})
    assert BinaryInput.has_property?(created, :interface_value)
    assert created.interface_value == :undefined
    {:ok, added} = BinaryInput.add_property(object(%{}), :interface_value, :undefined)
    assert BinaryInput.has_property?(added, :interface_value)
    assert added.interface_value == :undefined
    {:ok, initialized} = Lifecycle.execute(added, context(nil, 0, :initialization))
    assert initialized.object.interface_value == :undefined
    {:ok, sampled} = BinaryInput.set_input(added, true)
    assert sampled.interface_value
  end

  defp object(properties, options \\ []) do
    {:ok, object} = BinaryInput.create(10, "Input", properties, options)
    object
  end

  defp deliver_transition(result, identifier) do
    case EventReporting.transition(result) do
      %{enabled: true, routing: %{destinations: destinations} = routing} = transition ->
        for destination <- destinations do
          notification = %UnconfirmedEventNotification{
            process_identifier: destination.process_identifier,
            initiating_device: %ObjectIdentifier{type: :device, instance: 1},
            event_object: identifier,
            timestamp: transition.timestamp,
            notification_class: transition.notification_class,
            priority: routing.priority,
            event_type: transition.event_type,
            message_text: transition.message_text,
            notify_type: transition.notify_type,
            ack_required: routing.ack_required,
            from_state: transition.from_state,
            to_state: transition.to_state,
            event_values: transition.event_values
          }

          {:ok, apdu} = UnconfirmedEventNotification.to_apdu(notification, [])
          {:ok, decoded} = UnconfirmedEventNotification.from_apdu(apdu)
          send(self(), {:notification, destination.recipient.device, decoded})
        end

      _other ->
        :ok
    end
  end

  defp initialize(properties) do
    {:ok, result} = Lifecycle.execute(object(properties), context(nil, 0, :initialization))
    result
  end

  defp timestamp(milliseconds),
    do: BACnetDateTime.from_datetime(DateTime.add(@now, milliseconds, :millisecond))

  defp context(stored, milliseconds, trigger) do
    Context.new(trigger,
      now: DateTime.add(@now, milliseconds, :millisecond),
      monotonic_time: milliseconds,
      state: if(stored, do: stored.state),
      read_property: fn _reference -> flunk("must not read") end,
      write_property: fn _reference, _value, _priority ->
        flunk("must not write other objects")
      end
    )
  end

  defp assert_history(object) do
    for property <- [:change_of_state_count, :change_of_state_time, :time_of_state_count_reset],
        do: assert(BinaryInput.has_property?(object, property))
  end

  defp sample(stored, raw, milliseconds) do
    ctx = context(stored, milliseconds, {:application_write, :present_value, nil, nil})

    with {:ok, candidate} <- BinaryInput.set_input(stored.object, raw),
         {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
      Lifecycle.execute(prepared, ctx)
    end
  end

  defp write(stored, property, value, milliseconds, options \\ []) do
    source = Keyword.get(options, :source, :property_write)
    ctx = context(stored, milliseconds, {source, property, nil, Keyword.get(options, :priority)})

    with {:ok, candidate} <- BinaryInput.update_property(stored.object, property, value),
         {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
      Lifecycle.execute(prepared, ctx)
    end
  end
end
