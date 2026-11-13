defmodule BACnet.Test.Protocol.ObjectTypes.BinaryValueTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.DaysOfWeek
  alias BACnet.Protocol.Destination
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.EventTransitionBits
  alias BACnet.Protocol.NotificationParameters
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectPropertyRef
  alias BACnet.Protocol.ObjectsMacro
  alias BACnet.Protocol.ObjectTypes.BinaryValue
  alias BACnet.Protocol.ObjectTypes.NotificationClass
  alias BACnet.Protocol.PropertyState
  alias BACnet.Protocol.Recipient
  alias BACnet.Protocol.Services.UnconfirmedEventNotification
  alias BACnet.Test.Support.Protocol.ObjectExecutionTestHost, as: Host

  use ExUnit.Case, async: true

  doctest BinaryValue

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_binary_value

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "create/4 priority array overrides given present value" do
    assert {:ok, %BinaryValue{present_value: false}} =
             BinaryValue.create(1, "TEST", %{present_value: true, relinquish_default: false})
  end

  test "add_property/3 priority array overrides given present value" do
    {:ok, %BinaryValue{present_value: false} = obj} =
      BinaryValue.create(1, "TEST", %{present_value: false})

    assert {:ok, %BinaryValue{present_value: true}} =
             BinaryValue.add_property(obj, :relinquish_default, true)
  end

  @now ~U[2026-11-08 10:00:00Z]

  test "each transition-history member selects the entire group and removal removes the group" do
    values = [
      change_of_state_count: 7,
      change_of_state_time: timestamp(0),
      time_of_state_count_reset: timestamp(0)
    ]

    for {property, value} <- values do
      {:ok, object} = BinaryValue.create(10, "Flag", %{property => value})
      assert_history_group(object)
      {:ok, plain} = BinaryValue.create(11, "Plain")
      {:ok, added} = BinaryValue.add_property(plain, property, value)
      assert_history_group(added)
      {:ok, removed} = BinaryValue.remove_property(added, property)
      for key <- Keyword.keys(values), do: refute(BinaryValue.has_property?(removed, key))
    end
  end

  test "initialization preserves historical totals without inventing a transition or hold" do
    object =
      object(%{
        change_of_state_count: 9,
        elapsed_active_time: 15,
        relinquish_default: true,
        min_on_time: 10
      })

    {:ok, initialized} = Lifecycle.execute(object, context(nil, -4000, :initialization))
    assert initialized.object.present_value
    assert initialized.object.change_of_state_count == 9
    assert initialized.object.elapsed_active_time == 15
    assert initialized.object.change_of_state_time == object.change_of_state_time
    assert initialized.object.time_of_state_count_reset == object.time_of_state_count_reset
    assert initialized.object.time_of_active_time_reset == object.time_of_active_time_reset
    assert initialized.object.priority_array.priority_6 == nil
    assert initialized.next_execution == %Wakeup{wall_time: nil, monotonic_time: -3000}
  end

  test "only actual effective transitions change count and timestamp" do
    stored = initialize(%{change_of_state_count: 0})
    {:ok, active} = write(stored, :present_value, true, 500)
    assert active.object.change_of_state_count == 1
    assert active.object.change_of_state_time == timestamp(500)
    {:ok, same} = write(active, :present_value, true, 800)
    assert same.object.change_of_state_count == 1
    assert same.object.change_of_state_time == active.object.change_of_state_time
    {:ok, inactive} = write(same, :present_value, false, 1200)
    assert inactive.object.change_of_state_count == 2
    assert inactive.object.change_of_state_time == timestamp(1200)
  end

  test "active seconds retain fractional remainder across inactive intervals and refresh on reads" do
    stored = initialize(%{elapsed_active_time: 0})
    {:ok, active} = write(stored, :present_value, true, 100)
    assert active.next_execution.monotonic_time == 1100
    {:ok, inactive} = write(active, :present_value, false, 850)
    assert inactive.object.elapsed_active_time == 0
    assert inactive.next_execution == nil
    {:ok, active} = write(inactive, :present_value, true, 2100)
    assert active.next_execution.monotonic_time == 2350

    {:ok, read} =
      Lifecycle.prepare_read(
        active.object,
        context(active, 2450, {:property_read, :elapsed_active_time, nil})
      )

    assert read.object.elapsed_active_time == 1
    assert read.next_execution.monotonic_time == 3350
    {:ok, repeated} = Lifecycle.execute(read.object, context(read, 2450, :periodic))
    assert repeated.object.elapsed_active_time == 1
    assert repeated.next_execution == read.next_execution
  end

  test "late wakeups accrue every elapsed second and wall corrections do not change duration" do
    stored = initialize(%{elapsed_active_time: 8, present_value: true})
    ctx = %{context(stored, 10_750, :clock_change) | now: DateTime.add(@now, -86_400)}
    {:ok, updated} = Lifecycle.execute(stored.object, ctx)
    assert updated.object.elapsed_active_time == 18
    assert updated.next_execution.monotonic_time == 11_000
  end

  test "zero total writes stamp reset times even for same-value writes" do
    stored = initialize(%{change_of_state_count: 0, elapsed_active_time: 0})

    for {property, reset_property} <- [
          change_of_state_count: :time_of_state_count_reset,
          elapsed_active_time: :time_of_active_time_reset
        ] do
      {:ok, first} = write(stored, property, 0, 50)
      assert Map.fetch!(first.object, reset_property) == timestamp(50)
      {:ok, second} = write(first, property, 0, 1250)
      assert Map.fetch!(second.object, reset_property) == timestamp(1250)
    end
  end

  test "nonzero total writes preserve reset timestamps and reset timestamps are writable" do
    stored = initialize(%{change_of_state_count: 4, elapsed_active_time: 10})

    for {property, reset_property} <- [
          change_of_state_count: :time_of_state_count_reset,
          elapsed_active_time: :time_of_active_time_reset
        ] do
      {:ok, edited} = write(stored, reset_property, timestamp(-1000), 10)
      {:ok, updated} = write(edited, property, 42, 20)
      assert Map.fetch!(updated.object, property) == 42
      assert Map.fetch!(updated.object, reset_property) == timestamp(-1000)
    end
  end

  test "active-time replacement discards old fractional time and starts from the write" do
    stored = initialize(%{elapsed_active_time: 0, present_value: true})
    {:ok, tick} = Lifecycle.execute(stored.object, context(stored, 750, :periodic))
    {:ok, reset} = write(tick, :elapsed_active_time, 0, 800)
    assert reset.object.time_of_active_time_reset == timestamp(800)
    assert reset.next_execution.monotonic_time == 1800
    {:ok, tick} = Lifecycle.execute(reset.object, context(reset, 1799, :timer))
    assert tick.object.elapsed_active_time == 0
    {:ok, tick} = Lifecycle.execute(tick.object, context(tick, 1800, :timer))
    assert tick.object.elapsed_active_time == 1
  end

  test "32-bit counters wrap without producing reset timestamps" do
    stored = initialize(%{change_of_state_count: 0xFFFFFFFF, elapsed_active_time: 0xFFFFFFFF})
    {:ok, active} = write(stored, :present_value, true, 1)
    assert active.object.change_of_state_count == 0
    assert active.object.time_of_state_count_reset == stored.object.time_of_state_count_reset
    {:ok, tick} = Lifecycle.execute(active.object, context(active, 1001, :timer))
    assert tick.object.elapsed_active_time == 0
    assert tick.object.time_of_active_time_reset == stored.object.time_of_active_time_reset
  end

  test "a commandable transition starts a priority-6 hold and stores lower-priority commands" do
    stored =
      initialize(%{
        relinquish_default: false,
        min_on_time: 3,
        min_off_time: 2,
        change_of_state_count: 0
      })

    {:ok, active} = write(stored, :present_value, true, 100, priority: 8)
    assert active.object.priority_array.priority_6 == true
    assert active.object.change_of_state_count == 1
    assert active.next_execution.monotonic_time == 3100
    {:ok, pending} = write(active, :present_value, false, 500, priority: 8)
    assert pending.object.present_value
    assert pending.object.priority_array.priority_8 == false
    assert pending.object.change_of_state_count == 1
    assert pending.next_execution == active.next_execution
    {:ok, early} = Lifecycle.execute(pending.object, context(pending, 3099, :timer))
    assert early.object.present_value
    {:ok, expired} = Lifecycle.execute(early.object, context(early, 3100, :timer))
    refute expired.object.present_value
    assert expired.object.priority_array.priority_6 == false
    assert expired.object.change_of_state_count == 2
    assert expired.next_execution.monotonic_time == 5100
    {:ok, released} = Lifecycle.execute(expired.object, context(expired, 5100, :timer))
    assert released.object.priority_array.priority_6 == nil
    assert released.next_execution == nil
  end

  test "priority 1 through 5 may override holds and start a new hold" do
    for priority <- 1..5 do
      stored = initialize(%{relinquish_default: false, min_on_time: 2, min_off_time: 3})
      {:ok, active} = write(stored, :present_value, true, 100, priority: 16)
      {:ok, override} = write(active, :present_value, false, 200, priority: priority)
      refute override.object.present_value
      assert override.object.priority_array.priority_6 == false
      assert override.next_execution.monotonic_time == 3200
      {:ok, relinquished} = write(override, :present_value, nil, 300, priority: priority)
      refute relinquished.object.present_value
      assert relinquished.next_execution.monotonic_time == 3200
      {:ok, resumed} = Lifecycle.execute(relinquished.object, context(relinquished, 3200, :timer))
      assert resumed.object.present_value
      assert resumed.object.priority_array.priority_6 == true
      assert resumed.next_execution.monotonic_time == 5200
    end
  end

  test "a hold expiry and a new command use current priorities in the same operation" do
    stored = initialize(%{relinquish_default: false, min_on_time: 2, min_off_time: 2})
    {:ok, active} = write(stored, :present_value, true, 100, priority: 16)
    {:ok, pending} = write(active, :present_value, false, 200, priority: 16)
    {:ok, current} = write(pending, :present_value, true, 2100, priority: 16)
    assert current.object.present_value
    assert current.object.priority_array.priority_6 == nil
    assert current.next_execution == nil
  end

  test "relinquishment and relinquish-default changes respect minimum protection" do
    stored = initialize(%{relinquish_default: false, min_on_time: 2, min_off_time: 2})
    {:ok, active} = write(stored, :present_value, true, 10)
    {:ok, relinquished} = write(active, :present_value, nil, 20)
    assert relinquished.object.priority_array.priority_16 == nil
    assert relinquished.object.present_value
    {:ok, changed_default} = write(relinquished, :relinquish_default, true, 30)

    {:ok, expired} =
      Lifecycle.execute(changed_default.object, context(changed_default, 2010, :timer))

    assert expired.object.present_value
    assert expired.object.priority_array.priority_6 == nil
  end

  test "changing a minimum time uses the original transition time" do
    stored = initialize(%{relinquish_default: false, min_on_time: 5})
    {:ok, active} = write(stored, :present_value, true, 100)
    {:ok, pending} = write(active, :present_value, false, 200)
    {:ok, shortened} = write(pending, :min_on_time, 1, 2100)
    refute shortened.object.present_value
    assert shortened.next_execution == nil
  end

  test "unconfigured and zero minimum times do not create a hold" do
    for properties <- [%{relinquish_default: false}, %{relinquish_default: false, min_on_time: 0}] do
      stored = initialize(properties)
      {:ok, active} = write(stored, :present_value, true, 100)
      assert active.object.priority_array.priority_6 == nil
      assert active.next_execution == nil
    end
  end

  test "priority 6 is rejected with or without configured minimum times" do
    for properties <- [%{relinquish_default: false}, %{relinquish_default: false, min_on_time: 3}] do
      stored = initialize(properties)
      assert {:error, :write_access_denied} = BinaryValue.set_priority(stored.object, 6, true)

      assert {:error, :write_access_denied} =
               Lifecycle.prepare_write(
                 stored.object,
                 stored.object,
                 context(stored, 100, {:property_write, 85, nil, 6})
               )
    end
  end

  test "non-commandable minimum times reject conflicting writes without creating an array" do
    stored = initialize(%{min_on_time: 2, min_off_time: 1, change_of_state_count: 0})
    {:ok, active} = write(stored, :present_value, true, 100)
    assert {:error, {:minimum_time_active, 2100}} = write(active, :present_value, false, 200)
    {:ok, same} = write(active, :present_value, true, 300)
    assert same.next_execution.monotonic_time == 2100
    refute BinaryValue.has_priority_array?(same.object)
    {:ok, expired} = Lifecycle.execute(same.object, context(same, 2100, :timer))
    assert expired.object.present_value
    assert expired.next_execution == nil
    {:ok, inactive} = write(expired, :present_value, false, 2100)
    assert inactive.object.change_of_state_count == 2
    assert inactive.next_execution.monotonic_time == 3100
  end

  test "out of service blocks application writes and preserves network commands and accounting" do
    for properties <- [%{}, %{relinquish_default: false}] do
      stored =
        initialize(
          Map.merge(properties, %{
            out_of_service: true,
            change_of_state_count: 0,
            elapsed_active_time: 0
          })
        )

      assert {:error, :out_of_service} =
               write(stored, :present_value, true, 100, source: :application_write)

      {:ok, network} = write(stored, :present_value, true, 100)
      assert network.object.present_value
      assert network.object.status_flags.out_of_service
      assert network.object.change_of_state_count == 1
      {:ok, tick} = Lifecycle.execute(network.object, context(network, 1100, :timer))
      assert tick.object.elapsed_active_time == 1
      {:ok, in_service} = write(tick, :out_of_service, false, 1200)
      {:ok, local} = write(in_service, :present_value, false, 1300, source: :application_write)
      refute local.object.present_value
    end
  end

  test "adding history starts at the supplied time and removing it cancels its wakeup" do
    stored = initialize(%{present_value: true})
    {:ok, candidate} = BinaryValue.add_property(stored.object, :elapsed_active_time, 5)
    {:ok, added} = Lifecycle.execute(candidate, context(stored, 5000, :periodic))
    assert added.object.elapsed_active_time == 5
    assert added.next_execution.monotonic_time == 6000
    {:ok, candidate} = BinaryValue.remove_property(added.object, :elapsed_active_time)
    {:ok, removed} = Lifecycle.execute(candidate, context(added, 6500, :periodic))
    assert removed.next_execution == nil
  end

  test "restart restores a stored hold with a fresh full duration and keeps stored totals" do
    stored = initialize(%{relinquish_default: false, min_on_time: 10, change_of_state_count: 0})
    {:ok, active} = write(stored, :present_value, true, 100)
    {:ok, pending} = write(active, :present_value, nil, 200)

    restored =
      object(%{
        min_on_time: pending.object.min_on_time,
        priority_array: pending.object.priority_array,
        relinquish_default: pending.object.relinquish_default,
        change_of_state_count: pending.object.change_of_state_count,
        change_of_state_time: pending.object.change_of_state_time
      })

    {:ok, restarted} = Lifecycle.execute(restored, context(nil, -9000, :initialization))
    assert restarted.object.present_value
    assert restarted.object.priority_array.priority_6 == true
    assert restarted.object.change_of_state_count == 1
    assert restarted.next_execution.monotonic_time == 1000
    {:ok, expired} = Lifecycle.execute(restarted.object, context(restarted, 1000, :timer))
    refute expired.object.present_value
    assert expired.object.change_of_state_count == 2
  end

  test "preparing an array replacement cannot clear an active hold" do
    stored = initialize(%{relinquish_default: false, min_on_time: 2})
    {:ok, active} = write(stored, :present_value, true, 100)
    object = active.object
    array = %{object.priority_array | priority_6: nil}
    context = context(active, 200, {:application_write, :priority_array, nil, nil})

    assert {:error, {:write_access_denied, :priority_array}} =
             BinaryValue.update_property(object, :priority_array, array)

    assert {:error, {:write_access_denied, :priority_array}} =
             BinaryValue.prepare_write(object, %{object | priority_array: array}, context)
  end

  test "invalid state and backwards monotonic samples fail before changing an object" do
    stored = initialize(%{})

    assert {:error, :invalid_execution_state} =
             Lifecycle.execute(
               stored.object,
               context(nil, 100, :periodic)
             )

    assert {:error, :invalid_execution_state} =
             Lifecycle.execute(
               stored.object,
               context(stored, -1, :clock_change)
             )

    other = Map.put(object(%{}), :object_instance, 50)

    assert {:error, :invalid_execution_state} =
             Lifecycle.execute(
               other,
               context(stored, 100, :periodic)
             )

    for state <- [
          :invalid,
          %{stored.state | active_remainder: 1000},
          %{stored.state | value: nil},
          %{stored.state | count: -1}
        ] do
      assert {:error, :invalid_execution_state} =
               Lifecycle.execute(
                 stored.object,
                 %{context(stored, 100, :periodic) | state: state}
               )
    end
  end

  test "intrinsic reporting runs alongside binary history" do
    object =
      object(
        %{
          change_of_state_count: 0,
          elapsed_active_time: 0,
          min_on_time: 1,
          alarm_value: true,
          time_delay: 0,
          event_detection_enable: true
        },
        intrinsic_reporting: true
      )

    {:ok, stored} = Lifecycle.execute(object, context(nil, 0, :initialization))
    {:ok, active} = write(stored, :present_value, true, 100)
    assert active.object.present_value
    assert active.object.change_of_state_count == 1
    {:ok, tick} = BinaryValue.execute(active.object, context(active, 1100, :timer))
    assert tick.object.elapsed_active_time == 1

    assert %{event_type: :change_of_state, to_state: :offnormal} =
             EventReporting.transition(active)

    assert tick.object.event_state == :offnormal
    assert EventReporting.transition(tick) == nil
  end

  test "both alarm delays restart after interruption and use monotonic time" do
    object =
      object(%{alarm_value: true, time_delay: 2, time_delay_normal: 1}, intrinsic_reporting: true)

    {:ok, initial} = BinaryValue.execute(object, context(nil, 0, :initialization))
    {:ok, pending} = sample(initial, true, 100)
    assert pending.next_execution.monotonic_time == 2100
    {:ok, cancelled} = sample(pending, false, 500)
    assert cancelled.next_execution == nil
    {:ok, pending} = sample(cancelled, true, 700)
    assert pending.next_execution.monotonic_time == 2700

    early = %{context(pending, 2100, :timer) | now: DateTime.add(@now, 100_000, :second)}
    assert {:ok, early} = BinaryValue.execute(pending.object, early)
    assert EventReporting.transition(early) == nil
    assert early.next_execution.monotonic_time == 2700
    assert {:ok, alarm} = BinaryValue.execute(early.object, context(early, 2700, :timer))

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
    assert {:ok, normal} = BinaryValue.execute(pending.object, context(pending, 4100, :timer))
    assert %{transition: :to_normal, to_state: :normal} = EventReporting.transition(normal)
    refute normal.object.status_flags.in_alarm
  end

  test "initialization restores an offnormal input and evaluates recovery from the current reading" do
    properties = %{event_state: :offnormal, alarm_value: true, time_delay_normal: 2}
    active = object(Map.put(properties, :present_value, true), intrinsic_reporting: true)
    cleared = object(Map.put(properties, :present_value, false), intrinsic_reporting: true)

    assert {:ok, stored} = BinaryValue.execute(active, context(nil, 100, :initialization))
    assert stored.object.event_state == :offnormal
    assert EventReporting.transition(stored) == nil
    assert stored.next_execution == nil

    assert {:ok, pending} = BinaryValue.execute(cleared, context(nil, 100, :initialization))
    assert pending.object.event_state == :offnormal
    assert EventReporting.transition(pending) == nil
    assert pending.next_execution.monotonic_time == 2100

    assert {:ok, normal} =
             BinaryValue.execute(pending.object, context(pending, 2100, :timer))

    assert %{from_state: :offnormal, to_state: :normal} = EventReporting.transition(normal)
  end

  test "history ticks retain a pending alarm and request the earliest deadline" do
    object =
      object(%{alarm_value: true, elapsed_active_time: 0, time_delay: 2},
        intrinsic_reporting: true
      )

    {:ok, initial} = BinaryValue.execute(object, context(nil, 0, :initialization))
    {:ok, pending} = sample(initial, true, 100)
    assert pending.next_execution.monotonic_time == 1100
    {:ok, tick} = BinaryValue.execute(pending.object, context(pending, 1100, :timer))
    assert tick.object.elapsed_active_time == 1
    assert tick.next_execution.monotonic_time == 2100
    assert EventReporting.transition(tick) == nil
    {:ok, alarm} = BinaryValue.execute(tick.object, context(tick, 2100, :timer))
    assert alarm.object.elapsed_active_time == 2
    assert %{to_state: :offnormal} = EventReporting.transition(alarm)
    assert alarm.next_execution.monotonic_time == 3100
  end

  test "inhibition cancels delays, clears alarms and restarts timing after release" do
    object = object(%{alarm_value: true, time_delay: 1}, intrinsic_reporting: true)
    {:ok, initial} = BinaryValue.execute(object, context(nil, 0, :initialization))
    {:ok, pending} = sample(initial, true, 100)
    {:ok, inhibited} = write(pending, :event_algorithm_inhibit, true, 200)
    assert inhibited.next_execution == nil
    {:ok, released} = write(inhibited, :event_algorithm_inhibit, false, 300)
    assert released.next_execution.monotonic_time == 1300
    {:ok, alarm} = BinaryValue.execute(released.object, context(released, 1300, :timer))
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

    assert {:ok, inhibited} = BinaryValue.execute(object, ctx)
    assert inhibited.object.event_algorithm_inhibit
    assert inhibited.object.event_state == :normal
    ctx = %{context(inhibited, 100, :periodic) | read_property: fn _ref -> {:error, :timeout} end}
    assert {:ok, still_inhibited} = BinaryValue.execute(inhibited.object, ctx)
    assert still_inhibited.object.event_algorithm_inhibit
    assert EventReporting.transition(still_inhibited) == nil
    ctx = %{context(still_inhibited, 200, :periodic) | read_property: fn _ref -> {:ok, false} end}
    assert {:ok, alarm} = BinaryValue.execute(still_inhibited.object, ctx)
    assert %{to_state: :offnormal} = EventReporting.transition(alarm)
  end

  test "faults take precedence over alarms and recovery starts a new alarm delay" do
    object =
      object(
        %{alarm_value: true, present_value: true, time_delay: 2, reliability: :no_fault_detected},
        intrinsic_reporting: true
      )

    {:ok, pending} = BinaryValue.execute(object, context(nil, 0, :initialization))
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
    {:ok, pending} = BinaryValue.execute(cleared.object, context(cleared, 400, :continuation))
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

    identifier = BinaryValue.get_object_identifier(object)

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

  test "remote snapshots retain their object and runtime state without callbacks" do
    object =
      object(
        %{
          present_value: true,
          out_of_service: false,
          event_state: :normal,
          status_flags: %BACnet.Protocol.StatusFlags{
            in_alarm: false,
            fault: false,
            overridden: false,
            out_of_service: false
          }
        },
        remote_object: 123
      )

    ctx = %{
      context(nil, 0, :periodic)
      | state: :remote,
        read_property: fn _reference -> flunk("must not read") end,
        write_property: fn _reference, _value, _priority -> flunk("must not write") end
    }

    assert :ok = BinaryValue.validate_execution(object, ctx)
    write = %{ctx | trigger: {:property_write, :present_value, nil, nil}}

    assert {:error, :operation_not_available_for_remote_objects} =
             BinaryValue.prepare_write(object, object, write)

    assert {:ok, %Result{object: ^object, state: :remote, next_execution: nil}} =
             Lifecycle.execute(object, ctx)

    assert {:ok, %Result{object: ^object, state: :remote, next_execution: nil}} =
             BinaryValue.execute(object, ctx)

    assert {:error, :operation_not_available_for_remote_objects} =
             Lifecycle.prepare_write(object, object, %{
               ctx
               | trigger: {:property_write, :present_value, nil, nil}
             })
  end

  test "a host drives preparation, pending commands, timers and fresh reads" do
    object =
      object(%{
        relinquish_default: false,
        min_on_time: 2,
        min_off_time: 1,
        change_of_state_count: 0,
        elapsed_active_time: 0
      })

    identifier = BinaryValue.get_object_identifier(object)
    host = Host.new([{object, []}], @now, 0)
    assert :ok = Host.execute(host, identifier, :initialization)

    reference = %DeviceObjectPropertyRef{
      device_identifier: nil,
      object_identifier: identifier,
      property_identifier: :present_value,
      property_array_index: nil
    }

    Host.advance(host, DateTime.add(@now, 100, :millisecond), 100)
    assert :ok = Host.write(host, reference, true, 8)
    Host.advance(host, DateTime.add(@now, 200, :millisecond), 200)
    assert :ok = Host.write(host, reference, false, 8)
    assert {:ok, true} = Host.read(host, reference)
    Host.advance(host, DateTime.add(@now, 2100, :millisecond), 2100)
    assert :ok = Host.run_due(host)
    assert {:ok, false} = Host.read(host, reference)
    current = Host.snapshot(host, identifier)
    assert current.object.change_of_state_count == 2
    assert current.object.elapsed_active_time == 2
    assert current.next_execution.monotonic_time == 3100
  end

  test "preparation reserves the hold before commit and leaves original state untouched" do
    stored = initialize(%{relinquish_default: false, min_on_time: 2, change_of_state_count: 0})
    {:ok, candidate} = BinaryValue.set_priority(stored.object, 8, true)
    ctx = context(stored, 100, {:property_write, :present_value, nil, 8})
    {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, ctx)
    assert prepared.priority_array.priority_6 == true
    assert stored.object.priority_array.priority_6 == nil
    assert stored.object.present_value == false
    assert stored.state.value == false
    {:ok, updated} = BinaryValue.execute(prepared, ctx)
    assert updated.object.change_of_state_count == 1
    assert updated.next_execution.monotonic_time == 2100
  end

  test "a total reset coinciding with a hold expiry stamps reset and counts the new transition once" do
    stored = initialize(%{relinquish_default: false, min_on_time: 1, change_of_state_count: 0})
    {:ok, active} = write(stored, :present_value, true, 100)
    {:ok, pending} = write(active, :present_value, nil, 200)
    {:ok, reset} = write(pending, :change_of_state_count, 0, 1100)
    refute reset.object.present_value
    assert reset.object.change_of_state_count == 1
    assert reset.object.change_of_state_time == timestamp(1100)
    assert reset.object.time_of_state_count_reset == timestamp(1100)
  end

  test "non-commandable values ignore write priorities and numeric identifiers identify resets" do
    stored = initialize(%{change_of_state_count: 7, elapsed_active_time: 3})
    {:ok, active} = write(stored, :present_value, true, 100, priority: 6)
    assert active.object.present_value

    for {property, numeric, reset} <- [
          {:change_of_state_count, 15, :time_of_state_count_reset},
          {:elapsed_active_time, 33, :time_of_active_time_reset}
        ] do
      {:ok, candidate} = BinaryValue.update_property(active.object, property, 0)
      ctx = context(active, 200, {:property_write, numeric, nil, nil})
      {:ok, prepared} = Lifecycle.prepare_write(active.object, candidate, ctx)
      {:ok, updated} = BinaryValue.execute(prepared, ctx)
      assert Map.fetch!(updated.object, property) == 0
      assert Map.fetch!(updated.object, reset) == timestamp(200)
    end
  end

  test "local default changes cannot bypass out-of-service protection" do
    stored = initialize(%{relinquish_default: false, out_of_service: true})

    assert {:error, :out_of_service} =
             write(stored, :relinquish_default, true, 100, source: :application_write)

    {:ok, network} = write(stored, :relinquish_default, true, 100)
    assert network.object.present_value
  end

  test "OOS reliability simulation is available from both origins with optional commandability" do
    for capabilities <- [%{}, %{relinquish_default: false}],
        source <- [:application_write, :property_write] do
      stored =
        initialize(
          Map.merge(capabilities, %{out_of_service: true, reliability: :no_fault_detected})
        )

      assert {:ok, simulated} = write(stored, :reliability, :process_error, 100, source: source)
      assert simulated.object.reliability == :process_error
      assert simulated.object.status_flags.fault
      refute simulated.object.present_value
    end
  end

  defp assert_history_group(object) do
    for property <- [:change_of_state_time, :change_of_state_count, :time_of_state_count_reset],
        do: assert(BinaryValue.has_property?(object, property))
  end

  defp object(properties, options \\ []) do
    {:ok, object} = BinaryValue.create(10, "Flag", properties, options)
    object
  end

  defp initialize(properties) do
    {:ok, result} = Lifecycle.execute(object(properties), context(nil, 0, :initialization))
    result
  end

  defp context(stored, time, trigger) do
    Context.new(trigger,
      now: DateTime.add(@now, time, :millisecond),
      monotonic_time: time,
      state: if(stored, do: stored.state)
    )
  end

  defp timestamp(time), do: BACnetDateTime.from_datetime(DateTime.add(@now, time, :millisecond))

  defp write(stored, property, value, time, options \\ []) do
    source = Keyword.get(options, :source, :property_write)
    priority = Keyword.get(options, :priority)
    ctx = context(stored, time, {source, property, nil, priority})

    candidate =
      if property == :present_value and BinaryValue.has_priority_array?(stored.object),
        do: BinaryValue.set_priority(stored.object, priority || 16, value),
        else: BinaryValue.update_property(stored.object, property, value)

    with {:ok, candidate} <- candidate,
         {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
      BinaryValue.execute(prepared, ctx)
    end
  end

  defp sample(stored, raw, milliseconds) do
    ctx = context(stored, milliseconds, {:application_write, :present_value, nil, nil})

    with {:ok, candidate} <- BinaryValue.update_property(stored.object, :present_value, raw),
         {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
      Lifecycle.execute(prepared, ctx)
    end
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
end
