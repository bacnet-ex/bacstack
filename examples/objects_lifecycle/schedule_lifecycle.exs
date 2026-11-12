# Run from the repository root: mix run examples/objects_lifecycle/schedule_lifecycle.exs
defmodule BACnet.Examples.ScheduleLifecycle do
  @moduledoc """
  Finite Schedule walkthrough with application-owned storage and supplied UTC time.

  The main walkthrough owns one Schedule, one Calendar and one BinaryOutput. The caller
  explicitly checks and delivers the requested deadline. A running application
  needs to arrange timers as described by `BACnet.Protocol.ObjectExecution.Lifecycle`.
  A separate remote segment constructs a WriteProperty request through a simulated
  callback - it sends no network traffic.
  """

  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.CalendarEntry
  alias BACnet.Protocol.DailySchedule
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.DeviceObjectRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectTypes.BinaryOutput
  alias BACnet.Protocol.ObjectTypes.Calendar, as: CalendarObject
  alias BACnet.Protocol.ObjectTypes.Schedule

  @spec run() :: :ok
  def run() do
    off = Encoding.create!({:enumerated, 0})
    on = Encoding.create!({:enumerated, 1})
    calendar_id = %ObjectIdentifier{type: :calendar, instance: 500}
    schedule_id = %ObjectIdentifier{type: :schedule, instance: 600}
    output_id = %ObjectIdentifier{type: :binary_output, instance: 700}
    output_ref = reference(output_id, :present_value)

    day = %DailySchedule{
      schedule: [
        %BACnet.Protocol.TimeValue{time: BACnetTime.from_time(~T[08:00:00]), value: on},
        %BACnet.Protocol.TimeValue{time: BACnetTime.from_time(~T[18:00:00]), value: off}
      ]
    }

    exception = %BACnet.Protocol.SpecialEvent{
      period: calendar_id,
      priority: 1,
      list: [%BACnet.Protocol.TimeValue{time: BACnetTime.from_time(~T[00:00:00]), value: off}]
    }

    {:ok, calendar} = CalendarObject.create(500, "Holidays")
    {:ok, output} = BinaryOutput.create(700, "Lighting")

    {:ok, schedule} =
      Schedule.create(600, "Occupancy", %{
        weekly_schedule: BACnetArray.from_list(List.duplicate(day, 7), true),
        exception_schedule: BACnetArray.from_list([exception]),
        schedule_default: off,
        list_of_object_property_references: [output_ref],
        priority_for_writing: 16
      })

    records =
      Map.new([calendar, output, schedule], fn object ->
        {object.__struct__.get_object_identifier(object),
         %Result{object: object, state: nil, next_execution: nil}}
      end)

    {:ok, store} = Agent.start_link(fn -> %{records: records, active: MapSet.new()} end)

    try do
      now = ~U[2026-11-09 07:30:00Z]
      :ok = step(store, output_id, now, 0, :initialization, 100)
      :ok = step(store, schedule_id, now, 0, :initialization, 100)
      false = snapshot(store, output_id).object.present_value
      show(store, schedule_id, output_id, "Initialized before occupancy")

      now = ~U[2026-11-09 08:00:00Z]
      stored = snapshot(store, schedule_id)
      true = Wakeup.due?(stored.next_execution, context(store, stored, now, 1_800_000, :timer))
      :ok = step(store, schedule_id, now, 1_800_000, :timer, 100)
      true = snapshot(store, output_id).object.present_value
      show(store, schedule_id, output_id, "Requested 08:00 transition")

      now = ~U[2026-11-09 09:00:00Z]

      holiday = %CalendarEntry{
        type: :date,
        date: BACnetDate.from_date(~D[2026-11-09]),
        date_range: nil,
        week_n_day: nil
      }

      :ok = write(store, reference(calendar_id, :date_list), [holiday], nil, now, 5_400_000)

      :ok =
        step(
          store,
          schedule_id,
          now,
          5_400_000,
          {:object_changed,
           %DeviceObjectRef{object_identifier: calendar_id, device_identifier: nil}},
          100
        )

      false = snapshot(store, output_id).object.present_value
      show(store, schedule_id, output_id, "Same-day Calendar edit selects holiday exception")

      :ok = write(store, reference(schedule_id, :out_of_service), true, nil, now, 5_400_001)
      :ok = write(store, reference(schedule_id, :present_value), on, nil, now, 5_400_002)
      true = snapshot(store, output_id).object.present_value
      nil = snapshot(store, schedule_id).next_execution
      show(store, schedule_id, output_id, "Manual out-of-service value still commands lighting")

      :ok = write(store, reference(schedule_id, :out_of_service), false, nil, now, 5_400_003)
      {:ok, ^off} = read(store, reference(schedule_id, :present_value), now, 5_400_004)
      false = snapshot(store, output_id).object.present_value
      show(store, schedule_id, output_id, "Return to service recalculates the exception")
      remote_walkthrough(now)
    after
      Agent.stop(store)
    end
  end

  @spec remote_walkthrough(DateTime.t()) :: :ok
  defp remote_walkthrough(now) do
    value = Encoding.create!({:null, nil})

    target = %DeviceObjectPropertyRef{
      device_identifier: %ObjectIdentifier{type: :device, instance: 42},
      object_identifier: %ObjectIdentifier{type: :binary_output, instance: 700},
      property_identifier: :present_value,
      property_array_index: nil
    }

    {:ok, object} =
      Schedule.create(601, "Remote relinquishment", %{
        schedule_default: value,
        list_of_object_property_references: [target],
        priority_for_writing: 8
      })

    token = make_ref()

    context =
      Context.new(:initialization,
        now: now,
        monotonic_time: 0,
        write_property: fn reference, encoding, priority ->
          {:ok, _apdu} =
            BACnet.Protocol.Services.WriteProperty.to_apdu(
              %BACnet.Protocol.Services.WriteProperty{
                object_identifier: reference.object_identifier,
                property_identifier: reference.property_identifier,
                property_array_index: reference.property_array_index,
                property_value: encoding,
                priority: priority
              },
              []
            )

          send(self(), {token, reference, encoding, priority})
          :ok
        end
      )

    {:ok, published} = Lifecycle.execute(object, context)
    :immediate = published.next_execution

    {:ok, stored} =
      Lifecycle.execute(
        published.object,
        %{context | trigger: :continuation, state: published.state}
      )

    :no_fault_detected = stored.object.reliability

    receive do
      {^token, ^target, ^value, 8} ->
        IO.puts(
          "Remote callback receives NULL at priority 8 - WriteProperty request encoded without a remote lookup (no network traffic)"
        )
    after
      0 -> raise "remote callback was not invoked"
    end
  end

  @spec reference(ObjectIdentifier.t(), atom()) :: DeviceObjectPropertyRef.t()
  defp reference(identifier, property),
    do: %DeviceObjectPropertyRef{
      object_identifier: identifier,
      device_identifier: nil,
      property_identifier: property,
      property_array_index: nil
    }

  @spec snapshot(pid(), ObjectIdentifier.t()) :: Result.t()
  defp snapshot(store, identifier), do: Agent.get(store, &Map.fetch!(&1.records, identifier))

  @spec retain(pid(), ObjectIdentifier.t(), Result.t()) :: :ok
  defp retain(store, identifier, result),
    do: Agent.update(store, &%{&1 | records: Map.put(&1.records, identifier, result)})

  @spec step(
          pid(),
          ObjectIdentifier.t(),
          DateTime.t(),
          integer(),
          Context.trigger(),
          non_neg_integer()
        ) :: :ok | {:error, term()}
  defp step(store, identifier, now, monotonic, trigger, budget)

  defp step(_store, _identifier, _now, _monotonic, _trigger, 0), do: {:error, :continuation_limit}

  defp step(store, identifier, now, monotonic, trigger, budget) do
    if Agent.get(store, &MapSet.member?(&1.active, identifier)) do
      {:error, :cyclic_execution}
    else
      stored = snapshot(store, identifier)
      context = context(store, stored, now, monotonic, trigger)
      Agent.update(store, &%{&1 | active: MapSet.put(&1.active, identifier)})

      result =
        try do
          case trigger do
            {:property_read, _property, _index} -> Lifecycle.prepare_read(stored.object, context)
            _other -> Lifecycle.execute(stored.object, context)
          end
        after
          Agent.update(store, &%{&1 | active: MapSet.delete(&1.active, identifier)})
        end

      case result do
        {:ok, result} ->
          :ok = retain(store, identifier, result)

          if result.next_execution == :immediate,
            do: step(store, identifier, now, monotonic, :continuation, budget - 1),
            else: :ok

        {:error, _reason} = error ->
          error
      end
    end
  end

  @spec read(pid(), DeviceObjectPropertyRef.t(), DateTime.t(), integer()) ::
          {:ok, term()} | {:error, term()}
  defp read(store, reference, now, monotonic) do
    with :ok <-
           step(
             store,
             reference.object_identifier,
             now,
             monotonic,
             {:property_read, reference.property_identifier, reference.property_array_index},
             100
           ) do
      object = snapshot(store, reference.object_identifier).object
      object.__struct__.get_property(object, reference.property_identifier)
    end
  end

  @spec write(pid(), DeviceObjectPropertyRef.t(), term(), 1..16 | nil, DateTime.t(), integer()) ::
          :ok | {:error, term()}
  defp write(store, reference, value, priority, now, monotonic) do
    stored = snapshot(store, reference.object_identifier)
    module = stored.object.__struct__

    commandable =
      reference.property_identifier == :present_value and
        not is_nil(Map.get(stored.object, :priority_array))

    trigger =
      {:property_write, reference.property_identifier, reference.property_array_index, priority}

    context = context(store, stored, now, monotonic, trigger)

    candidate =
      with {:ok, value} <- cast_write(stored.object, reference, value, commandable) do
        cond do
          not is_nil(reference.property_array_index) ->
            {:error, :unsupported_example_array_write}

          commandable and priority == 6 ->
            {:error, :write_access_denied}

          commandable ->
            module.set_priority(stored.object, priority || 16, value)

          module.property_writable?(stored.object, reference.property_identifier) ->
            module.update_property(stored.object, reference.property_identifier, value)

          true ->
            {:error, :write_access_denied}
        end
      end

    with {:ok, candidate} <- candidate,
         {:ok, prepared} <- Lifecycle.prepare_write(stored.object, candidate, context) do
      :ok = retain(store, reference.object_identifier, %{stored | object: prepared})

      case step(store, reference.object_identifier, now, monotonic, trigger, 100) do
        :ok -> :ok
        {:error, reason} -> {:error, {:execution_failed_after_commit, reason}}
      end
    end
  end

  @spec cast_write(struct(), DeviceObjectPropertyRef.t(), term(), boolean()) ::
          {:ok, term()} | {:error, term()}
  defp cast_write(object, reference, value, commandable)

  defp cast_write(_object, _reference, %Encoding{type: :null}, true), do: {:ok, nil}

  defp cast_write(object, reference, %Encoding{} = value, _commandable) do
    ObjectsUtility.cast_property_to_value(
      object.__struct__.get_object_identifier(object),
      reference.property_identifier,
      value,
      allow_partial: not is_nil(reference.property_array_index),
      allow_numeric_constants: true
    )
  end

  defp cast_write(_object, _reference, value, _commandable), do: {:ok, value}

  @spec context(pid(), Result.t(), DateTime.t(), integer(), Context.trigger()) :: Context.t()
  defp context(store, stored, now, monotonic, trigger) do
    %Context{
      device_identifier: nil,
      now: now,
      monotonic_time: monotonic,
      timezone_database: Calendar.UTCOnlyTimeZoneDatabase,
      trigger: trigger,
      state: stored.state,
      options: [],
      lookup_object: fn reference ->
        case Agent.get(store, &Map.fetch(&1.records, reference.object_identifier)) do
          {:ok, result} -> {:ok, result.object}
          :error -> {:error, :unknown_object}
        end
      end,
      read_property_multiple: nil,
      read_property: fn reference -> read(store, reference, now, monotonic) end,
      write_property: fn reference, value, priority ->
        write(store, reference, value, priority, now, monotonic)
      end
    }
  end

  @spec show(pid(), ObjectIdentifier.t(), ObjectIdentifier.t(), String.t()) :: :ok
  defp show(store, schedule_id, output_id, label) do
    schedule = snapshot(store, schedule_id).object
    output = snapshot(store, output_id).object

    IO.puts(
      "#{label}: Schedule=#{inspect(schedule.present_value.value)}, lighting=#{output.present_value}, reliability=#{schedule.reliability}"
    )
  end
end

BACnet.Examples.ScheduleLifecycle.run()
