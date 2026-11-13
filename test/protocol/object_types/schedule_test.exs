defmodule BACnet.Test.Protocol.ObjectTypes.ScheduleTest do
  use ExUnit.Case, async: false

  alias BACnet.Protocol.ApplicationTags.Encoding
  alias BACnet.Protocol.BACnetArray
  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.BACnetTime
  alias BACnet.Protocol.CalendarEntry
  alias BACnet.Protocol.DailySchedule
  alias BACnet.Protocol.DateRange
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.EventTransitionBits
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.EventReporting
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.ScheduleTargets
  alias BACnet.Protocol.ObjectIdentifier
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectTypes.AnalogOutput
  alias BACnet.Protocol.ObjectTypes.BinaryOutput
  alias BACnet.Protocol.ObjectTypes.BitstringValue
  alias BACnet.Protocol.ObjectTypes.Calendar, as: CalendarObject
  alias BACnet.Protocol.ObjectTypes.CharacterStringValue
  alias BACnet.Protocol.ObjectTypes.DatePatternValue
  alias BACnet.Protocol.ObjectTypes.DateValue
  alias BACnet.Protocol.ObjectTypes.IntegerValue
  alias BACnet.Protocol.ObjectTypes.LargeAnalogValue
  alias BACnet.Protocol.ObjectTypes.OctetStringValue
  alias BACnet.Protocol.ObjectTypes.PositiveIntegerValue
  alias BACnet.Protocol.ObjectTypes.Schedule
  alias BACnet.Protocol.ObjectTypes.TimePatternValue
  alias BACnet.Protocol.ObjectTypes.TimeValue, as: TimeValueObject
  alias BACnet.Protocol.SpecialEvent
  alias BACnet.Protocol.TimeValue
  alias BACnet.Test.Support.Protocol.ObjectExecutionTestHost, as: Host

  @moduletag :object_test
  doctest Schedule

  # Schedule object behaviour
  doctest BACnet.Protocol.ObjectExecution.ScheduleEvaluator
  doctest BACnet.Protocol.ObjectExecution.ScheduleTargets

  @now ~U[2026-11-09 08:00:00Z]

  # A typed contract probe, not a standard object's operational implementation.
  defmodule Target do
    alias BACnet.Protocol.EventTransitionBits
    use BACnet.Protocol.ObjectsMacro
    @type object_opts :: common_object_opts()
    bac_object :analog_value do
      services(intrinsic: false)
      field(:present_value, Encoding.t(), required: true, default: Encoding.create!({:null, nil}))
      field(:description, String.t(), required: true, default: "")

      field(:in_process, boolean(),
        required: true,
        default: false,
        annotation: [readonly_when: {:out_of_service, true}]
      )

      field(:out_of_service, boolean(), required: true, default: false)

      field(:schedule_default, Encoding.t(),
        required: true,
        default: Encoding.create!({:null, nil})
      )

      field(:state_text, BACnetArray.t(String.t()),
        required: true,
        default: BACnetArray.from_list(["A"])
      )

      field(:reliability, BACnet.Protocol.Constants.reliability(),
        required: true,
        default: :no_fault_detected
      )

      field(:max_info_frames, 1..255, required: true, default: 1)

      field(:controlled_variable_reference, ObjectIdentifier.t(),
        required: true,
        default: %ObjectIdentifier{type: :device, instance: 0}
      )

      field(:ip_address, :inet.ip4_address(),
        required: true,
        init_fun: &__MODULE__.default_ip/0,
        annotation: [
          decoder: fn %Encoding{type: :octet_string, value: <<a, b, c, d>>} ->
            {:ok, {a, b, c, d}}
          end,
          encoder: fn {a, b, c, d} -> {:ok, {:octet_string, <<a, b, c, d>>}} end
        ]
      )

      field(:status_flags, BACnet.Protocol.StatusFlags.t(), required: true, readonly: true)
      field(:resolution, float(), required: true, default: 0.0, annotation: {:encode_as, :double})

      field(:cov_increment, float(),
        required: true,
        default: 0.0,
        annotation: [
          encoder: fn
            value when value == 0.0 -> {:error, :unsupported_increment}
            -1.0 -> raise ArgumentError, "negative increment"
            1.0 -> Encoding.create!({:double, 1.0})
            value -> {:ok, {:double, value}}
          end
        ]
      )

      field(:deadband, float(),
        required: true,
        default: 0.0,
        annotation: [decoder: fn %Encoding{value: value} -> {:ok, value * 1.0} end]
      )

      field(:object_list, BACnetArray.t(non_neg_integer(), 2),
        required: true,
        default: BACnetArray.from_list([0, 0], true)
      )

      field(:setpoint, float() | boolean(), required: true, default: false)

      field(:event_algorithm_inhibit_ref, BACnet.Protocol.ObjectPropertyRef.t())
      field(:event_enable, EventTransitionBits.t())
    end

    @doc false
    @spec default_ip() :: :inet.ip4_address()
    def default_ip(), do: {0, 0, 0, 0}
  end

  # The casting utility resolves the test target through its object-type mapping.
  setup do
    previous = ObjectsUtility.get_object_type_mappings()[:analog_value]
    ObjectsUtility.put_object_type_mapping(:analog_value, Target)
    on_exit(fn -> ObjectsUtility.put_object_type_mapping(:analog_value, previous) end)
    :ok
  end

  defmodule TimezoneDatabase do
    @moduledoc false
    @behaviour Calendar.TimeZoneDatabase
    @standard %{utc_offset: 0, std_offset: 0, zone_abbr: "STD"}
    @summer %{utc_offset: 0, std_offset: 3600, zone_abbr: "DST"}

    @impl true
    @spec time_zone_period_from_utc_iso_days(Calendar.iso_days(), Calendar.time_zone()) ::
            {:error, :time_zone_not_found}
    def time_zone_period_from_utc_iso_days(_days, _zone), do: {:error, :time_zone_not_found}

    @impl true
    @spec time_zone_periods_from_wall_datetime(Calendar.naive_datetime(), Calendar.time_zone()) ::
            {:ok, Calendar.TimeZoneDatabase.time_zone_period()}
            | {:ambiguous, earlier_period :: Calendar.TimeZoneDatabase.time_zone_period(),
               later_period :: Calendar.TimeZoneDatabase.time_zone_period()}
            | {:gap,
               {period_before_gap :: Calendar.TimeZoneDatabase.time_zone_period(),
                gap_start :: Calendar.TimeZoneDatabase.time_zone_period_limit()},
               {period_after_gap :: Calendar.TimeZoneDatabase.time_zone_period(),
                gap_end :: Calendar.TimeZoneDatabase.time_zone_period_limit()}}
    def time_zone_periods_from_wall_datetime(datetime, timezone)

    def time_zone_periods_from_wall_datetime(
          %NaiveDateTime{year: 2026, month: 3, day: 29, hour: 2, minute: 30},
          "Test/Gap"
        ),
        do: {:gap, {@standard, ~N[2026-03-29 02:00:00]}, {@summer, ~N[2026-03-29 03:00:00]}}

    def time_zone_periods_from_wall_datetime(
          %NaiveDateTime{year: 2026, month: 10, day: 25, hour: 1, minute: 30},
          "Test/Overlap"
        ),
        do: {:ambiguous, @summer, @standard}

    def time_zone_periods_from_wall_datetime(_datetime, "Test/Gap"), do: {:ok, @summer}
    def time_zone_periods_from_wall_datetime(_datetime, "Test/Overlap"), do: {:ok, @standard}
  end

  test "weekly lists select the latest time, reset at midnight and honor hundredths" do
    object =
      schedule(%{
        weekly_schedule: week([tv(8, 0, enc(:real, 21.0)), tv(9, 0, enc(:real, 18.0))]),
        schedule_default: enc(:real, 12.0)
      })

    for {now, expected} <- [
          {~U[2026-11-09 07:59:59Z], 12.0},
          {@now, 21.0},
          {~U[2026-11-09 09:00:00Z], 18.0},
          {~U[2026-11-10 00:00:00Z], 12.0}
        ] do
      {:ok, result} = Lifecycle.execute(object, context(now))
      assert result.object.present_value.value == expected
    end

    time = %BACnetTime{hour: 8, minute: 0, second: 0, hundredth: 1}

    object =
      schedule(%{weekly_schedule: week([%TimeValue{time: time, value: enc(:boolean, true)}])})

    {:ok, before} = Lifecycle.execute(object, context(~U[2026-11-09 08:00:00.005Z]))
    assert before.object.present_value.type == :null
    assert before.next_execution.wall_time == ~U[2026-11-09 08:00:00.010000Z]
    {:ok, at} = Lifecycle.execute(object, context(~U[2026-11-09 08:00:00.010Z]))
    assert at.object.present_value.value
  end

  test "weekly indices are Monday through Sunday and unordered times are evaluated by time" do
    week =
      BACnetArray.from_list(
        for day <- 1..7 do
          %DailySchedule{
            schedule: [
              tv(9, 0, enc(:unsigned_integer, day + 10)),
              tv(0, 0, enc(:unsigned_integer, day))
            ]
          }
        end,
        true
      )

    object = schedule(%{weekly_schedule: week})

    for day <- 1..7 do
      {:ok, result} = Lifecycle.execute(object, context(DateTime.add(@now, (day - 1) * 86_400)))
      assert result.object.present_value.value == day
    end
  end

  test "exceptions use priority then array index and NULL contributions fall through" do
    events = [
      event([tv(0, 0, enc(:null, nil))], 1),
      event([tv(0, 0, enc(:real, 22.0)), tv(9, 0, enc(:null, nil))], 2),
      event([tv(0, 0, enc(:real, 23.0)), tv(10, 0, enc(:null, nil))], 2)
    ]

    object =
      schedule(%{
        weekly_schedule: week([tv(0, 0, enc(:real, 20.0))]),
        exception_schedule: BACnetArray.from_list(events),
        schedule_default: enc(:real, 10.0)
      })

    for {now, value} <- [
          {@now, 22.0},
          {~U[2026-11-09 09:00:00Z], 23.0},
          {~U[2026-11-09 10:00:00Z], 20.0}
        ] do
      {:ok, result} = Lifecycle.execute(object, context(now))
      assert result.object.present_value.value == value
    end
  end

  test "exceptions-only and empty weekly schedules are valid, empty exceptions alone are not" do
    {:ok, object} =
      Schedule.remove_property(
        schedule(%{exception_schedule: BACnetArray.from_list([event([])])}),
        :weekly_schedule
      )

    assert {:ok, _result} = Lifecycle.execute(object, context())
    {:ok, empty} = Schedule.update_property(object, :exception_schedule, BACnetArray.new())

    assert {:error, {:invalid_configuration, :missing_schedule}} =
             Lifecycle.execute(empty, context())

    assert {:ok, _result} = Lifecycle.execute(schedule(), context())
  end

  test "duplicate and wildcard times are rejected without invoking host operations" do
    for entries <- [
          [tv(8, 0, enc(:real, 1.0)), tv(8, 0, enc(:real, 2.0))],
          [
            %TimeValue{
              time: %BACnetTime{hour: 8, minute: :unspecified, second: 0, hundredth: 0},
              value: enc(:real, 1.0)
            }
          ]
        ] do
      original = schedule()
      {:ok, candidate} = Schedule.update_property(original, :weekly_schedule, week(entries))

      context = %{
        context()
        | trigger: {:property_write, :weekly_schedule, nil, nil},
          lookup_object: fn _reference -> flunk("preparation must not look up objects") end,
          read_property: fn _reference -> flunk("preparation must not read") end,
          write_property: fn _reference, _value, _priority ->
            flunk("preparation must not write")
          end
      }

      assert {:error, _reason} = Lifecycle.prepare_write(original, candidate, context)
    end

    original = schedule()

    {:ok, duplicate} =
      Schedule.add_property(
        original,
        :exception_schedule,
        BACnetArray.from_list([
          event([tv(0, 0, enc(:boolean, true)), tv(0, 0, enc(:boolean, false))])
        ])
      )

    assert {:error, {:duplicate_entry, :exception_schedule}} =
             Lifecycle.prepare_write(original, duplicate, %{
               context()
               | trigger: {:property_write, :exception_schedule, nil, nil}
             })
  end

  test "inconsistent datatypes set configuration error and cannot be committed through preparation" do
    object =
      schedule(%{
        weekly_schedule: week([tv(0, 0, enc(:real, 1.0))]),
        schedule_default: enc(:double, 1.0)
      })

    {:ok, result} = Lifecycle.execute(object, context())
    assert result.object.reliability == :configuration_error
    assert result.object.status_flags.fault

    assert {:error, :inconsistent_datatypes} =
             Lifecycle.prepare_write(schedule(), object, %{
               context()
               | trigger: {:property_write, :weekly_schedule, nil, nil}
             })
  end

  test "all primitive application datatypes and all-NULL schedules execute across property revisions" do
    values = [
      enc(:null, nil),
      enc(:boolean, true),
      enc(:unsigned_integer, 12),
      enc(:signed_integer, -12),
      enc(:real, 1.5),
      enc(:double, 1.5),
      enc(:octet_string, <<0, 255>>),
      enc(:character_string, "on"),
      enc(:bitstring, {true, false}),
      enc(:enumerated, 1),
      enc(:date, BACnetDate.from_date(~D[2026-11-09])),
      enc(:time, BACnetTime.from_time(~T[08:00:00])),
      enc(:object_identifier, oid(:binary_value, 3))
    ]

    for revision <- [14, 19, 22], value <- values do
      {:ok, object} = Schedule.create(1, "Typed", %{schedule_default: value}, revision: revision)
      {:ok, target} = Target.create(2, "Target")

      {:ok, object} =
        Schedule.update_property(object, :list_of_object_property_references, [ref(target)])

      host = start(object, [target])
      assert Host.snapshot(host, ref(target).object_identifier).object.present_value == value
      assert record(host).object.present_value == value
    end
  end

  test "target types honor ENUMERATED booleans and REAL versus Double and Unsigned distinctions" do
    {:ok, binary} = BinaryOutput.create(2, "Binary")

    host =
      start(
        schedule(%{
          schedule_default: enc(:enumerated, 1),
          list_of_object_property_references: [ref(binary)]
        }),
        [binary]
      )

    assert Host.snapshot(host, ref(binary).object_identifier).object.present_value
    assert Host.writes(host) == [{ref(binary), enc(:enumerated, 1), 16}]

    {:ok, analog} = AnalogOutput.create(3, "Analog")

    for wrong <- [enc(:double, 1.0), enc(:unsigned_integer, 1)] do
      host =
        start(
          schedule(%{schedule_default: wrong, list_of_object_property_references: [ref(analog)]}),
          [analog]
        )

      assert record(host).object.reliability == :configuration_error
      assert Host.writes(host) == []
    end

    {:ok, target} = Target.create(4, "Double")
    reference = %{ref(target) | property_identifier: :resolution}

    host =
      start(
        schedule(%{
          schedule_default: enc(:double, 1.0),
          list_of_object_property_references: [reference]
        }),
        [target]
      )

    assert Host.writes(host) == [{reference, enc(:double, 1.0), 16}]
  end

  test "local target identity accepts omitted and explicit self-device references" do
    {:ok, target} = Target.create(2, "Target")
    device = oid(:device, 42)
    reference = %{ref(target) | device_identifier: device}
    object = schedule(%{list_of_object_property_references: [reference]})
    host = Host.new([{object, []}, {target, []}], @now, 0, device_identifier: device)
    assert :ok = Host.execute(host, oid(:schedule, 1), :initialization)

    assert [{%DeviceObjectPropertyRef{device_identifier: nil}, %Encoding{type: :null}, 16}] =
             Host.writes(host)
  end

  test "remote targets preserve encodings, device identity, numeric properties, indices and priority" do
    reference = %DeviceObjectPropertyRef{
      device_identifier: oid(:device, 42),
      object_identifier: %ObjectIdentifier{type: 512, instance: 700},
      property_identifier: 512,
      property_array_index: 3
    }

    for value <- [
          enc(:null, nil),
          enc(:enumerated, 1),
          enc(:double, 2.5),
          enc(:octet_string, <<1, 2>>),
          enc(:bitstring, {true, false})
        ] do
      object =
        schedule(%{
          schedule_default: value,
          list_of_object_property_references: [reference],
          priority_for_writing: 8
        })

      # No remote object model, lookup callback or local identity is needed.
      ctx = %{
        context()
        | write_property: fn actual, written, priority ->
            send(self(), {:remote_write, actual, written, priority})
            :ok
          end
      }

      assert {:ok, published} = Lifecycle.execute(object, ctx)
      assert published.next_execution == :immediate
      refute_received {:remote_write, _, _, _}

      assert {:ok, finished} =
               Lifecycle.execute(
                 published.object,
                 %{ctx | state: published.state, trigger: :continuation}
               )

      assert_received {:remote_write, ^reference, ^value, 8}
      assert finished.object.reliability == :no_fault_detected
    end
  end

  test "remote failures retain full references, continue to local and remote targets, and do not retry" do
    {:ok, local} = BinaryOutput.create(2, "Local")
    remote = %{ref(local) | device_identifier: oid(:device, 42)}
    other_remote = %{remote | device_identifier: oid(:device, 43)}
    value = enc(:enumerated, 1)

    object =
      schedule(%{
        schedule_default: value,
        list_of_object_property_references: [remote, ref(local), other_remote]
      })

    host =
      Host.new([{object, []}, {local, []}], @now, 0,
        remote_write: fn reference, ^value, 16 ->
          if reference == remote, do: {:error, :timeout}, else: :ok
        end
      )

    assert :ok = Host.execute(host, BinaryOutput.get_object_identifier(local), :initialization)
    assert :ok = Host.execute(host, oid(:schedule, 1), :initialization)

    assert Host.writes(host) == [
             {remote, value, 16},
             {ref(local), value, 16},
             {other_remote, value, 16}
           ]

    assert Host.snapshot(host, ref(local).object_identifier).object.present_value
    assert record(host).state.failures == [{remote, :timeout}]
    assert record(host).object.reliability == :communication_failure
    assert :ok = Host.execute(host, oid(:schedule, 1), :periodic)
    assert length(Host.writes(host)) == 3
  end

  test "remote property and object error APDUs are retained configuration faults" do
    remote = %{ref_id(:binary_output, 2) | device_identifier: oid(:device, 42)}

    object =
      schedule(%{
        schedule_default: enc(:enumerated, 1),
        list_of_object_property_references: [remote]
      })

    for error_class <- [:property, :object, 2, 1] do
      error = %BACnet.Protocol.APDU.Error{
        invoke_id: 7,
        service: :write_property,
        class: error_class,
        code: :write_access_denied,
        payload: []
      }

      host =
        Host.new([{object, []}], @now, 0,
          remote_write: fn _reference, _value, _priority -> {:error, error} end
        )

      assert :ok = Host.execute(host, oid(:schedule, 1), :initialization)
      assert record(host).object.reliability == :configuration_error
      assert record(host).state.failures == [{remote, error}]
    end
  end

  test "NULL defaults relinquish local commands and NULL time entries select fallback values" do
    {:ok, binary} = BinaryOutput.create(2, "Lighting")

    object =
      schedule(%{
        schedule_default: enc(:null, nil),
        weekly_schedule: week([tv(8, 0, enc(:enumerated, 1)), tv(9, 0, enc(:null, nil))]),
        list_of_object_property_references: [ref(binary)]
      })

    host = start(object, [binary])
    assert Host.snapshot(host, ref(binary).object_identifier).object.present_value
    Host.advance(host, ~U[2026-11-09 09:00:00Z], 3_600_000)
    assert :ok = Host.execute(host, oid(:schedule, 1), :timer)
    assert List.last(Host.writes(host)) == {ref(binary), enc(:null, nil), 16}

    assert Host.snapshot(host, ref(binary).object_identifier).object.priority_array.priority_16 ==
             nil

    assert record(host).object.reliability == :no_fault_detected

    {:ok, target} = Target.create(3, "Non-commandable")
    reference = %{ref(target) | property_identifier: :in_process}

    object =
      schedule(%{
        schedule_default: enc(:boolean, false),
        weekly_schedule: week([tv(8, 0, enc(:null, nil))]),
        list_of_object_property_references: [reference]
      })

    host = start(object, [target])
    assert record(host).object.reliability == :no_fault_detected
    assert Host.writes(host) == [{reference, enc(:boolean, false), 16}]
  end

  test "a future NULL default is validated for non-commandable targets" do
    {:ok, target} = Target.create(2, "Non-commandable")
    reference = %{ref(target) | property_identifier: :in_process}

    object =
      schedule(%{
        schedule_default: enc(:null, nil),
        weekly_schedule: week([tv(8, 0, enc(:boolean, true))]),
        list_of_object_property_references: [reference]
      })

    host = start(object, [target])
    assert record(host).object.reliability == :configuration_error
    assert Host.writes(host) == []
  end

  test "REAL commands reach initialized Analog Output lifecycle targets including OOS simulation" do
    for out_of_service <- [false, true] do
      {:ok, target} = AnalogOutput.create(2, "Analog target", %{out_of_service: out_of_service})
      reference = ref(target)

      host =
        start(
          schedule(%{
            schedule_default: enc(:real, 25.0),
            list_of_object_property_references: [reference]
          }),
          [target]
        )

      retained = Host.snapshot(host, reference.object_identifier)
      assert retained.object.present_value == 25.0
      assert retained.object.priority_array.priority_16 == 25.0
      assert retained.next_execution == nil

      assert AnalogOutput.get_output(retained.object, 7.0) ==
               if(out_of_service, do: 7.0, else: 25.0)

      assert Host.writes(host) == [{reference, enc(:real, 25.0), 16}]
    end
  end

  test "missing host operations fail before I/O" do
    object = schedule(%{list_of_object_property_references: [ref_id(:analog_output, 2)]})

    assert {:error, {:unsupported_operation, :lookup_object}} =
             Lifecycle.execute(object, context())

    assert {:error, {:unsupported_operation, :write_property}} =
             Lifecycle.execute(
               object,
               %{
                 context()
                 | lookup_object: fn _reference -> flunk("preflight must not invoke lookup") end
               }
             )
  end

  test "intrinsic properties do not block initialization or write preparation" do
    {:ok, intrinsic} =
      Schedule.create(2, "Intrinsic", %{schedule_default: enc(:boolean, true)},
        intrinsic_reporting: true
      )

    properties = [:event_state | Schedule.get_intrinsic_properties()]
    reporting = Map.take(intrinsic, properties)
    assert {:ok, result} = Lifecycle.execute(intrinsic, context())
    assert result.object.present_value == enc(:boolean, true)
    assert Map.take(result.object, properties) == reporting

    {:ok, candidate} =
      Schedule.update_property(result.object, :schedule_default, enc(:boolean, false))

    write_context = %{
      context()
      | state: result.state,
        trigger: {:property_write, :schedule_default, nil, nil}
    }

    assert {:ok, prepared} = Lifecycle.prepare_write(result.object, candidate, write_context)
    assert {:ok, updated} = Lifecycle.execute(prepared, write_context)
    assert updated.object.present_value == enc(:boolean, false)
    assert Map.take(updated.object, properties) == reporting
  end

  test "reports a simulated Schedule reliability fault directly" do
    assert {:ok, object} =
             Schedule.create(
               1,
               "Simulated Schedule",
               %{out_of_service: true, reliability_evaluation_inhibit: true},
               intrinsic_reporting: true
             )

    assert {:ok, initial} = Schedule.execute(object, context())

    assert {:ok, candidate} =
             Schedule.update_property(initial.object, :reliability, :configuration_error)

    write = %{
      context()
      | trigger: {:property_write, :reliability, nil, nil},
        state: initial.state
    }

    assert {:ok, result} = Schedule.execute(candidate, write)

    assert %{
             event_type: :change_of_reliability,
             to_state: :fault,
             event_values: %{property_values: []}
           } = EventReporting.transition(result)
  end

  test "reports reliability failures without an offnormal event algorithm" do
    {:ok, target} = Target.create(2, "Unavailable target")

    {:ok, object} =
      Schedule.create(
        1,
        "Intrinsic schedule",
        %{
          schedule_default: enc(:real, 1.0),
          list_of_object_property_references: [ref(target)],
          time_delay: 0,
          event_detection_enable: true
        },
        intrinsic_reporting: true
      )

    host = Host.new([{object, []}, {target, []}], @now, 0)
    Host.fail_writes(host, ref(target).object_identifier, :offline)
    assert :ok = Host.execute(host, oid(:schedule, 1), :initialization)
    result = record(host)
    assert result.object.reliability == :communication_failure
    assert result.object.status_flags.fault
    assert result.object.event_state == :fault
    assert result.object.event_timestamps.to_fault.type == :datetime
  end

  test "effective period entry forces writes, exit holds the value without relinquishing" do
    period = %DateRange{
      start_date: BACnetDate.from_date(~D[2026-11-10]),
      end_date: BACnetDate.from_date(~D[2026-11-10])
    }

    {:ok, target} = Target.create(2, "Target")

    object =
      schedule(%{effective_period: period, list_of_object_property_references: [ref(target)]})

    host = start(object, [target])
    assert Host.writes(host) == []
    Host.advance(host, ~U[2026-11-10 00:00:00Z], 57_600_000)
    assert :ok = Host.run_due(host)
    assert length(Host.writes(host)) == 1
    Host.advance(host, ~U[2026-11-11 00:00:00Z], 144_000_000)
    assert :ok = Host.run_due(host)
    assert length(Host.writes(host)) == 1
  end

  test "manual OOS changes fan out, same-value writes do not, returning to service recalculates" do
    {:ok, target} = Target.create(2, "Target")

    object =
      schedule(%{
        schedule_default: enc(:boolean, false),
        list_of_object_property_references: [ref(target)]
      })

    host = start(object, [target])

    assert {:error, {:write_access_denied, :present_value}} =
             Host.write(host, ref(object), enc(:boolean, true))

    refute Schedule.property_writable?(record(host).object, :present_value)
    assert :ok = Host.write(host, %{ref(object) | property_identifier: :out_of_service}, true)
    assert record(host).next_execution == nil
    assert Schedule.property_writable?(record(host).object, :present_value)
    assert :ok = Host.write(host, ref(object), enc(:boolean, true))
    assert List.last(Host.writes(host)) == {ref(target), enc(:boolean, true), 16}
    count = length(target_writes(host))
    assert :ok = Host.write(host, ref(object), enc(:boolean, true))
    assert length(target_writes(host)) == count
    assert :ok = Host.write(host, %{ref(object) | property_identifier: :out_of_service}, false)
    refute record(host).object.present_value.value
    assert length(target_writes(host)) == count + 1
  end

  test "one target failure does not stop later writes and unchanged execution does not retry" do
    {:ok, first} = Target.create(2, "First")
    {:ok, second} = Target.create(3, "Second")

    object =
      schedule(%{
        schedule_default: enc(:real, 1.0),
        list_of_object_property_references: [ref(first), ref(second)]
      })

    host = Host.new([{object, []}, {first, []}, {second, []}], @now, 0)
    Host.fail_writes(host, ref(first).object_identifier, :offline)
    assert :ok = Host.execute(host, oid(:schedule, 1), :initialization)
    assert length(Host.writes(host)) == 2
    assert record(host).object.reliability == :communication_failure
    assert record(host).state.failures == [{ref(first), :offline}]
    assert Host.snapshot(host, ref(second).object_identifier).object.present_value.value == 1.0
    assert :ok = Host.execute(host, oid(:schedule, 1), :periodic)
    assert length(Host.writes(host)) == 2
  end

  test "unknown or read-only targets produce retained configuration faults and continue" do
    {:ok, good} = Target.create(2, "Good")

    refs = [
      ref_id(:analog_value, 99),
      %{ref(good) | property_identifier: :status_flags},
      ref(good)
    ]

    host =
      start(
        schedule(%{schedule_default: enc(:real, 1.0), list_of_object_property_references: refs}),
        [good]
      )

    assert record(host).object.reliability == :configuration_error
    assert length(record(host).state.failures) == 2
    assert Host.writes(host) == [{ref(good), enc(:real, 1.0), 16}]
  end

  test "array target elements preserve index and require compatible existing elements" do
    {:ok, target} = Target.create(2, "Array")
    reference = %{ref(target) | property_identifier: :object_list, property_array_index: 2}

    host =
      start(
        schedule(%{
          schedule_default: enc(:unsigned_integer, 9),
          list_of_object_property_references: [reference]
        }),
        [target]
      )

    assert Host.writes(host) == [{reference, enc(:unsigned_integer, 9), 16}]

    assert {:ok, 9} =
             BACnetArray.get_item(
               Host.snapshot(host, ref(target).object_identifier).object.object_list,
               2
             )

    for index <- [nil, 0, 3] do
      host =
        start(
          schedule(%{
            schedule_default: enc(:unsigned_integer, 9),
            list_of_object_property_references: [%{reference | property_array_index: index}]
          }),
          [target]
        )

      assert record(host).object.reliability == :configuration_error
      assert Host.writes(host) == []
    end
  end

  test "Calendar reads are fresh inside Schedule evaluation and same-day edits take effect" do
    {:ok, calendar} = CalendarObject.create(2, "Holiday")
    exception = %{event([tv(0, 0, enc(:boolean, true))]) | period: oid(:calendar, 2)}

    object =
      schedule(%{
        schedule_default: enc(:boolean, false),
        exception_schedule: BACnetArray.from_list([exception])
      })

    host = start(object, [calendar])
    refute record(host).object.present_value.value

    entry = %CalendarEntry{
      type: :date,
      date: BACnetDate.from_date(~D[2026-11-09]),
      date_range: nil,
      week_n_day: nil
    }

    assert :ok = Host.write(host, %{ref(calendar) | property_identifier: :date_list}, [entry])

    assert :ok =
             Host.execute(
               host,
               oid(:schedule, 1),
               {:object_changed,
                %BACnet.Protocol.DeviceObjectRef{
                  device_identifier: nil,
                  object_identifier: oid(:calendar, 2)
                }}
             )

    assert record(host).object.present_value.value
    Host.advance(host, ~U[2026-11-10 08:00:00Z], 86_400_000)
    assert {:ok, %Encoding{value: false}} = Host.read(host, ref(object))
    refute Host.snapshot(host, oid(:calendar, 2)).object.present_value
  end

  test "clock corrections recalculate and do not replay missed transitions" do
    {:ok, target} = Target.create(2, "Target")

    object =
      schedule(%{
        schedule_default: enc(:real, 10.0),
        weekly_schedule: week([tv(8, 0, enc(:real, 20.0)), tv(9, 0, enc(:real, 30.0))]),
        list_of_object_property_references: [ref(target)]
      })

    host = start(object, [target])
    Host.advance(host, ~U[2026-11-09 10:00:00Z], 7_200_000)
    assert :ok = Host.execute(host, oid(:schedule, 1), :clock_change)
    assert record(host).object.present_value.value == 30.0
    Host.advance(host, ~U[2026-11-09 07:00:00Z], 7_200_001)
    assert :ok = Host.execute(host, oid(:schedule, 1), :clock_change)
    assert record(host).object.present_value.value == 10.0
    assert DateTime.compare(record(host).next_execution.wall_time, @now) == :eq
    assert length(Host.writes(host)) == 3
  end

  test "remote snapshots remain passive and reject local write preparation" do
    {:ok, object} =
      Schedule.create(
        1,
        "Remote",
        %{
          out_of_service: false,
          present_value: enc(:boolean, true),
          schedule_default: enc(:null, nil),
          effective_period: schedule().effective_period,
          list_of_object_property_references: [],
          priority_for_writing: 16,
          reliability: :no_fault_detected,
          status_flags: %BACnet.Protocol.StatusFlags{
            in_alarm: false,
            fault: false,
            overridden: false,
            out_of_service: false
          },
          weekly_schedule: week([])
        },
        remote_object: 42
      )

    {:ok, result} = Lifecycle.execute(object, %{context() | state: :opaque})
    assert result == %Result{object: object, state: :opaque, next_execution: nil}

    write = %{context() | trigger: {:property_write, :schedule_default, nil, nil}}

    assert {:error, :operation_not_available_for_remote_objects} =
             Lifecycle.prepare_write(object, object, write)

    assert :ok = Schedule.validate_execution(object, %{context() | state: :opaque})

    assert {:error, :operation_not_available_for_remote_objects} =
             Schedule.prepare_write(object, object, write)

    assert {:ok, %Result{object: ^object, state: :opaque, next_execution: nil}} =
             Schedule.execute(object, %{context() | state: :opaque})
  end

  test "atom and tuple write failures are configuration faults" do
    reference = %DeviceObjectPropertyRef{
      device_identifier: oid(:device, 42),
      object_identifier: oid(:analog_value, 9),
      property_identifier: :present_value,
      property_array_index: nil
    }

    object =
      schedule(%{
        schedule_default: enc(:enumerated, 1),
        list_of_object_property_references: [reference]
      })

    for reason <- [:unknown_object, {:unknown_property, :present_value}] do
      ctx = %{
        context()
        | write_property: fn _reference, _value, _priority -> {:error, reason} end
      }

      assert {:ok, published} = Lifecycle.execute(object, ctx)
      assert published.next_execution == :immediate

      assert {:ok, finished} =
               Lifecycle.execute(published.object, %{
                 ctx
                 | state: published.state,
                   trigger: :continuation
               })

      assert finished.object.reliability == :configuration_error
      assert finished.state.failures == [{reference, reason}]
      assert finished.state.failure_kind == :write
    end
  end

  test "a non-boolean calendar value is an invalid calendar reference" do
    calendar = oid(:calendar, 2)
    exception = %{event([tv(0, 0, enc(:boolean, true))]) | period: calendar}

    object =
      schedule(%{
        schedule_default: enc(:boolean, false),
        exception_schedule: BACnetArray.from_list([exception])
      })

    {:ok, failed} =
      Lifecycle.execute(object, %{
        context()
        | read_property: fn _reference -> {:ok, 1} end
      })

    assert failed.object.reliability == :configuration_error
    assert failed.object.present_value.type == :null

    assert [{identifier, {:invalid_calendar_value, ^calendar}}] = failed.state.failures
    assert identifier == Schedule.get_object_identifier(failed.object)
  end

  test "opaque runtime state is rejected after initialization" do
    {:ok, stored} = Lifecycle.execute(schedule(), context())

    assert {:error, :invalid_execution_state} =
             Schedule.execute(stored.object, %{context() | trigger: :periodic, state: :bad})

    assert {:error, :invalid_execution_state} =
             Lifecycle.execute(stored.object, %{
               context()
               | trigger: :periodic,
                 state: %{stored.state | value: :not_an_encoding}
             })
  end

  test "timezone gaps and overlaps resolve actual future deadlines" do
    object = schedule(%{weekly_schedule: week([tv(2, 30, enc(:boolean, true))])})
    now = %DateTime{~U[2026-03-29 01:00:00Z] | time_zone: "Test/Gap", zone_abbr: "STD"}

    {:ok, result} =
      Lifecycle.execute(object, %{context(now) | timezone_database: TimezoneDatabase})

    assert result.next_execution.wall_time.hour == 3

    object = schedule(%{weekly_schedule: week([tv(1, 30, enc(:boolean, true))])})

    now = %DateTime{
      ~U[2026-10-25 01:45:00Z]
      | time_zone: "Test/Overlap",
        zone_abbr: "DST",
        std_offset: 3600
    }

    {:ok, result} =
      Lifecycle.execute(object, %{context(now) | timezone_database: TimezoneDatabase})

    assert result.next_execution.wall_time.hour == 1
    assert result.next_execution.wall_time.minute == 30
    assert result.next_execution.wall_time.std_offset == 0
    assert DateTime.compare(result.next_execution.wall_time, now) == :gt
    assert {:error, {:timezone_error, _reason}} = Lifecycle.execute(object, context(now))
  end

  test "typed primitive targets receive their exact Elixir representation" do
    date_pattern = %BACnetDate{
      year: :unspecified,
      month: :even,
      day: :last,
      weekday: :unspecified
    }

    time_pattern = %BACnetTime{
      hour: :unspecified,
      minute: 30,
      second: 0,
      hundredth: 42
    }

    cases = [
      {IntegerValue, enc(:signed_integer, -12), -12},
      {PositiveIntegerValue, enc(:unsigned_integer, 12), 12},
      {LargeAnalogValue, enc(:double, 1.0000000000000002), 1.0000000000000002},
      {CharacterStringValue, enc(:character_string, " Lüftung "), " Lüftung "},
      {OctetStringValue, enc(:octet_string, <<0, 255>>), <<0, 255>>},
      {BitstringValue, enc(:bitstring, {true, false}), {true, false}},
      {DatePatternValue, enc(:date, date_pattern), date_pattern},
      {DateValue, enc(:date, BACnetDate.from_date(~D[2026-11-09])),
       BACnetDate.from_date(~D[2026-11-09])},
      {TimePatternValue, enc(:time, time_pattern), time_pattern},
      {TimeValueObject, enc(:time, BACnetTime.from_time(~T[08:00:00.42])),
       BACnetTime.from_time(~T[08:00:00.42])}
    ]

    for {module, value, raw} <- cases, out_of_service <- [false, true] do
      {:ok, target} =
        module.create(2, "Typed target", %{present_value: raw, out_of_service: out_of_service})

      host =
        start(
          schedule(%{schedule_default: value, list_of_object_property_references: [ref(target)]}),
          [target]
        )

      assert record(host).object.reliability == :no_fault_detected
      assert Host.writes(host) == [{ref(target), value, 16}]
      assert Host.snapshot(host, ref(target).object_identifier).object.present_value == raw
    end

    {:ok, target} = Target.create(2, "Scalar properties")

    for {property, value, raw} <- [
          {:in_process, enc(:boolean, true), true},
          {:controlled_variable_reference, enc(:object_identifier, oid(:device, 42)),
           oid(:device, 42)},
          {:ip_address, enc(:octet_string, <<192, 168, 1, 5>>), {192, 168, 1, 5}}
        ] do
      reference = %{ref(target) | property_identifier: property}

      host =
        start(
          schedule(%{schedule_default: value, list_of_object_property_references: [reference]}),
          [target]
        )

      assert record(host).object.reliability == :no_fault_detected
      assert Host.writes(host) == [{reference, value, 16}]

      assert Map.fetch!(Host.snapshot(host, ref(target).object_identifier).object, property) ==
               raw
    end
  end

  test "local target datatype unions retain compatible primitive alternatives" do
    {:ok, target} = Target.create(2, "Union")
    reference = %{ref(target) | property_identifier: :setpoint}

    for value <- [enc(:boolean, true), enc(:real, 2.5)] do
      host =
        start(
          schedule(%{schedule_default: value, list_of_object_property_references: [reference]}),
          [target]
        )

      assert record(host).object.reliability == :no_fault_detected
      assert Host.writes(host) == [{reference, value, 16}]
      assert Host.snapshot(host, ref(target).object_identifier).object.setpoint == value.value
    end
  end

  test "numeric property identifiers preserve target references and do not bypass Schedule access" do
    {:ok, target} = Target.create(2, "Target")
    reference = %{ref(target) | property_identifier: 85}

    host =
      start(
        schedule(%{
          schedule_default: enc(:boolean, true),
          list_of_object_property_references: [reference]
        }),
        [target]
      )

    assert Host.writes(host) == [{reference, enc(:boolean, true), 16}]
    original = schedule()
    {:ok, candidate} = Schedule.update_property(original, :present_value, enc(:boolean, true))

    assert {:error, {:write_access_denied, :present_value}} =
             Lifecycle.prepare_write(original, candidate, %{
               context()
               | trigger: {:property_write, 85, nil, nil}
             })
  end

  test "computed value is retained before target I/O and no write occurs in the calculation step" do
    {:ok, target} = Target.create(2, "Target")

    object =
      schedule(%{
        schedule_default: enc(:boolean, true),
        list_of_object_property_references: [ref(target)]
      })

    context = %{
      context()
      | lookup_object: fn _reference -> {:ok, target} end,
        write_property: fn _reference, _value, _priority ->
          published = Process.get(:published_schedule)
          assert published.present_value.value
          :ok
        end
    }

    {:ok, calculated} = Lifecycle.execute(object, context)
    assert calculated.next_execution == :immediate
    Process.put(:published_schedule, calculated.object)

    assert {:ok, %Result{next_execution: %BACnet.Protocol.ObjectExecution.Wakeup{}}} =
             Lifecycle.execute(calculated.object, %{
               context
               | state: calculated.state,
                 trigger: :continuation
             })
  end

  test "target datatype checks include future values and clearing a fault resynchronizes targets" do
    {:ok, binary} = BinaryOutput.create(2, "Binary")

    object =
      schedule(%{
        schedule_default: enc(:enumerated, 0),
        weekly_schedule: week([tv(9, 0, enc(:enumerated, 2))]),
        list_of_object_property_references: [ref(binary)]
      })

    host = start(object, [binary])
    assert record(host).object.reliability == :configuration_error
    assert Host.writes(host) == []

    assert :ok =
             Host.write(
               host,
               %{ref(object) | property_identifier: :weekly_schedule},
               week([tv(9, 0, enc(:enumerated, 1))])
             )

    assert record(host).object.reliability == :no_fault_detected
    assert target_writes(host) == [{ref(binary), enc(:enumerated, 0), 16}]
  end

  test "reliability inhibit masks faults and only preserves explicitly written OOS reliability" do
    {:ok, target} = Target.create(2, "Target")

    object =
      schedule(%{
        schedule_default: enc(:boolean, true),
        reliability_evaluation_inhibit: false,
        list_of_object_property_references: [ref(target)]
      })

    host = Host.new([{object, []}, {target, []}], @now, 0)
    Host.fail_writes(host, ref(target).object_identifier, :offline)
    assert :ok = Host.execute(host, oid(:schedule, 1), :initialization)
    assert record(host).object.reliability == :communication_failure

    assert :ok =
             Host.write(
               host,
               %{ref(object) | property_identifier: :reliability_evaluation_inhibit},
               true
             )

    assert record(host).object.reliability == :no_fault_detected
    refute record(host).object.status_flags.fault
    assert record(host).state.failures == [{ref(target), :offline}]
    assert :ok = Host.write(host, %{ref(object) | property_identifier: :out_of_service}, true)
    assert record(host).object.reliability == :no_fault_detected

    assert :ok =
             Host.write(
               host,
               %{ref(object) | property_identifier: :reliability},
               :configuration_error
             )

    assert record(host).object.reliability == :configuration_error
    assert :ok = Host.write(host, %{ref(object) | property_identifier: :out_of_service}, false)
    assert record(host).object.reliability == :no_fault_detected

    assert :ok =
             Host.write(
               host,
               %{ref(object) | property_identifier: :reliability_evaluation_inhibit},
               false
             )

    assert record(host).object.reliability == :communication_failure
  end

  test "inhibited OOS reliability simulation accepts both origins and property identifier forms" do
    for source <- [:application_write, :property_write], property <- [:reliability, 103] do
      object =
        schedule(%{
          out_of_service: true,
          reliability_evaluation_inhibit: true,
          list_of_object_property_references: []
        })

      {:ok, stored} = Lifecycle.execute(object, %{context() | trigger: :initialization})
      ctx = %{context() | trigger: {source, property, nil, nil}, state: stored.state}

      {:ok, candidate} =
        Schedule.update_property(stored.object, :reliability, :configuration_error)

      assert {:ok, prepared} = Lifecycle.prepare_write(stored.object, candidate, ctx)
      assert {:ok, simulated} = Lifecycle.execute(prepared, ctx)
      assert simulated.object.reliability == :configuration_error
      assert simulated.object.status_flags.fault

      assert {:ok, read} =
               Lifecycle.prepare_read(
                 simulated.object,
                 %{ctx | trigger: {:property_read, :reliability, nil}, state: simulated.state}
               )

      assert read.object.reliability == :configuration_error
    end
  end

  test "inline calendar range and WeekNDay exceptions use the shared full pattern semantics" do
    entries = [
      %CalendarEntry{
        type: :date_range,
        date: nil,
        week_n_day: nil,
        date_range: %DateRange{
          start_date: BACnetDate.from_date(~D[2026-11-01]),
          end_date: BACnetDate.from_date(~D[2026-11-30])
        }
      },
      %CalendarEntry{
        type: :week_n_day,
        date: nil,
        date_range: nil,
        week_n_day: %BACnet.Protocol.WeekNDay{month: 11, week_of_month: 9, weekday: 1}
      }
    ]

    for entry <- entries do
      exception = %{event([tv(0, 0, enc(:boolean, true))]) | period: entry}

      object =
        schedule(%{
          schedule_default: enc(:boolean, false),
          exception_schedule: BACnetArray.from_list([exception])
        })

      {:ok, result} = Lifecycle.execute(object, context())
      assert result.object.present_value.value
    end
  end

  test "missing Calendar values produce a retained fault and recover with a fresh read" do
    exception = %{event([tv(0, 0, enc(:boolean, true))]) | period: oid(:calendar, 2)}

    object =
      schedule(%{
        schedule_default: enc(:boolean, false),
        exception_schedule: BACnetArray.from_list([exception])
      })

    {:ok, failed} =
      Lifecycle.execute(object, %{
        context()
        | read_property: fn _reference -> {:error, :unknown_object} end
      })

    assert failed.object.reliability == :configuration_error
    assert failed.object.present_value.type == :null

    {:ok, recovered} =
      Lifecycle.execute(failed.object, %{
        context()
        | trigger: :periodic,
          state: failed.state,
          read_property: fn _reference -> {:ok, true} end
      })

    assert recovered.object.present_value.value
    assert recovered.object.reliability == :no_fault_detected
  end

  test "reserved-priority rejection is a retained configuration fault without blind retries" do
    {:ok, binary} = BinaryOutput.create(2, "Binary")

    object =
      schedule(%{
        schedule_default: enc(:enumerated, 1),
        priority_for_writing: 6,
        list_of_object_property_references: [ref(binary)]
      })

    host = start(object, [binary])
    assert record(host).object.reliability == :configuration_error
    assert record(host).state.failures == [{ref(binary), :write_access_denied}]
    assert :ok = Host.execute(host, oid(:schedule, 1), :periodic)
    assert target_writes(host) == []
    assert :ok = Host.write(host, %{ref(object) | property_identifier: :priority_for_writing}, 8)
    assert record(host).object.reliability == :no_fault_detected
    assert List.last(target_writes(host)) == {ref(binary), enc(:enumerated, 1), 8}
  end

  test "default-filled exception array slots retain their actual index and values" do
    default = event([tv(0, 0, enc(:boolean, true))])

    object =
      schedule(%{
        schedule_default: enc(:boolean, false),
        exception_schedule: BACnetArray.new(2, default)
      })

    {:ok, result} = Lifecycle.execute(object, context())
    assert result.object.present_value.value
  end

  test "invalid primitive payloads and deferred encoders fail pure preflight" do
    bad_values = [
      enc(:unsigned_integer, true),
      enc(:boolean, 1),
      enc(:real, "not a float"),
      %Encoding{
        encoding: :primitive,
        type: :real,
        value: 1.0,
        extras: [encoder: fn _value -> flunk("preflight must not invoke deferred encoders") end]
      }
    ]

    for value <- bad_values do
      object = schedule(%{schedule_default: value})

      assert {:error, {:invalid_configuration, :schedule_value}} =
               Lifecycle.execute(object, context())
    end
  end

  test "manual OOS control remains available with inconsistent automatic configuration" do
    {:ok, target} = Target.create(2, "Target")

    object =
      schedule(%{
        weekly_schedule: week([tv(0, 0, enc(:real, 1.0))]),
        schedule_default: enc(:double, 1.0),
        list_of_object_property_references: [ref(target)]
      })

    host = start(object, [target])
    assert record(host).object.reliability == :configuration_error
    assert Host.writes(host) == []
    assert :ok = Host.write(host, %{ref(object) | property_identifier: :out_of_service}, true)
    assert :ok = Host.write(host, ref(object), enc(:boolean, true))
    assert record(host).object.present_value.value
    assert record(host).object.reliability == :configuration_error
    assert target_writes(host) == [{ref(target), enc(:boolean, true), 16}]
  end

  test "primitive codec rejection becomes a configuration fault instead of a callback crash" do
    {:ok, target} = Target.create(2, "Codec")
    reference = %{ref(target) | property_identifier: :ip_address}

    for value <- [enc(:character_string, "192.168.1.5"), enc(:octet_string, <<1, 2, 3>>)] do
      host =
        start(
          schedule(%{schedule_default: value, list_of_object_property_references: [reference]}),
          [target]
        )

      assert record(host).object.reliability == :configuration_error
      assert Host.writes(host) == []
    end
  end

  test "encoder-only and decoder-only annotations preserve the actual BACnet datatype" do
    {:ok, target} = Target.create(2, "Codec")
    reference = %{ref(target) | property_identifier: :cov_increment}

    host =
      start(
        schedule(%{
          schedule_default: enc(:double, 2.5),
          list_of_object_property_references: [reference]
        }),
        [target]
      )

    assert Host.writes(host) == [{reference, enc(:double, 2.5), 16}]

    for {property, value} <- [
          {:cov_increment, enc(:real, 2.5)},
          {:deadband, enc(:unsigned_integer, 2)}
        ] do
      host =
        start(
          schedule(%{
            schedule_default: value,
            list_of_object_property_references: [%{reference | property_identifier: property}]
          }),
          [target]
        )

      assert record(host).object.reliability == :configuration_error
      assert Host.writes(host) == []
    end
  end

  test "malformed host lookup results remain programming errors" do
    object =
      schedule(%{
        schedule_default: enc(:boolean, true),
        list_of_object_property_references: [ref_id(:analog_output, 2)]
      })

    assert_raise ArgumentError, ~r/lookup_object/, fn ->
      Lifecycle.execute(object, %{
        context()
        | lookup_object: fn _reference -> {:ok, nil} end,
          write_property: fn _reference, _value, _priority -> :ok end
      })
    end
  end

  test "primitive bitstring properties represented by helper structs are converted losslessly" do
    {:ok, binary} =
      Target.create(2, "Event flags", %{
        event_enable: %EventTransitionBits{
          to_offnormal: false,
          to_fault: false,
          to_normal: false
        }
      })

    reference = %{ref(binary) | property_identifier: :event_enable}

    host =
      start(
        schedule(%{
          schedule_default: enc(:bitstring, {true, false, true}),
          list_of_object_property_references: [reference]
        }),
        [binary]
      )

    assert record(host).object.reliability == :no_fault_detected
    assert Host.writes(host) == [{reference, enc(:bitstring, {true, false, true}), 16}]

    assert Host.snapshot(host, ref(binary).object_identifier).object.event_enable ==
             EventTransitionBits.from_bitstring({true, false, true})
  end

  test "target reference validation rejects malformed containers and entries before lookup" do
    ctx = context()
    reference = ref_id(:analog_value, 2)
    error = {:error, {:invalid_configuration, :list_of_object_property_references}}

    assert ScheduleTargets.validate_references(reference, ctx) == error

    assert ScheduleTargets.validate_references([%{reference | property_array_index: -1}], ctx) ==
             error
  end

  test "local target plans reject remote snapshots, absent properties and scalar array indices" do
    {:ok, target} = Target.create(2, "Target", %{out_of_service: true})
    remote = %{target | _metadata: %{target._metadata | remote_object: 42}}
    base = ref(target)
    value = enc(:boolean, true)

    for {object, property, index, error} <- [
          {remote, :present_value, nil, :object_not_local},
          {target, 9_999, nil, {:unknown_property, 9_999}},
          {target, :event_enable, nil, {:unknown_property, :event_enable}},
          {target, :present_value, 1, :property_is_not_an_array},
          {target, :in_process, nil, {:write_access_denied, :in_process}}
        ] do
      reference = %{base | property_identifier: property, property_array_index: index}
      ctx = %{context() | lookup_object: fn _ref -> {:ok, object} end}

      assert [{^reference, {:error, ^error}}] =
               ScheduleTargets.prepare([reference], value, [], 16, ctx)
    end
  end

  test "local target plans validate array lengths and the exact wire datatype" do
    {:ok, target} = Target.create(2, "Target")
    ctx = %{context() | lookup_object: fn _ref -> {:ok, target} end}
    base = ref(target)

    for {property, index, value} <- [
          {:state_text, 0, enc(:unsigned_integer, 3)},
          {:object_list, 2, enc(:unsigned_integer, 9)},
          {:schedule_default, nil, enc(:null, nil)},
          {:reliability, nil, enc(:enumerated, 0)},
          {:max_info_frames, nil, enc(:unsigned_integer, 100)},
          {:cov_increment, nil, enc(:double, 1.0)}
        ] do
      reference = %{base | property_identifier: property, property_array_index: index}

      assert [{^reference, {:ok, ^value}}] =
               ScheduleTargets.prepare([reference], value, [], 16, ctx)
    end

    for {property, index, value, error} <- [
          {:state_text, 0, enc(:signed_integer, -1), :invalid_property_value},
          {:cov_increment, nil, enc(:double, 0.0), :unsupported_increment},
          {:cov_increment, nil, enc(:double, -1.0), {:invalid_target_encoding, ArgumentError}}
        ] do
      reference = %{base | property_identifier: property, property_array_index: index}

      assert [{^reference, {:error, ^error}}] =
               ScheduleTargets.prepare([reference], value, [], 16, ctx)
    end
  end

  defp enc(type, value), do: Encoding.create!({type, value})
  defp oid(type, instance), do: %ObjectIdentifier{type: type, instance: instance}

  defp ref_id(type, instance),
    do: %DeviceObjectPropertyRef{
      object_identifier: oid(type, instance),
      device_identifier: nil,
      property_identifier: :present_value,
      property_array_index: nil
    }

  defp ref(object),
    do: ref_id(object.__struct__.get_object_identifier(object).type, object.object_instance)

  defp week(entries),
    do: BACnetArray.from_list(List.duplicate(%DailySchedule{schedule: entries}, 7), true)

  defp tv(hour, minute, value),
    do: %TimeValue{
      time: %BACnetTime{hour: hour, minute: minute, second: 0, hundredth: 0},
      value: value
    }

  defp event(entries, priority \\ 1),
    do: %SpecialEvent{
      period: %CalendarEntry{
        type: :date,
        date: %BACnetDate{
          year: :unspecified,
          month: :unspecified,
          day: :unspecified,
          weekday: :unspecified
        },
        date_range: nil,
        week_n_day: nil
      },
      list: entries,
      priority: priority
    }

  defp schedule(properties \\ %{}) do
    {:ok, object} = Schedule.create(1, "Schedule", properties)
    object
  end

  defp context(now \\ @now),
    do: %Context{
      device_identifier: nil,
      now: now,
      timezone_database: Calendar.UTCOnlyTimeZoneDatabase,
      monotonic_time: 0,
      trigger: :initialization,
      state: nil,
      lookup_object: nil,
      read_property_multiple: nil,
      read_property: nil,
      write_property: nil,
      options: []
    }

  defp start(object, targets) do
    host = Host.new(Enum.map([object | targets], &{&1, []}), @now, 0)

    for target <- targets,
        target.__struct__ in [
          AnalogOutput,
          BinaryOutput,
          BitstringValue,
          CharacterStringValue,
          DatePatternValue,
          DateValue,
          IntegerValue,
          LargeAnalogValue,
          OctetStringValue,
          PositiveIntegerValue,
          TimePatternValue,
          TimeValueObject
        ] do
      assert :ok =
               Host.execute(
                 host,
                 target.__struct__.get_object_identifier(target),
                 :initialization
               )
    end

    assert :ok = Host.execute(host, oid(:schedule, 1), :initialization)
    host
  end

  defp record(host), do: Host.snapshot(host, oid(:schedule, 1))

  defp target_writes(host),
    do:
      Enum.reject(Host.writes(host), fn {reference, _value, _priority} ->
        reference.object_identifier == oid(:schedule, 1)
      end)
end
