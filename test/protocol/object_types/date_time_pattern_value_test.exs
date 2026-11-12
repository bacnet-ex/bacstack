defmodule BACnet.Test.Protocol.ObjectTypes.DateTimePatternValueTest do
  alias BACnet.Protocol.ApplicationTags
  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetDateTime
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectTypes.DateTimePatternValue
  alias BACnet.Protocol.PriorityArray
  alias BACnet.Test.Support.Protocol.ObjectExecutionTestHost, as: Host

  use ExUnit.Case, async: true

  @moduletag :object_test
  @moduletag :bacnet_object
  @moduletag :bacnet_object_datetime_pattern_value

  @now ~U[2026-11-09 12:00:00Z]

  @earlier BACnetDateTime.from_datetime(~U[2026-11-09 07:30:15.25Z])
  @later %BACnetDateTime{
    date: %BACnetDate{
      year: :unspecified,
      month: :even,
      day: :last,
      weekday: :unspecified
    },
    time: %BACnetTime{
      hour: :unspecified,
      minute: 30,
      second: 0,
      hundredth: 42
    }
  }
  @unknown_date %BACnetDate{
    year: :unspecified,
    month: :unspecified,
    day: :unspecified,
    weekday: :unspecified
  }
  @unknown_time %BACnetTime{
    hour: :unspecified,
    minute: :unspecified,
    second: :unspecified,
    hundredth: :unspecified
  }
  @unspecified %BACnetDateTime{date: @unknown_date, time: @unknown_time}

  test "a fully unspecified date and time stays active until a NULL command relinquishes it" do
    {:ok, object} =
      DateTimePatternValue.create(10, "Recurring deadline", %{
        present_value: @earlier,
        relinquish_default: @earlier
      })

    host = Host.new([{object, []}], @now, 0)
    id = DateTimePatternValue.get_object_identifier(object)
    assert :ok = Host.execute(host, id, :initialization)

    reference = %DeviceObjectPropertyRef{
      device_identifier: nil,
      object_identifier: id,
      property_identifier: :present_value,
      property_array_index: nil
    }

    assert {:ok, unknown} =
             ObjectsUtility.cast_value_to_property(id, :present_value, @unspecified)

    assert [
             %Encoding{type: :date, value: @unknown_date},
             %Encoding{type: :time, value: @unknown_time}
           ] =
             unknown

    assert {:ok, lower} = ObjectsUtility.cast_value_to_property(id, :present_value, @later)
    assert [%Encoding{type: :date, value: date}, %Encoding{type: :time, value: time}] = lower
    assert date == @later.date
    assert time == @later.time
    relinquish = Encoding.create!({:null, nil})
    assert :ok = Host.write(host, reference, lower)
    assert :ok = Host.write(host, reference, unknown, 8)
    assert {:ok, @unspecified} = Host.read(host, reference)
    object = Host.snapshot(host, id).object
    assert {8, @unspecified} = DateTimePatternValue.get_priority_value(object)

    priorities = object.priority_array
    assert priorities.priority_16 == @later

    assert {:ok, encodings} =
             ObjectsUtility.cast_value_to_property(id, :priority_array, priorities)

    assert length(encodings) == 16
    pattern_slot = Enum.at(encodings, 15)

    assert {:ok, <<0x1E, 0xA4, 255, 14, 32, 255, 0xB4, 255, 30, 0, 42, 0x1F>>} =
             ApplicationTags.encode(Encoding.to_encoding!(pattern_slot))

    assert {:ok, ^priorities} =
             ObjectsUtility.cast_property_to_value(id, :priority_array, encodings)

    assert :ok = Host.write(host, reference, relinquish, 8)
    assert {:ok, @later} = Host.read(host, reference)
    assert :ok = Host.write(host, reference, relinquish)
    assert {:ok, @earlier} = Host.read(host, reference)
    assert Host.snapshot(host, id).next_execution == nil
  end

  test "direct writes preserve specified and unspecified fields independently" do
    stored = initialize(%{present_value: @earlier})

    for value <- [
          @earlier,
          @later,
          @unspecified,
          %{@earlier | date: @unknown_date},
          %{@earlier | time: @unknown_time},
          put_in(@earlier.date.day, :last),
          put_in(@earlier.time.hundredth, :unspecified)
        ] do
      {:ok, updated} = write(stored, :present_value, value, :application_write)

      now = ~U[2026-11-30 12:30:00.42Z]
      context = Context.new(:periodic, now: now, state: updated.state)

      assert {:ok, %Result{object: %{present_value: ^value}, next_execution: nil}} =
               Lifecycle.execute(updated.object, context)
    end

    for invalid <- [put_in(@earlier.date.day, 32), put_in(@earlier.time.hour, 24)] do
      assert {:error, {:invalid_property_type, :present_value}} =
               DateTimePatternValue.create(10, "Recurring deadline", %{present_value: invalid})

      assert {:error, {:invalid_property_type, :present_value}} =
               write(stored, :present_value, invalid, :application_write)
    end
  end

  test "masked commands and the relinquish default are checked for valid date and time fields" do
    invalid = put_in(@earlier.time.hundredth, 100)
    properties = %{present_value: @earlier, relinquish_default: @unspecified}
    stored = initialize(properties)
    {:ok, high} = write(stored, :present_value, @later, :property_write, 8)

    assert {:error, {:invalid_property_type, :priority_array}} =
             write(high, :present_value, invalid, :property_write, 16)

    assert {:error, {:invalid_property_type, :relinquish_default}} =
             write(high, :relinquish_default, invalid)

    invalid_properties =
      Map.put(properties, :priority_array, %PriorityArray{
        priority_8: @later,
        priority_16: invalid
      })

    assert {:error, {:invalid_property_type, :priority_array}} =
             DateTimePatternValue.create(10, "Recurring deadline", invalid_properties)

    priorities = %{high.object.priority_array | priority_16: invalid}
    legacy = %{high.object | priority_array: priorities}

    assert {:error, {:invalid_property_type, :priority_array}} =
             Lifecycle.execute(legacy, context(nil, :initialization))

    fallback = %{@earlier | time: @unknown_time}
    {:ok, configured} = write(high, :relinquish_default, fallback)
    {:ok, released} = write(configured, :present_value, nil, :property_write, 8)
    assert released.object.present_value == fallback
  end

  test "Is_UTC declares the time basis and leaves stored fields intact" do
    stored = initialize(%{present_value: @earlier, relinquish_default: @earlier})
    refute DateTimePatternValue.has_property?(stored.object, :is_utc)
    {:ok, commanded} = write(stored, :present_value, @later, :property_write, 8)

    {:ok, candidate} = DateTimePatternValue.add_property(commanded.object, :is_utc, true)
    {:ok, utc} = Lifecycle.execute(candidate, context(commanded, :periodic))
    assert utc.object.is_utc
    assert utc.object.present_value == @later
    assert utc.object.priority_array.priority_8 == @later
    assert utc.object.relinquish_default == @earlier

    {:ok, local} = write(utc, :is_utc, false, :application_write)
    refute local.object.is_utc
    assert local.object.present_value == @later
    assert local.object.priority_array.priority_8 == @later
    assert local.object.relinquish_default == @earlier
  end

  test "service isolation blocks application writes and preserves BACnet arbitration" do
    stored =
      initialize(%{present_value: @earlier, relinquish_default: @earlier, out_of_service: true})

    {:ok, high} = write(stored, :present_value, @later, :property_write, 8)
    assert {:error, :out_of_service} = write(high, :present_value, @later, :application_write)

    {:ok, masked} = write(high, :relinquish_default, @later, :application_write)
    {:ok, released} = write(masked, :present_value, nil, :property_write, 8)
    assert released.object.present_value == @later

    assert {:error, :out_of_service} =
             write(released, :relinquish_default, @earlier, :application_write)

    {:ok, in_service} = write(released, :out_of_service, false, :application_write)
    {:ok, updated} = write(in_service, :present_value, @earlier, :application_write)
    assert updated.object.present_value == @earlier
  end

  test "an absent Out_Of_Service property is treated as in service" do
    {:ok, object} =
      DateTimePatternValue.create(10, "Recurring deadline", %{
        present_value: @earlier,
        out_of_service: true
      })

    {:ok, object} = DateTimePatternValue.remove_property(object, :out_of_service)
    {:ok, stored} = Lifecycle.execute(object, context(nil, :initialization))

    assert stored.object.status_flags.out_of_service == false
    {:ok, changed} = write(stored, :present_value, @later, :application_write)
    assert changed.object.present_value == @later
  end

  test "priority six is reserved for local commandable objects" do
    stored = initialize(%{present_value: @earlier, relinquish_default: @earlier})

    for value <- [@later, nil] do
      assert {:error, :write_access_denied} =
               DateTimePatternValue.set_priority(stored.object, 6, value)
    end

    ctx = context(stored, {:property_write, 85, nil, 6})

    assert {:error, :write_access_denied} =
             Lifecycle.prepare_write(stored.object, stored.object, ctx)

    {:ok, object} =
      DateTimePatternValue.create(10, "Recurring deadline", %{
        present_value: @earlier,
        relinquish_default: @earlier,
        priority_array: %PriorityArray{priority_6: @later}
      })

    assert {:error, {:invalid_configuration, :priority_6}} =
             Lifecycle.execute(object, context(nil, :initialization))
  end

  test "local instances require matching runtime state and remote snapshots are passive" do
    stored = initialize(%{present_value: @earlier})
    ctx = context(stored, :periodic)
    wrong_id = %{stored.state.identifier | instance: 11}

    for state <- [
          nil,
          %{stored.state | value: put_in(@earlier.date.day, 32)},
          %{stored.state | identifier: wrong_id}
        ] do
      assert {:error, :invalid_execution_state} =
               Lifecycle.execute(stored.object, %{ctx | state: state})
    end

    properties =
      Map.take(stored.object, [:present_value, :out_of_service, :status_flags, :event_state])

    properties = Map.put(properties, :present_value, put_in(@earlier.date.day, :last))
    {:ok, remote} = DateTimePatternValue.create(11, "Remote", properties, remote_object: 42)

    assert {:ok, %Result{object: ^remote, state: :snapshot, next_execution: nil}} =
             Lifecycle.execute(remote, %{ctx | state: :snapshot})

    write_context = context(stored, {:property_write, :present_value, nil, nil})

    assert {:error, :operation_not_available_for_remote_objects} =
             Lifecycle.prepare_write(remote, remote, write_context)
  end

  test "Reliability reports survive inhibition and simulation remains available" do
    for origin <- [:property_write, :application_write] do
      stored = initialize(%{present_value: @later, reliability: :process_error})
      {:ok, inhibited} = write(stored, :reliability_evaluation_inhibit, true)
      assert inhibited.object.reliability == :no_fault_detected

      {:ok, reported} = write(inhibited, :reliability, :communication_failure, :application_write)
      refute reported.object.status_flags.fault

      {:ok, restored} = write(reported, :reliability_evaluation_inhibit, false)
      assert restored.object.reliability == :communication_failure
      assert restored.object.status_flags.fault

      {:ok, masked} = write(restored, :reliability_evaluation_inhibit, true)
      {:ok, isolated} = write(masked, :out_of_service, true)
      {:ok, simulated} = write(isolated, :reliability, :process_error, origin)
      assert simulated.object.reliability == :process_error
      assert simulated.object.status_flags.fault

      {:ok, resumed} = write(simulated, :out_of_service, false)
      assert resumed.object.reliability == :no_fault_detected
      refute resumed.object.status_flags.fault
    end
  end

  test "clears the alarm flag when the optional Event_State is removed" do
    stored = initialize(%{present_value: @earlier, event_state: :offnormal})
    assert stored.object.status_flags.in_alarm

    {:ok, object} = DateTimePatternValue.remove_property(stored.object, :event_state)
    read = context(stored, {:property_read, :present_value, nil})
    {:ok, updated} = Lifecycle.prepare_read(object, read)

    refute DateTimePatternValue.has_property?(updated.object, :event_state)
    refute updated.object.status_flags.in_alarm
    assert updated.object.present_value == @earlier
    assert updated.next_execution == nil
  end

  defp initialize(properties) do
    {:ok, object} = DateTimePatternValue.create(10, "Recurring deadline", properties)
    {:ok, stored} = Lifecycle.execute(object, context(nil, :initialization))
    stored
  end

  defp context(stored, trigger) do
    Context.new(trigger, now: @now, monotonic_time: 0, state: if(stored, do: stored.state))
  end

  defp write(stored, property, value, origin \\ :property_write, priority \\ nil) do
    ctx = context(stored, {origin, property, nil, priority})

    candidate =
      if property == :present_value and DateTimePatternValue.has_priority_array?(stored.object),
        do: DateTimePatternValue.set_priority(stored.object, priority || 16, value),
        else: DateTimePatternValue.update_property(stored.object, property, value)

    with {:ok, candidate} <- candidate,
         {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, ctx) do
      Lifecycle.execute(prepared, ctx)
    end
  end
end
