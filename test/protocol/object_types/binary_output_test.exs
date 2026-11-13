defmodule BACnet.Test.Protocol.ObjectTypes.BinaryOutputTest do
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ObjectExecution.BinaryState
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsContract
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectTypes.BinaryOutput
  alias BACnet.Test.Support.Protocol.ObjectExecutionTestHost, as: Host

  use ExUnit.Case, async: true

  doctest BinaryOutput

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_binary_output

  # This test suite only extends the basic and utility test suite to
  # cover additional implemented functionality

  test "create/4 priority array overrides given present value" do
    assert {:ok, %BinaryOutput{present_value: false}} =
             BinaryOutput.create(1, "TEST", %{present_value: true})
  end

  test "verify get_property/2 with present_value respects command prioritization on out of service" do
    {:ok, %BinaryOutput{present_value: false} = obj} =
      BinaryOutput.create(1, "TEST", %{relinquish_default: false})

    assert {:ok, false} = BinaryOutput.get_property(obj, :present_value)

    {:ok, obj} = BinaryOutput.update_property(obj, :out_of_service, true)

    assert {:ok, false} = BinaryOutput.get_property(obj, :present_value)
    assert {:ok, %{present_value: true} = obj} = BinaryOutput.set_priority(obj, 16, true)
    assert {:ok, %{present_value: false} = obj} = BinaryOutput.set_priority(obj, 1, false)

    assert {:ok, %{present_value: false}} =
             BinaryOutput.update_property(obj, :out_of_service, false)
  end

  test "verify get_output/1 for normal polarity" do
    {:ok, %BinaryOutput{present_value: false} = obj} =
      BinaryOutput.create(1, "TEST", %{polarity: :normal})

    assert false == BinaryOutput.get_output(obj)

    {:ok, obj} = BinaryOutput.update_property(obj, :relinquish_default, true)
    assert true == BinaryOutput.get_output(obj)

    {:ok, obj} = BinaryOutput.update_property(obj, :relinquish_default, false)
    assert false == BinaryOutput.get_output(obj)
  end

  test "verify get_output/1 for reverse polarity" do
    {:ok, %BinaryOutput{present_value: false} = obj} =
      BinaryOutput.create(1, "TEST", %{polarity: :reverse})

    assert true == BinaryOutput.get_output(obj)

    {:ok, obj} = BinaryOutput.update_property(obj, :relinquish_default, true)
    assert false == BinaryOutput.get_output(obj)

    {:ok, obj} = BinaryOutput.update_property(obj, :relinquish_default, false)
    assert true == BinaryOutput.get_output(obj)
  end

  test "verify get_output/2 for normal polarity on out of service" do
    {:ok, %BinaryOutput{present_value: false} = obj} =
      BinaryOutput.create(1, "TEST", %{polarity: :normal})

    assert false == BinaryOutput.get_output(obj)
    assert {:ok, false} = BinaryOutput.get_property(obj, :present_value)

    {:ok, obj} = BinaryOutput.update_property(obj, :out_of_service, true)
    assert false == BinaryOutput.get_output(obj)
    assert true == BinaryOutput.get_output(obj, true)

    {:ok, obj} = BinaryOutput.update_property(obj, :relinquish_default, true)
    assert {:ok, true} = BinaryOutput.get_property(obj, :present_value)

    assert false == BinaryOutput.get_output(obj)
    assert true == BinaryOutput.get_output(obj, true)

    {:ok, obj} = BinaryOutput.update_property(obj, :out_of_service, false)
    assert true == BinaryOutput.get_output(obj)

    {:ok, obj} = BinaryOutput.update_property(obj, :relinquish_default, false)
    assert {:ok, false} = BinaryOutput.get_property(obj, :present_value)
    assert false == BinaryOutput.get_output(obj)
  end

  test "verify get_output/2 for reverse polarity on out of service" do
    {:ok, %BinaryOutput{present_value: false} = obj} =
      BinaryOutput.create(1, "TEST", %{polarity: :reverse})

    assert true == BinaryOutput.get_output(obj)
    assert {:ok, false} = BinaryOutput.get_property(obj, :present_value)

    {:ok, obj} = BinaryOutput.update_property(obj, :out_of_service, true)
    assert false == BinaryOutput.get_output(obj)
    assert true == BinaryOutput.get_output(obj, true)

    {:ok, obj} = BinaryOutput.update_property(obj, :relinquish_default, true)
    assert {:ok, true} = BinaryOutput.get_property(obj, :present_value)

    assert false == BinaryOutput.get_output(obj)
    assert true == BinaryOutput.get_output(obj, true)

    {:ok, obj} = BinaryOutput.update_property(obj, :out_of_service, false)
    assert false == BinaryOutput.get_output(obj)

    {:ok, obj} = BinaryOutput.update_property(obj, :relinquish_default, false)
    assert {:ok, false} = BinaryOutput.get_property(obj, :present_value)
    assert true == BinaryOutput.get_output(obj)
  end

  @now ~U[2026-11-08 10:00:00Z]

  test "each history member selects the complete trio and removal removes its partners" do
    properties = [
      change_of_state_count: 7,
      change_of_state_time: timestamp(0),
      time_of_state_count_reset: timestamp(0)
    ]

    for {property, value} <- properties do
      created = object(%{property => value})
      assert_history_group(created)
      {:ok, added} = BinaryOutput.add_property(object(%{}), property, value)
      assert_history_group(added)
      {:ok, removed} = BinaryOutput.remove_property(added, property)
      for key <- Keyword.keys(properties), do: refute(BinaryOutput.has_property?(removed, key))
    end
  end

  test "initialization retains totals and timestamps without fabricating a transition" do
    object =
      object(%{
        relinquish_default: true,
        change_of_state_count: 5,
        elapsed_active_time: 8,
        min_on_time: 4
      })

    {:ok, stored} = Lifecycle.execute(object, context(nil, -2000, :initialization))
    assert stored.object.present_value
    assert stored.object.change_of_state_count == 5
    assert stored.object.change_of_state_time == object.change_of_state_time
    assert stored.object.time_of_state_count_reset == object.time_of_state_count_reset
    assert stored.object.time_of_active_time_reset == object.time_of_active_time_reset
    assert stored.object.elapsed_active_time == 8
    assert stored.object.priority_array.priority_6 == nil
    assert stored.next_execution == %Wakeup{wall_time: nil, monotonic_time: -1000}
  end

  test "only effective logical transitions count, irrespective of physical polarity" do
    stored = initialize(%{polarity: :reverse, change_of_state_count: 0})
    assert BinaryOutput.get_output(stored.object)
    {:ok, active} = write(stored, :present_value, true, 100, priority: 8)
    refute BinaryOutput.get_output(active.object)
    assert active.object.change_of_state_count == 1
    assert active.object.change_of_state_time == timestamp(100)
    {:ok, masked} = write(active, :present_value, false, 200, priority: 16)
    assert masked.object.present_value
    assert masked.object.change_of_state_count == 1
    {:ok, same} = write(masked, :present_value, true, 300, priority: 8)
    assert same.object.change_of_state_time == timestamp(100)
    {:ok, polarity} = write(same, :polarity, :normal, 400)
    assert BinaryOutput.get_output(polarity.object)
    assert polarity.object.change_of_state_count == 1
    {:ok, released} = write(polarity, :present_value, nil, 500, priority: 8)
    refute released.object.present_value
    assert released.object.change_of_state_count == 2
    assert released.object.change_of_state_time == timestamp(500)
  end

  test "priority-6 minimum on/off holds preserve pending commands and expire in order" do
    stored = initialize(%{min_on_time: 3, min_off_time: 2, change_of_state_count: 0})
    {:ok, active} = write(stored, :present_value, true, 100, priority: 8)
    assert active.object.priority_array.priority_6 == true
    assert active.next_execution.monotonic_time == 3100
    {:ok, pending} = write(active, :present_value, false, 200, priority: 8)
    assert pending.object.present_value
    assert pending.object.priority_array.priority_8 == false
    assert pending.next_execution == active.next_execution
    {:ok, early} = Lifecycle.execute(pending.object, context(pending, 3099, :timer))
    assert early.object.present_value
    {:ok, expired} = Lifecycle.execute(early.object, context(early, 3100, :timer))
    refute expired.object.present_value
    assert expired.object.priority_array.priority_6 == false
    assert expired.object.change_of_state_count == 2
    assert expired.next_execution.monotonic_time == 5100
    assert {:error, :write_access_denied} = BinaryOutput.set_priority(expired.object, 6, nil)

    object = expired.object
    cleared = put_in(object.priority_array.priority_6, nil)
    replacement = context(expired, 3200, {:application_write, :priority_array, nil, nil})

    assert {:error, {:write_access_denied, :priority_array}} =
             BinaryOutput.prepare_write(expired.object, cleared, replacement)

    {:ok, finished} = Lifecycle.execute(expired.object, context(expired, 5100, :timer))
    assert finished.object.priority_array.priority_6 == nil
    assert finished.next_execution == nil
  end

  test "all emergency priorities can override a hold and start the opposite hold" do
    for priority <- 1..5 do
      stored = initialize(%{min_on_time: 2, min_off_time: 3})
      {:ok, active} = write(stored, :present_value, true, 100)
      {:ok, critical} = write(active, :present_value, false, 200, priority: priority)
      refute critical.object.present_value
      assert critical.object.priority_array.priority_6 == false
      assert critical.next_execution.monotonic_time == 3200
      assert {:error, :write_access_denied} = BinaryOutput.set_priority(critical.object, 6, nil)
      assert {:ok, override} = write(critical, :present_value, true, 250, priority: priority)
      assert override.object.present_value
      assert override.object.priority_array.priority_6 == true

      {:ok, released} = write(critical, :present_value, nil, 300, priority: priority)
      refute released.object.present_value
      {:ok, resumed} = Lifecycle.execute(released.object, context(released, 3200, :timer))
      assert resumed.object.present_value
      assert resumed.object.priority_array.priority_6 == true
      assert resumed.next_execution.monotonic_time == 5200
    end
  end

  test "hold expiry calls the inhibit hook once with the final candidate" do
    stored = initialize(%{min_on_time: 3, min_off_time: 2})
    {:ok, active} = write(stored, :present_value, true, 100, priority: 8)
    {:ok, pending} = write(active, :present_value, false, 200, priority: 8)

    contract = %ObjectsContract{
      object_module: BinaryOutput,
      object_type: :binary_output,
      type_map: %{present_value: :boolean},
      annotations: [],
      protected: [],
      validators: %{}
    }

    hooks = %{
      add_defaults: fn _properties, _metadata -> flunk("unexpected defaults") end,
      check_implicit_relationships: fn _object, _operation -> flunk("unexpected relationship") end,
      inhibit_object_check: fn candidate, original, operation, args ->
        send(self(), {:inhibit, candidate, original, operation, args})
        {:ok, candidate}
      end
    }

    assert {:ok, expired} =
             BinaryState.execute(pending.object, context(pending, 3100, :timer), contract, hooks)

    original = pending.object

    assert_received {:inhibit, %{priority_array: %{priority_6: false}, present_value: false},
                     ^original, :set_minimum_time_hold, %{priority: 6, value: false}}

    refute_received {:inhibit, _, _, _, _}
    assert expired.object.priority_array.priority_6 == false
  end

  test "priority 6 is reserved even when no minimum times are configured" do
    for properties <- [%{}, %{min_on_time: 2}] do
      stored = initialize(properties)
      assert {:error, :write_access_denied} = BinaryOutput.set_priority(stored.object, 6, true)

      for source <- [:property_write, :application_write] do
        assert {:error, :write_access_denied} =
                 Lifecycle.prepare_write(
                   stored.object,
                   stored.object,
                   context(stored, 100, {source, 85, nil, 6})
                 )
      end
    end
  end

  test "unconfigured and zero minimum durations create no hold" do
    for properties <- [%{}, %{min_on_time: 0, min_off_time: 0}] do
      stored = initialize(properties)
      {:ok, active} = write(stored, :present_value, true, 100)
      assert active.object.priority_array.priority_16 == true
      assert active.object.priority_array.priority_6 == nil
      assert active.next_execution == nil
    end
  end

  test "duration edits reevaluate from the last transition and default edits still arbitrate" do
    stored = initialize(%{min_on_time: 5})
    {:ok, active} = write(stored, :present_value, true, 100)
    {:ok, pending} = write(active, :present_value, nil, 200)
    {:ok, shortened} = write(pending, :min_on_time, 1, 1100)
    refute shortened.object.present_value
    assert shortened.next_execution == nil
    {:ok, default} = write(shortened, :relinquish_default, true, 1200)
    assert default.object.present_value
    assert default.next_execution.monotonic_time == 2200
  end

  test "active seconds use logical present value, not feedback or the physical signal" do
    stored =
      initialize(%{
        polarity: :reverse,
        feedback_value: true,
        elapsed_active_time: 0,
        change_of_state_count: 0
      })

    assert BinaryOutput.get_output(stored.object)
    {:ok, idle} = Lifecycle.execute(stored.object, context(stored, 5000, :periodic))
    assert idle.object.elapsed_active_time == 0
    {:ok, active} = write(idle, :present_value, true, 5100)
    {:ok, feedback} = write(active, :feedback_value, false, 5500, source: :application_write)
    assert feedback.object.change_of_state_count == 1
    refute feedback.object.feedback_value
    refute BinaryOutput.get_output(feedback.object)
    {:ok, inactive} = write(feedback, :present_value, false, 5850)
    assert inactive.object.elapsed_active_time == 0
    {:ok, active} = write(inactive, :present_value, true, 7100)
    assert active.next_execution.monotonic_time == 7350

    {:ok, read} =
      Lifecycle.prepare_read(
        active.object,
        context(active, 7450, {:property_read, :elapsed_active_time, nil})
      )

    assert read.object.elapsed_active_time == 1
    assert read.next_execution.monotonic_time == 8350
  end

  test "late and repeated wakeups use monotonic elapsed time despite wall-clock corrections" do
    stored = initialize(%{relinquish_default: true, elapsed_active_time: 8})
    ctx = %{context(stored, 10_750, :clock_change) | now: DateTime.add(@now, -86_400)}
    {:ok, late} = Lifecycle.execute(stored.object, ctx)
    assert late.object.elapsed_active_time == 18
    assert late.next_execution.monotonic_time == 11_000
    {:ok, repeated} = Lifecycle.execute(late.object, %{ctx | state: late.state})
    assert repeated.object.elapsed_active_time == 18
    assert repeated.next_execution == late.next_execution
  end

  test "zero and nonzero total writes honor reset timestamps, including same-value zero writes" do
    stored = initialize(%{change_of_state_count: 0, elapsed_active_time: 0})

    for {property, reset_property} <- [
          change_of_state_count: :time_of_state_count_reset,
          elapsed_active_time: :time_of_active_time_reset
        ] do
      {:ok, first} = write(stored, property, 0, 100)
      assert Map.fetch!(first.object, reset_property) == timestamp(100)
      {:ok, repeated} = write(first, property, 0, 200)
      assert Map.fetch!(repeated.object, reset_property) == timestamp(200)
      {:ok, nonzero} = write(repeated, property, 42, 300)
      assert Map.fetch!(nonzero.object, property) == 42
      assert Map.fetch!(nonzero.object, reset_property) == timestamp(200)
      {:ok, edited} = write(nonzero, reset_property, timestamp(-1000), 400)
      assert Map.fetch!(edited.object, reset_property) == timestamp(-1000)
      assert Map.fetch!(edited.object, property) == 42
    end
  end

  test "active-time replacement discards the fractional remainder" do
    stored = initialize(%{relinquish_default: true, elapsed_active_time: 0})
    {:ok, tick} = Lifecycle.execute(stored.object, context(stored, 750, :periodic))
    {:ok, reset} = write(tick, :elapsed_active_time, 0, 800)
    assert reset.next_execution.monotonic_time == 1800
    {:ok, early} = Lifecycle.execute(reset.object, context(reset, 1799, :timer))
    assert early.object.elapsed_active_time == 0
    {:ok, tick} = Lifecycle.execute(early.object, context(early, 1800, :timer))
    assert tick.object.elapsed_active_time == 1
  end

  test "elapsed seconds wrap but the existing unsigned state count has no artificial limit" do
    stored = initialize(%{change_of_state_count: 0xFFFFFFFF, elapsed_active_time: 0xFFFFFFFF})
    {:ok, active} = write(stored, :present_value, true, 100)
    assert active.object.change_of_state_count == 0x100000000
    {:ok, tick} = BinaryOutput.execute(active.object, context(active, 1100, :timer))
    assert tick.object.elapsed_active_time == 0
    assert tick.object.time_of_active_time_reset == stored.object.time_of_active_time_reset
    assert tick.object.time_of_state_count_reset == stored.object.time_of_state_count_reset
  end

  test "out of service preserves local commands, priority timing and logical accounting" do
    stored =
      initialize(%{
        out_of_service: true,
        min_on_time: 2,
        change_of_state_count: 0,
        elapsed_active_time: 0,
        polarity: :reverse
      })

    {:ok, active} = write(stored, :present_value, true, 100, source: :application_write)
    assert active.object.present_value
    assert active.object.status_flags.out_of_service
    assert active.object.change_of_state_count == 1
    assert BinaryOutput.get_output(active.object, true)
    refute BinaryOutput.get_output(active.object, false)
    {:ok, pending} = write(active, :present_value, false, 200)
    {:ok, expired} = Lifecycle.execute(pending.object, context(pending, 2100, :timer))
    refute expired.object.present_value
    assert expired.object.change_of_state_count == 2
    assert expired.object.elapsed_active_time == 2
    {:ok, in_service} = write(expired, :out_of_service, false, 2200)
    assert BinaryOutput.get_output(in_service.object)
  end

  test "physical feedback updates are isolated during out-of-service simulation" do
    stored = initialize(%{out_of_service: true, feedback_value: false})

    assert {:error, :out_of_service} =
             write(stored, :feedback_value, true, 100, source: :application_write)

    {:ok, simulated} = write(stored, :feedback_value, true, 100)
    assert simulated.object.feedback_value
    {:ok, live} = write(simulated, :out_of_service, false, 200)
    {:ok, physical} = write(live, :feedback_value, true, 300, source: :application_write)
    assert physical.object.feedback_value
  end

  test "OOS reliability simulation accepts local and BACnet writes including same values" do
    for source <- [:application_write, :property_write] do
      stored = initialize(%{out_of_service: true, reliability: :no_fault_detected})
      assert {:ok, simulated} = write(stored, :reliability, :process_error, 100, source: source)
      assert simulated.object.reliability == :process_error
      assert simulated.object.status_flags.fault
      {:ok, repeated} = write(simulated, :reliability, :process_error, 200, source: source)
      assert repeated.object.reliability == :process_error
      {:ok, cleared} = write(repeated, :reliability, :no_fault_detected, 300, source: source)
      refute cleared.object.status_flags.fault
      assert stored.object.reliability == :no_fault_detected
    end
  end

  test "feedback is selectable without intrinsic reporting and stays independent of commands" do
    stored = initialize(%{feedback_value: false, elapsed_active_time: 0, min_on_time: 1})
    assert BinaryOutput.has_property?(stored.object, :feedback_value)
    refute stored.object._metadata.intrinsic_reporting
    {:ok, active} = write(stored, :present_value, true, 100)
    refute active.object.feedback_value
    {:ok, tick} = BinaryOutput.execute(active.object, context(active, 1100, :timer))
    refute tick.object.feedback_value
    {:ok, reported} = write(tick, :feedback_value, true, 1200, source: :application_write)
    assert reported.object.feedback_value

    {:ok, encoded} =
      ObjectsUtility.cast_value_to_property(
        BinaryOutput.get_object_identifier(reported.object),
        :feedback_value,
        true
      )

    assert %Encoding{type: :enumerated, value: 1} = encoded
    {:ok, added} = BinaryOutput.add_property(object(%{}), :feedback_value, true)
    assert added.feedback_value
  end

  test "auto feedback selects the property and models the logical command, including simulation" do
    object = object(%{out_of_service: true, polarity: :reverse}, auto_write_feedback: true)
    assert BinaryOutput.has_property?(object, :feedback_value)
    {:ok, stored} = Lifecycle.execute(object, context(nil, 0, :initialization))
    {:ok, active} = write(stored, :present_value, true, 100, source: :application_write)
    assert active.object.feedback_value

    assert {:error, :feedback_managed_automatically} =
             write(active, :feedback_value, false, 200)

    {:ok, released} = write(active, :present_value, nil, 300)
    refute released.object.feedback_value
  end

  test "preparation installs a hold atomically without I/O or changing original state" do
    stored = initialize(%{min_on_time: 2, change_of_state_count: 0})
    {:ok, candidate} = BinaryOutput.set_priority(stored.object, 8, true)
    ctx = context(stored, 100, {:property_write, :present_value, nil, 8})
    {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, ctx)
    assert prepared.present_value
    assert prepared.priority_array.priority_6 == true
    refute stored.object.present_value
    assert stored.object.priority_array.priority_6 == nil
    assert stored.state.value == false
    {:ok, updated} = BinaryOutput.execute(prepared, ctx)
    assert updated.object.change_of_state_count == 1
  end

  test "a count reset at hold expiry counts the resulting transition only once" do
    stored = initialize(%{min_on_time: 1, change_of_state_count: 0})
    {:ok, active} = write(stored, :present_value, true, 100)
    {:ok, pending} = write(active, :present_value, nil, 200)
    {:ok, reset} = write(pending, :change_of_state_count, 0, 1100)
    refute reset.object.present_value
    assert reset.object.change_of_state_count == 1
    assert reset.object.time_of_state_count_reset == timestamp(1100)
    assert reset.object.change_of_state_time == timestamp(1100)
  end

  test "numeric total identifiers preserve zero-write reset semantics" do
    stored = initialize(%{change_of_state_count: 0, elapsed_active_time: 0})

    for {property, numeric, reset} <- [
          {:change_of_state_count, 15, :time_of_state_count_reset},
          {:elapsed_active_time, 33, :time_of_active_time_reset}
        ] do
      {:ok, candidate} = BinaryOutput.update_property(stored.object, property, 0)
      ctx = context(stored, 100, {:property_write, numeric, nil, nil})
      {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, ctx)
      {:ok, updated} = BinaryOutput.execute(prepared, ctx)
      assert Map.fetch!(updated.object, reset) == timestamp(100)
    end
  end

  test "restart reestablishes a stored hold using fresh monotonic time" do
    stored = initialize(%{min_on_time: 10, change_of_state_count: 0})
    {:ok, active} = write(stored, :present_value, true, 100)
    {:ok, pending} = write(active, :present_value, nil, 200)
    {:ok, restarted} = Lifecycle.execute(pending.object, context(nil, -9000, :initialization))
    assert restarted.object.present_value
    assert restarted.object.change_of_state_count == 1
    assert restarted.next_execution.monotonic_time == 1000
    {:ok, expired} = Lifecycle.execute(restarted.object, context(restarted, 1000, :timer))
    refute expired.object.present_value
    assert expired.object.change_of_state_count == 2
  end

  test "new history groups start now and removed groups stop accounting" do
    stored = initialize(%{relinquish_default: true})
    {:ok, candidate} = BinaryOutput.add_property(stored.object, :elapsed_active_time, 5)
    {:ok, added} = Lifecycle.execute(candidate, context(stored, 5000, :periodic))
    assert added.object.elapsed_active_time == 5
    assert added.next_execution.monotonic_time == 6000
    {:ok, candidate} = BinaryOutput.remove_property(added.object, :elapsed_active_time)
    {:ok, removed} = Lifecycle.execute(candidate, context(added, 6500, :periodic))
    assert removed.next_execution == nil
  end

  test "invalid state, cross-object state and backwards monotonic time fail safely" do
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

    for state <- [
          :bad,
          %{stored.state | kind: :binary_value},
          %{stored.state | identifier: nil},
          %{stored.state | active_remainder: 1000},
          %{stored.state | identifier: %ObjectIdentifier{type: :binary_output, instance: 99}}
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
          time_delay: 0,
          event_detection_enable: true
        },
        intrinsic_reporting: true
      )

    assert BinaryOutput.has_property?(object, :feedback_value)
    {:ok, stored} = Lifecycle.execute(object, context(nil, 0, :initialization))
    {:ok, active} = write(stored, :present_value, true, 100)
    assert active.object.present_value
    refute active.object.feedback_value
    assert active.object.change_of_state_count == 1
    {:ok, tick} = BinaryOutput.execute(active.object, context(active, 1100, :timer))
    assert tick.object.elapsed_active_time == 1

    assert %{event_type: :command_failure, to_state: :offnormal} =
             EventReporting.transition(active)

    assert tick.object.event_state == :offnormal
    assert EventReporting.transition(tick) == nil
  end

  test "remote snapshots preserve state without I/O and reject lifecycle writes" do
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
          },
          polarity: :normal,
          priority_array: %BACnet.Protocol.PriorityArray{},
          relinquish_default: false
        },
        remote_object: 42
      )

    ctx = %{context(nil, 0, :periodic) | state: :remote}

    assert {:ok, %Result{object: ^object, state: :remote, next_execution: nil}} =
             Lifecycle.execute(object, ctx)

    assert {:ok, %Result{object: ^object, state: :remote, next_execution: nil}} =
             BinaryOutput.execute(object, ctx)

    assert :ok = BinaryOutput.validate_execution(object, ctx)

    write_context = %{ctx | trigger: {:property_write, :present_value, nil, 8}}

    assert {:error, :operation_not_available_for_remote_objects} =
             BinaryOutput.prepare_write(object, object, write_context)

    assert {:error, :operation_not_available_for_remote_objects} =
             Lifecycle.prepare_write(object, object, write_context)
  end

  test "a host drives pending commands, elapsed seconds, hold timers and fresh reads" do
    object =
      object(%{min_on_time: 2, min_off_time: 1, change_of_state_count: 0, elapsed_active_time: 0})

    identifier = BinaryOutput.get_object_identifier(object)
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
    stored = Host.snapshot(host, identifier)
    assert stored.object.change_of_state_count == 2
    assert stored.object.elapsed_active_time == 2
    assert stored.next_execution.monotonic_time == 3100
  end

  defp object(properties, options \\ []) do
    {:ok, object} = BinaryOutput.create(10, "Output", properties, options)
    object
  end

  defp initialize(properties) do
    {:ok, stored} = Lifecycle.execute(object(properties), context(nil, 0, :initialization))
    stored
  end

  defp context(stored, milliseconds, trigger) do
    Context.new(trigger,
      now: DateTime.add(@now, milliseconds, :millisecond),
      monotonic_time: milliseconds,
      state: if(stored, do: stored.state),
      read_property: fn _reference -> flunk("must not read other properties") end,
      write_property: fn _reference, _value, _priority ->
        flunk("must not write other objects")
      end
    )
  end

  defp timestamp(milliseconds),
    do: BACnetDateTime.from_datetime(DateTime.add(@now, milliseconds, :millisecond))

  defp assert_history_group(object) do
    for property <- [:change_of_state_time, :change_of_state_count, :time_of_state_count_reset],
        do: assert(BinaryOutput.has_property?(object, property))
  end

  defp write(stored, property, value, milliseconds, options \\ []) do
    priority = Keyword.get(options, :priority)

    ctx =
      context(
        stored,
        milliseconds,
        {Keyword.get(options, :source, :property_write), property, nil, priority}
      )

    candidate =
      if property == :present_value,
        do: BinaryOutput.set_priority(stored.object, priority || 16, value),
        else: BinaryOutput.update_property(stored.object, property, value)

    with {:ok, candidate} <- candidate,
         {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
      BinaryOutput.execute(prepared, ctx)
    end
  end
end
