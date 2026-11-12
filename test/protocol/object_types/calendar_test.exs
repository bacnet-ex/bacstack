defmodule BACnet.Protocol.ObjectTypes.CalendarTest do
  use ExUnit.Case, async: true

  alias BACnet.Protocol.BACnetDate
  alias BACnet.Protocol.CalendarEntry
  alias BACnet.Protocol.DateRange
  alias BACnet.Protocol.DeviceObjectPropertyRef
  alias BACnet.Protocol.ObjectExecution.Context
  alias BACnet.Protocol.ObjectExecution.Lifecycle
  alias BACnet.Protocol.ObjectExecution.Result
  alias BACnet.Protocol.ObjectExecution.Wakeup
  alias BACnet.Protocol.ObjectsProtocol
  alias BACnet.Protocol.ObjectsUtility
  alias BACnet.Protocol.ObjectTypes.Calendar, as: CalendarObject
  alias BACnet.Protocol.WeekNDay
  alias BACnet.Test.Support.Protocol.ObjectExecutionTestHost, as: Host

  @moduletag :object_test
  doctest CalendarObject

  defmodule TimeZoneDatabase do
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

    def time_zone_periods_from_wall_datetime(~N[2026-03-29 00:00:00], "Test/Gap"),
      do: {:gap, {@standard, ~N[2026-03-29 00:00:00]}, {@summer, ~N[2026-03-29 01:00:00]}}

    def time_zone_periods_from_wall_datetime(~N[2026-10-25 00:00:00], "Test/Overlap"),
      do: {:ambiguous, @summer, @standard}

    def time_zone_periods_from_wall_datetime(~N[2026-10-24 23:30:00], "Test/Overlap"),
      do: {:ambiguous, @summer, @standard}

    def time_zone_periods_from_wall_datetime(~N[2011-12-30 00:00:00], "Test/SkippedDate"),
      do:
        {:gap, {%{@standard | utc_offset: -36_000}, ~N[2011-12-30 00:00:00]},
         {%{@standard | utc_offset: 50_400}, ~N[2011-12-31 00:00:00]}}

    def time_zone_periods_from_wall_datetime(_datetime, "Test/Gap"), do: {:ok, @standard}
    def time_zone_periods_from_wall_datetime(_datetime, "Test/Overlap"), do: {:ok, @summer}

    def time_zone_periods_from_wall_datetime(_datetime, "Test/SkippedDate"),
      do: {:ok, %{@standard | utc_offset: -36_000}}
  end

  @context %Context{
    device_identifier: nil,
    now: ~U[2026-11-07 12:00:00Z],
    timezone_database: Calendar.UTCOnlyTimeZoneDatabase,
    monotonic_time: -1000,
    trigger: :initialization,
    state: nil,
    lookup_object: nil,
    read_property_multiple: nil,
    read_property: nil,
    write_property: nil,
    options: []
  }

  test "empty lists and all entry choices execute with different property revisions" do
    choices = [
      date_entry(~D[2026-11-07]),
      %CalendarEntry{
        type: :date_range,
        date: nil,
        week_n_day: nil,
        date_range: %DateRange{
          start_date: BACnetDate.from_date(~D[2026-11-01]),
          end_date: BACnetDate.from_date(~D[2026-11-08])
        }
      },
      week_entry(1, 6)
    ]

    for revision <- [14, 19],
        entries <- [[], [date_entry(~D[2026-11-08])] | Enum.map(choices, &[&1])] do
      {:ok, object} =
        CalendarObject.create(1, "Calendar", %{date_list: entries}, revision: revision)

      assert {:ok,
              %Result{
                object: updated,
                state: nil,
                next_execution: %Wakeup{wall_time: ~U[2026-11-08 00:00:00Z], monotonic_time: nil}
              }} =
               Lifecycle.execute(object, @context)

      assert updated.present_value == Enum.any?(entries, &(&1 in choices))
      assert updated.date_list == entries
    end
  end

  test "entries are ORed and repeated calls use supplied time rather than cached state" do
    {:ok, object} =
      CalendarObject.create(1, "Calendar", %{
        date_list: [date_entry(~D[2026-11-06]), date_entry(~D[2026-11-07])]
      })

    state = %{opaque: make_ref(), cached_date: ~D[2000-01-01]}

    for now <- [
          ~U[2026-11-07 12:00:00Z],
          ~U[2026-11-08 12:00:00Z],
          ~U[2026-11-06 00:00:00Z],
          ~U[2028-02-29 12:00:00Z]
        ] do
      context = %{@context | now: now, state: state, trigger: :clock_change}

      assert {:ok, %Result{object: updated, state: ^state}} =
               ObjectsProtocol.execute(object, context)

      assert updated.present_value == DateTime.to_date(now) in [~D[2026-11-06], ~D[2026-11-07]]
    end
  end

  test "all allowed wildcard and open-range forms survive property validation" do
    any = %BACnetDate{
      year: :unspecified,
      month: :unspecified,
      day: :unspecified,
      weekday: :unspecified
    }

    cases = [
      {%{date_entry(~D[2026-11-07]) | date: any}, true},
      {%{date_entry(~D[2026-11-07]) | date: %{any | month: :odd, day: :odd}}, true},
      {%{date_entry(~D[2026-11-07]) | date: %{any | day: :last}}, false},
      {week_entry(:unspecified, :unspecified), true},
      {week_entry(:unspecified, 7), false}
    ]

    ranges =
      for {start, finish, expected} <- [
            {any, any, true},
            {any, BACnetDate.from_date(~D[2026-11-06]), false},
            {BACnetDate.from_date(~D[2026-11-06]), any, true}
          ] do
        {%CalendarEntry{
           type: :date_range,
           date: nil,
           week_n_day: nil,
           date_range: %DateRange{start_date: start, end_date: finish}
         }, expected}
      end

    for revision <- [14, 19], {entry, expected} <- cases ++ ranges do
      assert {:ok, object} =
               CalendarObject.create(1, "Calendar", %{date_list: [entry]}, revision: revision)

      assert {:ok, %Result{object: updated}} = Lifecycle.execute(object, @context)
      assert updated.present_value == expected
    end
  end

  test "supported WeekNDay values work across property-revision settings" do
    options = [{[], 14} | Enum.map([0, 13, 14, 15, 18, 19, 20, 22, 1000], &{[revision: &1], &1})]

    for {opts, revision} <- options, week <- 7..9 do
      entry = week_entry(week, :unspecified)
      assert {:ok, created} = CalendarObject.create(1, "Calendar", %{date_list: [entry]}, opts)
      assert created._metadata.revision == revision
      assert {:ok, %Result{object: computed}} = Lifecycle.execute(created, @context)
      assert computed.present_value == (week == 9)
      assert computed._metadata.revision == revision
      {:ok, empty} = CalendarObject.create(1, "Calendar", %{}, opts)
      assert {:ok, updated} = CalendarObject.update_property(empty, :date_list, [entry])
      assert {:ok, %Result{object: ^computed}} = CalendarObject.execute(updated, @context)
    end
  end

  test "semantic validation rejects incoherent choices and invalid range configuration before commit" do
    start = BACnetDate.from_date(~D[2026-11-07])

    malformed = [
      %{date_entry(~D[2026-11-07]) | week_n_day: week_entry(1, 1).week_n_day},
      %CalendarEntry{
        type: :date_range,
        date: nil,
        week_n_day: nil,
        date_range: %DateRange{start_date: %{start | day: :last}, end_date: start}
      }
    ]

    {:ok, object} = CalendarObject.create(1, "Calendar")

    for entry <- malformed do
      assert {:error, {_reason, :date_list}} =
               CalendarObject.create(1, "Calendar", %{date_list: [entry]})

      assert {:error, {_reason, :date_list}} =
               CalendarObject.update_property(object, :date_list, [entry])

      candidate = %{object | date_list: [entry]}

      assert {:error, {:invalid_configuration, :date_list}} =
               Lifecycle.prepare_write(object, candidate, %{
                 @context
                 | trigger: {:property_write, :date_list, nil, nil}
               })
    end
  end

  test "computed Present_Value denies external writes while internal updates remain possible" do
    {:ok, object} = CalendarObject.create(1, "Calendar")
    refute CalendarObject.property_writable?(object, :present_value)
    refute ObjectsUtility.property_writable?(object, :present_value)
    assert CalendarObject.property_writable?(object, :date_list)
    {:ok, candidate} = CalendarObject.update_property(object, :present_value, true)

    for value <- [false, true] do
      assert {:error, {:write_access_denied, :present_value}} =
               Lifecycle.prepare_write(
                 object,
                 %{candidate | present_value: value},
                 %{@context | trigger: {:property_write, :present_value, nil, nil}}
               )
    end

    assert {:ok, %Result{object: %{present_value: false}}} =
             CalendarObject.execute(candidate, @context)
  end

  test "host configuration writes including equal values immediately refresh the same-date predicate" do
    {:ok, object} = CalendarObject.create(1, "Calendar")
    host = Host.new([{object, []}], @context.now, @context.monotonic_time)
    id = CalendarObject.get_object_identifier(object)

    reference = %DeviceObjectPropertyRef{
      device_identifier: nil,
      object_identifier: id,
      property_identifier: :date_list,
      property_array_index: nil
    }

    for _attempt <- 1..2 do
      assert :ok = Host.write(host, reference, [date_entry(~D[2026-11-07])])
      assert Host.snapshot(host, id).object.present_value
    end

    before_write = Host.snapshot(host, id)

    assert {:error, {:invalid_property_type, :date_list}} =
             Host.write(host, reference, [week_entry(10, :unspecified)])

    assert Host.snapshot(host, id) == before_write
    assert :ok = Host.write(host, reference, [])
    refute Host.snapshot(host, id).object.present_value
  end

  test "computed reads refresh before periodic execution and midnight timers update the next date" do
    {:ok, object} =
      CalendarObject.create(1, "Calendar", %{date_list: [date_entry(~D[2026-11-07])]})

    host = Host.new([{object, []}], @context.now, @context.monotonic_time)
    id = CalendarObject.get_object_identifier(object)

    reference = %DeviceObjectPropertyRef{
      device_identifier: nil,
      object_identifier: id,
      property_identifier: :present_value,
      property_array_index: nil
    }

    assert {:ok, true} = Host.read(host, reference)
    Host.advance(host, ~U[2026-11-08 00:00:00Z], -500)
    Host.run_due(host)
    record = Host.snapshot(host, id)
    refute record.object.present_value
    assert record.next_execution.wall_time == ~U[2026-11-09 00:00:00Z]
    Host.advance(host, ~U[2026-11-07 00:00:00Z], 0)
    assert {:ok, true} = Host.read(host, reference)
  end

  test "passive remote snapshots bypass configuration and timezone validation" do
    for remote <- [true, 0, 42] do
      {:ok, object} =
        CalendarObject.create(1, "Remote", %{date_list: :unparsed, present_value: true},
          remote_object: remote,
          revision: 22,
          skip_property_validation_remote_object: true
        )

      context = %{@context | state: :opaque, timezone_database: :no_such_database}
      expected = %Result{object: object, state: :opaque, next_execution: nil}
      assert {:ok, ^expected} = Lifecycle.execute(object, context)
      assert {:ok, ^expected} = CalendarObject.execute(object, context)
      assert :ok = CalendarObject.validate_execution(object, context)

      assert {:error, :operation_not_available_for_remote_objects} =
               CalendarObject.prepare_write(object, object, %{
                 context
                 | trigger: {:property_write, :date_list, nil, nil}
               })
    end
  end

  test "preflight checks capabilities before host I/O across property-revision settings" do
    context = %{
      @context
      | lookup_object: fn _ref -> flunk("lookup") end,
        read_property: fn _ref -> flunk("read") end,
        write_property: fn _ref, _value, _priority -> flunk("write") end
    }

    for revision <- [0, 13, 15, 18, 20, 22] do
      {:ok, object} = CalendarObject.create(1, "Calendar", %{}, revision: revision)

      assert {:ok, %Result{object: ^object}} = CalendarObject.execute(object, context)
      assert {:ok, %Result{object: ^object}} = Lifecycle.execute(object, context)
    end

    assert_raise ArgumentError, ~r/does not support intrinsic reporting/, fn ->
      CalendarObject.create(1, "Calendar", %{}, intrinsic_reporting: true)
    end

    {:ok, object} = CalendarObject.create(1, "Calendar")
    object = %{object | _metadata: %{object._metadata | intrinsic_reporting: true}}

    assert {:ok, %Result{object: result}} = Lifecycle.execute(object, context)
    assert result._metadata.intrinsic_reporting

    {:ok, object} = CalendarObject.create(1, "Calendar")
    assert {:ok, _result} = Lifecycle.execute(object, context)
  end

  test "midnight resolution handles gaps, overlaps and skipped civil dates using the supplied database" do
    {:ok, object} = CalendarObject.create(1, "Calendar")

    cases = [
      {~D[2026-03-28], "Test/Gap", ~D[2026-03-29], ~T[01:00:00], 3600},
      {~D[2026-10-24], "Test/Overlap", ~D[2026-10-25], ~T[00:00:00], 3600},
      {~D[2011-12-29], "Test/SkippedDate", ~D[2011-12-31], ~T[00:00:00], 50_400}
    ]

    for {date, zone, wake_date, wake_time, offset} <- cases do
      now = DateTime.new!(date, ~T[12:00:00], zone, TimeZoneDatabase)
      context = %{@context | now: now, timezone_database: TimeZoneDatabase}

      assert {:ok, %Result{next_execution: %Wakeup{wall_time: deadline}}} =
               Lifecycle.execute(object, context)

      assert DateTime.to_date(deadline) == wake_date
      assert DateTime.to_time(deadline) == wake_time
      assert deadline.utc_offset + deadline.std_offset == offset
      assert DateTime.compare(deadline, now) == :gt
    end
  end

  test "device-local date is used across UTC date boundaries and unsupported zones fail explicitly" do
    {:ok, object} =
      CalendarObject.create(1, "Calendar", %{date_list: [date_entry(~D[2026-10-24])]})

    now = DateTime.new!(~D[2026-10-24], ~T[00:30:00], "Test/Overlap", TimeZoneDatabase)
    assert DateTime.to_date(DateTime.shift_zone!(now, "Etc/UTC")) == ~D[2026-10-23]
    context = %{@context | now: now, timezone_database: TimeZoneDatabase}
    assert {:ok, %Result{object: %{present_value: true}}} = Lifecycle.execute(object, context)

    assert {:error, {:timezone_error, :utc_only_time_zone_database}} =
             Lifecycle.execute(object, %{
               context
               | timezone_database: Calendar.UTCOnlyTimeZoneDatabase
             })
  end

  test "a rollback across the date boundary requests the still-future ambiguous midnight" do
    {:ok, object} =
      CalendarObject.create(1, "Calendar", %{date_list: [date_entry(~D[2026-10-25])]})

    {:ambiguous, _earlier, now} =
      DateTime.new(~D[2026-10-24], ~T[23:30:00], "Test/Overlap", TimeZoneDatabase)

    context = %{@context | now: now, timezone_database: TimeZoneDatabase, trigger: :clock_change}

    assert {:ok,
            %Result{object: %{present_value: false}, next_execution: %Wakeup{wall_time: deadline}}} =
             Lifecycle.execute(object, context)

    assert deadline.std_offset == 0
    assert DateTime.to_date(deadline) == ~D[2026-10-25]
    assert DateTime.diff(deadline, now) == 1800
  end

  test "midnight wakeups cross month, leap-day, year and BACnet year limits" do
    {:ok, object} = CalendarObject.create(1, "Calendar")

    for {now, expected} <- [
          {~U[2023-02-28 23:59:59Z], ~U[2023-03-01 00:00:00Z]},
          {~U[2024-02-28 23:59:59Z], ~U[2024-02-29 00:00:00Z]},
          {~U[2024-02-29 23:59:59Z], ~U[2024-03-01 00:00:00Z]},
          {~U[2026-12-31 23:59:59Z], ~U[2027-01-01 00:00:00Z]},
          {~U[2154-12-31 23:59:59Z], ~U[2155-01-01 00:00:00Z]}
        ] do
      assert {:ok, %Result{next_execution: %Wakeup{wall_time: ^expected}}} =
               Lifecycle.execute(object, %{@context | now: now})
    end
  end

  defp date_entry(date),
    do: %CalendarEntry{
      type: :date,
      date: BACnetDate.from_date(date),
      date_range: nil,
      week_n_day: nil
    }

  defp week_entry(week, weekday),
    do: %CalendarEntry{
      type: :week_n_day,
      date: nil,
      date_range: nil,
      week_n_day: %WeekNDay{month: :unspecified, week_of_month: week, weekday: weekday}
    }
end
